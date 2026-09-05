# Glossary

Canonical term directory for Redotian Sun. Fast lookup — meaning readable here,
expanded semantics live in the anchored spec (authoritative) or code. Grouped by
domain cluster.

**Rule:** read this before writing specs/design docs or naming things. When a
term surfaces during planning or clarifying — even a prompt-only term — propose
adding it here. See **Undecided** below for terms that must not be guessed.

Entry form: term → one-line meaning → anchor.

## Game Selection & Content

| Term | Meaning | Where |
|------|---------|-------|
| game definition | One standalone game's content manifest: `GameDefinition` resource at `res://games/<id>/game.tres` (id, display_name, rules, data_sets, maps_dir). The `id` must match its directory name. | [game-context](openspec/changes/add-game-definition-context/specs/game-context/spec.md) · scripts/data/GameDefinition.gd |
| GameContext | First autoload: resolves the active game (`--game` flag → persisted `[game] id` → `ts`), owns `select_game`/`game_changed` lifecycle and per-game rules access. | [game-context](openspec/changes/add-game-definition-context/specs/game-context/spec.md) · scripts/core/GameContext.gd |
| data set | One `res://` layer root a consumer registers for scanning; the consumer appends its known subdir (`entities/`, `audio/`, `terrain_objects/`, `art/terrain/`, `theaters/`). | [game-content](openspec/changes/add-game-definition-context/specs/game-content/spec.md) |
| layering (last-wins) | Same resource id in a later data-set root overrides the earlier registration within one game. Borrowing another game's content = listing its root; same-id claims by two non-borrowing games are a validator error, not layering. | [game-content](openspec/changes/add-game-definition-context/specs/game-content/spec.md) |

## Placement & Building

| Term | Meaning | Where |
|------|---------|-------|
| `foundation` | Data property: building size in cells as `EntityData.foundation` (Vector2i width × depth). Not derived, not runtime state. | [entity-data](openspec/specs/entity-data/spec.md) · scripts/data/EntityData.gd |
| `adjacent` | Max empty-cell gap (Chebyshev) allowed between a new footprint and friendly footprints at placement; `<= 0` = no requirement — diverges from TS (0 = must-touch, negative = disabled). | [building-manager](openspec/specs/building-manager/spec.md) · scripts/data/EntityData.gd |
| `footprint` | Runtime derived set of occupied cells computed from `foundation`: `FoundationComponent.footprint_cells()`. Never a data field. | [foundation-component](openspec/specs/foundation-component/spec.md) · scripts/components/FoundationComponent.gd |
| `bib` | Part of the building foundation: blocks everything the building foundation does, but pathfinding may still pass through bib cells at a cost (`bib_cost_penalty`). | [bib-pathfinding-penalty](openspec/specs/bib-pathfinding-penalty/spec.md) |
| build mode | BuildingManager lifecycle: pick entity → preview ghost → validate → place. | [building-manager](openspec/specs/building-manager/spec.md) |
| placing (EntityPlacer session) | Free-placement lifecycle: pick entity → ghost preview → place or cancel; no validity checks (unlike build mode). `EntityPlacer.is_placing()` is the placement-mode truth. Not "arming" — that word belongs to projectiles. | sidebar-ui-thinning change |
| placement blocking | Placement refused while moving units stand on the footprint. | [building-placement-blocking](openspec/specs/building-placement-blocking/spec.md) |
| free unit | Unit spawned automatically when a building is placed (`EntityData.free_unit`; refinery → harvester). | [free-unit](openspec/specs/free-unit/spec.md) |
| primary building | `FactoryComponent.is_primary` flag; ProductionManager routes production to it over same-type factories. | [primary-building](openspec/specs/primary-building/spec.md) |

⚠ Drift note: some `FoundationComponent` static methods name their Vector2i
parameter `footprint` while it actually receives the `foundation` size. Treat
those params as legacy — `foundation` = the data property, `footprint` = the
cell set.

## Grid & Cells

