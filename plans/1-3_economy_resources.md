# Economy & Resources System - Redotian Sun

## Overview
The economy system manages Tiberium harvesting, credit tracking, and spending — the core RTS resource loop. Unlike SimCity, there is **no passive income**. Every credit comes from the harvest cycle: harvester → Tiberium pod → fill → refinery → dump → credits.

## Core Loop
```
TiberiumTree (persistent spawner on map)
  └── spawns Tiberium pod entities (one per cell within radius)
        └── Harvester drives to pod → fills cargo (pod depletes)
              → drives to nearest refinery → docks at bib platform → dumps cargo → credits added
              → repeats (or finds new pod if current is depleted)
```

## Overlay Concept
Tiberium and Tiberium Tree entities are **overlays** — TERRAIN-type entities with 1×1 foundation that:
- **Block building placement** (checked by `_has_tiberium_on_cell()`)
- **Do NOT block unit movement or pathfinding**
- Are indestructible by weapons (no HealthComponent)
- Are unselectable by the player (no SelectComponent)
- Tiberium pods use **pseudo-foundation**: blocks building placement via FoundationComponent but has no collision shape for units
- Tiberium trees use **true 1×1 foundation**: blocks everything (like a building cell)

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
Attached to a TiberiumTree TERRAIN entity (1x1 true foundation, indestructible, unselectable). The tree is a persistent spawner placed by map designers — it does NOT disappear when pods are depleted. Future: growth/spread ticks managed here.
```gdscript
class_name TiberiumTreeComponent extends Node
@export var spawned_entity_id: String = ""       # EntityData ID of pod to spawn (e.g. "TIB")
@export var radius_cells: int = 8                # spawn radius in grid cells
@export var resource_type_id: String = "tiberium_green"  # resource sub-type to spawn
@export var node_count: int = 12                 # how many pod entities to spawn
@export var amount_per_node: int = 300           # tiberium per pod entity
@export var max_amount_per_node: int = 300       # fully grown amount
@export var regrowth_rate: float = -1.0          # -1 = use GlobalRules.growth_rate
```
- On `_ready()` with `call_deferred()`: spawn `node_count` pod entities via `EntityFactory.create_entity(spawned_entity_id)` scattered within `radius_cells` with 2-cell minimum spacing
- Each spawned pod gets TiberiumComponent configured from tree parameters, including `resource_type_id`
- Tree persists on map regardless of pod depletion
- Placeholder art: a thin pole (`0.33 × 2.0 × 0.33` BoxMesh) via ArtComponent placeholder_size. Named "Tiberium Tree Art" to distinguish from future normal tree art.

### TiberiumComponent
Attached to TERRAIN-type entity instances (individual Tiberium pods, one per cell). Acts as an overlay.
```gdscript
class_name TiberiumComponent extends Node
@export var amount: int = 0                      # current Tiberium in this pod
@export var max_amount: int = 0                  # initial / fully grown amount
@export var resource_type_id: String = "tiberium_green"  # resource sub-type
@export var regrowth_rate: float = -1.0          # -1 = use GlobalRules.growth_rate
@export var spread_count: int = 0                # times this entity has spread
```
- EntityData gets `@export var tiberium_resource: bool = false` so EntityFactory attaches TiberiumComponent
- **Pseudo-foundation**: 1x1 cell blocks building placement but NOT unit movement. `BuildingManager.can_place()` checks for TiberiumComponent in footprint cells.
- 3 visual stages based on remaining amount, rendered as procedurally generated cube clusters. Cube sizes and positions are seeded per-cell using `RandomNumberGenerator.seed = hash(cell_position)` for unique visual variety per cell:
  1. **Stage 0 (≤33%, low amount)**: 3 small cubes (random size 0.15–0.35).
  2. **Stage 1 (34–66%, medium amount)**: 2 big cubes (0.35–0.55) + 3 small cubes (0.15–0.25).
  3. **Stage 2 (≥67%, full amount)**: 5 big cubes (0.35–0.55).
- All cubes are green-tinted (`Color(0.2, 0.8, 0.2)`).
- `_update_visual()` is called after each `collect()` to switch visible stages.
- When `amount <= 0` after a `collect()` call, the entity self-destructs via `get_parent().queue_free()`.
  `queue_free()` is deferred (end-of-frame), so the harvest loop releases `_current_tiberium_node = null`
  in the same frame safely. All `is_instance_valid()` guards in HarvestComponent handle this.

