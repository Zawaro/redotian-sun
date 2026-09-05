# Design — Add Game Definition Context

## Context

Three autoloads hardcode their content directories in `_ready()`: EntityFactory (`resources/entities/` + `resources/global_rules.tres`), TerrainCatalog (`terrain_objects/`, `art/terrain/`, `theaters/`), and AudioManager (`resources/audio/`). All 1094 `.tres` under `resources/` are Tiberian Sun content, as are most of the referenced `assets/` subdirs. `GlobalRules.get_current()` (16 consumer files) resolves through the EntityFactory node. Tests reach into `EntityFactory.set_global_rules()` and `register_data_set()` with fixture dirs — both seams must survive.

Parent issue #374 approved: data-only parity for four games first, single binary, full content restructure, `GameDefinition`/`GameContext` naming. This change is child #375 — the core layer.

## Goals / Non-Goals

**Goals:**
- One game = one content tree (`res://games/<id>/`), selected at boot, switchable at runtime.
- Zero hardcoded game paths in consumer `_ready()` methods.
- `--game <id>` works today; the BootScreen (#376) only needs `list_games()` + `select_game()` + `save_game_choice()`.
- Existing suite passes unchanged with default game `ts`.

**Non-Goals:**
- `features: Dictionary` / `is_feature_enabled()` — deferred until a real consumer exists (T6). Deviates from the #375 issue text; approved during planning.
- Per-game keybind sections — deferred until a second game exists; the `[keybinds:<game_id>]` convention is documented but InputSettings is untouched this change. Deviates from the #375 issue text; approved during planning.
- BootScreen UI, per-game mechanics (superweapons, mind control, etc.) — #376 and later.
- Migration shim for legacy `[keybinds]` sections in existing `user://settings.cfg`.

## Decisions

### D1 — `data_sets` holds ordered layer roots, not flat dirs
A single flat dir list shared by all three consumers would make each scan `load()`-and-discard the other consumers' resources (TerrainCatalog would load every entity/art `.tres`). Instead `data_sets` holds roots (`["res://games/ts/"]` today) and each consumer appends its known subdir (`entities/`, `audio/`, `terrain_objects/`, `art/terrain/`, `theaters/`). Last-wins falls out of the existing `_entity_cache`-style dictionaries; borrowing (a game listing another game's root) is just another layer. Future games only add directories and a definition — no further code changes. Alternative rejected: per-consumer dir lists on GameDefinition — three fields, duplicated per game, no layering story. `maps_dir` is carried per the issue but has no consumer until the BootScreen change (#376).

### D2 — `GlobalRules.get_current()` contract unchanged; EntityFactory copies rules from GameContext
GameContext loads the def and sets `EntityFactory._global_rules = GameContext.current.rules` at select time. `get_current()` keeps routing through EntityFactory, so all 16 consumer files and every `_inject_rules`-style test monkeypatch (`set_global_rules`) keep working byte-for-byte. Alternative rejected: rerouting `get_current()` through GameContext — same 3 lines but touches the one seam every rules test leans on.

### D3 — Consumers pull at `_ready()`; `game_changed` is for runtime switches only
Autoload `_ready()` runs in registration order: GameContext (first) resolves the game before EntityFactory/TerrainCatalog/AudioManager (later) even exist. A boot-time `game_changed` emission would fire into the void. So consumers pull from GameContext in their own `_ready()` AND connect to `game_changed` for switches. Selecting the default game at boot is an implicit `select_game`, so the lifecycle has exactly one code path. `reset_content()` on each consumer (clear caches + `_data_sets`, plus TerrainCatalog's `_terrain_scene`/`_active_theater`) serves both unload (`select_game("")`) and re-select — and doubles as the hook the per-game boot smoke test needs, so no test-only API exists.

### D4 — Content move: git mv + scripted reference rewrite, sidecars travel
- `git mv resources/* → games/ts/*` and `git mv` TS-owned asset dirs → `games/ts/assets/` (see D5 for the split). `.uid` files travel with their resources.
- `.import` sidecars move WITH their sources and their `source_file=` line is rewritten; import params and `uid=` survive in the sidecar, and the engine regenerates the hash-based `dest_files` on a headless `--import` (dest path embeds a hash of the source path). Deleting sidecars and re-importing was rejected: it loses per-file import params.
- Rewrite passes: `res://resources/` → `res://games/ts/` (432 `.tres` incl. internal ext_resource paths, 19 scripts/tests) and moved-asset prefixes `res://assets/{models,textures,resources,cameos,ui,test_map01,test_terrain}` → `res://games/ts/assets/...`. Cursors, fonts, hdri prefixes are NOT rewritten.
- `resources/` ends up empty and disappears from git — expected; shared content will recreate it.

### D5 — Asset ownership split: shared shell vs per-game
| Asset | Owner | Home |
|---|---|---|
| `assets/fonts/`, `assets/hdri/` | shared shell | stays |
| `assets/cursors/placeholders/` (40 SVGs hardcoded in `CursorState.gd`) | shared shell | stays — generic placeholder icons, not TS art; real per-game cursors land in `games/<id>/assets/cursors/` later |
| `assets/models/`, `textures/`, `resources/` (GDIConyard material), `test_*.json` | TS | → `games/ts/assets/` |
| `assets/cameos/`, `assets/ui/tsmenu2k.png`, `background01_final01.jpg` | TS | → `games/ts/assets/{cameos,ui}/` |

The `ArtData.cameo_path` indirection means game-owned art keeps pointing at game-owned assets; no resolution mechanism is built for UI assets now.

### D6 — Settings: one file, `[game]` persistence only this change
`user://settings.cfg` stays the single config file. GameContext (autoload #1) reads/writes `[game] id` directly with its own ConfigFile instance — it cannot go through InputSettings (autoload #2) and shouldn't; ConfigFile load-set-save preserves the other sections. The per-game `<section>:<game_id>` convention (e.g. `[keybinds:ts]`) is reserved for when a second game exists; migrating InputSettings now was reviewed and deliberately deferred — with a roster of one it breaks existing `[keybinds]` data for zero user value, and the split is mechanical later. Alternative rejected: separate `user://games/ts/settings.cfg` — two files to load/save/keep in sync for no gain.

### D7 — Validation timing: active game at select, cross-game on demand
Only one game is ever active; same-id overlap *within* a layer list is desired layering (last-wins), not an error. A same-id claim by two *non-borrowing* games is only detectable by loading both games' content — wrong thing to do at every boot. So: `select_game` validates the active game's rules via the existing `validate_locomotor_keys()`/`validate_warhead_armor_keys()` helpers and refuses on error; a static cross-game collision validator (over two defs' dir lists, error names both games and the id) runs on demand — unit-tested with fixture dirs, later wired into CI/tooling. **Deviation from #375 issue text, approved during planning**: the issue says collision validation "refuses to boot"; that is only achievable for the active game's own registries (done at select), while the sibling-game collision check cannot run at single-game boot and lands as an on-demand validator.

### D8 — Boot smoke = in-process select cycle, not subprocesses
Booting each discovered game in one headless process is only safe because D3's `reset_content()` makes repeated select cycles complete (caches, `_data_sets`, theater state all reset — the cycle test proves it). Spawning a `redot` subprocess per game was rejected: slow, and CI would need engine-path plumbing.

### D9 — `--game` parsing checks both arg lists
`OS.get_cmdline_args()` catches `redot --game ts` (engine passes unknown options through); `OS.get_cmdline_user_args()` catches `redot -- --game ts`. Checking both is two lines and removes a footgun.

## Risks / Trade-offs

- [Blanket `res://resources/` rewrite touches 432 `.tres`] → rewrite is mechanical and verified by the full test suite plus a headless boot; any missed string surfaces as a load warning that the smoke test flags.
- [Reimport churn on ~59 moved sidecars] → sidecars keep params/uids; only `source_file` changes; headless `--import` once after the move. Font/texture loading has no automated test — verified by booting to the main menu manually.
- [`resources/` directory disappears] → intentional; GLOSSARY/AGENTS/spec examples updated in the same change so no doc dangles.
- [Shared `MainMenu01.tscn` now references `games/ts/assets/ui/tsmenu2k.png`] → accepted seam; #376 resolves the menu background per game. One-line follow-up, not worth a UI-asset resolution mechanism today.
- [Repeated select cycles leak stale state (e.g. cached `_terrain_scene`)] → reset-completeness is asserted by a dedicated cycle test before the smoke test relies on it.
- [`reset_content()` is new public API on three autoloads] → it is the unload path the menu flow (#376) requires anyway; not test-only creep.
- [TerrainCatalog's placeholder fallback resolves to the TS GLB (`games/ts/assets/models/theater/placeholder/`) even when another game is active] → accepted during review: the GLB is the transitional stand-in for unresolvable terrain art; each game ships its own placeholder art under its tree as content lands.

## Migration Plan

1. Land core (GameDefinition, GameContext, project.godot entry, consumer wiring) with GameContext still reading today's layout-independent defaults — no behavior change yet.
2. Perform the content move + reference rewrites in one commit; run headless `--import`; run the full suite (`redot --headless -s test/run_tests.gd`).
3. Flip consumers to GameContext-fed paths (this and step 1 can land together; the move must precede the flip's new default paths).
4. Validation + new tests. Rollback = revert branch; the move commit is self-contained (git mv keeps history: `git log --follow` works).
