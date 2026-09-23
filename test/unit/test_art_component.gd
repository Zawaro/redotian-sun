extends Node

# ArtComponent unit tests — BatchLoader integration, animation clip engine,
# power gating, damaged swap, theater resolution, and one-shot clips.

const ART_COMPONENT_SCRIPT: GDScript = preload("res://scripts/components/ArtComponent.gd")

var _signal_fired := false


func _make_component(entity: Node3D) -> ArtComponent:
    var comp := Node3D.new()
    comp.name = "ArtComponent"
    comp.set_script(ART_COMPONENT_SCRIPT)
    entity.add_child(comp)
    return comp as ArtComponent


func _make_data(path: String) -> EntityData:
    var data := EntityData.new()
    data.id = "TEST_ART"
    var art := ArtData.new()
    art.id = "TEST_ART"
    art.model_path = path
    data.art_data = art
    data.foundation = Vector2i(1, 1)
    return data


func _make_scene() -> PackedScene:
    var root := Node3D.new()
    root.name = "TestModel"
    var ps := PackedScene.new()
    ps.pack(root)
    root.free()
    return ps


func _make_animated_scene(anim_name: String, length: float = 1.0) -> PackedScene:
    var root := Node3D.new()
    root.name = "ClipModel"
    var ap := AnimationPlayer.new()
    ap.name = "AnimationPlayer"
    var lib := AnimationLibrary.new()
    var anim := Animation.new()
    anim.length = length
    lib.add_animation(anim_name, anim)
    ap.add_animation_library("", lib)
    root.add_child(ap)
    ap.owner = root
    var ps := PackedScene.new()
    ps.pack(root)
    root.free()
    return ps


func _make_clip(
    role: AnimClipData.Role, model_path: String, clip_name: String = ""
) -> AnimClipData:
    var clip := AnimClipData.new()
    clip.role = role
    clip.model_path = model_path
    clip.clip_name = clip_name
    return clip


## Builds an entity (optional Power/Health siblings) with a configured
## ArtComponent. Returns [entity, art, power, health].
func _configured_art(
    model_path: String, animations: Array[AnimClipData], with_health := false, with_power := false
) -> Array:
    var entity := Node3D.new()
    var power: PowerComponent = null
    if with_power:
        power = PowerComponent.new()
        power.name = "PowerComponent"
        entity.add_child(power)
    var health: HealthComponent = null
    if with_health:
        health = HealthComponent.new()
        health.name = "HealthComponent"
        health.max_health = 100
        health.current_health = 100
        entity.add_child(health)
    var comp := _make_component(entity)
    var data := _make_data(model_path)
    data.art_data.animations = animations
    comp.configure(data)
    return [entity, comp, power, health]


func _on_model_loaded() -> void:
    _signal_fired = true


func test_batch_loader_cache_hit_instantiates_synchronously():
    var path := "res://__test_batch_cache_hit__.tscn"
    BatchLoader._cache[path] = _make_scene()

    var entity := Node3D.new()
    var comp := _make_component(entity)
    _signal_fired = false
    comp.model_loaded.connect(_on_model_loaded)
    comp.configure(_make_data(path))

    var has_child: bool = comp.get_child_count() > 0
    TestHelper.assert_true(has_child, "BatchLoader cache hit adds model as child synchronously")
    TestHelper.assert_true(
        not _signal_fired, "cache hit defers model_loaded until after configure() returns"
    )

    BatchLoader._cache.erase(path)
    entity.free()


func test_fallback_starts_threaded_load():
    var path := "res://games/ts/assets/models/gdi_conyard01.glb"
    BatchLoader._cache.erase(path)
    TestHelper.assert_true(ResourceLoader.exists(path), "test model resource exists")

    var entity := Node3D.new()
    var comp := _make_component(entity)
    comp.configure(_make_data(path))

    TestHelper.assert_true(
        comp._waiting_for_path == path, "fallback sets _waiting_for_path to the model path"
    )

    BatchLoader._cache.erase(path)
    entity.free()


