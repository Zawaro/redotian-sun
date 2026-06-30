extends SceneTree

# Minimal test runner — no framework, no class_name dependencies
# Usage: redot --headless -s test/run_tests.gd

var _total_passed := 0
var _total_failed := 0

func _init() -> void:
    print("=== Redotian Sun Test Suite ===\n")

    _run_test_file("res://test/unit/test_pathfinder.gd")

    print("\n=== Results: %d passed, %d failed ===" % [_total_passed, _total_failed])
    quit(1 if _total_failed > 0 else 0)


func _run_test_file(path: String) -> void:
    var script: GDScript = load(path)
    if not script:
        print("ERROR: Cannot load " + path)
        _total_failed += 1
        return

    var obj: Object = script.new()
    var suite_name: String = path.get_file().get_basename()
    print("--- " + suite_name + " ---")

    for m in script.get_script_method_list():
        var method_name: String = m["name"]
        if method_name.begins_with("test_"):
            var before_p: int = obj.get("_test_passed") if obj.has_method("get") else 0
            var before_f: int = obj.get("_test_failed") if obj.has_method("get") else 0
            obj.call(method_name)
            var after_p: int = obj.get("_test_passed") if obj.has_method("get") else 0
            var after_f: int = obj.get("_test_failed") if obj.has_method("get") else 0
            _total_passed += after_p - before_p
            _total_failed += after_f - before_f

    obj.free()
