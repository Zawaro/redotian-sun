## ADDED Requirements

### Requirement: Stacked sound loudness ceiling
The system SHALL guarantee that concurrent playback on any audio bus never exceeds a configured loudness ceiling, regardless of how many sounds — same or different ids — are stacked at once. To enforce this, `AudioManager` SHALL install bus effects at startup: a compressor and a hard limiter on the `Master` bus (compressor before limiter), a hard limiter on the `SFX` bus, and a compressor on the `Voice` bus. Effect setup SHALL be idempotent (never duplicating an effect on repeated startup), and the limiter/compressor parameters SHALL be configurable constants in `AudioManager` for playtesting.

#### Scenario: Master bus carries a compressor and hard limiter
- **WHEN** `AudioManager` finishes `_ready()`
- **THEN** the `Master` bus has an `AudioEffectCompressor` followed by an `AudioEffectHardLimiter` whose ceiling is set below 0 dB

#### Scenario: SFX and Voice buses carry loudness effects
- **WHEN** `AudioManager` finishes `_ready()`
- **THEN** the `SFX` bus has an `AudioEffectHardLimiter` and the `Voice` bus has an `AudioEffectCompressor`

#### Scenario: Bus effect setup does not duplicate on repeated ready
- **WHEN** `_ensure_buses` (or equivalent startup path) runs again on an already-initialized `AudioManager`
- **THEN** no bus gains a second copy of an effect it already has

### Requirement: Fire sound retrigger throttling
The system SHALL throttle repeat playback of the same sound id so that rapid-fire weapons — which fire up to 20+ shots per second per unit — cannot flood the mix with a dense wall of gunfire. `play_sound` SHALL skip starting a sound id that was played within the previous `RETRIGGER_INTERVAL_MS`, silently (no warning — throttling is normal operation). Skipped throttling SHALL apply per sound id (distinct ids are not throttled by each other), covers `play_voice` (which routes through `play_sound`), and the interval SHALL be a configurable constant in `AudioManager` for playtesting.

#### Scenario: Rapid same-id replays are skipped
- **WHEN** the same sound id is requested more than once within `RETRIGGER_INTERVAL_MS`
- **THEN** only the first request starts playback; subsequent requests are dropped silently

#### Scenario: Distinct ids are not throttled by each other
- **WHEN** different sound ids are requested within the same interval
- **THEN** each id starts playback normally

#### Scenario: Playback resumes after the interval elapses
- **WHEN** a sound id is requested after `RETRIGGER_INTERVAL_MS` has elapsed since its last play
- **THEN** playback starts normally

### Requirement: Concurrent stack bounding
The system SHALL bound concurrent playback so that stacked sounds — identical or different ids — never play louder than a single copy. At most `MAX_STACK_PER_ID` copies of any single id SHALL play concurrently; beyond that the oldest copy SHALL be stopped and released. Each active copy SHALL have its volume scaled by the total number of concurrent copies on its bus, so that N concurrent copies on a bus sum to roughly one copy's loudness (per-copy attenuation of `-20·log10(N)` dB). Scaling SHALL be scoped per bus (`SFX`, `Voice`, `Music` normalized independently) so voice playback remains audible over stacked weapon fire. This SHALL apply to both spatial and non-spatial players and to both `play_sound` and `play_voice` (which routes through `play_sound`).

#### Scenario: Concurrent copies capped per id
- **WHEN** more than `MAX_STACK_PER_ID` copies of the same id are requested at once
- **THEN** the oldest copy is stopped and released so active copies never exceed the cap

#### Scenario: Stacked identical copies scale down in volume
- **WHEN** N copies of the same id are playing concurrently on a bus
- **THEN** each copy's `volume_db` is reduced by `20·log10(N)` dB relative to its base volume

#### Scenario: Different ids on one bus share a loudness budget
- **WHEN** N different sound ids play concurrently on the same bus
- **THEN** each copy is scaled by the bus total (`-20·log10(N)` dB) so the stack never exceeds one copy's loudness

#### Scenario: Buses are normalized independently
- **WHEN** sounds play concurrently on the `SFX` bus while a single voice plays on the `Voice` bus
- **THEN** the SFX copies are scaled by the SFX bus count and the voice keeps its base volume (not buried by the SFX stack)

#### Scenario: Copy count recovers after playback ends
- **WHEN** a copy of an id finishes playing
- **THEN** the remaining copies on its bus are re-normalized to their new count and the finished copy is released
