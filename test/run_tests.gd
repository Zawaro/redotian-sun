extends SceneTree

# Minimal test runner — no framework, no class_name dependencies
# Usage: redot --headless -s test/run_tests.gd

var _total_passed := 0
var _total_failed := 0


func _init() -> void:
    print("=== Redotian Sun Test Suite ===\n")

    # Wait for autoloads to be available
    var max_wait := 60
    var waited := 0
    while waited < max_wait:
        var tree_root: Node = get_root()
        if tree_root and tree_root.has_node("TerrainSystem"):
            break
        await create_timer(0.1).timeout
        waited += 1

    _discover_and_run_tests()

    print("\n=== Results: %d passed, %d failed ===" % [_total_passed, _total_failed])
    quit(1 if _total_failed > 0 else 0)


func _discover_and_run_tests() -> void:
    var dirs := ["res://test/unit/", "res://test/integration/"]
    for dir_path in dirs:
        var dir := DirAccess.open(dir_path)
        if not dir:
            continue
        dir.list_dir_begin()
        var file_name: String = dir.get_next()
        while file_name != "":
            if file_name.begins_with("test_") and file_name.ends_with(".gd"):
                _run_test_file(dir_path + file_name)
            file_name = dir.get_next()
        dir.list_dir_end()


func _run_test_file(path: String) -> void:
    var script: GDScript = load(path)
    if not script:
        print("ERROR: Cannot load " + path)
        _total_failed += 1
        return

    var obj: Object = script.new()
    var suite_name: String = path.get_file().get_basename()
    print("--- " + suite_name + " ---")

    _inject_autoloads(obj)

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


func _inject_autoloads(obj: Object) -> void:
    var tree_root: Node = get_root()
    if tree_root == null:
        return
    for child in tree_root.get_children():
        var child_name: String = child.name
        if child_name == "TerrainSystem":
            obj.set("_ts", child)
        elif child_name == "SpatialHashSingleton":
            obj.set("_sh", child)
        elif child_name == "SelectionManager":
            obj.set("_sm", child)
        elif child_name == "BuildingManager":
            obj.set("_bm", child)
        elif child_name == "EconomyManager":
            obj.set("_em", child)
        elif child_name == "PlayerManager":
            obj.set("_pm", child)