### DockHostComponent (on buildings — refineries, airpads, repair pads)
Manages the dock slot, queue, and cell reservation. Renamed from DockComponent.
```gdscript
class_name DockHostComponent extends Node
@export var dock_position: Vector3     # local offset where unit stops
@export var dock_rotation: float       # Y rotation the unit faces when docked
@export var dock_types: PackedStringArray = []  # what this host offers (e.g. ["harvest"])
@export var max_queue_length: int = 3  # max queued clients
@export var dock_wait_ticks: int = 10  # ticks before queued client docks

var queue: Array[Node] = []
var current_docker: Node = null
signal docker_docked(docker: Node)
signal docker_undocked(docker: Node)
signal slot_available
```
- One client at a time. Others queue up to `max_queue_length`.
- Queued clients wait `dock_wait_ticks` before docking (visual polish).
- Reads foundation from FoundationComponent sibling (no duplicate `foundation` export).
- Reserve/release dock cell in SpatialHash on dock/undock.

### DockClientComponent (on units — harvesters, future service depot clients)
Handles dock-finding, reservation-before-movement, and occupancy-aware host selection.
```gdscript
class_name DockClientComponent extends Node
@export var can_dock_with: PackedStringArray = []  # entity IDs (e.g. ["PROC"])
@export var occupancy_penalty: float = 5.0         # added to distance per queued client
@export var search_radius_cells: int = 20

var _reserved_host: Node3D = null
signal dock_slot_reserved(host: Node3D)
signal dock_slot_failed
```
- Searches Buildings group for DockHostComponent with matching entity ID.
- Applies occupancy penalty to distance — distributes harvesters across refineries.
- Reserves slot before movement — prevents wasted pathfinding.
- Client decides compatibility via `can_dock_with`, not host's `allowed_entities`.

### RefineryComponent (on refinery buildings)
Declares what resource categories the building accepts. Separate from DockUnloadComponent (data vs logic).
```gdscript
class_name RefineryComponent extends Node
@export var accepted_resource_categories: PackedStringArray = []  # e.g. ["tiberium"]
@export var unload_rate: float = 2.33
```
- DockUnloadComponent reads this to validate cargo before unloading.
- Future ServiceDepotComponent can reuse DockClientComponent without inheriting refinery logic.

### HarvestComponent
Harvester behavior logic. References TransportComponent for cargo capacity and DockClientComponent for dock operations.
- States: IDLE → SEEK_RESOURCE → HARVESTING → FULL → SEEK_REFINERY → DOCKING → UNLOADING → IDLE
- SEEK_RESOURCE: search scene tree for nearest entity with TiberiumComponent matching `harvestable_types` category (e.g. `["tiberium"]` umbrella matches green/blue/red)
- HARVESTING: tick fill rate at `GlobalRules.harvester_fill_rate`, deplete pod amount via `TiberiumComponent.collect()`. When full (cargo total == TransportComponent.resource_capacity) or pod depleted → FULL
- **Cell occupation**: No special harvester positioning logic — MovementController pathfinds to the pod normally. The pod's TiberiumComponent blocks building placement via `_has_tiberium_on_cell()` while alive. When depleted and freed, the cell becomes available. No SpatialHash registration needed.
- FULL: delegates to DockClientComponent.try_reserve_dock(). On success → DOCKING. On failure → QUEUED.
- DOCKING: navigate to dock position, orient to dock rotation
- UNLOADING: passive — DockUnloadComponent on the building handles the tick. When empty → IDLE.
- Auto-targets nearest matching resource node when idle with no cargo
- Can be manually ordered to a specific pod via left-click (context-sensitive: click tiberium → harvest, click refinery → dock)

### FoundationComponent.bib_cells
```gdscript
@export var bib_cells: PackedVector2i = []  # cell offsets from origin, within footprint
```
- Bib = flat concrete pad where harvesters drive onto (Refinery, War Factory, Service Depot)
- Cells within the foundation rect. Offsets outside are clamped/ignored.
- Bib cells are soft-blocked in SpatialHash — passable only for dock-queued harvesters
- EntityData gets `@export var bib_cells: PackedVector2i = []`

