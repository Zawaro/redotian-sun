# Goal: First Blood — MCV Deploy to Enemy Destruction

## Overview

End-to-end gameplay flow: player deploys MCV, builds base, trains infantry, attacks and destroys enemy Construction Yard. This plan tracks all issues and dependencies needed to achieve the first playable combat scenario.

## Goal Steps

| # | Step | Issue(s) | Status |
|---|------|----------|--------|
| 1 | Place MCV in MapEditor, assign to player 0 | #83 | ✅ Closed |
| 2 | Place Con Yard in MapEditor, assign to enemy (player 1) | #83 | ✅ Closed |
| 3 | Deploy MCV → Con Yard | #80 | ✅ Closed |
| 4 | Build menu empty before Con Yard exists | #81 | ✅ Closed |
| 5 | Build Power Plant (unlocks Barracks) | #81, #23 | ✅ Closed |
| 6 | Build Barracks (unlocks Infantry) | #81, #23 | ✅ Closed |
| 7 | Train infantry (E1 rifle) | #23 (weapon data) | ✅ Closed |
| 8 | Left-click enemy Con Yard → attack command | #79 | ✅ Closed |
| 9 | Infantry fires weapon → hitscan damage applied | #28 | ✅ Closed |
| 10 | Con Yard health reaches 0 → health_zero signal | #30 | ❌ Open |
| 11 | Death handler removes destroyed building | #82 | ❌ Open |

## Dependency Graph

```
#28 (CombatComponent Firing — hitscan MVP)
  ├─ #30 (HealthComponent death)
  │    └─ #82 (Death Handler)
  └─ #26 (GlobalRules Integration)

#78/#89 (Projectile System — future upgrade from hitscan)
```

## Critical Path

The longest dependency chain is:

1. ~~**#81** → prerequisite chain wiring~~ ✅
2. ~~**#79** → attack command~~ ✅
3. ~~**#28** → CombatComponent fires (hitscan MVP)~~ ✅
4. **#30** → health_zero signal emitted (already works, needs death handler)
5. **#82** → death removes building (connects to health_zero)

Note: #78/#89 (projectile system) and #29 (HitboxComponent) are future upgrades from the hitscan MVP. They add visual projectiles but are not required for the First Blood demo.

## Parallel Workstreams

While the critical path runs, these can proceed in parallel:

- **#26** (GlobalRules) — wiring existing values
- **#98** (FreeUnitComponent bug) — MapEditor spawn fix

## Minimum Viable Scope

For "first blood" demo, skip:
- Turret rotation (#28 secondary)
- Elite weapon promotion (#28 secondary)
- Ammo tracking (#28 secondary)
- Death effects/explosions (#30 secondary — just remove node)
- Auto-engage on sight (#79 secondary — manual attack only)
- Undeploy (#80 secondary)
- Armor calculation (#30 secondary — flat damage for MVP)

## Map Setup for Demo

Using MapEditor (#83 — done):
- Player 0 (human, GDI): starts with MCV at spawn point
- Player 1 (AI, Nod): Construction Yard pre-placed
- Both assigned via MapEditor entity placement tool

## Testing

After implementation, verify:
1. MapEditor: place MCV (player 0) and Con Yard (player 1)
2. Start game → sidebar shows nothing useful (no Con Yard for player 0)
3. Select MCV → deploy → Con Yard appears
4. Sidebar now shows Power Plant, Barracks (prerequisites met)
5. Build Power Plant → Barracks unlocks
6. Build Barracks → Infantry unlocks
7. Train infantry
8. Left-click enemy Con Yard → infantry walks toward it
9. In range → fires weapon → hitscan damage applied
10. Health bar decreases
11. Health reaches 0 → Con Yard disappears, cells freed

## Related Issues

- #81 — Prerequisite chain wiring
- #79 — Attack command
- #28 — CombatComponent firing logic (hitscan MVP)
- #78 — Projectile system (future upgrade)
- #89 — ProjectileData resource class (future upgrade)
- #29 — HitboxComponent damage detection (future upgrade)
- #30 — HealthComponent death/armor
- #82 — Death handler
- #26 — GlobalRules integration
- #98 — FreeUnitComponent MapEditor bug

### Closed (done)

- #77 — Per-player data
- #83 — MapEditor entity placement
- #80 — MCV deploy
- #23 — Entity data population
- #81 — Prerequisite chain wiring
- #79 — Attack command
- #28 — CombatComponent firing logic (hitscan MVP)
