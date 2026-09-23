## 1. Animation clip schema

- [x] 1.1 Add `scripts/data/AnimClipData.gd` (`class_name AnimClipData`) with the `Role` enum (`ACTIVE`, `DOOR`, `UNDER_DOOR`, `PRODUCTION`, `PRE_PRODUCTION`, `BUILDUP`, `DEPLOY`, `SPECIAL`, `CHARGE`, `POWER_UP`, `GATE`) and exported fields `role`, `model_path`, `clip_name`, `damaged_model_path`, `speed_scale`, `loop`, `offset: Vector3`, `requires_power`, plus its `.uid`
- [x] 1.2 Delete `scripts/data/ActiveAnimData.gd` and `scripts/data/ActiveAnimData.gd.uid`
- [x] 1.3 In `scripts/data/ArtData.gd`, replace `active_anims: Array[ActiveAnimData]` with `animations: Array[AnimClipData]`, fold the one-shot String fields (`buildup_name`, `deploying_anim`, `door_anim`, `under_door_anim`, `production_anim`, `pre_production_anim`, `special_anim`, `charge_anim`) into role-tagged entries, and keep `new_theater` as the theater opt-in
- [x] 1.4 Update `ArtData.validate()` to flag animation entries with an empty `model_path`
- [x] 1.5 Update the remaining references (`scripts/components/ArtComponent.gd`, `test/unit/test_power_grid.gd`) so the project parses

## 2. ArtComponent engine core

- [x] 2.1 In `ArtComponent`, instantiate each `animations` entry with a non-empty `model_path` as a child node at its `offset`; skip empty or missing paths with a warning
- [x] 2.2 Resolve the first `AnimationPlayer` within each clip node, set `speed_scale` from the entry, play the entry's `clip_name` (or the first animation), and set `loop_mode` from `loop`
- [x] 2.3 Keep the base model load path unchanged and stop creating the empty standalone `AnimationPlayer` for model-provided animations
- [x] 2.4 Store per-clip records (`node`, `player`, `entry`, normal/damaged node) for gating and one-shots

## 3. Theater suffix resolution

- [x] 3.1 Add an art-path resolver (in `ArtData` or a shared helper) that, when `new_theater` is true and the active theater id is non-empty, returns `<dir>/<base>_<theater>.<ext>` if it exists, else the authored path
- [x] 3.2 Use `TerrainCatalog.get_active_theater_id()` as the theater source and apply the resolver to `model_path` and every clip/damaged path in `ArtComponent`
- [x] 3.3 Cover the resolver with the four spec scenarios (variant hit, generic fallback, `new_theater` false, no active theater)

## 4. Power gating and damaged swap

- [x] 4.1 Rework `set_active_anims_running` (or replace it) so power loss pauses only clips with `requires_power = true` and leaves the others playing; resume paused clips on restore
- [x] 4.2 Connect `HealthComponent.health_changed` and, at health ratio ≤ 0.5, hide the normal node and show `damaged_model_path` (playing) for ACTIVE entries; revert above 0.5
- [x] 4.3 Guard for entities without a `HealthComponent` or without a damaged variant

## 5. One-shot lifecycle clips

- [x] 5.1 Add a door API: forward on the factory exit-started trigger, `play_backwards` on exit-completed, holding frame 0 while idle
- [x] 5.2 Play the `PRODUCTION` clip while a factory is busy and stop it when idle
- [x] 5.3 Play the `BUILDUP` clip once on placement, hiding the base model and ACTIVE clips until `animation_finished`, then reveal
- [x] 5.4 Wire trigger signals from sibling components in `configure` (`FactoryComponent.exit_in_progress`, `ExitComponent.unit_spawned`, `ExitComponent.exit_completed`) and accept a `play_buildup()` call from `BuildingManager.place_building` after placement
- [x] 5.5 Ensure map-load starting bases and deploy-created structures do not play buildup

## 6. Tests

- [x] 6.1 Expand `test/unit/test_art_component.gd` with synthetic `PackedScene` + `AnimationPlayer`/`Animation` fixtures registered in `BatchLoader._cache`
- [x] 6.2 Assert per-anim power gate (power-required pauses, non-power keeps playing, resume)
- [x] 6.3 Assert damaged swap at ≤ 50% and revert above, including the exact-boundary case and the no-variant case
- [x] 6.4 Assert `speed_scale` is applied and `loop` sets the animation's loop mode
- [x] 6.5 Assert theater suffix hit, generic fallback, and disabled/no-theater paths
- [x] 6.6 Assert door forward/reverse direction, production clip start/stop, and buildup reveal-on-finish
- [x] 6.7 Run `redot --headless -s test/run_tests.gd`

## 7. Docs and cleanup

- [x] 7.1 Update `GLOSSARY.md`: add "animation clip" and "theater variant" terms and link the `art-component` spec; check the Undecided section
- [x] 7.2 Document the Blender authoring contract for asset authors in the change: disable `Sampling Animations` for keyframed clips, one GLB per clip, name the file with the theater suffix for variants
- [x] 7.3 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`
