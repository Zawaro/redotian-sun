## 1. Core: GameDefinition + GameContext

- [x] 1.1 Create `scripts/data/GameDefinition.gd` Resource class: `id`, `display_name`, `rules: GlobalRules`, `data_sets: PackedStringArray`, `maps_dir` (per spec game-context; no `features` field)
- [x] 1.2 Create `scripts/core/GameContext.gd` autoload: game discovery (`res://games/*/game.tres`, id = dir name, mismatch = error+skip), `list_games()`, `current`, `rules`
- [x] 1.3 Implement resolution order in GameContext `_ready()`: `--game` in both `OS.get_cmdline_args()` and `OS.get_cmdline_user_args()` → `[game] id` in `user://settings.cfg` → `"ts"`; unknown id = `push_error` + fall through
- [x] 1.4 Implement `select_game(id)` lifecycle: validate def, validate rules (`validate_locomotor_keys`, `validate_warhead_armor_keys`), `reset_content()` on consumers, register layer roots, rebind EntityFactory rules, emit `game_changed`; `select_game("")` = reset only; unknown id = error, keep current
- [x] 1.5 Implement `save_game_choice(id)` writing `[game] id` to `user://settings.cfg` preserving other sections
- [x] 1.6 Register GameContext as first autoload in `project.godot` with a `; why` comment; commit `.gd.uid` files

## 2. Consumer wiring

- [x] 2.1 EntityFactory: drop hardcoded dirs/rules from `_ready()`, pull registration from `GameContext.current` (subdir `entities/` per root), load rules from game def, connect `game_changed`
- [x] 2.2 TerrainCatalog: drop three hardcoded dirs, register `terrain_objects/`, `art/terrain/`, `theaters/` per layer root from GameContext, connect `game_changed`
- [x] 2.3 AudioManager: drop `DEFAULT_DATA_PATH`, register `audio/` per layer root from GameContext, connect `game_changed`
- [x] 2.4 Add `reset_content()` to all three consumers: clear caches + `_data_sets` (+ TerrainCatalog `_terrain_scene`/`_active_theater`); keep `register_data_set()` public API and idempotency intact
- [x] 2.5 AssetPreviewController: replace hardcoded `THEATER_PATH` (`res://resources/theaters/temperate.tres`) with the game-specific `TerrainCatalog.get_theater("temperate")` registry lookup — no test covers this dev tool, verify via the asset preview scene

## 3. Content move

- [x] 3.1 Create `games/ts/game.tres` (id `ts`, display name, rules → `games/ts/global_rules.tres`, `data_sets = ["res://games/ts/"]`)
- [x] 3.2 `git mv resources/* → games/ts/` (entities, art, audio, factions, armor_types, land_types, locomotors, projectiles, resource_types, terrain_objects, theaters, warheads, weapons, global_rules.tres) including `.uid` files
- [x] 3.3 `git mv` TS-owned assets → `games/ts/assets/`: `models/`, `textures/`, `resources/`, `cameos/`, `ui/` (both images), `test_map01.json`, `test_terrain.json` — with `.import` sidecars; leave `fonts/`, `hdri/`, `cursors/` in place
- [x] 3.4 Rewrite `source_file=` inside moved `.import` sidecars and run headless `--import` to regenerate dest hashes
- [x] 3.5 Rewrite `res://resources/` → `res://games/ts/` across all `.tres` (incl. internal ext_resource paths), scripts and tests; rewrite moved-asset prefixes (`models|textures|resources|cameos|ui|test_map`) in `.tres`, scenes (`MainMenu01*.tscn`, `NodBuggy.tscn`, `GDIConyard01.tscn`, `TestMap*.tscn`) and scripts/tests; update `ArtData.gd` docstring example
- [x] 3.6 Verify zero remaining references: `rg "res://resources/"` returns nothing (outside openspec/plans docs), moved-asset prefix grep clean, full headless boot reaches main menu

## 4. Validation

- [x] 4.1 Wire active-game rules validation into `select_game` with refusal + error naming game and keys
- [x] 4.2 Implement cross-game entity-id collision validator (static, over defs' layer roots, error names both games and id; borrowed roots excluded)

## 5. Tests

- [x] 5.1 `run_tests.gd`: inject `_gc` (GameContext) shorthand alongside existing autoload vars
- [x] 5.2 `test_game_context.gd`: discovery (list_games, id/dir mismatch, missing game.tres ignored), resolution order (CLI flag both arg lists, persisted, default, unknown fallback), select lifecycle (roster swap, rules rebind, `game_changed` emitted, unknown id keeps current, `select_game("")` unloads), `get_current()` contract + `set_global_rules` monkeypatch, persistence round-trip preserving `[camera]`/other sections
- [x] 5.3 `test_game_content.gd`: consumer subdir conventions per root, missing subdir warns without crash, last-wins layering (fixture dirs), borrowing (another game's root first), collision validator (siblings collide naming both; borrowed = no collision; boot loads no other games' content)
- [x] 5.4 Reset-cycle completeness test: repeated select/reset across all three consumers leaves no stale cache state (roster, audio ids, theater)
- [x] 5.5 Per-game boot smoke test: for each `list_games()` def, select → non-empty EntityFactory roster + valid rules + non-empty theater registry, restore `ts` after
- [x] 5.6 Update existing suites for new paths only (global_rules, land_type, projectile_registry, projectile_data, audio_manager, terrain, sidebar_cameo, art_component, asset_preview, theater_data, etc.) — no behavior/expectation changes

## 6. Docs

- [x] 6.1 GLOSSARY.md: add *game definition*, *GameContext*, *data set*, *layering (last-wins)*; check Undecided section
- [x] 6.2 AGENTS.md: autoload table + GameContext (first), folder structure gains `games/` (per-game content) and `assets/` ownership note, update "22/24 autoloads" counts

## 7. Verification

- [x] 7.1 Full suite green: `redot --headless -s test/run_tests.gd` (existing tests unchanged in behavior)
- [x] 7.2 `gdlint` + `gdformat --check` on new/modified scripts; tab-check grep after gdformat
- [x] 7.3 Manual: `--game ts` boots identical session (roster, terrain, audio); `--game bogus` errors and falls back to TS; exit-to-menu path of `select_game("")` leaves no errors in log; asset preview scene resolves its theater
- [x] 7.4 `openspec validate add-game-definition-context` passes
