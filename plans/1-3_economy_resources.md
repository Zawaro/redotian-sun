# Economy & Resources System - Redotian Sun

## Overview
The economy system manages Tiberium harvesting, credit tracking, and spending — the core RTS resource loop. Unlike SimCity, there is **no passive income**. Every credit comes from the harvest cycle: harvester → Tiberium crystal → fill → refinery → dump → credits.

## Core Loop
```
TiberiumTree (persistent spawner on map)
  └── spawns Tiberium crystal entities (one per cell within radius)
        └── Harvester drives to crystal → fills cargo (crystal depletes)
              → drives to nearest refinery → docks at bib platform → dumps cargo → credits added
              → repeats (or finds new crystal if current is depleted)
```

## Architecture

### PlayerData (Resource)
```gdscript
class_name PlayerData extends Resource
@export var player_id: int = 0
@export var credits: int = 0
```
Per-player treasury resource. No income_rate or storage_capacity stored here — those are derived values computed from buildings the player owns.

### EconomyManager (Autoload Singleton)
Thin ledger. No income tick, no passive generation. Pure add/deduct.
```gdscript
extends Node
signal credits_changed(player_id: int, new_balance: int, reason: String)
signal insufficient_funds(player_id: int, cost: int, balance: int)

func get_balance(player_id: int) -> int
func can_afford(player_id: int, cost: int) -> bool
func deduct(player_id: int, cost: int, reason: String) -> bool  # false if insufficient
func add(player_id: int, amount: int, reason: String) -> void
func get_storage_capacity(player_id: int) -> int  # computed from silos
```

### Deduction Timing
Credits deducted when an item enters a **production queue** (building at Construction Yard, unit at Factory/Barracks), not on placement. Repair deduction is handled by ServiceDepotComponent (future, rate per HP). Refunds from cancel/sell are proportional (GlobalRules.refund_percent).

## Components

### TiberiumTreeComponent
Attached to a TiberiumTree TERRAIN entity (1x1 foundation, indestructible, unselectable). The tree is a persistent spawner placed by map designers — it does NOT disappear when crystals are depleted. Future: growth/spread ticks managed here.
```gdscript
class_name TiberiumTreeComponent extends Node
@export var spawned_entity_id: String = ""   # EntityData ID of crystal to spawn (e.g. "TIB")
@export var radius_cells: int = 8            # spawn radius in grid cells
@export var tiberium_type: int = 0           # 0 = green, 1 = blue
@export var node_count: int = 12             # how many crystal entities to spawn
@export var amount_per_node: int = 300       # tiberium per crystal entity
@export var max_amount_per_node: int = 300   # fully grown amount
@export var regrowth_rate: float = -1.0      # -1 = use GlobalRules.growth_rate
```
- On `_ready()` with `call_deferred()`: spawn `node_count` crystal entities via `EntityFactory.create_entity(spawned_entity_id)` scattered within `radius_cells` with 2-cell minimum spacing
- Each spawned crystal gets TiberiumComponent configured from tree parameters
- Tree persists on map regardless of crystal depletion

### TiberiumComponent
Attached to TERRAIN-type entity instances (individual Tiberium crystals, one per cell).
```gdscript
class_name TiberiumComponent extends Node
@export var amount: int = 0          # current Tiberium in this crystal
@export var max_amount: int = 0      # initial / fully grown amount
@export var tiberium_type: int = 0   # 0 = green, 1 = blue
@export var regrowth_rate: float = -1.0  # -1 = use GlobalRules.growth_rate
```
- EntityData gets `@export var tiberium_resource: bool = false` so EntityFactory attaches TiberiumComponent
- **Pseudo-foundation**: 1x1 cell blocks building placement but NOT unit movement. `BuildingManager.can_place()` checks for TiberiumComponent in footprint cells.
- 3 visual stages based on remaining amount:
  1. 3 small cube meshes (low amount)
  2. 2 big cubes + 3 small cubes (medium amount)
  3. 5 big cubes (full/max amount)

### HarvestComponent
Harvester behavior logic. References TransportComponent for cargo capacity.
- States: IDLE → SEEK_NODE → APPROACH_NODE → HARVESTING → FULL → SEEK_REFINERY → APPROACH_REFINERY → DOCKING → UNLOADING → IDLE
- SEEK_NODE: query SpatialHash for nearest cell with TiberiumComponent (ignoring pseudo-foundation — units pass through)
- HARVESTING: tick fill rate at `GlobalRules.harvester_fill_rate`, deplete crystal amount. When full (storage == TransportComponent.storage) or crystal depleted → FULL
- SEEK_REFINERY: scan for nearest building with DockComponent where allowed_entities includes "HARV"
- DOCKING: navigate to dock position, orient to dock rotation
- UNLOADING: tick cargo → credits via DockComponent.unload_rate. When empty → IDLE
- Auto-targets nearest Tiberium crystal when idle with no cargo
- Can be manually ordered to a specific crystal via right-click

