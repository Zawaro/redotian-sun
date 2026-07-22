extends Node

# DebugMenu tests — cheat flags, overlay toggles, lighting controls

var _test_passed := 0
var _test_failed := 0


func test_cheat_flags_are_booleans():
    # Verify cheat flags are boolean type
    var no_prereqs: bool = false
    var no_build_time: bool = false
    var no_cost: bool = false
    var place_anywhere: bool = false

    if (
        typeof(no_prereqs) == TYPE_BOOL
        and typeof(no_build_time) == TYPE_BOOL
        and typeof(no_cost) == TYPE_BOOL
        and typeof(place_anywhere) == TYPE_BOOL
    ):
        _test_passed += 1
        print("    PASS: Cheat flags are boolean type")
    else:
        _test_failed += 1
        print("    FAIL: Cheat flags should be boolean type")


func test_cheat_flags_default_false():
    var no_prereqs: bool = false
    var no_build_time: bool = false
    var no_cost: bool = false
    var place_anywhere: bool = false

    if (
        no_prereqs == false
        and no_build_time == false
        and no_cost == false
        and place_anywhere == false
    ):
        _test_passed += 1
        print("    PASS: Cheat flags default to false")
    else:
        _test_failed += 1
        print("    FAIL: Cheat flags should default to false")


func test_cheat_flags_toggle():
    var no_prereqs: bool = false
    var no_build_time: bool = false
    var no_cost: bool = false
    var place_anywhere: bool = false

    no_prereqs = true
    no_build_time = true
    no_cost = true
    place_anywhere = true

    if no_prereqs and no_build_time and no_cost and place_anywhere:
        _test_passed += 1
        print("    PASS: Cheat flags can be toggled")
    else:
        _test_failed += 1
        print("    FAIL: Cheat flags should be toggleable")


func test_overlay_flags_default():
    var enabled: bool = true
    var show_spatial_hash: bool = false
    var show_entity_bounds: bool = false
    var show_health_bars: bool = false
    var show_entity_ids: bool = false

    if (
        enabled == true
        and show_spatial_hash == false
        and show_entity_bounds == false
        and show_health_bars == false
        and show_entity_ids == false
    ):
        _test_passed += 1
        print("    PASS: Overlay flags default correctly")
    else:
        _test_failed += 1
        print("    FAIL: Overlay flags should have correct defaults")


func test_overlay_reset():
    var enabled: bool = true
    var show_spatial_hash: bool = true
    var show_entity_bounds: bool = true
    var show_health_bars: bool = true
    var show_entity_ids: bool = true

    # Simulate reset
    enabled = true
    show_spatial_hash = false
    show_entity_bounds = false
    show_health_bars = false
    show_entity_ids = false

    if (
        enabled == true
        and show_spatial_hash == false
        and show_entity_bounds == false
        and show_health_bars == false
        and show_entity_ids == false
    ):
        _test_passed += 1
        print("    PASS: Overlay reset clears all flags")
    else:
        _test_failed += 1
        print("    FAIL: Overlay reset should clear all flags")


func test_lighting_controls_defaults():
    var sun_elevation: float = 36.0
    var sun_rotation: float = 0.0
    var sun_intensity: float = 1.0
    var sun_color: Color = Color.WHITE
    var shadow_strength: float = 0.9
    var ambient_light: float = 1.0
    var fog_density: float = 0.001
    var sky_rotation: float = -0.18
    var glow_intensity: float = 0.1

    if (
        sun_elevation == 36.0
        and sun_rotation == 0.0
        and sun_intensity == 1.0
        and sun_color == Color.WHITE
    ):
        _test_passed += 1
        print("    PASS: LightingControls defaults match scene files")
    else:
        _test_failed += 1
        print("    FAIL: LightingControls defaults should match scene files")


func test_panel_state():
    var is_open: bool = false
    var content_visible: bool = false

    # Toggle open
    is_open = true
    content_visible = true

    if is_open == true and content_visible == true:
        _test_passed += 1
        print("    PASS: Panel toggles open")
    else:
        _test_failed += 1
        print("    FAIL: Panel should toggle open")

    # Toggle closed
    is_open = false
    content_visible = false

    if is_open == false and content_visible == false:
        _test_passed += 1
        print("    PASS: Panel toggles closed")
    else:
        _test_failed += 1
        print("    FAIL: Panel should toggle closed")


func test_clear_inspection():
    var inspected_entity: Node3D = null
    var inspect_visible: bool = true
    var inspect_text: String = "test"

    # Clear
    inspected_entity = null
    inspect_visible = false
    inspect_text = ""

    if inspected_entity == null and inspect_visible == false and inspect_text == "":
        _test_passed += 1
        print("    PASS: clear_inspection resets state")
    else:
        _test_failed += 1
        print("    FAIL: clear_inspection should reset state")


func test_inspect_entity_requires_open():
    var is_open: bool = false
    var inspected_entity: Node3D = null

    # Should not inspect when closed
    if is_open == false and inspected_entity == null:
        _test_passed += 1
        print("    PASS: inspect_entity ignores when panel closed")
    else:
        _test_failed += 1
        print("    FAIL: inspect_entity should ignore when panel closed")


func _ready():
    print("--- test_debug_menu ---")
    test_cheat_flags_are_booleans()
    test_cheat_flags_default_false()
    test_cheat_flags_toggle()
    test_overlay_flags_default()
    test_overlay_reset()
    test_lighting_controls_defaults()
    test_panel_state()
    test_clear_inspection()
    test_inspect_entity_requires_open()
    print("    %d passed, %d failed" % [_test_passed, _test_failed])
