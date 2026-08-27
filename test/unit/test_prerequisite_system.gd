extends Node

# PrerequisiteSystem unit tests — Nod advanced power plant availability (#167)
# TS reference: rules.ini [NAAPWR] Prerequisite=NAWEAP (Nod war factory).
# The plant must stay locked until the war factory chain is built — owning
# only a construction yard (fresh MCV deploy) is not enough.

var _pm: Node = null
var _ps: Node = null


func _get_ps() -> Node:
    if _ps == null:
        # The runner never adds this suite to the tree, so resolve the
        # autoload through an injected sibling instead of /root.
        _ps = _pm.get_node_or_null("/root/PrerequisiteSystem")
    if _ps == null:
        TestHelper.fail("PrerequisiteSystem not reachable")
    return _ps


func _data(entity_id: String) -> EntityData:
    var data: EntityData = EntityFactory.get_entity_data(entity_id)
    if data == null:
        TestHelper.fail("EntityFactory has no data for %s" % entity_id)
    return data


func test_naapwr_data_requires_war_factory():
    var naapwr := _data("NOD_ADVANCED_POWER_PLANT")
    if naapwr == null:
        return
    TestHelper.assert_true(
        "NOD_WAR_FACTORY" in naapwr.prerequisite,
        "NAAPWR prerequisite must include NOD_WAR_FACTORY per TS rules.ini"
    )


func test_naapwr_locked_with_yard_only():
    var ps := _get_ps()
    var naapwr := _data("NOD_ADVANCED_POWER_PLANT")
    var power_plant := _data("NOD_POWER_PLANT")
    var yard := _data("NOD_CONSTRUCTION_YARD")
    if ps == null or naapwr == null or power_plant == null or yard == null:
        return
    # MCV just deployed: only a construction yard exists.
    ps.register_building(201, yard)
    # Sanity: the setup is a playable state — basic power plant is buildable.
    TestHelper.assert_true(
        ps.can_build(201, power_plant), "yard-only state must allow the basic Nod power plant"
    )
    # Regression #167: advanced plant must NOT be buildable yet.
    TestHelper.assert_true(
        not ps.can_build(201, naapwr), "NAAPWR must stay locked with only a construction yard"
    )


func test_naapwr_available_after_war_factory():
    var ps := _get_ps()
    var naapwr := _data("NOD_ADVANCED_POWER_PLANT")
    var yard := _data("NOD_CONSTRUCTION_YARD")
    var war_factory := _data("NOD_WAR_FACTORY")
    if ps == null or naapwr == null or yard == null or war_factory == null:
        return
    ps.register_building(202, yard)
    ps.register_building(202, war_factory)
    TestHelper.assert_true(
        ps.can_build(202, naapwr), "NAAPWR must become available once the war factory exists"
    )


func test_naapwr_locked_before_any_building():
    var ps := _get_ps()
    var naapwr := _data("NOD_ADVANCED_POWER_PLANT")
    if ps == null or naapwr == null:
        return
    TestHelper.assert_true(
        not ps.can_build(203, naapwr), "NAAPWR must be locked before the MCV is deployed"
    )
