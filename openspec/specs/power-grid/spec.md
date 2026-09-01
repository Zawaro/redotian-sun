## Purpose

Per-player power aggregation: every PowerComponent registers via scene-tree signals, PowerGrid sums output and drain per player, classifies low power, fans out shutdown to powered structures, and scales production speed. Selection-overlay and sidebar UI read live grid totals; build-cameo tooltips carry each item's data power value.
## Requirements

### Requirement: PowerGrid autoload aggregates per-player power
The system SHALL provide a `PowerGrid` autoload singleton that maintains a registry of all `PowerComponent` nodes present in the scene tree. For each registered component, PowerGrid SHALL resolve the owning player via the entity's `StatsComponent.player_id` and maintain per-player sums: `output` (sum of positive `power` values) and `drain` (sum of the absolute values of negative `power` values). Registration SHALL be driven by scene-tree `node_added`/`node_removed` signals so that buildings reach the grid through every spawn path (player placement, map-load starting bases, MCV deploy, editor placement) and leave it on free.

#### Scenario: Register on placement
- **WHEN** BuildingManager places a building with a `PowerComponent` (e.g. a power plant, `power = 100`)
- **THEN** PowerGrid registers the component and the owner's `output` increases by 100

#### Scenario: Register map-load starting base
- **WHEN** MapLoader creates a starting-base building via `EntityFactory.create_entity()` (not BuildingManager)
- **THEN** PowerGrid registers its `PowerComponent` and includes it in the owner's sums

#### Scenario: Register deployed structure
- **WHEN** an MCV deploys into a structure with a `PowerComponent`
- **THEN** PowerGrid registers the deployed structure's `PowerComponent`

#### Scenario: Unregister on destruction or sale
- **WHEN** a registered building is destroyed (health reaches zero) or sold (queue_free)
- **THEN** PowerGrid unregisters its `PowerComponent` and recomputes the owner's sums

#### Scenario: Per-player isolation
- **WHEN** player 0 is in power deficit and player 1 has surplus
- **THEN** only player 0's structures are affected; player 1's sums and structure states are unchanged

#### Scenario: Entity without PowerComponent is ignored
- **WHEN** an entity without a `PowerComponent` (e.g. a wall) is added or removed
- **THEN** PowerGrid's sums are unchanged

### Requirement: Low power state
PowerGrid SHALL classify a player's grid as **low power** when `sum = output − drain < 0`, and as **healthy** when `sum >= 0`. The classification SHALL update immediately when any registered `PowerComponent` is added or removed — no per-frame polling. A grid with `drain = 0` SHALL always be healthy.

#### Scenario: Healthy grid
- **WHEN** a player's output is 200 and drain is 150 (sum = 50)
- **THEN** the grid is healthy

#### Scenario: Deficit triggers low power
- **WHEN** a power plant producing 100 is destroyed while drain is 150 (output drops to 50, sum = −100)
- **THEN** the grid is classified as low power immediately

#### Scenario: Recovery restores healthy state
- **WHEN** a plant is placed that brings the sum back to ≥ 0
- **THEN** the grid is classified as healthy immediately

#### Scenario: No consumers means never low power
- **WHEN** a player owns only producers (drain = 0)
- **THEN** the grid is healthy regardless of output

### Requirement: Grid state change signals
PowerGrid SHALL emit `grid_state_changed(player_id: int)` whenever a player's computed state changes, covering both the low-power boundary crossing and rate-only drift. It SHALL NOT emit when a registry change does not alter that player's computed state.

#### Scenario: Boundary crossing emits
- **WHEN** a player's sum crosses from ≥ 0 to < 0
- **THEN** `grid_state_changed` emits once for that player

#### Scenario: Rate drift emits without boundary crossing
- **WHEN** a consumer is added that keeps the sum negative but changes the output/drain ratio
- **THEN** `grid_state_changed` emits so consumers can refresh derived values (e.g. cached build speed)

#### Scenario: No-op change stays silent
- **WHEN** a building with `power = 0` is placed
- **THEN** `grid_state_changed` does not emit

#### Scenario: Tiny rate drift still emits
- **WHEN** a consumer joins a large low-power grid and shifts the build rate by less than floating-point approximation tolerance
- **THEN** `grid_state_changed` still emits so consumers' cached rates refresh

### Requirement: Runtime power state on PowerComponent
`PowerComponent` SHALL expose a runtime `is_online` state (default `true`, independent of the data-level `powered` flag, which only marks that a structure *requires* power) and a `power_state_changed(is_online: bool)` signal emitted by `set_online()`. PowerGrid SHALL call `set_online()` on every affected registered component exactly when the owning player's grid crosses the low-power boundary, and SHALL NOT re-emit for components whose state does not change. Components whose entity lacks `powered = true` SHALL always remain online.

#### Scenario: Shutdown transition
- **WHEN** the owning player's grid crosses into low power
- **THEN** each `powered = true` structure's PowerComponent emits `power_state_changed(false)` exactly once

#### Scenario: Recovery transition
- **WHEN** the owning player's grid returns to healthy
- **THEN** each previously offline PowerComponent emits `power_state_changed(true)` exactly once

#### Scenario: Structures not requiring power stay online
- **WHEN** the grid is in low power and a building has `powered = false`
- **THEN** its PowerComponent does not change state and emits nothing

#### Scenario: Registered during an active deficit
- **WHEN** a `powered = true` structure is registered while its owner's grid is already low power
- **THEN** its PowerComponent starts offline via `set_online(false)` exactly once, without waiting for a boundary crossing

