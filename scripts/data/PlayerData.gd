class_name PlayerData extends Resource

@export_group("Player")
@export var player_id: int = 0
@export var faction_id: String = ""
@export var color: Color = Color.WHITE
@export var team_id: int = 0
@export var spawn_index: int = 0
@export var display_name: String = ""
@export var is_bot: bool = false

## Per-category stored resource value (e.g. "tiberium" -> 1000). Harvested
## deposits and refunds; subject to storage capacity. Single source of truth.
var stored_by_category: Dictionary = {}

## Free credits: starting credits, crate bonuses, debug money, sell refunds.
## Not subject to storage capacity and never counted toward the storage bar.
var free_credits: int = 0
