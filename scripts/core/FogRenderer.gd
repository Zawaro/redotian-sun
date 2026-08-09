extends Node

## Renders the ShroudSystem fog grid as a world-aligned overlay plane and applies
## fog-driven visual culling to enemy buildings. Unit culling lives in
## UnitMeshRenderer. Inert when fog_of_war is false.

const FOG_SHADER: Shader = preload("res://shaders/maps/FogOfWarPlane.gdshader")
const FOG_SHADER_OPAQUE: Shader = preload("res://shaders/maps/FogShroudPlane.gdshader")

## Height above the terrain surface the fog plane drapes, to avoid z-fighting
## while keeping the reveal edge at ground height (no camera parallax).
const PLANE_EPSILON: float = 0.02

## World-units the overlay planes are lifted above the terrain so the OPAQUE
## shroud sheet sits closer to the tilted camera than any ground entity — the
## depth pass then occludes units/buildings/Tiberium in shrouded cells without
## relying on per-instance culling. The XZ components shift the sheet laterally
## to compensate the parallax the lift introduces (a tuning knob, not exact for
## every camera pitch).
const SHROUD_LIFT_XZ: float = 40.0
const SHROUD_LIFT_Y: float = 40.0 * TerrainSystem.HEIGHT_STEP

## Cells of flat shroud added past each edge of the map square, so the plane
## still covers the viewport when the camera is panned to a map edge (ortho
## camera shows ~40 world units past the visible diamond). The fog texture only
## covers the map square; the rim renders shroud via the shader's out-of-range
## UV check.
const RIM_MARGIN: int = 32

## Soft-edge band widths (in cells) for the shroud and fog boundaries, mirrored
## into the fog shader as `shroud_grow` / `shroud_falloff` / `fog_grow` /
## `fog_falloff`. `*_grow` extends the fully-opaque zone past the region
## boundary so the opaque sheet's crisp edge hides under it; `*_falloff` is the
## smoothstep width beyond that. Tunable at runtime through those uniforms
## without a rebake.
const SHROUD_GROW: float = 0.5
const SHROUD_FALLOFF: float = 1.5
const FOG_GROW: float = 0.25
const FOG_FALLOFF: float = 1.0

## Max ring distance baked into the edge mask; must exceed the largest falloff
## width so the smoothstep saturates before the sentinel is reached.
const MASK_MAX_RING: int = 4

var _plane: MeshInstance3D
var _plane_opaque: MeshInstance3D
var _material: ShaderMaterial
var _material_opaque: ShaderMaterial
var _last_states := PackedByteArray()
var _buildings: Dictionary = {}


func _ready() -> void:
    _material = ShaderMaterial.new()
    _material.shader = FOG_SHADER
    _plane = MeshInstance3D.new()
    _plane.name = "FogOfWarPlane"
    _plane.material_override = _material
    _plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _plane.extra_cull_margin = 100.0
    add_child(_plane)
    _material_opaque = ShaderMaterial.new()
    _material_opaque.shader = FOG_SHADER_OPAQUE
    _plane_opaque = MeshInstance3D.new()
    _plane_opaque.name = "FogShroudPlane"
    _plane_opaque.material_override = _material_opaque
    _plane_opaque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _plane_opaque.extra_cull_margin = 100.0
    add_child(_plane_opaque)
    _plane.visible = false
    _plane_opaque.visible = false
    ShroudSystem.state_changed.connect(_on_shroud_changed)
    TerrainSystem.grid_initialized.connect(_on_grid_initialized)
    get_tree().node_added.connect(_on_node_added)
    get_tree().node_removed.connect(_on_node_removed)
    if TerrainSystem.grid_cells != Vector2i.ZERO:
        _on_grid_initialized()


func _exit_tree() -> void:
    if ShroudSystem.state_changed.is_connected(_on_shroud_changed):
        ShroudSystem.state_changed.disconnect(_on_shroud_changed)
    if TerrainSystem.grid_initialized.is_connected(_on_grid_initialized):
        TerrainSystem.grid_initialized.disconnect(_on_grid_initialized)
    if get_tree() and get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.disconnect(_on_node_added)
    if get_tree() and get_tree().node_removed.is_connected(_on_node_removed):
        get_tree().node_removed.disconnect(_on_node_removed)


