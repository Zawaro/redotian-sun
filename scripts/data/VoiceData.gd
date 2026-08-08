class_name VoiceData extends Resource

## Identity
@export_group("Identity")
## Voice set id — standalone catalog item any entity can reference (no faction/player coupling).
@export var id: String = ""

## Voice events — each maps an event name to interchangeable audio id variants
## (mirrors rules.ini VoiceSelect/VoiceMove/VoiceAttack/VoiceDie/VoiceFeedback).
@export_group("Voice Events")
@export var select: Array[String] = []
@export var move: Array[String] = []
@export var attack: Array[String] = []
@export var die: Array[String] = []
@export var feedback: Array[String] = []

const EVENT_SELECT: String = "select"
const EVENT_MOVE: String = "move"
const EVENT_ATTACK: String = "attack"
const EVENT_DIE: String = "die"
const EVENT_FEEDBACK: String = "feedback"


func get_event(event_name: String) -> Array[String]:
    match event_name:
        EVENT_SELECT:
            return select
        EVENT_MOVE:
            return move
        EVENT_ATTACK:
            return attack
        EVENT_DIE:
            return die
        EVENT_FEEDBACK:
            return feedback
        _:
            return []
