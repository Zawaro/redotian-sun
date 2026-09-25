extends Node

# WeaponData FX field tests — muzzle_fx default and assignment.


func test_muzzle_fx_default_and_assignment():
    var weapon := WeaponData.new()
    TestHelper.assert_eq(weapon.muzzle_fx, null, "muzzle_fx defaults to null")
    var effect := FxData.new()
    effect.id = "MuzzleSmall"
    effect.kind = FxData.Kind.SPRITE
    effect.sprite_frames = SpriteFrames.new()
    weapon.muzzle_fx = effect
    TestHelper.assert_eq(weapon.muzzle_fx, effect, "muzzle_fx accepts an assigned FxData")
