## Context

The game has no campaign/mission layer: `MainMenu01.gd` hardcodes `TestMap02.tscn`, `MainScene`
has an empty `Gameplay` node, and there is no way to express per-mission overrides or a briefing.
`GameContext` resolves the active *game*; nothing resolves an active *mission*. `MapConfig` exists
as a `Node`-based per-map player config but is effectively dead: `PlayerManager._ready()` runs
before any scene exists, so `_find_map_config()` always returns null and defaults are used.

This change adds the campaign → mission → map boot path needed by the GDI Mission 01 milestone,
using the existing catalog pattern (`FactionCatalog`), `MapLoader`, and `GlobalRules`.

## Goals / Non-Goals

**Goals:**
- Data-driven `Campaign`/`Mission` resources discovered per game.
- A campaign dialog that starts a campaign's first mission.
- A single mission-boot flow that sets the active mission, applies overrides, loads the map into
  `MainScene/Gameplay`, and centers the camera.
- A briefing dialog shown pre-mission (game held paused) and re-openable from the pause menu.
- `--mission <id>` for headless/debug entry.

**Non-Goals:**
- Mission-select / unlock list and campaign progression persistence.
- Win/lose detection (default annihilation) and objectives (#237).
- FMV briefings.
- Skirmish/multiplayer map selection; generalized map loading (#262) beyond the minimal seam here.
- Named map waypoints (the `home_cell` string is a bridge until they land).

## Decisions

### D1 — Campaign/Mission are resources, not map-JSON keys
`Campaign` and `Mission` live under `games/<id>/campaigns/` and `games/<id>/missions/`; map JSON
stays the editor's format for map content (terrain, entities, theater, `start_locations`).
Listing/filtering campaigns in the dialog must not require parsing every map, and `next_mission_id`
is campaign metadata, not map data. *Alternative:* top-level `[Briefing]`/`NextMission` keys in the
map JSON (TS-like) — rejected because it pollutes the map format used by skirmish maps and forces
the editor to know about campaigns.

### D2 — `CampaignCatalog` autoload mirrors `FactionCatalog`
Scans `<data_set>/campaigns/` and `<data_set>/missions/`, caches by id, recurses subdirectories,
later layer roots win, resets on `game_changed`. Reuses the existing per-catalog scan shape rather
than inventing a new registry. *Alternative:* fold into `GameContext` — rejected for consistency;
every content domain has its own catalog.

### D3 — Override resolution goes through `PlayerManager.begin_mission(mission)`
`Mission` carries `starting_credits` (`-1` inherit) and `player_house` (`""` inherit), matching the
`MapConfig.PlayerConfig` convention. `begin_mission` clears and rebuilds `_players`, resolving
`mission > map > GlobalRules`. This is the single, reusable entry point: future map-defined player
lists (a real `MapConfig` in the mission map scene) can feed the same resolution without changing
callers. *Alternatives:* materialize a `MapConfig` node and add `PlayerManager.reload()` — rejected
as premature; there is no map-defined player data yet and `MapConfig`'s `Node`/nested-class shape is
awkward. Keeping `_find_map_config` untouched preserves the existing `map-config` spec.

### D4 — One generic `MissionMap.tscn`, not a scene per mission
`MissionMap.tscn` instances `MapBase01` and its script reads `GameContext.current_mission.map_path`
to call `MapLoader.load_map_into`. This mirrors `TestMap02.gd`'s pattern but is data-driven, so new
missions need no new scene. *Alternative:* per-mission `.tscn` — rejected as content duplication.

### D5 — Briefing dialog: one scene, two entry points, explicit pause ownership
`BriefingDialog` lives in `MapBase01` (the map scene root), so both the pre-mission auto-show and
the pause menu can reach it within the same scene instance. `PauseMenu` emits
`briefing_requested` (signal up) and `MapBase01` connects and calls down to the dialog — matching
the repo's signal-driven convention and keeping `PauseMenu.tscn` reusable standalone. The dialog
records whether it was opened from pause: closing a pre-mission briefing unpauses; closing a
pause-menu briefing returns to the (still paused) pause menu. The dialog uses
`process_mode = ALWAYS` so it is interactive while paused.

### D6 — Mission boot carries its own minimal loading seam
This change appends `MissionMap.tscn` into `MainScene/Gameplay` and sets the active mission. #262
later generalizes menu → gameplay loading; this design keeps the seam small (one `add_child` in
`MissionBoot`) so #262 can absorb it without conflict.

### D7 — `--mission` parsed as a pure static, consumed after autoloads are ready
Flag parsing is a pure static on `GameContext` (testable, like `extract_flag_id`). The actual
`start_mission` call is made by `MissionBoot` at scene `_ready`, after `CampaignCatalog` has
populated, avoiding the autoload-order race (`GameContext` is first, catalogs load later).

### D8 — `home_cell` is a `"x,y"` string for now
Named waypoints are not implemented. `Mission.home_cell` stores a cell string and is applied by
mission boot as a camera override above the map's `start_locations`. When map waypoints land, this
becomes `home_waypoint: int` with no change to the boot flow.

## Risks / Trade-offs

- [Autoload-order race on `--mission`] → parse the flag in a static, defer `start_mission` to
  `MissionBoot._ready` (D7).
- [`PlayerManager.begin_mission` rebuilds `_players`, dropping any prior state] → intended: a mission
  start is a new match. Existing `_init_defaults`/`_init_from_map_config` remain for other paths.
- [Briefing unpause conflicts with the pause menu] → dialog tracks its open origin and only unpauses
  the pre-mission path (D5).
- [`MapConfig` stays dead] → explicitly out of scope; D3 leaves its code path intact and future
  per-map players can route through `begin_mission`.
- [Pause-leftover when mission starts] → mission boot ensures `get_tree().paused` is set by the
  briefing path and cleared on close; a mission with `show_briefing = false` starts unpaused.

## Migration Plan

Additive; no persisted-format migration. The only behavior change is the main menu's campaign
entry no longer hardcoding `TestMap02.tscn`. Rollback = revert the change; existing dev workflow of
running map scenes standalone is unaffected.

## Open Questions

None blocking. Deferred: mission-select list + unlock persistence, real `gdi01` map content (#226/
#232), waypoint-backed `home_cell`, objectives/win-lose.
