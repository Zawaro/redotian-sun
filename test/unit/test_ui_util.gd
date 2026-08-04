extends Node

# UIUtil unit tests — static UI overlap detection helpers


func test_is_inside_node_true():
    var parent := Node.new()
    parent.name = "TargetParent"
    var child := Node.new()
    child.name = "Child"
    parent.add_child(child)
    var result := UIUtil.is_inside_node(child, "TargetParent")
    parent.queue_free()
    TestHelper.assert_true(
        result, "is_inside_node finds ancestor: is_inside_node should find TargetParent"
    )


func test_is_inside_node_false():
    var parent := Node.new()
    parent.name = "SomeNode"
    var child := Node.new()
    child.name = "Child"
    parent.add_child(child)
    var result := UIUtil.is_inside_node(child, "NotHere")
    parent.queue_free()
    (
        TestHelper
        . assert_true(
            not result,
            (
                "is_inside_node returns false for missing ancestor: "
                + "is_inside_node should return false"
            ),
        )
    )


func test_is_inside_node_walks_chain():
    var root := Node.new()
    root.name = "Root"
    var mid := Node.new()
    mid.name = "Mid"
    var leaf := Node.new()
    leaf.name = "Leaf"
    root.add_child(mid)
    mid.add_child(leaf)
    var result := UIUtil.is_inside_node(leaf, "Root")
    root.queue_free()
    (
        TestHelper
        . assert_true(
            result,
            (
                "is_inside_node walks multi-level chain: "
                + "is_inside_node should find Root through chain"
            ),
        )
    )


func test_find_sidebar_returns_null_when_missing():
    var result := UIUtil.find_sidebar()
    (
        TestHelper
        . assert_true(
            result == null,
            "find_sidebar returns null when no sidebar exists: expected null, got %s" % result,
        )
    )
