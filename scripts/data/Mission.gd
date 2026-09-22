class_name Mission
extends Resource

## Mission — a single-player mission: a map JSON plus campaign metadata and
## per-mission overrides. One mission per `.tres` under `<game>/missions/`,
## discovered by CampaignCatalog.
##
## Override fields use inherit sentinels matching MapConfig.PlayerConfig:
## `starting_credits < 0` and empty `player_house` / `home_cell` defer to the
## map and then to the active game's GlobalRules.

@export var id: String = ""
@export var display_name: String = ""
@export var map_path: String = ""
@export_multiline var briefing: String = ""

## Whether the pre-mission briefing dialog is shown when the mission starts.
@export var show_briefing: bool = true

## Local player's house id (a Faction id, e.g. "GDI"). "" inherits the default.
@export var player_house: String = ""

## Starting credits for the local player. -1 inherits map/global rules.
@export var starting_credits: int = -1

## Start-camera cell override as "x,y". "" defers to the map start location.
@export var home_cell: String = ""

## Next mission id in the campaign chain. "" = none. Consumed by the later
## campaign-progression feature.
@export var next_mission_id: String = ""
