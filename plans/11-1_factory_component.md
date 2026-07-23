# FactoryComponent Cleanup & Production Exit System

**Issue:** #31
**Status:** Design complete, ready for implementation
**Created:** 2026-07-23

## Overview

Refactor FactoryComponent from dead code into the building-level production interface. ProductionManager queries it directly instead of reaching through BuildingManager. Add ExitComponent, RallyPointComponent, primary building toggle, and door animation wiring.

## Architecture Decisions

### ProductionManager Flow

```
ProductionManager (autoload)
  └── talks to FactoryComponent only
      └── FactoryComponent orchestrates exit
```

### Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| FactoryComponent | Declares what queue types building produces, manages primary building flag, orchestrates exit process |
| ExitComponent | Defines exit point (cell offset, facing), positions unit on exit, emits unit_spawned signal |
| RallyPointComponent | Manages rally path (waypoints after exit), set by player via Alt + Left Click |
| ArtComponent | Plays door animations based on ArtData fields, listens to production signals |

### Signal Contracts

```
FactoryComponent
  signal exit_in_progress  — emitted when unit is exiting, ProductionManager uses this to find next free factory

ExitComponent
  signal unit_spawned(unit: Node3D)  — emitted after unit is positioned, ArtComponent listens for door anim

RallyPointComponent
  signal rally_point_changed(path: Array[Vector2i])  — emitted when player sets new rally point
```

### Data Flow

```
EntityData (.tres)
  ├── buildable_queue: String → FactoryComponent.produces (array)
  ├── exit_cell_offset: Vector2i → ExitComponent
  ├── spawn_cell_offset: Vector2i → ExitComponent
  ├── exit_facing: int → ExitComponent
  └── has_rally_point: bool → RallyPointComponent (if true, attach)

EntityFactory
  ├── reads EntityData
  ├── creates FactoryComponent if data.buildable_queue != ""
  ├── creates ExitComponent if data.exit_cell_offset != Vector2i(-1, -1)
  └── creates RallyPointComponent if data.has_rally_point == true
```

### Production Exit Flow

```
ProductionManager._complete_item()
  │
  ├── Building? → _add_ready_to_place() (wait for placement)
  │
  └── Unit? → FactoryComponent.on_unit_produced(entity_data, player_id)
                │
                ├── ExitComponent exists?
                │   ├── YES → ExitComponent.on_unit_produced(unit)
                │   │         → positions unit at spawn_cell_offset
                │   │         → sets exit_facing
                │   │         → emits unit_spawned
                │   │
                │   └── NO → find nearest free cell, spawn there
                │
                ├── RallyPointComponent exists?
                │   └── YES → unit follows rally_path after exit
                │
                ├── FactoryComponent emits exit_in_progress
                │
                └── ProductionManager receives exit_in_progress
                    → finds next free factory of same type
                    → starts next queued item
```

### Helipad Pattern

Helipads use both DockHostComponent and ExitComponent:

```
Helipad
  ├── DockHostComponent — where aircraft land/attach
  └── ExitComponent — where aircraft take off from (thin usage)

Airfield
  ├── FactoryComponent — produces aircraft
  └── ExitComponent — where aircraft spawn and take off from
```

The DockHostComponent handles landing position. ExitComponent handles takeoff position. They can be different points on the same building.

### Primary Building Toggle

```
FactoryComponent.set_primary()
  │
  ├── Set self.is_primary = true
  │
  └── Query all "factories" with same produces type + same player_id
      └── Set their is_primary = false
```

Only one primary factory per queue type per player.

## File Changes

### New Files

| File | Purpose |
|------|---------|
| `scripts/components/ExitComponent.gd` | Exit point definition and unit positioning |
| `scripts/components/RallyPointComponent.gd` | Rally path management |

### Modified Files

| File | Changes |
|------|---------|
| `scripts/components/FactoryComponent.gd` | Delete dead code, add produces/is_primary/on_unit_produced, group registration |
| `scripts/data/EntityData.gd` | Add exit_cell_offset, spawn_cell_offset, exit_facing, has_rally_point |
| `scripts/entities/EntityFactory.gd` | Update _add_factory_component, add _add_exit_component, _add_rally_point_component |
| `scripts/production/ProductionManager.gd` | Query "factories" group, call FactoryComponent.on_unit_produced |
| `scripts/components/ArtComponent.gd` | Listen to production signals, play door anims |
| 4 .tres files | Add exit fields to GDI/Nod Barracks and War Factories |

## Testing Strategy

1. Unit tests for FactoryComponent (produces, is_primary toggle)
2. Unit tests for ExitComponent (positioning, facing)
3. Unit tests for RallyPointComponent (set/clear, path)
4. Integration test: ProductionManager → FactoryComponent → ExitComponent flow
5. Integration test: multiple factories, primary building selection
6. Integration test: helipad dock + exit flow
