## ADDED Requirements

### Requirement: Component timers accumulate delta seconds

Gameplay component timers SHALL measure elapsed time by accumulating the per-tick `delta` (in seconds) provided by `_process`/`_physics_process`, rather than by counting ticks with an integer counter. This ensures delays are independent of frame rate and scale with game speed applied through `Engine.time_scale`.

#### Scenario: Delay depends on elapsed seconds, not tick count

- **WHEN** a timer's threshold is `T` seconds and the accumulated `delta` reaches `T`
- **THEN** the timed action fires, regardless of how many ticks the accumulation took

#### Scenario: Delay scales with game speed

- **WHEN** `Engine.time_scale` is increased so each tick reports a larger `delta`
- **THEN** the timer reaches its threshold in fewer wall-clock ticks, shortening the delay proportionally

### Requirement: Dock queue promotion delay is expressed in seconds

`DockHostComponent` SHALL delay promotion of the next queued docker by a configurable duration in seconds (`dock_wait_seconds`), accumulated from `delta`.

#### Scenario: Promotion waits the configured seconds

- **WHEN** the dock slot is free, a docker is queued, and less than `dock_wait_seconds` of accumulated `delta` has elapsed
- **THEN** no docker is promoted yet

#### Scenario: Promotion occurs once the configured seconds elapse

- **WHEN** the accumulated `delta` since the wait began reaches `dock_wait_seconds`
- **THEN** the first valid queued docker is promoted to current docker

### Requirement: Movement wait and repair timers are expressed in seconds

`MovementController` SHALL express its blocked-wait scatter/reroute timer and its path-repair re-check interval as seconds accumulated from `delta`.

#### Scenario: Blocked unit reroutes after the wait duration

- **WHEN** a unit has been in the WAIT state for longer than its wait threshold (in seconds)
- **THEN** it scatters nearby blockers and requests a new path to a free cell

#### Scenario: Path repair re-checks at a fixed second interval

- **WHEN** a moving unit has accumulated the repair interval (in seconds) of travel time
- **THEN** it re-checks whether the upcoming waypoint cell is occupied and repaths if so
