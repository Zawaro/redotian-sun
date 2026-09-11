## Why

Issue #401 reports two linked harvester-economy bugs: a harvester deposits only a fraction of its cargo at a refinery, and filling a harvester consumes far more tiberium cells than the original game.

Two independent root causes:

1. **Cell yield is normalized to 1 bale.** `ResourceComponent.collect()` returns `actual_health / max_health`, so a completely full cell yields exactly `1.0` bale regardless of `strength`. `gdi_harvester.tres` declares `storage = 28`, so filling needs 28 full cells. In the original engine a tiberium cell has 12 growth stages (0-11); harvesting lifts one stage per cycle and a ripe cell yields **11 collectable bales** (the stage-0 clearing bite yields nothing). With `Storage=28` a harvester fills from roughly **2.5 ripe cells**, and a full Riparius load is 28 x 25 = 700 credits.
2. **The dock evicts the harvester mid-unload.** `DockHostComponent.stale_timeout = 5.0` evicts the current docker once `_stale_timer >= stale_timeout`. `begin_unload()` resets the timer once, but `DockUnloadComponent._process` never refreshes it while draining, so at `unload_rate = 0.5` bales/s a 28-bale load (~56 s) is cut off after ~5 s - about 2.5 bales, i.e. a sliver.

Pacing is also slower than the reference. The project runs TS timings on a 2x time base (matching `build_speed = 0.4` = half TS's `.8`), so fill should be ~1.67 bales/s (18 TS ticks/bail at 30 ticks/s) and unload ~2.0 bales/s (~15 TS ticks/bail), versus the current 0.5.

## What Changes

- **Bale-based cell yield**: a ripe tiberium cell yields 11 collectable bales; per-cell capacity is data-driven on `ResourceType` (`bales_per_cell`, default `1.0` for backward compatibility, `11` for tiberium). `ResourceComponent.get_amount()`, `get_max_amount()`, and `collect()` operate in bales.
- **Consistent bale/health conversion** in resource growth seeding and the map editor's paint/erase brush, so spread crystals and hand-painted cells start at the intended bale amount.
- **No mid-unload eviction**: the stale timeout bounds only the approach/rotation phase; an actively unloading docker is never evicted and its full accepted cargo is deposited.
- **Reference pacing**: harvester fill rate ~1.67 bales/s, dock unload rate ~2.0 bales/s (2x TS time base, matching `build_speed`).

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `resource-harvesting`: cell amount/yield measured in bales; harvested continuously in bale increments; a full 28-bale load draws from ~2.5 ripe cells; reference fill cadence.
- `dock-host-client`: the stale timeout never evicts an actively unloading docker; unload completes the full accepted cargo; reference unload cadence.
- `resource-growth-system`: spawning, spreading, and growth convert bales to health through the cell's bale capacity.

## Impact

- `scripts/components/ResourceComponent.gd` - bale conversions.
- `scripts/components/DockUnloadComponent.gd` - refresh host stale timer while draining; reference unload rate.
- `scripts/components/DockHostComponent.gd` - scope stale timeout to approach/rotation.
- `scripts/core/ResourceGrowthSystem.gd` - bale-to-health seeding/growth.
- `scripts/editor/ResourcePainter.gd` - bale-to-health add/remove.
- `scripts/data/ResourceType.gd` + `games/ts/resource_types/tiberium_*.tres` - `bales_per_cell`.
- `games/ts/global_rules.tres` - `harvester_fill_rate`.
- Tests: `test/unit/test_resource_component.gd`, `test/unit/test_harvest_dock.gd`, `test/unit/test_resource_growth_system.gd`, `test/unit/test_global_rules.gd`, `test/unit/test_fog_ghosts.gd`.
- Specs: `resource-harvesting`, `dock-host-client`, `resource-growth-system`.
