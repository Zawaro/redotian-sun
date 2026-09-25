extends Node

# FxSystem unit tests — node build per kind, deterministic one-shot lifetime,
# invalid no-op, and fog-of-war spawn gating / freeze / resume.
#
# The runner calls test methods synchronously, so `_process` is driven manually
# and effects are freed by the test instead of waiting for a frame.

var _ef: Node = null
var _ss: Node = null
var _rules: GlobalRules = null
var _real_rules: GlobalRules = null
var _real_cell_count: int = 0

## Far cell no revealer covers, so shroud gating is deterministic in tests.
const FAR := Vector3(5000, 0, 5000)


func _fx() -> Node:
    return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("FxSystem")


func _inject_rules(shroud: bool) -> void:
    _real_rules = _ef.get_global_rules() as GlobalRules
    _rules = GlobalRules.new()
    _rules.shroud_enabled = shroud
    _rules.fog_of_war = false
    _ef.set_global_rules(_rules)
    # Simulate a ready shroud grid so fog gating is active; without one,
    # FxSystem deliberately does not gate.
    _real_cell_count = _ss._cell_count
    _ss._cell_count = 100


func _restore_rules() -> void:
    if _real_rules != null:
        _ef.set_global_rules(_real_rules)
    _real_rules = null
    _rules = null
    _ss._cell_count = _real_cell_count


func _reset_fx() -> void:
    var fx := _fx()
    if fx == null:
        return
    for entry in fx._active:
        var node: Node3D = entry["node"]
        if is_instance_valid(node):
            node.free()
    fx._active.clear()


func _sprite_fx(id: String = "Hit", frames: int = 1, duration: float = 0.0) -> FxData:
    var fx := FxData.new()
    fx.id = id
    fx.kind = FxData.Kind.SPRITE
    var sheet := SpriteFrames.new()
    if not sheet.has_animation("default"):
        sheet.add_animation("default")
    sheet.set_animation_speed("default", 1.0)
    for i in frames:
        sheet.add_frame("default", PlaceholderTexture2D.new(), 0.1)
    fx.sprite_frames = sheet
    fx.duration = duration
    return fx


func _particle_fx(id: String = "Muzzle", lifetime: float = 0.5) -> FxData:
    var fx := FxData.new()
    fx.id = id
    fx.kind = FxData.Kind.PARTICLES
    fx.process_material = ParticleProcessMaterial.new()
    fx.draw_material = StandardMaterial3D.new()
    fx.lifetime = lifetime
    return fx


func test_play_sprite_builds_animated_sprite():
    _inject_rules(false)
    _reset_fx()
    var fx := _sprite_fx("Hit", 3)
    var node: Node3D = _fx().play(fx, Transform3D(Basis(), FAR))
    TestHelper.assert_true(node is AnimatedSprite3D, "sprite effect builds an AnimatedSprite3D")
    TestHelper.assert_true(is_instance_valid(node), "sprite node is in the tree")
    TestHelper.assert_eq(node.sprite_frames, fx.sprite_frames, "sprite frames assigned")
    TestHelper.assert_eq(node.layers, 1, "effect renders on layer 1")
    TestHelper.assert_eq(
        node.texture_filter, BaseMaterial3D.TEXTURE_FILTER_NEAREST, "nearest filtering"
    )
    TestHelper.assert_true(node.visible, "spawned effect is visible")
    _reset_fx()
    _restore_rules()


func test_play_particles_builds_gpu_emitter():
    _inject_rules(false)
    _reset_fx()
    var fx := _particle_fx("Muzzle", 0.7)
    var node: Node3D = _fx().play(fx, Transform3D(Basis(), FAR))
    TestHelper.assert_true(node is GPUParticles3D, "particle effect builds a GPUParticles3D")
    TestHelper.assert_eq(node.process_material, fx.process_material, "process material assigned")
    TestHelper.assert_true(node.draw_pass_1 is QuadMesh, "draw pass is a quad")
    TestHelper.assert_eq(node.amount, fx.amount, "amount applied")
    TestHelper.assert_true(absf(node.lifetime - 0.7) < 0.0001, "lifetime applied")
    TestHelper.assert_eq(node.one_shot, true, "particle effect is one-shot")
    TestHelper.assert_eq(node.emitting, true, "particle effect emits on spawn")
    TestHelper.assert_eq(node.layers, 1, "effect renders on layer 1")
    _reset_fx()
    _restore_rules()


