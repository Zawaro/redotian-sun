class_name MapConfig extends Node

@export_group("Players")
@export var players: Array = []


class PlayerConfig:
    @export_group("Player Config")
    @export var player_id: int = 0
    @export var display_name: String = ""
    @export var faction_id: String = ""
    @export var team_id: int = 0
    @export var color: Color = Color.WHITE
    @export var spawn_index: int = 0
    @export var is_bot: bool = false
    @export var starting_credits: int = -1
    @export var starting_units: PackedStringArray = []
    @export var power_output: int = -1
