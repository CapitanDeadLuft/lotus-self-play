// render11.cpp — in-game D3D11 renderer driven by the Present hook.
// Lua publishes a draw-command list (HUD + ClickGUI) + hit boxes each tick;
// this module replays them every frame (independent of bot tick) and adds
// per-frame world markers. Del / redraw are instant.
#include <windows.h>
#include <d3d11.h>
#include <d3d11_4.h>
#include <d3dcompiler.h>
#include <cstdio>
#include <cstring>
#include <cmath>
#include <cstdlib>
#include <winver.h>
#include <bcrypt.h>
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "d3dcompiler.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "version.lib")
#pragma comment(lib, "bcrypt.lib")

struct RCmd { int kind; float x, y, z, w; unsigned color; int size; char text[64]; float x2, y2, z2; };
struct RHit { float x, y, w, h; int id; };

static ID3D11Device* g_dev = NULL;
static ID3D11DeviceContext* g_ctx = NULL;
static ID3D11RenderTargetView* g_rtv = NULL;
static ID3D11Texture2D* g_fontTex = NULL;
static ID3D11ShaderResourceView* g_fontSrv = NULL;
static ID3D11VertexShader* g_vs = NULL;
static ID3D11PixelShader* g_ps = NULL;
static ID3D11InputLayout* g_layout = NULL;
static ID3D11Buffer* g_vb = NULL;
static int g_vbBytes = 0;
static bool g_loggedOverflow = false, g_loggedResNull = false, g_loggedMapFail = false;
// branch hit-counters (diagnostic build): makes "frames return early" attributable
static int g_cntInitFail = 0, g_cntBbNull = 0, g_cntCmdCount = 0, g_cntResNull = 0;
static int g_cntEnsureFail = 0, g_cntMapFail = 0;
// last completed-frame stats for the rate-limited evidence line (post-draw values)
static int g_statHud = 0, g_statMenu = 0, g_statOpen = 0, g_statEst = 0, g_statVerts = 0;
static int g_statCap = 0, g_statVb = 0, g_statDrew = 0, g_statMapOk = 0;
static int g_diagFrames = 0;
static bool g_loggedVbSize = false, g_loggedTri = false, g_loggedNan = false, g_loggedCmdCount = false;
static ID3D11BlendState* g_blend = NULL;
static ID3D11SamplerState* g_samp = NULL;
static ID3D11DepthStencilState* g_depth = NULL;
static ID3D11RasterizerState* g_rast = NULL;
static int g_vbCap = 0;
static bool g_init = false;
static int g_sw = 0, g_sh = 0;

// safety: log-once a draw-skip reason so a crash can be told apart from a driver bug
static void RLog(const char* fmt, ...);   // defined below
static void RLogSkip(const char* reason, int a, int b, int c) {
  static const char* seen[8]; static int n = 0;
  for (int i = 0; i < n; i++) if (seen[i] == reason) return;
  if (n < 8) seen[n++] = reason;
  RLog("skip draw reason=%s a=%d b=%d c=%d", reason, a, b, c);
}
static bool Finite(float v) { return v == v && v > -1e9f && v < 1e9f; }
static bool RPtrOk(void* p, size_t n);   // defined below (live-memory probe)

// ===== v4 diagnostics: draw masks, warm-up/guard, multithread, cached RTV,
// ===== device-removed handling and write-ahead stage markers.
// draw mask bits: 1=HUD(0-6), 2=MENU, 4=WORLD(7-9); 0 = no D3D calls (hook-only)
static volatile LONG g_drawMask = 7;
static int g_drawGuardMs = 0;          // suppress drawing for N ms after bb-desc change
static int g_useCachedRtv = 0;   // v4d default off (diagnostics: R11_CACHED_RTV=1)
static int g_frameId4 = 0;
static bool g_autoModLogged = false;
static DWORD g_presentTid = 0;   // render thread that owns the D3D context (documented assumption)
static int g_framesSinceBbChange = 1000;
static ULONGLONG g_lastDescChangeTick = 0;
static HWND g_lastHwnd = NULL;
static int g_lastW = 0, g_lastH = 0, g_lastFmt = 0, g_lastFlags = 0, g_lastCount = 0, g_lastSamples = 0;
static bool g_mtProtected = false, g_mtLogged = false, g_loggedDevRm = false, g_loggedMatrixBad = false, g_loggedStateCard = false, g_loggedBbNull = false;
static int g_cntHookOnly = 0, g_cntGuardSkip = 0, g_cntDevRemoved = 0, g_cntRtvCreate = 0, g_cntRtvReuse = 0, g_cntBbChange = 0;
static FILE* g_stageFile = NULL;
static int g_stageTrace = 1;   // R11_STAGE_TRACE=0 disables the per-stage trace
static int g_resize1HookCfg = 0;  // v4e(b): ResizeBuffers1 hook OFF by default; R11_RESIZE1_HOOK=1 enables (probe-gated)
static int g_restoreRt1 = 0;   // R11_RESTORE_RT1=1 restores only RTV slot 0 (game may bind 1)
static int g_mtProtectCfg = 1;  // R11_MT_PROTECT=0 disables SetMultithreadProtected
static bool g_viewSane = false;

struct BbRtvEntry { ID3D11Texture2D* tex; ID3D11RenderTargetView* rtv; };
static BbRtvEntry g_bbRtv[8]; static int g_bbRtvN = 0;
static void ClearRtvCache() { for (int i = 0; i < g_bbRtvN; i++) { if (g_bbRtv[i].rtv) g_bbRtv[i].rtv->Release(); if (g_bbRtv[i].tex) g_bbRtv[i].tex->Release(); } g_bbRtvN = 0; }

