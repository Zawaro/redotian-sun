## MODIFIED Requirements

### Requirement: AudioManager autoload with dynamic .tres loader
The system SHALL provide an `AudioManager` autoload that registers data-set directories and recursively scans them for `.tres` resources, caching `AudioData` and `VoiceData` resources by their `id`. The scan SHALL mirror the `EntityFactory._scan_directory` pattern, and loading a directory SHALL be idempotent per path. A missing or unreadable directory SHALL produce a warning and return without error. The registered directories SHALL come from the active game's `data_sets` layer roots (the `audio/` subdirectory of each root), resolved via GameContext at select time.

#### Scenario: Scan loads all audio resources by id
- **WHEN** `AudioManager.register_data_set("res://games/ts/audio/")` is called
- **THEN** every `AudioData.tres` and `VoiceData.tres` under that directory is cached, keyed by its `id`

#### Scenario: Registering the same data set twice is idempotent
- **WHEN** `register_data_set` is called twice with the same path
- **THEN** the directory is scanned only once and cached resources are not duplicated

#### Scenario: Missing directory does not crash
- **WHEN** `register_data_set` is called with a non-existent path
- **THEN** the call logs a warning and returns without raising an error

### Requirement: Content .tres files
The system SHALL author `AudioData.tres` files under the active game's `audio/` data directory (`games/ts/audio/` for Tiberian Sun) for available audio files, and `VoiceData.tres` files for units with select/order voice sets, using the available audio library and `references/sound.ini` id mapping. A `default_bus_layout.tres` SHALL define the Master/Music/SFX/Voice buses.

#### Scenario: Content matches sound.ini ids
- **WHEN** content `AudioData.tres` files are scanned
- **THEN** each id matches a `references/sound.ini` `[SoundList]` name and resolves to an existing imported audio file

#### Scenario: Voice sets reference existing audio ids
- **WHEN** a `VoiceData.tres` event lists audio ids
- **THEN** each listed id resolves to a cached `AudioData`
