extends Node

# MoveLineRenderer tests — shared batched line rendering: N active lines collapse
# into one buffer (2 surfaces regardless of count), with a clean register /
# unregister / freed-source lifecycle.

const RENDERER_SCRIPT: GDScript = preload("res://scripts/core/MoveLineRenderer.gd")


class FakeSource:
    extends Node

    var _data: Dictionary = {}

    func _init(data: Dictionary) -> void:
        _data = data

    func get_line_render_data() -> Dictionary:
        return _data


func _make_renderer() -> Node:
    var renderer: Node = RENDERER_SCRIPT.new()
    (Engine.get_main_loop() as SceneTree).root.add_child(renderer)
    return renderer


func _data(alpha: float) -> Dictionary:
    return {
        "origin": Vector3(0, 0, 0),
        "target": Vector3(0, 0, 5),
        "alpha": alpha,
        "marker_half": 0.125,
        "marker_diamond": false,
    }


func test_many_lines_render_as_two_surfaces():
    var renderer := _make_renderer()
    for i in 60:
        renderer.register(FakeSource.new(_data(1.0)))
    renderer._process(0.0)
    var immesh: ImmediateMesh = renderer._line_mesh.mesh as ImmediateMesh
    var surfaces: int = immesh.get_surface_count() if immesh else -1
    renderer.free()
    (
        TestHelper
        . assert_eq(
            surfaces,
            2,
            "60 lines collapse into one LINES + one TRIANGLES surface (got %d)" % surfaces,
        )
    )


func test_unregister_removes_source():
    var renderer := _make_renderer()
    var src := FakeSource.new(_data(1.0))
    renderer.register(src)
    TestHelper.assert_eq(renderer._sources.size(), 1, "source registered")
    renderer.unregister(src)
    TestHelper.assert_eq(renderer._sources.size(), 0, "source unregistered")
    renderer.free()


func test_freed_source_dropped_on_process():
    var renderer := _make_renderer()
    var src := FakeSource.new(_data(1.0))
    renderer.register(src)
    src.free()
    renderer._process(0.0)
    TestHelper.assert_eq(renderer._sources.size(), 0, "freed source dropped in per-frame pass")
    renderer.free()
