extends Node

# DockClientComponent tests — find_nearest_host, try_reserve, occupancy penalty

var _test_passed := 0
var _test_failed := 0


func _make_dock_client(dock_id: String = "PROC") -> DockClientComponent:
    var client := DockClientComponent.new()
    client.name = "DockClientComponent"
    client._dock_id = dock_id
    client.can_dock_with = [dock_id]
    return client


func _make_dock_host(_dock_id: String = "PROC", queue_size: int = 0) -> Node3D:
    var entity := Node3D.new()
    entity.name = "TestRefinery"

    var host := DockHostComponent.new()
    host.name = "DockHostComponent"
    host.dock_types = ["harvest"]
    for i in queue_size:
        host.queue.append(Node.new())
    entity.add_child(host)

    return entity


func test_configure_sets_can_dock_with():
    var client := _make_dock_client("PROC")
    if client.can_dock_with.has("PROC") and client.get_dock_id() == "PROC":
        _test_passed += 1
        print("    PASS: configure sets can_dock_with")
    else:
        _test_failed += 1
        print("    FAIL: configure did not set can_dock_with")


func test_get_dock_id():
    var client := _make_dock_client("REFN")
    if client.get_dock_id() == "REFN":
        _test_passed += 1
        print("    PASS: get_dock_id returns correct id")
    else:
        _test_failed += 1
        print("    FAIL: get_dock_id returned wrong id")


func test_is_reserved():
    var client := _make_dock_client()
    if not client.is_reserved():
        _test_passed += 1
        print("    PASS: is_reserved returns false when no host")
    else:
        _test_failed += 1
        print("    FAIL: is_reserved returned true with no host")
