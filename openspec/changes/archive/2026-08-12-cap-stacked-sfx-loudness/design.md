## Context

`AudioManager` (`scripts/core/AudioManager.gd`) plays every sound by spawning a fresh `AudioStreamPlayer`/`AudioStreamPlayer3D` per call on the SFX/Voice/Music/Master buses (`default_bus_layout.tres`). The #280 fix added a per-id cap (`MAX_STACK_PER_ID = 12`) plus per-copy `-20·log10(N)` renormalization. That bounds *identical* ids at the source, but the overall mix is still too loud: different ids each keep full volume and sum at Master, and no bus has any effects, so nothing prevents clipping when many sounds stack.

The engine's sanctioned mechanism is bus effects: `AudioServer.add_bus_effect()` with `AudioEffectHardLimiter` (docs: "recommended to use a hard limiter on the Master bus as a safeguard against sudden volume spikes and clipping-induced distortion") and `AudioEffectLimiter`/`AudioEffectCompressor` (compressor on voice "for consistent volume").

## Goals / Non-Goals

**Goals:**
- Guarantee a loudness ceiling on the mixed output regardless of how many sounds or ids stack.
- Keep stacked identical sounds at single-copy loudness (existing #280 behavior).
- Idempotent, code-driven setup with tunable constants.

**Non-Goals:**
- New audio content, asset work, or changes to individual `AudioData` volumes.
- Editing `default_bus_layout.tres` (effects are added in code so tests and headless runs share the same path).
- A full mixer/ducking system or per-sound-priority preemption.

## Decisions

**1. Bus effects are the loudness guarantee, not more per-id math.**
Per-id normalization cannot bound cross-id stacking; a bus limiter is a hard ceiling on the actual mixed waveform. A limiter is a ceiling: it engages only above threshold, so normal (quiet) mixes are untouched and only runaway stacking is reined in.
- Alternative considered: raise the per-id cap / strengthen normalization → rejected, still can't touch different-ids-plus-voices-plus-music summing at Master.

**2. Effect placement:**
- `Master` ← `AudioEffectHardLimiter`, `ceiling_db = -1.0` (headroom below 0 dB, prevents clipping; docs range −24..0).
- `SFX` ← `AudioEffectLimiter`, `threshold_db = -3.0`, `ceiling_db = -1.0`, small `soft_clip_db` (≈ 0.5) so busy combat stacks compress instead of blasting, with a little makeup.
- `Voice` ← `AudioEffectCompressor` (docs: compressors "on voice channels for consistent volume") so stacked voice lines stay consistent.
- Parameters as `const` at the top of `AudioManager` (`# ponytail:` knobs, tuned from playtesting).

**3. Idempotent setup in `_ensure_buses()` (run once from `_ready`).**
Guard each `add_bus_effect` with a `get_bus_effect` presence check so re-running `_ready` (or repeated tests) never duplicates effects.

**4. Keep per-id cap + renormalize.**
Each mechanism handles a distinct failure mode: per-id normalization prevents identical-id volleys from ever creating the burst (so the limiter never engages on them, avoiding pumping/ducking artifacts), the limiter is the global safety net for everything else.

**5. Normalization is per-bus, not per-id (follow-up).**
Playtesting showed weapon fire still too loud when stacked. Root cause: renormalizing by *id count* gives every distinct weapon id (INFGUN3, RKETINF1, MISL1, 120MMF, CHAINGN1…) its own full loudness budget; a mixed force sums one-copy-loudness per id. The SFX limiter caps peaks but can't lower perceived loudness. Fix: scale every copy by the **total concurrent count on its bus** (`SFX`/`Voice`/`Music` independently). Tracking per bus (a `_active_players_by_bus` dictionary) so every player rebalances when any copy on the bus spawns or finishes; the per-id array is kept solely for the `MAX_STACK_PER_ID` cap. Per-bus (not fully global) keeps a single voice line at full volume during a 20-gun volley.
- Alternative considered: fully-global single counter → fewer lines, but buries gameplay-critical voices during combat (a lone voice at ~1/21 amplitude).

**6. Retrigger throttle fixes the real driver: fire rate (follow-up 2).**
Still too loud after per-bus normalization. Root cause: M1 carbine/minigun fire at `rate_of_fire = 20+` (`resources/weapons/m1carbine.tres`), and `CombatComponent._fire_weapon` → `_play_fire_sound` spawns a player on **every bullet** (`scripts/components/CombatComponent.gd:210`). A 20-man squad = 400 sound-spawns/sec. Volume normalization only bounds *concurrent* copies; it cannot touch the *density* of 400 short transients/sec, which reads as a wall of gunfire. Per-bus vs per-id is inaudible for a single weapon type — matching the "didn't do anything" report.
Fix: `play_sound` skips a sound id that played within `RETRIGGER_INTERVAL_MS` (100ms), collapsing 400 spawns/sec → ~10/sec and dropping concurrent copies to ~1–2, so massed fire sounds like a single weapon. This is the standard "retrigger limit" pattern (Wwise/FMOD). Also cleaned the bus chain per docs: replaced the deprecated `AudioEffectLimiter` on SFX with `AudioEffectHardLimiter`, and added a gentle compressor on Master before the hard limiter (docs: "compress the whole output before it hits a limiter's ceiling").
- Alternative considered: global SFX voice budget (cap total concurrent players) → bounded density too, but the throttle alone suffices and is simpler; skipped to keep the diff minimal.

## Risks / Trade-offs

- Limiter thresholds too aggressive → audible compression on legitimately busy (but desired) mixes → tune constants from playtesting; start at −3 dB threshold / −1 dB ceiling.
- Compressor on Voice may soften single voice lines → low ratio (≈ 2:1) so it only acts when stacked.
- Headless tests don't render audio; effect presence is asserted via `AudioServer.get_bus_effect`, and existing stack behavior tests cover renormalization.
