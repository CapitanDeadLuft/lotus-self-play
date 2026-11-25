# v4e RUN — A1-repeat (mask 7, Steam overlay ENABLED, restoreRt1=0) — pid 9492

Label per PM: **v4e A1-repeat** (NOT A0/A1b/A1c). Lead moved without published order; QA captures as-is, no injection/kill, mask stays 7 unless Lead says "A1c go".

## Artifact & attribution
- Active `src\host16.dll` **776,704 B md5 D4A6B522D902CCF8A7080422376197F1** (v4e).
- Source **at build** (pinned from `src\host16.dll.md5.txt` `[20261117_193433] Lead window v4e`): `render11.cpp` **56,079 B md5 A010A8676049A7B2C9AE57B779B2C6AA**; `host.cpp` **29,337 B md5 B1B7D4A1447E21608B4C2A4C70D244C7**.
- **DRIFT CAVEAT:** on-disk `render11.cpp` is now **56,541 B @19:36:48** ≠ build source 56,079/A010A867 → this run's evidence is attributed to **artifact md5 D4A6B522 only**; do NOT attribute the newer on-disk edits.
- Rollback available: 422751ED; v4c archived `host16.dll.v4c_20261117_193433`.

## Injection/init (line-index)
- `L485048 [19:36:20.355] host: watchdog thread start pid=9492`; loop running (lobby, nil hero).
- `L485155 [19:36:22.538] swapchain vtable probe getDescSlot=12 resizeSlot=13`
- `L485156 Present hook installed at 00007FF85424C130`
- `L485157 hook ResizeBuffers slot=13 addr=00007FF89D922810` → **`L485158 ResizeBuffers prologue mismatch, hook skipped`**
- `L485223 [19:36:22] R11: statecard rtvN=8 vpN=1 scN=1 dev=0000015E6A21DF58 ctx=0000015E6B66E0F0 atlas=0000015F285303C0`
- `L485225 [19:36:22] R11: host: hook ResizeBuffers1 slot=36 addr=00007FF89D968B50` → **`L485226 ResizeBuffers1 prologue mismatch, hook skipped`**
- `L485231 [19:36:22] R11: view matrix sane again -> world draws resumed`
- `L485179 [19:36:22] R11: modules host16 base=00007FF83AF80000 path=D:\hake\lotus\src\host16.dll md5=D4A6B522D902CCF8A7080422376197F1`
- `L485180 [19:36:22] R11: modules gameoverlayrenderer64.dll … version=11.23.65.88` (**overlay renderer LOADED** — A1-repeat, not A0)
- `L485181 gameoverlayui64.dll NOT LOADED` (in-process); `L485182 GameBar.dll NOT LOADED`
- `L485184 nvwgf2umx.dll version=32.0.15.9159`; `L485185 d3d11.dll 10.0.19041.5794`; `L485186 dxgi.dll 10.0.19041.5794`; `L485187 nvngx.dll NOT LOADED`
- `L485188 [19:36:22] R11: modules drawmode mask=7 guard=0 cachedRtv=0 mtProtect=1 stageTrace=1 restoreRt1=0`
- `L485190 [19:36:22] R11: multithread protected already=0 now=1`
- First present: `[19:36:22] R11: present tid=25736 hr=0x00000000 devRemoved=0x00000000 f=1 mask=7 mt=1`; frame `hud=0 menu=0 open=0 est=0 verts=0 cap=0 vbB=0 drew=0 mapOk=0`.
- Later resize event: `L490371 [19:39:46] R11: bb change 1920x1080 fmt=28 samples=1 hwnd=… client=958x1039 (prev 1920x1080 fmt=28) sinceLastMs=125` — window/client resized mid-run (record; possible G-like condition).

## State now (19:39:22-19:39:50)
- pid 9492 responding; loop lobby `loop 4198 0.0s nil hp=- 0 0 gt=-1.0`; `present tid=25736 hr=0 devRemoved=0 f=9929 mask=7 mt=1`.
- Fresh `r11_stages.log` growing (6,795,841 B @19:39:22).
- **No new Windows Application 1000/1001** (latest remains A1 crash 19:16:47/19:16:50).

## RUN END — 19:44:52 (pid 9492 ended; no crash event, no horn)
- Last observed: `present tid=25736 hr=0x00000000 devRemoved=0x00000000 f=25172 mask=7 mt=1`; loop `11853`; lobby (nil hero, hud/menu/verts all 0) for the whole run (~8.5 min soak). **No match/horn started; no Windows 1000/1001; pid ended ~19:44:52** (replaced by new Dota pid 11996 at 19:44:59).
- **Verdict: v4e A1-repeat ended without crash, no horn (lobby soak only)** — no diagnostic value for the crash gate; hook-skip lines and module evidence retained above.
- `r11_stages.log` archived (18.3 MB) → **`qa_task26/r11_stages_v4e_a1repeat_194452.log`**.

## Pending capture (fill at horn/crash/end)
- [x] horn line(s) — N/A (no horn)
- [x] 2+ horns — N/A
- [x] Windows 1000/1001 re-check — none
- [x] archive stages log at run end — done (path above)
- [x] screenshots — none taken after freeze (Dota never entered match)
- **Verdict: ended without crash, no horn, lobby soak; evidence = module list, hook-skip lines, MT line, present stream; not gate evidence.**