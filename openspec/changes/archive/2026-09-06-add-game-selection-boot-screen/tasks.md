## 1. Boot screen scene + script

- [x] 1.1 Create `scripts/ui/BootScreen.gd`: static `should_skip(args)` (via `GameContext.extract_flag_id`), `_ready()` gate (hide self when flag present, else show + hide the MainMenu01 sibling), plain placeholder `Button` rows built from `GameContext.list_games()` (`display_name` falling back to `id`, `pressed` signal bound to `pick`; disabled `Options`; `Quit` row and ESC (`pause` action) both exit the app), `pick(id)` = `select_game` with same-id guard → `save_game_choice` → hide + reveal menu, deferred per-game-menu seam comment
- [x] 1.2 Create `scenes/ui/BootScreen.tscn`: full-rect Control, neutral placeholder background (no per-game assets), `Rows` container for runtime-built buttons
- [x] 1.3 Instance `BootScreen` in `scenes/MainScene.tscn` under `HUD/UI` after `MainMenu01` so it draws on top

## 2. Tests

- [x] 2.1 Create `test/unit/test_boot_screen.gd`: skip-gate statics (flag present/absent/with `--game` valueless), visibility + MainMenu01 occlusion after instantiation without flag, rows match `list_games()` incl. display-name fallback + Options/Quit present, pick different game (`GameContext.current.id`, one `game_changed`, persisted id in scratch `_config_path`, menu restored), pick same id (no `game_changed`, persisted), empty list still offers Quit + Quit press-wiring asserted (ESC-quit is a one-line `_quit()` call — untestable headlessly), Options no-op — with `TestHelper.snapshot_game_context`/`restore_game_context` around every mutating test
- [x] 2.2 Full suite passes: `redot --headless -s test/run_tests.gd`

## 3. Cleanup + verification

- [x] 3.1 Fix `GameDefinition.maps_dir` doc comment to point at the map-selection follow-up instead of #376
- [x] 3.2 `gdlint` + `gdformat --check` on new files, commit script with its generated `.uid`
- [x] 3.3 Manual boot check: without `--game` the launcher lists Tiberian Sun + Options/Quit and picking it lands on MainMenu01; with `--game ts` no launcher flash and MainMenu01 shows directly
