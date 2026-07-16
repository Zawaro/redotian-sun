## Context

EntityFactory autoload scans `resources/entities/` recursively and caches all `.tres` files
that extend EntityData. The sidebar currently shows all buildings with `buildable = true`.
The new tabbed sidebar (issue #66) will filter by `entity_type` per tab.

Existing pattern: `resources/entities/vehicles/gdi_harvester.tres` references an ArtData
resource at `resources/art/vehicles/harvester_art.tres` via `art_data` field.

## Goals / Non-Goals

**Goals:**
- Add 6 new entity .tres files with TS-accurate stats from rules.ini
- Add 6 placeholder ArtData .tres files (no model, just placeholder_size)
- All new entities marked `buildable = true`
- Entities organized in existing folder structure (`infantry/`, `vehicles/`, `aircraft/`)

**Non-Goals:**
- No code changes to EntityFactory or Sidebar
- No actual 3D models or textures (placeholder only)
- No weapon data files (future work)
- No faction-specific variants (GDI/Nod versions)

## Decisions

**1. Stats source: CnCNet official rules.ini**
Used the canonical TS rules.ini from `downloads.cncnet.org` for all stats.
Alternatives considered: Tiberian Sun Wiki (unreliable), PPMSite (outdated).

**2. Placeholder art approach: ArtData with placeholder_size only**
Each entity gets an ArtData .tres with `placeholder_size` set but no `model_path`.
This makes them render as colored boxes in the 3D view — same as existing entities
without art. Alternative: skip art_data entirely. Chosen approach is better because
it gives the selection overlay something to size against.

**3. New `aircraft/` folder for AIRCRAFT entity_type**
Currently only `infantry/`, `vehicles/`, `structures/`, `terrain/` exist.
Adding `aircraft/` follows the same convention and keeps the entity type directories clean.

**4. `buildable = true` on all new units**
Even though the current sidebar only uses this for buildings, setting it on units
means they'll be ready when the tabbed sidebar filters by entity_type.
The tab filtering logic will check `entity_type` match, not `buildable`.

## Risks / Trade-offs

- **Risk**: Stats may differ from TS:FS (Firestorm) expansion. → Mitigation: using base TS rules.ini, Firestorm units are separate.
- **Risk**: Placeholder boxes look odd in-game. → Mitigation: temporary, models added later.
- **Trade-off**: No weapon data means units can't fight. → Acceptable for sidebar validation.
