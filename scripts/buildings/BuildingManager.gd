extends Node

signal build_mode_changed(is_active: bool)
signal building_placed(building: Node3D, entity_data: EntityData)

var is_build_mode: bool = false
var current_building_type: EntityData = null
var _buildings: Array[Dictionary] = []
var exiting_build_mode: bool = false

var building_types: Array[EntityData] = []

var _preview: Node3D = null
var _building_preview: Node3D = null
var _buildings_parent: Node3D = null
var _map_half_diag: int = 640
var _play_area_half_diag: int = 256


func _ready() -> void:
    _load_building_types()
    _find_buildings_parent()
    _find_bounds_system()
    _create_preview()


func _load_building_types() -> void:
    var all_buildings := EntityFactory.get_all_by_type(EntityData.EntityType.BUILDING)
    for data in all_buildings:
        if data.buildable:
            building_types.append(data)


func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        return

    if not is_build_mode:
        return

    _update_preview_position()

    if Input.is_action_just_pressed("select_entity"):
        _try_place_building()
    elif Input.is_action_just_pressed("deselect_entity"):
        exit_build_mode()
    elif Input.is_action_just_pressed("ui_cancel"):
        exit_build_mode()


func enter_build_mode(building_type: EntityData) -> void:
    if is_build_mode and current_building_type == building_type:
        exit_build_mode()
        return

    current_building_type = building_type
    is_build_mode = true
    _create_building_preview()
    _show_preview(true)
    build_mode_changed.emit(true)


func exit_build_mode() -> void:
    is_build_mode = false
    current_building_type = null
    _show_preview(false)
    # Free preview building so its collision shapes leave the physics space
    for child in _preview.get_children():
        child.queue_free()
    _building_preview = null
    build_mode_changed.emit(false)


func can_place(building_type: EntityData, origin_cell: Vector2i) -> bool:
    var result: bool = true

    for dx in building_type.foundation.x:
        for dz in building_type.foundation.y:
            var cell := origin_cell + Vector2i(dx, dz)

            if not _is_in_bounds(cell):
                result = false
                break

            if not _is_in_play_area(cell):
                result = false
                break

            var key := SpatialHash.instance._cell_key(cell)
            if SpatialHash.instance.get_building_cells().has(key):
                result = false
                break

            if SpatialHash.instance.is_cell_blocked(cell):
                result = false
                break

            if _has_resource_on_cell(cell):
                result = false
                break

            if SpatialHash.instance.is_bib_cell(cell):
                result = false
                break

            var cell_type := TerrainSystem.get_cell_type(cell)
            if cell_type != "" and cell_type != "clear":
                result = false
                break

        if not result:
            break

    if result:
        var min_h := INF
        var max_h := -INF
        for dx in building_type.foundation.x:
            for dz in building_type.foundation.y:
                var cell := origin_cell + Vector2i(dx, dz)
                var h := TerrainSystem.get_cell_max_height(cell)
                min_h = minf(min_h, h)
                max_h = maxf(max_h, h)

        if min_h != INF and (max_h - min_h) > TerrainSystem.HEIGHT_STEP:
            result = false

    return result


func place_building(building_type: EntityData, origin_cell: Vector2i) -> bool:
    if not can_place(building_type, origin_cell):
        return false

    var em := get_node("/root/EconomyManager") as EconomyManager
    if em and not em.deduct(0, building_type.cost, "build:%s" % building_type.id):
        push_warning("[BuildingManager] Insufficient funds for %s" % building_type.id)
        return false

    var building: Node3D = EntityFactory.create_entity(building_type.id)
    if not building:
        push_error("[BuildingManager] Failed to create building entity")
        return false

    var world_pos := _cell_origin_to_world(origin_cell, building_type.foundation)
    var max_height := _get_max_height(origin_cell, building_type.foundation)
    world_pos.y = max_height

    building.position = world_pos
    _get_buildings_parent().add_child(building)

    var cells: Array[Vector2i] = []
    for dx in building_type.foundation.x:
        for dz in building_type.foundation.y:
            var offset := Vector2i(dx, dz)
            if not building_type.bib_cells.has(offset):
                cells.append(origin_cell + offset)
    SpatialHash.instance.register_building_cells(cells)

    if not building_type.bib_cells.is_empty():
        var fc := building.get_node_or_null("FoundationComponent") as FoundationComponent
        if fc:
            var bib := fc.get_bib_cells(origin_cell)
            if not bib.is_empty():
                SpatialHash.instance.register_bib_cells(bib)

    (
        _buildings
        . append(
            {
                "node": building,
                "type": building_type,
                "origin": origin_cell,
                "cells": cells,
            }
        )
    )

    building_placed.emit(building, building_type)
    return true


