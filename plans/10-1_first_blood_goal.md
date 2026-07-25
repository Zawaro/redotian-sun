# Goal: First Blood — MCV Deploy to Enemy Destruction

## Overview

End-to-end gameplay flow: player deploys MCV, builds base, trains infantry, attacks and destroys enemy Construction Yard. This plan tracks all issues and dependencies needed to achieve the first playable combat scenario.

## Goal Steps

| # | Step | Issue(s) | Status |
|---|------|----------|--------|
| 1 | Place MCV in MapEditor, assign to player 0 | #83 | ✅ Closed |
| 2 | Place Con Yard in MapEditor, assign to enemy (player 1) | #83 | ✅ Closed |
| 3 | Deploy MCV → Con Yard | #80 | ✅ Closed |
| 4 | Build menu empty before Con Yard exists | #81 | ❌ Open |
| 5 | Build Power Plant (unlocks Barracks) | #81, #23 | ✅ Closed |
| 6 | Build Barracks (unlocks Infantry) | #81, #23 | ✅ Closed |
| 7 | Train infantry (E1 rifle) | #23 (weapon data) | ✅ Closed |
| 8 | Right-click enemy Con Yard → attack command | #79 | ❌ Open |
| 9 | Infantry fires weapon → projectile flies | #78, #89, #28 | ❌ Open |
| 10 | Projectile hits Con Yard → damage applied | #29, #30 | ❌ Open |
| 11 | Con Yard health reaches 0 → destroyed, removed | #82 | ❌ Open |

## Dependency Graph

```
#81 (Prerequisite Chain)
  └─ #79 (Attack Command)
       └─ #28 (CombatComponent Firing)
            ├─ #78 (Projectile System)
            │    └─ #89 (ProjectileData Resource)
            │         └─ #29 (HitboxComponent)
            │              └─ #30 (HealthComponent)
            │                   └─ #82 (Death Handler)
            └─ #26 (GlobalRules Integration)
```

## Critical Path

The longest dependency chain is:

1. **#81** → prerequisite chain wiring (just .tres edits)
2. **#79** → attack command (needs player_id + is_enemy — already in codebase from #77)
3. **#28** → CombatComponent fires (needs attack command)
4. **#78/#89** → projectile system + ProjectileData resource (needs CombatComponent to spawn it)
5. **#29** → hitbox detects projectile (needs projectile to exist)
6. **#30** → health decrements (needs hitbox forwarding)
7. **#82** → death removes building (needs health_zero)

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
8. Right-click enemy Con Yard → infantry walks toward it
9. In range → fires weapon → projectile flies
10. Projectile hits → health bar decreases
11. Health reaches 0 → Con Yard disappears, cells freed

## Related Issues

- #81 — Prerequisite chain wiring
- #79 — Attack command
- #28 — CombatComponent firing logic
- #78 — Projectile system
- #89 — ProjectileData resource class
- #29 — HitboxComponent damage detection
- #30 — HealthComponent death/armor
- #82 — Death handler
- #26 — GlobalRules integration
- #98 — FreeUnitComponent MapEditor bug

### Closed (done)

- #77 — Per-player data
- #83 — MapEditor entity placement
- #80 — MCV deploy
- #23 — Entity data population
