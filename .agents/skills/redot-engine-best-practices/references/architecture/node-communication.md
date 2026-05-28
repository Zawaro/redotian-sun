# Node Communication Patterns

How nodes in a Redot scene tree should talk to each other — ordered by preference from most decoupled to least.

## Rule: Signal Up, Call Down

| Direction | Mechanism | Why |
|-----------|----------|-----|
| **Child → Parent** (up the tree) | Child emits signals; parent connects in `_ready()` | Child has no knowledge of who its parent is — works even if scene hierarchy changes |
| **Parent → Child** (down the tree) | Parent calls methods on known child references (`@onready var x: Type = $Child`) or passes data via arguments to public API | Parent owns and wires children; it knows exactly what each child exposes |

### Example — Health Component Notifies Its Owner

```gdscript
# health_component.gd (child) — emits signals, does NOT call parent methods directly
class_name HealthComponent extends Node3D

signal health_changed(current: int, maximum: int)
signal died(position: Vector3)

var _current_health: int = 100
@export var max_health: int = 100

func take_damage(amount: int, source: Node3D = null) -> void:
	_current_health = maxi(0, _current_health - amount)
	health_changed.emit(_current_health, max_health)
	if _current_health <= 0:
		died.emit(global_position)


# player.gd (parent/owner) — connects to child signals and reacts
class_name Player extends CharacterBody3D

@onready var health_component: HealthComponent = $HealthComponent

func _ready() -> void:
	health_component.health_changed.connect(_on_health_changed)  # Connect in _ready, not at top-level scope
	health_component.died.connect(_on_died)

func _on_health_changed(current: int, maximum: int) -> void:
	update_health_bar_ui(current, maximum)

func _on_died(position: Vector3) -> void:
	queue_free()  # Parent decides what to do when child reports death


```

## Pattern A: Direct Method Calls (Parent → Child) — Preferred for Known Relationships

When a parent node **owns** the scene tree placement of its children, call public methods directly. This is fast and type-safe.

```gdscript
# enemy.gd — owner wires this unit's components
@onready var health_component: HealthComponent = $HealthComponent
@onready var movement_controller: Node3D  # Assume a MovementController node exists as sibling

func take_damage_from(source_node: Node3D, amount: int) -> void:
	# Call child method directly — parent owns this relationship
	var actual := health_component.take_damage(amount, source_node)
	
	if health_component.current_health <= 0:
		on_unit_destroyed()


```

## Pattern B: Signals (Child → Parent or Decoupled Broadcasts)

Use signals when the emitter doesn't know who will listen — useful for global events, HUD updates from game logic nodes, or cross-cutting concerns.

### Per-Instance Signals (One-to-One or One-to-Few)

```gdscript
# Bullet hits a target → emits signal on itself; parent connects handler
signal hit(target_position: Vector3)

func _on_body_entered(body: Node3D) -> void:
	hit.emit(global_position)  # Emit — doesn't know who the body is
	queue_free()


```

### Global Event Bus (Many-to-Many via Autoload Singleton)

For truly decoupled systems that need to broadcast events across unrelated scene hierarchies, use an autoload singleton as a signal bus. Keep it **thin** — no game logic inside the event bus itself; only signal declarations and optional helper methods for convenience.

```gdscript
# event_bus.gd (registered in Project Settings → Autoload with name "EventBus")
extends Node

## Global communication channel for cross-scene events.
## Keep this file as a list of signal declarations — no logic here.

signal player_spawned(player: CharacterBody3D)
signal entity_died(position: Vector3, entity_name: StringName)
signal score_changed(new_score: int)
signal round_started(round_number: int)
signal game_paused(is_paused: bool)


```

Usage — any node can emit or connect to these signals without holding references to each other. The `EventBus` autoload is globally accessible by name.

## Pattern C: Groups (Broadcasting to Many Nodes of the Same Type)

Groups provide a lightweight way to address multiple nodes at once when you don't have direct references. Use sparingly — prefer signals or method calls for critical paths where type safety matters.

```gdscript
# In _ready() of each component that should be group-addressable:
func _ready() -> void:
	if select_box_type != SelectBoxType.Structure:
		add_to_group("entities")  # Add to scene-specific group


// Later — broadcast a message to all nodes in the "entities" group
func deselect_all_entities() -> void:
	for entity_node in get_tree().get_nodes_in_group("entities"):
		if entity_node is SelectComponent and entity_node.has_method("set_is_selected"):
			entity_node.set_is_selected(false)

```

**When to use groups:**
- Iterating over all entities for bulk operations (selection, rendering culling, save/load iteration)
- Debug visualization toggles that need to affect many nodes at once

**Avoid groups when:**
- You only have 1–2 targets — direct references are faster and type-safe
- The group membership changes frequently during gameplay (adding/removing from groups has overhead)

## Anti-Pattern: Circular References Between Siblings

```gdscript
# BAD: Child A holds reference to sibling B, AND child B holds reference back to A.
// This creates tight coupling — neither can be reused independently, and cleanup order matters.

class_name WeaponMount extends Node3D:
	@export var target_enemy: Enemy  # Direct reference to a specific enemy type — bad!


```

**Fix:** Remove the cross-reference. Let the parent (or an external system like SelectionManager) decide which `Enemy` is targeted, and pass it as a method argument or via signal data rather than storing sibling references directly between children.
