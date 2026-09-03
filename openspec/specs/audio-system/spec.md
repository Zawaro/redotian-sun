### Requirement: AudioManager autoload with dynamic .tres loader
The system SHALL provide an `AudioManager` autoload that registers data-set directories and recursively scans them for `.tres` resources, caching `AudioData` and `VoiceData` resources by their `id`. The scan SHALL mirror the `EntityFactory._scan_directory` pattern, and loading a directory SHALL be idempotent per path. A missing or unreadable directory SHALL produce a warning and return without error.

#### Scenario: Scan loads all audio resources by id
- **WHEN** `AudioManager.register_data_set("res://resources/audio/")` is called
- **THEN** every `AudioData.tres` and `VoiceData.tres` under that directory is cached, keyed by its `id`

#### Scenario: Registering the same data set twice is idempotent
- **WHEN** `register_data_set` is called twice with the same path
- **THEN** the directory is scanned only once and cached resources are not duplicated

#### Scenario: Missing directory does not crash
- **WHEN** `register_data_set` is called with a non-existent path
- **THEN** the call logs a warning and returns without raising an error

### Requirement: Audio buses (Master, Music, SFX, Voice)
The system SHALL ensure four audio buses exist at startup: `Master`, `Music`, `SFX`, and `Voice`. `Master` is the default root bus; the other three are created as children when missing. Each `AudioData` SHALL specify which bus its stream plays on.

#### Scenario: Buses exist after AudioManager ready
- **WHEN** `AudioManager` finishes `_ready()`
- **THEN** buses `Master`, `Music`, `SFX`, and `Voice` exist in the audio server

#### Scenario: Sound plays on its declared bus
- **WHEN** `play_sound` is called with an `AudioData` whose bus is `Voice`
- **THEN** the resulting player is routed to the `Voice` bus

