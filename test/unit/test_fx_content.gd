extends Node

# FX content tests — every FxData under games/ts/fx/ loads and validates, and
# the MVP wiring resolves: the Light Infantry weapon carries a muzzle effect and
# the small-arms warhead carries the "bullet hit" effect.

const FX_DIR: String = "res://games/ts/fx/"

var _minigun: WeaponData = null
var _sa: WarheadData = null


func _minigun_data() -> WeaponData:
    if _minigun == null:
        _minigun = load("res://games/ts/weapons/minigun.tres") as WeaponData
    return _minigun


func _sa_data() -> WarheadData:
    if _sa == null:
        _sa = load("res://games/ts/warheads/sa.tres") as WarheadData
    return _sa


func test_all_fx_resources_load_and_validate():
    var dir := DirAccess.open(FX_DIR)
    TestHelper.assert_true(dir != null, "fx content directory exists")
    if dir == null:
        return
    var count := 0
    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        if file_name.ends_with(".tres"):
            var resource := load(FX_DIR + file_name)
            TestHelper.assert_true(resource is FxData, "%s loads as FxData" % file_name)
            if resource is FxData:
                var effect := resource as FxData
                TestHelper.assert_eq(
                    effect.validate().size(), 0, "%s passes validation" % file_name
                )
                count += 1
        file_name = dir.get_next()
    dir.list_dir_end()
    TestHelper.assert_true(count >= 2, "the MVP muzzle and bullet-hit effects exist")


func test_light_infantry_weapon_has_muzzle_fx():
    var weapon := _minigun_data()
    TestHelper.assert_true(weapon != null, "Light Infantry weapon loads")
    TestHelper.assert_true(weapon.muzzle_fx != null, "Light Infantry weapon has a muzzle effect")
    var effect := weapon.muzzle_fx
    TestHelper.assert_eq(effect.kind, FxData.Kind.PARTICLES, "muzzle effect is a particle system")
    TestHelper.assert_true(effect.draw_material != null, "muzzle has a draw material")
    (
        TestHelper
        . assert_true(
            effect.draw_material.vertex_color_use_as_albedo,
            "draw material consumes the process material's color/alpha",
        )
    )


func test_small_arms_warhead_has_impact_fx():
    var warhead := _sa_data()
    TestHelper.assert_true(warhead != null, "SA warhead loads")
    TestHelper.assert_true(warhead.impact_fx != null, "SA warhead has an impact effect")
    TestHelper.assert_eq(
        warhead.impact_fx.kind, FxData.Kind.PARTICLES, "bullet hit is a particle system"
    )


func test_light_infantry_entity_weapon_is_equipped():
    var entity := load("res://games/ts/entities/infantry/gdi_light_infantry.tres") as EntityData
    TestHelper.assert_true(entity != null, "GDI Light Infantry data loads")
    TestHelper.assert_true(entity.weapons.size() > 0, "Light Infantry has a weapon")
    TestHelper.assert_true(
        entity.weapons[0].muzzle_fx != null, "the Light Infantry weapon has a muzzle effect"
    )


func test_light_infantry_muzzle_is_at_gun_height():
    # A body-mounted muzzle is entity origin + fire_offset; the entity origin is
    # at the unit's feet, so a zero offset puts the flash on the ground. The
    # authored FLH must lift it and stay within the unit's ~1 unit footprint.
    var weapon := _minigun_data()
    TestHelper.assert_true(weapon.fire_offset.y > 0.2, "muzzle offset clears the feet")
    TestHelper.assert_true(weapon.fire_offset.length() < 1.0, "muzzle offset stays near the unit")
    TestHelper.assert_true(weapon.fire_offset.z < 0.0, "muzzle sits in front of the body (-Z)")


func test_muzzle_particles_are_world_sized():
    var weapon := _minigun_data()
    var effect := weapon.muzzle_fx
    TestHelper.assert_eq(effect.kind, FxData.Kind.PARTICLES, "muzzle is a particle effect")
    TestHelper.assert_true(effect.quad_size > 0.0, "muzzle quad has a positive size")
    # A soldier is ~1 unit tall; sparks must be a small fraction of that, not a
    # metre-wide quad.
    TestHelper.assert_true(effect.quad_size <= 0.25, "muzzle quad is a small fraction of a unit")
    TestHelper.assert_true(effect.light_energy > 0.0, "muzzle emits a point light")


func test_muzzle_fire_is_muted():
    # Muzzle fire reads as a warm, desaturated flash rather than a saturated
    # primary, and lights the world only slightly. Saturation = 1 - min/max RGB.
    var effect := _minigun_data().muzzle_fx
    var tint: Color = effect.process_material.color
    var hi := maxf(tint.r, maxf(tint.g, tint.b))
    var lo := minf(tint.r, minf(tint.g, tint.b))
    TestHelper.assert_true(hi <= 0.0 or 1.0 - lo / hi <= 0.45, "muzzle fire colour is desaturated")
    TestHelper.assert_true(hi <= 0.95, "muzzle flash is not blown out")
    TestHelper.assert_true(
        effect.light_energy > 0.0 and effect.light_energy <= 1.0, "light is a hint, not a flood"
    )


