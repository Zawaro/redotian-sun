## ADDED Requirements

### Requirement: Entity revealer centered on the owner's footprint

A player-owned entity's revealer SHALL be registered around that entity's own footprint center cell. When an entity's footprint is larger than 1×1, the center cell SHALL be a cell inside the entity's footprint (`foundation` cells) and SHALL NOT be offset by any part of the footprint. A building's revealer SHALL register once the entity has an assigned player and SHALL remain registered, unmoved, until the entity leaves the tree (death or sell), so its sight radius stays revealed for the building's lifetime.

#### Scenario: Multi-cell building reveal is centered on its footprint

- **WHEN** a building whose foundation is larger than 1×1 is placed and its revealer registers
- **THEN** the reveal disc is centered on a cell inside the building's footprint, and the building's own cells within its sight radius are visible

#### Scenario: Building reveal is symmetric

- **WHEN** a building is placed on open terrain and no other revealer is present
- **THEN** cells at equal distance on opposite sides of the footprint resolve to the same visibility (no diagonal offset of the reveal disc)

#### Scenario: Building reveal persists while alive

- **WHEN** a placed building remains alive after registering
- **THEN** its revealer stays registered and covered cells do not revert to shroud

#### Scenario: Single-cell entities keep their cell center

- **WHEN** a 1×1 entity (unit) registers a revealer
- **THEN** the revealer is centered on the entity's own cell, unchanged by this requirement
