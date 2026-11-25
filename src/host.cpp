// host.cpp — in-process LuaJIT host with a file-watchdog loop.
// Loads lua51.dll (full path), then watches D:\hake\lotus\run.txt (one line = script path).
// Whenever run.txt changes, runs that script in a FRESH Lua state. No external process access
// needed for iteration (works regardless of integrity level). Logs to D:\hake\lotus\host.log.
// Create D:\hake\lotus\stop.txt to exit the watchdog. Export RunHost forces one immediate run.
#include <windows.h>
#include <cstdio>
#include <cstdarg>
#include <cstring>
#include <d3d11.h>
#include <dxgi.h>
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "user32.lib")
// ClickGUI menu-open flag shared by the input hooks. Declared BEFORE render11.cpp
// is included so R11_SetMenuOpen can mirror every Lua-side Esc/close into this
// flag — Del and Esc must stay symmetric (single source of truth).
static volatile LONG g_menuOpen = 0;
#include "render11.cpp"

static void Log(const char* fmt, ...) {
  FILE* f = fopen("D:\\hake\\lotus\\host.log", "a");
  if (!f) return;
  SYSTEMTIME st; GetLocalTime(&st);
  fprintf(f, "[%02d:%02d:%02d.%03d] ", st.wHour, st.wMinute, st.wSecond, st.wMilliseconds);
  va_list ap; va_start(ap, fmt); vfprintf(f, fmt, ap); va_end(ap);
  fprintf(f, "\n"); fclose(f);
}

typedef struct lua_State lua_State;
typedef lua_State* (*fn_luaL_newstate)(void);
typedef void (*fn_luaL_openlibs)(lua_State*);
typedef int (*fn_luaL_loadfilex)(lua_State*, const char*, const char*);
typedef int (*fn_lua_pcall)(lua_State*, int, int, int);
typedef const char* (*fn_lua_tolstring)(lua_State*, int, size_t*);
typedef void (*fn_lua_close)(lua_State*);
typedef int (*fn_luaL_loadstring)(lua_State*, const char*);

static fn_luaL_newstate  p_newstate;
static fn_luaL_openlibs  p_openlibs;
static fn_luaL_loadfilex p_loadfile;
static fn_lua_pcall      p_pcall;
static fn_lua_tolstring  p_tolstring;
static fn_lua_close      p_close;
static fn_luaL_loadstring p_loadstring;

static void RunScript(const char* scriptPath) {
  lua_State* L = p_newstate();
  if (!L) { Log("host: newstate FAILED"); return; }
  p_openlibs(L);
  const char* pathSetup = "package.path = 'D:\\\\hake\\\\lotus\\\\src\\\\?.lua;' .. package.path";
  if (p_loadstring(L, pathSetup) == 0) p_pcall(L, 0, 0, 0);
  Log("host: running %s", scriptPath);
  if (p_loadfile(L, scriptPath, NULL) != 0) {
    Log("host: load error: %s", p_tolstring(L, -1, NULL));
  } else if (p_pcall(L, 0, 0, 0) != 0) {
    Log("host: runtime error: %s", p_tolstring(L, -1, NULL));
  }
  p_close(L);
  Log("host: script finished");
}

static bool ReadRunPath(char* out, size_t cap) {
  FILE* rf = fopen("D:\\hake\\lotus\\run.txt", "r");
  if (!rf) return false;
  bool ok = false;
  if (fgets(out, (int)cap, rf)) {
    size_t n = strlen(out);
    while (n && (out[n-1]=='\n'||out[n-1]=='\r'||out[n-1]==' ')) out[--n]=0;
    ok = (n > 0);
  }
  fclose(rf);
  return ok;
}

static HRESULT STDMETHODCALLTYPE HookPresentVt(IDXGISwapChain* sc, UINT sync, UINT flags);
extern "C" __declspec(dllexport) void R11_UnhookAll(void);
static DWORD WINAPI HostThread(LPVOID) {
  Log("host: watchdog thread start pid=%lu", GetCurrentProcessId());
  HMODULE lj = LoadLibraryA("D:\\hake\\lotus\\luajit\\src\\src\\lua51.dll");
  if (!lj) { Log("host: lua51.dll load FAILED err=%lu", GetLastError()); return 1; }
  p_newstate  = (fn_luaL_newstate)  GetProcAddress(lj, "luaL_newstate");
  p_openlibs  = (fn_luaL_openlibs)  GetProcAddress(lj, "luaL_openlibs");
  p_loadfile  = (fn_luaL_loadfilex) GetProcAddress(lj, "luaL_loadfilex");
  p_pcall     = (fn_lua_pcall)      GetProcAddress(lj, "lua_pcall");
  p_tolstring = (fn_lua_tolstring)  GetProcAddress(lj, "lua_tolstring");
  p_close     = (fn_lua_close)      GetProcAddress(lj, "lua_close");
  p_loadstring= (fn_luaL_loadstring)GetProcAddress(lj, "luaL_loadstring");
  if (!p_newstate||!p_openlibs||!p_loadfile||!p_pcall||!p_tolstring||!p_close||!p_loadstring) {
    Log("host: GetProcAddress FAILED"); return 1;
  }
  Log("host: lua51 ready, watchdog armed (watch run.txt)");

  ULONGLONG lastMtime = 0;
  char scriptPath[MAX_PATH];
  for (;;) {
    if (GetFileAttributesA("D:\\hake\\lotus\\stop.txt") != INVALID_FILE_ATTRIBUTES) {
      R11_UnhookAll();
      Log("host: stop.txt detected, watchdog exit"); break;
    }
    WIN32_FILE_ATTRIBUTE_DATA fad;
    if (GetFileAttributesExA("D:\\hake\\lotus\\run.txt", GetFileExInfoStandard, &fad)) {
      ULARGE_INTEGER m; m.LowPart = fad.ftLastWriteTime.dwLowDateTime; m.HighPart = fad.ftLastWriteTime.dwHighDateTime;
      if (m.QuadPart != lastMtime) {
        lastMtime = m.QuadPart;
        if (ReadRunPath(scriptPath, sizeof(scriptPath))) RunScript(scriptPath);
      }
    }
    Sleep(400);
  }
  return 0;
}

// ---- unit orders executed on the render thread (Present hook) -------------
// Calling PrepareUnitOrders from the watchdog thread races the game thread and
// can crash Dota. Lua queues orders here; the Present hook drains them on the
// thread the game itself uses for rendering/input.
struct QOrder { void* player; int type; unsigned target; float pos[3]; unsigned ability; void* issuer; int queue; int show; };
static CRITICAL_SECTION g_qcs;
static QOrder g_q[256];
static int g_qn = 0;
// AI-14 fix: native PUO reads stack params past showEffects (arg9) up to arg13+
// (callback/executeFast/identifier/forceMinimap). 9-arg calls left arg10+ as stack
// garbage; a garbage pointer into LuaJIT memory got stored by the game and dispatched
// during entity think -> dangling after p_close(L) -> AV. Pass explicit zero defaults.
typedef bool (*PUO_fn)(void*, int, unsigned, float*, unsigned, int, void*, bool, bool,
                       unsigned long long, unsigned long long, unsigned long long, unsigned long long);
static PUO_fn g_puo = NULL;
typedef HRESULT (STDMETHODCALLTYPE *Present_fn)(IDXGISwapChain*, UINT, UINT);
static Present_fn g_origPresent = NULL;

