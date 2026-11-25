# REVIEWER CAPTURE ADDITIONS (next windows) — sc->vptr check, canaries, per-order logs, ±2 s transition drain

Required on every next-window run (new-architecture candidate, `R11_SKIP_PUO=1` control, and any v4l/v5 build), in addition to the standard evidence contract.

## 1. `sc->vptr` expectation check
- Log the swapchain object pointer (`sc`) captured at install and verify the **expected vptr** at the object head matches the installed patched vtable.
- Capture line(s) such as: `sc->vptr expected=<host16+0x…/dxgi+0x…> actual=<…> ok=0/1`; on mismatch record as anomaly (possible engine replaced swapchain object/vtable → secondary corruption).
- Cross-link: v4k crash had `r14=000002735ceecfd0` = patched `sc`; vptr check proves whether engine still saw our vtable at crash time.

## 2. Canary static arg / STOP-DRAIN lines
- Static canary-protected argument block: pre/post 64-bit canaries around `float pos[3]` (v4l-style diagnostics).
- Capture: `canary ok` per call-drain cycle; on corruption: **`CANARY CORRUPTED`** + immediate **stop draining** + count; record exact line/values.
- If `CANARY CORRUPTED` appears ⇒ stop/halt window per rule, dump + stages + host.log retained.

## 3. Per-order logs with engine state
- First N (5) PUO calls: `ret / type / tgt / abil / issuer / queue / show / pos[3]` **plus engine state at call time** (`gt`, `gs`, `state`, `in_game`, menu/open, hud cmds) — line-indexed.
- Record whether orders fire near state transitions; correlate with drain activity.

## 4. ±2 s transition-drain logging
- Around horn/game-start transition (±2 s): log transition-drain activity each frame — drain count, queue depth, PUO calls, order outcomes, stage trace phase, engine clock (`gt/gs/state/in_game`).
- Capture window: `transition drain t=-2.0..+2.0 gt=… state=… drainN=… queued=… puo=…`.
- Purpose: see exactly what our host does in the horn ±2 s window where all crashes cluster.

## Evidence handling
- Keep raw host.log tail + rotated stages + dump (matching PDB/MAP) untouched; archive copies to `qa_task26/` with timestamps.
- Any missing capture-addition line = incomplete evidence; note explicitly in run file (do not infer).