class_name CursorState

enum Type {
    DEFAULT,
    SELECT,
    MOVE,
    MOVE_BLOCKED,
    ATTACK,
    ATTACK_OUT_OF_RANGE,
    HARVEST,
    ENTER,
    GUARD,
    SELL,
    REPAIR,
    SELL_BLOCKED,
    REPAIR_BLOCKED,
    GENERIC_BLOCKED,
    SCROLL_T,
    SCROLL_TR,
    SCROLL_R,
    SCROLL_BR,
    SCROLL_B,
    SCROLL_BL,
    SCROLL_L,
    SCROLL_TL,
    SCROLL_T_BLOCKED,
    SCROLL_TR_BLOCKED,
    SCROLL_R_BLOCKED,
    SCROLL_BR_BLOCKED,
    SCROLL_B_BLOCKED,
    SCROLL_BL_BLOCKED,
    SCROLL_L_BLOCKED,
    SCROLL_TL_BLOCKED,
    JOYSTICK_CENTER,
    JOYSTICK_T,
    JOYSTICK_TR,
    JOYSTICK_R,
    JOYSTICK_BR,
    JOYSTICK_B,
    JOYSTICK_BL,
    JOYSTICK_L,
    JOYSTICK_TL,
    JOYSTICK_T_BLOCKED,
    JOYSTICK_TR_BLOCKED,
    JOYSTICK_R_BLOCKED,
    JOYSTICK_BR_BLOCKED,
    JOYSTICK_B_BLOCKED,
    JOYSTICK_BL_BLOCKED,
    JOYSTICK_L_BLOCKED,
    JOYSTICK_TL_BLOCKED,
}

const CURSOR_PRIORITY: Dictionary = {
    Type.ATTACK: 30,
    Type.JOYSTICK_CENTER: 25,
    Type.JOYSTICK_T: 25,
    Type.JOYSTICK_TR: 25,
    Type.JOYSTICK_R: 25,
    Type.JOYSTICK_BR: 25,
    Type.JOYSTICK_B: 25,
    Type.JOYSTICK_BL: 25,
    Type.JOYSTICK_L: 25,
    Type.JOYSTICK_TL: 25,
    Type.HARVEST: 20,
    Type.ENTER: 15,
    Type.SELL: 20,
    Type.REPAIR: 20,
    Type.SELL_BLOCKED: 20,
    Type.REPAIR_BLOCKED: 20,
    Type.MOVE: 5,
    Type.DEFAULT: 0,
}

static var _texture_cache: Dictionary = {}
static var _loaded: bool = false

static var _TYPE_TO_PATH: Dictionary = {
    Type.DEFAULT: "",
    Type.SELECT: "res://assets/cursors/placeholders/scan.svg",
    Type.MOVE: "res://assets/cursors/placeholders/locate.svg",
    Type.MOVE_BLOCKED: "res://assets/cursors/placeholders/locate-off.svg",
    Type.ATTACK: "res://assets/cursors/placeholders/crosshair.svg",
    Type.ATTACK_OUT_OF_RANGE: "res://assets/cursors/placeholders/circle-off.svg",
    Type.HARVEST: "res://assets/cursors/placeholders/crosshair.svg",
    Type.ENTER: "res://assets/cursors/placeholders/chevrons-down.svg",
    Type.GUARD: "res://assets/cursors/placeholders/shield.svg",
    Type.SELL: "res://assets/cursors/placeholders/dollar-sign.svg",
    Type.REPAIR: "res://assets/cursors/placeholders/wrench.svg",
    Type.SELL_BLOCKED: "res://assets/cursors/placeholders/circle-off.svg",
    Type.REPAIR_BLOCKED: "res://assets/cursors/placeholders/wrench-off.svg",
    Type.GENERIC_BLOCKED: "res://assets/cursors/placeholders/circle-off.svg",
    Type.SCROLL_T: "res://assets/cursors/placeholders/arrow-up.svg",
    Type.SCROLL_TR: "res://assets/cursors/placeholders/arrow-up-right.svg",
    Type.SCROLL_R: "res://assets/cursors/placeholders/arrow-right.svg",
    Type.SCROLL_BR: "res://assets/cursors/placeholders/arrow-down-right.svg",
    Type.SCROLL_B: "res://assets/cursors/placeholders/arrow-down.svg",
    Type.SCROLL_BL: "res://assets/cursors/placeholders/arrow-down-left.svg",
    Type.SCROLL_L: "res://assets/cursors/placeholders/arrow-left.svg",
    Type.SCROLL_TL: "res://assets/cursors/placeholders/arrow-up-left.svg",
    Type.SCROLL_T_BLOCKED: "res://assets/cursors/placeholders/arrow-up-to-line.svg",
    Type.SCROLL_TR_BLOCKED: "res://assets/cursors/placeholders/arrow-up-right.svg",
    Type.SCROLL_R_BLOCKED: "res://assets/cursors/placeholders/arrow-right-to-line.svg",
    Type.SCROLL_BR_BLOCKED: "res://assets/cursors/placeholders/arrow-down-right.svg",
    Type.SCROLL_B_BLOCKED: "res://assets/cursors/placeholders/arrow-down-to-line.svg",
    Type.SCROLL_BL_BLOCKED: "res://assets/cursors/placeholders/arrow-down-left.svg",
    Type.SCROLL_L_BLOCKED: "res://assets/cursors/placeholders/arrow-left-to-line.svg",
    Type.SCROLL_TL_BLOCKED: "res://assets/cursors/placeholders/arrow-up-left.svg",
    Type.JOYSTICK_CENTER: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_T: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_TR: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_R: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_BR: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_B: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_BL: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_L: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_TL: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_T_BLOCKED: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_TR_BLOCKED: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_R_BLOCKED: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_BR_BLOCKED: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_B_BLOCKED: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_BL_BLOCKED: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_L_BLOCKED: "res://assets/cursors/placeholders/move.svg",
    Type.JOYSTICK_TL_BLOCKED: "res://assets/cursors/placeholders/move.svg",
}


static func _ensure_loaded() -> void:
    if _loaded:
        return
    for cursor_type in _TYPE_TO_PATH:
        var path: String = _TYPE_TO_PATH[cursor_type]
        var tex := load(path) as Texture2D
        if tex:
            _texture_cache[cursor_type] = tex
        else:
            push_warning("[CursorState] Missing cursor texture: %s" % path)
    _loaded = true


static func get_texture(cursor: Type) -> Texture2D:
    _ensure_loaded()
    return _texture_cache.get(cursor, null)


static func get_hotspot(cursor: Type) -> Vector2:
    if cursor == Type.DEFAULT:
        return Vector2.ZERO
    return Vector2(16, 16)


static func get_priority(cursor: Type) -> int:
    return CURSOR_PRIORITY.get(cursor, 0)
