extends Node

## Plays a UI-level credit SFX when the economy changes: income sounds for
## credit gains (harvest dump, sell refunds), spend sounds for build/production
## deductions. Listens to EconomyManager.credits_changed so EconomyManager stays
## audio-agnostic ("signal up, call down"). Mounted as a node under Gameplay in
## MainScene.tscn.

const SOUND_INCOME: String = "ECON_INCOME"
const SOUND_SPEND: String = "ECON_SPEND"

## Explicit allowlist of reason prefixes per direction. Anything unlisted
## (e.g. "debug_menu" cheat credits) plays nothing until wired deliberately.
const INCOME_EXACT: Array[String] = ["harvest"]
const INCOME_PREFIXES: Array[String] = ["sell:"]
const SPEND_PREFIXES: Array[String] = ["build:", "prod:"]


func _ready() -> void:
    var em := get_node("/root/EconomyManager") as EconomyManager
    if em:
        em.credits_changed.connect(_on_credits_changed)


func _exit_tree() -> void:
    var em := get_node("/root/EconomyManager") as EconomyManager
    if em:
        em.credits_changed.disconnect(_on_credits_changed)


## Maps a credits_changed reason to a sound id; "" means stay silent.
func resolve_sound_id(reason: String) -> String:
    if INCOME_EXACT.has(reason) or _has_prefix(reason, INCOME_PREFIXES):
        return SOUND_INCOME
    if _has_prefix(reason, SPEND_PREFIXES):
        return SOUND_SPEND
    return ""


func _on_credits_changed(_player_id: int, _balance: int, reason: String, _category: String) -> void:
    var sound_id := resolve_sound_id(reason)
    if sound_id.is_empty():
        return
    AudioManager.play_sound(sound_id)


func _has_prefix(reason: String, prefixes: Array[String]) -> bool:
    for prefix in prefixes:
        if reason.begins_with(prefix):
            return true
    return false
