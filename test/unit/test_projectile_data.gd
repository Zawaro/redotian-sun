extends Node

# ProjectileData tests — schema defaults, .tres load/validation,
# and weapon → projectile reference resolvability.

const PROJECTILE_DIR := "res://games/ts/projectiles/"
const WEAPON_DIR := "res://games/ts/weapons/"

var _test_passed := 0
var _test_failed := 0


func _pass(msg: String) -> void:
    _test_passed += 1
    print("    PASS: " + msg)


func _fail(msg: String) -> void:
    _test_failed += 1
    print("    FAIL: " + msg)


func _load_dir(dir_path: String) -> Array[Resource]:
    var out: Array[Resource] = []
    var dir := DirAccess.open(dir_path)
    if not dir:
        return out
    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        if file_name.ends_with(".tres"):
            var res := load(dir_path + file_name)
            if res:
                out.append(res)
        file_name = dir.get_next()
    dir.list_dir_end()
    return out


func test_new_fields_default_to_noop():
    var p := ProjectileData.new()
    if not p.rotates_to_face and not p.is_ranged and p.tint_color == Color(1, 1, 1, 1):
        _pass("rotates_to_face/is_ranged default false, tint_color opaque white")
    else:
        _fail(
            (
                "defaults wrong: rotates=%s ranged=%s tint=%s"
                % [p.rotates_to_face, p.is_ranged, p.tint_color]
            )
        )


func test_empty_id_fails_validation():
    var p := ProjectileData.new()
    if not p.validate().is_empty():
        _pass("empty id reports a validation error")
    else:
        _fail("empty id should fail validation")


func test_all_projectiles_load_and_validate():
    var projectiles := _load_dir(PROJECTILE_DIR)
    if projectiles.is_empty():
        _fail("no projectile .tres files found")
        return
    var bad: PackedStringArray = []
    for res in projectiles:
        if not (res is ProjectileData):
            bad.append("%s is not ProjectileData" % res.resource_path)
            continue
        if not res.validate().is_empty():
            bad.append("%s failed validate()" % res.resource_path)
    if bad.is_empty():
        _pass("all %d projectile .tres load and validate" % projectiles.size())
    else:
        _fail("invalid projectiles: %s" % ", ".join(bad))


func test_weapon_projectile_references_resolve():
    var ids := {}
    for res in _load_dir(PROJECTILE_DIR):
        if res is ProjectileData and not res.id.is_empty():
            ids[res.id] = true
    var dangling: PackedStringArray = []
    for res in _load_dir(WEAPON_DIR):
        if not (res is WeaponData):
            continue
        if not res.projectile.is_empty() and not ids.has(res.projectile):
            dangling.append("%s -> '%s'" % [res.id, res.projectile])
    if dangling.is_empty():
        _pass("every weapon projectile reference resolves")
    else:
        _fail("dangling projectile references: %s" % ", ".join(dangling))