func get_all_buildings() -> Array[Dictionary]:
    return _buildings


func _cell_origin_to_world(origin: Vector2i, footprint: Vector2i) -> Vector3:
    var center_x := (origin.x + footprint.x * 0.5) * Pathfinder.CELL_SIZE
    var center_z := (origin.y + footprint.y * 0.5) * Pathfinder.CELL_SIZE
    return Vector3(center_x, 0.0, center_z)


func _get_max_height(origin: Vector2i, footprint: Vector2i) -> float:
    var max_h := 0.0
    for dx in footprint.x:
        for dz in footprint.y:
            var cell := origin + Vector2i(dx, dz)
            var h := TerrainSystem.get_cell_max_height(cell)
            max_h = maxf(max_h, h)
    return max_h


func _is_cell_free(cell: Vector2i) -> bool:
    var key := SpatialHash.instance._cell_key(cell)
    if SpatialHash.instance.get_building_cells().has(key):
        return false
    if SpatialHash.instance.is_cell_blocked(cell):
        return false
    if SpatialHash.instance.is_bib_cell(cell):
        return false
    if _has_resource_on_cell(cell):
        return false
    var cell_type := TerrainSystem.get_cell_type(cell)
    if cell_type != "" and cell_type != "clear":
        return false
    return true


func _has_resource_on_cell(cell: Vector2i) -> bool:
    for entity in get_tree().get_nodes_in_group("resources"):
        if not is_instance_valid(entity):
            continue
        if not entity is Node3D:
            continue
        var ecell := Pathfinder.world_to_cell((entity as Node3D).global_position)
        if ecell == cell:
            return true
    return false


func _find_buildings_parent() -> void:
    var tree := get_tree()
    if not tree:
        return
    var root := tree.current_scene
    if not root:
        return
    _buildings_parent = root.get_node_or_null("Buildings")
    if not _buildings_parent:
        _buildings_parent = Node3D.new()
        _buildings_parent.name = "Buildings"
        root.add_child(_buildings_parent)
        _buildings_parent.owner = root


func _find_bounds_system() -> void:
    var tree := get_tree()
    if not tree:
        return
    var root := tree.current_scene
    if not root:
        return
    var bs := root.get_node_or_null("BoundsSystem")
    if bs and bs is BoundsSystem:
        _map_half_diag = int(bs.map_size.x * Pathfinder.SQRT2 / 2.0)
        _play_area_half_diag = int(bs.visible_bounds_size.x * Pathfinder.SQRT2 / 2.0)


func _is_in_bounds(cell: Vector2i) -> bool:
    var cx := absf(float(cell.x) + 0.5)
    var cz := absf(float(cell.y) + 0.5)
    return cx + cz <= float(_map_half_diag)


func _is_in_play_area(cell: Vector2i) -> bool:
    var cx := absf(float(cell.x) + 0.5)
    var cz := absf(float(cell.y) + 0.5)
    return cx + cz <= float(_play_area_half_diag)


func _get_buildings_parent() -> Node3D:
    if not _buildings_parent:
        _find_buildings_parent()
    return _buildings_parent


func _create_preview() -> void:
    _preview = Node3D.new()
    _preview.name = "PlacementPreview"
    _preview.visible = false
    add_child(_preview)


func _show_preview(show: bool) -> void:
    if _preview:
        _preview.visible = show


func _update_preview_position() -> void:
    if not _preview or not current_building_type:
        return

    var mouse_pos := get_viewport().get_mouse_position()
    var camera := _get_camera_3d()
    if not camera:
        return

    var from := camera.project_ray_origin(mouse_pos)
    var dir := camera.project_ray_normal(mouse_pos)

    var ground_plane := Plane(Vector3.UP, 0.0)
    var intersection = ground_plane.intersects_ray(from, dir)
    if intersection == null:
        _preview.visible = false
        return

    var hit_pos := intersection as Vector3
    for i in 4:
        var terrain_y := TerrainSystem.get_height_at_world_smooth(hit_pos)
        var adjusted := Plane(Vector3.UP, terrain_y)
        var new_hit = adjusted.intersects_ray(from, dir)
        if new_hit == null:
            break
        hit_pos = new_hit as Vector3

    var mouse_cell := Pathfinder.world_to_cell(hit_pos)
    var origin_cell := (
        mouse_cell
        - Vector2i(current_building_type.foundation.x >> 1, current_building_type.foundation.y >> 1)
    )

    var valid := can_place(current_building_type, origin_cell)
    _update_preview_mesh(valid, origin_cell)
    _preview.visible = true


