// Temporary: measure text widths for candidate fonts/sizes vs reference screenshot.
#include <windows.h>
#include <cstdio>
#include <cstring>

static int Width(HDC dc, const char* s) {
  SIZE sz = {0, 0};
  GetTextExtentPoint32A(dc, s, (int)strlen(s), &sz);
  return sz.cx;
}
static void Measure(const char* face, int weight, int px, const char* s) {
  HDC scr = GetDC(NULL);
  HDC dc = CreateCompatibleDC(scr);
  HFONT f = CreateFontA(-px, 0, 0, 0, weight, 0, 0, 0, DEFAULT_CHARSET, 0, 0, ANTIALIASED_QUALITY, 0, face);
  HGDIOBJ of = SelectObject(dc, f);
  TEXTMETRICA tm = {};
  GetTextMetricsA(dc, &tm);
  int w = Width(dc, s);
  // ink box via a DIB
  BITMAPINFO bmi = {};
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = 512; bmi.bmiHeader.biHeight = -64;
  bmi.bmiHeader.biPlanes = 1; bmi.bmiHeader.biBitCount = 32;
  void* bits = NULL;
  HBITMAP dib = CreateDIBSection(scr, &bmi, DIB_RGB_COLORS, &bits, NULL, 0);
  HGDIOBJ od = SelectObject(dc, dib);
  memset(bits, 0, 512 * 64 * 4);
  SetBkMode(dc, TRANSPARENT); SetTextColor(dc, 0xFFFFFF);
  TextOutA(dc, 8, 8, s, (int)strlen(s));
  int y0 = 999, y1 = -1;
  unsigned char* p = (unsigned char*)bits;
  for (int y = 0; y < 64; y++) for (int x = 0; x < 512; x++) {
    unsigned char v = p[(y * 512 + x) * 4 + 2]; // red channel
    if (v > 24) { if (y < y0) y0 = y; if (y > y1) y1 = y; }
  }
  printf("%-12s w=%d px=%2d adv=%3d inkRows=%2d..%2d h=%2d ascent=%ld height=%ld\n",
         face, weight, px, w, y0 - 8, y1 - 8, y1 - y0 + 1, tm.tmAscent, tm.tmHeight);
  SelectObject(dc, od); DeleteObject(dib);
  SelectObject(dc, of); DeleteObject(f);
  DeleteDC(dc); ReleaseDC(NULL, scr);
}
int main() {
  const char* text = "Turn the bot on";
  int sizes[] = {12, 13, 14, 15};
  const char* faces[] = {"Segoe UI", "Bahnschrift", "Tahoma", "Verdana", "Arial"};
  int weights[] = {400, 600, 700};
  for (int f = 0; f < 5; f++)
    for (int wi = 0; wi < 3; wi++)
      for (int si = 0; si < 4; si++)
        Measure(faces[f], weights[wi], sizes[si], text);
  return 0;
}