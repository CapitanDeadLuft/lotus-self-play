// Temporary metrics probe: GDI font metrics + ink boxes for the text renderer.
#include <windows.h>
#include <cstdio>
#include <cstring>
#include <cmath>

static void Probe(const char* face, int height, int weight) {
  HDC scr = GetDC(NULL);
  HDC dc = CreateCompatibleDC(scr);
  BITMAPINFO bmi = {};
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  int W = 1024, H = 1024;
  bmi.bmiHeader.biWidth = W; bmi.bmiHeader.biHeight = -H;
  bmi.bmiHeader.biPlanes = 1; bmi.bmiHeader.biBitCount = 32;
  void* bits = NULL;
  HBITMAP dib = CreateDIBSection(scr, &bmi, DIB_RGB_COLORS, &bits, NULL, 0);
  HGDIOBJ old = SelectObject(dc, dib);
  memset(bits, 0, (size_t)W * H * 4);
  SetBkMode(dc, TRANSPARENT);
  SetTextColor(dc, 0xFFFFFF);
  HFONT f = CreateFontA(-height, 0, 0, 0, weight, 0, 0, 0, DEFAULT_CHARSET, 0, 0, ANTIALIASED_QUALITY, 0, face);
  HGDIOBJ of = SelectObject(dc, f);
  char got[64] = {0};
  GetTextFaceA(dc, sizeof(got), got);
  TEXTMETRICA tm = {};
  GetTextMetricsA(dc, &tm);
  printf("face=%s req=%s height=%d weight=%d => tmHeight=%ld tmAscent=%ld tmDescent=%ld tmIntLead=%ld tmExtLead=%ld tmAveChar=%ld tmMaxChar=%ld\n",
         got, face, height, weight, tm.tmHeight, tm.tmAscent, tm.tmDescent, tm.tmInternalLeading,
         tm.tmExternalLeading, tm.tmAveCharWidth, tm.tmMaxCharWidth);
  // ink box for sample glyphs, drawn at cell (x=10,y=10)
  const char* samples = "MygWpA_|jQ";
  for (const char* s = samples; *s; s++) {
    memset(bits, 0, (size_t)W * 64 * 4);
    TextOutA(dc, 10, 10, s, 1);
    int x0 = 999, y0 = 999, x1 = -1, y1 = -1;
    unsigned char* p = (unsigned char*)bits;
    for (int y = 0; y < 64; y++) for (int x = 0; x < 80; x++) {
      unsigned char a = p[(y * W + x) * 4 + 3];
      if (a > 8) { if (x < x0) x0 = x; if (y < y0) y0 = y; if (x > x1) x1 = x; if (y > y1) y1 = y; }
    }
    printf("  '%c' ink box rel to TextOut origin: x=%d..%d y=%d..%d (h=%d)\n", *s,
           x0 - 10, x1 - 10, y0 - 10, y1 - 10, (y1 >= 0 ? (y1 - y0 + 1) : 0));
  }
  // advances at this size
  printf("  adv: ");
  for (const char* s = "MWmy g."; *s; s++) {
    ABC abc;
    int adv = -1;
    if (GetCharABCWidthsA(dc, (UINT)(unsigned char)*s, (UINT)(unsigned char)*s, &abc))
      adv = abc.abcA + abc.abcB + abc.abcC;
    printf("'%c'=%d ", *s, adv);
  }
  printf("\n");
  SelectObject(dc, of);
  DeleteObject(f);
  SelectObject(dc, old);
  DeleteObject(dib);
  DeleteDC(dc);
  ReleaseDC(NULL, scr);
}

int main() {
  int sizes[] = {9, 10, 11, 12, 13, 14, 15, 16, 20, 24, 28, 32, 40};
  for (int i = 0; i < (int)(sizeof(sizes) / sizeof(sizes[0])); i++) {
    Probe("Bahnschrift", sizes[i], 400);
    Probe("Bahnschrift", sizes[i], 700);
  }
  return 0;
}