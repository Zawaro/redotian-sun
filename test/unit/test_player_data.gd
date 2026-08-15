extends Node

# PlayerData unit tests — category storage wallet and free credits


func test_stored_tiberium_set_directly():
    var data := PlayerData.new()
    data.stored_by_category["tiberium"] = 1000
    (
        TestHelper
        . assert_true(
            int(data.stored_by_category.get("tiberium", 0)) == 1000,
            "stored_by_category holds the tiberium amount",
        )
    )


func test_free_credits_field():
    var data := PlayerData.new()
    data.free_credits = 1000
    (
        TestHelper
        . assert_true(
            data.free_credits == 1000,
            "free_credits holds starting/crate credits: got %d" % data.free_credits,
        )
    )


func test_stored_and_free_coexist():
    var data := PlayerData.new()
    data.stored_by_category["tiberium"] = 500
    data.stored_by_category["weed"] = 100
    data.free_credits = 1000
    (
        TestHelper
        . assert_true(
            int(data.stored_by_category["tiberium"]) == 500,
            "tiberium stored balance coexists",
        )
    )
    (
        TestHelper
        . assert_true(
            int(data.stored_by_category["weed"]) == 100,
            "weed stored balance coexists",
        )
    )
    (
        TestHelper
        . assert_true(
            data.free_credits == 1000,
            "free credits coexist with stored balances",
        )
    )


func test_defaults_zero():
    var data := PlayerData.new()
    (
        TestHelper
        . assert_true(
            data.stored_by_category.is_empty(),
            "fresh PlayerData has no stored balances",
        )
    )
    (
        TestHelper
        . assert_true(
            data.free_credits == 0,
            "fresh PlayerData has zero free credits: got %d" % data.free_credits,
        )
    )
