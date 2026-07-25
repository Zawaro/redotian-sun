## ADDED Requirements

### Requirement: Track player-owned buildings
The system SHALL maintain a count of each building type owned by each player. When a building is placed, its count increments. When a building is destroyed (future), its count decrements.

#### Scenario: Building placed
- **WHEN** a building with entity_id "FACT" is placed for player 0
- **THEN** the system records player 0 owns 1× "FACT"

#### Scenario: Multiple buildings of same type
- **WHEN** player 0 places 3× "FACT" buildings
- **THEN** the system records player 0 owns 3× "FACT"

### Requirement: Check OR prerequisites
The system SHALL check `EntityData.prerequisite` with OR logic. If any prerequisite building is owned, the check passes.

#### Scenario: Has one prerequisite
- **WHEN** entity requires prerequisite ["BARR"]
- **AND** player owns "BARR"
- **THEN** `can_build()` returns true

#### Scenario: Has no prerequisite
- **WHEN** entity requires prerequisite ["BARR"]
- **AND** player does not own "BARR"
- **THEN** `can_build()` returns false

#### Scenario: Empty prerequisite list
- **WHEN** entity has empty prerequisite list
- **THEN** `can_build()` returns true (no prerequisite gate)

### Requirement: Check AND prerequisites
The system SHALL check `EntityData.prerequisite_necessary` with AND logic. All prerequisite buildings must be owned.

#### Scenario: Has all necessary prerequisites
- **WHEN** entity requires necessary prerequisites ["BARR", "RADAR"]
- **AND** player owns both "BARR" and "RADAR"
- **THEN** `can_build()` returns true

#### Scenario: Missing one necessary prerequisite
- **WHEN** entity requires necessary prerequisites ["BARR", "RADAR"]
- **AND** player owns "BARR" but not "RADAR"
- **THEN** `can_build()` returns false

### Requirement: Enforce build limits
The system SHALL enforce `EntityData.build_limit`. If the player owns or has in queue `build_limit` units of this entity, `can_build()` returns false. A build_limit of 0 means unlimited.

#### Scenario: Under build limit
- **WHEN** entity has build_limit=5
- **AND** player has 3 of this entity
- **THEN** `can_build()` returns true

#### Scenario: At build limit
- **WHEN** entity has build_limit=5
- **AND** player has 5 of this entity
- **THEN** `can_build()` returns false

#### Scenario: Unlimited build limit
- **WHEN** entity has build_limit=0
- **THEN** `can_build()` returns true regardless of count

### Requirement: Emit signal on prerequisite change
The system SHALL emit `prerequisites_changed(player_id)` whenever a building is registered or unregistered, so the sidebar can refresh.

#### Scenario: Signal emitted on building placed
- **WHEN** a building is registered for player 0
- **THEN** `prerequisites_changed(0)` is emitted

### Requirement: Debug cheat bypass
When the debug menu's `no_prereqs` flag is active, `can_build()` SHALL bypass all prerequisite, build limit, and factory checks, always returning true.

#### Scenario: Debug mode active
- **WHEN** `debug_menu.no_prereqs == true`
- **AND** entity has unmet prerequisites
- **THEN** `can_build()` returns true

#### Scenario: Debug mode inactive
- **WHEN** `debug_menu.no_prereqs == false` or debug menu does not exist
- **THEN** `can_build()` applies normal prerequisite checks

### Requirement: Query build count
`get_build_count(player_id, entity_id)` SHALL return the number of buildings of the given entity_id owned by the player, or 0 if none.

#### Scenario: Has buildings
- **WHEN** player 0 owns 3× "FACT"
- **THEN** `get_build_count(0, "FACT")` returns 3

#### Scenario: Has no buildings
- **WHEN** player 0 owns no "FACT"
- **THEN** `get_build_count(0, "FACT")` returns 0

### Requirement: Factory ownership check
The system SHALL verify the player owns at least one building whose `factory` field matches the entity's `buildable_queue`. If the entity has no `buildable_queue`, this check is skipped.

#### Scenario: Has matching factory
- **WHEN** entity has `buildable_queue = "infantry"`
- **AND** player owns a building with `factory = "infantry"`
- **THEN** `can_build()` passes the factory check

#### Scenario: No matching factory
- **WHEN** entity has `buildable_queue = "infantry"`
- **AND** player owns no building with `factory = "infantry"`
- **THEN** `can_build()` returns false

#### Scenario: No buildable queue
- **WHEN** entity has empty `buildable_queue`
- **THEN** factory check is skipped