func test_missing_model_starts_no_load():
    var entity := Node3D.new()
    var comp := _make_component(entity)
    comp.configure(_make_data("res://does_not_exist_model.glb"))

    var no_child: bool = comp.get_child_count() == 0
    var not_waiting: bool = comp._waiting_for_path == ""
    TestHelper.assert_true(no_child, "missing model adds no child")
    TestHelper.assert_true(not_waiting, "missing model does not start a load")

    entity.free()


func test_cache_shared_across_components():
    var path := "res://__test_shared_batch_cache__.tscn"
    BatchLoader._cache[path] = _make_scene()

    var entity_a := Node3D.new()
    var comp_a := _make_component(entity_a)
    comp_a.configure(_make_data(path))

    var entity_b := Node3D.new()
    var comp_b := _make_component(entity_b)
    comp_b.configure(_make_data(path))

    var both_have_model: bool = comp_a.get_child_count() > 0 and comp_b.get_child_count() > 0
    var neither_waiting: bool = comp_a._waiting_for_path == "" and comp_b._waiting_for_path == ""
    TestHelper.assert_true(
        both_have_model, "both components instantiate from the shared BatchLoader cache"
    )
    TestHelper.assert_true(neither_waiting, "cached path triggers no threaded load in either")

    BatchLoader._cache.erase(path)
    entity_a.free()
    entity_b.free()


# --- Animation clip engine ---------------------------------------------------


func test_clip_instantiated_at_offset():
    var base := "res://__art_base_offset__.tscn"
    var clip_path := "res://__art_clip_offset__.tscn"
    BatchLoader._cache[base] = _make_scene()
    BatchLoader._cache[clip_path] = _make_animated_scene("spin")

    var entry := _make_clip(AnimClipData.Role.ACTIVE, clip_path, "spin")
    entry.offset = Vector3(0, 1.5, 0)
    var ctx := _configured_art(base, [entry])
    var comp: ArtComponent = ctx[1]
    var node: Node3D = comp._clips[0]["node"]
    TestHelper.assert_true(is_instance_valid(node), "clip node instantiated")
    TestHelper.assert_true(node.position.is_equal_approx(entry.offset), "clip sits at its offset")

    BatchLoader._cache.erase(base)
    BatchLoader._cache.erase(clip_path)
    ctx[0].free()


func test_empty_path_skipped():
    var base := "res://__art_base_empty__.tscn"
    BatchLoader._cache[base] = _make_scene()
    var ctx := _configured_art(base, [_make_clip(AnimClipData.Role.ACTIVE, "")])
    var comp: ArtComponent = ctx[1]
    TestHelper.assert_eq(comp._clips.size(), 0, "empty model_path yields no clip")

    BatchLoader._cache.erase(base)
    ctx[0].free()


func test_missing_clip_does_not_block_base():
    var base := "res://__art_base_missing_clip__.tscn"
    var good := "res://__art_good_clip__.tscn"
    BatchLoader._cache[base] = _make_scene()
    BatchLoader._cache[good] = _make_animated_scene("spin")

    var ctx := _configured_art(
        base,
        [
            _make_clip(AnimClipData.Role.ACTIVE, "res://__art_absent_clip__.tscn", "spin"),
            _make_clip(AnimClipData.Role.ACTIVE, good, "spin"),
        ],
    )
    var comp: ArtComponent = ctx[1]
    TestHelper.assert_true(is_instance_valid(comp._model_root), "base model still loads")
    TestHelper.assert_eq(comp._clips.size(), 1, "only the loadable clip is instantiated")

    BatchLoader._cache.erase(base)
    BatchLoader._cache.erase(good)
    ctx[0].free()


