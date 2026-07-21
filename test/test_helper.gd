class_name TestHelper
# Minimal test assertions — no framework, no crashes on failure

static var _passed := 0
static var _failed := 0
static var _errors: Array[String] = []


static func assert_eq(got, expected, msg: String = "") -> void:
    if got == expected:
        _passed += 1
        print("    PASS")
    else:
        _failed += 1
        var err := "expected %s, got %s" % [expected, got]
        if msg != "":
            err = msg + " — " + err
        _errors.append(err)
        print("    FAIL: " + err)


static func assert_true(value: bool, msg: String = "") -> void:
    if value:
        _passed += 1
        print("    PASS")
    else:
        _failed += 1
        var err := "expected true" if msg == "" else msg
        _errors.append(err)
        print("    FAIL: " + err)


static func reset() -> void:
    _passed = 0
    _failed = 0
    _errors.clear()
