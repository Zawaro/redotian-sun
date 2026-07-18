## 1. ArtData Emission Fields

- [x] 1.1 Add `emission_enabled: bool = false`, `emission_color: Color = Color.BLACK`, `emission_energy_multiplier: float = 1.0` to `scripts/data/ArtData.gd`
- [x] 1.2 Add doc comments for the new emission fields (## style for editor tooltips)

## 2. ArtComponent Emission Application

- [x] 2.1 In `ArtComponent._load_model()`, after creating the StandardMaterial3D, apply emission fields from `art_data` when `emission_enabled` is true
- [x] 2.2 In `ArtComponent._add_placeholder()`, apply emission fields from `art_data` when `emission_enabled` is true

## 3. ResourceComponent Emission Integration

- [x] 3.1 Add `var _art_data: ArtData = null` to ResourceComponent
- [x] 3.2 In `ResourceComponent.configure()`, store `data.art_data` in `_art_data`
- [x] 3.3 In `ResourceComponent._ensure_visual_nodes()`, when creating the material cache entry, read emission from `_art_data` and apply to the StandardMaterial3D

## 4. Tiberium Art Data

- [x] 4.1 Create `resources/art/terrain/tiberium_crystal_art.tres` with: emission_enabled=true, emission_color=Color(0.2, 0.8, 0.2), emission_energy_multiplier=3.0
- [x] 4.2 Update `resources/entities/terrain/tiberium_crystal.tres` to reference `tiberium_crystal_art.tres` via art_data field

## 5. WorldEnvironment Glow Tuning

- [x] 5.1 In `scenes/environment/DefaultWorldEnvironment01.tscn`, increase `glow_intensity` from 0.1 to 1.0
- [x] 5.2 Add `glow_bloom = 0.2` to the environment settings