| Term | Meaning | Where |
|------|---------|-------|
| cell | Grid unit on the 2 m raster, addressed as `Vector2i`. Conversions: CellUtil. | [cell-util](openspec/specs/cell-util/spec.md) |
| sub-slot | Reserved position within a cell for units whose locomotor has `shares_cell = true`; mainly used by infantry. | [cell-occupancy](openspec/specs/cell-occupancy/spec.md) |
| shared slots | Max sharers per cell: `GlobalRules.shared_slots_per_cell`. | [global-rules](openspec/specs/global-rules/spec.md) |
| cell reservation | Present/coming occupancy registry so batching units don't collide mid-move. | [cell-reservation](openspec/specs/cell-reservation/spec.md) |
| blocked cells | Cells removed from pathing: idle-unit bodies, buildings (non-bib), resources. | [spatial-hash](openspec/specs/spatial-hash/spec.md) |
| SpatialHash | Entity-per-cell spatial index rebuilt every physics frame. | [spatial-hash](openspec/specs/spatial-hash/spec.md) |

## Map & Bounds

Two frames of reference — most "diamond vs rectangle" confusion is which frame
you're standing in.

**World frame** (top-down XY plane): cells are axis-aligned squares; map extents
are 45°-rotated rectangles, i.e. diamonds.

| Term | Meaning | Where |
|------|---------|-------|
| playable bounds (red diamond) | World-frame full map extent — a 45°-rotated rectangle; hard validity limit for entities/orders. | [rectangular-grid](openspec/specs/rectangular-grid/spec.md) |
| visible bounds (blue diamond) | Inset shrink of the red diamond via top/right/bottom/left insets; limiter for reveals/clamps/UI. | [rectangular-grid](openspec/specs/rectangular-grid/spec.md) |
| terrain diamond | Visual-only: the EditorGrid draw of the owned-cell raster. Same shape, different sense from the two above. | [rectangular-grid](openspec/specs/rectangular-grid/spec.md) |
| `isometric view` | The gameplay camera: Y=45°-yawed orthographic (`projection = 1`). Inverts the world picture: the whole map reads as an axis-aligned rectangle on screen while each cell reads as a screen diamond — the Tiberian Sun look. Consequence: picking and alignment math must rotate by ±45° (e.g. MouseHandler), and anything drawn world-axis-aligned (minimap footprint, EditorGrid) renders rotated on screen. | scenes/hud/Camera01.tscn · scripts/hud/CameraController.gd · scripts/editor/Minimap.gd:151 |
| `MapConfig` | Scene-level map configuration resource holding players and dimensions. | [map-config](openspec/specs/map-config/spec.md) |
| theater | Light look-tag (temperate/snow/…) affecting art only — never passability or movement. | [terrain-catalog](openspec/specs/terrain-catalog/spec.md) |
| grade | Per-cell integer height level (steps). | [terrain-grade](openspec/specs/terrain-grade/spec.md) |
| heightfield | Terrain collision authority; cells split by a crease diagonal into corner triangles. | [terrain-heightfield-collision](openspec/specs/terrain-heightfield-collision/spec.md) |

## Terrain & Land

| Term | Meaning | Where |
|------|---------|-------|
| `LandType` | Per-cell surface class ("clear", "water", …); drives locomotor passability/speed. | [land-types](openspec/specs/land-types/spec.md) |
| terrain speeds | `Locomotor.terrain_speeds`: land-type id → multiplier (0/absent = impassable for that locomotor). | [locomotor](openspec/specs/locomotor/spec.md) |
| `TerrainObject` | Authored directional terrain tile: per-cell land types, baked corner heights, crease, edge connection roles. | [terrain-object-catalog](openspec/specs/terrain-object-catalog/spec.md) |
| connection roles | Per-edge vocabulary describing how cliffs/ramps mate with neighbors. | [terrain-object-catalog](openspec/specs/terrain-object-catalog/spec.md) |
| resource land type | Cells under resource crystals resolve to the resource land type (drives movement and routing both). | [terrain-movement-costs](openspec/specs/terrain-movement-costs/spec.md) |

## Resources & Economy

