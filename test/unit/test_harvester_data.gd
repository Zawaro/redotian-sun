extends Node

## Harvester cargo capacity must match the original Tiberian Sun rules.ini.
## Reference: TS RULES.INI [HARV] Storage=28 (Vinifera-Developers/Tiberian-Sun-INIs
## archive of the shipped rules.ini). One entry covers both GDI and Nod — the
## "20-28 loads" seen in the field is the same 28-bale hold filled with tiberium
## types worth different credits, not a per-type capacity.
const TS_RULES_INI_HARV_STORAGE: int = 28


func test_gdi_harvester_storage_matches_ts_rules_ini():
    var data := load("res://games/ts/entities/vehicles/gdi_harvester.tres") as EntityData
    TestHelper.assert_true(data != null, "GDI harvester data loads")
    if data == null:
        return
    TestHelper.assert_true(data.harvester, "GDI harvester is flagged as harvester")
    TestHelper.assert_eq(data.storage, TS_RULES_INI_HARV_STORAGE, "GDI harvester capacity")


func test_nod_harvester_storage_matches_ts_rules_ini():
    var data := load("res://games/ts/entities/vehicles/nod_harvester.tres") as EntityData
    TestHelper.assert_true(data != null, "Nod harvester data loads")
    if data == null:
        return
    TestHelper.assert_true(data.harvester, "Nod harvester is flagged as harvester")
    TestHelper.assert_eq(data.storage, TS_RULES_INI_HARV_STORAGE, "Nod harvester capacity")


func test_docked_variants_carry_no_capacity_override():
    # Docked states map to TS [HORV] ("harvester without back"), which defines
    # no Storage flag in rules.ini — the .tres must not introduce one.
    for path: String in [
        "res://games/ts/entities/vehicles/gdi_harvester_docked.tres",
        "res://games/ts/entities/vehicles/nod_harvester_docked.tres",
    ]:
        var data := load(path) as EntityData
        TestHelper.assert_true(data != null, "%s loads" % path)
        if data == null:
            continue
        TestHelper.assert_eq(data.storage, 0, "%s leaves storage at the schema default" % path)
