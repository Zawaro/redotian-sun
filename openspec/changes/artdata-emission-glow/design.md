## Context

Tiberium crystals are placeholder BoxMesh clusters with flat `StandardMaterial3D` materials. The material is created inline in `ResourceComponent._ensure_visual_nodes()` using only `albedo_color` from `ResourceType.color`. No emission, no glow.

The project already has:
- `glow_enabled = true` in WorldEnvironment (but `glow_intensity = 0.1` — inert)
- `sdfgi_enabled = true` — emission will naturally illuminate nearby objects
- ArtData resource class used by ArtComponent for models/placeholders

Tiberium crystals currently have **no ArtData** — `tiberium_crystal.tres` has `art_data = null`. ResourceComponent builds visuals procedurally, bypassing ArtComponent entirely.

## Goals / Non-Goals

**Goals:**
- Add emission fields to ArtData so any entity can glow via .tres configuration
- ArtComponent applies emission when building materials (models + placeholders)
- ResourceComponent reads ArtData emission for procedural materials (tiberium crystals)
- Tune WorldEnvironment glow to actually be visible
- Zero performance regression — emission is a shader uniform, bloom is already enabled

**Non-Goals:**
- OmniLight3D per entity (expensive, unnecessary with emission + bloom)
- Animated/pulsing emission (future enhancement)
- Per-pixel emission textures (future enhancement)
- Changing tiberium tree visuals (gray placeholder — deferred to art pass)

## Decisions

### 1. Emission fields on ArtData (not ResourceType or EntityData)

**Choice:** Add `emission_enabled`, `emission_color`, `emission_energy_multiplier` to ArtData.

**Rationale:**
- ArtData is the visual properties resource — emission is visual
- ResourceType is economic (value, growth) — emission doesn't belong there
- EntityData is already 170+ lines — avoid more bloat
- Every entity that has art already has an ArtData reference
- Consistent with existing pattern: ArtData has model_path, texture_path → now also emission

**Alternatives considered:**
- ResourceType: simpler (color already exists), but pollutes economic data with visual concerns
- EntityData direct: simplest, but EntityData is bloated
- New EmissionData resource: over-engineered for 3 fields

### 2. ResourceComponent reads ArtData via EntityData

**Choice:** ResourceComponent stores `_art_data: ArtData` from `configure(data)` and reads emission fields when creating materials.

**Rationale:**
- ResourceComponent already receives EntityData in `configure()`
- EntityData already has `art_data` field
- No new wiring needed — just store the reference and use it

**Flow:**
```
EntityData.art_data → ResourceComponent.configure() stores _art_data
                    → _ensure_visual_nodes() reads _art_data.emission_*
                    → applies to StandardMaterial3D
```

### 3. New tiberium_crystal_art.tres

**Choice:** Create `resources/art/terrain/tiberium_crystal_art.tres` with emission fields set.

**Rationale:**
- tiberium_crystal.tres currently has no art_data
- New ArtData resource with: emission_enabled=true, emission_color=green, emission_energy=3.0
- Link it on tiberium_crystal.tres via art_data field

### 4. WorldEnvironment glow tuning

**Choice:** Increase glow_intensity from 0.1 to 1.0, add glow_bloom = 0.2.

**Rationale:**
- Current 0.1 is invisible — bloom needs threshold-exceeding brightness
- emission_energy=3.0 on tiberium will trigger bloom at HDR threshold ~1.0
- SDFGI already enabled — emission will illuminate nearby terrain naturally

## Risks / Trade-offs

- **SDFGI emission interaction** → SDFGI is already computing indirect lighting. Emission adds input but no extra cost. Green tiberium will cast green light on nearby terrain — desirable for atmosphere.
- **Material cache key** → `ResourceComponent._mat_cache` uses `resource_type_id` as key. All crystals of same type share one material. If different ArtData per crystal is ever needed, cache key must change. Acceptable for now.
- **ArtComponent dual path** → ArtComponent applies emission in both `_load_model()` and `_add_placeholder()`. Two code paths, same logic. Could extract to a helper, but it's 3 lines — not worth the abstraction yet.
