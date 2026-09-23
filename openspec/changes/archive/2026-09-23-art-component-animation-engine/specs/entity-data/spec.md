## ADDED Requirements

### Requirement: ArtData animation clip schema

`ArtData` SHALL expose `animations: Array[AnimClipData]` (default empty), replacing `active_anims`. Each `AnimClipData` SHALL be a `Resource` with a `role: Role` enum (default `ACTIVE`), `model_path: String` (default `""`), `clip_name: String` (default `""`, meaning the player's first animation), `damaged_model_path: String` (default `""`), `speed_scale: float` (default `1.0`), `loop: bool` (default `true`), `offset: Vector3` (default `Vector3.ZERO`), and `requires_power: bool` (default `true`). The `Role` enum SHALL include at least `ACTIVE`, `DOOR`, `UNDER_DOOR`, `PRODUCTION`, `PRE_PRODUCTION`, `BUILDUP`, `DEPLOY`, `SPECIAL`, `CHARGE`, `POWER_UP`, and `GATE`. `ArtData.validate()` SHALL report an animation entry whose `model_path` is empty.

#### Scenario: Defaults on a new entry
- **WHEN** an `AnimClipData` is created with no fields set
- **THEN** `role` is `ACTIVE`, `model_path` is empty, `speed_scale` is `1.0`, `loop` is true, `offset` is `Vector3.ZERO`, and `requires_power` is true

#### Scenario: Multiple clips on one building
- **WHEN** an `ArtData` sets `animations` to a rotating-antenna `ACTIVE` entry and a `DOOR` entry
- **THEN** both entries are retained in order and expose their own `model_path` and `offset`

#### Scenario: Validation flags empty model path
- **WHEN** `ArtData.validate()` runs with an animation entry whose `model_path` is empty
- **THEN** the returned errors include an entry identifying the missing animation model path

### Requirement: Theater variant opt-in flag

`ArtData.new_theater` SHALL enable suffix-based theater art resolution for the base model path and every animation clip path. When false, only the authored paths are used.

#### Scenario: Opt-in enables resolution
- **WHEN** `new_theater` is true and a theater-specific file exists
- **THEN** resolution may select the theater-specific file

#### Scenario: Opt-out keeps generic
- **WHEN** `new_theater` is false
- **THEN** only the authored generic path is used regardless of theater
