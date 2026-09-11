extends Node

# Weapon fire SFX wiring — every [Weapon] Report= value from references/rules.ini
# must be authored on its WeaponData resource, and every report id must resolve
# to a committed AudioData under games/ts/audio/. The reference itself is not
# committed (references/ is gitignored), so the expected mapping is frozen here.

const WEAPONS_DIR: String = "res://games/ts/weapons/"
const AUDIO_DIR: String = "res://games/ts/audio/"

var _am: Node = null


func _ready() -> void:
    if has_node("/root/AudioManager"):
        _am = get_node("/root/AudioManager")


## Weapon file stem -> Report= value from references/rules.ini. Empty means the
## reference assigns no fire report (Grenade, Bomb, 75mm).
const EXPECTED_REPORTS: Dictionary = {
    "120mm": "120MMF",
    "120mmx": "120MMX9",
    "155mm": "120MMF",
    "75mm": "",
    "90mm": "120MMF",
    "assaultcannon": "TSGUN4",
    "bazooka": "RKETINF1",
    "bikemissile": "MISL1",
    "bomb": "",
    "chemlauncher": "ICBM1",
    "cycannon": "SCRIN5B",
    "dragon": "MISL1",
    "empulseweapon": "PLSECAN2",
    "fiendshard": "FIEND2",
    "fireballlauncher": "FLAMTNK1",
    "grenade": "",
    "harpyclaw": "CYGUN1",
    "heal": "HEALER1",
    "hellfire": "ORCAMIS1",
    "hovermissile": "HOVRMIS1",
    "jumpcannon": "JUMPJET1",
    "laserfire": "OBELRAY1",
    "laserfire2": "LASTUR1",
    "ltrail": "BIGGGUN1",
    "m1carbine": "INFGUN3",
    "mammothtusk": "MISL1",
    "mechrailgun": "RAILUSE5",
    "minigun": "INFGUN3,GOSTGUN1,SLVKGUN1",
    "multicluster": "MISL1",
    "multilauncher": "SAMSHOT1",
    "pistola": "GUN18",
    "proton": "SCRIN5B",
    "raidercannon": "CHAINGN1",
    "redeye2": "SAMSHOT1",
    "repairbullet": "REPAIR11",
    "rpgtower": "GLNCH4",
    "slimeattack": "VICER1",
    "sniper": "SILENCER",
    "soniczap": "SONIC4",
    "suicidebomb": "HUNTER2",
    "vulcan": "CHAINGN1",
    "vulcan2": "TSGUN4",
    "vulcan3": "CYGUN1",
    "vulcantower": "CHAINGN1",
}


func _load_weapon(stem: String) -> WeaponData:
    var path := WEAPONS_DIR + stem + ".tres"
    if not ResourceLoader.exists(path):
        return null
    return load(path) as WeaponData


func test_every_weapon_report_matches_reference():
    for stem in EXPECTED_REPORTS:
        var weapon := _load_weapon(stem)
        TestHelper.assert_true(weapon != null, "weapon resource exists: %s" % stem)
        if weapon:
            TestHelper.assert_eq(
                weapon.sound_report, EXPECTED_REPORTS[stem], "%s sound_report" % stem
            )


func test_every_report_id_resolves_to_audio_data():
    TestHelper.assert_true(_am != null, "AudioManager autoload present")
    if not _am:
        return
    _am.register_data_set(AUDIO_DIR)
    var checked := 0
    for stem in EXPECTED_REPORTS:
        var weapon := _load_weapon(stem)
        if not weapon:
            continue
        for token in weapon.sound_report.split(",", false):
            var id := token.strip_edges()
            if id.is_empty():
                continue
            checked += 1
            TestHelper.assert_true(
                _am.get_audio_data(id) != null, "%s report id %s has AudioData" % [stem, id]
            )
    TestHelper.assert_true(checked > 0, "at least one weapon report id was checked")