### Requirement: AudioData resource definition
The system SHALL provide an `AudioData` resource (`scripts/data/AudioData.gd`) with fields: `id` (unique sound id matching the `sound.ini` `[SoundList]` name, e.g. `INFGUN3`, `15-I000`), `path` (res:// path to the audio stream), `bus` (one of `Master`/`Music`/`SFX`/`Voice`), `priority` (int, default 10), `volume_db` (float), and `is_spatial` (bool, default true). Each sound file SHALL have one `AudioData.tres` under `resources/audio/`.

#### Scenario: AudioData exposes playback fields
- **WHEN** an `AudioData` resource is loaded from a `.tres` file
- **THEN** its id, path, bus, priority, volume_db, and is_spatial fields are populated from the file

#### Scenario: Default bus and spatiality
- **WHEN** an `AudioData` is created without explicit bus or spatial values
- **THEN** `bus` defaults to `SFX` and `is_spatial` defaults to true

### Requirement: VoiceData resource definition
The system SHALL provide a standalone `VoiceData` resource (`scripts/data/VoiceData.gd`) keyed by `id`, mapping voice events to lists of audio ids. Supported events SHALL be `select`, `move`, `attack`, `die`, and `feedback`. Each event list SHALL hold one or more audio ids representing interchangeable variants. `VoiceData` SHALL be a standalone catalog item that any entity can reference by id — it is not coupled to faction or player.

#### Scenario: VoiceData maps events to variant ids
- **WHEN** a `VoiceData` resource is loaded whose `select` event lists `["15-I000", "15-I002", "15-I008"]`
- **THEN** requesting a `select` voice offers one of those three ids

#### Scenario: Missing event returns no variants
- **WHEN** a `VoiceData` has no `die` entries and the `die` event is requested
- **THEN** playback is skipped without error

### Requirement: Event-driven voice playback
The system SHALL play a voice for a unit on two events: selection and order issue. On selection (`SelectionManager.add_entity`), the system SHALL play a random variant from the unit's `VoiceData.select` event. On order issue (`MouseHandler._try_execute_orders`), the system SHALL map the resolved `OrderResult.cursor` type to a voice event and play a random variant of that event. The mapping SHALL be: `MOVE` → `move`; `ATTACK`, `HARVEST`, `ENTER`, `DEPLOY` → `attack`; other cursor types SHALL play no order voice. Voices SHALL play as commander radio chatter, centered on the camera at full volume, regardless of the unit's world position.

#### Scenario: Selecting a unit plays its select voice
- **WHEN** a unit with a `VoiceData` whose `select` event has variants is selected
- **THEN** one variant from `select` is played on the unit's bus, centered on the camera

#### Scenario: Selecting a unit without voice data is silent
- **WHEN** a unit with no `VoiceData` or an empty `select` event is selected
- **THEN** no audio plays and no error is raised

#### Scenario: Issuing a move order plays the move voice
- **WHEN** a player issues a `MOVE` order to a unit with a `move` voice event
- **THEN** a random `move` variant is played

#### Scenario: Issuing an attack order plays the attack voice
- **WHEN** a player issues an `ATTACK`, `HARVEST`, `ENTER`, or `DEPLOY` order to a unit with an `attack` voice event
- **THEN** a random `attack` variant is played

#### Scenario: Orders that map to no voice event are silent
- **WHEN** an order resolves to a cursor type outside the defined mapping
- **THEN** no order voice plays and no error is raised

### Requirement: Graceful failure on missing audio
The system SHALL fail silently when a requested audio id cannot be resolved or loaded: it SHALL log a warning via `push_warning` and return without raising an error or disturbing gameplay. This SHALL apply to `play_sound`, `play_voice`, and weapon/effect sounds.

#### Scenario: Unknown sound id logs a warning
- **WHEN** `play_sound` is called with an id absent from the cache
- **THEN** the call logs a warning and returns without playing anything

#### Scenario: Missing audio file logs a warning
- **WHEN** an `AudioData` whose `path` fails to load is requested
- **THEN** the call logs a warning and returns without playing anything

#### Scenario: Unit without voice data does not crash
- **WHEN** a unit without voice data is selected or ordered
- **THEN** gameplay continues normally with no audio and no error

### Requirement: VoiceComponent per-entity holder
The system SHALL provide a `VoiceComponent` that holds a unit's `VoiceData` reference and exposes voice-event playback to the audio system. It SHALL be attached to an entity only when `EntityData.voice_data` is set, following the existing conditional component pattern (`EntityFactory._add_components`). Entities without voice data SHALL have no `VoiceComponent`.

#### Scenario: VoiceComponent attached only when voice data present
- **WHEN** an entity is created from `EntityData` with a `voice_data` reference
- **THEN** the entity has a `VoiceComponent` holding that reference

#### Scenario: VoiceComponent absent without voice data
- **WHEN** an entity is created from `EntityData` without `voice_data`
- **THEN** the entity has no `VoiceComponent`

### Requirement: Weapon fire and death sounds
The system SHALL play weapon fire sounds using `WeaponData.sound_report` (a comma-separated list of audio ids) at the `CombatComponent._fire_weapon` choke point, spatially at the firing unit. When the list has multiple entries, the system SHALL select the report by stacking depth: entries SHALL be considered in list order and the first entry whose current live copy count is below the rotation threshold SHALL play; ids that do not resolve to a cached `AudioData` SHALL be skipped with a warning; when every entry is at or above the rotation threshold, the last entry SHALL play. On death (`HealthComponent.health_zero`), the system SHALL play the unit's `VoiceData.die` set when one exists; entities without a die voice set play nothing. Explosion/effect SFX for unvoiced entities SHALL be assigned in a future issue. Both SHALL honor the graceful-failure requirement when ids are missing.

### Requirement: Viewport-aware spatial falloff
The system SHALL play spatial sounds (e.g. weapon fire) at full volume while the source is inside the camera's viewport, and attenuate with distance beyond the viewport edge. The spatial player's position SHALL be placed on the listener-relative bearing of the source at the source's distance past the viewport rectangle, using inverse-distance attenuation. Voices positioned at the camera are unaffected (distance zero → full volume). In headless/UI contexts without a camera, the sound SHALL play positionally at the source without falloff.

#### Scenario: On-screen sound plays at full volume
- **WHEN** a spatial sound source is inside the viewport footprint
- **THEN** its player is placed at the listener position (full volume, no panning)

#### Scenario: Off-screen sound attenuates with distance
- **WHEN** a spatial sound source is beyond the viewport edge
- **THEN** its player is placed past the listener along the source bearing, so the engine attenuates it by the off-screen distance

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

### Requirement: Content .tres files
The system SHALL author `AudioData.tres` files under `resources/audio/` for available audio files, and `VoiceData.tres` files for units with select/order voice sets, using the available audio library and `references/sound.ini` id mapping. A `default_bus_layout.tres` SHALL define the Master/Music/SFX/Voice buses.

#### Scenario: Content matches sound.ini ids
- **WHEN** content `AudioData.tres` files are scanned
- **THEN** each id matches a `references/sound.ini` `[SoundList]` name and resolves to an existing imported audio file

#### Scenario: Voice sets reference existing audio ids
- **WHEN** a `VoiceData.tres` event lists audio ids
- **THEN** each listed id resolves to a cached `AudioData`

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
