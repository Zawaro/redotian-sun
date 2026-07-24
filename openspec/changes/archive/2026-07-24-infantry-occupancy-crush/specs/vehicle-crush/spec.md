## ADDED Requirements

### Requirement: Vehicle crush on cell entry
The system SHALL kill enemy crushable infantry when a crusher vehicle steps onto their cell. Crush SHALL happen on cell transition during movement, not as a combat action. Crush SHALL always succeed — there is no dodge or survival chance.

#### Scenario: Crusher kills enemy infantry
- **WHEN** a vehicle with `crusher = true` moves onto a cell containing enemy infantry with `crushable = true`
- **THEN** all enemy crushable infantry on that cell are killed via `HealthComponent.kill()`

#### Scenario: Crusher does not kill friendly infantry
- **WHEN** a vehicle with `crusher = true` moves onto a cell containing friendly infantry
- **THEN** no infantry are killed (the `get_crushable_enemies_on_cell()` method filters by player_id)

#### Scenario: Non-crusher does not crush
- **WHEN** a vehicle with `crusher = false` moves onto a cell containing enemy infantry
- **THEN** no infantry are killed

#### Scenario: Crush does not affect non-crushable infantry
- **WHEN** a vehicle with `crusher = true` moves onto a cell containing enemy infantry with `crushable = false`
- **THEN** no infantry are killed

### Requirement: Crusher vehicle data flags
The system SHALL read `crusher` and `crushable` properties from EntityData at runtime via StatsComponent. These flags SHALL be set on `.tres` resource files according to the original Tiberian Sun rules.ini.

#### Scenario: Crusher flag propagated
- **WHEN** a vehicle EntityData has `crusher = true`
- **THEN** the vehicle's StatsComponent exposes `crusher = true` at runtime

#### Scenario: Crushable flag propagated
- **WHEN** an infantry EntityData has `crushable = true`
- **THEN** the infantry's StatsComponent exposes `crushable = true` at runtime
