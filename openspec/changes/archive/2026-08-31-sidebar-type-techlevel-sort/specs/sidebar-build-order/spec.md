## ADDED Requirements

### Requirement: Sidebar build items sort by type group then tech level
The sidebar build menu SHALL sort buildable items by: entity type group rank (mirroring `Sidebar.TAB_ENTITY_TYPES` order — Buildings, Infantry, Vehicles, Aircraft), then ascending `EntityData.tech_level` (with -1, meaning always available, sorting before all finite levels), then `display_name` (natural case-insensitive), then `id`. Sorting SHALL be deterministic: items with equal keys SHALL resolve to the same sequence regardless of load order.

#### Scenario: Ground vehicles precede aircraft in the Vehicles tab
- **WHEN** the Vehicles tab lists buildable entities of type VEHICLE and AIRCRAFT
- **THEN** every VEHICLE entry SHALL appear before every AIRCRAFT entry

#### Scenario: Lower tech level appears earlier within a type group
- **WHEN** two buildable entities share an entity type and differ in tech_level
- **THEN** the entity with the lower tech_level SHALL appear first, with tech_level -1 (always available) sorted before all finite levels

#### Scenario: Equal keys resolve deterministically
- **WHEN** two buildable entities share entity type, tech_level, and display_name
- **THEN** their relative order SHALL be decided by id, identically on every sidebar rebuild

### Requirement: No manual sidebar position field
`EntityData` SHALL NOT expose a sidebar position/priority field; sidebar order SHALL derive solely from entity type, tech_level, display_name, and id.

#### Scenario: New buildable entity requires no ordering metadata
- **WHEN** a new buildable entity is added with only entity_type and tech_level set
- **THEN** it SHALL slot into the sidebar order automatically without editing any sibling entity
