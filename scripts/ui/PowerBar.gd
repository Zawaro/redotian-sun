class_name PowerBar extends Control

## TS-style twin power bar for the sidebar's left edge: a black column
## backed by a green fill (power output) with a red fill (drain) drawn in
## front — on deficit the red bar rises above the green. Fills follow a
## milder-than-linear power curve and ease toward their targets so grid
## changes animate instead of jumping.

## Full-bar scale: output of 2000 fills the bar, everything below is
## relative. # ponytail: fixed TS-style scale; GlobalRules export if it ever varies.
const MAX_POWER := 2000
## Fill curve exponent: (value / MAX_POWER)^0.4 — a single plant (+100)
## reads ~30% of the bar instead of 5% linear, while big bases still spread
## across the top half.
const CURVE_EXPONENT := 0.4
## Exponential ease rate (per second) for the fill animation.
const ANIM_SPEED := 8.0
## Distance at which an animating fill snaps to its target — below this the
## lerp asymptote would otherwise stall redraws forever.
const SNAP_DISTANCE_SQ := 0.000001

const COLOR_BACKGROUND := Color(0.0, 0.0, 0.0, 0.75)
const COLOR_OUTPUT := Color(0.0, 0.75, 0.0)
const COLOR_DRAIN := Color(0.75, 0.0, 0.0)

## Fill fractions currently displayed — eased toward the live grid targets.
var _displayed := Vector2.ZERO


func _process(delta: float) -> void:
    var grid := get_node_or_null("/root/PowerGrid")
    if grid == null:
        return
    var pid := PlayerManager.get_local_player_id()
    var target := _ratios(grid.get_output(pid), grid.get_drain(pid))
    if _displayed.is_equal_approx(target):
        return
    _displayed = _advance(_displayed, target, delta)
    queue_redraw()


func _draw() -> void:
    var height := size.y
    var width := size.x
    draw_rect(Rect2(Vector2.ZERO, size), COLOR_BACKGROUND)
    draw_rect(
        Rect2(Vector2(0, height * (1.0 - _displayed.x)), Vector2(width, height * _displayed.x)),
        COLOR_OUTPUT
    )
    draw_rect(
        Rect2(Vector2(0, height * (1.0 - _displayed.y)), Vector2(width, height * _displayed.y)),
        COLOR_DRAIN
    )


## Bottom-up fill fractions for output and drain, clamped to the bar height.
static func _ratios(output: int, drain: int) -> Vector2:
    return Vector2(_curve(output), _curve(drain))


## Milder-than-linear fill curve; clamped before pow so negative/oversized
## values stay well-defined (pow of a negative base is NaN).
static func _curve(value: int) -> float:
    return pow(clampf(float(value) / float(MAX_POWER), 0.0, 1.0), CURVE_EXPONENT)


## Frame-rate independent exponential ease toward the target, snapping on
## arrival.
static func _advance(current: Vector2, target: Vector2, delta: float) -> Vector2:
    var eased := current.lerp(target, 1.0 - exp(-ANIM_SPEED * delta))
    return target if eased.distance_squared_to(target) < SNAP_DISTANCE_SQ else eased
