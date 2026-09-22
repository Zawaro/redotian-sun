## Why

The archived `mission-boot` change has gaps surfaced in review of the shipped code:

1. Launching `--mission` without `--game` leaves the `BootScreen` (and `MainMenu01`) occluding the
   running mission — the mission loads, but the player sees only the boot splash.
2. Pressing ESC while the briefing dialog is open both closes the briefing and toggles pause: the
   dialog does not consume the event, so `PauseMenu._unhandled_input` unpauses the game and stacks
   the pause menu beneath the briefing.
3. The `mission > map > global` precedence has no reachable map layer: `PlayerManager.begin_mission`
   ran before the mission map existed and no map supplied a `MapConfig`, so the map branch was dead
   code.
4. `BriefingDialog` hardcodes its `../PauseMenu` path, so it only wires up when the dialog sits at a
   fixed position in the scene tree.
5. `MissionBoot`'s CLI consumption is embedded in `_ready` and cannot be driven from a test.

The docs also still carry placeholder wording left from the original change.

## What Changes

- Hide both menu overlays (`MainMenu01` and `BootScreen`) when a mission starts.
- Make the briefing dialog own the `pause` action while it is visible, so ESC closes it without
  toggling pause or opening the pause menu underneath.
- Materialize an optional top-level `players` array from the map JSON into a `MapConfig` child of
  the mission map, and resolve the map layer through
  `PlayerManager.begin_mission(mission, map_config)` with precedence **mission > map > global**.
- Make the briefing find its pause menu by the `briefing_requested` signal instead of a hardcoded
  scene path.
- Extract `MissionBoot._consume_mission_args` as a pure helper so the CLI consumption is testable.
- Preserve the map JSON's `players` array across an editor re-save, and fix doc placeholders.

## Impact

- `scripts/maps/MissionBoot.gd` — `_hide_menu_overlays()`, `_consume_mission_args()`.
- `scripts/maps/MissionMap.gd` — `_attach_map_config()` materializes the `MapConfig`.
- `scripts/core/PlayerManager.gd` — `begin_mission(mission, map_config)`, `resolve_starting_credits`.
- `scripts/ui/BriefingDialog.gd` — `_input()` pause-action handling, signal-based pause-menu lookup.
- `scripts/editor/EditorSaveLoad.gd` — preserve the `players` array on re-save.
- Tests: mission precedence, briefing dialog, mission boot, overlay input.
- `AGENTS.md` — document the map `players` array and the mission boot seam.
