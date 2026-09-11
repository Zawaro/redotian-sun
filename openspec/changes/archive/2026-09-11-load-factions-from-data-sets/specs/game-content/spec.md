## MODIFIED Requirements

### Requirement: Data sets are ordered layer roots
`GameDefinition.data_sets` SHALL hold ordered `res://` directory roots. Each consumer SHALL append its known subdirectory names to every root when registering (EntityFactory: `entities/`; AudioManager: `audio/`; TerrainCatalog: `terrain_objects/`, `art/terrain/`, `theaters/`; FactionCatalog: `factions/`), registering roots in list order. A missing subdirectory under a root SHALL warn and continue, not fail the boot.

#### Scenario: Consumer subdir conventions hold per root
- **WHEN** a GameDefinition with two layer roots is selected
- **THEN** EntityFactory registers `<root1>entities/` and `<root2>entities/`, TerrainCatalog registers the three terrain subdirs under both roots, and FactionCatalog registers `<root1>factions/` and `<root2>factions/`, in order

#### Scenario: Missing subdir warns without crashing
- **WHEN** a layer root does not contain an `audio/` subdirectory
- **THEN** AudioManager logs a warning for that root and the rest of the boot proceeds
