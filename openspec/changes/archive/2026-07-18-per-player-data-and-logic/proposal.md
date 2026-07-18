## Why

BuildingManager, Sidebar, and ProductionManager all hardcode `player_id = 0` — there's no way to know which player is the human, which entities belong to whom, or who is allied with whom. This blocks component implementation (CombatComponent, HealthComponent, FactoryComponent, PowerComponent) which needs owner tracking and team-based targeting.

## What Changes

- **PlayerManager** new autoload (first in load order): thin registry that owns PlayerData instances, provides `get_local_player_id()`, `is_enemy(a, b)`, `get_all_players()`, `get_players_by_team(team_id)`
- **PlayerData** expanded from 4 lines to full identity + economy struct: `player_id`, `credits`, `faction_id`, `color`, `team_id`, `spawn_index`, `display_name`, `is_bot`
- **Faction** new resource: per-faction definition (id, display_name, color) stored as .tres files under `resources/factions/`
- **MapConfig** new resource with PlayerConfig inner class: per-map player definitions with full overrides (starting_credits, starting_units, power_output). Loaded from map scene child node. Fallback: player 0 (human) + player 1 (AI)
- **EconomyManager** refactored to stateless: calls PlayerManager.get_player_data() instead of own `_players` dict. Signals stay.
- **BuildingManager** refactored: replaces hardcoded `em.deduct(0, ...)` and `ps.register_building(0, ...)` with `PlayerManager.get_local_player_id()`
- **ProductionManager** refactored: replaces hardcoded `0` in `clear_waiting_for_placement` and `cancel_ready_building`. Queue state stays internal (no ProductionState extraction).
- **Sidebar** refactored: replaces hardcoded `player_id != 0` check and all `pm.get_ready_buildings(0)` / `pm.get_queue_key(0, ...)` with local player ID lookup
- **PrerequisiteSystem** refactored: replaces hardcoded `0` in `register_building` and `can_build` calls

## Capabilities

### New Capabilities
- `player-manager`: PlayerManager autoload — central player registry, local player ID, team-based relationship queries
- `player-data`: PlayerData resource definition with identity, economy, and bot flag
- `faction-data`: Faction resource definitions (GDI, Nod)
- `map-config`: Per-map player initialization from MapConfig resource (scene child node)

### Modified Capabilities
- `economy-core`: EconomyManager becomes stateless, reads PlayerData from PlayerManager instead of own dict

## Impact

- `scripts/core/PlayerManager.gd` — new autoload
- `scripts/data/PlayerData.gd` — expanded fields
- `scripts/data/Faction.gd` — new resource
- `scripts/data/MapConfig.gd` — new resource with PlayerConfig inner class
- `resources/factions/gdi.tres` — GDI faction data
- `resources/factions/nod.tres` — Nod faction data
- `scripts/economy/EconomyManager.gd` — refactor to stateless
- `scripts/buildings/BuildingManager.gd` — replace hardcoded player_id
- `scripts/production/ProductionManager.gd` — replace hardcoded player_id
- `scripts/ui/Sidebar.gd` — replace hardcoded player_id
- `test/unit/test_player_manager.gd` — new tests
- `test/unit/test_economy_manager.gd` — update for PlayerManager dependency
- `project.godot` — add PlayerManager autoload (first position)
