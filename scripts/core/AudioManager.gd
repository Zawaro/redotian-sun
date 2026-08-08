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
            AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


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
        player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
        add_child(player)
        var viewport_rect := _viewport_rect()
        if viewport_rect.size == Vector2.ZERO:
            # No camera (headless/UI) — positional at the source, no falloff.
            player.global_position = position
        else:
            # RTS rule: full volume while on screen, fall off beyond the
            # viewport edge (distance from the camera past the edge).
            # ponytail: unit_size is the falloff knob, tune from playtesting.
            player.unit_size = maxf(viewport_rect.size.y, 1.0) * 0.5
            player.global_position = _falloff_position(
                position, viewport_rect, _listener_position()
            )
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


## Voice playback is commander radio chatter: always centered on the camera at
## full volume, regardless of where the speaking unit is in the world.
func play_voice(voice_id: String, event_name: String) -> void:
    var voice := get_voice_data(voice_id)
    if not voice:
        push_warning("AudioManager: Unknown voice id: %s" % voice_id)
        return
    var variants := voice.get_event(event_name)
    if variants.is_empty():
        return
    var chosen := variants[randi() % variants.size()]
    play_sound(chosen, _listener_position())


## World-space viewport footprint: the 4 screen corners unprojected to the
## ground plane. Zero-size rect signals "no camera" (headless/UI contexts).
func _viewport_rect() -> Rect2:
    var viewport := get_viewport()
    var camera := viewport.get_camera_3d() if viewport else null
    if not camera or not camera.is_inside_tree():
        return Rect2()
    var ground := Plane(Vector3.UP, 0.0)
    var screen_rect := viewport.get_visible_rect()
    var corners: Array[Vector2] = [
        screen_rect.position,
        screen_rect.position + Vector2(screen_rect.size.x, 0.0),
        screen_rect.position + screen_rect.size,
        screen_rect.position + Vector2(0.0, screen_rect.size.y),
    ]
    var min_p: Vector2 = Vector2.INF
    var max_p: Vector2 = Vector2.INF * -1.0
    var hit_count := 0
    for corner in corners:
        var hit: Variant = ground.intersects_ray(
            camera.project_ray_origin(corner), camera.project_ray_normal(corner)
        )
        if hit == null:
            continue
        var p: Vector3 = hit
        min_p.x = minf(min_p.x, p.x)
        min_p.y = minf(min_p.y, p.z)
        max_p.x = maxf(max_p.x, p.x)
        max_p.y = maxf(max_p.y, p.z)
        hit_count += 1
    if hit_count < 3:
        return Rect2()
    return Rect2(min_p, max_p - min_p)


## Distance from a world position past the viewport rectangle (0 when on screen).
func _excess_distance(world_position: Vector3, viewport_rect: Rect2) -> float:
    var center := viewport_rect.get_center()
    var excess := Vector2(
        maxf(absf(world_position.x - center.x) - viewport_rect.size.x * 0.5, 0.0),
        maxf(absf(world_position.z - center.y) - viewport_rect.size.y * 0.5, 0.0),
    )
    return excess.length()


## Position for a spatial player: on the listener-relative bearing of the source
## at distance `excess`, so the engine's attenuation applies only off-screen.
func _falloff_position(world_position: Vector3, viewport_rect: Rect2, listener: Vector3) -> Vector3:
    var excess := _excess_distance(world_position, viewport_rect)
    if excess <= 0.0:
        return listener
    var dir := Vector3(world_position.x - listener.x, 0.0, world_position.z - listener.z)
    if dir.length_squared() < 0.0001:
        return listener
    return listener + dir.normalized() * excess


func _listener_position() -> Vector3:
    var camera := get_viewport().get_camera_3d() if get_viewport() else null
    if camera and camera.is_inside_tree():
        return camera.global_position
    return Vector3.ZERO
