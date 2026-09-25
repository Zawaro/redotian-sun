extends Node

# FxData unit tests — defaults, validation, and animated-texture support.


func _sprite_frames(animation: String = "shine", frame_count: int = 1) -> SpriteFrames:
    var frames := SpriteFrames.new()
    if not frames.has_animation(animation):
        frames.add_animation(animation)
    for i in frame_count:
        frames.add_frame(animation, PlaceholderTexture2D.new(), 0.1)
    return frames


func test_sprite_effect_defaults():
    var effect := FxData.new()
    effect.id = "Hit"
    effect.kind = FxData.Kind.SPRITE
    effect.sprite_frames = _sprite_frames()
    TestHelper.assert_true(effect.sprite_frames != null, "sprite frames assigned")
    TestHelper.assert_eq(effect.process_material, null, "particle fields default to null")
    TestHelper.assert_eq(effect.duration, 0.0, "duration defaults to derived")
    TestHelper.assert_true(effect.pixel_size > 0.0, "pixel_size has a positive default")


func test_particle_effect_defaults():
    var effect := FxData.new()
    effect.id = "Muzzle"
    effect.kind = FxData.Kind.PARTICLES
    effect.process_material = ParticleProcessMaterial.new()
    TestHelper.assert_true(effect.process_material != null, "process material assigned")
    TestHelper.assert_eq(effect.sprite_frames, null, "sprite fields default to null")
    TestHelper.assert_eq(effect.amount, 16, "amount default")
    TestHelper.assert_true(effect.lifetime > 0.0, "lifetime has a positive default")
    TestHelper.assert_eq(effect.local_coords, true, "particles default to local coords")


func test_validate_empty_id_fails():
    var effect := FxData.new()
    effect.kind = FxData.Kind.SPRITE
    effect.sprite_frames = _sprite_frames()
    var errors := effect.validate()
    TestHelper.assert_true(not errors.is_empty(), "empty id fails validation")


func test_validate_sprite_without_frames_fails():
    var effect := FxData.new()
    effect.id = "NoFrames"
    effect.kind = FxData.Kind.SPRITE
    var errors := effect.validate()
    TestHelper.assert_true(not errors.is_empty(), "sprite effect without frames fails")


func test_validate_particles_without_process_material_fails():
    var effect := FxData.new()
    effect.id = "NoProcess"
    effect.kind = FxData.Kind.PARTICLES
    var errors := effect.validate()
    TestHelper.assert_true(not errors.is_empty(), "particle effect without process material fails")


func test_validate_valid_effect_passes():
    var sprite := FxData.new()
    sprite.id = "ValidSprite"
    sprite.kind = FxData.Kind.SPRITE
    sprite.sprite_frames = _sprite_frames()
    TestHelper.assert_eq(sprite.validate().size(), 0, "valid sprite passes validation")

    var particles := FxData.new()
    particles.id = "ValidParticles"
    particles.kind = FxData.Kind.PARTICLES
    particles.process_material = ParticleProcessMaterial.new()
    TestHelper.assert_eq(particles.validate().size(), 0, "valid particle effect passes validation")


func test_sprite_frames_support_multiple_frames():
    var effect := FxData.new()
    effect.id = "Sheet"
    effect.kind = FxData.Kind.SPRITE
    effect.sprite_frames = _sprite_frames("default", 4)
    TestHelper.assert_eq(
        effect.sprite_frames.get_frame_count("default"), 4, "frame sequence stored"
    )
