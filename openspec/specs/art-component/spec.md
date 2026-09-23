# art-component Specification

## Purpose
TBD - created by archiving change art-component-animation-engine. Update Purpose after archive.
## Requirements
### Requirement: ArtComponent instantiates animation clip models

`ArtComponent` SHALL instantiate every `ArtData.animations` entry with a non-empty `model_path` as its own child node positioned at that entry's `offset`, independently of the base model. Entries with an empty `model_path` SHALL be skipped without error. A clip whose model fails to load SHALL be skipped with a warning and SHALL NOT block the base model or other clips.

#### Scenario: Clip instantiated at its offset
- **WHEN** an `ArtComponent` finalizes a model whose `ArtData.animations` contains an entry with `model_path = "res://games/ts/assets/models/anim/antenna.glb"` and `offset = Vector3(0, 1.5, 0)`
- **THEN** the clip scene is added as a child of the art component and its local position equals `Vector3(0, 1.5, 0)`

#### Scenario: Empty path is skipped
- **WHEN** an animations entry has an empty `model_path`
- **THEN** no node is instantiated for it and no error is raised

#### Scenario: Missing clip model does not block base art
- **WHEN** one animations entry points at a model path that does not exist
- **THEN** that clip is skipped with a warning, the base model still loads, and the other clips still instantiate

### Requirement: ArtComponent drives the model's own AnimationPlayer

For each instantiated clip, `ArtComponent` SHALL locate the first `AnimationPlayer` contained in the clip's scene and drive that player, rather than creating an empty `AnimationPlayer` of its own. The clip SHALL be played using `clip_name` when non-empty, otherwise the player's first animation. Only `ACTIVE` clips SHALL loop, and only when the entry's `loop` flag is true; every other role is a one-shot and SHALL NOT loop regardless of the flag. The player's `speed_scale` SHALL be set from the entry's `speed_scale`. A clip with no `AnimationPlayer` or no matching animation SHALL be skipped without error.

#### Scenario: Model animation plays
- **WHEN** a clip GLB contains an `AnimationPlayer` with an animation named `"rotate"` and the entry sets `clip_name = "rotate"`, `loop = true`
- **THEN** that player's `"rotate"` animation is playing and its `loop_mode` is `LOOP_LINEAR`

#### Scenario: Animation speed applied
- **WHEN** an entry sets `speed_scale = 0.5`
- **THEN** the clip player's `speed_scale` is `0.5`

#### Scenario: One-shot ignores the loop flag
- **WHEN** a `DOOR` entry has `loop = true` (the default) and `clip_name = "open"`
- **THEN** the clip player's `"open"` animation has `loop_mode = LOOP_NONE`

#### Scenario: Model without animations is inert
- **WHEN** a clip GLB contains no `AnimationPlayer`
- **THEN** the clip node is still instantiated but no player is started and no error is raised

### Requirement: Theater suffix resolution for art paths

When `ArtData.new_theater` is true and the active theater id is non-empty, every art path — the base `ArtData.model_path` and each `animations[].model_path` and `damaged_model_path` — SHALL resolve to `<dir>/<base>_<theater>.<ext>` when that file exists, and SHALL otherwise fall back to the authored generic path. When `new_theater` is false or no theater is active, the authored path SHALL be used unchanged.

#### Scenario: Theater variant exists
- **WHEN** the active theater is `"snow"`, `new_theater` is true, and both `gdi_conyard01.glb` and `gdi_conyard01_snow.glb` exist
- **THEN** `gdi_conyard01_snow.glb` is loaded

#### Scenario: Missing variant falls back to generic
- **WHEN** the active theater is `"snow"`, `new_theater` is true, and only `gdi_conyard01.glb` exists
- **THEN** `gdi_conyard01.glb` is loaded

#### Scenario: Theater disabled
- **WHEN** `new_theater` is false and `gdi_conyard01_snow.glb` exists
- **THEN** the authored `gdi_conyard01.glb` is loaded

#### Scenario: No active theater
- **WHEN** no theater is active and `new_theater` is true
- **THEN** the authored generic path is loaded

