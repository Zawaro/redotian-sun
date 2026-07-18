## 1. Data Resources

- [x] 1.1 Expand PlayerData.gd with identity fields (faction_id, color, team_id, spawn_index, display_name, is_bot)
- [x] 1.2 Create Faction.gd resource (id, display_name, color)
- [x] 1.3 Create MapConfig.gd resource with PlayerConfig inner class
- [x] 1.4 Create GDI and Nod faction .tres files under resources/factions/

## 2. PlayerManager Autoload

- [x] 2.1 Create PlayerManager.gd autoload script with _players dict and _local_player_id
- [x] 2.2 Implement get_local_player_id() method
- [x] 2.3 Implement get_player_data(player_id) with lazy creation
- [x] 2.4 Implement is_enemy(a_id, b_id) using team_id comparison
- [x] 2.5 Implement get_all_players() and get_players_by_team(team_id)
- [x] 2.6 Implement _ready() to find MapConfig child node and initialize players
- [x] 2.7 Implement fallback: create player 0 (human, GDI, team 1) and player 1 (AI, Nod, team 2) when no MapConfig found
- [x] 2.8 Register PlayerManager in project.godot autoloads BEFORE all other autoloads (first position)

## 3. EconomyManager Refactor

- [x] 3.1 Remove _players dict and _get_player_data() from EconomyManager
- [x] 3.2 Update get_balance() to call PlayerManager.get_player_data()
- [x] 3.3 Update can_afford() to call PlayerManager.get_player_data()
- [x] 3.4 Update deduct() to call PlayerManager.get_player_data()
- [x] 3.5 Update add() to call PlayerManager.get_player_data()
- [x] 3.6 Update get_storage_capacity() to call PlayerManager.get_player_data()
- [x] 3.7 Verify signals (credits_changed, insufficient_funds) still emit correctly

## 4. Consumer Refactors

- [x] 4.1 Update BuildingManager: replace em.deduct(0, ...) with PlayerManager.get_local_player_id()
- [x] 4.2 Update BuildingManager: replace em.add(0, ...) in sell_building with PlayerManager.get_local_player_id()
- [x] 4.3 Update BuildingManager: replace ps.register_building(0, ...) with PlayerManager.get_local_player_id()
- [x] 4.4 Update BuildingManager: replace pm.clear_waiting_for_placement(0) with PlayerManager.get_local_player_id()
- [x] 4.5 Update Sidebar: replace player_id != 0 check in _on_credits_changed with PlayerManager.get_local_player_id()
- [x] 4.6 Update Sidebar: replace pm.get_ready_buildings(0) with PlayerManager.get_local_player_id()
- [x] 4.7 Update Sidebar: replace pm.get_queue_key(0, ...) in _is_paused, _is_queued_non_active, _get_queue_count, _get_item_progress with PlayerManager.get_local_player_id()
- [x] 4.8 Update Sidebar: replace pm.start_production(0, ...) and pm.cancel_production(0, ...) with PlayerManager.get_local_player_id()
- [x] 4.9 Update Sidebar: replace ps.can_build(0, ...) and ps.get_build_count(0, ...) with PlayerManager.get_local_player_id()
- [x] 4.10 Update ProductionManager: replace hardcoded 0 in clear_waiting_for_placement and cancel_ready_building with PlayerManager.get_local_player_id()
- [x] 4.11 Verify PrerequisiteSystem: register_building(0, ...) and can_build(0, ...) are replaced

## 5. Tests

- [x] 5.1 Create test_player_manager.gd with unit tests for PlayerManager
- [x] 5.2 Update test_economy_manager.gd to set up PlayerManager in scene tree before tests
- [ ] 5.3 Run full test suite and verify all tests pass

## 6. Polish

- [x] 6.1 Update plans/1-3_economy_resources.md with final PlayerData/PlayerManager design
- [x] 6.2 Verify no hardcoded player_id = 0 remains in source code (excluding tests)
- [x] 6.3 Run gdlint and gdformat on all changed files