static bool MatrixSane(const float* m) {
  if (!m) return false;
  int nz = 0;
  for (int i = 0; i < 16; i++) {
    float v = m[i];
    if (!(v == v) || v > 1e6f || v < -1e6f) return false;
    if (v != 0.0f) nz++;
  }
  return nz >= 8;   // a real view/proj matrix has plenty of non-zero elements
}
static void Stage(const char* name, int hudN, int menuN, int open, int est, int verts, int cap, int drew, int mapOk) {
  if (!g_stageTrace) return;
  if (!g_stageFile) {
    g_stageFile = fopen("D:\\hake\\lotus\\r11_stages.log", "a");
    if (!g_stageFile) return;
  }
  fprintf(g_stageFile, "%llu f=%d tid=%d mask=%ld guard=%d sinceBb=%d stage=%-9s hud=%d menu=%d open=%d est=%d verts=%d cap=%d drew=%d mapOk=%d\n",
    (unsigned long long)GetTickCount64(), g_frameId4, (int)GetCurrentThreadId(), (long)g_drawMask, g_drawGuardMs, g_framesSinceBbChange,
    name, hudN, menuN, open, est, verts, cap, drew, mapOk);
  fflush(g_stageFile);   // write-ahead: a crash leaves the last executed stage on disk
}
static void InitDiagEnv() {
  const char* e;
  if ((e = getenv("R11_DRAW_MASK")) != NULL) { long v = atol(e); if (v < 0) v = 0; if (v > 7) v = 7; InterlockedExchange(&g_drawMask, v); }
  if ((e = getenv("R11_DRAW_GUARD_MS")) != NULL) { int v = atoi(e); g_drawGuardMs = v > 0 ? v : 0; }
  if ((e = getenv("R11_CACHED_RTV")) != NULL) g_useCachedRtv = atoi(e) ? 1 : 0;
  if ((e = getenv("R11_STAGE_TRACE")) != NULL) g_stageTrace = atoi(e) ? 1 : 0;
  if ((e = getenv("R11_RESTORE_RT1")) != NULL) g_restoreRt1 = atoi(e) ? 1 : 0;
  if ((e = getenv("R11_MT_PROTECT")) != NULL) g_mtProtectCfg = atoi(e) ? 1 : 0;
  if ((e = getenv("R11_RESIZE1_HOOK")) != NULL) g_resize1HookCfg = atoi(e) ? 1 : 0;
  RLog("diag env mask=%ld guard=%d cachedRtv=%d", (long)g_drawMask, g_drawGuardMs, g_useCachedRtv);
}
static ID3D11RenderTargetView* g_uncachedRtv = NULL;
static void ReleaseUncachedRtv(void) { if (g_uncachedRtv) { g_uncachedRtv->Release(); g_uncachedRtv = NULL; } }
static ID3D11RenderTargetView* CacheRtv(ID3D11Texture2D* tex) {
  if (!tex || !g_dev) return NULL;
  if (g_useCachedRtv) {
    for (int i = 0; i < g_bbRtvN; i++) if (g_bbRtv[i].tex == tex) { g_cntRtvReuse++; return g_bbRtv[i].rtv; }
  } else if (g_uncachedRtv) { g_uncachedRtv->Release(); g_uncachedRtv = NULL; }
  ID3D11RenderTargetView* rtv = NULL;
  if (FAILED(g_dev->CreateRenderTargetView(tex, NULL, &rtv)) || !rtv) return NULL;
  g_cntRtvCreate++;
  if (!g_useCachedRtv) { g_uncachedRtv = rtv; return rtv; }
  if (g_bbRtvN < 8) { tex->AddRef(); g_bbRtv[g_bbRtvN].tex = tex; g_bbRtv[g_bbRtvN].rtv = rtv; g_bbRtvN++; }
  return rtv;
}
struct Vert;   // full definition later (v4 helpers only hold a pointer)
static struct Vert* g_buf = NULL; static int g_n = 0; static int g_cap = 0;
static void ReleaseD3D() {
  ClearRtvCache();
  if (g_fontSrv) { g_fontSrv->Release(); g_fontSrv = NULL; }
  if (g_fontTex) { g_fontTex->Release(); g_fontTex = NULL; }
  if (g_vb) { g_vb->Release(); g_vb = NULL; }
  if (g_layout) { g_layout->Release(); g_layout = NULL; }
  if (g_vs) { g_vs->Release(); g_vs = NULL; }
  if (g_ps) { g_ps->Release(); g_ps = NULL; }
  if (g_blend) { g_blend->Release(); g_blend = NULL; }
  if (g_samp) { g_samp->Release(); g_samp = NULL; }
  if (g_depth) { g_depth->Release(); g_depth = NULL; }
  if (g_rast) { g_rast->Release(); g_rast = NULL; }
  if (g_rtv) { g_rtv->Release(); g_rtv = NULL; }
  if (g_ctx) { g_ctx->Release(); g_ctx = NULL; }
  if (g_dev) { g_dev->Release(); g_dev = NULL; }
  g_vbBytes = 0; g_cap = 0; g_bbRtvN = 0; g_init = false;
}
extern "C" __declspec(dllexport) void R11_SetDrawMask(int m) {
  if (m < 0) m = 0; if (m > 7) m = 7;
  InterlockedExchange(&g_drawMask, m);
  RLog("setdrawmask bits=%d (1=hud 2=menu 4=world; 0=hook-only)", m);
}
extern "C" __declspec(dllexport) void R11_SetDrawMode(int m) { R11_SetDrawMask(m); }
extern "C" __declspec(dllexport) void R11_SetDrawGuard(int ms) { g_drawGuardMs = ms > 0 ? ms : 0; RLog("setdrawguard ms=%d", g_drawGuardMs); }
extern "C" __declspec(dllexport) void R11_DiagDump(void) {
  HRESULT dr = g_dev ? g_dev->GetDeviceRemovedReason() : (HRESULT)E_FAIL;
  RLog("diagdump init=%d dev=%p ctx=%p sw=%d sh=%d mt=%d mask=%ld guard=%d cachedRtv=%d devRemoved=0x%08X frames=%d bbRtvs=%d hookOnly=%d guardSkip=%d devRm=%d rtvCreate=%d rtvReuse=%d bbChange=%d stat[hud=%d menu=%d open=%d est=%d verts=%d cap=%d drew=%d mapOk=%d]",
    g_init ? 1 : 0, (void*)g_dev, (void*)g_ctx, g_sw, g_sh, g_mtProtected ? 1 : 0, (long)g_drawMask, g_drawGuardMs,
    g_useCachedRtv, (unsigned)dr, g_frameId4, g_bbRtvN, g_cntHookOnly, g_cntGuardSkip, g_cntDevRemoved,
    g_cntRtvCreate, g_cntRtvReuse, g_cntBbChange,
    g_statHud, g_statMenu, g_statOpen, g_statEst, g_statVerts, g_statCap, g_statDrew, g_statMapOk);
}
extern "C" __declspec(dllexport) void R11_LogPresent(long long hr) {
  HRESULT dr = g_dev ? g_dev->GetDeviceRemovedReason() : (HRESULT)E_FAIL;
  static ULONGLONG last = 0;
  ULONGLONG now = GetTickCount64();
  bool bad = (hr != 0 && FAILED((HRESULT)hr)) || FAILED(dr);
  if (bad || now - last > 2000) {
    last = now;
    RLog("present tid=%d hr=0x%08X devRemoved=0x%08X f=%d mask=%ld mt=%d", (int)GetCurrentThreadId(), (unsigned)(HRESULT)hr, (unsigned)dr, g_frameId4, (long)g_drawMask, g_mtProtected ? 1 : 0);
  }
  Stage("present", g_statHud, g_statMenu, g_statOpen, g_statEst, g_statVerts, g_statCap, g_statDrew, g_statMapOk);
  if (FAILED(dr)) { g_cntDevRemoved++; if (!g_loggedDevRm) { g_loggedDevRm = true; RLog("device removed reason=0x%08X -> release+reinit next frame", (unsigned)dr); } ReleaseD3D(); }
}

// published state
static CRITICAL_SECTION g_cs;
static bool g_csInit = false;
static RCmd g_hud[4096]; static int g_hudN = 0;
static RCmd g_menu[8192]; static int g_menuN = 0;
static RHit g_hits[1024]; static int g_hitsN = 0;
static int g_clickQ[256]; static int g_clickN = 0;
static volatile LONG g_r11Open = 0;
// published menu panel rectangle in backbuffer px (x,y,w,h); the input hook
// uses it + the widget hit boxes to decide whether a click belongs to the GUI
static float g_menuRect[4] = { 0, 0, 0, 0 };
extern "C" __declspec(dllexport) void R11_ToLocal(float x, float y, float* lx, float* ly);

// font atlas
struct Glyph { float u0, v0, u1, v1; float w, h; float adv; float top; };
static Glyph g_glyphR[0x500];
static Glyph g_glyphB[0x500];
static int g_fontPix = 0;
static const int ATLAS = 1024;

static void Lock() { if (!g_csInit) { InitializeCriticalSection(&g_cs); g_csInit = true; } EnterCriticalSection(&g_cs); }
static void Unlock() { LeaveCriticalSection(&g_cs); }

static const char* VS_SRC =
  "struct VSIn { float2 pos:POSITION; float2 uv:TEXCOORD; float4 col:COLOR; };"
  "struct PSIn { float4 pos:SV_POSITION; float2 uv:TEXCOORD; float4 col:COLOR; };"
  "PSIn main(VSIn i){ PSIn o; o.pos=float4(i.pos,0,1); o.uv=i.uv; o.col=i.col; return o; }";
static const char* PS_SRC =
  "Texture2D tex:register(t0); SamplerState samp:register(s0);"
  "struct PSIn { float4 pos:SV_POSITION; float2 uv:TEXCOORD; float4 col:COLOR; };"
  "float4 main(PSIn i):SV_TARGET { float a = (i.uv.x < 0.0) ? 1.0 : tex.Sample(samp,i.uv).a; return float4(i.col.rgb, i.col.a*a); }";

struct Vert { float x, y, u, v; unsigned char r, g, b, a; };

static void BuildFontAtlas() {
  HDC scr = GetDC(NULL);
  HDC dc = CreateCompatibleDC(scr);
  BITMAPINFO bmi = {};
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = ATLAS; bmi.bmiHeader.biHeight = -ATLAS;
  bmi.bmiHeader.biPlanes = 1; bmi.bmiHeader.biBitCount = 32;
  void* bits = NULL;
  HBITMAP dib = CreateDIBSection(scr, &bmi, DIB_RGB_COLORS, &bits, NULL, 0);
  HGDIOBJ old = SelectObject(dc, dib);
  memset(bits, 0, ATLAS * ATLAS * 4);
  int px = 28;
  SetBkMode(dc, TRANSPARENT);
  SetTextColor(dc, 0xFFFFFF);
  ((unsigned*)bits)[0] = 0xFFFFFFFF; // white pixel at (0,0)
  int cursorY = 1;
  for (int pass = 0; pass < 2; pass++) {
    int weight = pass == 0 ? 400 : 700;
    Glyph* arr = pass == 0 ? g_glyphR : g_glyphB;
    HFONT f = CreateFontA(-px, 0, 0, 0, weight, 0, 0, 0, DEFAULT_CHARSET, 0, 0, ANTIALIASED_QUALITY, 0, "Bahnschrift");
    if (!f) f = CreateFontA(-px, 0, 0, 0, weight, 0, 0, 0, DEFAULT_CHARSET, 0, 0, ANTIALIASED_QUALITY, 0, "Segoe UI");
    HGDIOBJ of = SelectObject(dc, f);
    // GDI silently substitutes when the face is missing; verify and fall back
    {
      char face[64] = { 0 };
      GetTextFaceA(dc, sizeof(face), face);
      if (!strstr(face, "Bahnschrift")) {
        SelectObject(dc, of); DeleteObject(f);
        f = CreateFontA(-px, 0, 0, 0, weight, 0, 0, 0, DEFAULT_CHARSET, 0, 0, ANTIALIASED_QUALITY, 0, "Segoe UI");
        of = SelectObject(dc, f);
      }
    }
    int x = 1, y = cursorY, rowH = 0;
    for (int c = 32; c < 0x500; c++) {
      // skip codepoints the font has no glyph for
      wchar_t wch[2] = { (wchar_t)c, 0 };
      WORD gi = 0;
      if (GetGlyphIndicesW(dc, wch, 1, &gi, GGI_MARK_NONEXISTING_GLYPHS) != 1 || gi == 0xFFFF) continue;
      ABC abc; float adv = px * 0.5f;
      if (c < 127) { if (GetCharABCWidthsA(dc, c, c, &abc)) adv = (float)(abc.abcA + abc.abcB + abc.abcC); }
      else { if (GetCharABCWidthsW(dc, c, c, &abc)) adv = (float)(abc.abcA + abc.abcB + abc.abcC); }
      int gw = (int)ceilf(adv) + 2, gh = px + 6;
      if (x + gw >= ATLAS) { x = 1; y += rowH + 1; rowH = 0; }
      if (y + gh >= ATLAS) break;
      TextOutW(dc, x, y, wch, 1);
      Glyph& g = arr[c];
      g.u0 = (float)x / ATLAS; g.v0 = (float)y / ATLAS;
      g.u1 = (float)(x + gw) / ATLAS; g.v1 = (float)(y + gh) / ATLAS;
      g.w = (float)gw; g.h = (float)gh; g.adv = adv;
      x += gw + 1; if (gh > rowH) rowH = gh;
    }
    SelectObject(dc, of); DeleteObject(f);
    cursorY = y + rowH + 2;
  }
  // GDI writes RGB but leaves alpha=0; derive alpha from luminance so the
  // pixel shader's .a sample is non-zero (white glyphs -> opaque).
  {
    unsigned char* p = (unsigned char*)bits;
    for (int i = 0; i < ATLAS * ATLAS; i++) {
      unsigned char b = p[i*4+0], g = p[i*4+1], r = p[i*4+2];
      unsigned char a = (r > g ? (r > b ? r : b) : (g > b ? g : b));
      p[i*4+0] = 255; p[i*4+1] = 255; p[i*4+2] = 255; p[i*4+3] = a;
    }
    for (int pass = 0; pass < 2; pass++) {
      Glyph* arr = pass == 0 ? g_glyphR : g_glyphB;
      for (int c = 32; c < 0x500; c++) {
        Glyph& g = arr[c];
        if (g.adv <= 0) continue;
        int x0 = (int)(g.u0 * ATLAS), y0 = (int)(g.v0 * ATLAS);
        int gw = (int)g.w, gh = (int)g.h;
        int top = gh;
        for (int r = 0; r < gh && top == gh; r++) {
          for (int q = 0; q < gw; q++) {
            if (p[((y0 + r) * ATLAS + (x0 + q)) * 4 + 3] > 16) { top = r; break; }
          }
        }
        g.top = (top == gh) ? 0.0f : (float)top;
      }
    }
  }
  // upload
  D3D11_TEXTURE2D_DESC td = {};
  td.Width = ATLAS; td.Height = ATLAS; td.MipLevels = 1; td.ArraySize = 1;
  td.Format = DXGI_FORMAT_B8G8R8A8_UNORM; td.SampleDesc.Count = 1;
  td.Usage = D3D11_USAGE_IMMUTABLE; td.BindFlags = D3D11_BIND_SHADER_RESOURCE;
  D3D11_SUBRESOURCE_DATA sd = {}; sd.pSysMem = bits; sd.SysMemPitch = ATLAS * 4;
  g_dev->CreateTexture2D(&td, &sd, &g_fontTex);
  g_dev->CreateShaderResourceView(g_fontTex, NULL, &g_fontSrv);
  SelectObject(dc, old); DeleteObject(dib); DeleteDC(dc); ReleaseDC(NULL, scr);
  g_fontPix = px;
}

