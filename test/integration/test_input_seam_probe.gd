extends Node

# Headless input-seam probe (sidebar-ui-thinning task 1.2). The placement
# machines poll `Input.is_action_just_pressed` inside `_process`. Before any
# characterization test relies on driving them synchronously, this probe
# validates the seam: does `Input.action_press()` + an explicit `_process()`
# tick make `is_action_just_pressed` true in the `-s test/run_tests.gd`
# harness (no real frame advance)? If the first test fails, placement tests
# must drive `_unhandled_input`/public API directly instead of polled paths.

const ACTION: String = "select_entity"


class PollProbe:
    extends Node

    var seen_just_pressed: bool = false
    var seen_pressed: bool = false

    func _process(_delta: float) -> void:
        seen_just_pressed = Input.is_action_just_pressed(ACTION)
        seen_pressed = Input.is_action_pressed(ACTION)


func test_action_press_is_visible_to_explicit_process_tick() -> void:
    var probe: PollProbe = PollProbe.new()
    Input.action_release(ACTION)
    Input.action_press(ACTION)
    probe._process(0.016)
    Input.action_release(ACTION)
    TestHelper.assert_true(
        probe.seen_pressed, "action_press is visible to Input.is_action_pressed in a manual tick"
    )
    TestHelper.assert_true(
        probe.seen_just_pressed,
        "action_press registers as just_pressed in the same manual tick (synchronous seam holds)"
    )
    probe.free()


func test_action_press_latches_across_manual_ticks() -> void:
    # Probe finding (recorded as the contract): without a real frame advance,
    # Engine.get_process_frames() never moves, so just_pressed STAYS true on
    # later manual ticks. Consequence for characterization tests: multi-tick
    # skip-frame semantics of the polled machines cannot be simulated with
    # manual ticks — tests must drive _unhandled_input/public API directly
    # (which the event-driven placing session in this change makes the norm).
    var probe: PollProbe = PollProbe.new()
    Input.action_release(ACTION)
    Input.action_press(ACTION)
    probe._process(0.016)
    Input.action_release(ACTION)
    probe.seen_just_pressed = false
    probe._process(0.016)
    TestHelper.assert_true(
        probe.seen_just_pressed,
        "just_pressed stays latched on a later manual tick (no frame advance in synthetic mode)"
    )
    probe.free()
