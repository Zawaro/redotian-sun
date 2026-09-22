## Why

The game boots straight into the main menu / test map. There is no way to start a named
campaign mission, no per-mission overrides, and no briefing. The GDI Mission 01 milestone needs a
campaign → mission boot path before any mission content or scripting can be exercised.

## What Changes

- Add `Campaign` and `Mission` resource types plus a `CampaignCatalog` that discovers them per
  game (`<data_set>/campaigns/`, `<data_set>/missions/`), mirroring `FactionCatalog`.
- Add mission boot: selecting a campaign in the new campaign dialog starts its first mission,
  which loads the mission's map into `MainScene/Gameplay`.
- Add per-mission overrides applied at boot — starting credits, player house, home cell / start
  camera — with precedence **mission > map > global rules**.
- Add a briefing dialog, auto-shown before a mission when the mission enables it (game stays
  paused until closed), and re-openable from the pause menu's new Briefing button.
- Track the active mission on `GameContext`.
- Add `--mission <id>` CLI/debug entry so a mission can be started headlessly.
- Add a placeholder GDI01 mission map, mission resource, and GDI campaign as fixture content.

## Capabilities

### New Capabilities
- `campaign-catalog`: `Campaign`/`Mission` resource schema and per-game catalog discovery, lookup,
  and reset on game switch.
- `mission-boot`: starting a mission — resolve the campaign's first mission, set the active
  mission, apply overrides, load the map into the gameplay node, and center the camera.
- `campaign-dialog`: main-menu campaign selection listing available campaigns and starting the
  selected campaign's first mission.
- `briefing-screen`: the pre-mission briefing dialog, its enable toggle, and its pause-menu entry.

### Modified Capabilities
- `game-context`: tracks the active mission alongside the active game.
- `pause-system`: the pause menu gains a Briefing button that opens the briefing dialog.

## Impact

- New scripts: `Campaign.gd`, `Mission.gd`, `CampaignCatalog.gd`, `CampaignDialog.gd`,
  `BriefingDialog.gd`, `MissionBoot.gd`, `MissionMap.gd`.
- Modified: `GameContext.gd` (active mission), `PlayerManager.gd` (mission override resolution),
  `MainMenu01.gd` (New Campaign → dialog, drop hardcoded `TestMap02` path), `PauseMenu.gd`/.tscn
  (Briefing button), `MapBase01.tscn` (host briefing dialog), `project.godot` (new autoload),
  `games/ts/game.tres` (`maps_dir`), `GLOSSARY.md`.
- New content: `games/ts/campaigns/gdi.tres`, `games/ts/missions/gdi01.tres`,
  `games/ts/maps/gdi01.json`.
- Depends on nothing. Enables the scripted-mission work (#237+).
