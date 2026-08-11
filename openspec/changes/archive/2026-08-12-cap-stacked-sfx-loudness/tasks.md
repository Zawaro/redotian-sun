## 1. Bus effects in AudioManager

- [x] 1.1 Add configurable constants to `AudioManager` for the bus-effect parameters: Master hard-limiter ceiling, SFX limiter threshold/ceiling/soft-clip, Voice compressor threshold/ratio
- [x] 1.2 Add idempotent bus-effect setup in `_ensure_buses()`: install `AudioEffectHardLimiter` on `Master`, `AudioEffectLimiter` on `SFX`, `AudioEffectCompressor` on `Voice`, each guarded by a `get_bus_effect` presence check so repeated runs never duplicate effects
- [x] 1.3 Confirm `_ensure_buses()` runs once from `_ready()` before any playback

## 2. Tests

- [x] 2.1 Add test asserting the `Master` bus has an `AudioEffectHardLimiter` with a sub-0 dB ceiling after `AudioManager` ready
- [x] 2.2 Add tests asserting the `SFX` bus has an `AudioEffectLimiter` and the `Voice` bus has an `AudioEffectCompressor`
- [x] 2.3 Add test asserting effect setup is idempotent (re-running setup adds no duplicate effects)
- [x] 2.4 Verify the existing per-id stack tests (cap, `-20·log10(N)` renormalization, count recovery) still pass in `test/unit/test_audio_manager.gd`

## 3. Verification

- [x] 3.1 Run `redot --headless -s test/run_tests.gd` — all pass
- [x] 3.2 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check` — clean, no tabs introduced

## 4. Per-bus stack normalization (follow-up)

- [x] 4.1 Replace per-id renormalization with per-bus tracking: `_active_players_by_bus` (bus → player list), player base volume stored via `set_meta`, id array kept only for the `MAX_STACK_PER_ID` cap
- [x] 4.2 Rebalance the whole bus stack on any spawn/finish/cap-drop via `_renormalize_bus` (`-20·log10(bus_count)` dB per copy), scoped per bus so Voice stays audible over stacked SFX
- [x] 4.3 Add cross-id tests: 3 different ids on one shared bus scale to the bus total; mixed cross-id stack never exceeds single-copy loudness; SFX and Voice buses normalize independently
- [x] 4.4 Verify: full suite (4785 pass), `gdlint` clean, `gdformat --check` clean, no tabs

## 5. Fire-rate retrigger throttle (follow-up 2)

- [x] 5.1 Add `RETRIGGER_INTERVAL_MS` const + `_last_played_at` tracking; `play_sound` silently skips a sound id that played within the interval (per-id, covers `play_voice`)
- [x] 5.2 Clean up the bus chain: SFX deprecated `AudioEffectLimiter` → `AudioEffectHardLimiter`; Master gains a gentle compressor before the hard limiter
- [x] 5.3 Tests: rapid same-id replays spawn one player; distinct ids not throttled; playback resumes after the interval; effect tests updated for the new chain
- [x] 5.4 Fix cross-test throttle pollution in `test_audio_voice_routing.gd` (reset the retrigger window in the shared fixture so routing tests observe fresh playback)
- [x] 5.5 Verify: full suite (4789 pass), `gdlint` clean, `gdformat --check` clean, no tabs

## 6. Compressor makeup gain (follow-up 3)

- [x] 6.1 Add `MASTER_COMPRESSOR_GAIN_DB` and `VOICE_COMPRESSOR_GAIN_DB` (default +8 dB) and apply via `effect.gain` in the compressor factories — restores the ~9 dB the −18 dB/2:1 compressors were pulling off every loud transient
- [x] 6.2 Assert compressor makeup gain in the Master and Voice effect tests
- [x] 6.3 Verify: full suite (4791 pass), `gdlint` clean, `gdformat --check` clean, no tabs