### DockComponent
Attached to refineries (and future airpads, repair pads).
```gdscript
class_name DockComponent extends Node
@export var dock_position: Vector3     # local offset where unit stops
@export var dock_rotation: float       # Y rotation the unit faces when docked
@export var allowed_entities: PackedStringArray = []
@export var unload_rate: float = 28.0  # amount/sec for unloading cargo
@export var load_rate: float = 0.0     # amount/sec (future: aircraft ammo reload)

var queue: Array[HarvestComponent] = []
signal slot_available()
```
- One harvester at a time. Others queue.
- Nearest non-occupied refinery preferred. If nearest is occupied, harvester queues there rather than traveling to a farther one.
- EntityData gets `@export var dock_position: Vector3` and `@export var dock_rotation: float`

### FoundationComponent.bib_cells
```gdscript
@export var bib_cells: PackedVector2i = []  # cell offsets from origin, within footprint
```
- Bib = flat concrete pad where harvesters drive onto (Refinery, War Factory, Service Depot)
- Cells within the foundation rect. Offsets outside are clamped/ignored.
- Bib cells are soft-blocked in SpatialHash — passable only for dock-queued harvesters
- EntityData gets `@export var bib_cells: PackedVector2i = []`

## TiberiumTree System

The TiberiumTree is a persistent map object that spawns and manages a Tiberium patch. Map designers drop a `TiberiumTree` scene into the map and configure it in the inspector.

- The tree is created via `EntityFactory` as a TERRAIN entity with `TiberiumTreeComponent` + `FoundationComponent(1x1)`
- It has a true foundation (blocks everything) — occupies a cell like a building
- No HealthComponent (indestructible), no SelectComponent (unselectable)
- Crystal entities are also TERRAIN entities (full EntityFactory path) with 1x1 pseudo-foundation
- Pseudo-foundation blocks `BuildingManager.can_place()` but allows unit movement through the cell
- `BuildingManager.can_place()` checks: for each footprint cell, if any entity has TiberiumComponent on that cell, the cell is blocked

## Game Data

### GlobalRules additions
```gdscript
@export var starting_credits: int = 0       # starting credits (skirmish = 0, missions vary)
@export var tiberium_value: float = 1.0     # credits per unit of tiberium refined
@export var harvester_fill_rate: float = 2.0  # tiberium units collected per second
```

### EntityData additions
```gdscript
# For TiberiumTree
@export var tiberium_tree: bool = false
@export var spawned_entity_id: String = ""
@export var radius_cells: int = 0
@export var node_count: int = 0
@export var amount_per_node: int = 0
@export var max_amount_per_node: int = 0

# For Tiberium crystals
@export var tiberium_resource: bool = false
@export var tiberium_amount: int = 0
@export var tiberium_max_amount: int = 0
@export var tiberium_type: int = 0
@export var tiberium_regrowth_rate: float = -1.0

# For buildings (dock + bib)
@export var bib_cells: PackedVector2i = []
@export var dock_position: Vector3 = Vector3.ZERO
@export var dock_rotation: float = 0.0
```

## Integration Points
- `BuildingManager.can_place()` → check footprint cells for TiberiumComponent entities (pseudo-foundation)
- `BuildingManager.place_building()` → stub deduction (replaced by build queue later)
- `FactoryComponent` / future production queue → deduct on queue
- `SpatialHash` → handle bib cells as soft-blocked
- `EntityFactory._add_components()` → add TiberiumTreeComponent, TiberiumComponent, HarvestComponent, DockComponent
- `GlobalRules.tres` → add new fields
- Map scenes → add TiberiumTree instances for Tiberium patches

## Credit Display UI

A `Label` above the build menu grid showing the current credit balance, updated in real-time via `EconomyManager.credits_changed` signal.

- Located directly above the building cameo grid in `BuildMenu.tscn`
- Uses a large monospace font (white, ~18px) with a "$" prefix
- Updates on every `credits_changed` emission — no polling in `_process()`
- When balance is insufficient for the cheapest buildable item, the label turns red
- Reads initial balance from `EconomyManager.get_balance(0)` in `_ready()`

## Future (Not in scope of #45)
- ServiceDepotComponent for repair deduction
- Build queue integration (separate issue)
- Factory queue integration (separate issue)
- Tiberium crystal growth/spread ticks (TiberiumTree regrowth)
- Tiberium toxicity/veins
- Multiplayer per-player treasury
