## 1. Component validation methods

- [x] 1.1 Add `validate(data) -> PackedStringArray` to `MovementController` (warn on `speed <= 0`)
- [x] 1.2 Add `validate(data) -> PackedStringArray` to `FoundationComponent` (warn on `foundation == Vector2i(0, 0)`)
- [x] 1.3 Add `validate(data) -> PackedStringArray` to `FactoryComponent` (warn on unknown `factory` queue type)
- [x] 1.4 Add `validate(data) -> PackedStringArray` to `TransportComponent` (warn on `harvester` with empty `dock`)
- [x] 1.5 Add `validate(data) -> PackedStringArray` to `SpecialAbilityComponent` (TODO per enabled ability flag)

## 2. Factory integration

- [x] 2.1 In `EntityFactory._configure_components`, call each child's `validate(data)` and `push_warning()` each returned message before configuring
- [x] 2.2 Ensure the per-child loop isolates components so one warning does not stop the others

## 3. Tests & quality gate

- [x] 3.1 Add `test/unit/test_entity_validation.gd` covering each component's `validate()` (valid and invalid cases)
- [x] 3.2 Run `gdformat` + `gdlint`; fix formatting/lint
- [x] 3.3 Run headless test suite; confirm `N passed, 0 failed`
