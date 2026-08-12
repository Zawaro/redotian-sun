## Context

`EntityFactory.create_entity()` already calls `EntityData.validate()` and logs
the results, and `CombatComponent` already exposes
`validate(data: EntityData) -> PackedStringArray`. But that per-component method
is dead code — nothing calls it — and no other component validates its data. The
`entity-validation` spec calls for component-level validation, TODO logging for
unimplemented properties, and graceful degradation. This change finishes that
capability by generalizing the pattern `CombatComponent` and `EntityData` already
use.

Constraints:
- GDScript has no exceptions/try-catch, so "if a component fails to configure,
  log and skip" can only mean *validate before configuring* — we cannot catch a
  runtime crash mid-configure.
- Components are added conditionally by the factory (e.g. `MovementController`
  only when `speed > 0`), so most "skip setup" cases are already handled by the
  add-guards; the value here is the diagnostic warning.
- Tests use the no-framework runner; validation that returns a `PackedStringArray`
  is directly assertable, whereas `push_warning()` output is not.

## Goals / Non-Goals

**Goals:**
- Every component that has meaningful data requirements owns a
  `validate(data) -> PackedStringArray` returning human-readable warnings.
- `EntityFactory` runs each component's `validate()` at creation time and logs
  the messages via `push_warning()`, isolating each component.
- `SpecialAbilityComponent` logs a `TODO:` for each enabled-but-unimplemented
  ability flag.

**Non-Goals:**
- Changing which components are added, or their configuration/wiring behavior.
- Wiring `data.speed` into `MovementController.move_speed` (movement tuning is a
  separate concern; this change only warns on invalid speed).
- Implementing any special ability, power grid, or combat resolution.

## Decisions

**Validation lives in `validate(data) -> PackedStringArray`, not inline in
`configure()`.** The spec says components validate "when configured"; we satisfy
this by having the factory call `validate()` immediately before `configure()` for
each child. Returning strings (rather than calling `push_warning()` inside
`configure()`) reuses the exact signature `CombatComponent`/`EntityData` already
have, keeps `configure()` focused on setup, and makes validation unit-testable.
The factory is the single place that logs, matching how `EntityData.validate()`
is already handled. Alternative — inline `push_warning()` in each `configure()` —
was rejected because it is untestable and duplicates the logging site.

**Factory drives validation + logging in `_configure_components`.** For each
child, if it has a `validate` method, call it and `push_warning()` each returned
string; then call `configure()`. Looping per-child means one component's bad data
does not stop the others from being configured (graceful degradation within the
limits of GDScript).

**`FactoryComponent` known-type set.** Valid `factory` queue types are
`BuildingType`, `InfantryType`, `VehicleType`, `AircraftType` (the values present
in the data set and consumed by `ProductionManager`/`Sidebar`). `validate()`
warns when `factory` is non-empty and outside this set.

**`SpecialAbilityComponent` TODO logging.** None of the ability flags are
implemented, so `validate()` emits `"TODO: <ability> not implemented for '<id>'"`
for each flag that is `true`. This is the grep-able migration marker the spec
describes; the check iterates the flags so implemented abilities can be dropped
from the TODO list later.

## Risks / Trade-offs

- [Warning noise from TODO logging] → Only *enabled* ability flags warn, and only
  at entity creation, so noise scales with actual usage, not the whole schema.
- [`validate()` runs before `configure()`, so it reads `data`, not component
  state] → Intentional; every check the spec lists is a property of the source
  `EntityData`, so validating the data is equivalent and avoids ordering issues.
- [GDScript cannot catch a configure crash] → Documented; validation-before-
  configure catches the malformed-data cases the spec enumerates, which is the
  realistic failure mode.

## Open Questions

None.