func test_clip_animation_plays_with_speed_and_loop():
    var base := "res://__art_base_play__.tscn"
    var clip_path := "res://__art_clip_play__.tscn"
    BatchLoader._cache[base] = _make_scene()
    BatchLoader._cache[clip_path] = _make_animated_scene("spin")

    var entry := _make_clip(AnimClipData.Role.ACTIVE, clip_path, "spin")
    entry.speed_scale = 0.5
    entry.loop = true
    var ctx := _configured_art(base, [entry])
    var comp: ArtComponent = ctx[1]
    var player: AnimationPlayer = comp._clips[0]["player"]
    TestHelper.assert_true(player.is_playing(), "clip animation is playing")
    TestHelper.assert_eq(
        String(player.current_animation), "spin", "clip_name selects the animation"
    )
    TestHelper.assert_true(absf(player.speed_scale - 0.5) < 0.0001, "speed_scale is applied")
    TestHelper.assert_eq(
        player.get_animation("spin").loop_mode, Animation.LOOP_LINEAR, "loop sets LOOP_LINEAR"
    )

    BatchLoader._cache.erase(base)
    BatchLoader._cache.erase(clip_path)
    ctx[0].free()


func test_clip_without_animation_player_is_inert():
    var base := "res://__art_base_inert__.tscn"
    var clip_path := "res://__art_clip_inert__.tscn"
    BatchLoader._cache[base] = _make_scene()
    BatchLoader._cache[clip_path] = _make_scene()

    var ctx := _configured_art(base, [_make_clip(AnimClipData.Role.ACTIVE, clip_path)])
    var comp: ArtComponent = ctx[1]
    TestHelper.assert_eq(comp._clips.size(), 1, "clip node still instantiated")
    TestHelper.assert_true(comp._clips[0]["player"] == null, "no player resolved")
    TestHelper.assert_eq(comp._clips[0]["anim_name"], "", "no animation name resolved")

    BatchLoader._cache.erase(base)
    BatchLoader._cache.erase(clip_path)
    ctx[0].free()


# --- Power gating ------------------------------------------------------------


func test_power_gate_pauses_only_power_required_clips():
    var base := "res://__art_base_power__.tscn"
    var clip_path := "res://__art_clip_power__.tscn"
    BatchLoader._cache[base] = _make_scene()
    BatchLoader._cache[clip_path] = _make_animated_scene("spin")

    var gated := _make_clip(AnimClipData.Role.ACTIVE, clip_path, "spin")
    gated.requires_power = true
    var free := _make_clip(AnimClipData.Role.ACTIVE, clip_path, "spin")
    free.requires_power = false

    var ctx := _configured_art(base, [gated, free], false, true)
    var comp: ArtComponent = ctx[1]
    var power: PowerComponent = ctx[2]
    var gated_player: AnimationPlayer = comp._clips[0]["player"]
    var free_player: AnimationPlayer = comp._clips[1]["player"]
    TestHelper.assert_true(gated_player.is_playing(), "gated clip plays while online")
    TestHelper.assert_true(free_player.is_playing(), "free clip plays while online")

    power.set_online(false)
    TestHelper.assert_true(not gated_player.is_playing(), "power-required clip pauses")
    TestHelper.assert_true(free_player.is_playing(), "non-power clip keeps playing")

    power.set_online(true)
    TestHelper.assert_true(gated_player.is_playing(), "power-required clip resumes")

    BatchLoader._cache.erase(base)
    BatchLoader._cache.erase(clip_path)
    ctx[0].free()


# --- Damaged swap ------------------------------------------------------------


