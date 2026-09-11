## ADDED Requirements

### Requirement: RadarSystem autoload aggregates per-player radar availability

The system SHALL provide a `RadarSystem` autoload singleton that maintains a registry of all `RadarComponent` nodes present in the scene tree. For each registered component, `RadarSystem` SHALL resolve the owning player via the entity's `StatsComponent.player_id`. A player SHALL be considered radar-available when at least one registered `RadarComponent` owned by that player reports `has_radar() == true`. Registration SHALL be driven by scene-tree `node_added`/`node_removed` signals so that radar structures reach the system through every spawn path (player placement, map-load starting bases, MCV deploy) and leave it on free or destruction.

#### Scenario: Register on placement
- **WHEN** a building with a `RadarComponent` (`radar = true`) is placed by a player
- **THEN** `RadarSystem.player_has_radar(owner_id)` returns true

#### Scenario: Unregister on destruction or sale
- **WHEN** the last radar-available structure owned by a player is destroyed or sold
- **THEN** `RadarSystem.player_has_radar(owner_id)` returns false

#### Scenario: Per-player isolation
- **WHEN** player 0 owns an online radar and player 1 owns none
- **THEN** `player_has_radar(0)` is true and `player_has_radar(1)` is false

#### Scenario: Entity without RadarComponent is ignored
- **WHEN** an entity without a `RadarComponent` is added or removed
- **THEN** `RadarSystem` availability results are unchanged

### Requirement: RadarComponent reports and signals effective state

`RadarComponent` SHALL expose `has_radar() -> bool`, returning true only when the component's `radar` data flag is set AND the owning entity is not powered down (`PowerComponent.is_online == false`); an entity without a `PowerComponent` SHALL be treated as powered. `RadarComponent` SHALL emit `radar_state_changed(is_active: bool)` when its effective state flips, including flips driven by power changes (via the sibling `PowerComponent.power_state_changed` signal), and SHALL NOT emit when the state does not change.

#### Scenario: Powered-down radar reports offline
- **WHEN** a `powered = true` radar structure goes offline
- **THEN** `has_radar()` returns false, `radar_state_changed(false)` is emitted once, and both reverse on recovery

#### Scenario: Radar without power component stays available
- **WHEN** a `radar = true` entity has no `PowerComponent`
- **THEN** `has_radar()` returns true and no spurious `radar_state_changed` fires

#### Scenario: No capability reports false
- **WHEN** a `RadarComponent` has `radar = false`
- **THEN** `has_radar()` returns false regardless of power state

### Requirement: Radar availability change signal

`RadarSystem` SHALL emit `radar_availability_changed(player_id: int)` when a player's availability flips, and SHALL NOT emit when a registry change or component state change does not alter that player's availability.

#### Scenario: Gaining radar emits once
- **WHEN** a player with no radar finishes placing their first online radar structure
- **THEN** `radar_availability_changed(player_id)` emits exactly once

#### Scenario: Losing radar emits once
- **WHEN** a player's last online radar structure is destroyed
- **THEN** `radar_availability_changed(player_id)` emits exactly once

#### Scenario: No-op change stays silent
- **WHEN** a non-radar entity is added or removed, or a radar entity is added for a player that already has radar
- **THEN** `radar_availability_changed` does not emit

### Requirement: Debug radar override

`RadarSystem` SHALL expose a `force_online: bool` override (default false). While `force_online` is true, `player_has_radar(player_id)` SHALL return true for every player regardless of registered components, so debug builds can exercise radar-dependent UI without owning a radar structure. Toggling `force_online` SHALL update availability results immediately.

#### Scenario: Override forces availability
- **WHEN** `RadarSystem.force_online` is true and a player owns no radar structure
- **THEN** `player_has_radar(player_id)` returns true

#### Scenario: Override off restores computed availability
- **WHEN** `force_online` is set back to false
- **THEN** `player_has_radar(player_id)` returns to the computed result from registered components
