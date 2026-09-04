## ADDED Requirements

### Requirement: Entity house ownership persists
Placed entities SHALL persist their owning house: `EditorSaveLoad` SHALL write `house_id` (one of "gdi", "nod", "neutral", "special") on each entity entry, and `MapLoader` SHALL pass it through to the placed entity. The legacy `player_id` integer SHALL remain a valid alias — entries carrying only `player_id` SHALL load unchanged, and `player_id` SHALL be kept in sync when writing.

#### Scenario: Round-trip house ownership
- **WHEN** an entity placed with house Nod is exported and the map reloaded
- **THEN** the entity entry carries `"house_id": "nod"` and the loaded entity records the Nod house

#### Scenario: Legacy player_id still loads
- **WHEN** a pre-existing map entry carries only `"player_id": 1`
- **THEN** the entity loads without error

#### Scenario: Writing keeps the alias
- **WHEN** the editor saves an entity with house_id "nod"
- **THEN** the JSON entry also contains a `player_id` compatible with older readers

### Requirement: Format v4 gains optional editor keys
The map JSON format version SHALL remain 4. The keys introduced by this change (`waypoints`, `cell_pins`, `house_id`) SHALL be optional: readers of any version MAY ignore unknown keys, and maps written before this change SHALL load unchanged. Re-saving a new-format map with an older build SHALL silently drop the optional keys — accepted at this stage.

#### Scenario: Version stays 4
- **WHEN** the editor exports a map with waypoints, cell pins, and house ownership
- **THEN** the JSON `"version"` field is still `4`

#### Scenario: Older build re-save drops keys
- **WHEN** a map containing the new keys is re-saved by a build predating this change
- **THEN** the output JSON omits them and remains valid version-4
