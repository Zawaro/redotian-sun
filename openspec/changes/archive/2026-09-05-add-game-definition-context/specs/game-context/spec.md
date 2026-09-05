## ADDED Requirements

### Requirement: GameDefinition resource
The system SHALL provide a `GameDefinition` resource class (`scripts/data/GameDefinition.gd`) with fields: `id: String`, `display_name: String`, `rules: GlobalRules` (the game's full rules resource — no override-merge machinery), `data_sets: PackedStringArray` (ordered layer roots consumed by EntityFactory, TerrainCatalog and AudioManager), and `maps_dir: String`. Each game SHALL have exactly one definition stored at `res://games/<id>/game.tres`, and the `id` SHALL match its directory name.

#### Scenario: TS game definition loads
- **WHEN** `res://games/ts/game.tres` is loaded as a GameDefinition
- **THEN** `id` is `"ts"`, `rules` is a valid GlobalRules instance, and `data_sets` contains `"res://games/ts/"` as a layer root

#### Scenario: Definition id must match directory
- **WHEN** a `game.tres` is discovered in `res://games/<dir>/` whose `id` differs from `<dir>`
- **THEN** discovery reports an error naming both and the def is skipped

### Requirement: GameContext autoload registered first
The system SHALL provide a `GameContext` autoload (`scripts/core/GameContext.gd`) registered as the **first** entry in `project.godot`'s `[autoload]` section, before every other autoload.

#### Scenario: First autoload
- **WHEN** the game boots
- **THEN** GameContext is instantiated before PlayerManager, EntityFactory, TerrainCatalog, AudioManager and all other autoloads, so consumers may read the resolved game in their `_ready()`

### Requirement: Active game resolution order
GameContext SHALL resolve the active game at startup in this order: the `--game <id>` command-line flag (recognized in both `OS.get_cmdline_args()` and `OS.get_cmdline_user_args()`), then the persisted setting (`[game] id` in `user://settings.cfg`), then the default `"ts"`. An unknown game id SHALL log a `push_error` naming the id and fall back to the next source in the order.

#### Scenario: CLI flag selects the game
- **WHEN** the game is launched with `--game ts`
- **THEN** `GameContext.current.id` is `"ts"`

#### Scenario: Persisted setting used when no flag
- **WHEN** no `--game` flag is present and `user://settings.cfg` contains `[game] id=ts`
- **THEN** `GameContext.current.id` is `"ts"`

#### Scenario: Default when nothing set
- **WHEN** no flag is present and no persisted setting exists
- **THEN** `GameContext.current.id` is `"ts"`

#### Scenario: Unknown id falls back
- **WHEN** `--game ra2` is passed but no `res://games/ra2/game.tres` exists
- **THEN** a `push_error` names `"ra2"` and the game falls back to the persisted setting or default

### Requirement: Game discovery
GameContext SHALL discover available games by scanning `res://games/*/game.tres`, exposing `list_games() -> Array[GameDefinition]`. A game directory without a `game.tres` SHALL be ignored.

#### Scenario: Enumerate games
- **WHEN** `res://games/` contains `ts/game.tres` and `empty/` (no `game.tres`)
- **THEN** `list_games()` returns exactly the `ts` definition

### Requirement: Select and unload lifecycle
GameContext SHALL expose `select_game(id: String)`. Selecting a game SHALL validate the definition exists, validate its rules, and emit `game_changed`. Consumers SHALL react to `game_changed` by resetting their content and re-registering from the game's `data_sets` layer roots; EntityFactory SHALL rebind its rules to the game's GlobalRules. GameContext SHALL NOT call consumers directly — the signal is the only coupling. `select_game("")` SHALL result in consumers resetting without re-registering (unload, used when exiting to a selection menu).

#### Scenario: Switching games reloads content
- **WHEN** `select_game("ra2")` is called after `"ts"` was active
- **THEN** consumers reset their caches, register only `ra2`'s layer roots, EntityFactory holds `ra2`'s rules, and `game_changed` was emitted

#### Scenario: Unload without re-register
- **WHEN** `select_game("")` is called
- **THEN** consumer caches are cleared, no data sets are registered, and `EntityFactory.get_entity_data` lookups return null

#### Scenario: Selecting an unknown id keeps the current game
- **WHEN** `select_game("nope")` is called and no such definition exists
- **THEN** a `push_error` names `"nope"` and the previously active game remains active

### Requirement: Consumers pull at startup
EntityFactory, TerrainCatalog and AudioManager SHALL register their data from `GameContext.current` in their own `_ready()` (not by listening for a boot-time signal, which fires before they exist), and SHALL connect to `game_changed` for runtime switches. GameContext SHALL be resolved before any consumer runs because it is the first autoload.

#### Scenario: Boot registers TS content with no hardcoded paths
- **WHEN** the game boots with the default game
- **THEN** EntityFactory, TerrainCatalog and AudioManager hold the `ts` rosters/registries, and none of their `_ready()` methods contains a hardcoded `res://games/` or `res://resources/` path

### Requirement: Active-game rules validation
On every `select_game(id)`, GameContext SHALL validate the game's rules using the existing `GlobalRules.validate_locomotor_keys()` and `validate_warhead_armor_keys()` helpers. A validation failure SHALL log a `push_error` naming the game and the offending keys, and SHALL refuse the selection.

#### Scenario: Valid rules select cleanly
- **WHEN** a game whose locomotor and warhead/armor references all resolve is selected
- **THEN** selection proceeds and `game_changed` is emitted

#### Scenario: Broken rules refuse selection
- **WHEN** a game's rules reference a locomotor id not in its registry
- **THEN** selection is refused with an error naming the game and the key, and the previous game stays active

### Requirement: Game choice persistence
GameContext SHALL read the persisted game id from `[game] id` in `user://settings.cfg` at startup and SHALL expose `save_game_choice(id: String)` that writes it back. Saving SHALL preserve all other sections and keys in the file.

#### Scenario: Save preserves other settings
- **WHEN** `save_game_choice("ra2")` is called on a settings file containing `[camera] edge_scroll_enabled=false` and keybind sections
- **THEN** the file contains `[game] id=ra2` and the camera and keybind entries are unchanged

### Requirement: Rules access contract
`GameContext` SHALL expose `current: GameDefinition` and `rules: GlobalRules` (the active game's rules). `GlobalRules.get_current()` SHALL keep its existing external contract — it resolves through the EntityFactory autoload, whose rules GameContext sets at select time. `EntityFactory.set_global_rules()` SHALL continue to override the rules for testing.

#### Scenario: get_current reflects the active game
- **WHEN** `select_game("ra2")` completes
- **THEN** `GlobalRules.get_current()` returns the same GlobalRules instance as `GameContext.current.rules`

#### Scenario: Test monkeypatch still works
- **WHEN** a test calls `EntityFactory.set_global_rules(custom_rules)`
- **THEN** `GlobalRules.get_current()` returns `custom_rules` until the next select or restore

### Requirement: Per-game boot smoke
For every discovered GameDefinition, the system SHALL support an in-process boot rehearsal: `select_game(id)` registers a non-empty entity roster and the game's rules validate. This SHALL be exercised per game by tests so each new game definition is verified the moment it is added.

#### Scenario: Each present game boots
- **WHEN** the smoke test iterates `list_games()` and selects each game in turn (restoring `ts` after)
- **THEN** every selection ends with a non-empty EntityFactory roster, valid rules, and a non-empty TerrainCatalog theater registry