func test_muzzle_is_a_tight_forward_streak():
    # Thin and long, not a soft puff: sparks stay in a tight cone, carry forward
    # for a few tenths of a metre over their short life, and draw thin.
    var effect := _minigun_data().muzzle_fx
    var pm := effect.process_material
    TestHelper.assert_true(pm.spread <= 15.0, "muzzle sparks stay in a tight cone")
    var reach: float = pm.initial_velocity_max * effect.lifetime
    TestHelper.assert_true(reach > 0.3 and reach <= 0.6, "streak carries ~0.5m forward")
    TestHelper.assert_true(effect.quad_size <= 0.1, "thin sparks, not a blob")


func test_impact_is_triangle_debris():
    # Small-arms impact: a flat spawner of small yellow/gray/brown triangle
    # shards, not a fire/explosion flash.
    var effect := _sa_data().impact_fx
    TestHelper.assert_eq(effect.kind, FxData.Kind.PARTICLES, "bullet hit is particles")
    TestHelper.assert_eq(
        effect.particle_shape, FxData.ParticleShape.TRIANGLE, "impact particles are triangles"
    )
    TestHelper.assert_true(effect.quad_size > 0.0 and effect.quad_size <= 0.2, "small shards")
    (
        TestHelper
        . assert_eq(
            effect.process_material.emission_shape,
            ParticleProcessMaterial.EMISSION_SHAPE_BOX,
            "spawns from a flat box standing in for a plane",
        )
    )
    (
        TestHelper
        . assert_true(
            absf(effect.process_material.emission_box_extents.y) < 0.0001,
            "the spawn volume is flat (plane), not a 3D box",
        )
    )
    # Footprint is a fraction of a cell (half-extents box -> 2x extents wide).
    var spawn_width: float = 2.0 * effect.process_material.emission_box_extents.x
    (
        TestHelper
        . assert_true(
            spawn_width > 0.5 * CellUtil.CELL_SIZE and spawn_width <= CellUtil.CELL_SIZE,
            "debris scatters across most of a cell, not one tight point",
        )
    )
    # The spawn window and per-shard life are separate: `spawn_duration` keeps
    # the emitter running while each shard dies `lifetime` after its own birth,
    # so the effect has to outlive the window plus that final life.
    var spawn_window: float = effect.spawn_duration
    if spawn_window <= 0.0:
        spawn_window = effect.lifetime * (1.0 - effect.explosiveness)
    TestHelper.assert_true(spawn_window > 0.05 and spawn_window <= 0.45, "spawner keeps emitting")
    TestHelper.assert_true(
        effect.lifetime > 0.05 and effect.lifetime <= 0.45,
        "each shard lives a fraction of a second"
    )
    TestHelper.assert_true(spawn_window > effect.lifetime, "spawning outlasts any single shard")
    var flush: float = maxf(effect.spawn_duration, effect.lifetime) + effect.lifetime
    (
        TestHelper
        . assert_true(
            FxSystem.resolve_duration(effect) >= flush,
            "effect outlives the spawn window plus the last shard",
        )
    )
    (
        TestHelper
        . assert_true(
            effect.process_material.color_initial_ramp != null,
            "debris colours come from a ramp (yellow/gray/brown)",
        )
    )
    TestHelper.assert_true(
        effect.draw_material.vertex_color_use_as_albedo, "particle colour reaches the pixels"
    )
    (
        TestHelper
        . assert_eq(
            effect.draw_material.cull_mode,
            BaseMaterial3D.CULL_DISABLED,
            "single-triangle shards disable culling so they never back-face away",
        )
    )
    (
        TestHelper
        . assert_eq(
            effect.draw_material.billboard_mode,
            BaseMaterial3D.BILLBOARD_PARTICLES,
            "particles billboard mode is what applies each shard's random rotation",
        )
    )
    (
        TestHelper
        . assert_true(
            effect.process_material.angle_min < effect.process_material.angle_max,
            "shard start rotation is random, not fixed",
        )
    )
    # Shards only drop if gravity out-runs the damping that is slowing them;
    # otherwise they hang in the air and the hit reads as floaty.
    (
        TestHelper
        . assert_true(
            absf(effect.process_material.gravity.y) > effect.process_material.damping_max,
            "debris is yanked down instead of hovering",
        )
    )
    TestHelper.assert_true(effect.light_energy <= 0.0, "no flash light on a bullet impact")
