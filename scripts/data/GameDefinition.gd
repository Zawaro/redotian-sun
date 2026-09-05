class_name GameDefinition
extends Resource

## GameDefinition — one standalone game's content manifest (Tiberian Sun,
## Firestorm, RA2, ...). Each game owns exactly one definition at
## res://games/<id>/game.tres; the id MUST match the directory name.
## GameContext discovers these and exposes the active one to consumers.

## Unique game id, matching the res://games/<id>/ directory name.
@export var id: String = ""

## Human-readable name shown in menus (e.g. "Tiberian Sun").
@export var display_name: String = ""

## Full per-game rules resource — one global_rules.tres per game, no
## override-merge machinery.
@export var rules: GlobalRules = null

## Ordered layer roots scanned by EntityFactory/TerrainCatalog/AudioManager.
## Each entry is a res:// directory; consumers append their known subdirectory
## names (entities/, audio/, terrain_objects/, art/terrain/, theaters/) per
## root and register roots in order — later roots win on id collisions.
## Borrowing another game's content = listing its root here.
@export var data_sets: PackedStringArray = PackedStringArray()

## Directory holding this game's map files. Consumed by the game-selection
## boot screen (#376); unused until then.
@export var maps_dir: String = ""
