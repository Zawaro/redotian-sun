## Why

Weapon fire sounds with a comma-separated `sound_report` list are currently picked uniformly at random on every shot (`CombatComponent._play_fire_sound`). The original Tiberian Sun engine selects the report based on how much weapon-fire SFX is currently stacking: the first entry is the "individual report" heard from a lone shooter, and later entries rotate in only as overlapping copies pile up. Verified empirically against the original game and consistent with ModEnc's `Report=` documentation (units appear to lock onto one sound because stacking, not randomness, drives the mix). In the original game the lone-shooter report is audibly `SLVKGUN1`, so our `minigun.tres` lists it first (the rules.ini `Report=` order puts `SLVKGUN1` last; the stacking rotation reproduces the original's audible mix either way). Issue #349 exposed the adjacent data wiring bug (light infantry carried the elite M1Carbine instead of the Minigun, whose report list is `SLVKGUN1,INFGUN3,GOSTGUN1`); with the data now correct, the selection logic is the remaining mismatch.

## What Changes

- Replace the per-shot random pick in `CombatComponent._play_fire_sound` with stacking-driven selection delegated to AudioManager.
- Add `AudioManager.play_report(ids, position)`: walk the report list in order and play the first entry whose live copy count is below a rotation threshold (`REPORT_STACK_PER_ID`); fall through on unknown ids (missing AudioData warns once); if every entry is saturated, play the last entry.
- Single-entry lists keep today's exact behavior (`m1carbine.tres` and most weapons are unaffected in practice).
- Update the audio-system spec scenario "Weapon fire plays one report sound" from random selection to stacking-driven selection.
- No data changes: `minigun.tres` already carries the faithful `INFGUN3,GOSTGUN1,SLVKGUN1` list and the `slvkgun1`/`gostgun1` AudioData resources exist.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `audio-system`: The weapon-fire report requirement changes from "one of the listed sounds is chosen at random" to "the earliest listed sound that is not saturated by concurrent copies plays; saturation rotates fire into later entries; unknown ids are skipped".

## Impact

- `scripts/components/CombatComponent.gd` — `_play_fire_sound` no longer picks randomly; delegates the list to AudioManager.
- `scripts/core/AudioManager.gd` — new `play_report` method plus `REPORT_STACK_PER_ID` constant and a read-only active-count helper for tests; reuses existing `_active_players_by_id` tracking, no new state.
- `openspec/specs/audio-system/spec.md` — one scenario's requirement text changes.
- `test/integration/test_audio_voice_routing.gd` — comma-report test rewritten for stacking semantics; new rotation, saturation, unknown-id, and single-entry cases.
- Backward compatible: weapons with a single `sound_report` entry (all current weapons except minigun) behave identically.
