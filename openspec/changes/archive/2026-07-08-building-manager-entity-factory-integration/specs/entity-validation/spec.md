## MODIFIED Requirements

### Requirement: EntityData validation on load
EntityData SHALL have a `validate() -> PackedStringArray` method that checks for required fields and returns error messages. Validation SHALL run when EntityData is loaded from .tres. When `buildable = true`, validation SHALL also check that `strength > 0` and `foundation != Vector2i(1,1)`.

#### Scenario: Valid entity data
- **WHEN** an EntityData with `id = "E1"`, `display_name = "Light Infantry"`, `strength = 125`, `cost = 120`, `owner = ["GDI", "Nod"]` is validated
- **THEN** `validate()` returns an empty array (no errors)

#### Scenario: Missing id
- **WHEN** an EntityData with `id = ""` is validated
- **THEN** `validate()` returns `["EntityData: id is empty"]`

#### Scenario: Zero strength for non-terrain
- **WHEN** an EntityData with `entity_type = VEHICLE`, `strength = 0` is validated
- **THEN** `validate()` returns `["BGGY: strength must be > 0"]`

#### Scenario: Negative cost
- **WHEN** an EntityData with `cost = -100` is validated
- **THEN** `validate()` returns `["E1: cost must be >= 0"]`

#### Scenario: Empty owner
- **WHEN** an EntityData with `owner = []` is validated
- **THEN** `validate()` returns `["E1: owner is empty"]`

#### Scenario: Buildable building with zero strength
- **WHEN** an EntityData with `buildable = true`, `entity_type = BUILDING`, `strength = 0` is validated
- **THEN** `validate()` returns a warning containing "strength must be > 0"

#### Scenario: Buildable building with default foundation
- **WHEN** an EntityData with `buildable = true`, `entity_type = BUILDING`, `foundation = Vector2i(1,1)` is validated
- **THEN** `validate()` returns a warning containing "foundation should be > 1x1 for buildable buildings"
