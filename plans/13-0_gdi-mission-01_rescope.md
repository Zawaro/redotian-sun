# 13-0 — GDI Mission 01 Milestone Re-scope (Authenticity-First)

**Created:** 2026-09-14
**Milestone:** #1 "GDI Mission 01: Reinforce Phoenix Base" (`gdi1a.map`)
**Basis:** four-agent gap audit of milestone #1 against `main` @ `2870ede` and the actual
`gdi1a.map`. Companion to `plans/12-0_unified_multi_title_expansion.md`.

## Decisions (2026-09-14)

1. **Authenticity-first.** Scripted teams, triggers, reinforcements, reveals, and bridge
   destruction move from `milestone-tier2` into the required milestone scope.
2. **Art is polish-phase.** Placeholder art is acceptable through the milestone; final art
   (#235/#252/#253) is tracked under a new `milestone-polish` label and is not a hard gate.
3. **Meteor is trigger-driven.** #244 fires meteor strikes at waypoints via trigger action 58;
   player superweapon-targeting UI (#265) is descoped from this mission.
4. **Cross-milestone deps pulled in:** #203 theater registry, #267 aircraft/helipad,
   #321 world-space impact spawner, #323 AoE splash.
5. **Cliff resolver consolidated:** #199/#207 superseded by #230.

## Command model (mouse)

| Input | Order |
|---|---|
| `Left-click` | Select / act (existing) |
| `Ctrl+Left-click` | **Explicit Attack** — engage the designated target only; suppress auto-acquire while en route (once #261 lands) |
| `Ctrl+Shift+Left-click` | **Attack-move** — advance to the point, engage enemies encountered, then resume |
| `Alt+Left-click` | Force-move (existing) |
| `Shift` | Queue (existing) |
| `Right-click` | Deselect / cancel only (repo convention) |

`plans/2-2_movement_commands.md` previously said `Shift+Right-click` for attack-move — corrected
here. Add a proper `attack_move` action to `project.godot` (not raw key checks) so it stays
remappable via `InputSettings`.

## Issue disposition

| Action | Issues |
|---|---|
| Close (done) | #246 radar/minimap (shipped), #242, #243 |
| Split | #245 → defense weapons (remaining: auto-engage, blocked on #261) + N5 building upgrade attach |
| Re-tier to required | #238 teams, #239 reinforcements, #241 camera/reveal, #244 meteor, #248 trigger wiring, #249 set-dressing FX, #250 bridge destruction |
| Keep required | #226–#234, #236, #237, #240, #247, #255, #258, #261, #262, #264 |
| Polish (`milestone-polish`) | #235 terrain art, #251 audio content, #252 overlay art, #253 entity art |
| Closer | #254 playtest & balance |
| Supersede | #199, #207 → #230 |
| Pull into milestone | #203, #267, #321, #323 |
| Descope | #265 superweapon targeting UI |

## New issues

- **N1** — map-local houses (GDI2/Nod2/Neutral2 + `ActsLike`); `Houses.gd` lacks it.
- **N2** — per-mission roster/build gating (`Owner`/`RequiredHouses`/`ForbiddenHouses`/`TechLevel`).
- **N3** — CellTags subsystem (JSON schema + runtime registry + editor tool).
- **N4** — mission timer HUD.
- **N5** — building upgrade attachment (`PowersUpBuilding`), split from #245.

Folded into existing: menu map-select + delete dead `EntityMaskManager.gd` → #262;
explicit-attack suppression → #261/#264.

## Corrected mission facts (validated against `gdi1a.map`)

| Claim | Actual |
|---|---|
| 49 triggers | **52** |
| 22 TaskForces | **20** (22 TeamTypes, 22 Scripts) |
| 26 structures | **36** (3 units, 17 infantry) |
| 4 Power Plants, 1 upgraded | **3** `GAPOWR`, all 3 with `GAPOWRUP` |
| CellTags 49064–54066 | **49064–54064** |
| 50 waypoints A..AZ | **53** (A..AY + 98, 99) |
| #247 missing entities (~13) | **all 31 already exist** — verify-and-map, not create |
| TREE01–25 | **TREE19 absent** |

Event types used: `{1,7,10,11,13,19,35,36,48}`. Actions include
`{1,2,4,6,7,11,12,17,19,21,22,32,41,46,47,48,52,55,56,58,63,64,65,66,80,88,100}`.

## Dependency graph

```
A (map):   #226 → #227 ; #228 → #229/#230/#231 → #232 → #233 ; #234 ∥
B (mission): #236 → #237 (+N3 CellTags) → #238 → #239 ; #240 ; #241
C (content): #232 + N1 → #247 ; N5 → #245
D (combat): #261 → #264
E (integrate): #248 (needs A+B+C) → #244 + #250 → #249 → #255/#258 → #254 (closer)
Pulled deps: #203 (theater), #267 (aircraft), #321/#323 (AoE/FX)
Cycle fix: #247 places content; #245/#246 verification moves to #254 (one-way edge).
```

## Scope risks (large subsystems inside single issues)

#237 trigger engine, #238 team runtime, #241 camera+reveal (two systems), #248 wiring,
#232 hand-built 48×63 map, #255 music, #226 LZO importer. Consider splitting #241 and #255
if they stall.

## Open items

- Splitting #241 (camera) and #255 (music) into engine vs content if scope grows.
- Type-list/roster gating semantics (N2) may need a small design doc before implementation.
