class_name OrderResult

const MOD_FORCE_ATTACK: String = "force_attack"
const MOD_FORCE_MOVE: String = "force_move"
const MOD_QUEUED: String = "queued"
## Surface level a ground move targets (0 = ground, N = bridge deck level). Set by
## the cursor pick and carried on the produced move order.
const MOD_TARGET_LEVEL: String = "target_level"

var cursor: CursorState.Type
var priority: int
var target: Node3D
var target_pos: Vector3
var queued: bool
var execute: Callable
## Surface level the order targets, resolved from the cursor pick (0 = ground).
var target_level: int = 0


func _init(
    p_cursor: CursorState.Type = CursorState.Type.DEFAULT,
    p_priority: int = 0,
    p_target: Node3D = null,
    p_target_pos: Vector3 = Vector3.ZERO,
    p_queued: bool = false,
    p_execute: Callable = Callable(),
) -> void:
    cursor = p_cursor
    priority = p_priority
    target = p_target
    target_pos = p_target_pos
    queued = p_queued
    execute = p_execute
