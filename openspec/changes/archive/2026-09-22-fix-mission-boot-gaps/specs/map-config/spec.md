## ADDED Requirements

### Requirement: MapConfig from map JSON
`MissionMap` SHALL read a map JSON's optional top-level `players` array (entries mirroring
`MapConfig.PlayerConfig`) and SHALL materialize it as a `MapConfig` node attached to the mission
map; an absent or empty array SHALL leave the map with no config.

#### Scenario: Players array materialized
- **WHEN** a mission map JSON carries a top-level `players` array with one entry
- **THEN** the mission map has a `MapConfig` child whose `players` holds that entry

#### Scenario: No players array leaves no config
- **WHEN** a mission map JSON has no `players` array (or an empty one)
- **THEN** the mission map has no `MapConfig` child
