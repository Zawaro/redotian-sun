## MODIFIED Requirements

### Requirement: Powered-down structures stop functioning
When a structure is offline (`is_online == false`), its gameplay subsystems SHALL stop: `CombatComponent` SHALL NOT acquire targets or fire; `RadarComponent.has_radar()` SHALL return `false`; `ArtComponent` SHALL pause every animation clip whose entry has `requires_power = true` regardless of role, and SHALL leave clips with `requires_power = false` playing. When the structure returns online, paused `ACTIVE` clips SHALL resume; paused event-driven one-shot clips SHALL NOT auto-resume and wait for their next trigger. Structures that are online SHALL behave exactly as before this change.

#### Scenario: Offline turret stops firing
- **WHEN** a `powered = true` defense structure goes offline while engaged
- **THEN** CombatComponent stops acquiring targets and fires no weapons, and resumes normal behavior when power is restored

#### Scenario: Offline radar reports offline
- **WHEN** a `powered = true` radar structure goes offline
- **THEN** `has_radar()` returns `false` and returns `true` again on recovery

#### Scenario: Offline power-required animations pause
- **WHEN** a `powered = true` structure with an animation clip whose `requires_power = true` goes offline
- **THEN** that clip pauses, and an `ACTIVE` clip resumes when the structure powers back up

#### Scenario: Offline non-power animations keep running
- **WHEN** a structure goes offline and one of its animation clips has `requires_power = false`
- **THEN** that clip keeps playing while any `requires_power = true` clips pause

#### Scenario: Offline one-shot clip does not auto-resume
- **WHEN** a playing one-shot clip whose `requires_power = true` is paused by a blackout and the structure powers back up
- **THEN** the clip stays paused until it is triggered again

#### Scenario: Combat entity without PowerComponent unaffected
- **WHEN** a combat entity has no `PowerComponent` (e.g., a tank)
- **THEN** its firing behavior is unchanged