| Term | Meaning | Where |
|------|---------|-------|
| crystal | Harvestable resource entity (e.g. TIBERIUM_RIPARIUS); self-grows and spreads. | [resource-growth-system](openspec/specs/resource-growth-system/spec.md) |
| tree | `ResourceTree` spawner entity that creates crystals within `radius_cells` up to `node_count`. | [resource-tree](openspec/specs/resource-tree/spec.md) |
| bale | Atomic raw-resource quantity carried/stored/spread (not credits; value applied at refinery). | [resource-harvesting](openspec/specs/resource-harvesting/spec.md) |
| resource category | Group id aggregating resource types (e.g. "tiberium"); basis for storage capacity and HUD totals. | [resource-storage](openspec/specs/resource-storage/spec.md) |
| resource type | Specific variant with `value`, `grow_rate`, color etc.; `ResourceType.parent_type` is a deprecated alias of `category`. | [resource-loadability](openspec/specs/resource-loadability/spec.md) · ResourceType.gd |
| deposited credits | Stored-resource balance subject to per-category storage capacity; what HUD displays (if `display_in_hud`). | [resource-storage](openspec/specs/resource-storage/spec.md) |
| free credits | Starting credits, sell refunds, crate bonuses, debug money — outside storage caps, excluded from the storage bar. | [player-data](openspec/specs/player-data/spec.md) · PlayerData.gd |
| storage capacity | Per-player per-category cap; refineries declare their own share via `EntityData.storage_capacity`. | [resource-storage](openspec/specs/resource-storage/spec.md) |
| production queue | Per-player list managed by ProductionManager; cost deducted gradually, multiple-factory speed bonus. | [production-manager](openspec/specs/production-manager/spec.md) |

## Power

| Term | Meaning | Where |
|------|---------|-------|
| power grid | Per-player aggregate of building power: `output` (Σ positive `power`) − `drain` (Σ \|negative\|). PowerGrid autoload is the authority; registered from tree add/remove of `PowerComponent`s. | [add-power-grid change](openspec/changes/add-power-grid/specs/power-grid/spec.md) · scripts/core/PowerGrid.gd |
| low power | Grid state where `sum < 0`; immediate on registry change. `drain = 0` grids are never low power. | [add-power-grid change](openspec/changes/add-power-grid/specs/power-grid/spec.md) |
| powered-down | Runtime offline state (`PowerComponent.is_online == false`) of a structure that *requires* power, under low power. Combat holds fire, radar reports offline, active anims pause. Producers never power down in this phase. | [add-power-grid change](openspec/changes/add-power-grid/specs/power-grid/spec.md) |
| build rate | Production speed multiplier from power: 1.0 healthy; in low power `lerp(worst, best, output/drain)` (defaults 0.3 → 0.75). Slows production, never halts it. | [add-power-grid change](openspec/changes/add-power-grid/specs/power-grid/spec.md) · [add-power-grid design](openspec/changes/add-power-grid/design.md) |
| power bar | TS-style twin bar on the sidebar's left edge: black column backing a green output fill with a red drain fill in front (red rises above green on deficit). Fills map through `(value/2000)^0.4` and ease toward live PowerGrid targets. | [add-power-grid change](openspec/changes/add-power-grid/specs/power-grid/spec.md) · scripts/ui/PowerBar.gd |

## Units & Combat