// ---- v4d: swapchain ResizeBuffers hooks (release our backbuffer refs first) ----
typedef HRESULT (STDMETHODCALLTYPE *ResizeBuffers_fn)(IDXGISwapChain*, UINT, UINT, UINT, DXGI_FORMAT, UINT);
typedef HRESULT (STDMETHODCALLTYPE *ResizeBuffers1_fn)(IDXGISwapChain3*, UINT, UINT, UINT, DXGI_FORMAT, UINT, const UINT*, IUnknown* const*);
static ResizeBuffers_fn g_origResizeBuffers = NULL;
static ResizeBuffers1_fn g_origResizeBuffers1 = NULL;
static bool g_resize1Tried = false;
extern "C" __declspec(dllexport) void R11_ReleaseBackbufferRefs(const char* why);
static int DecodeHookPrefix(const unsigned char* target, int maxLen) {
  // Relocatable prefix decoder: accepts stack/register-only instructions (no
  // RIP-relative or absolute memory operands), complete instruction boundary,
  // prefix length >= 10 and <= maxLen (<=16).
  int len = 0;
  while (len < maxLen) {
    unsigned char a = target[len], b = target[len + 1];
    int n = 0;
    if (a == 0x48 && b == 0x8B && target[len + 2] == 0xC4) n = 3;      // mov rax,rsp
    else if (a == 0x41 && b >= 0x50 && b <= 0x57) n = 2;               // push r8-r15
    else if (a == 0x48 && b == 0x8D && target[len + 2] == 0x68) n = 4; // lea rbp,[rax+d8]
    else if (a == 0x48 && b == 0x8D && target[len + 2] == 0x6C && target[len + 3] == 0x24) n = 5; // lea rbp,[rsp+d8]
    else if (a == 0x48 && b == 0x81 && target[len + 2] == 0xEC) n = 7; // sub rsp,imm32
    else if (a == 0x48 && b == 0xC7 && target[len + 2] == 0x44 && target[len + 3] == 0x24) n = 9; // mov qword [rsp+d8],imm32
    else if (a == 0x48 && (b == 0x89 || b == 0x8B) && (target[len + 2] & 0xC7) == 0x44 && target[len + 3] == 0x24) n = 5; // mov [rsp+d8],r64 / r64,[rsp+d8]
    else if (a == 0x48 && b == 0x83 && target[len + 2] == 0xEC) n = 4; // sub rsp,imm8
    else if (a >= 0x50 && a <= 0x57) n = 1;                            // push r64
    else if (a == 0x40 && b >= 0x50 && b <= 0x57) n = 2;               // rex push r64
    else return 0;   // unknown / RIP-relative / memory-absolute -> no hook
    if (len + n > maxLen) return 0;
    len += n;
    if (len >= 10) return len;
  }
  return 0;
}
static int DecoderSelfTest(void) {
  static const unsigned char resizeBuffers[] = { 0x48,0x8B,0xC4,0x55,0x41,0x54,0x41,0x55,0x41,0x56,0x41,0x57,0x48,0x8D,0x68,0xB1 };
  static const unsigned char resizeBuffers1[] = { 0x40,0x57,0x48,0x83,0xEC,0x30,0x48,0xC7,0x44,0x24,0x20,0xFE,0xFF,0xFF,0xFF,0x48 };
  static const unsigned char negative[] = { 0x48,0x8B,0x05,0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xAA,0xBB,0xCC,0xDD };
  int okRB = DecodeHookPrefix(resizeBuffers, 16) >= 10;
  int okRB1 = DecodeHookPrefix(resizeBuffers1, 16) >= 10;
  int okNeg = DecodeHookPrefix(negative, 16) == 0;
  Log("host: decoder selftest ok=%d rbLen=%d rb1Len=%d negRejected=%d", (okRB && okRB1 && okNeg) ? 1 : 0, DecodeHookPrefix(resizeBuffers, 16), DecodeHookPrefix(resizeBuffers1, 16), okNeg ? 1 : 0);
  return (okRB && okRB1 && okNeg) ? 1 : 0;
}
static int InstallInlineHook(unsigned char* target, void* hook, void** origOut, const char* name);
static HRESULT STDMETHODCALLTYPE HookResizeBuffers(IDXGISwapChain* sc, UINT bc, UINT w, UINT h, DXGI_FORMAT fmt, UINT flags) {
  DXGI_SWAP_CHAIN_DESC d = {};
  if (sc) sc->GetDesc(&d);
  RLog("resize begin old=%ux%u new=%ux%u buffers=%u fmt=%u flags=0x%X",
    d.BufferDesc.Width, d.BufferDesc.Height, w, h, bc, (unsigned)fmt, flags);
  R11_ReleaseBackbufferRefs("ResizeBuffers");
  HRESULT hr = g_origResizeBuffers(sc, bc, w, h, fmt, flags);
  DXGI_SWAP_CHAIN_DESC a = {};
  if (sc) sc->GetDesc(&a);
  RLog("resize hr=0x%08X now=%ux%u", (unsigned)hr, a.BufferDesc.Width, a.BufferDesc.Height);
  return hr;
}
static HRESULT STDMETHODCALLTYPE HookResizeBuffers1(IDXGISwapChain3* sc, UINT bc, UINT w, UINT h, DXGI_FORMAT fmt, UINT flags, const UINT* nodeMask, IUnknown* const* presentQueue) {
  RLog("resize1 begin new=%ux%u buffers=%u fmt=%u flags=0x%X", w, h, bc, (unsigned)fmt, flags);
  R11_ReleaseBackbufferRefs("ResizeBuffers1");
  HRESULT hr = g_origResizeBuffers1(sc, bc, w, h, fmt, flags, nodeMask, presentQueue);
  RLog("resize1 hr=0x%08X", (unsigned)hr);
  return hr;
}
static volatile LONG g_draining = 0;

typedef int (*FwdQueue_fn)(void*, int, unsigned, float, float, float, unsigned, void*, int, int);
static FwdQueue_fn g_fwdQueue = NULL;
// v4l: queue lock must be initialized before ANY early return from InitOrders
// (v4i skips hook installation, and Lua orders call QueueOrder immediately).
static volatile LONG g_qcsReady = 0;
static void EnsureQueueCs(void) {
  if (InterlockedCompareExchange(&g_qcsReady, 1, 0) == 0) InitializeCriticalSection(&g_qcs);
}
// v4l diagnostics: canary-protected static position buffer for PrepareUnitOrders.
struct PuoArgCanary { unsigned long long pre; float pos[3]; unsigned long long post; };
static PuoArgCanary g_puoArgs;
static volatile LONG64 g_puoCalls = 0;
static volatile LONG64 g_puoCanaryBad = 0;
static bool g_puoVerified = false; static int g_puoMatchCount = 0; static bool g_skipPuo = false; static bool g_drainDisabled = false; static bool g_puoUnverifiedLogged = false;
#define PUO_PRE  0xC0FFEE1122334455ULL
#define PUO_POST 0xDEADBEEF55667788ULL

// ---- per-frame world markers (line hero->goal) drawn on the render thread ---
static bool PtrOk(void* p, size_t n);
extern "C" __declspec(dllexport) int QueueOrder(void* player, int type, unsigned target,
    float x, float y, float z, unsigned ability, void* issuer, int queue, int show) {
  EnsureQueueCs();
  // capture hero + goal for per-frame D3D markers (works even when forwarding)
  if (type == 1 || type == 2 || type == 4) R11_Marker(issuer, x, y, z, 1);
  else if (type == 21 || type == 10) R11_Marker(issuer, 0, 0, 0, 0);
  if (g_fwdQueue) return g_fwdQueue(player, type, target, x, y, z, ability, issuer, queue, show);
  EnterCriticalSection(&g_qcs);
  int n = g_qn;
  if (n < 256) {
    QOrder& o = g_q[n++];
    o.player = player; o.type = type; o.target = target;
    o.pos[0] = x; o.pos[1] = y; o.pos[2] = z;
    o.ability = ability; o.issuer = issuer; o.queue = queue; o.show = show;
    g_qn = n;
  }
  LeaveCriticalSection(&g_qcs);
  return n;
}