### Refinery Placeholder Art
The GDI Refinery uses an ArtData resource with `placeholder_size = Vector3(7, 2, 5)` — 1 unit smaller in XZ than the foundation-based default (`Vector3(8, 2, 6)`). The foundation remains 4×3 for placement, but the visual placeholder box is slightly smaller.

### FreeUnitComponent
Reusable one-shot component that spawns a free unit when its parent enters the scene tree, then removes itself.
```gdscript
class_name FreeUnitComponent extends Node
@export var free_unit_id: String = ""
```
- On `_ready()`: skip if `Engine.is_editor_hint()` or `get_parent().get_meta("_preview", false)` (ghost guard).
- Calls `_spawn_free_unit()` via `call_deferred()`:
  1. Find an adjacent free cell outside the entity's foundation (orthogonal first, then diagonal, search up to ~5 cells).
  2. If no cell found after search radius, `queue_free()` silently (unit not spawned).
  3. Create entity via `EntityFactory.create_entity(free_unit_id)`.
  4. Position it at the adjacent cell's center (cell size 2×2).
  5. Add it as a sibling in the scene tree.
  6. If the spawned entity has a HarvestComponent, find the nearest resource node via `_find_nearest_resource()` and call `set_target_node()` to auto-start harvesting.
  7. `queue_free()` itself — gone after one frame.
- BuildingManager ghost preview sets `entity.set_meta("_preview", true)` so FreeUnitComponent doesn't fire on the preview entity.

## TiberiumTree System

The TiberiumTree is a persistent map object that spawns and manages a Tiberium patch. Map designers drop a `TiberiumTree` scene into the map and configure it in the inspector.

- The tree is created via `EntityFactory` as a TERRAIN entity with `TiberiumTreeComponent` + `FoundationComponent(1x1)`
- It has a true foundation (blocks everything) — occupies a cell like a building
- No HealthComponent (indestructible), no SelectComponent (unselectable)
- Tiberium pods are also TERRAIN overlay entities (full EntityFactory path) with 1x1 pseudo-foundation
- Pseudo-foundation blocks `BuildingManager.can_place()` but allows unit movement through the cell
- `BuildingManager.can_place()` checks: for each footprint cell, if any entity has TiberiumComponent on that cell, the cell is blocked

## Map Editor — Tiberium Tools & Entity Persistence

The map editor provides tools to paint Tiberium pods, place Tiberium trees, and erase both. All painted/placed entities persist in the map JSON file and are recreated on load. Entities are placed at the center of 2×2 unit cells.

### Editor UI Layout
- Top toolbar row: tools arranged horizontally
  `[Save] [Load] | [Paint Height] [Paint Tiberium] [Place Tree] [Erase] | [Strength: HSlider] [Radius: SpinBox]`
- Minimap in top-right corner, above the toolbar
- Toggle tools are radio-button exclusive (one active at a time)
- **Strength** (HSlider): 0–100%, determines amount of Tiberium added/removed per paint pass
- **Radius** (SpinBox): brush radius in cells for Paint Tiberium and Erase

### Tool Behaviors
- **Paint Height** — existing HeightPainter (click+drag raises/lowers terrain). No change.
- **Paint Tiberium** — click+drag over cells: calls `EntityFactory.create_entity("TIB", {tiberium_amount, tiberium_max_amount, resource_type_id})` for each cell within brush radius. If a Tiberium pod already exists on the cell, adds to its amount (up to max_amount) instead of creating a duplicate. Entities placed at cell center.
- **Place Tree** — single-click (no drag): places a TiberiumTree entity on the clicked cell. If the cell is occupied (by a pod or any entity), the existing entity is removed and replaced with the tree. Entities placed at cell center.
- **Erase** — click+drag within brush radius: reduces Tiberium amount by `strength% * max_amount` per cell per pass. When amount ≤ 0, removes the entity and frees the cell.

### Entity Tracking
`MapEditor` holds `_painted_entities: Dictionary` (key = `"x,y"` string, value = `{ node: Node3D, data: Dictionary }`). Used for:
- O(1) lookup when erasing or re-painting a cell
- O(1) lookup when placing tree on occupied cell (replace)
- Serialization on save
This is editor-local — not using SpatialHash (runtime system).

