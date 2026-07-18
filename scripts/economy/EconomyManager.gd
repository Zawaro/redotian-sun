extends Node

signal credits_changed(player_id: int, new_balance: int, reason: String)
signal insufficient_funds(player_id: int, cost: int, balance: int)


func get_balance(player_id: int) -> int:
    return _get_player_data(player_id).credits


func can_afford(player_id: int, cost: int) -> bool:
    return _get_player_data(player_id).credits >= cost


func deduct(player_id: int, cost: int, reason: String) -> bool:
    var data := _get_player_data(player_id)
    if data.credits < cost:
        insufficient_funds.emit(player_id, cost, data.credits)
        return false
    data.credits -= cost
    credits_changed.emit(player_id, data.credits, reason)
    return true


func add(player_id: int, amount: int, reason: String) -> void:
    var data := _get_player_data(player_id)
    data.credits += amount
    credits_changed.emit(player_id, data.credits, reason)


func get_storage_capacity(_player_id: int) -> int:
    return 2000


func _get_player_data(player_id: int) -> PlayerData:
    return PlayerManager.get_player_data(player_id)
