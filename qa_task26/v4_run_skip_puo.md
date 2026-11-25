# `R11_SKIP_PUO=1` CONTROL RUN (staged; execute only if default window recurs — Lead order)

Purpose: isolate the engine wild-deref path. v4k crash was `tier0!CKeyValues_Data::Internal_GetName` AV (`rcx=0x020b2712` wild) with **no host16 frame** but **r14 = patched swapchain ptr**, right at horn. If a default window recurs, run this control to determine whether **engine `PrepareUnitOrders` execution** (our PUO call into engine with position/order args) is the corruption source.

## ENV (set BEFORE Steam/Dota launch; inherited at CreateProcess)
```
$env:R11_SKIP_PUO = 1
# plus the window's normal mask/env (e.g. R11_DRAW_MASK=7, R11_CACHED_RTV=0) — do NOT set R11_NO_HOOKS
```
No other overrides; stage trace ON; MT protect default.

## Expected evidence
- [ ] explicit skip line (exact wording from dev spec; expect `PUO skipped (R11_SKIP_PUO=1)` / `skip PUO` per order or aggregate) — capture verbatim
- [ ] **zero engine PUO calls**: no `[order] PUO type=…` execution lines, no `PrepareUnitOrders` results; Lua still runs (`loop N … npc_dota_hero_treant`, script lines)
- [ ] standard window evidence: `hook mode=…`, `hook target=…`, vtable patched/restore/absence lines, `modules host16 md5=…`, `modules drawmode …`, `multithread protected …`
- [ ] in-match mask-7 stages `drew=1 mapOk=1`; `present hr=0x…`; HUD visible; Steam overlay functional
- [ ] **2+ horns + 15-min soak**; horn timestamps + ±2 s transition logs (see `v4_capture_additions.md`)
- [ ] Windows 1000/1001; dump path if crash (matching PDB); retain all until review

## Verdict logic
- **Skip-PUO survives 2+ horns/soak** where default window crashed ⇒ engine PUO call path implicated (wild deref in engine order processing) → product fix around PUO argument/engine-state contract.
- **Skip-PUO crashes same way** ⇒ PUO not the cause; corruption from draw/vtable/hook interaction or engine transition itself → continue architecture path.
- Any anomaly/crash ⇒ invalidate run per rule, retain dump/logs, report Lead+reviewer+pm.

## Invalidation
- Skip line missing or engine PUO calls present; artifact/provenance mismatch; more than one loop; missing absence/restore lines.