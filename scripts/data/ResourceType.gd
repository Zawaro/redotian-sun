class_name ResourceType extends Resource

## Unique identifier for this resource type (e.g. "tiberium_green", "vein").
@export var id: String = ""
## Human-readable name shown in UI tooltips.
@export var display_name: String = ""
## Parent category this type belongs to (e.g. "tiberium" for all tiberium variants).
@export var category: String = ""
## Legacy parent type identifier — use category for new resources.
@export var parent_type: String = ""
## Credit value per bale when processed at a refinery.
@export var value: float = 1.0
## Display color for UI elements (pip scale, minimap dots, selection highlights).
@export var color: Color = Color.WHITE
## Fraction of max health added per growth tick (0.05 = 5% per tick).
@export var grow_rate: float = 0.05
## Bales of resource created when this type spreads to a new cell (0.01-0.5).
@export var spread_amount: float = 0.5
## Max times a single crystal can spread before it stops spreading.
@export var spread_max: int = 3
