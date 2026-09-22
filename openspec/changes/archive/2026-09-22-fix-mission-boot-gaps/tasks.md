## 1. Menu overlays

- [x] 1.1 Hide `MainMenu01` and `BootScreen` in `MissionBoot._hide_menu_overlays()` when a mission starts
- [x] 1.2 Cover the `--mission`-without-`--game` path where the boot screen occludes the map

## 2. Briefing ESC + wiring

- [x] 2.1 Add `BriefingDialog._input()` consuming the `pause` action while the briefing is visible
- [x] 2.2 Ensure the event is marked handled so `PauseMenu._unhandled_input` cannot toggle pause
- [x] 2.3 Replace the hardcoded `../PauseMenu` path with a `briefing_requested`-signal lookup
- [x] 2.4 Keep close semantics: pre-mission unpauses, pause-menu briefing stays paused

## 3. Map precedence layer

- [x] 3.1 Add `MissionMap._attach_map_config()` building a `MapConfig` from the JSON `players` array
- [x] 3.2 Attach the `MapConfig` node to the mission map (no-op when the array is absent/empty)
- [x] 3.3 Change `PlayerManager.begin_mission(mission, map_config)` to resolve mission > map > global
- [x] 3.4 Add `resolve_starting_credits` and the map house lookup helpers
- [x] 3.5 Preserve the `players` array across an editor re-save in `EditorSaveLoad`

## 4. CLI testability

- [x] 4.1 Extract `MissionBoot._consume_mission_args(args, user_args)` as a pure helper
- [x] 4.2 Keep `_ready` consuming the helper after autoloads are ready

## 5. Docs

- [x] 5.1 Document the map JSON `players` array and the mission boot seam in `AGENTS.md`
- [x] 5.2 Remove placeholder wording left from the original mission-boot change

## 6. Tests

- [x] 6.1 Test map-layer credit precedence (`mission` inherits → map value wins)
- [x] 6.2 Test briefing ESC closes and does not toggle pause (pre-mission and pause-menu paths)
- [x] 6.3 Test `_consume_mission_args` with synthetic engine/user args
- [x] 6.4 Test mission start hides the menu overlays

## 7. Verification

- [x] 7.1 Run `openspec validate fix-mission-boot-gaps --strict`
- [x] 7.2 Run `redot --headless -s test/run_tests.gd` and fix failures
- [x] 7.3 Run `gdlint` + `gdformat --check` and fix findings
