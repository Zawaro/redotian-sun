class_name SpecialAbilityComponent extends Node

@export var cloakable: bool = false
@export var self_healing: bool = false
@export var c4: bool = false
@export var engineer: bool = false
@export var disguise: bool = false
@export var agent: bool = false
@export var thief: bool = false
@export var tiberium_proof: bool = false
@export var immune_to_veins: bool = false
@export var capturable: bool = false


func configure(data: EntityData) -> void:
    cloakable = data.cloakable
    self_healing = data.self_healing
    c4 = data.c4
    engineer = data.engineer
    disguise = data.disguise
    agent = data.agent
    thief = data.thief
    tiberium_proof = data.tiberium_proof
    immune_to_veins = data.immune_to_veins
    capturable = data.capturable


func has_ability(ability: String) -> bool:
    var abilities := {
        "cloakable": cloakable,
        "self_healing": self_healing,
        "c4": c4,
        "engineer": engineer,
        "disguise": disguise,
        "agent": agent,
        "thief": thief,
        "tiberium_proof": tiberium_proof,
        "immune_to_veins": immune_to_veins,
        "capturable": capturable,
    }
    return abilities.get(ability, false)
