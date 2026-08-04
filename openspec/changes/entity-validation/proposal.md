## Why

The `entity-validation` capability specifies component-level validation, graceful
degradation, and TODO logging, but only `EntityData.validate()` and
`CombatComponent.validate()` exist today. The other components silently accept
malformed `EntityData` (a harvester with no dock, a building with a zero
foundation, an unknown factory queue type, unimplemented special-ability flags),
which produces confusing runtime behavior with no diagnostic. As the data set
grows (#23), un-validated data becomes harder to debug. This change finishes the
capability so bad data surfaces a clear warning at entity-creation time instead
of failing silently later.

## What Changes

- Standardize a `validate(data: EntityData) -> PackedStringArray` convention on
  components, reusing the pattern already established by `CombatComponent` and
  `EntityData`.
- Add `validate()` to `MovementController`, `FoundationComponent`,
  `FactoryComponent`, `TransportComponent`, and `SpecialAbilityComponent`.
- `SpecialAbilityComponent.validate()` emits a `TODO:` warning for each enabled
  ability flag, since none are implemented yet — grep for `TODO:` finds them all.
- `EntityFactory` calls each component's `validate()` at creation time and logs
  the returned messages via `push_warning()`, then configures the component. One
  bad component's data no longer prevents siblings from being configured.
- `PowerComponent` and `ArtComponent` are left as-is (data-only / already
  graceful).

## Capabilities

### New Capabilities
<!-- none — capability already exists -->

### Modified Capabilities
- `entity-validation`: sharpen the "Component-level validation" and "Graceful
  degradation" requirements with the concrete per-component checks, warning
  message formats, and the factory-driven logging flow.

## Impact

- Code: `scripts/entities/EntityFactory.gd`, `scripts/components/MovementController.gd`,
  `FoundationComponent.gd`, `FactoryComponent.gd`, `TransportComponent.gd`,
  `SpecialAbilityComponent.gd`.
- Tests: new `test/unit/test_entity_validation.gd`.
- No data migration; no public API removed. Purely additive diagnostics.
