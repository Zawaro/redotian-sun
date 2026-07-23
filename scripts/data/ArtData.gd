class_name ArtData extends Resource

## Art configuration for an entity — defines model, textures, animations,
## and rendering properties. Referenced by EntityData.art_data.

## Identity
@export var id: String = ""

## Model
## Whether this entity uses a voxel model (true) or a polygonal mesh (false).
# ponytail: schema-first, no consumer yet
@export var is_voxel: bool = false
## Whether the model supports player-color remapping (e.g., unit tinting).
@export var is_remappable: bool = false
## Path to the 3D model scene (e.g., "res://assets/models/infantry/e1.glb").
@export var model_path: String = ""
## Path to the diffuse/albedo texture override (empty = use model's default).
@export var texture_path: String = ""
## Path to the sidebar cameo (build icon) image (e.g., "res://assets/ui/cameos/e1.png").
# ponytail: schema-first, no consumer yet
@export var cameo_path: String = ""
## Path to the buildup scene played during construction (buildings only).
# ponytail: schema-first, no consumer yet
@export var buildup_scene: String = ""

## Dimensions
## Footprint in cells (width × depth) — must match EntityData.foundation.
@export var foundation: Vector2i = Vector2i(1, 1)
## Visual height in world units — affects bounding box and selection overlay.
@export var height: float = 1.0

## Turret
## Horizontal offset in voxels from the entity origin to the turret pivot point.
# ponytail: schema-first, no consumer yet
@export var turret_offset: float = 0.0
## Length of the gun barrel in voxels — affects muzzle flash position.
# ponytail: schema-first, no consumer yet
@export var barrel_length: float = 0.0

## Fire offsets — muzzle positions in voxels (Front-Length-Height) relative to entity origin.
## Front = forward distance, Length = lateral offset, Height = vertical offset.
# ponytail: schema-first, no consumer yet
@export var primary_fire_offset: Vector3 = Vector3.ZERO
# ponytail: schema-first, no consumer yet
@export var secondary_fire_offset: Vector3 = Vector3.ZERO
## Barrel length for primary weapon (overrides global barrel_length for this weapon).
# ponytail: schema-first, no consumer yet
@export var primary_barrel_length: float = 0.0
## Barrel length for secondary weapon.
# ponytail: schema-first, no consumer yet
@export var secondary_barrel_length: float = 0.0

## Animations
## Active animation tracks played on this entity (e.g., idle, walk, fire).
@export var active_anims: Array[ActiveAnimData] = []
## Infantry sequence name (e.g., "E1Sequence") — references [SequenceName] in art.ini
## which defines frame ranges for Ready, Walk, FireUp, Die, etc.
# ponytail: schema-first, no consumer yet
@export var sequence: String = ""
## Whether infantry has crawl (prone) animation frames.
# ponytail: schema-first, no consumer yet
@export var crawls: bool = false
## Number of frames in the fire-up animation (transition from idle to firing pose).
# ponytail: schema-first, no consumer yet
@export var fire_up: int = 0

## Infantry/vehicle walk/firing frames
## Number of walk animation frames (used for voxel frame interpolation).
# ponytail: schema-first, no consumer yet
@export var walk_frames: int = 0
## Number of firing animation frames.
# ponytail: schema-first, no consumer yet
@export var firing_frames: int = 0
## Whether the loading/boarding animation is visible to other players.
# ponytail: schema-first, no consumer yet
@export var visible_load: bool = false

## Building animations
## Name of the buildup animation played during construction.
# ponytail: schema-first, no consumer yet
@export var buildup_name: String = ""
## Name of the deployment animation (e.g., MCV unfolding).
# ponytail: schema-first, no consumer yet
@export var deploying_anim: String = ""
## Name of the door open/close animation.
# ponytail: schema-first, no consumer yet
@export var door_anim: String = ""
## Number of door stages (for multi-step door animations).
# ponytail: schema-first, no consumer yet
@export var door_stages: int = 0
## Name of the animation played under the door (production output).
# ponytail: schema-first, no consumer yet
@export var under_door_anim: String = ""
## Name of the production animation (e.g., unit emerging from factory).
# ponytail: schema-first, no consumer yet
@export var production_anim: String = ""
## Production animation X offset in voxels.
# ponytail: schema-first, no consumer yet
@export var production_anim_x: float = 0.0
## Production animation Y offset in voxels.
# ponytail: schema-first, no consumer yet
@export var production_anim_y: float = 0.0
## Whether production animation uses Y-sort (render in front of entities at same depth).
# ponytail: schema-first, no consumer yet
@export var production_anim_ysort: bool = false
## Production animation Z-adjust (vertical offset for rendering order).
# ponytail: schema-first, no consumer yet
@export var production_anim_zadjust: float = 0.0
## Name of the animation played before production starts (e.g., door opening).
# ponytail: schema-first, no consumer yet
@export var pre_production_anim: String = ""

