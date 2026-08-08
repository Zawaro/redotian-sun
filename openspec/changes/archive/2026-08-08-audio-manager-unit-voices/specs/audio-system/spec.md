## ADDED Requirements

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
The system SHALL play a voice for a unit on two events: selection and order issue. On selection (`SelectionManager.add_entity`), the system SHALL play a random variant from the unit's `VoiceData.select` event, spatially at the unit position if configured. On order issue (`MouseHandler._try_execute_orders`), the system SHALL map the resolved `OrderResult.cursor` type to a voice event and play a random variant of that event. The mapping SHALL be: `MOVE` → `move`; `ATTACK`, `HARVEST`, `ENTER`, `DEPLOY` → `attack`; other cursor types SHALL play no order voice.

#### Scenario: Selecting a unit plays its select voice
- **WHEN** a unit with a `VoiceData` whose `select` event has variants is selected
- **THEN** one variant from `select` is played on the unit's bus at its position

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
The system SHALL play weapon fire sounds using `WeaponData.sound_report` (a comma-separated list of audio ids) at the `CombatComponent._fire_weapon` choke point, spatially at the firing unit. One id SHALL be chosen at random from the comma-separated list when the list has multiple entries. The system SHALL play a death/explosion sound from the `HealthComponent.health_zero` signal at the dying entity's position. Both SHALL honor the graceful-failure requirement when ids are missing.

#### Scenario: Weapon fire plays one report sound
- **WHEN** a weapon with `sound_report = "INFGUN3,GOSTGUN1"` fires
- **THEN** one of `INFGUN3` or `GOSTGUN1` plays at the firing unit's position

#### Scenario: Weapon with empty sound report is silent
- **WHEN** a weapon with an empty `sound_report` fires
- **THEN** no fire sound plays and no error is raised

#### Scenario: Death plays an explosion sound
- **WHEN** an entity's health reaches zero
- **THEN** a death/explosion sound plays at the entity's position

### Requirement: Content .tres files
The system SHALL author `AudioData.tres` files under `resources/audio/` for available audio files, and `VoiceData.tres` files for units with select/order voice sets, using the available audio library and `references/sound.ini` id mapping. A `default_bus_layout.tres` SHALL define the Master/Music/SFX/Voice buses.

#### Scenario: Content matches sound.ini ids
- **WHEN** content `AudioData.tres` files are scanned
- **THEN** each id matches a `references/sound.ini` `[SoundList]` name and resolves to an existing imported audio file

#### Scenario: Voice sets reference existing audio ids
- **WHEN** a `VoiceData.tres` event lists audio ids
- **THEN** each listed id resolves to a cached `AudioData`