| Term | Meaning | Where |
|------|---------|-------|
| entity | Anything spawned from an `EntityData`: infantry, vehicle, building, aircraft, terrain, overlay, smudge. | [entity-factory](openspec/specs/entity-factory/spec.md) |
| warhead | Damage-application profile: base multiplier + per-armor-type multiplier table + effect flags. | [armor-types](openspec/specs/armor-types/spec.md) · WarheadData.gd |
| armor type | Target protection class; warhead's table keys select the final damage fraction. | [armor-types](openspec/specs/armor-types/spec.md) |
| projectile | Flight-behavior definition referenced by `WeaponData.projectile` string id. | [projectile-data](openspec/specs/projectile-data/spec.md) |
| veterancy | Promotion levels granting combat/speed/armor/rof multipliers, clamped at `veteran_cap`. | [global-rules](openspec/specs/global-rules/spec.md) |
| crusher / crushable | Vehicle flags; crushers destroy crushable targets standing in an entered cell. | [vehicle-crush](openspec/specs/vehicle-crush/spec.md) |
| `weight` | Crush pairing + ice-breakage threshold (`ice_cracking_weight`). Explicitly not a speed factor. | [entity-data](openspec/specs/entity-data/spec.md) · [ice-drowning](openspec/specs/ice-drowning/spec.md) |
| hitscan | Damage applied instantly at fire time, no projectile travel. | [combat-firing](openspec/specs/combat-firing/spec.md) |
| threat posed | AI targeting priority hint on EntityData. | [combat-firing](openspec/specs/combat-firing/spec.md) |
| flight model | Per-projectile behavior chosen by `ProjectileData` flags: teleport-detonate (`is_invisible`) vs real flight (straight + optional homing). One branch set inside ProjectileController — mirrors the locomotor pattern, not component nodes. | [projectile-system change](openspec/changes/archive/2026-08-27-projectile-system/specs/projectile-runtime/spec.md) · scripts/components/ProjectileController.gd |
| teleport-detonate | Invisible projectiles skip flight: spawn at the muzzle, position at the target coordinate, detonate at dispatch (same tick as the legacy hitscan path) through the hitbox pipeline. Behavior-preserving against the legacy hitscan path. | [projectile-system change](openspec/changes/archive/2026-08-27-projectile-system/specs/projectile-runtime/spec.md) |
| detonation trigger | Ordered first-match causes a projectile detonates: contact, close proximity while armed, overshoot (target distance stops decreasing), max range. Close detonations snap onto the victim's center. | [projectile-system change](openspec/changes/archive/2026-08-27-projectile-system/specs/projectile-runtime/spec.md) |
| arming | `ProjectileData.arm_delay` frames after spawn during which a projectile cannot detonate at all. Frame-based, not distance-based (original engine armed by distance). | scripts/data/ProjectileData.gd |

## Movement

| Term | Meaning | Where |
|------|---------|-------|
| locomotor | Registered movement-behavior class (`GlobalRules.locomotors`); sole authority on passability via terrain speeds. | [locomotor](openspec/specs/locomotor/spec.md) |
| movement zone | TS pathfinding domain-class metadata on EntityData; validated against the locomotor (`LOCOMOTOR_ZONES`) but doesn't gate passability. | [entity-data](openspec/specs/entity-data/spec.md) |
| climb tolerance | Max grade steps ascendable/descendable per cell transition. | [locomotor](openspec/specs/locomotor/spec.md) |
| hybrid locomotion | Hover / Jumpjet / Subterranean flags with distance thresholds deciding walk↔fly/dig switching. | [locomotor](openspec/specs/locomotor/spec.md) · [jumpjet-vertical-transitions](openspec/specs/jumpjet-vertical-transitions/spec.md) |
| speed ramp | Closed-form ramping of locomotor speed (accelerate/decelerate flags); targets move_speed directly with per-unit factors multiplying on top; crawl floor near arrival; resets at arrival/finish_stop. | [locomotor](openspec/specs/locomotor/spec.md) |
| greedy step | Pathfinder primitive: one-cell direct step toward goal when reachable without full A*. | [pathfinder](openspec/specs/pathfinder/spec.md) |
| greedy-first resolution | Try greedy step before computing an A* route. | [pathfinder](openspec/specs/pathfinder/spec.md) |
| stagnation fallback | Recovery when a unit stops making progress along its path. | [pathfinder](openspec/specs/pathfinder/spec.md) |
| height cost penalty | A* edge cost scaling with slope between cells. | [pathfinder](openspec/specs/pathfinder/spec.md) |

## Orders & Selection