### Map Persistence (JSON v3)
```
{
  "version": 3,
  "grid_cells": 512,
  "vertices": { "0,0": 1, ... },
  "cells": { "0,0": { "height": 2 }, ... },
  "entities": [
    { "id": "TIB", "cell": "12,5", "tiberium_amount": 300, "tiberium_max_amount": 300, "resource_type_id": "tiberium_green" },
    { "id": "TIBTRE01", "cell": "8,3" }
  ]
}
```

### MapLoader.gd
New script that reads the JSON and restores both terrain and entities:
1. Pass `"vertices"`/`"cells"` to `TerrainSystem.import_from_json()`
2. Iterate `"entities"` array, call `EntityFactory.create_entity(id, overrides)` for each entry
3. Add entities to scene, register in editor's `_painted_entities` dict
Called from MapEditor load flow and game map load.

### ArtComponent.placeholder_size
Add to ArtData:
```
@export var placeholder_size: Vector3 = Vector3.ZERO  # ZERO = auto from foundation
```
`_add_placeholder()` uses `placeholder_size` if non-zero, else existing foundation-based sizing.
TiberiumTree ArtData sets `placeholder_size = Vector3(0.33, 2.0, 0.33)` for a thin pole.

## Resource Type System

### ResourceType Resource Class
Defines a resource type with parent/sub-type hierarchy.
```gdscript
class_name ResourceType extends Resource
@export var id: String = ""              # "tiberium_green", "vein"
@export var display_name: String = ""
@export var category: String = ""        # parent category (e.g. "tiberium") — empty = is a category
@export var parent_type: String = ""     # immediate parent type — empty = is a category
@export var value_per_unit: float = 1.0  # credits per unit when refined
@export var color: Color = Color.WHITE   # for future visual differentiation
```

### Resource Type Hierarchy
```
GlobalRules.resource_types: Dictionary = {
    "tiberium":       ResourceType  {category="", value_per_unit=1.0},        # parent category
    "tiberium_green": ResourceType  {category="tiberium", value_per_unit=1.0}, # sub-type
    "tiberium_blue":  ResourceType  {category="tiberium", value_per_unit=2.0}, # sub-type
    "tiberium_red":   ResourceType  {category="tiberium", value_per_unit=3.0}, # sub-type
    "vein":           ResourceType  {category="weed", value_per_unit=0.5},     # category
}
```

- HarvestComponent uses `harvestable_types = ["tiberium"]` which umbrellas all sub-types via `GlobalRules.get_resource_category()`
- TiberiumComponent stores `resource_type_id: String` (e.g. `"tiberium_green"`)
- RefineryComponent declares `accepted_resource_categories` (e.g. `["tiberium"]`)
- Resource types stored as `.tres` files under `resources/resource_types/`

### TransportComponent
```gdscript
class_name TransportComponent extends Node
@export var passengers: int = 0        # infantry capacity (APC, etc.)
@export var resource_capacity: int = 0 # resource cargo capacity (harvester)
@export var dock: String = ""          # entity ID of dock target
@export var harvester: bool = false
@export var pip_scale: String = ""

var cargo: Dictionary = {}  # {resource_type_id: amount}, e.g. {"tiberium_green": 500}

func get_cargo_total() -> int          # sum all values
func get_cargo_value(global_rules) -> int  # sum of amount × value_per_unit
func add_cargo(type_id, amount) -> int     # returns actual added (capped by capacity)
func remove_cargo(type_id, amount) -> int  # returns actual removed
```

## Game Data

### GlobalRules additions
```gdscript
@export var starting_credits: int = 0
@export var harvester_fill_rate: float = 2.0
@export var resource_types: Dictionary = {}  # {id: ResourceType} — replaces tiberium_value

func get_resource_type(id: String) -> ResourceType
func get_resource_category(resource_id: String) -> String
func get_subtypes(category_id: String) -> Array[String]
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

# For Tiberium pods
@export var tiberium_resource: bool = false
@export var tiberium_amount: int = 0
@export var tiberium_max_amount: int = 0
@export var resource_type_id: String = ""  # replaces tiberium_type: int
@export var tiberium_regrowth_rate: float = -1.0

# For buildings (dock + bib)
@export var bib_cells: PackedVector2i = []
@export var dock_position: Vector3 = Vector3.ZERO
@export var dock_rotation: float = 0.0
@export var accepted_resource_categories: PackedStringArray = []  # for refineries

# For units that dock
@export var dock: String = ""  # target entity ID (e.g. "PROC")

# For factory buildings with free units
@export var factory: String = ""
@export var free_unit: String = ""

# For harvester cargo
@export var resource_capacity: int = 0  # replaces storage

# For hitbox sizing
@export var hitbox_size: Vector3 = Vector3.ZERO
```

