## Context

`mission-boot` landed the campaign → mission → map boot path: `MissionBoot` activates a mission,
`MissionMap` loads the map JSON, `PlayerManager.begin_mission` applies per-player overrides, and
`BriefingDialog` gates gameplay before it starts. Review of the shipped code found five gaps where
the implementation did not match the intended contract, plus doc placeholders. The fixes are small
and localized; they do not change the boot flow's shape, only make its advertised behavior real.

## Goals / Non-Goals

**Goals:**
- A booted mission is the only visible surface (menu overlays hidden).
- The briefing owns ESC while open and never toggles pause underneath itself.
- The `mission > map > global` precedence has a real, reachable map layer.
- The briefing finds its pause menu structurally rather than by a hardcoded path.
- The `--mission` CLI consumption is testable in isolation.

**Non-Goals:**
- Authoring players in the map editor (the `players` array is hand-authored JSON for now).
- Generalizing menu → gameplay loading (#262) or the editor re-save pipeline.
- Changing the existing `map-config` `_find_map_config` path used by `PlayerManager._ready`.
- Mission scripting, objectives, or win/lose (#237).

## Decisions

### D1 — Mission start hides `MainMenu01` and `BootScreen`
`MissionBoot._on_mission_started` calls `_hide_menu_overlays()`, which walks the current scene root
and hides both overlays by name. This fixes the `--mission`-without-`--game` path where the boot
screen would otherwise occlude the loaded map. Hiding by name keeps the boot seam from taking a
dependency on either overlay's script.

### D2 — `BriefingDialog._input` consumes the `pause` action while visible
The dialog implements `_input`, which runs before `_unhandled_input`. When visible, a `pause`
action press closes the dialog and calls `get_viewport().set_input_as_handled()`, so
`PauseMenu._unhandled_input` never sees the event and cannot unpause or open the pause menu beneath
the briefing. Closing honors the recorded origin: pre-mission unpauses, pause-menu stays paused.

### D3 — The map layer is an optional top-level `players` array in the map JSON
`MissionMap._attach_map_config` reads the map JSON, and when a top-level `players` array is present
it builds a `MapConfig` node (entries mirror `MapConfig.PlayerConfig`) and attaches it to the
mission map. `MissionBoot` passes that node to `PlayerManager.begin_mission(mission, map_config)`,
which resolves credits and house with **mission > map > global**. An absent or empty array leaves
the map with no config and the map layer inert — the same behavior as before for maps that define
no players. *Alternative:* a per-mission `.tscn` carrying a `MapConfig` — rejected as content
duplication; the JSON is the map's own format and already parsed at load.

### D4 — The briefing finds its pause menu by the `briefing_requested` signal
`BriefingDialog._find_pause_menu` walks up from the dialog, checking the node and its siblings for a
`briefing_requested` signal, instead of assuming a fixed `../PauseMenu` path. This keeps the dialog
usable whether it is nested under the map HUD or placed beside the pause menu, and avoids a hard
script dependency on `PauseMenu`.

### D5 — `MissionBoot._consume_mission_args` is a pure helper
The `--mission` lookup (`OS.get_cmdline_args()` then `OS.get_cmdline_user_args()`) is extracted into
`_consume_mission_args(args, user_args)`, so a test can drive it with synthetic arrays without real
process args. `_ready` still makes the actual `start_mission` call after autoloads are ready.

## Risks / Trade-offs

- [Hiding overlays by name breaks if an overlay is renamed] → names are stable scene-node names
  (`MainMenu01`, `BootScreen`); `find_child` tolerates nesting and missing nodes.
- [The dialog's `_input` swallows ESC for the whole tree while visible] → intended: the briefing is
  modal; the dialog is the only surface that should react.
- [A malformed `players` entry crashes `MapConfig` construction] → entries are type-checked; a
  non-dictionary entry is skipped and an absent/invalid array is ignored.
- [Editor re-save drops hand-authored `players`] → `EditorSaveLoad` preserves the array read on
  load; the editor does not author players yet.
