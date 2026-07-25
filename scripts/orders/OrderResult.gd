class_name OrderResult

const MOD_FORCE_ATTACK: String = "force_attack"
const MOD_FORCE_MOVE: String = "force_move"
const MOD_QUEUED: String = "queued"

var cursor: CursorState.Type
var priority: int
var target: Node3D
var target_pos: Vector3
var queued: bool
var execute: Callable


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