func test_damaged_swap_at_threshold_and_revert():
    var base := "res://__art_base_damage__.tscn"
    var normal_path := "res://__art_clip_normal__.tscn"
    var damaged_path := "res://__art_clip_damaged__.tscn"
    BatchLoader._cache[base] = _make_scene()
    BatchLoader._cache[normal_path] = _make_animated_scene("idle")
    BatchLoader._cache[damaged_path] = _make_animated_scene("idle_damaged")

    var entry := _make_clip(AnimClipData.Role.ACTIVE, normal_path, "idle")
    entry.damaged_model_path = damaged_path
    var ctx := _configured_art(base, [entry], true)
    var comp: ArtComponent = ctx[1]
    var health: HealthComponent = ctx[3]
    var normal: Node3D = comp._clips[0]["node"]
    var damaged: Node3D = comp._clips[0]["damaged_node"]
    TestHelper.assert_true(normal.visible, "normal clip visible at full health")
    TestHelper.assert_true(not damaged.visible, "damaged clip hidden at full health")

    health.current_health = 50
    TestHelper.assert_true(not normal.visible, "normal clip hidden at exactly 50%")
    TestHelper.assert_true(damaged.visible, "damaged clip shown at exactly 50%")
    TestHelper.assert_true(
        (comp._clips[0]["damaged_player"] as AnimationPlayer).is_playing(), "damaged clip plays"
    )

    health.current_health = 60
    TestHelper.assert_true(normal.visible, "normal clip restored above 50%")
    TestHelper.assert_true(not damaged.visible, "damaged clip hidden above 50%")

    BatchLoader._cache.erase(base)
    BatchLoader._cache.erase(normal_path)
    BatchLoader._cache.erase(damaged_path)
    ctx[0].free()


func test_no_damaged_variant_is_unaffected():
    var base := "res://__art_base_nodamage__.tscn"
    var normal_path := "res://__art_clip_nodamage__.tscn"
    BatchLoader._cache[base] = _make_scene()
    BatchLoader._cache[normal_path] = _make_animated_scene("idle")

    var entry := _make_clip(AnimClipData.Role.ACTIVE, normal_path, "idle")
    var ctx := _configured_art(base, [entry], true)
    var comp: ArtComponent = ctx[1]
    var health: HealthComponent = ctx[3]
    var normal: Node3D = comp._clips[0]["node"]

    health.current_health = 40
    TestHelper.assert_true(normal.visible, "normal clip continues without a damaged variant")
    TestHelper.assert_true(comp._clips[0].get("damaged_node") == null, "no damaged node exists")

    BatchLoader._cache.erase(base)
    BatchLoader._cache.erase(normal_path)
    ctx[0].free()


# --- Theater resolution ------------------------------------------------------


func test_theater_suffix_resolution():
    var generic := "res://__theater_res_generic.tres"
    var snow := "res://__theater_res_generic_snow.tres"
    var a := ArtData.new()
    a.id = "GENERIC"
    var b := ArtData.new()
    b.id = "SNOW"
    TestHelper.assert_eq(ResourceSaver.save(a, generic), OK, "generic test resource saved")
    TestHelper.assert_eq(ResourceSaver.save(b, snow), OK, "snow test resource saved")

    var art := ArtData.new()
    art.id = "T"

    art.new_theater = true
    TestHelper.assert_eq(art.resolve_art_path(generic, "snow"), snow, "theater variant selected")
    TestHelper.assert_eq(
        art.resolve_art_path(generic, "desert"), generic, "missing variant falls back to generic"
    )

    art.new_theater = false
    TestHelper.assert_eq(art.resolve_art_path(generic, "snow"), generic, "disabled uses generic")

    art.new_theater = true
    TestHelper.assert_eq(art.resolve_art_path(generic, ""), generic, "no theater uses generic")

    DirAccess.remove_absolute(generic)
    DirAccess.remove_absolute(snow)


# --- One-shot lifecycle clips ------------------------------------------------


