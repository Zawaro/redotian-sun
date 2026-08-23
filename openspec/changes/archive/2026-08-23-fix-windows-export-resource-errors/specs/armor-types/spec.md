## MODIFIED Requirements

### Requirement: Armor type validation
The system SHALL validate that every armor id referenced by data (warheads, entities) exists in the GlobalRules armor type registry.

#### Scenario: Warhead references unknown armor
- **WHEN** a WarheadData's multiplier dictionary references an armor id not in the registry
- **THEN** `validate()` reports an error for that warhead

#### Scenario: Entity references unknown armor
- **WHEN** damage is dealt to an entity whose `StatsComponent.armor` is not in the registry
- **THEN** damage SHALL be applied unmodified (full damage, multiplier 1.0) and the lookup SHALL not crash

#### Scenario: Warhead data uses legacy positional array
- **WHEN** a warhead `.tres` serializes `armor_damage_multipliers` as a positional array (`PackedFloat32Array([...])`) instead of a keyed dictionary
- **THEN** the file fails to load with a parse error and `validate()` cannot run, so the serialized form is rejected before it reaches validation