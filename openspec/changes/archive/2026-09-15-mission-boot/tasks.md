## 1. Data model

- [x] 1.1 Add `scripts/data/Campaign.gd` (`Campaign` resource: id, display_name, faction_id, missions)
- [x] 1.2 Add `scripts/data/Mission.gd` (`Mission` resource: id, display_name, map_path, briefing, show_briefing, player_house, starting_credits, home_cell, next_mission_id)
- [x] 1.3 Add `scripts/core/CampaignCatalog.gd` scanning `campaigns/` + `missions/`, with lookup and `game_changed` reset
- [x] 1.4 Register `CampaignCatalog` in `project.godot` after `FactionCatalog`
- [x] 1.5 Point `games/ts/game.tres` `maps_dir` at `res://games/ts/maps/`

## 2. Active mission and overrides

- [x] 2.1 Add `GameContext.current_mission`, `start_mission(id)`, `mission_started` signal
- [x] 2.2 Clear `current_mission` on game select/unload
- [x] 2.3 Add `PlayerManager.begin_mission(mission)` resolving `mission > map > GlobalRules` for credits and house
- [x] 2.4 Keep `_find_map_config` / `_init_from_map_config` intact for the existing `map-config` contract

## 3. Mission boot

- [x] 3.1 Add `scripts/maps/MissionMap.gd` + `scenes/maps/MissionMap.tscn` (instance of `MapBase01`) loading `GameContext.current_mission.map_path`
- [x] 3.2 Add `scripts/maps/MissionBoot.gd`: set active mission, apply overrides, instantiate `MissionMap` into `MainScene/Gameplay`
- [x] 3.3 Apply `home_cell` camera override, falling back to `MapLoader` start-location framing
- [x] 3.4 Add `--mission` static flag parse on `GameContext`; consume it from `MissionBoot._ready`

## 4. Campaign dialog

- [x] 4.1 Add `scripts/ui/CampaignDialog.gd` + `scenes/ui/CampaignDialog.tscn` listing campaigns with Start
- [x] 4.2 Add empty-catalog state with disabled Start and main-menu occlusion
- [x] 4.3 Wire `MainMenu01` "New Campaign" to open the dialog; remove the hardcoded `TestMap02.tscn` path

## 5. Briefing

- [x] 5.1 Add `scripts/ui/BriefingDialog.gd` + `scenes/ui/BriefingDialog.tscn` showing title + briefing text
- [x] 5.2 Add `MapBase01` briefing host script: connect `PauseMenu.briefing_requested`, auto-show on `mission_started` when `show_briefing`
- [x] 5.3 Add Briefing button to `PauseMenu.tscn` / `PauseMenu.gd` emitting `briefing_requested`; disabled when no mission
- [x] 5.4 Implement pause ownership: pre-mission close unpauses; pause-menu open/close keeps the game paused

## 6. Content

- [x] 6.1 Add placeholder `games/ts/maps/gdi01.json` map
- [x] 6.2 Add `games/ts/missions/gdi01.tres`
- [x] 6.3 Add `games/ts/campaigns/gdi.tres`
- [x] 6.4 Update `GLOSSARY.md` with campaign, mission, briefing, home cell, next mission

## 7. Tests and verification

- [x] 7.1 Unit test `CampaignCatalog`: scan, collisions, missing dirs, `game_changed` reset
- [x] 7.2 Unit test `Mission` inherit defaults
- [x] 7.3 Unit test override precedence (`mission > global`) via `PlayerManager.begin_mission`
- [x] 7.4 Integration test mission boot: map entities, credits, home-cell camera
- [x] 7.5 Test briefing gate (`show_briefing` on/off) and pause ownership
- [x] 7.6 Test `--mission` parse and start seam
- [x] 7.7 Run `redot --headless -s test/run_tests.gd` and fix failures
- [x] 7.8 Run `gdlint` + `gdformat --check` and fix findings
