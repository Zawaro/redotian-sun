extends Node

## AudioManager autoload — dynamic .tres loader and event-driven playback.
## Mirrors EntityFactory/TerrainCatalog data-set loading: register a directory,
## scan it recursively, cache AudioData/VoiceData by id. Missing ids or failed
## loads always warn and return silently — never crash gameplay.

const DEFAULT_DATA_PATH: String = "res://resources/audio/"
const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"
const BUS_VOICE: String = "Voice"
const REQUIRED_BUSES: Array[String] = [BUS_MASTER, BUS_MUSIC, BUS_SFX, BUS_VOICE]

var _audio_cache: Dictionary = {}
var _voice_cache: Dictionary = {}
var _data_sets: Array[String] = []


func _ready() -> void:
    _ensure_buses()
    register_data_set(DEFAULT_DATA_PATH)


func _ensure_buses() -> void:
    for bus_name in REQUIRED_BUSES:
        if AudioServer.get_bus_index(bus_name) == -1:
            AudioServer.add_bus()


func register_data_set(path: String) -> void:
    if _data_sets.has(path):
        return
    _data_sets.append(path)
    _scan_directory(path)


func _scan_directory(path: String) -> void:
    var dir := DirAccess.open(path)
    if not dir:
        push_warning("AudioManager: Cannot open directory: %s" % path)
        return
    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        if file_name.ends_with(".tres"):
            var full_path := path + file_name
            var resource := load(full_path)
            if resource is AudioData:
                _audio_cache[resource.id] = resource
            elif resource is VoiceData:
                _voice_cache[resource.id] = resource
        elif dir.current_is_dir() and not file_name.begins_with("."):
            _scan_directory(path + file_name + "/")
        file_name = dir.get_next()
    dir.list_dir_end()


func get_audio_data(id: String) -> AudioData:
    return _audio_cache.get(id, null) as AudioData


func get_voice_data(id: String) -> VoiceData:
    return _voice_cache.get(id, null) as VoiceData


func play_sound(id: String, position: Vector3 = Vector3.INF) -> void:
    var audio := get_audio_data(id)
    if not audio:
        push_warning("AudioManager: Unknown sound id: %s" % id)
        return
    if audio.path.is_empty() or not ResourceLoader.exists(audio.path):
        push_warning("AudioManager: Missing audio file for id %s: %s" % [id, audio.path])
        return
    var stream := load(audio.path) as AudioStream
    if not stream:
        push_warning("AudioManager: Failed to load audio stream for id %s: %s" % [id, audio.path])
        return

    var spatial := audio.is_spatial and position != Vector3.INF
    if spatial:
        var player := AudioStreamPlayer3D.new()
        player.stream = stream
        player.volume_db = audio.volume_db
        player.bus = audio.bus
        player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
        add_child(player)
        player.global_position = position
        player.play()
        player.finished.connect(func() -> void: player.queue_free())
    else:
        var player := AudioStreamPlayer.new()
        player.stream = stream
        player.volume_db = audio.volume_db
        player.bus = audio.bus
        add_child(player)
        player.play()
        player.finished.connect(func() -> void: player.queue_free())


func play_voice(voice_id: String, event_name: String, position: Vector3 = Vector3.INF) -> void:
    var voice := get_voice_data(voice_id)
    if not voice:
        push_warning("AudioManager: Unknown voice id: %s" % voice_id)
        return
    var variants := voice.get_event(event_name)
    if variants.is_empty():
        return
    var chosen := variants[randi() % variants.size()]
    play_sound(chosen, position)
