## 1. Test fixture owner setup

- [x] 1.1 Add a minimal helper to dock test fixtures that attaches a `StatsComponent` with a chosen `player_id` to a fixture entity; default existing fixtures in `test_dock_host_component.gd`, `test_dock_client_component.gd`, `test_harvest_dock.gd`, `test_dock_queue_step.gd` to matching owners so current scenarios keep passing
- [x] 1.2 Run full suite (`redot --headless -s test/run_tests.gd`) and confirm green before any production change

## 2. Host trust boundary

- [x] 2.1 In `DockHostComponent.request_dock()`, add owner gate: reject (return false) when docker's entity owner differs from host building's owner or either id is unset (`< 0` / missing `StatsComponent`) — place after the `_vacating_docker` guard
- [x] 2.2 Add tests: same-owner request succeeds (prove positive path), foreign owner rejected, missing `StatsComponent` on either side rejected, foreign docker never enters queue

## 3. Client seek filter

- [x] 3.1 In `DockClientComponent.find_nearest_host()`, skip candidates whose building owner mismatches the seeking entity's owner or has an unset id; ownerless clients match nothing
- [x] 3.2 Add tests: nearest enemy refinery skipped, own refinery farther away still found, only-enemy-hosts returns null, ownerless client returns null

## 4. Idle-with-retry behavior (no friendly refinery)

- [x] 4.1 Write regression test first: full harvester, only enemy refineries → harvester stays near field with cargo retained, retries via cooldown, never docks/queues toward enemy host (must fail before fix if run against old code)
- [x] 4.2 Verify the `dock_slot_failed` → retry-cooldown loop covers this case without code changes; add minimal handling only if the test exposes a gap

## 5. Order targeter ownership

- [x] 5.1 In `HarvestComponent.get_order_for_target()`, return ENTER only for same-owner dock hosts; return null for foreign-owned/unset-owner targets so downstream generators resolve the order
- [x] 5.2 Update/add tests: friendly refinery → ENTER (existing scenario stays green); enemy refinery → null order

## 6. Credit attribution

- [x] 6.1 In `DockUnloadComponent._process()`, read owner from the unload component's parent building `StatsComponent.player_id`; remove local-player fallback and stop reading docker stats; ownerless building grants nothing
- [x] 6.2 Add tests: own harvester at own refinery credits own player; credits go to refinery owner regardless of docker owner; ownerless refinery pays nobody

## 7. Verification

- [x] 7.1 Full test suite green (`redot --headless -s test/run_tests.gd`)
- [x] 7.2 Lint + format clean (`gdlint scripts/**/*.gd test/**/*.gd`, `gdformat --check scripts/**/*.gd test/**/*.gd`), then tab check (`grep -P '\t' scripts/**/*.gd`)
- [ ] 7.3 Manual smoke in editor: player + enemy refineries on map, order full harvester onto enemy refinery — no ENTER/dock occurs; destroy own refinery — harvester idles at field with cargo
