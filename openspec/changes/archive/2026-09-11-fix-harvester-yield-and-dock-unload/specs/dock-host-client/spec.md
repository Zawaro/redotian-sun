## ADDED Requirements

### Requirement: Active unload is never evicted
The dock host's `stale_timeout` SHALL bound only the approach and rotation phase of a dock sequence. While the current docker is actively unloading, the host SHALL NOT evict it for exceeding `stale_timeout`. The docker SHALL deposit its entire accepted cargo before the dock releases it; release SHALL occur only when cargo is empty, the cargo is rejected, or the docker is no longer valid.

#### Scenario: Full unload completes past the stale window
- **WHEN** a docked harvester with 28 bales of accepted cargo unloads at about 2.0 bales/s (about 14 s) with `stale_timeout = 5.0`
- **THEN** the dock SHALL NOT evict it mid-unload, no `dock_timeout` SHALL be emitted, and cargo SHALL reach 0 before `docker_undocked`

#### Scenario: Credits equal cargo bales times value
- **WHEN** the full load above completes
- **THEN** the refinery owner SHALL receive `28 x 25 = 700` credits and `TransportComponent.cargo` SHALL be empty

#### Scenario: Stuck docker is still evicted
- **WHEN** a docker occupies the dock and never begins or completes unloading within `stale_timeout`
- **THEN** the host SHALL still evict it and emit `dock_timeout`

#### Scenario: Rejected cargo still leaves
- **WHEN** a docker carrying an unaccepted resource category finishes the approach
- **THEN** the dock SHALL release it without depositing credits

### Requirement: Reference unload cadence
Unloading SHALL be incremental at approximately 2.0 bales per real second, using the project's 2x TS time base (30 logic ticks/second): ~15 TS ticks per bail (HarvesterDumpRate = .016 min) gives 30/15 = 2.0 bales/s, so a full 28-bale load deposits in about 14 seconds. Because the rate is per real second and applied via `delta`, the host frame rate SHALL NOT change that duration.

#### Scenario: Unload rate default
- **WHEN** a `DockUnloadComponent` runs with default settings
- **THEN** its unload rate SHALL be approximately 2.0 bales/s

#### Scenario: Incremental deposit
- **WHEN** a full harvester unloads with an economy manager attached
- **THEN** credits SHALL be added gradually across the unload rather than all at once on docking
