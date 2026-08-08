class_name AudioData extends Resource

## Identity
@export_group("Identity")
## Sound id matching the sound.ini [SoundList] name (e.g. "INFGUN3", "15-I000").
@export var id: String = ""

## Audio stream path (res://).
@export_group("Playback")
@export var path: String = ""
## Bus to route this sound to (Master/Music/SFX/Voice).
@export var bus: String = "SFX"
## Playback priority (default 10, max 100) — reserved for future mixing/ducking.
@export var priority: int = 10
## Volume offset in dB.
@export var volume_db: float = 0.0
## Play positionally at the caller's world position when true.
@export var is_spatial: bool = true