| Term | Meaning | Where |
|------|---------|-------|
| order targeter | Component interface: each component declares which click targets it handles. | [order-system](openspec/specs/order-system/spec.md) · [entity-components](openspec/specs/entity-components/spec.md) |
| `OrderResult` | Funnel output data class mapping an input to per-entity orders. | [order-system](openspec/specs/order-system/spec.md) |
| docker | Unit docking at a building (e.g. harvester unloading); host rejects foreign dockers. | [dock-host-client](openspec/specs/dock-host-client/spec.md) |
| deploy / undeploy | Vehicle↔building transformation via `deploys_into` / `undeploys_into`. | [deploy-undeploy](openspec/specs/deploy-undeploy/spec.md) |
| stop command | Halts all selected units' activity; overridden by any later order. | [stop-command](openspec/specs/stop-command/spec.md) |
| fog-gated targeting | Enemy targets only orderable when revealed through shroud/fog. | [order-system](openspec/specs/order-system/spec.md) |
| exit | Production spawn point config (`spawn_offset`, `exit_offset`, `exit_facing`); rally point destination follows. | [production-exit](openspec/specs/production-exit/spec.md) |
| load / unload | Infantry entering (boarding) vs ejecting from a transport. Load requires a stationary transport with free seats and never queues; unload runs via the deploy command and ejects one passenger per interval. | [add-transport-passengers](openspec/changes/add-transport-passengers/specs/transport-passengers/spec.md) |

## Rendering & Audio

| Term | Meaning | Where |
|------|---------|-------|
| cameo | Sidebar build icon image (`ArtData.cameo_path`). | [cameo-tooltip](openspec/specs/cameo-tooltip/spec.md) |
| MultiMesh bucket | Per-region instanced render batch for baked unit models; slots compacted, transforms synced per frame. | [unit-multimesh-rendering](openspec/specs/unit-multimesh-rendering/spec.md) |
| ghost | Destroyed-entity silhouette retained under fog/shroud ("tombstone" for units, fog ghost for buildings). | [fog-rendering](openspec/specs/fog-rendering/spec.md) |
| revealer | Entity-side registration granting visibility stamps into ShroudSystem. | [fog-of-war](openspec/specs/fog-of-war/spec.md) |
| shroud vs fog | Shroud = permanently-explored-or-black grid; fog = re-covering dynamic layer. Independently toggleable. | [fog-of-war](openspec/specs/fog-of-war/spec.md) · [fog-rendering](openspec/specs/fog-rendering/spec.md) |

## Data Fields (high-drift picks)

Full dictionaries: scripts/data/*.gd. Only ambiguous pairs listed here.

| Term | Meaning | Where |
|------|---------|-------|
| `buildable_queue` vs `factory` | On produced entities: which queue they belong to vs on producing buildings: what they produce. Both strings reference the same namespace but point opposite directions. | scripts/data/EntityData.gd |
| `spawn_offset` vs `exit_offset` | Where a unit appears inside the building vs where it walks out to (local space). | [production-exit](openspec/specs/production-exit/spec.md) |
| `passengers` vs `storage` | Infantry seat count on transports vs raw-bale carry capacity on harvesters. | scripts/data/EntityData.gd |
| `pip_color` | Seat pip color for a passenger riding in a transport (per entity type, default white); harvesters' cargo pips are unaffected. | scripts/data/EntityData.gd |
| `strength` | Max hit points (legacy rules.ini name — do not rename casually). | scripts/data/EntityData.gd |
| `tech_level` | Build availability gate; -1 = always available. | scripts/data/EntityData.gd |
| `powered` vs `is_online` | Data-level "requires power to function" flag (`EntityData.powered`, copied to PowerComponent) vs runtime state (`PowerComponent.is_online`, driven by the grid). Deliberately different names — never write `is_powered()` for the runtime state. | scripts/data/EntityData.gd · [add-power-grid change](openspec/changes/add-power-grid/specs/power-grid/spec.md) |

## Undecided

User-owned choices — do **not** guess these when writing specs; ask, then record
the decision here.

- `archetype` vs `template` vs `type` — no decision yet. Note: `archetype`
  appears nowhere in code or specs today; `template` currently means only TS
  `.tem` terrain templates ([isotem-tooling](openspec/specs/isotem-tooling/spec.md)).