### Requirement: Powered-down structures stop functioning
When a structure is offline (`is_online == false`), its gameplay subsystems SHALL stop: `CombatComponent` SHALL NOT acquire targets or fire; `RadarComponent.has_radar()` SHALL return `false`; `ArtComponent` SHALL pause its `active_anims` and resume them when the structure returns online. Structures that are online SHALL behave exactly as before this change.

#### Scenario: Offline turret stops firing
- **WHEN** a `powered = true` defense structure goes offline while engaged
- **THEN** CombatComponent stops acquiring targets and fires no weapons, and resumes normal behavior when power is restored

#### Scenario: Offline radar reports offline
- **WHEN** a `powered = true` radar structure goes offline
- **THEN** `has_radar()` returns `false` and returns `true` again on recovery

#### Scenario: Offline animations stop
- **WHEN** a `powered = true` structure with `active_anims` goes offline
- **THEN** its active animations stop (pause), and resume when the structure powers back up

#### Scenario: Combat entity without PowerComponent unaffected
- **WHEN** a combat entity has no `PowerComponent` (e.g. a tank)
- **THEN** its firing behavior is unchanged

### Requirement: Low power build rate interpolation
PowerGrid SHALL expose a per-player build-rate multiplier: `1.0` when healthy, and `lerp(worst, best, output / drain)` when in low power, where `worst`/`best` are the GlobalRules low-power build-rate coefficients and the ratio is clamped to `[0, 1]`. A mild deficit yields a rate near `best`; a near-blackout yields a rate near `worst`.

#### Scenario: Healthy grid full rate
- **WHEN** a player's grid is healthy
- **THEN** the build-rate multiplier is 1.0

#### Scenario: Mild deficit near best coefficient
- **WHEN** output is 130 against drain 150 (ratio ≈ 0.87)
- **THEN** the multiplier is close to `best_low_power_build_rate_coefficient` (0.75), computed as `lerp(0.3, 0.75, 0.87)`

#### Scenario: Near-blackout near worst coefficient
- **WHEN** output is 10 against drain 150 (ratio ≈ 0.07)
- **THEN** the multiplier is close to `worst_low_power_build_rate_coefficient` (0.3)

#### Scenario: No consumers full rate
- **WHEN** drain is 0
- **THEN** the multiplier is 1.0

### Requirement: Selected producer power label
When a building whose `PowerComponent` reports `power > 0` (a producer) is selected, the selection overlay SHALL draw the owner's grid totals as green two-line text — `POWER = {output}` on the first line, `DRAIN = {drain}` on the second — centered on the entity's selection bracket. Structures SHALL participate in overlay collection (with brackets, health bars, and pips suppressed — buildings render SelectComponent's 3D wireframe box) so the label can draw on them. The label SHALL be a per-frame read from PowerGrid (no cached values) and SHALL NOT appear on consumers, unselected entities, or producers of other players.

#### Scenario: Label on selected power plant
- **WHEN** the local player selects a power plant while the base drains 150 and supplies 200
- **THEN** green text "POWER = 200" and "DRAIN = 150" is drawn centered on the plant's selection bracket

#### Scenario: Label reflects live grid
- **WHEN** the label is visible and a producer is destroyed
- **THEN** the POWER number updates to the new grid total without reselecting

#### Scenario: No label on consumers
- **WHEN** a building with `power <= 0` (e.g. a radar) is selected
- **THEN** no power label is drawn

#### Scenario: No label on hover-only
- **WHEN** a producer is merely hovered (not selected)
- **THEN** no power label is drawn

### Requirement: Sidebar power bar
The sidebar SHALL host a vertical twin power bar on its left edge, spanning the cameo panel height: a black column backing the fills, a green fill whose height is the local player's power output relative to a 2000 full-scale, and a red fill whose height is the drain relative to the same scale, drawn in front of the green. Fill fractions SHALL map through a milder-than-linear power curve — `(fraction)^0.4`, so a single +100 plant reads ≈ 30% of the bar instead of 5% linear. The bar SHALL read live PowerGrid totals every frame (no caching, no signal dependency), ease the displayed fills toward their targets so grid changes animate rather than jump, and clamp fills to the bar height.

#### Scenario: Output fills relative to scale
- **WHEN** the local player's grid outputs 1000 with no consumers
- **THEN** the green fill is ≈ 76% of the bar height (0.5^0.4) and no red fill is drawn

#### Scenario: Small output stays visible
- **WHEN** the local player's grid outputs 100 (a single plant)
- **THEN** the green fill is ≈ 30% of the bar height (0.05^0.4)

#### Scenario: Fills animate on grid change
- **WHEN** a power plant is placed or sold while the bar is visible
- **THEN** the fills ease toward their new heights instead of jumping

#### Scenario: Deficit raises red above green
- **WHEN** the local player's drain exceeds output
- **THEN** the red fill is taller than the green fill

#### Scenario: Values clamp at full scale
- **WHEN** output or drain reaches 2000 or more
- **THEN** the corresponding fill spans the full bar height

### Requirement: Build menu power tooltip
A build menu cameo whose `EntityData.power` is nonzero SHALL show a signed power line in its tooltip (`Power: +N` for producers, `Power: -N` for consumers); cameos with `power = 0` SHALL show no power line.

#### Scenario: Producer tooltip
- **WHEN** hovering a build menu cameo whose data has `power = 100`
- **THEN** the tooltip includes "Power: +100"

#### Scenario: Consumer tooltip
- **WHEN** hovering a build menu cameo whose data has `power = -50`
- **THEN** the tooltip includes "Power: -50"

#### Scenario: No power line without power values
- **WHEN** hovering a build menu cameo whose data has `power = 0`
- **THEN** the tooltip contains no power line
