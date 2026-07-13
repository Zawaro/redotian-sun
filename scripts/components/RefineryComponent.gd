class_name RefineryComponent extends Node

## Resource categories this refinery accepts (e.g. ["tiberium"]). Empty = accepts all.
@export var accepted_resource_categories: PackedStringArray = []
## Units of resource processed per second during unloading.
@export var unload_rate: float = 2.33
