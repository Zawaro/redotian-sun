extends Node

# Terrain-matched highlight patch tests (#386): pick_diagonal, the
# catalog->world corner reordering, and the patch ArrayMesh geometry.
# Pure — no scene or autoloads required.

const H: float = 0.815  # TerrainSystem.HEIGHT_STEP, inlined for pure tests


func test_pick_diagonal_coplanar_cases() -> void:
    (
        TestHelper
        . assert_eq(
            PlacementGridOverlay.pick_diagonal([0.0, 0.0, 0.0, 0.0]),
            -1,
            "all corners equal -> planar",
        )
    )
    (
        TestHelper
        . assert_eq(
            PlacementGridOverlay.pick_diagonal([0.0, 0.0, 1.0, 1.0]),
            -1,
            "1-step ramp on adjacent pair -> planar",
        )
    )
    (
        TestHelper
        . assert_eq(
            PlacementGridOverlay.pick_diagonal([0.0, 1.0, 0.0, 1.0]),
            -1,
            "east 1-step ramp (NE,SE high) -> planar",
        )
    )
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([1.0, 0.0, 1.0, 0.0]), -1, "west 1-step ramp -> planar"
    )
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([0.0, 1.0, 1.0, 0.0]),
        1,
        "NE-SW raised pair is a saddle, not a ramp"
    )
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([0.0, 0.0, 1.0, 0.0]) == -1,
        false,
        "single raised corner is NOT coplanar"
    )
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([0.0, 0.0, 2.0, 2.0]),
        -1,
        "2-step ramp, equal low pair -> planar"
    )


func test_pick_diagonal_single_high() -> void:
    # Unique max at NW/NE/SW/SE -> the diagonal NOT through it:
    # NW(0)/SE(3) live on {NW,SE}; NE(1)/SW(2) live on {NE,SW}.
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([0.0, 0.0, 0.0, H]), 1, "unique SE-high -> {NE,SW}"
    )
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([0.0, H, 0.0, 0.0]), 0, "unique NE-high -> {NW,SE}"
    )
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([0.0, 0.0, H, 0.0]), 0, "unique SW-high -> {NW,SE}"
    )
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([H, 0.0, 0.0, 0.0]), 1, "unique NW-high -> {NE,SW}"
    )
    # 2-step steep (slope13 shape): h0+h3 == h1+h2, so it is a planar 2-step
    # ramp, not a tent — any diagonal, -1 by convention.
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([0.0, H, H, 2.0 * H]),
        -1,
        "2-step ramp (unique max) is coplanar"
    )


func test_pick_diagonal_single_low() -> void:
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([0.0, H, H, H]),
        1,
        "unique NW-low (inverted tent) -> {NE,SW}"
    )
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([H, 0.0, H, H]), 0, "unique NE-low -> {NW,SE}"
    )
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([H, H, 0.0, H]), 0, "unique SW-low -> {NW,SE}"
    )
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([H, H, H, 0.0]), 1, "unique SE-low -> {NE,SW}"
    )


func test_pick_diagonal_saddles() -> void:
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([H, 0.0, 0.0, H]),
        0,
        "NW-SE raised pair -> split along {NW,SE}"
    )
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([0.0, H, H, 0.0]),
        1,
        "NE-SW raised pair -> split along {NE,SW}"
    )


func test_pick_diagonal_adjacent_high_nonplanar_fallback() -> void:
    # Two adjacent highs with a non-equal low pair (no current content uses
    # this): the fixed fallback diagonal, so behavior is deterministic.
    TestHelper.assert_eq(
        PlacementGridOverlay.pick_diagonal([0.0, H, 2.0 * H, 2.0 * H]),
        0,
        "adjacent-high non-planar -> fixed {NW,SE}"
    )


func test_catalog_corners_reorder_swaps_third_and_fourth() -> void:
    var world: Array = PlacementGridOverlay.catalog_corners_to_world([0, 1, 2, 1])
    TestHelper.assert_eq(world, [0, 1, 1, 2], "catalog [NW,NE,SE,SW] -> world [NW,NE,SW,SE]")
    var world2: Array = PlacementGridOverlay.catalog_corners_to_world([1, 0, 1, 0])
    TestHelper.assert_eq(world2, [1, 0, 0, 1], "saddle2 catalog -> world")


