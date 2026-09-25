class_name FxData extends Resource

## One one-shot visual effect, configured as a `.tres`. Two primitives:
## SPRITE    -> AnimatedSprite3D + SpriteFrames (PNG sequence or sprite sheet).
## PARTICLES -> GPUParticles3D + embedded process/draw materials.
## Purely visual: callers keep owning their sounds (WeaponData.sound_report,
## WarheadData.sound_impact, EntityData.sound_die).

enum Kind { SPRITE, PARTICLES }

## Draw primitive for a PARTICLES effect.
enum ParticleShape { QUAD, TRIANGLE }

@export_group("Identity")
## Unique effect id (matches the `.tres` file name).
@export var id: String = ""
## Which primitive builds this effect.
@export var kind: Kind = Kind.SPRITE
## Explicit lifetime in seconds. 0 = derive from the effect (total sprite frame
## time, or particle `lifetime`).
@export var duration: float = 0.0

@export_group("Sprite")
## Frames for a SPRITE effect. Supports a PNG sequence (one texture per frame)
## and a sprite sheet (frames referencing atlas regions).
@export var sprite_frames: SpriteFrames = null
## Animation to play; empty / missing = the first animation in `sprite_frames`.
@export var animation: StringName = &"default"
## World size of one sprite pixel (matches the game's pixel scale).
@export var pixel_size: float = 0.01
## Sprite tint.
@export var modulate: Color = Color.WHITE

@export_group("Particles")
## Emission/behavior for a PARTICLES effect.
@export var process_material: ParticleProcessMaterial = null
## Draw material for the particle quad. Set `billboard_mode =
## BILLBOARD_PARTICLES` and (for animated sheets) `particles_anim_h_frames` /
## `_v_frames`. REQUIRED: `vertex_color_use_as_albedo = true`, otherwise the
## process material's `color` and any color/alpha ramp are ignored by the draw
## material.
@export var draw_material: StandardMaterial3D = null
## World-space edge length of the particle quad in metres. The process
## material's `scale_min` / `scale_max` vary each particle on top of this.
@export var quad_size: float = 0.1
## Draw primitive: a camera-facing quad, or a flat triangle (debris/sparks).
## A single triangle is one-sided, so a TRIANGLE effect's `draw_material` must
## disable culling (`cull_mode = CULL_DISABLED`) or it can face away and vanish.
@export var particle_shape: ParticleShape = ParticleShape.QUAD
@export var amount: int = 16
@export var lifetime: float = 1.0
@export var explosiveness: float = 1.0
## Seconds the emitter keeps spawning. 0 = burst: emission spreads across
## `lifetime` (rate = `amount / lifetime`), so the spawn window can never
## exceed a particle's own life. Above 0 decouples the two — the emitter runs
## for this long while each particle still lives `lifetime` seconds.
@export var spawn_duration: float = 0.0
@export var local_coords: bool = true

@export_group("Light")
## Omni light energy emitted by the effect. 0 = no light.
@export var light_energy: float = 0.0
## Omni light colour.
@export var light_color: Color = Color(1.0, 0.85, 0.45)
## Omni light range in metres.
@export var light_range: float = 2.0


func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty():
        errors.append("FxData: id is empty")
    if kind == Kind.SPRITE and sprite_frames == null:
        errors.append("%s: sprite effect has no sprite_frames" % id)
    if kind == Kind.PARTICLES and process_material == null:
        errors.append("%s: particle effect has no process_material" % id)
    return errors
