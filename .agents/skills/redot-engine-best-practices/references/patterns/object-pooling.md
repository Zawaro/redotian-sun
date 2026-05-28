# Object Pooling Pattern

Reuse objects to avoid instantiation cost and GC pressure. Essential for frequently-spawned entities: bullets, particles, projectiles, floating damage numbers, and environmental effects in RTS games like unit death explosions.

## When to Use It

| Scenario | Need pooling? | Reason |
|----------|---------------|--------|
| 5–10 objects that live for the whole game (player units, structures) | No | Instantiate once at scene load; `queue_free()` on destruction is fine |
| Bullets/projectiles firing every frame in combat | Yes | Hundreds of spawns per second cause GC stutter without pooling |
| Particle effects (explosions, muzzle flash) | Yes | Short-lived objects spawned/destroyed rapidly are the #1 use case for pools |
| Damage numbers / floating text popups | Maybe | Low volume can skip pooling; high-volume UI may benefit from a pool |

## Implementation — Generic Object Pool

```gdscript
# object_pool.gd
class_name ObjectPool extends Node3D
## Reusable container for frequently-created/destroyed objects.
## Place one instance per scene that needs spawning, or make it an Autoload singleton.

@export var pooled_scene: PackedScene  # Assign in Inspector — the template to clone
@export var initial_size: int = 10    # Pre-warm pool with this many instances
@export var can_grow: bool = true     # Allow creating new objects if pool is exhausted


var _available: Array[Node3D] = []   # Objects not currently in use (stack — LIFO)
var _in_use: Array[Node3D] = []      # Currently active instances tracking


func _ready() -> void:
	for i in initial_size:
		var instance := _create_instance()
		if instance != null:
			_available.append(instance)

# --- Public API ---

## Acquire an object from the pool. Returns a fresh instance if pool is empty and can_grow == true.
func acquire(initial_position: Vector3 = Vector3.INF, initial_rotation: float = 0.0) -> Node3D:
	var instance := _get_or_create_instance()
	
	if not has_path_to_child("MeshRoot"):
		push_warning("ObjectPool acquired null instance — pooled_scene may be invalid")
		return null
	
	instance.global_position = initial_position if initial_position != Vector3.INF else instance.global_position
	instance.visible = true
	instance.process_mode = Node3D.PROCESS_MODE_INHERIT
	
	if not _in_use.has(instance):
		_in_use.append(instance)
	
	# Call spawn callback on the pooled object (convention: on_spawn with optional args dict)
	var args := {"position": instance.global_position, "rotation_degrees_y": initial_rotation}
	if instance.has_method("on_spawn"):
		instance.on_spawn(args)
	return instance

## Return an object to the pool. Call this when the object's lifetime has ended.
func release(instance: Node3D) -> void:
	if not is_instance_valid(instance):
		push_warning("ObjectPool.release() called with invalid node — ignoring")
		return
	
	if _in_use.has(instance):
		_in_use.erase(instance)
	
	if instance.has_method("on_despawn"):
		instance.on_despawn({})  # Convention: always pass empty dict for consistency
	
	instance.process_mode = Node3D.PROCESS_MODE_DISABLED
	instance.visible = false
	
	if not _available.has(instance):
		_available.append(instance)


# --- Internals ---

func _get_or_create_instance() -> Node3D:
	var instance: Node3D
	
	if _available.is_empty():
		if can_grow:
			instance = _create_instance()
			return instance  # New object — not added to pool yet, just returned directly
		else:
			push_warning("ObjectPool exhausted and cannot grow")
			return null
	else:
		instance = _available.pop_back()
	
	return instance


func _create_instance() -> Node3D:
	if pooled_scene == null:
		push_error("ObjectPool: pooled_scene is not set in Inspector. Cannot create instances.")
		return null
	
	var new_instance := pooled_scene.instantiate() as Node3D
	
	assert(new_instance != null, "pooled_scene failed to instantiate")
	
	add_child(new_instance)  # Required — child of pool node for proper scene lifecycle
	new_instance.process_mode = Node3D.PROCESS_MODE_DISABLED
	new_instance.visible = false
	
	# Auto-connect returned_to_pool signal if the pooled object defines one
	if new_instance.has_signal("returned_to_pool"):
		new_instance.returned_to_pool.connect(_on_returned)
	
	return new_instance


func _on_returned() -> void:
	## Called when a pooled object emits its return signal.
	## The pool itself doesn't need to know which specific instance returned —
	## it's already in _in_use, and we just pop from available stack on next acquire().
	pass
