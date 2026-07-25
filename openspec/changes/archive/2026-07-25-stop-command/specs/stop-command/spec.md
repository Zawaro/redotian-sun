## ADDED Requirements

### Requirement: Stop command halts all selected unit activity
The system SHALL provide a Stop command (Ctrl+S) that immediately halts all activity for selected units, including movement and harvesting.

#### Scenario: Stop during movement
- **WHEN** a unit is moving along a path and the player issues the Stop command
- **THEN** the unit continues moving to the next cell center in its movement direction and stops there

#### Scenario: Stop during rotation
- **WHEN** a unit is rotating to face its movement direction and the player issues the Stop command
- **THEN** the unit immediately stops rotating and becomes idle at its current position

#### Scenario: Stop during harvesting
- **WHEN** a harvester is harvesting a resource cell and the player issues the Stop command
- **THEN** the harvester cancels harvesting, releases the resource cell, and becomes idle

#### Scenario: Stop when idle
- **WHEN** a unit is already idle and the player issues the Stop command
- **THEN** the unit remains idle (no-op)

### Requirement: Units stop at valid cell positions
The system SHALL ensure units stop at valid cell center positions, not mid-path between cells.

#### Scenario: Unit near cell center when stopped
- **WHEN** a moving unit is within 0.1 units of a cell center and the Stop command is issued
- **THEN** the unit stops at that cell center

#### Scenario: Unit far from cell center when stopped
- **WHEN** a moving unit is more than 0.1 units from the next cell center and the Stop command is issued
- **THEN** the unit continues moving to the next cell center in its movement direction and stops there

### Requirement: Stop is overridden by new orders
The system SHALL cancel the stop state when a new move order is issued to the unit.

#### Scenario: New move order during stop
- **WHEN** a unit is in the process of stopping (moving to cell center) and the player issues a new move order
- **THEN** the stop is cancelled and the unit proceeds with the new move order

### Requirement: Stop command works on groups
The system SHALL apply the Stop command to all selected entities simultaneously.

#### Scenario: Stop group of units
- **WHEN** multiple units are selected and the player issues the Stop command
- **THEN** each selected unit independently stops at the next cell center in its movement direction
