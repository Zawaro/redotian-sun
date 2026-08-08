# ponytail: thin data wrapper; voice selection/order logic lives in the audio hooks
class_name VoiceComponent extends Node

@export_group("Voice")
@export var voice_data: VoiceData = null


func configure(data: EntityData) -> void:
    voice_data = data.voice_data