func test_door_forward_and_reverse():
    var base := "res://__art_base_door__.tscn"
    var door_path := "res://__art_clip_door__.tscn"
    BatchLoader._cache[base] = _make_scene()
    BatchLoader._cache[door_path] = _make_animated_scene("open")

    var entry := _make_clip(AnimClipData.Role.DOOR, door_path, "open")
    var ctx := _configured_art(base, [entry])
    var comp: ArtComponent = ctx[1]
    var player: AnimationPlayer = comp._clips[0]["player"]
    TestHelper.assert_eq(
        player.get_animation("open").loop_mode, Animation.LOOP_NONE, "door is forced non-looping"
    )
    TestHelper.assert_true(not player.is_playing(), "idle door is not playing")
    TestHelper.assert_true(
        absf(player.current_animation_position) < 0.0001, "idle door rests on frame 0"
    )

    comp._on_exit_in_progress()
    TestHelper.assert_true(player.get_playing_speed() > 0.0, "door plays forward to open")

    comp._on_exit_completed()
    TestHelper.assert_true(player.get_playing_speed() < 0.0, "door plays backward to close")

    BatchLoader._cache.erase(base)
    BatchLoader._cache.erase(door_path)
    ctx[0].free()


func test_production_clip_starts_and_stops():
    var base := "res://__art_base_prod__.tscn"
    var prod_path := "res://__art_clip_prod__.tscn"
    BatchLoader._cache[base] = _make_scene()
    BatchLoader._cache[prod_path] = _make_animated_scene("produce")

    var entry := _make_clip(AnimClipData.Role.PRODUCTION, prod_path, "produce")
    var ctx := _configured_art(base, [entry])
    var comp: ArtComponent = ctx[1]
    var node: Node3D = comp._clips[0]["node"]
    var player: AnimationPlayer = comp._clips[0]["player"]
    TestHelper.assert_eq(
        player.get_animation("produce").loop_mode,
        Animation.LOOP_NONE,
        "production is forced non-looping"
    )
    TestHelper.assert_true(not node.visible, "production clip hidden while idle")

    comp._on_exit_in_progress()
    TestHelper.assert_true(node.visible, "production clip shown while factory busy")
    TestHelper.assert_true(player.is_playing(), "production clip plays while factory busy")

    comp._on_exit_completed()
    TestHelper.assert_true(not node.visible, "production clip hidden when idle again")
    TestHelper.assert_true(not player.is_playing(), "production clip stops when idle again")

    BatchLoader._cache.erase(base)
    BatchLoader._cache.erase(prod_path)
    ctx[0].free()


func test_buildup_hides_and_reveals():
    var base := "res://__art_base_buildup__.tscn"
    var buildup_path := "res://__art_clip_buildup__.tscn"
    BatchLoader._cache[base] = _make_scene()
    BatchLoader._cache[buildup_path] = _make_animated_scene("assemble")

    var entry := _make_clip(AnimClipData.Role.BUILDUP, buildup_path, "assemble")
    var ctx := _configured_art(base, [entry])
    var comp: ArtComponent = ctx[1]
    var node: Node3D = comp._clips[0]["node"]
    var player: AnimationPlayer = comp._clips[0]["player"]
    TestHelper.assert_eq(
        player.get_animation("assemble").loop_mode,
        Animation.LOOP_NONE,
        "buildup is forced non-looping despite the default loop flag"
    )
    TestHelper.assert_true(not node.visible, "buildup clip hidden before placement")

    comp.play_buildup()
    TestHelper.assert_true(comp._model_root.visible == false, "base model hidden during buildup")
    TestHelper.assert_true(node.visible, "buildup clip shown while playing")
    TestHelper.assert_true(player.is_playing(), "buildup clip plays")

    comp._on_buildup_finished("assemble")
    TestHelper.assert_true(comp._model_root.visible, "base model revealed when buildup finishes")
    TestHelper.assert_true(not node.visible, "buildup clip hidden when done")

    BatchLoader._cache.erase(base)
    BatchLoader._cache.erase(buildup_path)
    ctx[0].free()


# --- Review-fix regressions --------------------------------------------------


