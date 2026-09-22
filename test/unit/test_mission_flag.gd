extends Node

# GameContext flag parsing — `--mission` is extracted like `--game` but must not
# greedily match the other flag. Pure statics, so no singleton state is touched.

const GAME_CONTEXT_SCRIPT: GDScript = preload("res://scripts/core/GameContext.gd")
const MISSION_BOOT_SCRIPT: GDScript = preload("res://scripts/maps/MissionBoot.gd")


func test_mission_flag_extracted() -> void:
    (
        TestHelper
        . assert_eq(
            GAME_CONTEXT_SCRIPT.extract_mission_id(PackedStringArray(["--mission", "gdi01"])),
            "gdi01",
            "--mission value is extracted",
        )
    )


func test_mission_flag_absent_is_empty() -> void:
    (
        TestHelper
        . assert_eq(
            GAME_CONTEXT_SCRIPT.extract_mission_id(PackedStringArray(["--game", "ts"])),
            "",
            "absent --mission yields empty",
        )
    )
    (
        TestHelper
        . assert_eq(
            GAME_CONTEXT_SCRIPT.extract_mission_id(PackedStringArray()),
            "",
            "empty args yields empty",
        )
    )


func test_trailing_mission_flag_is_empty() -> void:
    (
        TestHelper
        . assert_eq(
            GAME_CONTEXT_SCRIPT.extract_mission_id(PackedStringArray(["--mission"])),
            "",
            "trailing --mission with no value yields empty",
        )
    )
    (
        TestHelper
        . assert_eq(
            GAME_CONTEXT_SCRIPT.extract_mission_id(
                PackedStringArray(["--game", "ts", "--mission"])
            ),
            "",
            "trailing --mission after other flags yields empty",
        )
    )


func test_mission_extractor_ignores_game_flag() -> void:
    (
        TestHelper
        . assert_eq(
            GAME_CONTEXT_SCRIPT.extract_mission_id(PackedStringArray(["--game", "ts"])),
            "",
            "--game is not matched by the mission extractor",
        )
    )


func test_game_flag_extractor_still_works() -> void:
    (
        TestHelper
        . assert_eq(
            GAME_CONTEXT_SCRIPT.extract_flag_id(PackedStringArray(["--game", "ts"])),
            "ts",
            "--game extraction unchanged",
        )
    )
    (
        TestHelper
        . assert_eq(
            GAME_CONTEXT_SCRIPT.extract_flag_id(PackedStringArray(["--game"])),
            "",
            "trailing --game yields empty",
        )
    )


func test_both_flags_extract_independently() -> void:
    var args := PackedStringArray(["--game", "ts", "--mission", "gdi01"])
    TestHelper.assert_eq(GAME_CONTEXT_SCRIPT.extract_flag_id(args), "ts", "--game still resolves")
    TestHelper.assert_eq(
        GAME_CONTEXT_SCRIPT.extract_mission_id(args), "gdi01", "--mission resolves alongside --game"
    )


func test_consume_mission_args_engine_args_win() -> void:
    var boot: Node = MISSION_BOOT_SCRIPT.new()
    (
        TestHelper
        . assert_eq(
            boot._consume_mission_args(
                PackedStringArray(["--mission", "gdi01"]), PackedStringArray(["--mission", "nod02"])
            ),
            "gdi01",
            "engine args win over user args",
        )
    )
    boot.free()


func test_consume_mission_args_falls_back_to_user_args() -> void:
    var boot: Node = MISSION_BOOT_SCRIPT.new()
    (
        TestHelper
        . assert_eq(
            boot._consume_mission_args(
                PackedStringArray(["--game", "ts"]), PackedStringArray(["--mission", "gdi01"])
            ),
            "gdi01",
            "user args are used when engine args carry no mission",
        )
    )
    boot.free()


func test_consume_mission_args_empty() -> void:
    var boot: Node = MISSION_BOOT_SCRIPT.new()
    (
        TestHelper
        . assert_eq(
            boot._consume_mission_args(PackedStringArray(), PackedStringArray()),
            "",
            "no args yields no mission",
        )
    )
    (
        TestHelper
        . assert_eq(
            boot._consume_mission_args(PackedStringArray(["--mission"]), PackedStringArray()),
            "",
            "trailing mission flag yields no mission",
        )
    )
    boot.free()
