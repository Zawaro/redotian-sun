class_name Faction extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var color: Color = Color.WHITE

## Canonical roster position (ascending). Ties are broken by `id`.
@export var order: int = 0

## Whether the faction is eligible for the default player roster (passive
## houses like Neutral/Special set this false).
@export var playable: bool = true
