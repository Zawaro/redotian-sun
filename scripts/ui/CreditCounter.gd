class_name CreditCounter
extends Label

## Animated credit balance readout (sidebar-ui-thinning): on credits_changed
## for the local player, steps a displayed value toward the new balance — one
## tick sound per displayed step — instead of jumping straight to it. Forced
## initialization (scene ready, balance resync) shows the balance instantly
## and silently. Behavior spec: openspec/specs/credit-ui/spec.md.

## ponytail: knobs reproducing the classic counter feel, tune from playtesting.
const GAIN_STEP_INTERVAL: float = 0.0  ## seconds between steps counting up (0 = every frame)
const SPEND_STEP_INTERVAL: float = 0.05  ## seconds between steps counting down (slower, heavier)
const STEP_DIVISOR: int = 8  ## step size = remaining gap / divisor, clamped below
const MIN_STEP: int = 1  ## guarantees termination on odd balances
const MAX_STEP: int = 143  ## caps the per-step jump so small gaps still tick a few times
const SOUND_INCOME: String = "ECON_INCOME"
const SOUND_SPEND: String = "ECON_SPEND"

var _displayed_credits: int = 0
var _target_credits: int = 0
var _step_accumulator: float = 0.0


func _ready() -> void:
    var em := get_node("/root/EconomyManager")
    if em:
        em.credits_changed.connect(_on_credits_changed)
        _force_display_credits(em.get_balance(PlayerManager.get_local_player_id()))


func _process(delta: float) -> void:
    _step_counter(delta)


func _on_credits_changed(
    player_id: int, new_balance: int, _reason: String, _category: String
) -> void:
    if player_id != PlayerManager.get_local_player_id():
        return
    # Reset the cadence accumulator only for a fresh animation. An in-flight
    # animation keeps accumulating so per-frame target updates — gradual
    # production deduction fires credits_changed nearly every frame — cannot
    # starve the spend cadence and freeze the counter mid-drain.
    if _displayed_credits == _target_credits:
        _step_accumulator = 0.0
    _target_credits = new_balance


## Forced display (scene ready, balance resync): jump straight to the balance,
## no animation, no tick.
func _force_display_credits(balance: int) -> void:
    _displayed_credits = balance
    _target_credits = balance
    _step_accumulator = 0.0
    text = "$%d" % balance


## Advance the credit counter by `delta` seconds: accumulate time, apply one
## step per elapsed interval — gains step every frame, spends every
## SPEND_STEP_INTERVAL — playing one tick per applied step. Idle once the
## displayed value equals the target. Split out from _process so tests can
## drive it with synthetic deltas.
func _step_counter(delta: float) -> void:
    if _displayed_credits == _target_credits:
        return
    var interval := (
        GAIN_STEP_INTERVAL if _target_credits > _displayed_credits else SPEND_STEP_INTERVAL
    )
    # Clamp accumulated time to one interval: gain frames (interval 0) never
    # drain the accumulator, so un-clamped time would burst out as extra steps
    # on the first spend frame and collapse the count-down to a single jump.
    _step_accumulator = minf(_step_accumulator + delta, interval)
    while _step_accumulator >= interval and _displayed_credits != _target_credits:
        var gap := _target_credits - _displayed_credits
        var step := clampi(absi(gap) / STEP_DIVISOR, MIN_STEP, MAX_STEP)
        _displayed_credits += signi(gap) * step
        _step_accumulator -= interval
        AudioManager.play_sound(SOUND_INCOME if gap > 0 else SOUND_SPEND)
        if interval <= 0.0:
            break
    text = "$%d" % _displayed_credits
