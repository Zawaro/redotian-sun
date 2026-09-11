extends Node

# EntityData resource field tests — sound_die default and round-trip.


func test_sound_die_default_and_round_trip():
    var data := EntityData.new()
    TestHelper.assert_eq(data.sound_die, "", "sound_die defaults empty")
    data.sound_die = "EXPNEW01,EXPNEW05"
    TestHelper.assert_eq(data.sound_die, "EXPNEW01,EXPNEW05", "sound_die round-trips comma list")


func test_sound_die_independent_of_voice_data():
    var data := EntityData.new()
    data.sound_die = "EXPNEW01"
    TestHelper.assert_true(data.voice_data == null, "sound_die does not require a voice set")
