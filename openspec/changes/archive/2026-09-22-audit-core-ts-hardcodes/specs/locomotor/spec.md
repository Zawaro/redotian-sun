## ADDED Requirements

### Requirement: Slope coefficients live on the Locomotor resource
`Locomotor` SHALL expose `uphill_factor: float` and `downhill_factor: float` (defaults 1.0 = no slope effect). `MovementController` SHALL read the slope coefficients from the unit's resolved `Locomotor` resource and SHALL NOT branch on locomotor id strings. When the resolved factors are both 1.0 the slope coefficient is 1.0.

#### Scenario: Tracked uphill
- **WHEN** a unit's Locomotor has `uphill_factor = 0.5` and it moves uphill
- **THEN** its speed is multiplied by 0.5

#### Scenario: Unknown locomotor id
- **WHEN** a unit uses a locomotor whose resource defines no slope factors
- **THEN** the slope coefficient is 1.0 (no error, no id-string match)

#### Scenario: Hover ignores slope
- **WHEN** a hover locomotor moves uphill
- **THEN** the slope coefficient is 1.0

### Requirement: Per-locomotor slope factors configured in data
The Tiberian Sun tracked and wheeled locomotors SHALL carry their slope factors in their `.tres` resources, preserving current behavior without a GlobalRules dependency.

#### Scenario: TS tracked values preserved
- **WHEN** `games/ts/locomotors/Track.tres` is loaded
- **THEN** `uphill_factor` is 0.5 and `downhill_factor` is 1.1

#### Scenario: TS wheeled values preserved
- **WHEN** `games/ts/locomotors/Wheel.tres` is loaded
- **THEN** `uphill_factor` is 0.5 and `downhill_factor` is 1.2
