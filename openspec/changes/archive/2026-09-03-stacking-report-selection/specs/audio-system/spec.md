## MODIFIED Requirements

### Requirement: Weapon fire and death sounds
The system SHALL play weapon fire sounds using `WeaponData.sound_report` (a comma-separated list of audio ids) at the `CombatComponent._fire_weapon` choke point, spatially at the firing unit. When the list has multiple entries, the system SHALL select the report by stacking depth: entries SHALL be considered in list order and the first entry whose current live copy count is below the rotation threshold SHALL play; ids that do not resolve to a cached `AudioData` SHALL be skipped with a warning; when every entry is at or above the rotation threshold, the last entry SHALL play. On death (`HealthComponent.health_zero`), the system SHALL play the unit's `VoiceData.die` set when one exists; entities without a die voice set play nothing. Explosion/effect SFX for unvoiced entities SHALL be assigned in a future issue. Both SHALL honor the graceful-failure requirement when ids are missing.

#### Scenario: Weapon fire plays the first entry when unstacked
- **WHEN** a weapon with `sound_report = "INFGUN3,GOSTGUN1"` fires while fewer than the rotation threshold of `INFGUN3` copies are live
- **THEN** `INFGUN3` plays at the firing unit's position and no `GOSTGUN1` player spawns

#### Scenario: Stacked fire rotates to later entries
- **WHEN** a weapon with `sound_report = "INFGUN3,GOSTGUN1"` fires while `INFGUN3` already has the rotation threshold of live copies
- **THEN** `GOSTGUN1` plays instead of `INFGUN3`

#### Scenario: All entries saturated plays the last entry
- **WHEN** a weapon with `sound_report = "INFGUN3,GOSTGUN1"` fires while both ids are at or above the rotation threshold
- **THEN** `GOSTGUN1` plays (the last entry)

#### Scenario: Unknown report id is skipped
- **WHEN** a weapon fires with `sound_report = "NO_SUCH_ID,GOSTGUN1"` where `NO_SUCH_ID` has no cached `AudioData`
- **THEN** a warning is raised and `GOSTGUN1` plays

#### Scenario: Weapon with empty sound report is silent
- **WHEN** a weapon with an empty `sound_report` fires
- **THEN** no fire sound plays and no error is raised

#### Scenario: Death plays the unit's die voice set
- **WHEN** an entity with a non-empty `VoiceData.die` reaches zero health
- **THEN** a random die variant is played; entities without die voices play nothing
