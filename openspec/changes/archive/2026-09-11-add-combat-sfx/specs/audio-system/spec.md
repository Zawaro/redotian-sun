## ADDED Requirements

### Requirement: Warhead impact sounds
On every damaging hit, the system SHALL play the victim's warhead impact report, read from `WarheadData.sound_impact` (a comma-separated list of audio ids), at the victim's position through `AudioManager.play_random`. The impact report SHALL use random selection with graceful failure: one id SHALL be chosen at random from the entries that resolve to a cached `AudioData`; unknown ids SHALL log a warning and be excluded; an empty `sound_impact` or a list with no known ids SHALL play nothing. Damage whose `damage_type` does not resolve to a `WarheadData` (for example vehicle crush or drowning) SHALL be silent. Impact playback SHALL NOT require the victim to have a `VoiceComponent`.

#### Scenario: Hit plays the warhead impact report
- **WHEN** a projectile or hitscan shot dealing warhead "HE" damages a victim and HE.sound_impact = "EXPNEW06"
- **THEN** "EXPNEW06" plays at the victim's position

#### Scenario: Impact picks one report at random
- **WHEN** a warhead with sound_impact = "EXPNEW06,EXPNEW10" damages a victim
- **THEN** exactly one of EXPNEW06 or EXPNEW10 plays at the victim's position

#### Scenario: Empty impact report is silent
- **WHEN** a warhead with an empty sound_impact damages a victim
- **THEN** no impact sound plays and no error is raised

#### Scenario: Unknown impact id warns and is skipped
- **WHEN** a warhead with sound_impact = "NO_SUCH_ID,EXPNEW10" damages a victim
- **THEN** a warning is logged and EXPNEW10 plays

#### Scenario: Non-warhead damage is silent
- **WHEN** an entity takes damage whose damage_type is not a registered warhead id
- **THEN** no impact sound plays and gameplay continues normally

### Requirement: Unvoiced destruction sounds
When an entity dies, the system SHALL play the entity's `VoiceData.die` set when a `VoiceComponent` with a non-empty die event exists; otherwise it SHALL play `EntityData.sound_die` (a comma-separated list of audio ids) through `AudioManager.play_random` at the entity's position; when neither exists it SHALL play nothing. `sound_die` SHALL use random selection among known ids with the same graceful-failure behavior as warhead impacts. `sound_die` SHALL be independent of `VoiceData`: an entity may define both, in which case the die voice takes precedence and the death sound does not play. This fulfils the previously deferred requirement that explosion/effect SFX for unvoiced entities be assigned.

#### Scenario: Unvoiced building plays its death sound
- **WHEN** a building with no VoiceComponent and sound_die = "EXPNEW09,EXPNEW11" reaches zero health
- **THEN** exactly one of EXPNEW09 or EXPNEW11 plays at the building's position

#### Scenario: Die voice takes precedence over sound_die
- **WHEN** an entity with both a non-empty VoiceData.die and sound_die reaches zero health
- **THEN** the die voice plays and the death sound is not played

#### Scenario: Entity with neither is silent
- **WHEN** an entity with no VoiceComponent and empty sound_die reaches zero health
- **THEN** no death sound plays and no error is raised

#### Scenario: Missing death-sound id warns
- **WHEN** an entity with sound_die = "NO_SUCH_ID" reaches zero health and no id resolves
- **THEN** a warning is logged, no sound plays, and the entity still frees normally
