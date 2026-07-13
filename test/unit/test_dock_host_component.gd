extends Node

# DockHostComponent tests — queue limits, wait timer, has_dock_type

var _test_passed := 0
var _test_failed := 0


func _make_dock_host(max_queue: int = 3, wait_ticks: int = 10) -> DockHostComponent:
    var host := DockHostComponent.new()
    host.name = "DockHostComponent"
    host.max_queue_length = max_queue
    host.dock_wait_ticks = wait_ticks
    host.dock_types = ["harvest"]
    return host


func test_request_dock_immediate():
    var host := _make_dock_host()
    var docker := Node.new()
    var result := host.request_dock(docker)
    if result and host.current_docker == docker:
        _test_passed += 1
        print("    PASS: request_dock succeeds when empty")
    else:
        _test_failed += 1
        print("    FAIL: request_dock failed when empty")


func test_request_dock_queue_full():
    var host := _make_dock_host(1)
    var docker1 := Node.new()
    var docker2 := Node.new()
    host.request_dock(docker1)
    var result := host.request_dock(docker2)
    if not result and host.queue.size() == 1:
        _test_passed += 1
        print("    PASS: request_dock rejects when queue full")
    else:
        _test_failed += 1
        print("    FAIL: request_dock did not reject when full")


func test_get_queue_size():
    var host := _make_dock_host()
    host.queue.append(Node.new())
    host.queue.append(Node.new())
    if host.get_queue_size() == 2:
        _test_passed += 1
        print("    PASS: get_queue_size returns correct count")
    else:
        _test_failed += 1
        print("    FAIL: get_queue_size returned wrong count")


func test_has_dock_type():
    var host := _make_dock_host()
    if host.has_dock_type("harvest") and not host.has_dock_type("repair"):
        _test_passed += 1
        print("    PASS: has_dock_type works correctly")
    else:
        _test_failed += 1
        print("    FAIL: has_dock_type mismatch")