static void RLog(const char* fmt, ...) {
  FILE* f = fopen("D:\\hake\\lotus\\host.log", "a");
  if (!f) return;
  SYSTEMTIME st; GetLocalTime(&st);
  fprintf(f, "[%02d:%02d:%02d] R11: ", st.wHour, st.wMinute, st.wSecond);
  va_list ap; va_start(ap, fmt); vfprintf(f, fmt, ap); va_end(ap);
  fprintf(f, "\n"); fclose(f);
}
// ===== v4c: run.txt-callable module/version/md5 evidence (R11_LogModules) =====
static void FileVersionStr(const char* path, char out[64]) {
  out[0] = 0;
  DWORD sz = GetFileVersionInfoSizeA(path, NULL);
  if (!sz) return;
  void* buf = malloc(sz);
  if (buf && GetFileVersionInfoA(path, 0, sz, buf)) {
    VS_FIXEDFILEINFO* fi = NULL; UINT len = 0;
    if (VerQueryValueA(buf, "\\", (LPVOID*)&fi, &len) && fi)
      sprintf(out, "%u.%u.%u.%u", HIWORD(fi->dwFileVersionMS), LOWORD(fi->dwFileVersionMS), HIWORD(fi->dwFileVersionLS), LOWORD(fi->dwFileVersionLS));
  }
  free(buf);
}
static void Md5FileHex(const char* path, char out[33]) {
  out[0] = 0;
  HANDLE f = CreateFileA(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);
  if (f == INVALID_HANDLE_VALUE) return;
  BCRYPT_ALG_HANDLE alg = NULL; BCRYPT_HASH_HANDLE h = NULL; UCHAR digest[16];
  if (BCryptOpenAlgorithmProvider(&alg, BCRYPT_MD5_ALGORITHM, NULL, 0) == 0 &&
      BCryptCreateHash(alg, &h, NULL, 0, NULL, 0, 0) == 0) {
    UCHAR buf[65536]; DWORD n = 0; bool ok = true;
    while (ReadFile(f, buf, sizeof(buf), &n, NULL) && n > 0) if (BCryptHashData(h, buf, n, 0) != 0) { ok = false; break; }
    if (ok && BCryptFinishHash(h, digest, 16, 0) == 0) {
      for (int i = 0; i < 16; i++) sprintf(out + i * 2, "%02X", digest[i]);
      out[32] = 0;
    }
    BCryptDestroyHash(h);
  }
  if (alg) BCryptCloseAlgorithmProvider(alg, 0);
  CloseHandle(f);
}
static void LogOneModule(const char* name) {
  HMODULE h = GetModuleHandleA(name);
  if (!h) { RLog("modules %s NOT LOADED", name); return; }
  char path[MAX_PATH] = {0}; GetModuleFileNameA(h, path, MAX_PATH);
  char ver[64] = {0}; FileVersionStr(path, ver);
  RLog("modules %s base=%p size? path=%s version=%s", name, (void*)h, path[0] ? path : "?", ver[0] ? ver : "?");
}
extern "C" __declspec(dllexport) void R11_ReleaseBackbufferRefs(const char* why) {
  DWORD tid = GetCurrentThreadId();
  if (g_presentTid && tid != g_presentTid) { RLog("release-refs tid=%lu present=%lu skip=1 why=%s", (unsigned long)tid, (unsigned long)g_presentTid, why ? why : "?"); return; }
  RLog("release-refs tid=%lu present=%lu skip=0 why=%s", (unsigned long)tid, (unsigned long)g_presentTid, why ? why : "?");
  ClearRtvCache();
  if (g_uncachedRtv) { g_uncachedRtv->Release(); g_uncachedRtv = NULL; }
  if (g_rtv) { g_rtv->Release(); g_rtv = NULL; }
  RLog("backbuffer refs released why=%s cachedRtvs=0 uncached=0", why ? why : "?");
}
extern "C" __declspec(dllexport) void R11_LogModules(void) {
  HMODULE self = GetModuleHandleA("host16.dll");
  char selfPath[MAX_PATH] = {0}; if (self) GetModuleFileNameA(self, selfPath, MAX_PATH);
  char md5[33] = {0}; Md5FileHex(selfPath, md5);
  RLog("modules host16 base=%p path=%s md5=%s", (void*)self, selfPath[0] ? selfPath : "?", md5[0] ? md5 : "?");
  LogOneModule("gameoverlayrenderer64.dll");
  LogOneModule("gameoverlayui64.dll");
  LogOneModule("GameBar.dll");
  LogOneModule("GameBarPresenceWriter.dll");
  LogOneModule("nvwgf2umx.dll");
  LogOneModule("d3d11.dll");
  LogOneModule("dxgi.dll");
  LogOneModule("nvngx.dll");
  RLog("modules drawmode mask=%ld guard=%d cachedRtv=%d mtProtect=%d stageTrace=%d restoreRt1=%d resize1Hook=%d",
    (long)g_drawMask, g_drawGuardMs, g_useCachedRtv, g_mtProtectCfg, g_stageTrace, g_restoreRt1, g_resize1HookCfg);
}
static bool InitD3D(IDXGISwapChain* sc) {
  if (g_init) return true;
  InitDiagEnv();
  if (FAILED(sc->GetDevice(__uuidof(ID3D11Device), (void**)&g_dev))) { RLog("GetDevice failed"); return false; }
  g_dev->GetImmediateContext(&g_ctx);
  // v4 primary candidate: Dota's in-match renderer is multithreaded; our
  // Present-thread D3D calls can race the engine unless the device is protected.
  {
    ID3D11Multithread* mt = NULL;
    if (!g_mtProtectCfg) {
      if (!g_mtLogged) { g_mtLogged = true; RLog("multithread protect DISABLED by R11_MT_PROTECT=0"); }
    } else if (SUCCEEDED(g_dev->QueryInterface(__uuidof(ID3D11Multithread), (void**)&mt)) && mt) {
      BOOL already = mt->GetMultithreadProtected();
      if (!already) mt->SetMultithreadProtected(TRUE);
      g_mtProtected = mt->GetMultithreadProtected() ? true : false;
      mt->Release();
      if (!g_mtLogged) { g_mtLogged = true; RLog("multithread protected already=%d now=%d", already ? 1 : 0, g_mtProtected ? 1 : 0); }
    } else if (!g_mtLogged) { g_mtLogged = true; RLog("multithread interface UNAVAILABLE (query failed)"); }
  }
  ID3D11Texture2D* bb = NULL;
  sc->GetBuffer(0, __uuidof(ID3D11Texture2D), (void**)&bb);
  if (!bb) return false;
  // v4d: never retain a swapchain backbuffer reference (H2c); size only
  D3D11_TEXTURE2D_DESC bd; bb->GetDesc(&bd);
  g_sw = bd.Width; g_sh = bd.Height;
  bb->Release();
  ID3DBlob* vsb = NULL; ID3DBlob* psb = NULL; ID3DBlob* err = NULL;
  if (FAILED(D3DCompile(VS_SRC, strlen(VS_SRC), "vs", NULL, NULL, "main", "vs_4_0", 0, 0, &vsb, &err))) { RLog("VS compile failed: %s", err ? (char*)err->GetBufferPointer() : "?"); return false; }
  if (FAILED(D3DCompile(PS_SRC, strlen(PS_SRC), "ps", NULL, NULL, "main", "ps_4_0", 0, 0, &psb, &err))) { RLog("PS compile failed: %s", err ? (char*)err->GetBufferPointer() : "?"); return false; }
  g_dev->CreateVertexShader(vsb->GetBufferPointer(), vsb->GetBufferSize(), NULL, &g_vs);
  g_dev->CreatePixelShader(psb->GetBufferPointer(), psb->GetBufferSize(), NULL, &g_ps);
  D3D11_INPUT_ELEMENT_DESC il[] = {
    { "POSITION", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    { "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 8, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    { "COLOR", 0, DXGI_FORMAT_R8G8B8A8_UNORM, 0, 16, D3D11_INPUT_PER_VERTEX_DATA, 0 },
  };
  g_dev->CreateInputLayout(il, 3, vsb->GetBufferPointer(), vsb->GetBufferSize(), &g_layout);
  vsb->Release(); psb->Release();
  D3D11_BLEND_DESC bl = {};
  bl.RenderTarget[0].BlendEnable = TRUE;
  bl.RenderTarget[0].SrcBlend = D3D11_BLEND_SRC_ALPHA; bl.RenderTarget[0].DestBlend = D3D11_BLEND_INV_SRC_ALPHA;
  bl.RenderTarget[0].BlendOp = D3D11_BLEND_OP_ADD;
  bl.RenderTarget[0].SrcBlendAlpha = D3D11_BLEND_ONE; bl.RenderTarget[0].DestBlendAlpha = D3D11_BLEND_INV_SRC_ALPHA;
  bl.RenderTarget[0].BlendOpAlpha = D3D11_BLEND_OP_ADD;
  bl.RenderTarget[0].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL;
  g_dev->CreateBlendState(&bl, &g_blend);
  D3D11_SAMPLER_DESC sp = {};
  sp.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
  sp.AddressU = sp.AddressV = sp.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
  g_dev->CreateSamplerState(&sp, &g_samp);
  D3D11_DEPTH_STENCIL_DESC ds = {};
  ds.DepthEnable = FALSE; ds.StencilEnable = FALSE;
  ds.DepthWriteMask = D3D11_DEPTH_WRITE_MASK_ZERO;
  g_dev->CreateDepthStencilState(&ds, &g_depth);
  D3D11_RASTERIZER_DESC rs = {};
  rs.FillMode = D3D11_FILL_SOLID; rs.CullMode = D3D11_CULL_NONE;
  rs.DepthClipEnable = FALSE; rs.ScissorEnable = FALSE;
  g_dev->CreateRasterizerState(&rs, &g_rast);
  BuildFontAtlas();
  g_init = true;
  RLog("init ok sw=%d sh=%d", g_sw, g_sh);
  return true;
}

// (g_buf/g_n/g_cap are declared above, before ReleaseD3D.)
static void EnsureCap(int n) {
  if (n <= g_cap) return;
  if (n < 64) n = 64;
  int newCap = n * 2 + 1024;
  Vert* nb = (Vert*)malloc((size_t)newCap * sizeof(Vert));
  if (!nb) { RLogSkip("vert-alloc-fail", newCap, 0, 0); return; }
  free(g_buf);
  g_buf = nb;
  g_cap = newCap;
  if (g_vb) g_vb->Release();
  g_vb = NULL;
  D3D11_BUFFER_DESC vd = {};
  vd.ByteWidth = (UINT)((size_t)g_cap * sizeof(Vert));
  vd.Usage = D3D11_USAGE_DYNAMIC; vd.BindFlags = D3D11_BIND_VERTEX_BUFFER;
  vd.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
  if (FAILED(g_dev->CreateBuffer(&vd, NULL, &g_vb))) {
    g_vb = NULL; g_vbBytes = 0; g_cntEnsureFail++;
    RLogSkip("vb-create-fail", (int)vd.ByteWidth, 0, 0);
    return;
  }
  g_vbBytes = (int)vd.ByteWidth;
}
static void PushVert(float x, float y, float u, float v, unsigned c) {
  // HARD GUARD: never write past the malloc'd scratch buffer (this overflow was
  // reaching the driver's mapped VB and could fail-fast inside nvwgf2umx).
  if (g_n >= g_cap || !g_buf) {
    if (!g_loggedOverflow) { g_loggedOverflow = true; RLog("skip vert overflow n=%d cap=%d", g_n, g_cap); }
    return;
  }
  Vert& t = g_buf[g_n++];
  // pixel -> NDC clip space (SV_POSITION expects [-1,1]); y flipped
  float sw = g_sw > 0 ? (float)g_sw : 1920.0f;
  float sh = g_sh > 0 ? (float)g_sh : 1080.0f;
  t.x = (x / sw) * 2.0f - 1.0f;
  t.y = 1.0f - (y / sh) * 2.0f;
  t.u = u; t.v = v;
  t.r = (c >> 16) & 255; t.g = (c >> 8) & 255; t.b = c & 255; t.a = (c >> 24) & 255;
}
static void Quad(float x, float y, float w, float h, float u0, float v0, float u1, float v1, unsigned c) {
  PushVert(x, y, u0, v0, c); PushVert(x + w, y, u1, v0, c); PushVert(x, y + h, u0, v1, c);
  PushVert(x + w, y, u1, v0, c); PushVert(x + w, y + h, u1, v1, c); PushVert(x, y + h, u0, v1, c);
}
static void SolidRect(float x, float y, float w, float h, unsigned c) {
  Quad(x, y, w, h, -1, -1, -1, -1, c);
}
static void Text(float x, float y, const char* s, int size, unsigned c, bool bold) {
  if (size < 1) size = 1;
  if (size > 128) size = 128;
  float scale = (float)size / (g_fontPix > 0 ? g_fontPix : 28);
  float cx = x;
  const Glyph* arr = bold ? g_glyphB : g_glyphR;
  // utf8 -> codepoint
  const unsigned char* p = (const unsigned char*)s;
  while (*p) {
    int cp = *p;
    if (cp < 0x80) p++;
    else if ((cp & 0xE0) == 0xC0) { if (!p[1]) break; cp = ((cp & 0x1F) << 6) | (p[1] & 0x3F); p += 2; }
    else if ((cp & 0xF0) == 0xE0) { if (!p[1] || !p[2]) break; cp = ((cp & 0x0F) << 12) | ((p[1] & 0x3F) << 6) | (p[2] & 0x3F); p += 3; }
    else { cp = '?'; p++; }
    if (cp < 32 || cp >= 0x500) { cx += size * 0.5f; continue; }
    const Glyph& g = arr[cp];
    if (g.adv <= 0) { cx += size * 0.5f; continue; }
    Quad(cx, y, g.w * scale, g.h * scale, g.u0, g.v0, g.u1, g.v1, c);
    cx += g.adv * scale;
  }
}
static void Line(float x1, float y1, float x2, float y2, float th, unsigned c) {
  float dx = x2 - x1, dy = y2 - y1;
  float len = sqrtf(dx * dx + dy * dy);
  if (len < 0.001f) return;
  float nx = -dy / len * th * 0.5f, ny = dx / len * th * 0.5f;
  PushVert(x1 + nx, y1 + ny, -1, -1, c); PushVert(x2 + nx, y2 + ny, -1, -1, c); PushVert(x1 - nx, y1 - ny, -1, -1, c);
  PushVert(x2 + nx, y2 + ny, -1, -1, c); PushVert(x2 - nx, y2 - ny, -1, -1, c); PushVert(x1 - nx, y1 - ny, -1, -1, c);
}

static unsigned Argb(unsigned c) { return c; } // stored as 0xAARRGGBB
static void FilledCircle(float cx, float cy, float r, unsigned c);
static void CircleOutline(float cx, float cy, float r, float th, unsigned c);

// world-space commands are projected here every frame with the game's own view
// matrix (never in Lua) so they stay glued to the world while the camera moves.
static float g_viewPrev[16] = {0};
static float g_viewCur[16] = {0};
static bool g_viewValid = false;

static void UpdateViewMatrix() {
  HMODULE client = GetModuleHandleA("client.dll");
  if (!client) return;
  const float* m = (const float*)((uintptr_t)client + 0x6221CB0);
  if (!RPtrOk((void*)m, sizeof(float) * 16)) return;   // guard the raw engine read
  memcpy(g_viewPrev, g_viewCur, sizeof(g_viewPrev));
  memcpy(g_viewCur, m, sizeof(g_viewCur));
  g_viewValid = true;
  {
    bool sane = MatrixSane(g_viewCur);
    if (sane != g_viewSane) {
      g_viewSane = sane;
      if (!sane && !g_loggedMatrixBad) { g_loggedMatrixBad = true; RLog("view matrix INSANE (zero/NaN) -> world draws suspended"); }
      else if (sane) RLog("view matrix sane again -> world draws resumed");
    }
  }
}
static bool ProjectW(float x, float y, float z, float& sx, float& sy) {
  const float* m = g_viewPrev; // matrix the presented frame was rendered with
  float w = m[12]*x + m[13]*y + m[14]*z + m[15];
  if (w < 0.001f) return false;
  sx = g_sw * 0.5f * (1.0f + (m[0]*x + m[1]*y + m[2]*z + m[3]) / w);
  sy = g_sh * 0.5f * (1.0f - (m[4]*x + m[5]*y + m[6]*z + m[7]) / w);
  return sx > -g_sw && sx < g_sw * 2 && sy > -g_sh && sy < g_sh * 2;
}

static void DrawWorldCmd(const RCmd& d) {
  if (!g_viewValid || !g_viewSane) return;
  float ax, ay, bx, by;
  unsigned c = d.color;
  if (d.kind == 7) {
    if (!ProjectW(d.x, d.y, d.z, ax, ay)) return;
    if (!ProjectW(d.x2, d.y2, d.z2, bx, by)) return;
    Line(ax, ay, bx, by, d.size > 0 ? d.size / 10.0f : 2.0f, c);
  } else if (d.kind == 8) {
    if (!ProjectW(d.x, d.y, d.z, ax, ay)) return;
    FilledCircle(ax, ay, d.w, c);
  } else if (d.kind == 9) {
    if (!ProjectW(d.x, d.y, d.z, ax, ay)) return;
    CircleOutline(ax, ay, d.w, d.size > 0 ? d.size / 10.0f : 1.5f, c);
  }
}

// filled circle as a triangle fan (kind 4); radius in pixels
static void FilledCircle(float cx, float cy, float r, unsigned c) {
  if (r <= 0.01f) return;
  int seg = (int)(r * 0.7f); if (seg < 12) seg = 12; if (seg > 64) seg = 64;
  const float PI2 = 6.28318530718f;
  for (int i = 0; i < seg; i++) {
    float a0 = PI2 * i / seg, a1 = PI2 * (i + 1) / seg;
    PushVert(cx, cy, -1, -1, c);
    PushVert(cx + cosf(a0) * r, cy + sinf(a0) * r, -1, -1, c);
    PushVert(cx + cosf(a1) * r, cy + sinf(a1) * r, -1, -1, c);
  }
}
// circle outline (kind 3) drawn with segments of the given thickness
static void CircleOutline(float cx, float cy, float r, float th, unsigned c) {
  if (r <= 0.01f) return;
  int seg = (int)(r * 0.9f); if (seg < 16) seg = 16; if (seg > 96) seg = 96;
  const float PI2 = 6.28318530718f;
  float px = cx + r, py = cy;
  for (int i = 1; i <= seg; i++) {
    float a = PI2 * i / seg;
    float nx = cx + cosf(a) * r, ny = cy + sinf(a) * r;
    Line(px, py, nx, ny, th, c);
    px = nx; py = ny;
  }
}
// rounded rect: 3 rects + 4 filled corners (kind 5)
static void RoundedRect(float x, float y, float w, float h, float r, unsigned c) {
  if (w <= 0 || h <= 0) return;
  if (r <= 0.01f) { SolidRect(x, y, w, h, c); return; }
  if (r > w * 0.5f) r = w * 0.5f;
  if (r > h * 0.5f) r = h * 0.5f;
  SolidRect(x + r, y, w - r * 2, h, c);
  SolidRect(x, y + r, r, h - r * 2, c);
  SolidRect(x + w - r, y + r, r, h - r * 2, c);
  FilledCircle(x + r, y + r, r, c);
  FilledCircle(x + w - r, y + r, r, c);
  FilledCircle(x + r, y + h - r, r, c);
  FilledCircle(x + w - r, y + h - r, r, c);
}

// ---- per-frame vertex budget (fail-safe capacity, mirrors the draw dispatch) --
static int TextVerts(const char* s) {
  int n = 6;
  const unsigned char* p = (const unsigned char*)s;
  while (*p) {
    int c = *p;
    if (c < 0x80) p++;
    else if ((c & 0xE0) == 0xC0) { if (!p[1]) break; p += 2; }
    else if ((c & 0xF0) == 0xE0) { if (!p[1] || !p[2]) break; p += 3; }
    else p++;
    n += 6;   // one glyph quad
  }
  return n;
}
static int CmdVerts(const RCmd& d) {
  switch (d.kind) {
    case 0: case 6: return TextVerts(d.text);
    case 1: case 2: return 6;
    case 3: { if (!Finite(d.z)) return 0; float r = d.z; int seg = (int)(r * 0.9f); if (seg < 16) seg = 16; if (seg > 96) seg = 96; return seg * 6; }
    case 4: { if (!Finite(d.z)) return 0; float r = d.z; if (!(r > 0.01f)) return 0; int seg = (int)(r * 0.7f); if (seg < 12) seg = 12; if (seg > 64) seg = 64; return seg * 3; }
    case 5: { if (!Finite(d.z) || !Finite(d.w)) return 0; float w = d.z, h = d.w; if (!(w > 0) || !(h > 0)) return 0;
              float r = d.size > 0 ? (float)d.size : 4.0f; if (r > w * 0.5f) r = w * 0.5f; if (r > h * 0.5f) r = h * 0.5f;
              if (!(r > 0.01f)) return 6; int seg = (int)(r * 0.7f); if (seg < 12) seg = 12; if (seg > 64) seg = 64; return 18 + seg * 12; }
    case 7: return 6;
    case 8: { if (!Finite(d.w)) return 0; float r = d.w; if (!(r > 0.01f)) return 0; int seg = (int)(r * 0.7f); if (seg < 12) seg = 12; if (seg > 64) seg = 64; return seg * 3; }
    case 9: { if (!Finite(d.w)) return 0; float r = d.w; if (!(r > 0.01f)) return 0; int seg = (int)(r * 0.9f); if (seg < 16) seg = 16; if (seg > 96) seg = 96; return seg * 6; }
    default: return 0;
  }
}
static bool CmdFinite(const RCmd& d) {
  if (!Finite(d.x) || !Finite(d.y) || !Finite(d.z) || !Finite(d.w)) return false;
  if (d.kind == 7 || d.kind == 8 || d.kind == 9) { if (!Finite(d.x2) || !Finite(d.y2) || !Finite(d.z2)) return false; }
  return true;
}
static void DrawCmd(const RCmd& d) {
  unsigned c = d.color;
  if (d.kind >= 7) { DrawWorldCmd(d); return; }
  if (d.kind == 0) Text(d.x, d.y, d.text, d.size, c, false);
  else if (d.kind == 6) Text(d.x, d.y, d.text, d.size, c, true);
  else if (d.kind == 1) SolidRect(d.x, d.y, d.z, d.w, c);
  else if (d.kind == 2) Line(d.x, d.y, d.z, d.w, d.size > 0 ? d.size / 10.0f : 2.0f, c);
  else if (d.kind == 3) CircleOutline(d.x, d.y, d.z, d.w > 0 ? d.w : 1.5f, c);
  else if (d.kind == 4) FilledCircle(d.x, d.y, d.z, c);
  else if (d.kind == 5) RoundedRect(d.x, d.y, d.z, d.w, d.size > 0 ? (float)d.size : 4.0f, c);
}

extern "C" __declspec(dllexport) void R11_Size(int* w, int* h) { if (w) *w = g_sw; if (h) *h = g_sh; }
static float TextWidthImpl(const char* s, int size, int bold) {
  if (!g_init || g_fontPix <= 0) return (float)strlen(s) * size * 0.5f;
  float scale = (float)size / g_fontPix;
  float cx = 0;
  const Glyph* arr = bold ? g_glyphB : g_glyphR;
  const unsigned char* p = (const unsigned char*)s;
  while (*p) {
    int cp = *p;
    if (cp < 0x80) p++;
    else if ((cp & 0xE0) == 0xC0) { cp = ((cp & 0x1F) << 6) | (p[1] & 0x3F); p += 2; }
    else if ((cp & 0xF0) == 0xE0) { cp = ((cp & 0x0F) << 12) | ((p[1] & 0x3F) << 6) | (p[2] & 0x3F); p += 3; }
    else { cp = '?'; p++; }
    if (cp < 32 || cp >= 0x500) { cx += size * 0.5f; continue; }
    const Glyph& g = arr[cp];
    cx += (g.adv > 0 ? g.adv : size * 0.5f) * scale;
  }
  return cx;
}
extern "C" __declspec(dllexport) float R11_TextWidth(const char* s, int size) {
  return TextWidthImpl(s, size, 0);
}
extern "C" __declspec(dllexport) float R11_TextWidthW(const char* s, int size, int bold) {
  return TextWidthImpl(s, size, bold);
}
extern "C" __declspec(dllexport) void R11_PublishHud(const RCmd* cmds, int n) {
  Lock();
  if (n < 0) n = 0; if (n > 4096) n = 4096;
  if (n > 0 && cmds) {
    memcpy(g_hud, cmds, n * sizeof(RCmd));
    // reviewer fix: force NUL termination so Text/TextVerts can never walk
    // past the fixed char[64] even if the publisher omitted the terminator
    for (int i = 0; i < n; i++) g_hud[i].text[63] = 0;
  } else n = 0;
  g_hudN = n; Unlock();
}
extern "C" __declspec(dllexport) void R11_PublishMenu(const RCmd* cmds, int n) {
  Lock();
  if (n < 0) n = 0; if (n > 8192) n = 8192;
  if (n > 0 && cmds) {
    memcpy(g_menu, cmds, n * sizeof(RCmd));
    for (int i = 0; i < n; i++) g_menu[i].text[63] = 0;
  } else n = 0;
  g_menuN = n; Unlock();
}
extern "C" __declspec(dllexport) void R11_PublishHits(const RHit* h, int n) {
  Lock(); if (n > 1024) n = 1024; memcpy(g_hits, h, n * sizeof(RHit)); g_hitsN = n; Unlock();
}
// menu panel rect (backbuffer px), published with the hit boxes each rebuild
extern "C" __declspec(dllexport) void R11_PublishMenuRect(float x, float y, float w, float h) {
  Lock(); g_menuRect[0] = x; g_menuRect[1] = y; g_menuRect[2] = w; g_menuRect[3] = h; Unlock();
}
// 1 = this SCREEN-px point belongs to the ClickGUI (widget hit box or the menu
// panel itself). The LL mouse hook only swallows clicks for such points, so a
// stray menu-open flag can never eat the game's/post-game UI clicks.
extern "C" __declspec(dllexport) int R11_HitTestScreen(float sx, float sy) {
  float lx = sx, ly = sy;
  R11_ToLocal(sx, sy, &lx, &ly);
  int hit = 0;
  Lock();
  for (int i = g_hitsN - 1; i >= 0; i--) {
    RHit& h = g_hits[i];
    if (lx >= h.x && lx < h.x + h.w && ly >= h.y && ly < h.y + h.h) { hit = 1; break; }
  }
  if (!hit && g_menuRect[2] > 1.0f && g_menuRect[3] > 1.0f) {
    if (lx >= g_menuRect[0] && lx < g_menuRect[0] + g_menuRect[2] &&
        ly >= g_menuRect[1] && ly < g_menuRect[1] + g_menuRect[3]) hit = 1;
  }
  Unlock();
  return hit;
}
// closing the menu invalidates hit-testing immediately (no stale boxes survive)
// and mirrors the host hook flag so Lua-side Esc/close (R11_SetMenuOpen only)
// cannot desync it — Del always reads the renderer flag (host.cpp UiKeyHook).
extern "C" __declspec(dllexport) void R11_SetMenuOpen(int v) {
  InterlockedExchange(&g_r11Open, v ? 1 : 0);
  // g_menuOpen lives in host.cpp (declared before this file is included)
  InterlockedExchange(&g_menuOpen, v ? 1 : 0);
  if (!v) {
    Lock();
    g_hitsN = 0; g_clickN = 0;
    g_menuRect[0] = g_menuRect[1] = g_menuRect[2] = g_menuRect[3] = 0;
    Unlock();
  }
}
extern "C" __declspec(dllexport) int R11_IsMenuOpen() { return g_r11Open ? 1 : 0; }
extern "C" __declspec(dllexport) int R11_DrainClicks(int* out, int max) {
  Lock(); int n = g_clickN < max ? g_clickN : max;
  for (int i = 0; i < n; i++) out[i] = g_clickQ[i];
  if (n == g_clickN) g_clickN = 0; else { memmove(g_clickQ, g_clickQ + n, (g_clickN - n) * sizeof(int)); g_clickN -= n; }
  Unlock(); return n;
}
// Find OUR process's main window. FindWindowA("SDL_app") is NOT safe: Steam's
// steamwebhelper creates hidden SDL_app windows that sort first, which broke
// screen->menu coordinate conversion. Enumerate and match by pid instead.
struct DotaWndCtx { DWORD pid; HWND best; long long bestArea; };
static BOOL CALLBACK DotaWndEnum(HWND h, LPARAM lp) {
  DotaWndCtx* c = (DotaWndCtx*)lp;
  DWORD pid = 0; GetWindowThreadProcessId(h, &pid);
  if (pid != c->pid || !IsWindowVisible(h)) return TRUE;
  RECT r; if (!GetWindowRect(h, &r)) return TRUE;
  long long area = (long long)(r.right - r.left) * (r.bottom - r.top);
  if (area > c->bestArea) { c->bestArea = area; c->best = h; }
  return TRUE;
}
static HWND DotaMainWindow() {
  static HWND cached = NULL;
  if (cached && IsWindow(cached)) {
    DWORD pid = 0; GetWindowThreadProcessId(cached, &pid);
    if (pid == GetCurrentProcessId()) return cached;
  }
  DotaWndCtx c = { GetCurrentProcessId(), NULL, 0 };
  EnumWindows(DotaWndEnum, (LPARAM)&c);
  cached = c.best;
  return cached;
}

extern "C" __declspec(dllexport) void R11_ToLocal(float x, float y, float* lx, float* ly) {
  float ax = x, ay = y;
  HWND dw = DotaMainWindow();
  if (dw) {
    POINT org = { 0, 0 };
    ClientToScreen(dw, &org);
    RECT cr;
    if (GetClientRect(dw, &cr)) {
      float cw = (float)(cr.right - cr.left), ch = (float)(cr.bottom - cr.top);
      if (cw > 100 && ch > 100) { ax = (x - org.x) * (g_sw / cw); ay = (y - org.y) * (g_sh / ch); }
    }
  }
  if (lx) *lx = ax; if (ly) *ly = ay;
}
extern "C" __declspec(dllexport) int R11_Click(float x, float y) {
  // convert screen px -> menu-local (backbuffer) px using client origin + scale
  float lx = x, ly = y;
  HWND dw = DotaMainWindow();
  if (dw) {
    RECT cr;
    if (GetClientRect(dw, &cr)) {
      float cw = (float)(cr.right - cr.left), ch = (float)(cr.bottom - cr.top);
      if (cw > 100 && ch > 100) {
        POINT org = { 0, 0 }; ClientToScreen(dw, &org); // client-area origin (no border offset)
        lx = (x - org.x) * (g_sw / cw);
        ly = (y - org.y) * (g_sh / ch);
      }
    }
  }
  int hit = 0;
  Lock();
  for (int i = g_hitsN - 1; i >= 0; i--) {
    RHit& h = g_hits[i];
    if (lx >= h.x && lx < h.x + h.w && ly >= h.y && ly < h.y + h.h) {
      if (g_clickN < 256) g_clickQ[g_clickN++] = h.id;
      hit = 1;
      break;
    }
  }
  Unlock();
  return hit;
}

// per-frame markers (fresh hero + view matrix)
static void* g_heroInst = NULL;
static float g_goal[3]; static int g_hasGoal = 0;
extern "C" __declspec(dllexport) void R11_Marker(void* hero, float gx, float gy, float gz, int has) {
  Lock(); g_heroInst = hero; g_goal[0] = gx; g_goal[1] = gy; g_goal[2] = gz; g_hasGoal = has; Unlock();
}
static bool RPtrOk(void* p, size_t n) {
  if (!p) return false;
  MEMORY_BASIC_INFORMATION mbi;
  if (!VirtualQuery(p, &mbi, sizeof(mbi))) return false;
  if (mbi.State != MEM_COMMIT) return false;
  DWORD pr = mbi.Protect & 0xFF;
  if (!(pr == PAGE_READONLY || pr == PAGE_READWRITE || pr == PAGE_EXECUTE_READ || pr == PAGE_EXECUTE_READWRITE || pr == PAGE_WRITECOPY)) return false;
  return ((uintptr_t)p + n) <= ((uintptr_t)mbi.BaseAddress + mbi.RegionSize);
}

void R11_Render(IDXGISwapChain* sc) {
  static bool envDone = false;
  if (!envDone) { envDone = true; InitDiagEnv(); }
  g_frameId4++;
  g_presentTid = GetCurrentThreadId();
  if (g_frameId4 == 1 && !g_autoModLogged) { g_autoModLogged = true; R11_LogModules(); }
  LONG mask = InterlockedCompareExchange(&g_drawMask, 0, 0);
  if (mask == 0) { g_cntHookOnly++; Stage("hookonly", 0, 0, 0, 0, 0, 0, 0, 0); return; }   // no D3D calls at all
  if (!g_init && !InitD3D(sc)) { g_cntInitFail++; Stage("init-fail", 0, 0, 0, 0, 0, 0, 0, 0); return; }
  { // device-removed: release resources, re-init next frame (diagnostic path)
    HRESULT dr = g_dev ? g_dev->GetDeviceRemovedReason() : (HRESULT)S_OK;
    if (FAILED(dr)) {
      g_cntDevRemoved++;
      if (!g_loggedDevRm) { g_loggedDevRm = true; RLog("device removed reason=0x%08X at frame=%d -> release/reinit", (unsigned)dr, g_frameId4); }
      Stage("dev-removed", 0, 0, 0, 0, 0, 0, 0, 0);
      ReleaseD3D();
      return;
    }
  }
  Stage("enter", g_statHud, g_statMenu, g_statOpen, g_statEst, g_statVerts, g_statCap, g_statDrew, g_statMapOk);
  // Draw into the game's CURRENT render target (do not create our own RTV,
  // which breaks flip-model presentation), and fully save/restore state.
  ID3D11RenderTargetView* oldRtvArr[8] = { NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL };
  ID3D11DepthStencilView* oldDSV = NULL;
  UINT oldRtvN = 8;
  g_ctx->OMGetRenderTargets(8, oldRtvArr, &oldDSV);
  UINT vpN = 16; D3D11_VIEWPORT oldVP[16];
  g_ctx->RSGetViewports(&vpN, oldVP);
  D3D11_RECT oldSc[16]; UINT scN = 16;
  g_ctx->RSGetScissorRects(&scN, oldSc);
  ID3D11RenderTargetView* oldRTV = oldRtvArr[0];
  auto RestoreSaved = [&]() {
    if (g_restoreRt1) g_ctx->OMSetRenderTargets(1, &oldRTV, oldDSV);
    else if (oldRtvN > 0) g_ctx->OMSetRenderTargets(oldRtvN, oldRtvArr, oldDSV);
    else g_ctx->OMSetRenderTargets(1, &oldRTV, oldDSV);
    g_ctx->RSSetViewports(vpN, oldVP);
    g_ctx->RSSetScissorRects(scN, oldSc);
    for (UINT i = 0; i < 8; i++) if (oldRtvArr[i]) oldRtvArr[i]->Release();
    if (oldDSV) oldDSV->Release();
  };
  if (!g_loggedStateCard) {
    g_loggedStateCard = true;
    RLog("statecard rtvN=%u vpN=%u scN=%u dev=%p ctx=%p atlas=%p", oldRtvN, vpN, scN, (void*)g_dev, (void*)g_ctx, (void*)g_fontSrv);
  }
  Stage("capture", 0, 0, 0, 0, 0, 0, 0, 0);
  if (mask == 1) { g_cntGuardSkip++; Stage("stateonly", 0, 0, 0, 0, 0, 0, 0, 0); RestoreSaved(); return; }   // state ops only
  // backbuffer + cached RTV (recreate only on pointer/desc change)
  ID3D11Texture2D* bb = NULL;
  HRESULT hrGetBuffer = sc->GetBuffer(0, __uuidof(ID3D11Texture2D), (void**)&bb);
  ID3D11RenderTargetView* bbRTV = NULL;
  int bbW = 0, bbH = 0;
  DXGI_SWAP_CHAIN_DESC scd = {};
  sc->GetDesc(&scd);
  if (SUCCEEDED(hrGetBuffer) && bb) {
    D3D11_TEXTURE2D_DESC bd; bb->GetDesc(&bd);
    bbW = bd.Width; bbH = bd.Height;
    g_sw = bbW; g_sh = bbH;
    // transition detection: swapchain/backbuffer desc change resets warm-up
    HWND hwnd = NULL; RECT cr = { 0, 0, 0, 0 };
    hwnd = GetForegroundWindow(); if (hwnd) GetClientRect(hwnd, &cr);
    if (bbW != g_lastW || bbH != g_lastH || (int)bd.Format != g_lastFmt || (int)bd.Usage != g_lastFlags ||
        (int)bd.SampleDesc.Count != g_lastSamples || hwnd != g_lastHwnd || bd.MipLevels != g_lastCount) {
      RLog("bb change %dx%d fmt=%d samples=%d hwnd=%p client=%dx%d (prev %dx%d fmt=%d) sinceLastMs=%llu",
        bbW, bbH, (int)bd.Format, (int)bd.SampleDesc.Count, (void*)hwnd,
        (int)(cr.right - cr.left), (int)(cr.bottom - cr.top), g_lastW, g_lastH, g_lastFmt,
        (unsigned long long)(GetTickCount64() - g_lastDescChangeTick));
      g_lastW = bbW; g_lastH = bbH; g_lastFmt = (int)bd.Format; g_lastFlags = (int)bd.Usage;
      g_lastSamples = (int)bd.SampleDesc.Count; g_lastHwnd = hwnd; g_lastCount = bd.MipLevels;
      g_lastDescChangeTick = GetTickCount64(); g_framesSinceBbChange = 0; g_cntBbChange++;
      if (g_useCachedRtv) ClearRtvCache();
      bbRTV = NULL;   // force re-create after desc change
    } else {
      g_framesSinceBbChange++;
    }
    bbRTV = CacheRtv(bb);   // cache key = current backbuffer texture pointer
    bb->Release();
  }
  HRESULT hrCreateRTV = bbRTV ? S_OK : E_FAIL;
  if (!bbRTV) {
    g_cntBbNull++;
    if (!g_loggedBbNull) { g_loggedBbNull = true; RLog("skip frame reason=bb-rtv-null hrGetBuffer=0x%08X hrCreateRTV=0x%08X size=%dx%d", (unsigned)hrGetBuffer, (unsigned)hrCreateRTV, bbW, bbH); }
    Stage("rtv-fail", 0, 0, 0, 0, 0, 0, 0, 0);
    RestoreSaved();
    ReleaseUncachedRtv();
    return;
  }
  Stage("rtv", 0, 0, 0, 0, 0, 0, 0, 0);
  // warm-up gate: drawing during the first frames of a desc/swapchain transition
  // or while the engine view matrix is insane is skipped (H1/H7 candidate).
  bool guardActive = false;
  if (g_drawGuardMs > 0 && (GetTickCount64() - g_lastDescChangeTick) < (ULONGLONG)g_drawGuardMs) guardActive = true;
  if (g_framesSinceBbChange < 3) guardActive = true;
  if (guardActive) {
    g_cntGuardSkip++;
    Stage("guard", 0, 0, 0, 0, 0, 0, 0, 0);
    RestoreSaved();
    ReleaseUncachedRtv();
    return;
  }
  g_ctx->OMSetRenderTargets(1, &bbRTV, NULL);
  D3D11_VIEWPORT vp = { 0, 0, (float)bbW, (float)bbH, 0, 1 };
  g_ctx->RSSetViewports(1, &vp);

  Lock();
  int hudN = g_hudN, menuN = g_menuN;
  static RCmd hud[4096], menu[8192];
  memcpy(hud, g_hud, hudN * sizeof(RCmd));
  memcpy(menu, g_menu, menuN * sizeof(RCmd));
  void* hero = g_heroInst; float gx = g_goal[0], gy = g_goal[1], gz = g_goal[2]; int hasGoal = g_hasGoal;
  int menuOpen = g_r11Open;
  Unlock();

  {
    static ULONGLONG last = 0;
    ULONGLONG now = GetTickCount64();
    if (now - last > 2000) {
      last = now;
      // post-draw stats of the last completed frame (previous frame); <=2 s cadence.
      // first-frame diagnostics are logged separately (see "diag(first)").
      RLog("frame tid=%d hud=%d menu=%d open=%d est=%d verts=%d cap=%d vbB=%d drew=%d mapOk=%d | init=%d bb=%d cmd=%d res=%d ens=%d mapfail=%d sw=%d",
        (int)GetCurrentThreadId(), g_statHud, g_statMenu, g_statOpen, g_statEst, g_statVerts, g_statCap, g_statVb, g_statDrew, g_statMapOk,
        g_cntInitFail, g_cntBbNull, g_cntCmdCount, g_cntResNull, g_cntEnsureFail, g_cntMapFail, g_sw);
    }
  }
  // ---- safety guards (crash triage: driver vs overlay) ----
  if (hudN < 0 || hudN > 4096 || menuN < 0 || menuN > 8192) {
    g_cntCmdCount++;
    if (!g_loggedCmdCount) { g_loggedCmdCount = true; RLog("skip frame reason=cmd-count hud=%d menu=%d", hudN, menuN); }
    Stage("guard-cmd", hudN, menuN, menuOpen, 0, 0, g_cap, 0, 0);
    RestoreSaved();
    ReleaseUncachedRtv();
    return;
  }
  // BOOTSTRAP FIX (v3): the vertex buffer is created by EnsureCap, so the device/
  // atlas check must run FIRST and the g_buf/g_vb gate AFTER EnsureCap. The old
  // order returned on frame 1 (g_buf==NULL) and never allocated -> overlay dark.
  if (!g_dev || !g_ctx || !g_fontSrv) {
    g_cntResNull++;
    if (!g_loggedResNull) { g_loggedResNull = true; RLog("skip frame reason=device-or-atlas dev=%d ctx=%d srv=%d", g_dev ? 1 : 0, g_ctx ? 1 : 0, g_fontSrv ? 1 : 0); }
    Stage("guard-dev", hudN, menuN, menuOpen, 0, 0, g_cap, 0, 0);
    RestoreSaved();
    ReleaseUncachedRtv();
    return;
  }
  // exact-ish vertex budget: per-command worst case (text 6 verts/glyph,
  // circles up to 576 verts). The old formula (cmds*64) could under-estimate
  // and let PushVert/memcpy run past the mapped VB into driver memory.
  int estVerts = 64;
  for (int i = 0; i < hudN; i++) estVerts += CmdVerts(hud[i]);
  {
    LONG m = InterlockedCompareExchange(&g_drawMask, 0, 0);
    if (!(m & 2)) estVerts = 64;   // menu will not be drawn
    else if (menuOpen) for (int i = 0; i < menuN; i++) estVerts += CmdVerts(menu[i]);
  }
  EnsureCap(estVerts + 256);
  // reviewer fix A: EnsureCap's CreateBuffer can null g_vb AFTER allocation, so
  // re-validate immediately before any Map(NULL) can happen.
  if (!g_buf || !g_vb) {
    g_cntResNull++;
    if (!g_loggedResNull) { g_loggedResNull = true; RLog("skip frame reason=resource-null-after-cap buf=%d vb=%d", g_buf ? 1 : 0, g_vb ? 1 : 0); }
    Stage("guard-cap", hudN, menuN, menuOpen, estVerts, 0, g_cap, 0, 0);
    RestoreSaved();
    ReleaseUncachedRtv();
    return;
  }
  g_n = 0;
  UpdateViewMatrix();
  {
    LONG m = InterlockedCompareExchange(&g_drawMask, 0, 0);
    bool drawHud = (m & 1) != 0;
    bool drawMenu = (m & 2) != 0 && menuOpen;
    bool drawWorld = (m & 4) != 0 && g_viewSane;
    int drawHudN = 0, drawMenuN = 0;
    for (int i = 0; i < hudN; i++) {
      if (!CmdFinite(hud[i])) { if (!g_loggedNan) { g_loggedNan = true; RLog("skip cmd reason=non-finite src=hud idx=%d", i); } continue; }
      bool isWorld = hud[i].kind >= 7;
      if (isWorld ? !drawWorld : !drawHud) continue;
      DrawCmd(hud[i]);
      if (isWorld) {} else drawHudN++;
    }
    if (drawMenu) for (int i = 0; i < menuN; i++) {
      if (!CmdFinite(menu[i])) { if (!g_loggedNan) { g_loggedNan = true; RLog("skip cmd reason=non-finite src=menu idx=%d", i); } continue; }
      if (menu[i].kind >= 7) continue;   // menu never publishes world cmds
      DrawCmd(menu[i]);
      drawMenuN++;
    }
    Stage("draw", drawHudN, drawMenuN, menuOpen, estVerts, g_n, g_cap, 0, 0);
  }

  // markers
  if ((InterlockedCompareExchange(&g_drawMask, 0, 0) & 4) && g_viewSane && hero && RPtrOk(hero, 0x400)) {
    HMODULE client = GetModuleHandleA("client.dll");
    if (client) {
      const float* m = (const float*)((uintptr_t)client + 0x6221CB0);
      uintptr_t node = *(uintptr_t*)((uintptr_t)hero + 0x330);
      if (RPtrOk((void*)m, sizeof(float) * 16) && node && RPtrOk((void*)node, 0xE0)) {
        float* org = (float*)(node + 0xD8);
        float ax, ay, bx, by;
        auto proj = [&](float x, float y, float z, float& sx, float& sy) -> bool {
          float w = m[12]*x + m[13]*y + m[14]*z + m[15];
          if (w < 0.001f) return false;
          sx = (m[0]*x + m[1]*y + m[2]*z + m[3]) / w;
          sy = (m[4]*x + m[5]*y + m[6]*z + m[7]) / w;
          return sx > -1.35f && sx < 1.35f && sy > -1.35f && sy < 1.35f;
        };
        if (proj(org[0], org[1], org[2], ax, ay)) {
          int x1 = (int)(g_sw * 0.5f * (1 + ax)), y1 = (int)(g_sh * 0.5f * (1 - ay));
          if (hasGoal && proj(gx, gy, gz, bx, by)) {
            int x2 = (int)(g_sw * 0.5f * (1 + bx)), y2 = (int)(g_sh * 0.5f * (1 - by));
            Line((float)x1, (float)y1, (float)x2, (float)y2, 2, 0xFF00A5FF);
          }
        }
      }
    }
  }

  if (g_n == 0) { Stage("zeroverts", 0, 0, 0, estVerts, 0, g_cap, 0, 0); ReleaseUncachedRtv(); RestoreSaved(); return; }

  // ---- save game state ----
  Stage("statecopy", hudN, menuN, menuOpen, estVerts, g_n, g_cap, 0, 0);
  ID3D11BlendState* oldBlend = NULL; FLOAT bf[4]; UINT oldMask = 0;
  ID3D11DepthStencilState* oldDepth = NULL; UINT oldRef = 0;
  ID3D11RasterizerState* oldRast = NULL;
  ID3D11VertexShader* oldVS = NULL; ID3D11PixelShader* oldPS = NULL;
  ID3D11InputLayout* oldLayout = NULL;
  ID3D11Buffer* oldVB = NULL; UINT oldStride = 0, oldOff = 0;
  D3D11_PRIMITIVE_TOPOLOGY oldTopo;
  ID3D11ShaderResourceView* oldSrv = NULL; ID3D11SamplerState* oldSamp = NULL;
  g_ctx->OMGetBlendState(&oldBlend, bf, &oldMask);
  g_ctx->OMGetDepthStencilState(&oldDepth, &oldRef);
  g_ctx->RSGetState(&oldRast);
  g_ctx->VSGetShader(&oldVS, NULL, NULL);
  g_ctx->PSGetShader(&oldPS, NULL, NULL);
  g_ctx->IAGetInputLayout(&oldLayout);
  g_ctx->IAGetVertexBuffers(0, 1, &oldVB, &oldStride, &oldOff);
  g_ctx->IAGetPrimitiveTopology(&oldTopo);
  g_ctx->PSGetShaderResources(0, 1, &oldSrv);
  g_ctx->PSGetSamplers(0, 1, &oldSamp);

  // ---- draw overlay (bounded upload: never copy past the mapped VB) ----
  D3D11_MAPPED_SUBRESOURCE mr;
  bool drew = false, mapOk = false;
  if (SUCCEEDED(g_ctx->Map(g_vb, 0, D3D11_MAP_WRITE_DISCARD, 0, &mr)) && mr.pData) {
    mapOk = true;
    size_t need = (size_t)g_n * sizeof(Vert);
    if (g_n <= 0 || need > (size_t)g_vbBytes) {
      if (!g_loggedVbSize) { g_loggedVbSize = true; RLog("skip draw reason=vb-size n=%d bytes=%d cap=%d", g_n, (int)need, g_vbBytes); }
    } else {
      memcpy(mr.pData, g_buf, need);
      drew = true;
    }
    g_ctx->Unmap(g_vb, 0);
  } else {
    g_cntMapFail++;
    if (!g_loggedMapFail) { g_loggedMapFail = true; RLog("skip draw reason=map-fail"); }
  }
  int drawN = g_n;
  if (drawN % 3) {
    drawN -= drawN % 3;
    if (!g_loggedTri) { g_loggedTri = true; RLog("skip tris reason=non-tri n=%d", g_n); }
  }
  if (drew && drawN > 0) {
    UINT stride = sizeof(Vert), off = 0;
    g_ctx->IASetInputLayout(g_layout);
    g_ctx->IASetVertexBuffers(0, 1, &g_vb, &stride, &off);
    g_ctx->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    g_ctx->VSSetShader(g_vs, NULL, 0);
    g_ctx->PSSetShader(g_ps, NULL, 0);
    g_ctx->PSSetShaderResources(0, 1, &g_fontSrv);
    g_ctx->PSSetSamplers(0, 1, &g_samp);
    g_ctx->OMSetBlendState(g_blend, NULL, 0xFFFFFFFF);
    g_ctx->OMSetDepthStencilState(g_depth, 0);
    g_ctx->RSSetState(g_rast);
    g_ctx->Draw(drawN, 0);
  }

  // post-draw stats for the <=2 s evidence line (printed next frame) + first
  // frames printed immediately so a fresh-run gate check can read cap>0/verts>0.
  Stage("upload", hudN, menuN, menuOpen, estVerts, g_n, g_cap, drew ? 1 : 0, mapOk ? 1 : 0);
  g_statHud = hudN; g_statMenu = menuN; g_statOpen = menuOpen; g_statEst = estVerts;
  g_statVerts = g_n; g_statCap = g_cap; g_statVb = g_vbBytes;
  g_statDrew = drew ? 1 : 0; g_statMapOk = mapOk ? 1 : 0;
  if (g_diagFrames < 5) {
    g_diagFrames++;
    RLog("diag(first=%d) hud=%d menu=%d open=%d est=%d verts=%d cap=%d vbB=%d drew=%d mapOk=%d | init=%d bb=%d cmd=%d res=%d ens=%d mapfail=%d",
      g_diagFrames, hudN, menuN, menuOpen, estVerts, g_n, g_cap, g_vbBytes, drew ? 1 : 0, mapOk ? 1 : 0,
      g_cntInitFail, g_cntBbNull, g_cntCmdCount, g_cntResNull, g_cntEnsureFail, g_cntMapFail);
  }

  // ---- restore game state (full RTV array + viewports + scissor rects) ----
  Stage("restore", hudN, menuN, menuOpen, estVerts, g_n, g_cap, drew ? 1 : 0, mapOk ? 1 : 0);
  g_ctx->OMSetBlendState(oldBlend, bf, oldMask);
  g_ctx->OMSetDepthStencilState(oldDepth, oldRef);
  g_ctx->RSSetState(oldRast);
  g_ctx->VSSetShader(oldVS, NULL, 0);
  g_ctx->PSSetShader(oldPS, NULL, 0);
  g_ctx->IASetInputLayout(oldLayout);
  g_ctx->IASetVertexBuffers(0, 1, &oldVB, &oldStride, &oldOff);
  g_ctx->IASetPrimitiveTopology(oldTopo);
  g_ctx->PSSetShaderResources(0, 1, &oldSrv);
  g_ctx->PSSetSamplers(0, 1, &oldSamp);
  RestoreSaved();
  if (oldBlend) oldBlend->Release(); if (oldDepth) oldDepth->Release(); if (oldRast) oldRast->Release();
  if (oldVS) oldVS->Release(); if (oldPS) oldPS->Release(); if (oldLayout) oldLayout->Release();
  if (oldVB) oldVB->Release(); if (oldSrv) oldSrv->Release(); if (oldSamp) oldSamp->Release();
  // v4e: no backbuffer RTV may survive the frame boundary (H2c); cache refs also released here
  ReleaseUncachedRtv();
  Stage("exit", hudN, menuN, menuOpen, estVerts, g_n, g_cap, drew ? 1 : 0, mapOk ? 1 : 0);
}