### Requirement: Per-animation power gating

On `PowerComponent.power_state_changed(false)`, `ArtComponent` SHALL pause every clip whose entry has `requires_power = true`, regardless of role, and SHALL leave clips with `requires_power = false` playing. On `power_state_changed(true)`, paused `ACTIVE` clips SHALL resume from their preserved playhead; paused one-shot clips SHALL NOT auto-resume and SHALL wait for their next trigger. Clips whose entity has no `PowerComponent` SHALL play unaffected.

#### Scenario: Power-required clip pauses
- **WHEN** a structure whose `ActiveAnimData` has `requires_power = true` goes offline
- **THEN** that clip's player pauses

#### Scenario: Non-power clip keeps playing
- **WHEN** a structure goes offline and one clip entry has `requires_power = false`
- **THEN** that clip continues playing while a power-required sibling pauses

#### Scenario: Power restored resumes
- **WHEN** a structure returns online after a power pause
- **THEN** each `ACTIVE` clip paused for power resumes from where it paused

#### Scenario: One-shot clip pauses but does not auto-resume
- **WHEN** a playing one-shot clip with `requires_power = true` is paused by a blackout and the structure powers back up
- **THEN** the clip stays paused until it is triggered again

#### Scenario: Entity without PowerComponent unaffected
- **WHEN** an animated entity has no `PowerComponent`
- **THEN** its clips play continuously, unaffected by grid state

### Requirement: Damaged-state clip swap

`ArtComponent` SHALL connect to `HealthComponent.health_changed` and, while an ACTIVE clip entry has a non-empty `damaged_model_path`, SHALL hide the normal clip node and show the damaged node (playing the damaged animation) when the health ratio is at or below 0.5, and SHALL show the normal node again and hide the damaged node when the ratio rises above 0.5. Entries without a `damaged_model_path` SHALL be unaffected. An entity without a `HealthComponent` SHALL keep its normal clips.

#### Scenario: Swap below threshold
- **WHEN** health drops to exactly 50% and the entry has a `damaged_model_path`
- **THEN** the normal clip node is hidden and the damaged clip node is visible and playing

#### Scenario: Revert above threshold
- **WHEN** a damaged entity is healed above 50%
- **THEN** the normal clip node becomes visible again and the damaged node is hidden

#### Scenario: No damaged variant
- **WHEN** health falls below 50% and the entry has an empty `damaged_model_path`
- **THEN** the normal clip continues unchanged

#### Scenario: Above threshold unchanged
- **WHEN** health is above 50%
- **THEN** only the normal clip node is visible

### Requirement: One-shot lifecycle clips

`ArtComponent` SHALL play role-tagged one-shot clips from sibling signals: a `DOOR` clip plays forward on the factory exit-started trigger and backward on the exit-completed trigger, holding its first frame while idle; a `PRODUCTION` clip plays while a factory is producing/exiting; a `BUILDUP` clip plays once when a building is placed, with the base model and ACTIVE clips hidden until it finishes and revealed when it completes. Buildup SHALL NOT play for map-load starting bases or deployed structures that did not go through placement.

#### Scenario: Door opens then closes
- **WHEN** a factory begins a unit exit and later reports the exit completed
- **THEN** the `DOOR` clip plays forward to its end frame on start and backward to its first frame on completion

#### Scenario: Idle door holds first frame
- **WHEN** a `DOOR` clip is not playing
- **THEN** the door mesh shows its first frame

#### Scenario: Production clip during exit
- **WHEN** a factory is busy producing or exiting a unit
- **THEN** the `PRODUCTION` clip is playing and stops when the factory is no longer busy

#### Scenario: Buildup reveal on completion
- **WHEN** a building is placed with a `BUILDUP` clip
- **THEN** the base model and ACTIVE clips are hidden while the buildup plays and become visible when it finishes

#### Scenario: Map-load base skips buildup
- **WHEN** a starting-base building is created by the map loader rather than placed
- **THEN** no `BUILDUP` clip plays and the building is shown in its normal state

