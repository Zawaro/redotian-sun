extends Node

# #386 design D6 acceptance gate: for every slope object variant, the
# terrain-matched highlight patch reproduces (a) the object's baked corner
# heights and (b) the placeholder GLB's tessellation (corner positions and
# internal diagonal). The GLB is the independent ground truth — it is
# hand-authored, so this test verifies the rule against it, not against the
# rule itself. `slope_saddle2` is the single documented deviation.

const GLB_PATH := "res://games/ts/assets/models/theater/placeholder/placeholder_terrain01.gltf"
const OBJ_DIR := "res://games/ts/terrain_objects/"
const DIR_ROTATIONS := {"n": 0.0, "e": 270.0, "s": 180.0, "w": 90.0}
const SADDLE2_BASE := "slope_saddle2"

var _mesh_by_node: Dictionary = {}


func _load_glb_meshes() -> void:
    var packed: PackedScene = load(GLB_PATH)
    if packed == null:
        push_error("cannot load " + GLB_PATH)
        return
    var scene := packed.instantiate()
    _collect_meshes(scene)
    scene.free()


func _collect_meshes(node: Node) -> void:
    if node is MeshInstance3D:
        var mi: MeshInstance3D = node
        if mi.mesh != null:
            _mesh_by_node[node.name.trim_suffix("_3D")] = mi.mesh
    for child in node.get_children():
        _collect_meshes(child)


## The 4 corner positions of a GLB node in its local 0..2 frame, as
## (x, z, y) with x/z snapped to the 0/2 grid. Returns {} when a corner is
## missing or off-grid.
static func _glb_corner_heights(mesh: Mesh) -> Dictionary:
    var corners := {}
    for surface in mesh.get_surface_count():
        var arrays := mesh.surface_get_arrays(surface)
        var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        for p in positions:
            var gx: int = 0 if absf(p.x) < 0.01 else (2 if absf(p.x - 2.0) < 0.01 else -1)
            var gz: int = 0 if absf(p.z) < 0.01 else (2 if absf(p.z - 2.0) < 0.01 else -1)
            if gx == -1 or gz == -1:
                continue
            var key := "%d,%d" % [gx, gz]
            var want: float = corners.get(key, p.y)
            if absf(p.y - want) > 0.02:
                return {}
            corners[key] = want
    if corners.size() != 4:
        return {}
    return corners


static func _glb_baked_diagonal(mesh: Mesh) -> int:
    var tris: Array = []
    for surface in mesh.get_surface_count():
        var arrays := mesh.surface_get_arrays(surface)
        var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
        for t in indices.size() / 3:
            var labels: Array = []
            var ok := true
            for j in 3:
                var i: int = indices[t * 3 + j]
                var p: Vector3 = positions[i]
                var gx: int = 0 if absf(p.x) < 0.01 else (2 if absf(p.x - 2.0) < 0.01 else -1)
                var gz: int = 0 if absf(p.z) < 0.01 else (2 if absf(p.z - 2.0) < 0.01 else -1)
                if gx == -1 or gz == -1:
                    ok = false
                    break
                labels.append(gx + gz * 10)
            if ok and labels[0] != labels[1] and labels[1] != labels[2] and labels[0] != labels[2]:
                tris.append(labels)
    for a in tris.size():
        for b in range(a + 1, tris.size()):
            var shared: Array = []
            for v in tris[a]:
                if tris[b].has(v):
                    shared.append(v)
            if shared.size() == 2:
                # (0,0)=NW, (2,0)=NE, (0,2)=SW, (2,2)=SE -> {0,3} NW-SE / {1,2} NE-SW
                return 0 if (shared == [0, 12] or shared == [12, 0]) else 1
    return -1


