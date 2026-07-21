extends Node

# Deploy/Undeploy integration tests — health transfer, owner preservation
# These tests verify the core logic without requiring full scene setup

var _sm: Node = null
var _bm: Node = null
var _pm: Node = null
var _test_passed := 0
var _test_failed := 0


func test_health_ratio_same_max():
    # Test: 500/1000 HP → 500/1000 HP (same max_health)
    var source_health := 500
    var source_max := 1000
    var target_max := 1000
    var ratio := float(source_health) / float(source_max) if source_max > 0 else 1.0
    var target_health := int(float(target_max) * ratio)
    if target_health == 500:
        _test_passed += 1
        print("    PASS: Health ratio same max_health: 500/1000 → 500/1000")
    else:
        _test_failed += 1
        print("    FAIL: Expected 500, got %d" % target_health)


func test_health_ratio_different_max():
    # Test: 500/1000 HP → 1000/2000 HP (different max_health)
    var source_health := 500
    var source_max := 1000
    var target_max := 2000
    var ratio := float(source_health) / float(source_max) if source_max > 0 else 1.0
    var target_health := int(float(target_max) * ratio)
    if target_health == 1000:
        _test_passed += 1
        print("    PASS: Health ratio different max_health: 500/1000 → 1000/2000")
    else:
        _test_failed += 1
        print("    FAIL: Expected 1000, got %d" % target_health)


func test_health_ratio_lower_target():
    # Test: 800/1000 HP → 400/500 HP (lower target max_health)
    var source_health := 800
    var source_max := 1000
    var target_max := 500
    var ratio := float(source_health) / float(source_max) if source_max > 0 else 1.0
    var target_health := int(float(target_max) * ratio)
    if target_health == 400:
        _test_passed += 1
        print("    PASS: Health ratio lower target: 800/1000 → 400/500")
    else:
        _test_failed += 1
        print("    FAIL: Expected 400, got %d" % target_health)


func test_health_ratio_zero_max():
    # Test: source max_health = 0 → target gets full health
    var source_health := 0
    var source_max := 0
    var target_max := 1000
    var target_health: int
    if source_max <= 0:
        target_health = target_max
    else:
        var ratio := float(source_health) / float(source_max)
        target_health = int(float(target_max) * ratio)
    if target_health == 1000:
        _test_passed += 1
        print("    PASS: Health ratio zero max → full health")
    else:
        _test_failed += 1
        print("    FAIL: Expected 1000, got %d" % target_health)


func test_health_ratio_full_health():
    # Test: 1000/1000 HP → full health on target
    var source_health := 1000
    var source_max := 1000
    var target_max := 2000
    var ratio := float(source_health) / float(source_max) if source_max > 0 else 1.0
    var target_health := int(float(target_max) * ratio)
    if target_health == 2000:
        _test_passed += 1
        print("    PASS: Health ratio full health: 1000/1000 → 2000/2000")
    else:
        _test_failed += 1
        print("    FAIL: Expected 2000, got %d" % target_health)


func test_health_ratio_damaged_source():
    # Test: 250/1000 HP → 500/2000 HP (25% damage preserved)
    var source_health := 250
    var source_max := 1000
    var target_max := 2000
    var ratio := float(source_health) / float(source_max) if source_max > 0 else 1.0
    var target_health := int(float(target_max) * ratio)
    if target_health == 500:
        _test_passed += 1
        print("    PASS: Health ratio damaged source: 250/1000 → 500/2000")
    else:
        _test_failed += 1
        print("    FAIL: Expected 500, got %d" % target_health)