static bool PtrOk(void* p, size_t n) {
  if (!p) return false;
  MEMORY_BASIC_INFORMATION mbi;
  if (!VirtualQuery(p, &mbi, sizeof(mbi))) return false;
  if (mbi.State != MEM_COMMIT) return false;
  DWORD pr = mbi.Protect & 0xFF;
  if (!(pr == PAGE_READONLY || pr == PAGE_READWRITE || pr == PAGE_EXECUTE_READ ||
        pr == PAGE_EXECUTE_READWRITE || pr == PAGE_WRITECOPY)) return false;
  return ((uintptr_t)p + n) <= ((uintptr_t)mbi.BaseAddress + mbi.RegionSize);
}

// ---- v4h: vtable Present hook (no inline code patching during the match) ----
// The inline present hook installed at init is TEMPORARY: it exists only to
// capture the game swapchain. On the first Present we copy the swapchain
// vtable, replace slot 8 (Present) with HookPresentVt, write the instance
// vtable pointer under VirtualProtect, then restore the exact pre-patch bytes
// of dxgi!Present (Steam's own hook bytes stay intact) and verify read-back.
static bool g_inlineHookMode = false;   // R11_INLINE_HOOK=1 -> legacy behavior (no vtable swap)
static bool g_noHooks = false;          // R11_NO_HOOKS=1   -> install nothing (control build)
static IDXGISwapChain* g_vtSc = NULL;
static void** g_vtOrig = NULL;
static void** g_vtCopy = NULL;
static bool g_vtHooked = false;
static void* g_vtOldPresent = NULL;   // saved slot-8 value (dxgi/Steam handler) for in-place vtable patch
static unsigned char* g_patchTarget = NULL;
static int g_patchLen = 0;
static unsigned char g_patchOrig[16];
static bool g_patchSaved = false;