func test_particles_quad_sized_from_fx():
    _inject_rules(false)
    _reset_fx()
    var fx := _particle_fx("Muzzle", 0.5)
    fx.quad_size = 0.15
    var node: Node3D = _fx().play(fx, Transform3D(Basis(), FAR))
    var quad := node.draw_pass_1 as QuadMesh
    TestHelper.assert_true(quad != null, "draw pass is a quad")
    TestHelper.assert_true(absf(quad.size.x - 0.15) < 0.0001, "quad width from quad_size")
    TestHelper.assert_true(absf(quad.size.y - 0.15) < 0.0001, "quad height from quad_size")
    _reset_fx()
    _restore_rules()


func test_particles_quad_has_small_default():
    _inject_rules(false)
    _reset_fx()
    var fx := _particle_fx("Muzzle", 0.5)
    var node: Node3D = _fx().play(fx, Transform3D(Basis(), FAR))
    var quad := node.draw_pass_1 as QuadMesh
    TestHelper.assert_true(
        quad.size.x < 0.5, "default quad is authored in world units, not a metre-wide quad"
    )
    _reset_fx()
    _restore_rules()


func test_triangle_particle_shape_builds_triangle_mesh():
    _inject_rules(false)
    _reset_fx()
    var fx := _particle_fx("Hit", 0.5)
    fx.quad_size = 0.09
    fx.particle_shape = FxData.ParticleShape.TRIANGLE
    var node: Node3D = _fx().play(fx, Transform3D(Basis(), FAR))
    var mesh: Mesh = node.draw_pass_1
    TestHelper.assert_true(mesh is ArrayMesh, "triangle shape builds an ArrayMesh, not a quad")
    TestHelper.assert_eq(mesh.get_surface_count(), 1, "one triangle surface")
    TestHelper.assert_true(mesh.surface_get_material(0) is StandardMaterial3D, "draw material set")
    _reset_fx()
    _restore_rules()


func _find_light(node: Node) -> OmniLight3D:
    for child in node.get_children():
        if child is OmniLight3D:
            return child as OmniLight3D
    return null


func test_light_added_when_energy_positive():
    _inject_rules(false)
    _reset_fx()
    var fx := _particle_fx("Muzzle", 0.5)
    fx.light_energy = 3.0
    fx.light_color = Color(1.0, 0.8, 0.4)
    fx.light_range = 2.0
    var node: Node3D = _fx().play(fx, Transform3D(Basis(), FAR))
    var light := _find_light(node)
    TestHelper.assert_true(light != null, "positive light energy adds an OmniLight3D")
    TestHelper.assert_true(absf(light.light_energy - 3.0) < 0.0001, "light energy applied")
    TestHelper.assert_eq(light.light_color, fx.light_color, "light colour applied")
    TestHelper.assert_true(absf(light.omni_range - 2.0) < 0.0001, "light range applied")
    TestHelper.assert_eq(light.shadow_enabled, false, "one-shot flash casts no shadows")
    var kept := light
    _reset_fx()
    TestHelper.assert_true(not is_instance_valid(kept), "light is freed with its effect")
    _restore_rules()


func test_light_tracks_effect_transform():
    # The light is a child of the effect node, so it must sit at the same
    # (muzzle) transform as the flash, not at the entity origin.
    _inject_rules(false)
    _reset_fx()
    var fx := _particle_fx("Muzzle", 0.5)
    fx.light_energy = 1.5
    var origin := Vector3(3, 2, 1)
    var node: Node3D = _fx().play(fx, Transform3D(Basis(), origin))
    var light := _find_light(node)
    TestHelper.assert_true(light != null, "light exists")
    (
        TestHelper
        . assert_true(
            light.global_position.distance_to(origin) < 0.001,
            "light sits at the effect transform (the muzzle), not the entity origin",
        )
    )
    _reset_fx()
    _restore_rules()


func test_no_light_by_default():
    _inject_rules(false)
    _reset_fx()
    var fx := _particle_fx("Muzzle", 0.5)
    var node: Node3D = _fx().play(fx, Transform3D(Basis(), FAR))
    TestHelper.assert_true(_find_light(node) == null, "default energy adds no light")
    _reset_fx()
    _restore_rules()


func test_play_invalid_returns_null():
    _inject_rules(false)
    _reset_fx()
    TestHelper.assert_eq(_fx().play(null, Transform3D()), null, "null effect returns null")
    var invalid := FxData.new()
    invalid.kind = FxData.Kind.SPRITE
    TestHelper.assert_eq(_fx().play(invalid, Transform3D()), null, "invalid effect returns null")
    TestHelper.assert_eq(_fx().active_count(), 0, "no effect was tracked")
    _reset_fx()
    _restore_rules()


func test_auto_free_after_duration():
    _inject_rules(false)
    _reset_fx()
    var fx := _sprite_fx("Short", 1, 0.2)
    var node: Node3D = _fx().play(fx, Transform3D(Basis(), FAR))
    _fx()._process(0.1)
    TestHelper.assert_true(not node.is_queued_for_deletion(), "effect alive before duration")
    _fx()._process(0.15)
    TestHelper.assert_true(node.is_queued_for_deletion(), "effect queued for free after duration")
    TestHelper.assert_eq(_fx().active_count(), 0, "expired effect untracked")
    _reset_fx()
    _restore_rules()