func test_every_slope_variant_patch_matches_glb() -> void:
    _load_glb_meshes()
    TestHelper.assert_true(_mesh_by_node.size() > 30, "GLB scene exposes many mesh nodes")
    var dir := DirAccess.open(OBJ_DIR)
    if dir == null:
        TestHelper.fail("cannot open " + OBJ_DIR)
        return
    var files: PackedStringArray = []
    dir.list_dir_begin()
    var name: String = dir.get_next()
    while name != "":
        if name.begins_with("slope") and name.ends_with(".tres"):
            files.append(name)
        name = dir.get_next()
    dir.list_dir_end()
    TestHelper.assert_eq(files.size(), 24, "24 directional slope object variants")

    var checked := 0
    var saddle2_deviations := 0
    for file in files:
        var obj: TerrainObject = load(OBJ_DIR + file)
        var cat: Array = obj.corners_at("0,0")
        if cat.size() != 4:
            TestHelper.fail("no corners in " + file)
            continue
        var world: Array = PlacementGridOverlay.catalog_corners_to_world(cat)
        # "<base>_<dir>.tres" -> the direction is the final 1-letter suffix
        # (bases themselves may contain underscores, e.g. "slope_saddle2").
        var stem: String = file.get_basename()
        var dir_id: String = stem.substr(stem.length() - 1)
        var base: String = stem.substr(0, stem.length() - 2)
        var submesh: String = ""
        if obj.art_data != null:
            submesh = obj.art_data.submesh_id
        if submesh.is_empty():
            submesh = base
        var mesh: Mesh = _mesh_by_node.get(submesh)
        if mesh == null:
            TestHelper.fail("no GLB node for submesh " + submesh + " (" + file + ")")
            continue
        var glb_corners := _glb_corner_heights(mesh)
        if glb_corners.is_empty():
            TestHelper.fail("GLB node %s has no clean corner set" % submesh)
            continue

        # Rotate the canonical mesh corners into the variant's placed frame
        # with the engine's own transform (Y-axis rotation about the cell
        # center; y is unaffected by Y rotation).
        var basis := Basis(Vector3.UP, deg_to_rad(DIR_ROTATIONS[dir_id]))
        var corner_xz := ["0,0", "2,0", "0,2", "2,2"]
        var heights_by_cell_corner := {}
        for key in glb_corners:
            var parts: PackedStringArray = key.split(",")
            var local := Vector3(float(parts[0]), 0.0, float(parts[1]))
            var rot: Vector3 = basis * (local - Vector3(1.0, 0.0, 1.0)) + Vector3(1.0, 0.0, 1.0)
            var rx: int = 0 if absf(rot.x) < 0.01 else (2 if absf(rot.x - 2.0) < 0.01 else -1)
            var rz: int = 0 if absf(rot.z) < 0.01 else (2 if absf(rot.z - 2.0) < 0.01 else -1)
            if rx == -1 or rz == -1:
                continue
            heights_by_cell_corner["%d,%d" % [rx, rz]] = glb_corners[key]

        for i in 4:
            var cc: String = corner_xz[i]
            var expected: float = world[i] * TerrainSystem.HEIGHT_STEP
            var got: float = heights_by_cell_corner.get(cc, -999.0)
            TestHelper.assert_true(
                absf(got - expected) <= 0.01 + 1e-4,
                "%s @ %s: GLB corner %f vs stored %f" % [file, cc, got, expected]
            )
        checked += 1

        # The baked diagonal lives in the canonical (unrotated) mesh frame, so
        # only the _n variant's own corner data is in a frame comparable to
        # it. Rotated variants are covered by the corner-height checks above
        # plus the rule's rotation covariance (unit tests).
        if dir_id != "n":
            continue
        var mesh_diag: int = _glb_baked_diagonal(mesh)
        var rule_diag: int = PlacementGridOverlay.pick_diagonal(world)
        if base == SADDLE2_BASE:
            if mesh_diag != -1 and mesh_diag != rule_diag and rule_diag != -1:
                saddle2_deviations += 1
            TestHelper.assert_true(rule_diag != -1, "%s: saddle is non-planar" % file)
        else:
            (
                TestHelper
                . assert_true(
                    mesh_diag == -1 or rule_diag == -1 or mesh_diag == rule_diag,
                    "%s: baked diagonal %d vs rule %d" % [file, mesh_diag, rule_diag],
                )
            )
    TestHelper.assert_eq(checked, 24, "all variants checked against the GLB")
    TestHelper.assert_true(
        saddle2_deviations > 0, "saddle2 deviates from its corner data (documented exception)"
    )