static void AddrToModule(const void* p, char* out, size_t outN, uintptr_t* offOut) {
  out[0] = 0; if (offOut) *offOut = 0;
  MEMORY_BASIC_INFORMATION mbi;
  if (!p || !VirtualQuery(p, &mbi, sizeof(mbi)) || !mbi.AllocationBase) { snprintf(out, outN, "?"); return; }
  char path[MAX_PATH] = {0};
  GetModuleFileNameA((HMODULE)mbi.AllocationBase, path, MAX_PATH);
  const char* base = path;
  for (const char* q = path; *q; q++) if (*q == '\\' || *q == '/') base = q + 1;
  size_t bl = strlen(base);
  if (bl > 4 && (base[bl - 4] == '.' ) && (base[bl - 3] == 'd' || base[bl - 3] == 'D')) { char tmp[160]; size_t n = bl - 4; if (n > 150) n = 150; memcpy(tmp, base, n); tmp[n] = 0; snprintf(out, outN, "%s", tmp); }
  else snprintf(out, outN, "%s", base);
  if (offOut) *offOut = (uintptr_t)p - (uintptr_t)mbi.AllocationBase;
}
static bool IsDxgiFamilyModule(const char* n) {
  if (!n) return false;
  return _stricmp(n, "dxgi") == 0 || _stricmp(n, "DXGI") == 0 ||
         _stricmp(n, "gameoverlayrenderer64") == 0 || _stricmp(n, "gameoverlayrenderer64.dll") == 0;
}
static void RestoreInlinePatch(void) {
  if (!g_patchSaved || !g_patchTarget || g_patchLen <= 0) return;
  DWORD old = 0;
  VirtualProtect(g_patchTarget, g_patchLen, PAGE_EXECUTE_READWRITE, &old);
  memcpy(g_patchTarget, g_patchOrig, g_patchLen);
  VirtualProtect(g_patchTarget, g_patchLen, old, &old);
  FlushInstructionCache(GetCurrentProcess(), g_patchTarget, g_patchLen);
  int ok = (memcmp(g_patchTarget, g_patchOrig, g_patchLen) == 0) ? 1 : 0;
  int nonzero = 0; for (int i = 0; i < g_patchLen; i++) if (g_patchOrig[i]) { nonzero = 1; break; }
  char tm[160]; uintptr_t toff = 0; AddrToModule((const void*)g_patchTarget, tm, sizeof(tm), &toff);
  char hex[100]; int hp = 0;
  for (int i = 0; i < g_patchLen && hp < 90; i++) hp += snprintf(hex + hp, sizeof(hex) - hp, "%02X ", g_patchOrig[i]);
  Log("host: inline patch restored ok=%d target=%s+0x%Ix addr=%p len=%d nonzeroSnapshot=%d bytes=%s",
      ok, tm, (uintptr_t)toff, (void*)g_patchTarget, g_patchLen, nonzero, hex);
  g_patchSaved = false;
}
static volatile LONG g_vtBusy = 0;
#define R11_MAX_PATCHED_VT 4
static void** g_patchedVts[R11_MAX_PATCHED_VT]; static void* g_patchedOld[R11_MAX_PATCHED_VT]; static int g_patchedVtN = 0;
// v4l: patch the REAL dxgi/Steam vtable slot 8 IN PLACE. No per-instance vptr
// swap and no malloc'd vtable: DXGI/engine identity assumptions stay intact.
static void PatchVtableSlotInPlace(void** vt, const char* whence) {
  if (!vt) return;
  if (vt[8] == (void*)&HookPresentVt) { Log("host: vtable slot already ours vt=%p (%s)", (void*)vt, whence); return; }
  MEMORY_BASIC_INFORMATION mbi;
  if (!VirtualQuery(vt, &mbi, sizeof(mbi)) || mbi.State != MEM_COMMIT ||
      ((uintptr_t)vt + 40 * sizeof(void*)) > ((uintptr_t)mbi.BaseAddress + mbi.RegionSize)) {
    Log("host: vtable slot patch skipped (unreadable vt=%p %s)", (void*)vt, whence); return;
  }
  char om[160]; uintptr_t ooff = 0; AddrToModule((const void*)vt[8], om, sizeof(om), &ooff);
  if (!IsDxgiFamilyModule(om)) {
    Log("host: vtable slot patch refused module %s+0x%Ix vt=%p (%s)", om, (uintptr_t)ooff, (void*)vt, whence); return;
  }
  DWORD old = 0;
  if (!VirtualProtect(vt, 32 * sizeof(void*), PAGE_READWRITE, &old)) { Log("host: vtable slot protect failed vt=%p (%s)", (void*)vt, whence); return; }
  void* saved = vt[8];
  vt[8] = (void*)&HookPresentVt;
  VirtualProtect(vt, 32 * sizeof(void*), old, &old);
  FlushInstructionCache(GetCurrentProcess(), vt, 32 * sizeof(void*));
  if (g_patchedVtN < R11_MAX_PATCHED_VT) { g_patchedVts[g_patchedVtN] = vt; g_patchedOld[g_patchedVtN] = saved; g_patchedVtN++; }
  g_vtOrig = vt; g_vtOldPresent = saved; g_vtCopy = NULL; g_vtHooked = true;
  char nm[160]; uintptr_t noff = 0; AddrToModule((const void*)&HookPresentVt, nm, sizeof(nm), &noff);
  Log("host: vtable slot patched in place vt=%p old=%s+0x%Ix new=%s+0x%Ix patched=%d whence=%s",
      (void*)vt, om, (uintptr_t)ooff, nm, (uintptr_t)noff, g_patchedVtN, whence);
}
static void RefreshVtableHook(void) {
  if (!g_vtHooked || !g_vtSc) return;
  if (InterlockedCompareExchange(&g_vtBusy, 1, 0) != 0) return;
  void** cur = *(void***)g_vtSc;
  if (cur && cur != g_vtOrig) {
    Log("host: swapchain vtable changed sc=%p cur=%p old=%p - patching new vtable in place", (void*)g_vtSc, (void*)cur, (void*)g_vtOrig);
    PatchVtableSlotInPlace(cur, "reinstall");
  }
  InterlockedExchange(&g_vtBusy, 0);
}
static HRESULT STDMETHODCALLTYPE HookPresentVt(IDXGISwapChain* sc, UINT sync, UINT flags);
static void InstallVtableHook(IDXGISwapChain* sc) {
  if (g_noHooks || g_vtHooked || !sc) return;
  if (GetCurrentThreadId() != g_presentTid) {
    Log("host: vtable install skipped tid=%lu presentTid=%lu", (unsigned long)GetCurrentThreadId(), (unsigned long)g_presentTid);
    RestoreInlinePatch();
    return;
  }
  void** ov = *(void***)sc;
  if (!ov) { RestoreInlinePatch(); Log("host: vtable hook failed - inline patch restored, no hooks in match (null vtable)"); return; }
  { char tm[160]; uintptr_t toff = 0; AddrToModule((const void*)(g_patchTarget ? g_patchTarget : (unsigned char*)ov[8]), tm, sizeof(tm), &toff);
    Log("host: hook target=%s+0x%Ix addr=%p", tm, (uintptr_t)toff, (void*)(g_patchTarget ? g_patchTarget : (unsigned char*)ov[8])); }
  g_vtSc = sc;
  PatchVtableSlotInPlace(ov, "first-present");
  RestoreInlinePatch();
  { int absent = (memcmp(g_patchTarget, g_patchOrig, g_patchLen) == 0) ? 1 : 0; Log("host: inline patch absent ok=%d target=%p len=%d", absent, (void*)g_patchTarget, g_patchLen); }
}
extern "C" __declspec(dllexport) void R11_UnhookAll(void) {
  int restored = 0;
  for (int i = 0; i < g_patchedVtN; i++) {
    void** vt = g_patchedVts[i]; if (!vt) continue;
    DWORD old = 0;
    if (VirtualProtect(vt, 32 * sizeof(void*), PAGE_READWRITE, &old)) {
      vt[8] = g_patchedOld[i];
      VirtualProtect(vt, 32 * sizeof(void*), old, &old);
      FlushInstructionCache(GetCurrentProcess(), vt, 32 * sizeof(void*));
      restored++;
    }
  }
  Log("host: vt restored count=%d", restored);
  g_patchedVtN = 0; g_vtHooked = false; g_vtSc = NULL; g_vtOrig = NULL; g_vtOldPresent = NULL;
  if (g_patchSaved) RestoreInlinePatch();
}
static HRESULT PresentCore(IDXGISwapChain* sc, UINT sync, UINT flags, Present_fn orig);
static HRESULT STDMETHODCALLTYPE HookPresent(IDXGISwapChain* sc, UINT sync, UINT flags) {
  if (!g_presentTid) g_presentTid = GetCurrentThreadId();
  Present_fn orig = g_origPresent;
  if (!g_inlineHookMode && !g_vtHooked) {
    InstallVtableHook(sc);
    if (g_vtHooked && g_vtOldPresent) orig = (Present_fn)g_vtOldPresent;
  }
  return PresentCore(sc, sync, flags, orig);
}
static HRESULT STDMETHODCALLTYPE HookPresentVt(IDXGISwapChain* sc, UINT sync, UINT flags) {
  if (!g_presentTid) g_presentTid = GetCurrentThreadId();
  if (!g_vtSc) { g_vtSc = sc; Log("host: vtable in-place active sc=%p patched=%d present-tid=%lu", (void*)sc, g_patchedVtN, (unsigned long)g_presentTid); }
  RefreshVtableHook();
  Present_fn orig = g_vtOldPresent ? (Present_fn)g_vtOldPresent : g_origPresent;
  return PresentCore(sc, sync, flags, orig);
}
static HRESULT PresentCore(IDXGISwapChain* sc, UINT sync, UINT flags, Present_fn orig) {
  if (InterlockedCompareExchange(&g_draining, 1, 0) == 0) {
    // v4k stack-safety: 256-entry drain buffer (~12 KB) is static, not on the render stack.
    // The 26884 crash dumped host16!PresentCore+0x2d0 near the epilogue (GS cookie).
    static QOrder s_drain[256];
    int n = 0;
    EnterCriticalSection(&g_qcs);
    n = g_qn; if (n < 0) n = 0; if (n > 256) n = 256;
    if (n) memcpy(s_drain, g_q, (size_t)n * sizeof(QOrder));
    g_qn = 0;
    LeaveCriticalSection(&g_qcs);
    if (g_puo) {
      // PUO verified flag: unverified -> never dispatch
      if (!g_puoVerified && !g_puoUnverifiedLogged) { g_puoUnverifiedLogged = true; RLog("order dispatch disabled: PUO unverified (no call made)"); }
      if (g_drainDisabled) { if (g_puoCalls < 3) RLog("puo drain DISABLED (canary corruption earlier)"); }
      else if (g_skipPuo) { if (g_puoCalls++ < 5) RLog("puo SKIPPED by R11_SKIP_PUO=1 (hook/overlay active)"); }
      else
      for (int i = 0; i < n; i++) {
        QOrder& o = s_drain[i];
        // entities may die between queue and drain; skip stale pointers
        if (!PtrOk(o.player, 0x100) || !PtrOk(o.issuer, 0x100)) continue;
        g_puoArgs.pre = PUO_PRE; g_puoArgs.post = PUO_POST;
        g_puoArgs.pos[0] = o.pos[0]; g_puoArgs.pos[1] = o.pos[1]; g_puoArgs.pos[2] = o.pos[2];
        int okpuo = g_puo(o.player, o.type, o.target, g_puoArgs.pos, o.ability, 3, o.issuer, o.queue != 0, o.show != 0,
                          0ULL, 0ULL, 0ULL, 0ULL) ? 1 : 0;  // AI-14: explicit trailing defaults
        LONG64 c = InterlockedIncrement64(&g_puoCalls);
        if (g_puoArgs.pre != PUO_PRE || g_puoArgs.post != PUO_POST) {
          g_drainDisabled = true; InterlockedIncrement64(&g_puoCanaryBad);
          RLog("puo CANARY CORRUPTED n=%lld pre=%016llX post=%016llX type=%d tgt=%u abil=%u", (long long)c, (unsigned long long)g_puoArgs.pre, (unsigned long long)g_puoArgs.post, o.type, o.target, o.ability);
          break;
        }
        if (c <= 5) RLog("puo call n=%lld ret=%d type=%d tgt=%u abil=%u issuer=%p queue=%d show=%d pos=%.2f %.2f %.2f", (long long)c, okpuo, o.type, o.target, o.ability, o.issuer, (int)o.queue, (int)o.show, g_puoArgs.pos[0], g_puoArgs.pos[1], g_puoArgs.pos[2]);
      }
    }
    InterlockedExchange(&g_draining, 0);
  }
  // In-game D3D overlay. R11_Render saves/restores all game state and draws
  // into the current RTV, so it does not black-screen the swapchain.
  { static int g_patchCheckTick = 0; if (g_patchTarget && ++g_patchCheckTick >= 1000) { g_patchCheckTick = 0; int absent = (memcmp(g_patchTarget, g_patchOrig, g_patchLen) == 0) ? 1 : 0; Log("host: inline patch absent recheck ok=%d target=%p len=%d", absent, (void*)g_patchTarget, g_patchLen); } }
  R11_Render(sc);
  if (!g_resize1Tried) {
    g_resize1Tried = true;
    if (!g_resize1HookCfg) RLog("host: ResizeBuffers1 hook disabled by default (R11_RESIZE1_HOOK=0)");
    else {
      IDXGISwapChain3* sc3 = NULL;
      if (sc && SUCCEEDED(sc->QueryInterface(__uuidof(IDXGISwapChain3), (void**)&sc3)) && sc3) {
        void** vt3 = *(void***)sc3;
        // No guessed slot: verify the SC3 layout by probing GetCurrentBackBufferIndex at
        // the dxgi1_4-derived slot 33; only a value < 8 proves the layout, then
        // ResizeBuffers1 = 33 + 3 = 36.
        typedef UINT (STDMETHODCALLTYPE *GCBBI_fn)(IDXGISwapChain3*);
        UINT curIdx = ((GCBBI_fn)vt3[33])(sc3);
        RLog("host: ResizeBuffers1 probe vtable[33] idx=%u", curIdx);
        if (curIdx < 8) {
          unsigned char* t36 = (unsigned char*)vt3[36];
          RLog("host: hook ResizeBuffers1 slot=36 addr=%p", (void*)t36);
          if (!InstallInlineHook(t36, (void*)&HookResizeBuffers1, (void**)&g_origResizeBuffers1, "ResizeBuffers1"))
            RLog("host: ResizeBuffers1 hook skipped");
        } else RLog("host: ResizeBuffers1 probe unverified - hook skipped");
        sc3->Release();
      } else RLog("host: IDXGISwapChain3 unavailable (resize1 hook skipped)");
    }
  }
  HRESULT hr = orig(sc, sync, flags);
  R11_LogPresent((long long)hr);
  return hr;
}

