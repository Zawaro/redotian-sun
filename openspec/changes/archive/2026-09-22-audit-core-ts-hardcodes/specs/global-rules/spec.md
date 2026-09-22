## ADDED Requirements

### Requirement: Power bar presentation constants
GlobalRules SHALL contain `power_bar_max_output: float` (full-bar output scale) and `power_bar_curve_exponent: float` (fill curve exponent). The sidebar power bar SHALL derive its fill fractions from these fields rather than compile-time constants.

#### Scenario: Default power bar scale
- **WHEN** GlobalRules is loaded with `power_bar_max_output = 2000.0` and `power_bar_curve_exponent = 0.4`
- **THEN** an output of 2000 fills the power bar and the fill fraction is `(value/2000)^0.4`

#### Scenario: Overridden power bar scale
- **WHEN** a game sets `power_bar_max_output = 1000.0`
- **THEN** an output of 1000 fills the bar

### Requirement: Weapon logic FPS constant
GlobalRules SHALL contain `logic_fps: float` (the logic frame rate weapon `rate_of_fire` values are authored against). The combat component SHALL convert `rate_of_fire` ticks to seconds using `logic_fps`.

#### Scenario: Default logic FPS
- **WHEN** GlobalRules is loaded with `logic_fps = 30.0` and a weapon has `rate_of_fire = 30`
- **THEN** the weapon's cooldown is 1.0 second

### Requirement: Refinery unload rate constant
GlobalRules SHALL contain `refinery_unload_rate: float` (bales deposited per second while unloading). Dock unload SHALL use this value unless the component overrides it.

#### Scenario: Default unload rate
- **WHEN** GlobalRules is loaded with `refinery_unload_rate = 2.0`
- **THEN** a docking harvester deposits 2 bales per second

### Requirement: Homing turn conversion constant
GlobalRules SHALL contain `homing_turn_per_sec_per_unit: float` converting a projectile's homing turn-rate value into degrees per second. The projectile controller SHALL use it instead of a hardcoded factor.

#### Scenario: Default homing conversion
- **WHEN** GlobalRules is loaded with `homing_turn_per_sec_per_unit = 60.0` and a projectile has `homing_turn_rate = 1`
- **THEN** the projectile turns at 60 degrees per second

### Requirement: Primary resource category
GlobalRules SHALL contain `primary_resource_category: String` naming the resource category the HUD, storage display and default economy deductions use (Tiberian Sun: `"tiberium"`). Game code SHALL read the active rules' value instead of the `"tiberium"` literal.

#### Scenario: Default primary category
- **WHEN** GlobalRules is loaded with `primary_resource_category = "tiberium"`
- **THEN** HUD storage and default deductions use `"tiberium"`

#### Scenario: Overridden primary category
- **WHEN** a game sets `primary_resource_category = "ore"`
- **THEN** HUD storage and default deductions use `"ore"`

### Requirement: Inert Tiberian Sun mechanic flags resolved
GlobalRules SHALL NOT expose flags that imply an unimplemented mechanic with no consumer. `visceroids`, `meteorites`, `weed_capacity` and `crew_escape` SHALL be removed from GlobalRules; if re-introduced they SHALL be declared as explicit off-by-default features of the owning game rather than inert numeric fields.

#### Scenario: No inert flags remain
- **WHEN** GlobalRules is loaded
- **THEN** it has no `visceroids`, `meteorites`, `weed_capacity` or `crew_escape` property

#### Scenario: Future mechanic is opt-in
- **WHEN** a game wants visceroids later
- **THEN** it declares a `visceroids` feature toggle and implements the consumer, rather than relying on a dormant rules field

## REMOVED Requirements

### Requirement: Movement coefficients
**Reason**: Tracked/wheeled uphill/downhill multipliers were selected by matching the locomotor id string in `MovementController`, which does not generalize to other games' locomotors.
**Migration**: Slope coefficients now live on the `Locomotor` resource (`uphill_factor`, `downhill_factor`); `MovementController` reads them from the unit's resolved locomotor. Set the values on each game's `locomotors/*.tres` (Tiberian Sun: Track 0.5/1.1, Wheel 0.5/1.2).
