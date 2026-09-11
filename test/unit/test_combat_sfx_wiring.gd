extends Node

# Combat SFX data wiring — warhead impact reports and entity death reports are
# derived from references/rules.ini (warhead AnimList / entity Explosion=) via
# art.ini animation Report= values. The reference is gitignored, so the expected
# values are frozen here and every referenced id must resolve to a committed
# AudioData under games/ts/audio/.

const WARHEADS_DIR: String = "res://games/ts/warheads/"
const ENTITIES_DIR: String = "res://games/ts/entities/"
const AUDIO_DIR: String = "res://games/ts/audio/"
const DEFAULT_DEATH: String = "EXPNEW09,EXPNEW11,EXPNEW12,EXPNEW14,EXPNEW15"

## Warheads with a non-empty impact report derived from rules.ini AnimList -> art.ini Report=.
const EXPECTED_IMPACT: Dictionary = {
    "ap": "EXPNEW14",
    "artyhe": "EXPNEW13,EXPNEW15,EXPNEW12,EXPNEW09",
    "he": "EXPNEW13,EXPNEW15,EXPNEW12,EXPNEW09",
    "ionwh": "EXPNEW13,EXPNEW15,EXPNEW12,EXPNEW09",
    "orcaap": "EXPNEW14",
    "orcahe": "EXPNEW12,EXPNEW09",
    "plasmawh": "EXPNEW12,EXPNEW09",
    "rpg": "EXPNEW14",
    "samwh": "EXPNEW13",
    "tankogas": "EXPNEW05,EXPNEW06,EXPNEW07,EXPNEW09,EXPNEW10",
}
## Warheads whose impact animation carries no Report= (silent impact).
const EMPTY_IMPACT: PackedStringArray = [
    "sa",
    "hollowpoint",
    "fire",
    "gas",
    "mechanical",
    "organic",
    "railshot",
    "railshot2",
    "shard",
    "slimer",
    "sonicwarhead",
    "super",
]

var _am: Node = null


func _ready() -> void:
    if has_node("/root/AudioManager"):
        _am = get_node("/root/AudioManager")


func _load_warhead(stem: String) -> WarheadData:
    var path := WARHEADS_DIR + stem + ".tres"
    if not ResourceLoader.exists(path):
        return null
    return load(path) as WarheadData


func test_impact_reports_match_reference():
    for stem in EXPECTED_IMPACT:
        var wh := _load_warhead(stem)
        TestHelper.assert_true(wh != null, "warhead exists: %s" % stem)
        if wh:
            TestHelper.assert_eq(wh.sound_impact, EXPECTED_IMPACT[stem], "%s sound_impact" % stem)
    for stem in EMPTY_IMPACT:
        var wh := _load_warhead(stem)
        TestHelper.assert_true(wh != null, "warhead exists: %s" % stem)
        if wh:
            TestHelper.assert_eq(wh.sound_impact, "", "%s impact is silent" % stem)


func test_representative_death_reports_match_reference():
    var cases: Dictionary = {
        "res://games/ts/entities/vehicles/gdi_titan.tres": DEFAULT_DEATH,
        "res://games/ts/entities/vehicles/gdi_wolverine.tres": DEFAULT_DEATH,
        "res://games/ts/entities/vehicles/gdi_mammoth_tank.tres": DEFAULT_DEATH,
        "res://games/ts/entities/structures/gdi/gdi_power_plant.tres": DEFAULT_DEATH,
        "res://games/ts/entities/structures/gdi/gdi_sam_upgrade.tres": "EXPNEW09",
        "res://games/ts/entities/structures/nod/nod_obelisk_of_light.tres": DEFAULT_DEATH,
    }
    for path in cases:
        var data := load(path) as EntityData
        TestHelper.assert_true(data != null, "entity loads: %s" % path)
        if data:
            TestHelper.assert_eq(data.sound_die, cases[path], "%s sound_die" % path)


func test_all_referenced_report_ids_resolve():
    TestHelper.assert_true(_am != null, "AudioManager autoload present")
    if not _am:
        return
    _am.register_data_set(AUDIO_DIR)
    var checked := 0
    for path in _collect_paths(ENTITIES_DIR):
        var data := load(path) as EntityData
        if data == null:
            continue
        for token in data.sound_die.split(",", false):
            var id := token.strip_edges()
            if id.is_empty():
                continue
            checked += 1
            TestHelper.assert_true(
                _am.get_audio_data(id) != null, "%s death id %s resolves" % [path, id]
            )
    for stem in EXPECTED_IMPACT:
        var wh := _load_warhead(stem)
        if not wh:
            continue
        for token in wh.sound_impact.split(",", false):
            var id := token.strip_edges()
            if id.is_empty():
                continue
            checked += 1
            TestHelper.assert_true(
                _am.get_audio_data(id) != null, "%s impact id %s resolves" % [stem, id]
            )
    TestHelper.assert_true(checked > 0, "at least one report id was checked")


## Recursively collect every .tres path under a directory.
func _collect_paths(root: String) -> PackedStringArray:
    var out := PackedStringArray()
    _walk(root, out)
    return out


func _walk(dir_path: String, out: PackedStringArray) -> void:
    var dir := DirAccess.open(dir_path)
    if not dir:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        var full := dir_path + name
        if dir.current_is_dir():
            if not name.begins_with("."):
                _walk(full + "/", out)
        elif name.ends_with(".tres"):
            out.append(full)
        name = dir.get_next()
    dir.list_dir_end()