func _physics_process(_delta: float) -> void:
    if Engine.is_editor_hint():
        return
    if not ShroudSystem.is_shroud_enabled() and not ShroudSystem.is_fog_enabled():
        return
    var scene := get_tree().current_scene
    if scene != null and scene.has_meta("is_map_editor"):
        return
    var local := PlayerManager.get_local_player_id()
    for entity in _buildings.keys():
        var node: Node3D = entity
        if not is_instance_valid(node):
            _buildings.erase(entity)
            continue
        var stats := node.get_node_or_null("StatsComponent") as StatsComponent
        if stats == null or stats.player_id < 0:
            continue
        if not PlayerManager.is_enemy(local, stats.player_id):
            continue
        var revealed := ShroudSystem.is_entity_revealed_to_local(node)
        if node.visible != revealed:
            node.visible = revealed


func _on_shroud_changed() -> void:
    if Engine.is_editor_hint():
        return
    # Re-sync the toggle uniforms every signal: `_layout_plane` only runs on grid
    # init, so a runtime toggle (DebugMenu -> refresh) would otherwise leave
    # `fog_enabled`/`shroud_enabled` stale and the shader never show fog.
    var shroud: bool = ShroudSystem.is_shroud_enabled()
    var fog: bool = ShroudSystem.is_fog_enabled()
    _material.set_shader_parameter("shroud_enabled", shroud)
    _material.set_shader_parameter("fog_enabled", fog)
    _material.set_shader_parameter("shroud_grow", SHROUD_GROW)
    _material.set_shader_parameter("shroud_falloff", SHROUD_FALLOFF)
    _material.set_shader_parameter("fog_grow", FOG_GROW)
    _material.set_shader_parameter("fog_falloff", FOG_FALLOFF)
    _material_opaque.set_shader_parameter("shroud_enabled", shroud)
    if not shroud and not fog:
        _set_plane_visible(false)
        _clear_textures()
        return
    _set_plane_visible(true)
    var states := ShroudSystem.get_effective_state(PlayerManager.get_local_player_id())
    if states.is_empty():
        return
    if states.size() == _last_states.size() and states == _last_states:
        return
    _last_states = states
    _rebuild_texture(states)


func _on_grid_initialized() -> void:
    _last_states = PackedByteArray()
    _layout_plane()
    if not ShroudSystem.is_shroud_enabled() and not ShroudSystem.is_fog_enabled():
        _set_plane_visible(false)
        _clear_textures()
        return
    _set_plane_visible(true)
    _rebuild_texture(ShroudSystem.get_effective_state(PlayerManager.get_local_player_id()))


## Re-applies the shroud/fog toggles (uniforms + plane visibility + texture)
## after the debug menu changes GlobalRules. No-op state compare ensures a
## rebuild when only a toggle changed without any cell-state change.
func refresh() -> void:
    _last_states = PackedByteArray()
    _on_shroud_changed()


func _layout_plane() -> void:
    var grid: Vector2i = TerrainSystem.grid_cells
    var extent := CellUtil.get_diamond_extent(grid)
    var origin := _grid_origin(grid)
    var size := Vector2(extent.x * CellUtil.CELL_SIZE, extent.y * CellUtil.CELL_SIZE)
    var mesh := _build_draped_mesh()
    _plane.mesh = mesh
    _plane_opaque.mesh = mesh
    # The sheets are lifted above entity height (SHROUD_LIFT_Y) so the opaque
    # shroud pass depth-occludes every entity in a shrouded cell — guaranteed
    # coverage without per-instance culling. The XZ offset (SHROUD_LIFT_XZ)
    # compensates the parallax the lift causes under the tilted camera; it is a
    # tuning knob. The shaders sample world-space XZ, so the pattern stays
    # column-pinned as long as grid_origin is offset by the same XZ amount.
    var lift := Vector3(SHROUD_LIFT_XZ, SHROUD_LIFT_Y, SHROUD_LIFT_XZ)
    _plane.position = lift
    _plane_opaque.position = lift
    # Redot's PlaneMesh defaults to FACE_Y (horizontal); no pitch rotation needed.
    origin += Vector2(SHROUD_LIFT_XZ, SHROUD_LIFT_XZ)
    _material.set_shader_parameter("grid_origin", origin)
    _material.set_shader_parameter("grid_size", size)
    _material.set_shader_parameter("shroud_enabled", ShroudSystem.is_shroud_enabled())
    _material.set_shader_parameter("fog_enabled", ShroudSystem.is_fog_enabled())
    _material.set_shader_parameter("shroud_grow", SHROUD_GROW)
    _material.set_shader_parameter("shroud_falloff", SHROUD_FALLOFF)
    _material.set_shader_parameter("fog_grow", FOG_GROW)
    _material.set_shader_parameter("fog_falloff", FOG_FALLOFF)
    # Transparent-pass sorting: above the CloudShadowPlane and unit ghosts, but
    # below the 2D SelectionOverlay CanvasLayer (layer 128). RENDER_PRIORITY_MAX
    # clamps at 127 in this engine.
    _material.render_priority = 127
    _material_opaque.set_shader_parameter("grid_origin", origin)
    _material_opaque.set_shader_parameter("grid_size", size)
    _material_opaque.set_shader_parameter("shroud_enabled", ShroudSystem.is_shroud_enabled())
    # UV size of one cell, for the opaque sheet's erosion neighbor taps.
    var texel := Vector2(1.0 / float(extent.x), 1.0 / float(extent.y))
    _material_opaque.set_shader_parameter("grid_texel", texel)


