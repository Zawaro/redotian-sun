## MODIFIED Requirements

### Requirement: Stop command halts all selected unit activity
The system SHALL provide a Stop command (Ctrl+S) that immediately halts all activity for selected units, including movement, harvesting, and in-progress transport unloading.

#### Scenario: Stop during movement
- **WHEN** a unit is moving along a path and the player issues the Stop command
- **THEN** the unit continues moving to the next cell center in its movement direction and stops there

#### Scenario: Stop with no path
- **WHEN** a unit has just started moving (no waypoints computed yet) and the player issues the Stop command
- **THEN** the unit stops immediately at its current position

#### Scenario: Stop during rotation
- **WHEN** a unit is rotating to face its movement direction and the player issues the Stop command
- **THEN** the unit immediately stops rotating and becomes idle at its current position

#### Scenario: Stop during harvesting
- **WHEN** a harvester is harvesting a resource cell and the player issues the Stop command
- **THEN** the harvester cancels harvesting, releases the resource cell, and becomes idle

#### Scenario: Stop during combat
- **WHEN** a unit is firing at an enemy and the player issues the Stop command
- **THEN** the unit stops firing and becomes idle (does not chase)

#### Scenario: Stop during dock transition
- **WHEN** a harvester is docking at a refinery and the player issues the Stop command
- **THEN** the harvester cancels docking and becomes idle

#### Scenario: Stop during unload
- **WHEN** a transport is ejecting passengers and the player issues the Stop command
- **THEN** the eject sequence cancels and remaining passengers stay aboard

#### Scenario: Stop on transported entity
- **WHEN** a unit inside a transport receives the Stop command
- **THEN** the command is ignored (unit is not visible or controllable)

#### Scenario: Stop when idle
- **WHEN** a unit is already idle and the player issues the Stop command
- **THEN** the unit remains idle (no-op)
