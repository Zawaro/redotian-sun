## ADDED Requirements

### Requirement: TransportComponent signals
The TransportComponent SHALL emit signals when cargo or passenger state changes, enabling real-time UI updates.

#### Scenario: Cargo changes emit signal
- **WHEN** `add_cargo()` or `remove_cargo()` is called on TransportComponent
- **THEN** the component emits `cargo_changed(current: int, capacity: int, type_id: String)` with the updated total cargo, resource capacity, and affected type ID

#### Scenario: Passenger changes emit signal
- **WHEN** `add_passenger()` or `remove_passenger()` is called on TransportComponent
- **THEN** the component emits `passenger_changed(current: int, max_passengers: int)` with the updated count and max capacity

### Requirement: TransportComponent passenger tracking
The TransportComponent SHALL track current passenger count in addition to max capacity.

#### Scenario: Add passenger
- **WHEN** `add_passenger()` is called and `current_passengers < passengers`
- **THEN** `current_passengers` increments by 1 and returns true

#### Scenario: Add passenger when full
- **WHEN** `add_passenger()` is called and `current_passengers >= passengers`
- **THEN** returns false, no state change

#### Scenario: Remove passenger
- **WHEN** `remove_passenger()` is called and `current_passengers > 0`
- **THEN** `current_passengers` decrements by 1 and returns true

#### Scenario: Remove passenger when empty
- **WHEN** `remove_passenger()` is called and `current_passengers <= 0`
- **THEN** returns false, no state change

### Requirement: SelectComponent cargo pips
The SelectComponent SHALL display cargo pips below the vehicle selection rectangle when the entity has a TransportComponent with `resource_capacity > 0`.

#### Scenario: Cargo pips created on selection
- **WHEN** a Vehicle-type SelectComponent is selected and the parent entity has a TransportComponent with `resource_capacity > 0`
- **THEN** up to 5 pip pairs (outline + fill) appear in a horizontal row below the selection box

#### Scenario: Cargo pips show fill level
- **WHEN** TransportComponent cargo total is 50% of resource_capacity
- **THEN** 3 of 5 pips are filled (rounded from 50% × 5 = 2.5 → 3), remaining 2 are dark gray

#### Scenario: Cargo pip color from ResourceType
- **WHEN** TransportComponent has cargo of type "tiberium_green"
- **THEN** filled pips use the `ResourceType.color` for "tiberium_green" (green)

#### Scenario: Cargo pips update in real-time
- **WHEN** HarvestComponent collects tiberium and TransportComponent emits `cargo_changed`
- **THEN** SelectComponent updates pip fill count and colors immediately

#### Scenario: Cargo pips hidden when not selected
- **WHEN** the entity is deselected
- **THEN** all cargo pips become invisible (handled by SelectComponent `_update_visibility()`)

### Requirement: SelectComponent passenger pips
The SelectComponent SHALL display passenger pips below the vehicle selection rectangle when the entity has a TransportComponent with `passengers > 0`.

#### Scenario: Passenger pips created
- **WHEN** a Vehicle-type SelectComponent is selected and the parent entity has a TransportComponent with `passengers > 0`
- **THEN** up to 5 pip pairs appear in a row below the selection box (or below cargo pips if present)

#### Scenario: Passenger pips show occupancy
- **WHEN** TransportComponent has 2 of 4 passengers
- **THEN** 2 pips are white (occupied), 2 are dark gray (empty)

#### Scenario: Passenger pips update in real-time
- **WHEN** TransportComponent emits `passenger_changed`
- **THEN** SelectComponent updates pip fill count immediately

### Requirement: Pip visual style
Each pip SHALL consist of two overlapping QuadMesh instances: a black outline quad (0.15 × 0.15) behind a colored fill quad (0.12 × 0.12). Both quads SHALL use `BILLBOARD_FIXED_Y`, `no_depth_test = true`, and `SHADING_MODE_UNSHADED`.

#### Scenario: Pip outline always visible
- **WHEN** a pip is displayed (filled or empty)
- **THEN** the black outline quad is always visible

#### Scenario: Pip fill color changes
- **WHEN** cargo/passenger state changes
- **THEN** only the fill quad's `albedo_color` changes (outline remains black)

### Requirement: Pip positioning
Pips SHALL be positioned in a horizontal row centered below the vehicle selection box. The row Y position SHALL be below the L-shaped corner lines. X spacing SHALL be `PIP_OUTLINE_SIZE * 1.5` between pip centers.

#### Scenario: Pips centered below selection box
- **WHEN** a vehicle with cargo is selected
- **THEN** the pip row is centered horizontally on the selection box and positioned below the bottom corner lines