func test_octagon_mesh_matches_shared_outline() -> void:
    # The flat octagon and the terrain-matched patches must share the exact
    # same XZ outline (single source of truth) — corner size and inset line up
    # between flat and slope cells (#386 smoke test).
    var overlay := PlacementGridOverlay.new()
    var mesh := overlay._build_cell_mesh()
    var arrays := mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    TestHelper.assert_eq(vertices.size(), 24, "8-gon triangle fan = 24 vertices")
    var outline := PlacementGridOverlay._octagon_local_xz()
    for i in 8:
        var ring := vertices[i * 3]
        (
            TestHelper
            . assert_true(
                is_equal_approx(ring.x, outline[i].x) and is_equal_approx(ring.z, outline[i].y),
                "octagon ring vertex %d matches the shared outline" % i,
            )
        )
    overlay.free()


func test_patch_drapes_on_crease_split_planes() -> void:
    # Known example: unique SE-high tent [NW,NE,SW,SE] = [0,0,0,H]. The crease
    # is the {NE,SW} diagonal (x + z = 0). NE and SW are both zero and lie on
    # that line, so on the SE triangle the height is H * (x + z) / 2; the NW
    # triangle is flat at zero. This pins the patch to the rendered tile's two
    # planes, not the bilinear sampler that sank it through the fold (#386).
    var corners: Array = [0.0, 0.0, 0.0, H]
    var crease := PlacementGridOverlay.pick_diagonal(corners)
    TestHelper.assert_eq(crease, 1, "unique SE-high -> {NE,SW} crease")
    var mesh := PlacementGridOverlay._build_patch_mesh(
        Vector3.ZERO, corners, crease, PlacementGridOverlay.WHITE_COLOR
    )
    var arrays := mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    TestHelper.assert_eq(vertices.size(), 12, "two 6-vertex halves = 12 vertices")
    for v in vertices:
        var expected: float = H * maxf(0.0, (v.x + v.z) * 0.5) + PlacementGridOverlay.PLANE_Y_OFFSET
        (
            TestHelper
            . assert_true(
                absf(v.y - expected) < 1e-4,
                (
                    "vertex (%.3f, %.3f) follows the tile plane (got %.4f want %.4f)"
                    % [v.x, v.z, v.y, expected]
                ),
            )
        )


func test_patch_silhouette_is_the_shared_octagon() -> void:
    # The crease split adds two interior points but never moves the outer ring,
    # so slope cells keep the flat octagon's exact silhouette (#386).
    var corners: Array = [0.0, 0.0, 0.0, H]
    var mesh := PlacementGridOverlay._build_patch_mesh(
        Vector3.ZERO, corners, 1, PlacementGridOverlay.WHITE_COLOR
    )
    var arrays := mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    for ring in PlacementGridOverlay._octagon_local_xz():
        var found := false
        for v in vertices:
            if absf(v.x - ring.x) < 1e-4 and absf(v.z - ring.y) < 1e-4:
                found = true
                break
        TestHelper.assert_true(
            found, "octagon ring vertex (%f, %f) is in the patch" % [ring.x, ring.y]
        )


func test_patch_mesh_colors_and_indices() -> void:
    var corners: Array = [0.0, 0.0, 0.0, H]
    var mesh := PlacementGridOverlay._build_patch_mesh(
        Vector3.ZERO, corners, 1, PlacementGridOverlay.GREEN_COLOR
    )
    var arrays := mesh.surface_get_arrays(0)
    var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
    TestHelper.assert_eq(colors.size(), 12, "per-vertex color present")
    var expected_color := PlacementGridOverlay.GREEN_COLOR
    for c in colors:
        # PackedColorArray quantizes alpha in storage (0.3 -> 0.298); the
        # visible difference is below the 0.01 tolerance used here.
        (
            TestHelper
            . assert_true(
                (
                    is_equal_approx(c.r, expected_color.r)
                    and is_equal_approx(c.g, expected_color.g)
                    and is_equal_approx(c.b, expected_color.b)
                    and absf(c.a - expected_color.a) < 0.01
                ),
                "state color rides vertex color",
            )
        )
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    var expected_indices := PackedInt32Array(
        [0, 1, 2, 0, 2, 3, 0, 3, 4, 0, 4, 5, 6, 7, 8, 6, 8, 9, 6, 9, 10, 6, 10, 11]
    )
    TestHelper.assert_eq(indices, expected_indices, "two 6-gon fans, 8 triangles")
    for idx in indices:
        TestHelper.assert_true(idx >= 0 and idx < 12, "index within vertex range")
