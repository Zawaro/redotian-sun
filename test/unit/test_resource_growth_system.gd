extends Node

# ResourceGrowthSystem tests — GlobalRules defaults, spread neighbor count,
# and tree-spawn behavior around the tree's root cell.

const GRID := Vector2i(50, 50)
const TREE_CELL := Vector2i(40, 40)
const SPAWN_RADIUS := 1

var _ts: Node = null
var _sh: Node = null


func test_global_rules_growth_fields():
    var rules := GlobalRules.new()
    (
        TestHelper
        . assert_true(
            (
                rules.tree_growth_rate == 3.0
                and rules.tree_spawn_radius == 3
                and rules.growth_batch_trees == 10
                and rules.growth_batch_crystals == 500
                and rules.spread_amount == 0.5
                and rules.spread_max == 3
            ),
            "GlobalRules growth defaults correct: GlobalRules growth defaults mismatch",
        )
    )


func test_spread_neighbors_count():
    (
        TestHelper
        . assert_true(
            ResourceGrowthSystem.SPREAD_NEIGHBORS.size() == 8,
            (
                "spread neighbors has 8 directions: expected 8, got %d"
                % ResourceGrowthSystem.SPREAD_NEIGHBORS.size()
            ),
        )
    )


func test_tree_spawn_radius_circle():
    # Verify that radius=3 produces a circular area (not full square)
    var radius := 3
    var count := 0
    for dx in range(-radius, radius + 1):
        for dz in range(-radius, radius + 1):
            if dx * dx + dz * dz <= radius * radius:
                count += 1
    # Full square would be 7x7=49. Circle should be less.
    (
        TestHelper
        . assert_true(
            count < 49 and count > 0,
            (
                (
                    "tree_spawn_radius circle has %d cells (< 49 square): "
                    + "expected circular area, got %d cells"
                )
                % [count, count]
            ),
        )
    )


## Builds the fixture, runs one tree spawn tick around a tree rooted at
## TREE_CELL, and returns {spawned, parent, tree_root}. The caller must free
## parent/tree_root AFTER inspecting spawned — freeing earlier would crash the
## caller's loop on freed nodes and silently skip the per-node assertions.
func _spawn_around_tree_root(radius: int) -> Dictionary:
    _ts.init_grid(GRID.x, GRID.y)
    _sh._building_cells.clear()
    _sh._bib_cells.clear()
    _sh._resource_cells.clear()
    var rules := GlobalRules.get_current()
    if not rules:
        TestHelper.fail("GlobalRules unavailable in headless test env")
        return {}
    (
        TestHelper
        . assert_true(
            BoundsSystem.is_in_play_area(TREE_CELL),
            "fixture tree root cell %s must be inside the playable area" % TREE_CELL,
        )
    )

    var tree_root := Node3D.new()
    var tree_comp := ResourceTreeComponent.new()
    tree_comp.name = "ResourceTreeComponent"
    tree_root.add_child(tree_comp)
    var data := EntityData.new()
    data.spawned_entity_id = "TIBERIUM_RIPARIUS"
    data.radius_cells = radius
    data.resource_type_id = "tiberium_green"
    data.node_count = 4
    tree_comp.configure(data)
    tree_root.position = CellUtil.cell_to_world(TREE_CELL)
    var scene_root: Window = (Engine.get_main_loop() as SceneTree).root
    scene_root.add_child(tree_root)

    var parent := Node3D.new()
    scene_root.add_child(parent)

    # Run the spawn tick on the real ResourceGrowthSystem autoload — the same
    # instance production uses — with the resource parent pointed at a
    # dedicated node so spawned resources are easy to inspect.
    var growth: Node = scene_root.get_node("ResourceGrowthSystem")
    var saved_parent: Node = growth._resource_parent
    growth._resource_parent = parent
    growth._spawn_in_radius(tree_comp, TREE_CELL, radius, rules)
    growth._resource_parent = saved_parent

    var spawned: Array[Node] = []
    for child in parent.get_children():
        if child.get_node_or_null("ResourceComponent"):
            spawned.append(child)
    return {"spawned": spawned, "parent": parent, "tree_root": tree_root}


func test_tree_root_cell_stays_clear_on_spawn():
    var result := _spawn_around_tree_root(SPAWN_RADIUS)
    if result.is_empty():
        return
    var spawned: Array[Node] = result["spawned"]
    # Proves the spawn tick actually ran and produced resources in the ring.
    (
        TestHelper
        . assert_true(
            spawned.size() >= 1,
            "spawn tick produced at least one resource neighbor: got %d" % spawned.size(),
        )
    )
    for node in spawned:
        var cell := CellUtil.world_to_cell((node as Node3D).global_position)
        var offset := cell - TREE_CELL
        (
            TestHelper
            . assert_true(
                offset != Vector2i.ZERO,
                "tree root cell %s must stay clear, found a resource at %s" % [TREE_CELL, cell],
            )
        )
        (
            TestHelper
            . assert_true(
                offset.length_squared() <= SPAWN_RADIUS * SPAWN_RADIUS,
                "spawned resource at %s is outside radius %d of the tree" % [cell, SPAWN_RADIUS],
            )
        )
    (
        TestHelper
        . assert_true(
            not _sh.has_resource_cell(TREE_CELL),
            "tree root cell %s must not be registered as a resource cell" % TREE_CELL,
        )
    )
    (result["parent"] as Node).free()
    (result["tree_root"] as Node).free()
