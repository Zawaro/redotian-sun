## ADDED Requirements

### Requirement: Powered-down structures do not fire
CombatComponent SHALL NOT acquire targets or fire while its entity's `PowerComponent` reports offline (`is_online == false`). The check SHALL be a local gate in the combat processing tick and SHALL NOT interfere with existing target-state handling: the current target SHALL be retained so power restoration resumes engagement. Entities without a `PowerComponent` SHALL be unaffected.

#### Scenario: Offline structure holds fire
- **WHEN** a `powered = true` defense structure is offline and an enemy is in range
- **THEN** CombatComponent fires no weapon and issues no approach move

#### Scenario: Power restoration resumes engagement
- **WHEN** the structure comes back online while a target is still set
- **THEN** CombatComponent resumes normal range/cooldown evaluation against that target

#### Scenario: Units without PowerComponent unaffected
- **WHEN** a combat entity has no `PowerComponent`
- **THEN** firing behavior is identical to the pre-change behavior
