extends Node

# Building data invariant: every sidebar-buildable structure must set
# adjacent > 0. Regression (#352): defenses (sam, laser turret, obelisk, ...)
# shipped without the field, so EntityData's default 0 meant "no requirement"
# and they could be placed anywhere. Construction yards are the only intended
# adjacent <= 0 case and are not buildable, so they pass via the other branch.

const STRUCTURES_ROOT := "res://resources/entities/structures/"
const EXPECTED_MIN_SCAN := 100
const SPOT_CHECKS := [
    "res://resources/entities/structures/nod/nod_sam.tres",
    "res://resources/entities/structures/nod/nod_laser_turret.tres",
    "res://resources/entities/structures/gdi/gdi_construction_yard.tres",
]

## Vanilla Tiberian Sun RULES.INI Adjacent= values (Vinifera
## Tiberian-Sun-INIs). Same gap semantics as EntityData.adjacent for N > 0.
## A buildable structure whose legacy_id is missing here fails the fidelity
## test so new data authors must check RULES.INI.
const VANILLA_ADJACENT := {
    "GAPILE": 2,
    "NAHAND": 2,
    "PROC": 2,
    "GAWEAP": 2,
    "NAWEAP": 2,
    "GARADR": 2,
    "NARADR": 2,
    "GAHPAD": 2,
    "NAHPAD": 2,
    "GATECH": 2,
    "NATECH": 2,
    "GAPLUG": 2,
    "GAFIRE": 2,
    "GASILO": 2,
    "GADEPT": 2,
    "NAOBEL": 2,
    "NAPULS": 2,
    "GAPOWR": 2,
    "NAPOWR": 2,
    "NAAPWR": 2,
    "GACTWR": 3,
    "NATMPL": 3,
    "NASAM": 4,
    "NALASR": 4,
    "GASAND": 4,
    "NAWALL": 4,
    "GAGATE_A": 4,
    "GAGATE_B": 4,
    "NAGATE_A": 4,
    "NAGATE_B": 4,
}


func _is_adjacency_compliant(data: EntityData) -> bool:
    return not data.buildable or data.adjacent > 0


func _collect_structure_paths() -> PackedStringArray:
    var paths: PackedStringArray = []
    var root := DirAccess.open(STRUCTURES_ROOT)
    if not root:
        TestHelper.fail("structures dir not found: " + STRUCTURES_ROOT)
        return paths
    root.list_dir_begin()
    var subdir := root.get_next()
    while subdir != "":
        if root.current_is_dir() and not subdir.begins_with("."):
            var sub := DirAccess.open(STRUCTURES_ROOT + subdir)
            if sub:
                sub.list_dir_begin()
                var file := sub.get_next()
                while file != "":
                    if file.ends_with(".tres"):
                        paths.append(STRUCTURES_ROOT + subdir + "/" + file)
                    file = sub.get_next()
                sub.list_dir_end()
        subdir = root.get_next()
    root.list_dir_end()
    return paths


func test_buildable_structures_require_adjacency() -> void:
    var paths := _collect_structure_paths()
    TestHelper.assert_true(
        paths.size() >= EXPECTED_MIN_SCAN,
        "sanity: scanned %d structure files, expected >= %d" % [paths.size(), EXPECTED_MIN_SCAN]
    )
    for spot in SPOT_CHECKS:
        TestHelper.assert_true(paths.has(spot), "sanity: scan covers " + spot)
    var violations: Array[String] = []
    for path in paths:
        var data := load(path) as EntityData
        if data == null:
            violations.append(path + " (not an EntityData)")
        elif not _is_adjacency_compliant(data):
            violations.append(
                "%s (buildable=%s, adjacent=%d)" % [path, data.buildable, data.adjacent]
            )
    TestHelper.assert_true(
        violations.is_empty(),
        "all buildable structures enforce adjacency: " + ", ".join(violations)
    )


func test_predicate_rejects_buildable_without_adjacency() -> void:
    # Prove the invariant actually detects the shipped defect shape.
    var bad := EntityData.new()
    bad.buildable = true
    bad.adjacent = 0
    TestHelper.assert_true(
        not _is_adjacency_compliant(bad), "buildable with adjacent=0 must be rejected"
    )


func test_predicate_allows_non_buildable_without_adjacency() -> void:
    # The construction-yard pattern: not buildable, adjacent left at default 0.
    var yard := (
        load("res://resources/entities/structures/gdi/gdi_construction_yard.tres") as EntityData
    )
    if yard == null:
        TestHelper.fail("gdi_construction_yard.tres did not load")
        return
    TestHelper.assert_true(
        _is_adjacency_compliant(yard),
        "non-buildable construction yard with adjacent=%d is compliant" % yard.adjacent
    )


func test_predicate_accepts_buildable_with_adjacency() -> void:
    var good := EntityData.new()
    good.buildable = true
    good.adjacent = 2
    TestHelper.assert_true(_is_adjacency_compliant(good), "buildable with adjacent=2 is compliant")


func test_adjacent_values_match_vanilla_rules_ini() -> void:
    var checked := 0
    var mismatches: Array[String] = []
    for path in _collect_structure_paths():
        var data := load(path) as EntityData
        if data == null or not data.buildable:
            continue
        var legacy: String = data.legacy_id
        if not VANILLA_ADJACENT.has(legacy):
            mismatches.append("%s (legacy_id %s missing from VANILLA_ADJACENT)" % [path, legacy])
            continue
        checked += 1
        var expected: int = VANILLA_ADJACENT[legacy]
        if data.adjacent != expected:
            mismatches.append(
                (
                    "%s (legacy_id %s, adjacent=%d, vanilla=%d)"
                    % [path, legacy, data.adjacent, expected]
                )
            )
    TestHelper.assert_true(
        checked >= VANILLA_ADJACENT.size(),
        (
            "sanity: checked %d buildable structures, expected >= %d"
            % [checked, VANILLA_ADJACENT.size()]
        )
    )
    TestHelper.assert_true(
        mismatches.is_empty(), "adjacent values match vanilla RULES.INI: " + ", ".join(mismatches)
    )
