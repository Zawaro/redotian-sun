class_name TestHelper
# Minimal test assertions — no framework, no crashes on failure.
# Tests report through TestHelper only; the runner owns all output.
# Assertions are silent on success; failures accumulate in _errors.

static var _passed := 0
static var _failed := 0
static var _errors: Array[String] = []


static func assert_eq(got, expected, msg: String = "") -> void:
    if got == expected:
        _passed += 1
    else:
        _failed += 1
        var err := "expected %s, got %s" % [expected, got]
        if msg != "":
            err = msg + " — " + err
        _errors.append(err)


static func assert_true(value: bool, msg: String = "") -> void:
    if value:
        _passed += 1
    else:
        _failed += 1
        var err := "expected true" if msg == "" else msg
        _errors.append(err)


static func fail(msg: String) -> void:
    _failed += 1
    _errors.append(msg)


static func reset() -> void:
    _passed = 0
    _failed = 0
    _errors.clear()
