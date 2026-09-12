class_name SocketData extends Resource

## A named attachment point on an entity, owned by ArtData. A socket is most
## often a turret hardpoint, but the concept is general: exit points, VFX
## anchors, etc. Behavior data (EntityData) references sockets only by id, so
## geometry stays in art and per-unit binding stays in behavior data.

@export_group("Identity")
## Stable id referenced by EntityData weapon mount groups (e.g. "main").
@export var id: String = ""

@export_group("Placement")
## 3D pivot local to the entity origin: position and rest orientation of the
## socket. The socket forward axis is -Z of this basis (Godot convention).
@export var pivot: Transform3D = Transform3D.IDENTITY
## Whether the socket yaws to aim. false = fixed; a weapon on it forces the
## whole body to face the target.
@export var yaw_free: bool = true
## Barrel length in world units from the pivot along its forward axis, used to
## place the muzzle.
@export var barrel_length: float = 0.0

@export_group("Visual")
## Placeholder box size rendered until a real turret model exists
## (Vector3.ZERO = no placeholder).
@export var placeholder_size: Vector3 = Vector3.ZERO
## Reserved: turret model path (e.g. "res://.../<unit>tur.glb").
## Empty = placeholder box.
@export var model_path: String = ""
