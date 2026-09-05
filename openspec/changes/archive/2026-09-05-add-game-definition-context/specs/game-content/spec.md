## ADDED Requirements

### Requirement: Per-game content layout
All per-game content SHALL live under `res://games/<id>/`: the game definition (`game.tres`), the game's `global_rules.tres`, data subdirectories (`entities/`, `audio/`, `terrain_objects/`, `art/terrain/`, `theaters/`, `weapons/`, `factions/`, armor/land/locomotor/projectile/resource/warhead type directories), and the game's owned assets under `res://games/<id>/assets/`. Shared shell assets SHALL remain in `res://assets/`: `fonts/`, `hdri/`, and `cursors/placeholders/`. For Tiberian Sun this means all former `res://resources/*` content and the TS-owned `assets/` subdirs (`models/`, `textures/`, `resources/` materials, `cameos/`, `ui/`, `test_map01.json`, `test_terrain.json`) now live under `res://games/ts/`.

#### Scenario: TS content resolves from its new home
- **WHEN** the game boots with the default game
- **THEN** every former `res://resources/` data id (entities, terrain, theaters, audio, rules registries) resolves from `res://games/ts/`, and TS-owned art references (models, cameos, menu UI) resolve from `res://games/ts/assets/`

#### Scenario: Shared shell assets stay put
- **WHEN** the main menu and world environment load
- **THEN** fonts, HDRI and placeholder cursors resolve from `res://assets/` unchanged

### Requirement: Data sets are ordered layer roots
`GameDefinition.data_sets` SHALL hold ordered `res://` directory roots. Each consumer SHALL append its known subdirectory names to every root when registering (EntityFactory: `entities/`; AudioManager: `audio/`; TerrainCatalog: `terrain_objects/`, `art/terrain/`, `theaters/`), registering roots in list order. A missing subdirectory under a root SHALL warn and continue, not fail the boot.

#### Scenario: Consumer subdir conventions hold per root
- **WHEN** a GameDefinition with two layer roots is selected
- **THEN** EntityFactory registers `<root1>entities/` and `<root2>entities/`, and TerrainCatalog registers the three terrain subdirs under both roots, in order

#### Scenario: Missing subdir warns without crashing
- **WHEN** a layer root does not contain an `audio/` subdirectory
- **THEN** AudioManager logs a warning for that root and the rest of the boot proceeds

### Requirement: Last-wins layering
When the same resource id is registered more than once across a game's ordered layer roots, the registration from the later root SHALL win in every consumer cache. This is the layering mechanism for shared → game → expansion stacks.

#### Scenario: Later root overrides an id
- **WHEN** `E1` is defined in both `shared-layer` and `game-layer`, and the game's `data_sets` is `[shared, game]`
- **THEN** `EntityFactory.get_entity_data("E1")` returns the game-layer definition

#### Scenario: Non-overlapping ids merge
- **WHEN** two layer roots define disjoint id sets
- **THEN** the consumer cache contains ids from both roots

### Requirement: Borrowing via layer roots
A game MAY include another game's directory root in its `data_sets` to borrow content. Borrowed ids MUST follow the same last-wins ordering as any other layer.

#### Scenario: Borrowed content registers
- **WHEN** a game `expansion` lists `res://games/ts/` before its own root
- **THEN** ids present only in the `ts` root resolve, and same-id entries from `expansion`'s own root win

### Requirement: Cross-game id collision validation
The system SHALL provide a validator that, given two or more game definitions' data-set roots, detects the same entity id being defined in directories belonging to different games that do not share that content via layering. A collision SHALL produce an error naming both games and the id. The validator SHALL run on demand (tests and tooling), never as part of every boot.

#### Scenario: Sibling games claiming the same id
- **WHEN** game `a` and game `b` both define entity id `X` in their own (non-borrowed) roots and the validator runs over both
- **THEN** it reports an error naming `a`, `b`, and `X`

#### Scenario: Borrowed content is not a collision
- **WHEN** game `b`'s `data_sets` includes game `a`'s root and both "define" `X` through that shared dir
- **THEN** the validator reports no collision

#### Scenario: Boot does not scan other games
- **WHEN** the game boots with only one game selected
- **THEN** no content from other `res://games/` directories is loaded
