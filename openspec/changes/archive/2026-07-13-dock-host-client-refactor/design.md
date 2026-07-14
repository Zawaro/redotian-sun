## Context

The current dock/harvest system has a single `DockComponent` that conflates host (building) and client (unit) responsibilities. `HarvestComponent` contains dock-finding logic that should be generic. Tiberium types are bare ints with no hierarchy, making multi-type resource support impossible. Cargo is a single integer.

The system needs to support: tiberium harvesters docking at refineries, weed eaters docking at weed refineries, future service depot repair, and proper harvester distribution across multiple refineries.

## Goals / Non-Goals

**Goals:**
- Clean host/client separation following OpenRA's DockHost/DockClient pattern
- Queue management with configurable limits and wait timers
- Reservation-before-movement to prevent wasted pathfinding
- Occupancy-aware host selection to distribute harvesters
- Extensible resource type hierarchy (parent categories + sub-types)
- Multi-type cargo via Dictionary-based TransportComponent
- RefineryComponent as a data declaration for accepted resource types

**Non-Goals:**
- DockType BitSet system (OpenRA's full type matching) — overkill for now, use entity ID matching
- ServiceDepotComponent / RepairComponent — future work, but DockClientComponent should be generic enough to support it
- Passenger enter/exit mechanics for APCs — separate concern
- Animated dock sequences (drag-in, reverse-out) — visual polish later
- Multiplayer sync considerations — single-player only for now

## Decisions

### 1. DockHostComponent reads foundation from FoundationComponent sibling

**Decision**: Remove `foundation` export from DockHostComponent. Read it from sibling FoundationComponent at runtime via `get_parent().get_node_or_null("FoundationComponent")`.

**Alternatives considered**:
- Keep duplicate foundation field: Simpler, but data drift risk when FoundationComponent changes
- Pass via configure(): Would require EntityFactory to wire it, adding coupling

**Rationale**: FoundationComponent is the single source of truth for building size. DockHostComponent is a child of the same entity, so sibling lookup is trivial and zero-cost.

### 2. Client specifies target hosts by entity ID, not dock type

**Decision**: `DockClientComponent.can_dock_with: PackedStringArray` holds entity IDs (e.g. `["PROC"]`). No abstract type matching.

**Alternatives considered**:
- OpenRA-style DockType BitSet: Powerful but complex — needs type registry, bitset operations, config per entity
- String-based type matching: Middle ground, but adds indirection without clear benefit

**Rationale**: In Tiberian Sun, a tiberium harvester docks at refineries (entity ID "PROC"), a weed eater docks at weed refineries (different entity ID). Entity ID matching is direct, debuggable, and sufficient. If type matching is needed later, DockClientComponent can be extended without breaking changes.

### 3. Resource type hierarchy with parent categories

**Decision**: `ResourceType` has `category` (parent) and `parent_type` (immediate parent). `GlobalRules.resource_types: Dictionary` holds all types. HarvestComponent uses `harvestable_types: PackedStringArray = ["tiberium"]` which matches all sub-types via `GlobalRules.get_resource_category()`.

**Alternatives considered**:
- Flat type list with manual sub-type enumeration: Simpler but requires updating HarvestComponent when adding new tiberium variants
- Enum-based: Not extensible for mods, can't add new types without code changes

**Rationale**: Category-based matching means HarvestComponent doesn't need to know about green/blue/red tiberium — it just harvests "tiberium" category. New sub-types are added as .tres files with no code changes. The `parent_type` field allows both categories (empty parent) and sub-types (non-empty parent).

### 4. RefineryComponent separate from DockUnloadComponent

**Decision**: `RefineryComponent` declares `accepted_resource_categories`. `DockUnloadComponent` handles the unload tick logic. DockUnloadComponent reads RefineryComponent to validate cargo.

**Alternatives considered**:
- Merge into DockUnloadComponent: Fewer components, but mixes data declaration with tick logic
- Merge into DockHostComponent: Overloads the host with economy concerns

**Rationale**: Separation of concerns. RefineryComponent is data ("what I accept"), DockUnloadComponent is behavior ("how I unload"). Future ServiceDepotComponent can reuse DockClientComponent without inheriting refinery-specific unload logic.

### 5. TransportComponent.cargo as Dictionary

**Decision**: `cargo: Dictionary = {}` with format `{resource_type_id: amount}`. Helper methods: `get_cargo_total()`, `get_cargo_value()`, `add_cargo()`, `remove_cargo()`.

**Alternatives considered**:
- Parallel arrays (types[] + amounts[]): More memory-efficient but harder to use
- Single int with type flag: Doesn't support mixed cargo

**Rationale**: Dictionary is the natural GDScript mapping. O(1) lookup by type, easy to iterate for unload. The cargo is small (typically 1-2 types), so dictionary overhead is negligible.

### 6. Hard break on .tres fields, no migration

**Decision**: Remove old fields (`tiberium_type`, `storage`, `dock`, `allowed_entities`, `foundation` on DockComponent) and update all .tres files directly. No backward compatibility layer.

**Alternatives considered**:
- Migration shim: Read old fields, map to new ones, warn on deprecation: More complex, tech debt
- Dual-field period: Both old and new fields exist simultaneously: Confusing, data drift risk

**Rationale**: This is a pre-release project. Clean breaks are cheaper than maintaining compatibility layers. All .tres files are in the repo and can be updated in one pass.

## Risks / Trade-offs

- **[Risk] Entity ID coupling** → DockClientComponent硬编码entity IDs like "PROC". If refinery IDs change, all harvesters break. Mitigation: IDs are stable (rules.ini convention), and this matches the original game's design.
- **[Risk] Sibling node lookup at runtime** → DockHostComponent reads FoundationComponent via `get_parent().get_node()`. If component order changes in EntityFactory, this could fail. Mitigation: EntityFactory always adds FoundationComponent before DockHostComponent, and the lookup uses `get_node_or_null` with null guard.
- **[Trade-off] Dictionary cargo vs int** → Slightly more complex code in HarvestComponent and DockUnloadComponent. Mitigated by helper methods on TransportComponent.
- **[Trade-off] Category-based harvestable matching** → HarvestComponent can't filter by specific sub-type (e.g. "harvest only green tiberium"). This is intentional — in Tiberian Sun, harvesters harvest all tiberium types. If selective harvesting is needed later, add a `harvestable_ids` field alongside `harvestable_types`.