## Integration Points
- `BuildingManager.can_place()` → check footprint cells for TiberiumComponent entities (pseudo-foundation)
- `BuildingManager._create_building_preview()` → set `_preview` meta on ghost entities
- `BuildingManager.place_building()` → stub deduction (replaced by build queue later)
- `FactoryComponent` / future production queue → deduct on queue
- `SpatialHash` → handle bib cells as soft-blocked
- `EntityFactory._add_components()` → add TiberiumTreeComponent, TiberiumComponent, HarvestComponent, DockHostComponent, DockClientComponent, RefineryComponent, FreeUnitComponent
- `GlobalRules.tres` → resource_types dictionary with ResourceType entries
- Map scenes → add TiberiumTree instances for Tiberium patches
- `MapLoader.gd` → restore terrain + entities from JSON v3 (uses `resource_type_id`)
- `ArtData.gd` → add `placeholder_size`
- `ArtComponent.gd` → honor `placeholder_size` in `_add_placeholder()`

## Credit Display UI

A `Label` above the build menu grid showing the current credit balance, updated in real-time via `EconomyManager.credits_changed` signal.

- Located in `Sidebar.tscn` (renamed from BuildMenu.tscn)
- Uses white-to-green text (~18px) with a "$" prefix
- Updates on every `credits_changed` emission — no polling in `_process()`
- When balance is insufficient for the cheapest buildable item, the label turns red
- Reads initial balance from `EconomyManager.get_balance(0)` in `_ready()`

## Transport Pip Display

When a vehicle with cargo or passengers is selected, small colored squares (pips) appear below the selection rectangle to indicate fill level. This is the classic Tiberian Sun visual feedback for transport capacity.

### Visual Design

- **Pip mesh**: QuadMesh with black outline (slightly larger QuadMesh behind fill)
- **Billboard**: `BILLBOARD_FIXED_Y` — always faces camera, flat on Y axis
- **Position**: Horizontal row centered below the vehicle selection box L-shaped corners
- **Size**: 0.12 × 0.12 fill, 0.15 × 0.15 outline
- **Max pips**: 5 for cargo, 5 for passengers

### Cargo Pips (Harvesters)

- One pip filled per 20% of `resource_capacity`
- Fill color from `ResourceType.color` (e.g., green for tiberium)
- Empty pips: dark gray (`Color(0.2, 0.2, 0.2)`)
- Updates in real-time via `TransportComponent.cargo_changed` signal

### Passenger Pips (APCs, Transports)

- One pip per passenger slot (up to 5)
- Fill color: white when occupied, dark gray when empty
- Updates in real-time via `TransportComponent.passenger_changed` signal

### Signal Flow

```
HarvestComponent → TransportComponent.add_cargo() → emits cargo_changed(current, capacity, type_id)
                                                      ↓
SelectComponent._on_cargo_changed() → updates pip fill colors

TransportComponent.add_passenger() → emits passenger_changed(current, max)
                                       ↓
SelectComponent._on_passenger_changed() → updates pip fill colors
```

### Implementation Notes

- SelectComponent creates pips in `_ready()` via `call_deferred("_setup_transport_pips")` (TransportComponent is added after SelectComponent by EntityFactory)
- Pips are children of SelectComponent — visibility handled by existing `_update_visibility()` (shows when selected)
- Each pip = two MeshInstance3D nodes (outline + fill) added as children

## Future (Not in scope of #50)
- ServiceDepotComponent for repair deduction (DockClientComponent is generic enough to support it)
- Build queue integration (separate issue)
- Factory queue integration (separate issue)
- Animated BIGBLUE/BIGBLUE3 tiberium variants
- Real 3D models replacing placeholder cubes (20 variants × 3 stages per tiberium type)
- Normal tree art (separate from Tiberium Tree Art)
- Tiberium toxicity/veins (ResourceType for "vein" category exists, needs gameplay)
- Multiplayer per-player treasury
