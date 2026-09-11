## ADDED Requirements

### Requirement: EntityData death sound reference
`EntityData` SHALL include an optional `sound_die: String` export (default `""`) holding a comma-separated list of audio ids played on death when the entity has no die voice set. The field SHALL be independent of `voice_data`; an entity may define either, both, or neither. An empty `sound_die` SHALL be valid and play nothing.

#### Scenario: EntityData exposes sound_die
- **WHEN** an EntityData resource is authored with `sound_die = "EXPNEW05"`
- **THEN** the resource exposes the value for the death handler

#### Scenario: Default is silent
- **WHEN** an EntityData resource omits `sound_die`
- **THEN** the field defaults to `""` and the entity plays no death sound unless it has a die voice
