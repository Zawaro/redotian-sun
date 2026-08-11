## Why

Stacked sound playback is still too loud in combat. Massed units firing together — even identical weapon sounds — drive the mix well past a single copy's loudness, and unrelated ids (different weapons, voices, music) each contribute full volume. The per-id normalization added in #280 only bounds *identical* copies; it cannot bound the overall mix, and nothing prevents clipping. The engine's sanctioned fix is a limiter on the Master/SFX/Voice buses.

## What Changes

- Add a **HardLimiter** effect to the Master bus so the mixed output can never exceed a configured ceiling (no clipping, no runaway stacking).
- Add a **Limiter** effect to the SFX bus to keep busy combat mixes at consistent loudness.
- Add a **Compressor** effect to the Voice bus so stacked voice lines stay at consistent volume.
- Add effect setup to `AudioManager` (idempotent, code-driven, tunable constants) so the guarantee is enforced by the playback path, not by a hand-edited bus layout file.
- Keep the existing per-id stack cap (`MAX_STACK_PER_ID`) and per-copy `-20·log10(N)` renormalization from #280 — they bound identical-id stacking at the source; the bus limiters are the global ceiling for everything else.

## Capabilities

### New Capabilities

None. No new capability is introduced; this is a behavioral tightening of the existing audio system.

### Modified Capabilities

- `audio-system`: requires that stacking of any sounds — same or different ids — can never exceed the configured loudness ceiling. Currently the audio-system spec describes per-playback behavior (data-driven loading, bus routing, spatial/voice playback) but places no bound on aggregate mix loudness.

## Impact

- `scripts/core/AudioManager.gd` — add bus-effect setup (`_ensure_buses`/new helper), limiter constants, and idempotency guards.
- `default_bus_layout.tres` — unchanged (effects added in code; layout file has no effects today).
- `test/unit/test_audio_manager.gd` — new assertions that Master/SFX/Voice buses carry the expected effects; existing stack tests must stay green.
- No scene/API/behavior changes outside the audio playback path.
