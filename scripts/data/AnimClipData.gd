class_name AnimClipData extends Resource

## One animated visual attached to an entity: a GLB clip plus where and how it
## plays. Mirrors the art.ini ActiveAnim / DoorAnim / ProductionAnim family.
## Behavior is driven by `role`: ACTIVE entries loop and are power-gated and
## damaged-swapped; the other roles are one-shot lifecycle clips.

enum Role {
    ACTIVE,
    DOOR,
    UNDER_DOOR,
    PRODUCTION,
    PRE_PRODUCTION,
    BUILDUP,
    DEPLOY,
    SPECIAL,
    CHARGE,
    POWER_UP,
    GATE,
}

@export_group("Identity")
## How this clip is driven by the animation engine.
@export var role: Role = Role.ACTIVE

@export_group("Model")
## GLB scene for this clip (one file per animation).
@export var model_path: String = ""
## Animation to play inside the GLB; empty plays the player's first animation.
@export var clip_name: String = ""
## Damaged-variant GLB shown in place of this clip at low health (ACTIVE only).
@export var damaged_model_path: String = ""

@export_group("Playback")
## Playback rate multiplier on the clip's AnimationPlayer.
@export var speed_scale: float = 1.0
## Whether the clip loops (ACTIVE) or plays once (one-shots).
@export var loop: bool = true
## Local-space placement relative to the entity origin.
@export var offset: Vector3 = Vector3.ZERO
## Whether the owning structure must be online for this clip to run.
@export var requires_power: bool = true