func _update_preview_mesh(_valid: bool, origin_cell: Vector2i) -> void:
    if not _preview or not current_building_type:
        return

    for child in _preview.get_children():
        if child != _building_preview:
            child.queue_free()

    var green_mat := StandardMaterial3D.new()
    green_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    green_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    green_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    green_mat.albedo_color = Color(0, 1, 0, 0.75)

    var red_mat := StandardMaterial3D.new()
    red_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    red_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    red_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    red_mat.albedo_color = Color(1, 0, 0, 0.75)

    var any_out_of_bounds := false
    for dx in current_building_type.foundation.x:
        for dz in current_building_type.foundation.y:
            var cell := origin_cell + Vector2i(dx, dz)
            if not _is_in_bounds(cell):
                any_out_of_bounds = true
                break
        if any_out_of_bounds:
            break

    for dx in current_building_type.foundation.x:
        for dz in current_building_type.foundation.y:
            var cell := origin_cell + Vector2i(dx, dz)
            if not _is_in_bounds(cell):
                continue

            var mesh := _build_cell_mesh(cell)
            if not mesh:
                continue

            var mesh_instance := MeshInstance3D.new()
            mesh_instance.mesh = mesh
            if not _is_in_play_area(cell):
                mesh_instance.material_override = red_mat
            else:
                mesh_instance.material_override = green_mat if _is_cell_free(cell) else red_mat
            var cell_world := Pathfinder.cell_to_world(cell)
            mesh_instance.position = Vector3(cell_world.x, 0, cell_world.z)
            _preview.add_child(mesh_instance)

    _add_grid_and_indicators(origin_cell, current_building_type.foundation, red_mat)

    if _building_preview:
        if any_out_of_bounds:
            _building_preview.visible = false
        else:
            var world_pos := _cell_origin_to_world(origin_cell, current_building_type.foundation)
            var max_height := _get_max_height(origin_cell, current_building_type.foundation)
            world_pos.y = max_height
            _building_preview.position = world_pos
            _building_preview.visible = true


func _create_building_preview() -> void:
    var t0 := Time.get_ticks_msec()
    if _building_preview:
        _building_preview.queue_free()
        _building_preview = null
    var t1 := Time.get_ticks_msec()
    _building_preview = EntityFactory.create_entity(current_building_type.id)
    var t2 := Time.get_ticks_msec()
    if _building_preview:
        _building_preview.set_meta("_preview", true)
        _set_node_transparency(_building_preview, 0.33)
        var t3 := Time.get_ticks_msec()
        _preview.add_child(_building_preview)
        var t4 := Time.get_ticks_msec()
        var elapsed := t4 - t0
        print(
            (
                "[bench preview] free=%d create=%d trans=%d child=%d total=%d %s"
                % [
                    t1 - t0,
                    t2 - t1,
                    t3 - t2,
                    t4 - t3,
                    elapsed,
                    current_building_type.id,
                ]
            )
        )


func _build_cell_mesh(cell: Vector2i) -> ImmediateMesh:
    var heights := TerrainSystem.get_cell_corner_heights(cell)
    var cs := Pathfinder.CELL_SIZE
    var half := cs * 0.5

    var mesh := ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    mesh.surface_add_vertex(Vector3(-half, heights[0], -half))
    mesh.surface_add_vertex(Vector3(-half, heights[2], half))
    mesh.surface_add_vertex(Vector3(half, heights[1], -half))
    mesh.surface_add_vertex(Vector3(half, heights[1], -half))
    mesh.surface_add_vertex(Vector3(-half, heights[2], half))
    mesh.surface_add_vertex(Vector3(half, heights[3], half))
    mesh.surface_end()
    return mesh


