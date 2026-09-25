## ADDED Requirements

### Requirement: Movement speed conversion from TS leptons

GlobalRules SHALL own the single conversion from TS `Speed` (leptons per game frame) to world units per second, derived from `logic_fps` and `CellUtil.CELL_SIZE`, using 256 leptons per cell and the linear scale factor 2.56 (`256/100`):

`speed_to_units_per_second(speed) = speed * 2.56 * logic_fps * CELL_SIZE / 256`

At the default `logic_fps = 30` and `CELL_SIZE = 2`, this SHALL equal `0.6 * speed`. This helper SHALL be the sole authority for the conversion; movement code SHALL NOT duplicate the constant. The project's existing 2× time base — `build_speed = 0.4` (half TS's `.8`), `harvester_fill_rate = 30/18` (vs TS `15/18`), and the 30 fps ROF base — SHALL be the reason `logic_fps` is 30 rather than TS's 15. TS's `min(Speed,100)` / `min(...,255)` clamp SHALL NOT be modeled: it only binds at Speed ≥ 99.6, far above authored TS data.

#### Scenario: Default conversion at 30 Hz

- **WHEN** `logic_fps = 30.0` and `speed_to_units_per_second(5.0)` is called
- **THEN** it returns `3.0` world units per second

#### Scenario: Conversion scales with the logic rate

- **WHEN** `logic_fps` is `15.0` and `speed_to_units_per_second(5.0)` is called
- **THEN** it returns `1.5` world units per second

#### Scenario: Immobile speed

- **WHEN** `speed_to_units_per_second(0.0)` is called
- **THEN** it returns `0.0`