## Builds a grid mesh draping the terrain surface (+PLANE_EPSILON) so the shroud
## follows slopes and reveal edges sit at ground height (no parallax offset).
## Covers the whole map square plus a RIM_MARGIN of flat shroud on every side;
## `TerrainSystem.get_vertex` returns 0 for out-of-diamond keys, so off-map cells
## drape flat. The full sheet renders as shroud beyond the map square because the
## shader forces out-of-range UVs to the shroud state.
func _build_draped_mesh() -> ArrayMesh:
    var extent := CellUtil.get_diamond_extent(TerrainSystem.grid_cells)
    var center: float = float(TerrainSystem.grid_cells.x + TerrainSystem.grid_cells.y) * 0.5
    var cs := CellUtil.CELL_SIZE
    var vertices := PackedVector3Array()
    var indices := PackedInt32Array()
    var vertex_indices: Dictionary = {}
    for cz in range(-RIM_MARGIN, extent.y + RIM_MARGIN):
        for cx in range(-RIM_MARGIN, extent.x + RIM_MARGIN):
            var quad := PackedInt32Array()
            quad.resize(4)
            var corners := [
                Vector2i(cx, cz),
                Vector2i(cx + 1, cz),
                Vector2i(cx, cz + 1),
                Vector2i(cx + 1, cz + 1),
            ]
            for i in 4:
                var key: Vector2i = corners[i]
                var idx: int = vertex_indices.get(key, -1)
                if idx < 0:
                    idx = vertices.size()
                    var height: float = (
                        float(TerrainSystem.get_vertex(key.x, key.y)) * TerrainSystem.HEIGHT_STEP
                    )
                    var vertex := Vector3(
                        (float(key.x) - center) * cs,
                        height + PLANE_EPSILON,
                        (float(key.y) - center) * cs,
                    )
                    vertices.append(vertex)
                    vertex_indices[key] = idx
                quad[i] = idx
            indices.append(quad[0])
            indices.append(quad[1])
            indices.append(quad[3])
            indices.append(quad[0])
            indices.append(quad[3])
            indices.append(quad[2])
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh


func _grid_origin(grid: Vector2i) -> Vector2:
    var center: float = float(grid.x + grid.y) * 0.5
    var min_x := (0.5 - center) * CellUtil.CELL_SIZE - CellUtil.CELL_SIZE * 0.5
    var min_z := (0.5 - center) * CellUtil.CELL_SIZE - CellUtil.CELL_SIZE * 0.5
    return Vector2(min_x, min_z)


func _rebuild_texture(states: PackedByteArray) -> void:
    var extent := CellUtil.get_diamond_extent(TerrainSystem.grid_cells)
    if extent.x <= 0 or extent.y <= 0 or states.is_empty():
        return
    var img := Image.create_from_data(extent.x, extent.y, false, Image.FORMAT_L8, states)
    var grid_tex := ImageTexture.create_from_image(img)
    _material.set_shader_parameter("fog_grid", grid_tex)
    _material_opaque.set_shader_parameter("fog_grid", grid_tex)
    var mask_tex := ImageTexture.create_from_image(_bake_edge_mask(states, extent))
    _material.set_shader_parameter("edge_mask", mask_tex)


