## 1. Selection exclusivity (SelectionManager)

- [x] 1.1 Add public `clear_incompatible_selection(entity)` clearing the selection unless both the current head and `entity` are local
- [x] 1.2 `select_entity` shift branch: call `clear_incompatible_selection(entity)` before `add_entity`
- [x] 1.3 `MouseHandler._select_entities_2d_projected`: call `clear_incompatible_selection` before each `add_entity`

## 2. Click routing (MouseHandler)

- [x] 2.1 Remove the enemy-specific early-return block so unselected enemies fall through to the generic orders-then-select branch
- [x] 2.2 Confirm armed-unit-clicking-enemy still executes ATTACK; shift+click selects instead of queueing an attack

## 3. Order/cursor filter (UnitOrderGenerator)

- [x] 3.1 Add `_local_selection(sm)` (selected entities whose parent is local)
- [x] 3.2 `get_cursor`: return `DEFAULT` when `locals` is empty; pass `locals` to `resolve_single`
- [x] 3.3 `get_orders`: return `[]` when `locals` is empty; pass `locals` to `resolve_all`

## 4. Hotkey ownership guard (review #1)

- [x] 4.1 Extract the deploy/stop hotkey loop into `MouseHandler.apply_selection_hotkey(is_stop)` and skip non-local selected entities
- [x] 4.2 Regression test: stop hotkey cancels a local harvester, never a selected enemy's

## 5. Shared ownership predicate (review #6)

- [x] 5.1 Add `PlayerManager.is_entity_local(entity, local_id)`; delegate `SelectionManager._is_local_entity_node` and `UnitOrderGenerator._is_local_entity` to it

## 6. Regression tests

- [x] 6.1 `test_selection_manager.gd`: shift-click enemy over local clears local; shift-click local over enemy clears enemy; second enemy replaces first; shift-click local unit still adds; lone enemy selectable; shift box-select over local clears a selected enemy; hotkey stop skips enemy
- [x] 6.2 `test_unit_order_generator.gd`: enemy unit/harvester/armed building/undeployable building → `DEFAULT`/empty orders; local armed/undeployable buildings still produce orders; armed local vs enemy → ATTACK
- [x] 6.3 Update `test_non_combat_empty_orders_allows_enemy_selection` for the exclusive-selection fallthrough

## 7. Verification

- [x] 7.1 Run `redot --headless -s test/run_tests.gd`
- [x] 7.2 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`
- [x] 7.3 Confirm no tabs in multi-line strings (`grep -P '\t' scripts/**/*.gd`)

## 8. Docs & workflow

- [x] 8.1 Add a GLOSSARY.md entry (Orders & Selection) for enemy/exclusive selection
- [x] 8.2 Remove the stray untracked, broken `scenes/AssetPreview.tscn` (review #2)
- [x] 8.3 `openspec validate fix-166-enemy-selection-commands`
- [x] 8.4 Archive the change before merge (CI rejects PRs with open changes; archiving syncs `openspec/specs/`)