static void* AllocNear(void* target, size_t size) {
  uintptr_t t = (uintptr_t)target;
  uintptr_t lo = (t > 0x7FFF0000) ? t - 0x7FFF0000 : 0x10000;
  uintptr_t hi = t + 0x7FFF0000;
  for (uintptr_t a = (t & ~0xFFFF); a >= lo; a -= 0x10000) {
    void* p = VirtualAlloc((void*)a, size, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    if (p) return p;
    if (a < 0x10000) break;
  }
  for (uintptr_t a = (t & ~0xFFFF) + 0x10000; a <= hi; a += 0x10000) {
    void* p = VirtualAlloc((void*)a, size, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    if (p) return p;
  }
  return NULL;
}

static void WriteAbsJump(unsigned char* at, void* to) {
  at[0] = 0x48; at[1] = 0xB8;
  *(uintptr_t*)(at + 2) = (uintptr_t)to;
  at[10] = 0xFF; at[11] = 0xE0;
}
static int InstallInlineHook(unsigned char* target, void* hook, void** origOut, const char* name) {
  if (!target || !hook || !origOut) return 0;
  for (int hop = 0; hop < 4 && target[0] == 0xE9; hop++) {
    int rel = *(int*)(target + 1);
    target = target + 5 + rel;
  }
  int len = DecodeHookPrefix(target, 16);
  if (len < 10) {
    Log("host: %s prologue mismatch (%02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X), hook skipped", name ? name : "?", target[0], target[1], target[2], target[3], target[4], target[5], target[6], target[7], target[8], target[9], target[10], target[11], target[12], target[13], target[14], target[15]);
    return 0;
  }
  unsigned char* stub = (unsigned char*)AllocNear(target, 64);
  unsigned char* tramp = (unsigned char*)AllocNear(target, 64);
  if (!stub || !tramp) { Log("host: %s AllocNear failed", name ? name : "?"); return 0; }
  WriteAbsJump(stub, hook);
  memcpy(tramp, target, len);
  WriteAbsJump(tramp + len, (void*)(target + len));
  *origOut = (void*)tramp;
  DWORD old;
  VirtualProtect(target, len, PAGE_EXECUTE_READWRITE, &old);
  target[0] = 0xE9;
  *(int*)(target + 1) = (int)((uintptr_t)stub - (uintptr_t)(target + 5));
  for (int i = 5; i < len; i++) target[i] = 0x90;
  VirtualProtect(target, len, old, &old);
  FlushInstructionCache(GetCurrentProcess(), target, len);
  Log("host: %s hook installed at %p", name ? name : "?", target);
  return 1;
}

static void* FindPuoAddress(void* base) {
  unsigned char* found = NULL;
  static const unsigned char sig[] = { 0x4C,0x89,0x4C,0x24,0x20,0x44,0x89,0x44,0x24,0x18,0x89,0x54,0x24,0x10,
                                       0x48,0x89,0x4C,0x24,0x08,0x55,0x53,0x56,0x57,0x41,0x56 };
  unsigned char* p = (unsigned char*)base;
  MEMORY_BASIC_INFORMATION mbi;
  while (VirtualQuery(p, &mbi, sizeof(mbi))) {
    if ((void*)mbi.AllocationBase != base) break;
    if (mbi.State == MEM_COMMIT && (mbi.Protect & (PAGE_READONLY | PAGE_READWRITE | PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE | PAGE_WRITECOPY))) {
      size_t n = mbi.RegionSize;
      if (n > sizeof(sig)) {
        for (size_t i = 0; i + sizeof(sig) <= n; i++) {
          if (p[i] == sig[0] && memcmp(p + i, sig, sizeof(sig)) == 0) { g_puoMatchCount++; found = p + i; }
        }
        if (g_puoMatchCount > 1) { Log("host: PUO signature AMBIGUOUS matches=%d", g_puoMatchCount); return NULL; }
        if (found) return found;
      }
    }
    p += mbi.RegionSize;
    if ((uintptr_t)p >= (uintptr_t)base + 0x40000000ULL) break;
  }
  return NULL;
}
extern "C" __declspec(dllexport) int InitOrders(void) {
  static bool tried = false;
  if (tried) return (g_patchedVtN > 0 || g_origPresent) ? 1 : 0;
  tried = true;
  Log("host: InitOrders begin");
  EnsureQueueCs();   // v4l: initialize before any early return (v4i path)
  { const char* nh = getenv("R11_NO_HOOKS"); if (nh && atoi(nh)) { g_noHooks = true; Log("host: hooks disabled by env R11_NO_HOOKS=1 (no DXGI/input hooks)"); return 1; } }
  { const char* im = getenv("R11_INLINE_HOOK"); g_inlineHookMode = (im && atoi(im)) ? true : false;
    Log("host: hook mode=%s", g_inlineHookMode ? "inline(legacy)" : "vtable(v4h)"); }
  // an older host module may already own the Present hook; forward into it
  { const char* sp = getenv("R11_SKIP_PUO"); g_skipPuo = (sp && atoi(sp)) ? true : false; Log("host: R11_SKIP_PUO=%d", g_skipPuo ? 1 : 0); }
  HMODULE h6 = GetModuleHandleA("host6.dll");
  if (h6) {
    g_fwdQueue = (FwdQueue_fn)GetProcAddress(h6, "QueueOrder");
    if (g_fwdQueue) { Log("host: forwarding orders to host6 hook"); return 1; }
  }
  EnsureQueueCs();
  HMODULE client = GetModuleHandleA("client.dll");
  if (!client) { Log("host: InitOrders no client.dll"); return 0; }
  { char cp[MAX_PATH] = {0}; GetModuleFileNameA(client, cp, MAX_PATH); auto* pe = (unsigned char*)client; DWORD peOff = *(DWORD*)(pe + 0x3C); DWORD ts = *(DWORD*)(pe + peOff + 8); DWORD imgSize = *(DWORD*)(pe + peOff + 0x50); Log("host: client.dll identity base=%p size=0x%X timestamp=0x%08X path=%s", (void*)client, imgSize, ts, cp); }
  { static const unsigned char puoSig[] = { 0x4C,0x89,0x4C,0x24,0x20,0x44,0x89,0x44,0x24,0x18,0x89,0x54,0x24,0x10,0x48,0x89,0x4C,0x24,0x08,0x55,0x53,0x56,0x57,0x41,0x56 };
    void* puo = FindPuoAddress((void*)client);
    if (puo) { g_puo = (PUO_fn)puo; g_puoVerified = true;
      Log("host: PUO resolved signature addr=%p rva=0x%Ix sig=ok matches=%d", puo, (uintptr_t)puo - (uintptr_t)client, g_puoMatchCount); }
    else { const unsigned char* p = (const unsigned char*)((uintptr_t)client + 0x1B5F9B0);
      if (memcmp(p, puoSig, sizeof(puoSig)) == 0) { g_puo = (PUO_fn)p; g_puoVerified = true;
        Log("host: PUO resolved fallback rva=0x1B5F9B0 sig=ok matches=%d", g_puoMatchCount); }
      else { g_puo = NULL; g_puoVerified = false; g_drainDisabled = true;
        Log("host: PUO unresolved - order dispatch disabled (matches=%d, sig mismatch at 0x1B5F9B0)", g_puoMatchCount); } } }
  Log("host: audit hardcoded client-rvas count=2 PUO=0x1B5F860(sig 0x1B5F9B0) viewmatrix=0x6221CB0 client=%p", (void*)client);
  { const void* vmp = (const void*)((uintptr_t)client + 0x6221CB0); MEMORY_BASIC_INFORMATION vmbi;
    if (VirtualQuery(vmp, &vmbi, sizeof(vmbi)) && vmbi.State == MEM_COMMIT) { const float* vm = (const float*)vmp; float f0 = vm[0], f1 = vm[1];
      int ok = (f0 == f0 && f1 == f1 && f0 < 1e6f && f0 > -1e6f) ? 1 : 0;
      Log("host: resolved viewmatrix rva=0x6221CB0 first=%.3f %.3f ok=%d", f0, f1, ok); }
    else Log("host: resolved viewmatrix rva=0x6221CB0 unreadable ok=0"); }
  // learn Present address from a throwaway swapchain
  DXGI_SWAP_CHAIN_DESC sd = {};
  sd.BufferCount = 1;
  sd.BufferDesc.Width = 64; sd.BufferDesc.Height = 64;
  sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
  sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
  sd.OutputWindow = GetDesktopWindow();
  sd.Windowed = TRUE;
  sd.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
  sd.SampleDesc.Count = 1;
  IDXGISwapChain* sc = NULL; ID3D11Device* dev = NULL; ID3D11DeviceContext* ctx = NULL;
  D3D_FEATURE_LEVEL fl;
  // WARP: a hardware device here can deadlock DXGI against the game's
  // fullscreen swapchain; we only need dxgi's Present address.
  HRESULT hr = D3D11CreateDeviceAndSwapChain(NULL, D3D_DRIVER_TYPE_WARP, NULL, 0, NULL, 0,
      D3D11_SDK_VERSION, &sd, &sc, &dev, &fl, &ctx);
  if (FAILED(hr) || !sc) { Log("host: dummy swapchain failed hr=%08lX", hr); return 0; }
  void** vt = *(void***)sc;
  if (!g_inlineHookMode) {
    // v4n in-place mode: NO temporary inline capture at all. The shared dxgi/Steam
    // vtable slot 8 is patched in place here; the first HookPresentVt call records
    // g_vtSc/g_presentTid. No code bytes are patched in this mode.
    PatchVtableSlotInPlace((void**)vt, "dummy-shared");
    sc->Release(); if (dev) dev->Release(); if (ctx) ctx->Release();
    Log("host: in-place mode - shared vtable patched at init, no temp inline capture (patched=%d)", g_patchedVtN);
    if (g_stageTrace) { FILE* sf = fopen("D:\\hake\\lotus\\r11_stages.log", "a"); if (sf) { fprintf(sf, "%llu f=0 tid=%d mask=0 stage=init line=host16-init patched=%d\n", (unsigned long long)GetTickCount64(), (int)GetCurrentThreadId(), g_patchedVtN); fflush(sf); fclose(sf); Log("host: r11_stages.log init marker written"); } else Log("host: r11_stages.log open failed"); }
    return 1;
  }
  // legacy inline mode (R11_INLINE_HOOK=1) below - not used by the in-place window
  unsigned char* target = (unsigned char*)vt[8];
  typedef HRESULT (STDMETHODCALLTYPE *GetDesc_fn)(IDXGISwapChain*, DXGI_SWAP_CHAIN_DESC*);
  int descSlot = -1;
  DXGI_SWAP_CHAIN_DESC pd = {};
  if (SUCCEEDED(((GetDesc_fn)vt[12])(sc, &pd)) &&
      pd.BufferDesc.Width == sd.BufferDesc.Width && pd.BufferDesc.Height == sd.BufferDesc.Height &&
      pd.BufferDesc.Format == sd.BufferDesc.Format && pd.BufferCount == sd.BufferCount) descSlot = 12;
  int resizeSlot = (descSlot == 12) ? 13 : -1;
  Log("host: swapchain vtable probe getDescSlot=%d resizeSlot=%d", descSlot, resizeSlot);
  unsigned char* resizeTarget = (resizeSlot >= 0) ? (unsigned char*)vt[resizeSlot] : NULL;
  for (int hop = 0; hop < 4 && target[0] == 0xE9; hop++) { target = target + 5 + *(int*)(target + 1); }
  int len = DecodeHookPrefix(target, 16);
  if (len < 10) { Log("host: legacy Present prologue mismatch, hook skipped"); return 0; }
  unsigned char* stub = (unsigned char*)AllocNear(target, 64);
  unsigned char* tramp = (unsigned char*)AllocNear(target, 64);
  if (!stub || !tramp) { Log("host: AllocNear failed"); return 0; }
  WriteAbsJump(stub, (void*)&HookPresent);
  memcpy(tramp, target, len); WriteAbsJump(tramp + len, (void*)(target + len));
  g_origPresent = (Present_fn)tramp;
  memcpy(g_patchOrig, target, len); g_patchTarget = target; g_patchLen = len; g_patchSaved = true;
  DWORD old; VirtualProtect(target, len, PAGE_EXECUTE_READWRITE, &old);
  target[0] = 0xE9; *(int*)(target + 1) = (int)((uintptr_t)stub - (uintptr_t)(target + 5));
  for (int i = 5; i < len; i++) target[i] = 0x90;
  VirtualProtect(target, len, old, &old); FlushInstructionCache(GetCurrentProcess(), target, len);
  Log("host: legacy Present hook installed at %p", target);
  if (resizeTarget) InstallInlineHook(resizeTarget, (void*)&HookResizeBuffers, (void**)&g_origResizeBuffers, "ResizeBuffers");
  return 1;
  return 1;
}

// ---- overlay input: native WndProc + event queue (stable across Lua states)
struct InEvt { unsigned int msg; unsigned long long wp; long long lp; };
static CRITICAL_SECTION g_ics;
static bool g_icsInit = false;
static InEvt g_in[512];
static int g_inn = 0;

extern "C" __declspec(dllexport) long long STDMETHODCALLTYPE OverlayWndProc(
    void* h, unsigned int msg, unsigned long long wp, long long lp) {
  if (msg == 0x0201 || msg == 0x0200 || msg == 0x0202 || msg == 0x0100) {
    if (!g_icsInit) { InitializeCriticalSection(&g_ics); g_icsInit = true; }
    EnterCriticalSection(&g_ics);
    if (g_inn < 512) { g_in[g_inn].msg = msg; g_in[g_inn].wp = wp; g_in[g_inn].lp = lp; g_inn++; }
    LeaveCriticalSection(&g_ics);
    if (msg != 0x0200) return 0;
  }
  return (long long)DefWindowProcA((HWND)h, msg, (WPARAM)wp, (LPARAM)lp);
}

extern "C" __declspec(dllexport) int DrainInput(unsigned int* msgs, unsigned long long* wps, long long* lps, int max) {
  if (!g_icsInit) return 0;
  EnterCriticalSection(&g_ics);
  int n = g_inn < max ? g_inn : max;
  for (int i = 0; i < n; i++) { msgs[i] = g_in[i].msg; wps[i] = g_in[i].wp; lps[i] = g_in[i].lp; }
  if (n == g_inn) g_inn = 0;
  else { memmove(g_in, g_in + n, (g_inn - n) * sizeof(InEvt)); g_inn -= n; }
  LeaveCriticalSection(&g_ics);
  return n;
}

// ---- global input hooks for the ClickGUI (never steal Dota's focus) --------
// (g_menuOpen is declared near the top, before render11.cpp, so the renderer
//  setter can mirror it: Del/Esc symmetry.)
static bool g_uiInit = false;

static bool DotaForeground() {
  HWND fg = GetForegroundWindow();
  if (!fg) return false;
  DWORD pid = 0;
  GetWindowThreadProcessId(fg, &pid);
  return pid == GetCurrentProcessId();
}

static void PushIn(unsigned int msg, unsigned long long wp, long long lp) {
  if (!g_icsInit) { InitializeCriticalSection(&g_ics); g_icsInit = true; }
  EnterCriticalSection(&g_ics);
  if (g_inn < 512) { g_in[g_inn].msg = msg; g_in[g_inn].wp = wp; g_in[g_inn].lp = lp; g_inn++; }
  LeaveCriticalSection(&g_ics);
}

static LRESULT CALLBACK UiMouseHook(int code, WPARAM wp, LPARAM lp) {
  if (code >= 0 && R11_IsMenuOpen()) {
    MSLLHOOKSTRUCT* m = (MSLLHOOKSTRUCT*)lp;
    // Only intercept clicks INSIDE the Dota window; outside, pass through so
    // the user can still click other apps / change focus while the menu is open.
    HWND dw = DotaMainWindow();
    RECT wr;
    bool inside = dw && GetWindowRect(dw, &wr) &&
      m->pt.x >= wr.left && m->pt.x < wr.right && m->pt.y >= wr.top && m->pt.y < wr.bottom;
    if (inside) {
      float lx = 0, ly = 0;
      R11_ToLocal((float)m->pt.x, (float)m->pt.y, &lx, &ly);
      long long packed = (long long)MAKELPARAM((int)lx, (int)ly);
      if (wp == WM_MOUSEMOVE) { PushIn(0x0200, 0, packed); }
      else if (wp == WM_LBUTTONDOWN || wp == WM_LBUTTONUP) {
        // Post-game/menu-leave fix: swallow ONLY clicks that actually land on
        // the ClickGUI (widget hit box or menu panel). Clicks elsewhere in the
        // window — e.g. the post-game ИГРАТЬ / close buttons — are passed to
        // the game even if a menu-open flag is somehow still set.
        int onGui = R11_HitTestScreen((float)m->pt.x, (float)m->pt.y);
        if (onGui) {
          PushIn(wp == WM_LBUTTONDOWN ? 0x0201 : 0x0202, 0, packed);
          static ULONGLONG lastLog = 0; static int logged = 0;
          ULONGLONG now = GetTickCount64();
          if (logged < 10 || now - lastLog > 2000) {
            lastLog = now; logged++;
            RLog("gui: hook swallow click %d,%d (onGui=1)", (int)m->pt.x, (int)m->pt.y);
          }
          return 1;
        }
      }
    }
  }
  return CallNextHookEx(NULL, code, wp, lp);
}

static LRESULT CALLBACK UiKeyHook(int code, WPARAM wp, LPARAM lp) {
  if (code >= 0 && (wp == WM_KEYDOWN || wp == WM_SYSKEYDOWN)) {
    KBDLLHOOKSTRUCT* k = (KBDLLHOOKSTRUCT*)lp;
    if (k->vkCode == VK_DELETE || k->vkCode == VK_INSERT) {
      // INSERT = Umbrella-default menu key (parity); DELETE kept for backward compat.
      // single source of truth = renderer flag: Del/Ins and Esc (which calls
      // R11_SetMenuOpen(0) via hostlib.SetMenuOpen) stay symmetric
      LONG v = R11_IsMenuOpen() ? 0 : 1;
      InterlockedExchange(&g_menuOpen, v);
      R11_SetMenuOpen(v);
      RLog("Del toggle -> %d", (int)v);
      return 1;
    }
    if (R11_IsMenuOpen() && DotaForeground()) {
      PushIn(0x0100, k->vkCode, 0);
      return 1;
    }
  }
  return CallNextHookEx(NULL, code, wp, lp);
}

static DWORD WINAPI UiThread(LPVOID) {
  HHOOK mh = NULL, kh = NULL;
  { const char* nh = getenv("R11_NO_HOOKS");
    if (nh && atoi(nh)) RLog("UiThread hooks disabled by env R11_NO_HOOKS=1");
    else {
      mh = SetWindowsHookExA(WH_MOUSE_LL, UiMouseHook, GetModuleHandleA(NULL), 0);
      kh = SetWindowsHookExA(WH_KEYBOARD_LL, UiKeyHook, GetModuleHandleA(NULL), 0);
      RLog("UiThread hooks mouse=%p key=%p", (void*)mh, (void*)kh);
    } }
  MSG msg;
  while (GetMessageA(&msg, NULL, 0, 0)) { TranslateMessage(&msg); DispatchMessageA(&msg); }
  return 0;
}

extern "C" __declspec(dllexport) int InitUI(void) {
  if (g_uiInit) return 1;
  g_uiInit = true;
  CreateThread(NULL, 0, UiThread, NULL, 0, NULL);
  RLog("InitUI thread created");
  return 1;
}
extern "C" __declspec(dllexport) int IsMenuOpen(void) { return g_menuOpen ? 1 : 0; }
// keep the hook flag and the renderer flag in lockstep from every caller
extern "C" __declspec(dllexport) void SetMenuOpen(int v) {
  InterlockedExchange(&g_menuOpen, v ? 1 : 0);
  R11_SetMenuOpen(v);
}

// ---- per-frame world markers on a DEDICATED thread (not the render thread,
// so no DWM/Present conflict). GDI layered window, reads fresh hero + matrix.
static CRITICAL_SECTION g_mkcs; static bool g_mkcsInit = false;
static void* g_mkHero = NULL; static float g_mkGoal[3]; static int g_mkHas = 0;
static HWND g_mkWnd = NULL; static HDC g_mkDc = NULL; static HBITMAP g_mkBmp = NULL;
static HGDIOBJ g_mkOld = NULL; static int g_mkW = 0, g_mkH = 0;
static bool g_mkThread = false;

extern "C" __declspec(dllexport) void MarkerSet(void* hero, float x, float y, float z, int has) {
  if (!g_mkcsInit) { InitializeCriticalSection(&g_mkcs); g_mkcsInit = true; }
  EnterCriticalSection(&g_mkcs);
  g_mkHero = hero; g_mkGoal[0] = x; g_mkGoal[1] = y; g_mkGoal[2] = z; g_mkHas = has;
  LeaveCriticalSection(&g_mkcs);
}

static bool MkPtrOk(void* p, size_t n) {
  if (!p) return false;
  MEMORY_BASIC_INFORMATION mbi;
  if (!VirtualQuery(p, &mbi, sizeof(mbi))) return false;
  if (mbi.State != MEM_COMMIT) return false;
  DWORD pr = mbi.Protect & 0xFF;
  if (!(pr == PAGE_READONLY || pr == PAGE_READWRITE || pr == PAGE_EXECUTE_READ || pr == PAGE_EXECUTE_READWRITE || pr == PAGE_WRITECOPY)) return false;
  return ((uintptr_t)p + n) <= ((uintptr_t)mbi.BaseAddress + mbi.RegionSize);
}

static void MkRender() {
  if (!g_mkcsInit) return;
  EnterCriticalSection(&g_mkcs);
  void* hero = g_mkHero; float gx = g_mkGoal[0], gy = g_mkGoal[1], gz = g_mkGoal[2]; int has = g_mkHas;
  LeaveCriticalSection(&g_mkcs);
  HWND dota = DotaMainWindow(); // own-process window; FindWindowA("SDL_app") hits Steam's hidden windows
  bool show = !(dota && IsIconic(dota));
  if (!show) { if (g_mkWnd) ShowWindow(g_mkWnd, 0); return; }
  int sw = GetSystemMetrics(0), sh = GetSystemMetrics(1);
  if (sw < 100) { sw = 1920; sh = 1080; }
  if (!g_mkWnd) {
    WNDCLASSEXA wc = {}; wc.cbSize = sizeof(wc); wc.lpfnWndProc = DefWindowProcA;
    wc.hInstance = GetModuleHandleA(NULL); wc.lpszClassName = "LotusMarkers";
    RegisterClassExA(&wc);
    g_mkWnd = CreateWindowExA(0x00080000 | 0x00000020 | 0x00000008 | 0x00000080 | 0x08000000,
        "LotusMarkers", "M", 0x80000000, 0, 0, sw, sh, NULL, NULL, wc.hInstance, NULL);
    if (!g_mkWnd) return;
    ShowWindow(g_mkWnd, 8);
  }
  if (!g_mkDc || g_mkW != sw || g_mkH != sh) {
    if (g_mkDc) { SelectObject(g_mkDc, g_mkOld); DeleteObject(g_mkBmp); DeleteDC(g_mkDc); g_mkDc = NULL; }
    HDC scr = GetDC(NULL); g_mkDc = CreateCompatibleDC(scr);
    BITMAPINFO bmi = {}; bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = sw; bmi.bmiHeader.biHeight = -sh; bmi.bmiHeader.biPlanes = 1; bmi.bmiHeader.biBitCount = 32;
    void* bits = NULL; g_mkBmp = CreateDIBSection(scr, &bmi, DIB_RGB_COLORS, &bits, NULL, 0);
    g_mkOld = SelectObject(g_mkDc, g_mkBmp); ReleaseDC(NULL, scr);
    g_mkW = sw; g_mkH = sh;
    SetWindowPos(g_mkWnd, HWND_TOPMOST, 0, 0, sw, sh, 0x0040);
  }
  HBRUSH kb = CreateSolidBrush(0x00FF00FF); RECT rc = { 0, 0, sw, sh };
  FillRect(g_mkDc, &rc, kb); DeleteObject(kb);
  if (hero && MkPtrOk(hero, 0x400)) {
    HMODULE client = GetModuleHandleA("client.dll");
    if (client) {
      uintptr_t node = *(uintptr_t*)((uintptr_t)hero + 0x330);
      if (node && MkPtrOk((void*)node, 0xE0)) {
        float* org = (float*)(node + 0xD8);
        const float* m = (const float*)((uintptr_t)client + 0x6221CB0);
        auto proj = [&](float x, float y, float z, float& sx, float& sy) -> bool {
          float w = m[12]*x + m[13]*y + m[14]*z + m[15];
          if (w < 0.001f) return false;
          sx = (m[0]*x + m[1]*y + m[2]*z + m[3]) / w;
          sy = (m[4]*x + m[5]*y + m[6]*z + m[7]) / w;
          return sx > -1.35f && sx < 1.35f && sy > -1.35f && sy < 1.35f;
        };
        float ax, ay, bx, by;
        if (proj(org[0], org[1], org[2], ax, ay)) {
          int x1 = (int)(sw * 0.5f * (1 + ax)), y1 = (int)(sh * 0.5f * (1 - ay));
          if (has && proj(gx, gy, gz, bx, by)) {
            int x2 = (int)(sw * 0.5f * (1 + bx)), y2 = (int)(sh * 0.5f * (1 - by));
            HPEN pen = CreatePen(PS_SOLID, 2, 0x00FFA500);
            HGDIOBJ op = SelectObject(g_mkDc, pen);
            MoveToEx(g_mkDc, x1, y1, NULL); LineTo(g_mkDc, x2, y2);
            SelectObject(g_mkDc, op); DeleteObject(pen);
            HBRUSH gb = CreateSolidBrush(0x00FFA500); HGDIOBJ ob = SelectObject(g_mkDc, gb);
            Ellipse(g_mkDc, x2 - 4, y2 - 4, x2 + 4, y2 + 4);
            SelectObject(g_mkDc, ob); DeleteObject(gb);
          }
        }
      }
    }
  }
  POINT dst = { 0, 0 }, src = { 0, 0 }; SIZE sz = { sw, sh };
  UpdateLayeredWindow(g_mkWnd, NULL, &dst, &sz, g_mkDc, &src, 0x00FF00FF, NULL, 1);
  if (g_mkWnd) ShowWindow(g_mkWnd, 8);
}

static DWORD WINAPI MarkerThread(LPVOID) {
  while (true) { Sleep(33); MkRender(); }
  return 0;
}
extern "C" __declspec(dllexport) int InitMarkers(void) {
  if (g_mkThread) return 1;
  g_mkThread = true;
  CreateThread(NULL, 0, MarkerThread, NULL, 0, NULL);
  return 1;
}

BOOL WINAPI DllMain(HINSTANCE h, DWORD reason, LPVOID) {
  if (reason == DLL_PROCESS_ATTACH) {
    DisableThreadLibraryCalls(h);
    CreateThread(NULL, 0, HostThread, NULL, 0, NULL);
  }
  return TRUE;
}

extern "C" __declspec(dllexport) DWORD WINAPI RunHost(LPVOID) {
  char scriptPath[MAX_PATH];
  if (ReadRunPath(scriptPath, sizeof(scriptPath))) { RunScript(scriptPath); return 0; }
  return 1;
}