func test_duration_resolves_from_sprite_frames():
    var fx := _sprite_fx("Clip", 4)
    (
        TestHelper
        . assert_true(
            absf(FxSystem.resolve_duration(fx) - 0.4) < 0.0001,
            "sprite duration is the total frame time (4 x 0.1s)",
        )
    )


func test_duration_uses_particle_lifetime():
    var fx := _particle_fx("Poof", 1.5)
    (
        TestHelper
        . assert_true(
            absf(FxSystem.resolve_duration(fx) - 3.0) < 0.0001,
            "particle duration is the 2x lifetime ceiling for the emission tail",
        )
    )


func test_spawn_duration_decouples_window_from_life():
    var fx := _particle_fx("Poof", 0.075)
    fx.spawn_duration = 0.3
    (
        TestHelper
        . assert_true(
            absf(FxSystem.resolve_duration(fx) - 0.375) < 0.0001,
            "duration is the spawn window plus the last particle's life",
        )
    )
    _inject_rules(false)
    _reset_fx()
    var node: Node3D = _fx().play(fx, Transform3D(Basis(), FAR))
    var emitter := node as GPUParticles3D
    TestHelper.assert_true(emitter != null, "play builds a GPUParticles3D")
    TestHelper.assert_eq(emitter.one_shot, false, "a window longer than one life keeps emitting")
    _reset_fx()
    _restore_rules()


func test_explicit_duration_wins():
    var fx := _sprite_fx("Explicit", 4, 0.25)
    (
        TestHelper
        . assert_true(
            absf(FxSystem.resolve_duration(fx) - 0.25) < 0.0001,
            "explicit duration overrides derivation",
        )
    )


func test_spawn_skipped_under_shroud():
    _inject_rules(true)
    _reset_fx()
    var fx := _sprite_fx("Hidden", 1, 0.2)
    var node: Node3D = _fx().play(fx, Transform3D(Basis(), FAR))
    TestHelper.assert_eq(node, null, "effect does not spawn in shrouded territory")
    TestHelper.assert_eq(_fx().active_count(), 0, "no effect tracked for a gated spawn")
    _reset_fx()
    _restore_rules()


func test_spawn_allowed_when_grid_not_ready():
    _inject_rules(true)
    _ss._cell_count = 0
    _reset_fx()
    var node: Node3D = _fx().play(_sprite_fx("PreBoot", 1, 0.2), Transform3D(Basis(), FAR))
    TestHelper.assert_true(node != null, "effect spawns when no shroud grid exists yet")
    _reset_fx()
    _restore_rules()


func test_frozen_effect_freed_after_max_age():
    _inject_rules(false)
    _reset_fx()
    var node: Node3D = _fx().play(_sprite_fx("Frozen", 1, 0.2), Transform3D(Basis(), FAR))
    _rules.shroud_enabled = true
    _fx()._on_shroud_changed(PackedInt32Array())
    TestHelper.assert_true(not node.visible, "effect frozen by shroud")
    _fx()._process(FxSystem.MAX_FROZEN_AGE + 0.1)
    TestHelper.assert_true(
        node.is_queued_for_deletion(), "a never-revealed frozen effect is freed at the age cap"
    )
    TestHelper.assert_eq(_fx().active_count(), 0, "frozen effect untracked after the cap")
    _reset_fx()
    _restore_rules()


func test_freeze_and_resume_on_shroud_change():
    _inject_rules(false)
    _reset_fx()
    var fx := _sprite_fx("Toggle", 2, 0.3)
    var node: Node3D = _fx().play(fx, Transform3D(Basis(), FAR))
    TestHelper.assert_true(node.visible, "effect visible while the cell is visible")
    TestHelper.assert_true(absf(node.speed_scale - 1.0) < 0.0001, "effect runs while visible")

    _rules.shroud_enabled = true
    _fx()._on_shroud_changed(PackedInt32Array())
    TestHelper.assert_true(not node.visible, "effect hidden when its cell is shrouded")
    TestHelper.assert_true(
        absf(node.speed_scale) < 0.0001, "effect frozen when its cell is shrouded"
    )

    _rules.shroud_enabled = false
    _fx()._on_shroud_changed(PackedInt32Array())
    TestHelper.assert_true(node.visible, "effect revealed again")
    TestHelper.assert_true(absf(node.speed_scale - 1.0) < 0.0001, "effect resumes when revealed")
    _reset_fx()
    _restore_rules()
