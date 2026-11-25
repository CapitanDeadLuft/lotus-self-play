# ROLLBACK PREP — v4g (B5928291…) → baseline 422751ED (staged; execute ONLY on Lead go)

State at freeze: runtime DOWN (no dota2). Active on disk: `src\host16.dll` = **v4g** 779,264 B md5 **B5928291C1A0A66AB8124620525D1F5D** (was the v4g window build). Next live session should start from rollback baseline **422751ED** (or agreed baseline) per reviewer/Lead.

## Pre-verified assets (QA read-only, 20:22)
- Target rollback: `src\host16.dll.bak_20261116_205629` = **185,344 B md5 422751ED3DABB466564B1A6F4E0EAC35** (long-stable, lobby-safe only — in-match crashes).
- Also present: `host16.dll.old_20261116_210003` (same 422751ED hash), `host16.dll.bak_20261117_174938` + `old_20261117_174950` (1AB3D773, 185,856 B), `host16.dll.v3_20261117_180924` (v3), arch s.
- v4g remaining on disk: active `host16.dll` (B5928291), `host16_new_v4g.dll` (B5928291), PDB/MAP.
- `host.log` frozen 27,511,245 B @20:05:37; stages log 4,895,161 B @20:05:37 (v4g final, mask=0 hook-only stream).
- Dumps retained: `dota2.exe.4232.dmp` 6.59 GiB, `dota2.exe.25052.dmp` 6.71 GiB, `dota2.exe.25604.dmp` 6.92 GiB, `dota2.exe.8856.dmp` 6.98 GiB.

## One-action rollback (when Lead says go; runtime must be down)
```
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
Move-Item -Force 'D:\hake\lotus\src\host16.dll' "D:\hake\lotus\src\host16.dll.v4g_$ts"          # archive v4g active copy
Copy-Item -Force 'D:\hake\lotus\src\host16.dll.bak_20261116_205629' 'D:\hake\lotus\src\host16.dll'  # restore baseline
$md5 = (Get-FileHash 'D:\hake\lotus\src\host16.dll' -Algorithm MD5).Hash
if ($md5 -ne '422751ED3DABB466564B1A6F4E0EAC35') { throw "ROLLBACK VERIFY FAILED: $md5" }
Add-Content 'D:\hake\lotus\src\host16.dll.md5.txt' ("[$(Get-Date -Format 'yyyyMMdd_HHmmss')] QA rollback v4g->422751ED active=$md5 size=$((Get-Item 'D:\hake\lotus\src\host16.dll').Length) archived=v4g_$ts")
```
Verify afterwards: active md5 **422751ED3DABB466564B1A6F4E0EAC35**, size 185,344; record line appended; no dota2 process; do **not** launch/inject until Lead go.

## Notes
- `host16.dll.md5.txt` already has v4g activation + provenance records; append QA rollback line rather than rewriting.
- Keep v4g artifact/PDB/MAP + dumps for developer analysis; disk free ample (≥420 GB) but dumps total ~27 GiB.
- After rollback, if Lead wants a live baseline session: relaunch/inject baseline only (lobby-safe, NO in-match per D14c); no crash soaking on baseline.