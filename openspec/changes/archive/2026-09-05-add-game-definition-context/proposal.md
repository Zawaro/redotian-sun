# Add Game Definition Context

## Why

The project is hardwired to Tiberian Sun: EntityFactory, TerrainCatalog and AudioManager hardcode their TS data directories in `_ready()`, there is a single `resources/global_rules.tres`, and all of `resources/` plus most of `assets/` is TS content. Supporting the four standalone games (TS, Firestorm, RA2, Yuri's Revenge) on one shared core (#374) requires a game-selection layer before any second game's content can exist. This change lands that layer now, while only TS content exists, so the migration is a mechanical one-time move instead of a cross-cutting rewrite later.

## What Changes

- **BREAKING** — content restructure: all TS data moves from `res://resources/*` to `res://games/ts/*` (1094 `.tres`), and TS-owned assets (`models/`, `textures/`, `resources/` materials, `cameos/`, `ui/`, `test_*.json`) move to `res://games/ts/assets/`. Shared shell assets (`assets/fonts/`, `assets/hdri/`, `assets/cursors/placeholders/`) stay put. All internal `res://` references are rewritten (~432 `.tres` files, ~19 scripts/tests, several `.tscn` scenes).
- New `GameDefinition` resource (`scripts/data/GameDefinition.gd`): `id`, `display_name`, `rules: GlobalRules` (full per-game resource, no merge machinery), `data_sets: PackedStringArray` (ordered layer roots, last-wins id registration), `maps_dir`.
- New `GameContext` autoload (`scripts/core/GameContext.gd`), registered **first** in `project.godot`: discovers defs at `res://games/*/game.tres`, resolves the active game (`--game` CLI flag → persisted setting → `"ts"`), drives select/unload lifecycle via `select_game(id)` + `game_changed`, persists the choice to `user://settings.cfg`.
- EntityFactory, TerrainCatalog and AudioManager drop hardcoded directories, register their data from GameContext layer roots at select time (consumer subdir conventions preserved), gain `reset_content()` for game switches, and rebind on `game_changed`. `GlobalRules.get_current()` external contract unchanged — it continues to resolve through EntityFactory, whose rules now come from the active game.
- Validation: active-game rules validated at select time via the existing `validate_locomotor_keys`/`validate_warhead_armor_keys` helpers; a cross-game entity-id collision validator (runs on demand — not at boot, see design deviation note — names both games) guards content authoring.
- Tests: `run_tests.gd` injects `_gc` (GameContext); new suites for resolution order, layering, collisions, reset cycles and a per-game boot smoke test; existing suite keeps passing unchanged with the TS default.
- GLOSSARY.md and AGENTS.md updated for the new terms and layout.

## Capabilities

### New Capabilities
- `game-context`: game selection and lifecycle — GameDefinition resource shape, GameContext autoload, resolution order, select/unload semantics, persistence, per-game rules access.
- `game-content`: per-game content layout and layering — `games/<id>/` directory contract, asset ownership split (shared shell vs per-game), last-wins data-set layering, cross-game id collision rules.

### Modified Capabilities
- `entity-factory`: entity data and rules registration now flows from GameContext (no hardcoded directory in `_ready()`); factory gains content reset for game switches; directory examples move to `games/ts/entities/`.
- `terrain-catalog`: terrain/theater/art registries populate from GameContext layer roots instead of hardcoded `resources/*` paths.
- `audio-system`: audio data registration flows from GameContext; AudioData/VoiceData content location moves to `games/ts/audio/`.
- `global-rules`: rules storage becomes per-game (`games/<id>/global_rules.tres`); `get_current()` resolves through the active game's rules.

## Impact

- **New files**: `scripts/data/GameDefinition.gd`, `scripts/core/GameContext.gd` (+ `.uid` files), `games/ts/game.tres`.
- **Modified scripts**: `project.godot` (GameContext as first autoload), `scripts/entities/EntityFactory.gd`, `scripts/core/TerrainCatalog.gd`, `scripts/core/AudioManager.gd`, `scripts/editor/AssetPreviewController.gd` (hardcoded `res://resources/theaters/temperate.tres` becomes game-specific — resolved through the TerrainCatalog registry; dev tool with no test coverage, so listed explicitly).
- **Modified scenes**: `scenes/ui/MainMenu01.tscn` (+ `MainMenu01_old.tscn`) now reference `games/ts/assets/ui/`; `scenes/entities/units/nod/NodBuggy.tscn`, `scenes/entities/structures/gdi/GDIConyard01.tscn` and `scenes/maps/TestMap*.tscn` get rewritten asset paths. Shared shell scenes (`DefaultWorldEnvironment01.tscn`, fonts) untouched.
- **Content move**: `git mv` of all `resources/*` and five `assets/` subdirs; `.import` sidecars travel with their sources and their `source_file=` paths are rewritten, then a headless `--import` regenerates dest hashes (import params and uids survive in the sidecars).
- **Reference rewrites**: scripted `res://resources/` → `res://games/ts/` (432 `.tres` incl. internal ext_resource paths, 19 scripts/tests) and moved-asset prefixes in the affected `.tres`/scenes/tests.
- **Tests**: `test/run_tests.gd` gains `_gc` injection; new suites `test_game_context`, `test_game_content`; existing suites updated for new paths only — behavior unchanged with default game `ts`.
- **Docs**: `GLOSSARY.md` (game definition, GameContext, data set, layering), `AGENTS.md` (autoload table, folder structure).
- **Backward compatibility**: packed-build scanning (`packed-data-catalog`) is unaffected — `register_data_set` semantics are unchanged, only the fed paths move. Shared `MainMenu01.tscn` temporarily cross-references a TS asset until #376 makes the menu background game-resolved.