func test_spawn_damaged_applies_on_cache_hit():
    var base := "res://__art_base_spawndmg__.tscn"
    var normal_path := "res://__art_clip_spawnnormal__.tscn"
    var damaged_path := "res://__art_clip_spawndamaged__.tscn"
    BatchLoader._cache[base] = _make_scene()
    BatchLoader._cache[normal_path] = _make_animated_scene("idle")
    BatchLoader._cache[damaged_path] = _make_animated_scene("idle_damaged")

    var entity := Node3D.new()
    var health := HealthComponent.new()
    health.name = "HealthComponent"
    health.max_health = 100
    health.current_health = 30
    entity.add_child(health)
    var comp := _make_component(entity)

    var data := _make_data(base)
    var entry := _make_clip(AnimClipData.Role.ACTIVE, normal_path, "idle")
    entry.damaged_model_path = damaged_path
    data.art_data.animations.append(entry)
    comp.configure(data)

    var normal: Node3D = comp._clips[0]["node"]
    var damaged: Node3D = comp._clips[0]["damaged_node"]
    TestHelper.assert_true(
        not normal.visible, "spawn-damaged entity hides the normal clip on the cache-hit path"
    )
    TestHelper.assert_true(
        damaged.visible, "spawn-damaged entity shows the damaged clip immediately"
    )

    BatchLoader._cache.erase(base)
    BatchLoader._cache.erase(normal_path)
    BatchLoader._cache.erase(damaged_path)
    entity.free()


func test_power_gate_pauses_one_shot_clip():
    var base := "res://__art_base_powone__.tscn"
    var door_path := "res://__art_clip_powone__.tscn"
    BatchLoader._cache[base] = _make_scene()
    BatchLoader._cache[door_path] = _make_animated_scene("open")

    var entry := _make_clip(AnimClipData.Role.DOOR, door_path, "open")
    entry.requires_power = true
    var ctx := _configured_art(base, [entry], false, true)
    var comp: ArtComponent = ctx[1]
    var power: PowerComponent = ctx[2]
    var player: AnimationPlayer = comp._clips[0]["player"]

    comp._on_exit_in_progress()
    TestHelper.assert_true(player.is_playing(), "one-shot clip plays while online")

    power.set_online(false)
    TestHelper.assert_true(
        not player.is_playing(), "blackout pauses a power-required one-shot clip"
    )

    BatchLoader._cache.erase(base)
    BatchLoader._cache.erase(door_path)
    ctx[0].free()


func test_shared_clip_loops_are_isolated_per_instance():
    var base := "res://__art_base_isolate__.tscn"
    var clip_path := "res://__art_clip_isolate__.tscn"
    BatchLoader._cache[base] = _make_scene()
    BatchLoader._cache[clip_path] = _make_animated_scene("anim")

    var active_entry := _make_clip(AnimClipData.Role.ACTIVE, clip_path, "anim")
    active_entry.loop = true
    var ctx_a := _configured_art(base, [active_entry])
    var a_player: AnimationPlayer = (ctx_a[1] as ArtComponent)._clips[0]["player"]

    var door_entry := _make_clip(AnimClipData.Role.DOOR, clip_path, "anim")
    var ctx_b := _configured_art(base, [door_entry])
    var b_player: AnimationPlayer = (ctx_b[1] as ArtComponent)._clips[0]["player"]

    TestHelper.assert_eq(
        a_player.get_animation("anim").loop_mode,
        Animation.LOOP_LINEAR,
        "ACTIVE instance keeps looping after another instance uses the same cached clip"
    )
    TestHelper.assert_eq(
        b_player.get_animation("anim").loop_mode,
        Animation.LOOP_NONE,
        "DOOR instance is non-looping without mutating the ACTIVE instance's animation"
    )

    BatchLoader._cache.erase(base)
    BatchLoader._cache.erase(clip_path)
    ctx_a[0].free()
    ctx_b[0].free()
