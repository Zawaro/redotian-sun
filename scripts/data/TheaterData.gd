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

@export_group("Radar")
## Brightness multiplier applied to terrain map colors at height ratio 0
## (flat ground). Terrain shading lerps from this to high_radar_brightness by
## cell height, so high ground reads brighter on the minimap.
@export_range(0.0, 4.0) var low_radar_brightness: float = 1.0
## Brightness multiplier applied to terrain map colors at height ratio 1.
@export_range(0.0, 4.0) var high_radar_brightness: float = 1.6
