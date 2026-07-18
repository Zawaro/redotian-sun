## Why

Tiberium crystals are flat-colored BoxMesh boxes with no visual glow. The original Tiberian Sun had luminous tiberium that illuminated its surroundings. The WorldEnvironment has `glow_enabled = true` but `glow_intensity = 0.1` — effectively inert. No material in the project uses emission.

Emission should be data-driven via ArtData .tres files, not hardcoded in components. This keeps visual properties tunable per-entity in the editor and consistent with the project's resource-driven architecture.

## What Changes

- Add emission fields to `ArtData`: `emission_enabled`, `emission_color`, `emission_energy_multiplier`
- `ArtComponent` applies emission to materials when loading models or creating placeholders
- `ResourceComponent` reads emission from `data.art_data` and applies to its procedural materials
- Create `tiberium_crystal_art.tres` with green emission (energy 3.0)
- Update `tiberium_crystal.tres` to reference the new ArtData
- Tune WorldEnvironment glow settings (intensity 0.1 → 1.0, bloom 0 → 0.2)
- SDFGI is already enabled — emission will naturally illuminate nearby terrain/buildings

## Capabilities

### New Capabilities
- `artdata-emission`: ArtData emission fields and their application by ArtComponent/ResourceComponent

### Modified Capabilities
- `tiberium-art-placeholder`: Tiberium crystals now use ArtData for emission; material creation reads from ArtData instead of hardcoded values

## Impact

- **Scripts**: `ArtData.gd` (3 new fields), `ArtComponent.gd` (apply emission in `_load_model` and `_add_placeholder`), `ResourceComponent.gd` (read ArtData emission in `_ensure_visual_nodes`)
- **Resources**: New `resources/art/terrain/tiberium_crystal_art.tres`, updated `resources/entities/terrain/tiberium_crystal.tres`
- **Scenes**: `DefaultWorldEnvironment01.tscn` (glow tuning)
- **No breaking changes**: All new fields default to disabled/zero — existing entities unaffected
