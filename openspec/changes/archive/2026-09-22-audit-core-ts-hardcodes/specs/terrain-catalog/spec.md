## ADDED Requirements

### Requirement: Terrain fallback declared per game
`TerrainCatalog` SHALL obtain its fallback terrain scene from the active `GameDefinition` (`fallback_terrain_scene`), not a hardcoded `res://games/ts/...` path. When no fallback is declared, missing theater art SHALL warn and return null rather than loading another game's asset.

#### Scenario: Declared fallback
- **WHEN** the active game declares a fallback terrain scene
- **THEN** missing theater art resolves to that scene

#### Scenario: No fallback
- **WHEN** the active game declares no fallback and theater art is missing
- **THEN** the catalog warns, returns null, and does not load a TS asset
