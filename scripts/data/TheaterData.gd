class_name TheaterData extends Resource

## A light theater tag: which authored look a map uses. Theaters vary visuals
## only — movement passability stays global in Locomotor.terrain_speeds. All
## TerrainObject geometry lives in the global TerrainCatalog; theater-specific
## art variation is expressed per element through TerrainArtData.theater_overrides.

@export_group("Theater")
## Unique identifier (e.g. "temperate", "desert", "winter").
@export var id: String = ""
## Human-readable name shown in the new-map dialog.
@export var display_name: String = ""
