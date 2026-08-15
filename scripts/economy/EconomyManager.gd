extends Node

signal credits_changed(player_id: int, new_balance: int, reason: String, category: String)
signal insufficient_funds(player_id: int, cost: int, balance: int)

const DEFAULT_CATEGORY := "tiberium"
const TIBERIUM_CAPACITY := 2000


func get_balance(player_id: int, category: String = "") -> int:
    var data := _get_player_data(player_id)
    if category != "":
        return int(data.stored_by_category.get(category, 0))
    var total := data.free_credits
    for cat: String in data.stored_by_category:
        if _is_displayable(cat):
            total += int(data.stored_by_category[cat])
    return total


func can_afford(player_id: int, cost: int) -> bool:
    return get_balance(player_id) >= cost


func deduct(player_id: int, cost: int, reason: String, category: String = DEFAULT_CATEGORY) -> bool:
    # Cheat mode: no cost
    var debug_menu := get_tree().get_first_node_in_group("debug_menu")
    if debug_menu and debug_menu.no_cost:
        return true

    var data := _get_player_data(player_id)
    var total := get_balance(player_id)
    if total < cost:
        insufficient_funds.emit(player_id, cost, total)
        return false
    # Spend stored credits first; the deficit comes from free credits.
    var stored := int(data.stored_by_category.get(category, 0))
    var taken_from_stored := mini(cost, stored)
    data.stored_by_category[category] = stored - taken_from_stored
    data.free_credits -= cost - taken_from_stored
    credits_changed.emit(player_id, get_balance(player_id), reason, category)
    return true


func add(
    player_id: int,
    amount: int,
    reason: String,
    category: String = DEFAULT_CATEGORY,
    is_free: bool = false,
) -> void:
    var data := _get_player_data(player_id)
    if is_free:
        data.free_credits += amount
    else:
        data.stored_by_category[category] = int(data.stored_by_category.get(category, 0)) + amount
    credits_changed.emit(player_id, get_balance(player_id), reason, category)


func get_storage_capacity(_player_id: int, category: String = DEFAULT_CATEGORY) -> int:
    return TIBERIUM_CAPACITY if category == DEFAULT_CATEGORY else 0


func _is_displayable(category: String) -> bool:
    var rules := EntityFactory.get_global_rules()
    if not rules:
        return true
    var rt: ResourceType = rules.get_resource_type(category)
    if not rt:
        for id: String in rules.resource_types:
            var candidate: ResourceType = rules.resource_types[id]
            if candidate.category == category:
                rt = candidate
                break
    return rt.display_in_hud if rt else true


func _get_player_data(player_id: int) -> PlayerData:
    return PlayerManager.get_player_data(player_id)
