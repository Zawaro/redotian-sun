## 1. Faction resource and TS data

- [x] 1.1 Add `@export var order: int = 0` and `@export var playable: bool = true` to `scripts/data/Faction.gd`
- [x] 1.2 Set `order = 0`, `playable = true` in `games/ts/factions/gdi.tres` and `order = 1`, `playable = true` in `games/ts/factions/nod.tres`
- [x] 1.3 Add `games/ts/factions/neutral.tres` (`order = 2`, `playable = false`, existing neutral color) and `special.tres` (`order = 3`, `playable = false`, a grey/other color)
- [x] 1.4 Verify no gameplay logic lives under `games/` — new files are faction data only

## 2. FactionCatalog autoload

- [x] 2.1 Create `scripts/core/FactionCatalog.gd` with a `Dictionary` cache, `_data_sets`, `register_data_set(path)`, recursive `.tres`/`.remap` `_scan_directory`, `get_faction(id)`, `reset_content()`, `_load_from_context()`, and `_on_game_changed`
- [x] 2.2 In `_load_from_context()`, register `root.trim_suffix("/") + "/factions/"` for each `GameContext.current.data_sets` root, last root wins
- [x] 2.3 Add `get_ordered() -> Array[Faction]` (ascending `order`, tie-break by `id`) and `get_playable() -> Array[Faction]`; add a `ponytail:` note at the scan pointing at a future shared scanner
- [x] 2.4 Apply the roster to `Houses` on load and clear it on reset (see 3.2)
- [x] 2.5 Register `FactionCatalog` in `project.godot` immediately after `GameContext` and before `PlayerManager`, with an ordering comment

## 3. Houses projection

- [x] 3.1 Convert `Houses.IDS`/`DISPLAY_NAMES` from constants to static state and add an ordered-id accessor plus `apply_roster(factions)` / `clear_roster()`
- [x] 3.2 Have `Houses` build its ids and display names from `Faction` `id`/`display_name` in ascending `order`; document the empty-roster fallback (`id_for` → `""`, `index_for` → `-1`)
- [x] 3.3 Update `MapLoader` and `EditorSaveLoad` to use the new accessor / helpers instead of reading `Houses.IDS` directly
- [x] 3.4 Grep the repo for `Houses.IDS` / `Houses.DISPLAY_NAMES` and confirm no direct-const readers remain

## 4. Player and sidebar consumers

- [x] 4.1 In `PlayerManager._init_defaults()`, select the first two playable factions from `FactionCatalog` and build player 0/1 with their ids and colors; empty/one-faction fallback uses `""` and `Color.WHITE`
- [x] 4.2 Replace `PlayerManager._get_global_rules()`'s `/root/EntityFactory` lookup with `GameContext.rules`
- [x] 4.3 In `Sidebar._get_cameo_color()`, resolve the tint from `FactionCatalog` by matching `EntityData.owner` against faction ids; fall back to `Color.GRAY`; remove `CAMEO_COLORS`

## 5. Tests

- [x] 5.1 Add faction fixtures under `test/fixtures/` (non-game-specific ids, mixed `order` and `playable`) and a `factions/` subdir under the `gamectx` layer-root fixtures
- [x] 5.2 Add `test/unit/test_faction_catalog.gd`: populates from a temp data root, last-wins override, ordered roster, playable filter, missing-dir warning, reset on game switch/unload
- [x] 5.3 Update `test/unit/test_houses.gd` to apply a fixture roster and assert id/index/display-name projection, ordered index, unknown id, and empty-roster fallback
- [x] 5.4 Update `test/unit/test_player_manager.gd` to assert the default roster picks the first two playable fixture factions with their colors, and the empty-registry fallback
- [x] 5.5 Extend `test/unit/test_game_content.gd` to assert `FactionCatalog` registers `<root>/factions/` per layer root
- [x] 5.6 Assert the active roster ids cover the shipped `EntityData.owner` vocabulary (casing contract)

## 6. Verification

- [x] 6.1 Run `redot --headless -s test/run_tests.gd` and confirm all tests pass
- [x] 6.2 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`; after `gdformat`, check for tab introduction in multi-line strings
- [x] 6.3 Boot the default game and confirm player 0/1 ids and colors, sidebar cameo tints, and map-editor house dropdowns all come from the TS faction resources with no GDI/Nod literals in engine scripts