## Additional active animation tracks (beyond the first).
# ponytail: schema-first, no consumer yet
@export var active_anim_two: String = ""
# ponytail: schema-first, no consumer yet
@export var active_anim_three: String = ""
# ponytail: schema-first, no consumer yet
@export var active_anim_four: String = ""

## Power-up animations (played when building is powered on).
# ponytail: schema-first, no consumer yet
@export var power_up1_anim: String = ""
# ponytail: schema-first, no consumer yet
@export var power_up2_anim: String = ""
# ponytail: schema-first, no consumer yet
@export var power_up3_anim: String = ""
## Power-up location offsets in voxels.
# ponytail: schema-first, no consumer yet
@export var power_up1_loc: Vector3 = Vector3.ZERO
# ponytail: schema-first, no consumer yet
@export var power_up2_loc: Vector3 = Vector3.ZERO
# ponytail: schema-first, no consumer yet
@export var power_up3_loc: Vector3 = Vector3.ZERO
## Power-up Y-sort flags.
# ponytail: schema-first, no consumer yet
@export var power_up1_sort: bool = false
# ponytail: schema-first, no consumer yet
@export var power_up2_sort: bool = false
# ponytail: schema-first, no consumer yet
@export var power_up3_sort: bool = false

## Special animations
# ponytail: schema-first, no consumer yet
@export var special_anim: String = ""
## Name of the charge-up animation (e.g., Obelisk charging).
# ponytail: schema-first, no consumer yet
@export var charge_anim: String = ""

## Building damage visuals
## Whether silo shows damage stages (visual change at low health).
# ponytail: schema-first, no consumer yet
@export var silo_damage: bool = false
## Whether the turret has no recoil animation when firing.
# ponytail: schema-first, no consumer yet
@export var recoilless: bool = false
## Number of damage visual levels (0 = no damage stages).
# ponytail: schema-first, no consumer yet
@export var damage_levels: int = 0

## SAM site
## Midpoint offset for projectile launch tracking.
# ponytail: schema-first, no consumer yet
@export var mid_point: Vector3 = Vector3.ZERO

## Gate
## Number of gate open/close stages.
# ponytail: schema-first, no consumer yet
@export var gate_stages: int = 0

## Overlay
## Path to the overlay texture (e.g., rubble, sandbags).
# ponytail: schema-first, no consumer yet
@export var overlay_texture_path: String = ""

## Rendering
## Whether UV coordinates are normalized (0–1 range instead of pixel coords).
# ponytail: schema-first, no consumer yet
@export var normalized: bool = false
## Whether to use the turret's own shadow instead of the body shadow.
# ponytail: schema-first, no consumer yet
@export var use_turret_shadow: bool = false
## Which shadow sprite index to use (for multi-shadow models).
# ponytail: schema-first, no consumer yet
@export var shadow_index: int = 0

## Theater
## Whether this entity uses theater-specific art (e.g., snow/sand terrain variants).
# ponytail: schema-first, no consumer yet
@export var new_theater: bool = false
## Whether the model renders as a flat billboard (always faces camera).
# ponytail: schema-first, no consumer yet
@export var flat: bool = false
## Whether the entity has an extra damage stage (visual change at low health).
# ponytail: schema-first, no consumer yet
@export var extra_damage_stage: bool = false
## Whether the entity uses a theater-specific palette for coloring.
# ponytail: schema-first, no consumer yet
@export var terrain_palette: bool = false

## Placeholder — colored box shown when no model is loaded.
## Size in world units (Vector3.ZERO = no placeholder rendered).
@export var placeholder_size: Vector3 = Vector3.ZERO
## 2D outline size for the selection overlay (Vector2.ZERO = use default).
@export var outline_2d_size: Vector2 = Vector2.ZERO
## Number of cargo/passenger pips to display on the selection overlay (0 = use default).
@export var pip_count: int = 0
## Whether this entity demands loading (affects LOD and streaming priority).
# ponytail: schema-first, no consumer yet
@export var demand_load: bool = false


func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty():
        errors.append("ArtData: id is empty")
    for anim in active_anims:
        if anim and anim.anim_name.is_empty():
            errors.append("%s: active_anim has empty anim_name" % id)
    return errors
