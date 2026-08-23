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
## Hard cap on concurrent copies of one sound id; past this the oldest copy is dropped.
const MAX_STACK_PER_ID: int = 12
## Skip starting a sound id that already played within this window. Kills the
## density wall from high-ROF weapons (M1 carbine at 20/s × 20 units = 400
## spawns/s): stacked fire then sounds like a single weapon.
## ponytail: retrigger knob, tune from playtesting.
const RETRIGGER_INTERVAL_MS: float = 100.0
## Master bus compressor — gentle, pulls the whole mix down only when it gets
## busy, before the hard limiter (docs-recommended chain). Makeup gain
## restores the compressed level so loud transients sit back at the ceiling.
## ponytail: knobs, tune from playtesting.
const MASTER_COMPRESSOR_THRESHOLD_DB: float = -18.0
const MASTER_COMPRESSOR_RATIO: float = 2.0
const MASTER_COMPRESSOR_GAIN_DB: float = 8.0
## Master bus hard limiter — final ceiling below 0 dB so the mixed output can never clip.
## ponytail: ceiling knob, tune from playtesting.
const MASTER_LIMIT_CEILING_DB: float = -1.0
## SFX bus hard limiter — reels in busy combat stacks above the threshold.
const SFX_LIMIT_CEILING_DB: float = -1.0
## Voice bus compressor — keeps stacked voice lines at consistent volume.
const VOICE_COMPRESSOR_THRESHOLD_DB: float = -18.0
const VOICE_COMPRESSOR_RATIO: float = 2.0
const VOICE_COMPRESSOR_GAIN_DB: float = 8.0

var _audio_cache: Dictionary = {}
var _voice_cache: Dictionary = {}
var _data_sets: Array[String] = []
var _active_players_by_id: Dictionary = {}
var _active_players_by_bus: Dictionary = {}
var _last_played_at: Dictionary = {}


func _ready() -> void:
    _ensure_buses()
    register_data_set(DEFAULT_DATA_PATH)


func _ensure_buses() -> void:
    for bus_name in REQUIRED_BUSES:
        if AudioServer.get_bus_index(bus_name) == -1:
            AudioServer.add_bus()
            AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
    _ensure_bus_effects()


## Install the loudness-ceiling effects once per bus. Idempotent: a bus that
## already carries an effect of the same class is left untouched. Master chain
## is compressor → hard limiter (docs recommendation: compress before the
## limiter's ceiling so the limiter stays subtle).
func _ensure_bus_effects() -> void:
    _add_bus_effect_if_missing(
        BUS_MASTER,
        _make_compressor(
            MASTER_COMPRESSOR_THRESHOLD_DB, MASTER_COMPRESSOR_RATIO, MASTER_COMPRESSOR_GAIN_DB
        ),
    )
    _add_bus_effect_if_missing(BUS_MASTER, _make_limiter(MASTER_LIMIT_CEILING_DB))
    _add_bus_effect_if_missing(BUS_SFX, _make_limiter(SFX_LIMIT_CEILING_DB))
    _add_bus_effect_if_missing(
        BUS_VOICE,
        _make_compressor(
            VOICE_COMPRESSOR_THRESHOLD_DB, VOICE_COMPRESSOR_RATIO, VOICE_COMPRESSOR_GAIN_DB
        ),
    )


func _add_bus_effect_if_missing(bus_name: String, effect: AudioEffect) -> void:
    var bus_idx := AudioServer.get_bus_index(bus_name)
    if bus_idx == -1:
        return
    for effect_idx in AudioServer.get_bus_effect_count(bus_idx):
        var existing: AudioEffect = AudioServer.get_bus_effect(bus_idx, effect_idx)
        if existing.get_class() == effect.get_class():
            return
    AudioServer.add_bus_effect(bus_idx, effect)


func _make_compressor(threshold_db: float, ratio: float, gain_db: float) -> AudioEffect:
    var effect := AudioEffectCompressor.new()
    effect.threshold = threshold_db
    effect.ratio = ratio
    effect.gain = gain_db
    return effect


func _make_limiter(ceiling_db: float) -> AudioEffect:
    var effect := AudioEffectHardLimiter.new()
    effect.ceiling_db = ceiling_db
    return effect


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
        var resource_path := file_name.trim_suffix(".remap")
        if resource_path.ends_with(".tres"):
            var full_path := path + resource_path
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

    var now_ms := Time.get_ticks_msec()
    if now_ms - (_last_played_at.get(id, -1) as int) < RETRIGGER_INTERVAL_MS:
        return
    _last_played_at[id] = now_ms

    var active := _active_players_by_id.get(id, []) as Array
    if active.size() >= MAX_STACK_PER_ID:
        var oldest := active.pop_front() as Node
        if is_instance_valid(oldest):
            oldest.call("stop")
            oldest.queue_free()
        _untrack_player(id, oldest)
    _active_players_by_id[id] = active

    var spatial := audio.is_spatial and position != Vector3.INF
    if spatial:
        var player := AudioStreamPlayer3D.new()
        player.stream = stream
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
        _track_player(id, player, active)
    else:
        var player := AudioStreamPlayer.new()
        player.stream = stream
        player.bus = audio.bus
        add_child(player)
        player.play()
        _track_player(id, player, active)


## Voice playback is commander radio chatter, always centered on the camera.
## It routes through play_sound, so stacked identical voices share the same
## loudness budget as any other stacked sound.
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


## Track a new copy on its bus. The whole bus stack is rebalanced so N
## concurrent copies — same or different ids — share one copy's loudness
## budget (each at -20·log10(N) dB).
func _track_player(id: String, player: Node, active: Array) -> void:
    active.append(player)
    var audio := get_audio_data(id)
    player.set_meta("stack_base_db", audio.volume_db)
    var bus_players := _active_players_by_bus.get(audio.bus, []) as Array
    bus_players.append(player)
    _active_players_by_bus[audio.bus] = bus_players
    _renormalize_bus(bus_players)
    player.connect("finished", _on_player_finished.bind(id, player))


## Scale every active copy on a bus by the bus's total concurrent count, so a
## stacked mix — across ids — sums to exactly one instance's loudness.
func _renormalize_bus(bus_players: Array) -> void:
    var count: int = bus_players.size()
    if count == 0:
        return
    var stack_db: float = linear_to_db(1.0 / float(count))
    for player: Node in bus_players:
        var base_db: float = player.get_meta("stack_base_db", 0.0) as float
        player.set("volume_db", base_db + stack_db)


## Remove a copy from its bus stack and rebalance the survivors.
func _untrack_player(id: String, player: Node) -> void:
    var audio := get_audio_data(id)
    if not audio or not is_instance_valid(player):
        return
    var bus_players := _active_players_by_bus.get(audio.bus, []) as Array
    bus_players.erase(player)
    if bus_players.is_empty():
        _active_players_by_bus.erase(audio.bus)
    else:
        _renormalize_bus(bus_players)


func _on_player_finished(id: String, player: Node) -> void:
    _untrack_player(id, player)
    if is_instance_valid(player):
        player.queue_free()
    var active := _active_players_by_id.get(id, []) as Array
    active.erase(player)
    if active.is_empty():
        _active_players_by_id.erase(id)


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