func _add_grid_and_indicators(
    origin_cell: Vector2i,
    footprint: Vector2i,
    red_mat: StandardMaterial3D,
) -> void:
    var center := Vector2(
        origin_cell.x + footprint.x * 0.5,
        origin_cell.y + footprint.y * 0.5,
    )
    var radius := maxf(float(footprint.x), float(footprint.y)) * 0.5 + 3.0
    var margin := 4
    var grid_start := origin_cell - Vector2i(margin + 1, margin + 1)
    var grid_end := origin_cell + footprint + Vector2i(margin + 1, margin + 1)
    var thick := 0.05

    var grid_mat := StandardMaterial3D.new()
    grid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    grid_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    grid_mat.albedo_color = Color(1, 1, 1, 0.1)

    var grid_mesh := ImmediateMesh.new()
    grid_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

    for z in range(grid_start.y, grid_end.y + 1):
        for x in range(grid_start.x, grid_end.x + 1):
            var cell := Vector2i(x, z)
            if not _is_in_bounds(cell):
                continue
            var cell_center := Vector2(x + 0.5, z + 0.5)
            if cell_center.distance_to(center) > radius:
                continue

            var in_footprint := (
                x >= origin_cell.x
                and x < origin_cell.x + footprint.x
                and z >= origin_cell.y
                and z < origin_cell.y + footprint.y
            )

            var show_red := false
            if not in_footprint:
                if not _is_cell_free(cell):
                    show_red = true
                elif not _is_in_play_area(cell):
                    show_red = true

            if show_red:
                var indicator := _build_cell_mesh(cell)
                if indicator:
                    var inst := MeshInstance3D.new()
                    inst.mesh = indicator
                    inst.material_override = red_mat
                    var cw := Pathfinder.cell_to_world(cell)
                    inst.position = Vector3(cw.x, 0, cw.z)
                    _preview.add_child(inst)

            var h := TerrainSystem.get_cell_corner_heights(cell)
            var cs := Pathfinder.CELL_SIZE
            var bx := x * cs
            var bz := z * cs
            var ht := thick * 0.5

            var t0 := Vector3(bx, h[0], bz - ht)
            var t1 := Vector3(bx + cs, h[1], bz - ht)
            var t2 := Vector3(bx, h[0], bz + ht)
            var t3 := Vector3(bx + cs, h[1], bz + ht)
            _quad(grid_mesh, t0, t1, t2, t3)

            var r0 := Vector3(bx + cs - ht, h[1], bz)
            var r1 := Vector3(bx + cs + ht, h[1], bz)
            var r2 := Vector3(bx + cs - ht, h[3], bz + cs)
            var r3 := Vector3(bx + cs + ht, h[3], bz + cs)
            _quad(grid_mesh, r0, r1, r2, r3)

            var b0 := Vector3(bx, h[2], bz + cs - ht)
            var b1 := Vector3(bx + cs, h[3], bz + cs - ht)
            var b2 := Vector3(bx, h[2], bz + cs + ht)
            var b3 := Vector3(bx + cs, h[3], bz + cs + ht)
            _quad(grid_mesh, b0, b1, b2, b3)

            var l0 := Vector3(bx - ht, h[0], bz)
            var l1 := Vector3(bx + ht, h[0], bz)
            var l2 := Vector3(bx - ht, h[2], bz + cs)
            var l3 := Vector3(bx + ht, h[2], bz + cs)
            _quad(grid_mesh, l0, l1, l2, l3)

    grid_mesh.surface_end()

    var grid_inst := MeshInstance3D.new()
    grid_inst.mesh = grid_mesh
    grid_inst.material_override = grid_mat
    grid_inst.position.y = 0.001
    _preview.add_child(grid_inst)


func _quad(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    mesh.surface_add_vertex(a)
    mesh.surface_add_vertex(c)
    mesh.surface_add_vertex(b)
    mesh.surface_add_vertex(b)
    mesh.surface_add_vertex(c)
    mesh.surface_add_vertex(d)


func _set_node_transparency(node: Node, alpha: float) -> void:
    var mat := StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(0.5, 0.5, 0.5, alpha)
    _apply_transparency(node, mat)


func _apply_transparency(node: Node, mat: StandardMaterial3D) -> void:
    if node is MeshInstance3D:
        (node as MeshInstance3D).material_override = mat
    for child in node.get_children():
        _apply_transparency(child, mat)


func _try_place_building() -> void:
    if not current_building_type:
        return

    var mouse_pos := get_viewport().get_mouse_position()
    var camera := _get_camera_3d()
    if not camera:
        return

    var from := camera.project_ray_origin(mouse_pos)
    var dir := camera.project_ray_normal(mouse_pos)

    var ground_plane := Plane(Vector3.UP, 0.0)
    var intersection = ground_plane.intersects_ray(from, dir)
    if intersection == null:
        return

    var hit_pos := intersection as Vector3
    for i in 4:
        var terrain_y := TerrainSystem.get_height_at_world_smooth(hit_pos)
        var adjusted := Plane(Vector3.UP, terrain_y)
        var new_hit = adjusted.intersects_ray(from, dir)
        if new_hit == null:
            break
        hit_pos = new_hit as Vector3

    var mouse_cell := Pathfinder.world_to_cell(hit_pos)
    var origin_cell := (
        mouse_cell
        - Vector2i(current_building_type.foundation.x >> 1, current_building_type.foundation.y >> 1)
    )
    if not place_building(current_building_type, origin_cell):
        # TODO: play invalid placement SFX
        push_warning("[BuildingManager] Cannot place here")
        return
    exiting_build_mode = true
    exit_build_mode()


func _get_camera_3d() -> Camera3D:
    var tree := get_tree()
    if not tree:
        return null
    var root := tree.current_scene
    if not root:
        return null
    var camera_controller := root.get_node_or_null("Camera")
    if not camera_controller:
        return null
    return camera_controller.get_node_or_null("Camera3D") as Camera3D