## Builds the RG8 soft-edge mask (R = shroud ring distance, G = fog ring
## distance) from the effective-state buffer. Covered cells store 0; each cell
## outward stores its 8-neighbor Chebyshev ring distance up to MASK_MAX_RING.
## Bilinear interpolation in the shader ramps the distance linearly between
## texel centers, so a covered footprint stays flat (alpha 1) to its exact edge
## and the band extends outward only. Runs on the state-change event — the same
## gate as `_rebuild_texture` — never per frame.
func _bake_edge_mask(states: PackedByteArray, extent: Vector2i) -> Image:
    var width := extent.x
    var height := extent.y
    var shroud_dist := _ring_distance(states, 0, width, height)
    var fog_dist := _ring_distance(states, 1, width, height)
    var data := PackedByteArray()
    data.resize(states.size() * 2)
    for i in states.size():
        data[i * 2] = shroud_dist[i]
        data[i * 2 + 1] = fog_dist[i]
    return Image.create_from_data(width, height, false, Image.FORMAT_RG8, data)


## Two-pass Chebyshev distance transform to the nearest texel whose effective
## state equals `target`, clamped to MASK_MAX_RING. Counts diagonal neighbors at
## the same cost as cardinal ones (8-neighbor, L-infinity), so the falloff band
## aligns equally to axes and diagonals — the 45-degree rotation of a Manhattan
## diamond. O(n) with 8 compares per texel — cheap enough to run on every state
## change.
func _ring_distance(
    states: PackedByteArray,
    target: int,
    width: int,
    height: int,
) -> PackedByteArray:
    var dist := PackedByteArray()
    dist.resize(states.size())
    for i in states.size():
        dist[i] = 0 if states[i] == target else MASK_MAX_RING
    for y in range(1, height):
        for x in range(1, width):
            var idx := y * width + x
            var best := dist[idx]
            if dist[idx - 1] + 1 < best:
                best = dist[idx - 1] + 1
            if dist[idx - width] + 1 < best:
                best = dist[idx - width] + 1
            if dist[idx - width - 1] + 1 < best:
                best = dist[idx - width - 1] + 1
            if x < width - 1 and dist[idx - width + 1] + 1 < best:
                best = dist[idx - width + 1] + 1
            dist[idx] = best
    for y in range(height - 2, -1, -1):
        for x in range(width - 2, -1, -1):
            var idx := y * width + x
            var best := dist[idx]
            if dist[idx + 1] + 1 < best:
                best = dist[idx + 1] + 1
            if dist[idx + width] + 1 < best:
                best = dist[idx + width] + 1
            if dist[idx + width + 1] + 1 < best:
                best = dist[idx + width + 1] + 1
            if x > 0 and dist[idx + width - 1] + 1 < best:
                best = dist[idx + width - 1] + 1
            dist[idx] = best
    return dist


func _clear_textures() -> void:
    _material.set_shader_parameter("fog_grid", null)
    _material.set_shader_parameter("edge_mask", null)
    _material_opaque.set_shader_parameter("fog_grid", null)


func _set_plane_visible(visible: bool) -> void:
    # The fog plane carries the soft shroud band as well as the fog dim, so it
    # renders when either toggle is on (default state is shroud on / fog off).
    var overlay_visible: bool = (
        visible and (ShroudSystem.is_shroud_enabled() or ShroudSystem.is_fog_enabled())
    )
    if is_instance_valid(_plane) and _plane.visible != overlay_visible:
        _plane.visible = overlay_visible
    var opaque_visible: bool = visible and ShroudSystem.is_shroud_enabled()
    if is_instance_valid(_plane_opaque) and _plane_opaque.visible != opaque_visible:
        _plane_opaque.visible = opaque_visible


func _on_node_added(node: Node) -> void:
    if not (node is Node3D):
        return
    var n3d := node as Node3D
    if not n3d.is_in_group("entities"):
        return
    var stats := n3d.get_node_or_null("StatsComponent") as StatsComponent
    if stats == null:
        return
    if stats.entity_type != EntityData.EntityType.BUILDING:
        return
    _buildings[n3d] = true


func _on_node_removed(node: Node) -> void:
    _buildings.erase(node)
