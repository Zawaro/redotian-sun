## Why

`ArtComponent` loads entity models but cannot play any of them: `_setup_animation_player()` creates a fresh empty `AnimationPlayer` and never references the `AnimationPlayer` the glTF importer builds inside the loaded model, so `active_anims`, `damaged_anim`, `door_anim`, `production_anim`, and `buildup_name` are all inert. Art data already describes a full TS animation vocabulary (art.ini `ActiveAnim*`, `ActiveAnimDamaged`, `DoorAnim`, `ProductionAnim`, `Buildup`, `DeployingAnim`, `NewTheater`) but no code consumes it. This change builds the missing animation engine so buildings can animate at all.

## What Changes

- Introduce `AnimClipData` (renamed from `ActiveAnimData`) carrying a `role`, a per-clip `model_path` GLB, an optional `damaged_model_path` GLB, `clip_name`, `speed_scale`, `loop`, a single `offset: Vector3`, and `requires_power`. **BREAKING** — the resource class and `ArtData.active_anims` field are renamed/replaced.
- Replace `ArtData.active_anims` with `ArtData.animations: Array[AnimClipData]`; fold the one-shot String fields (`door_anim`, `under_door_anim`, `production_anim`, `pre_production_anim`, `buildup_name`, `deploying_anim`, `special_anim`, `charge_anim`) into role-tagged entries. Their existing behavior is inert until animated models are authored.
- Add suffix-based theater resolution: with `ArtData.new_theater = true`, a path resolves to `<base>_<theater>.<ext>` when that file exists, else the generic path. Applied to every clip path.
- Teach `ArtComponent` to instantiate each clip GLB as an offset child, resolve its model's `AnimationPlayer`, apply `speed_scale`/`loop`, and register it for gating and one-shot playback.
- Per-anim power gating: only `requires_power` clips pause when the owning structure is offline; other clips keep playing. Replaces the current blanket `_animation_player.pause()`.
- Damaged-state swap: connect `HealthComponent.health_changed`; at health ratio ≤ 0.5 hide the normal clip node and show `damaged_model_path`, reverting above 0.5.
- One-shot lifecycle clips: door open/close as forward/reverse of the same clip, production/under-door during a factory exit, and buildup on placement.
- Reuse `TerrainCatalog.get_active_theater_id()` as the theater source; no new autoload.

## Capabilities

### New Capabilities

- `art-component`: entity model animation engine — clip instantiation with offsets, GLB `AnimationPlayer` resolution, speed/loop, theater suffix resolution, per-anim power gating, damaged-state swap, and one-shot lifecycle clips.

### Modified Capabilities

- `entity-data`: `ArtData` animation schema changes — `active_anims: Array[ActiveAnimData]` becomes `animations: Array[AnimClipData]`, one-shot String fields become role-tagged entries, and `new_theater` drives suffix resolution.
- `power-grid`: the "Offline animations stop" requirement changes from pausing all `active_anims` to gating only clips whose `requires_power` is true.

## Impact

- **Data**: `scripts/data/ActiveAnimData.gd` → `scripts/data/AnimClipData.gd` (+ `.uid`); `scripts/data/ArtData.gd` field/validation changes.
- **Components**: `scripts/components/ArtComponent.gd` (engine, gating, swap, one-shots).
- **Placement**: `scripts/buildings/BuildingManager.gd` calls buildup on placement; map-load bases skip it (FreeBuildup semantics).
- **Tests**: `test/unit/test_art_component.gd` expands; `test/unit/test_power_grid.gd` updates its `ActiveAnimData` construction.
- **Assets**: none of the 4 current GLBs have animations, so behavior is verified with synthetic `PackedScene` + `AnimationPlayer` fixtures.
- **Out of scope (own tickets)**: GLB punctual model lights + `powered_light` (#433); terrain-art per-file theater split (#434); superweapon silo door (#435, blocked on #244/#265); 25% extra-damage FX/smoke (#436); animated unit sub-meshes (#437); deploy/undeploy whole-art swap (#438, needs a `DeployComponent` transition window); tiberium silo fullness animation (#439, storage-driven, not health).
