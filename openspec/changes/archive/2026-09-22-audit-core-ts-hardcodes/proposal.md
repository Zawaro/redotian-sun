## Why

The multi-game architecture (GameDefinition + GameContext, #375–#377) landed a data-driven
content layer, but core systems still assume Tiberian Sun behavior: hardcoded TS numeric
constants (twin-bar power scale, ROF time base, refinery unload rate, homing ROT units,
harvester search radius), TS content strings branched directly in the factory (`"tiberium_tree"`,
`"ICE"` legacy-id prefix), TS-only mechanics with no on/off gate (breakable ice, the twin power
bar, tree-seeded crystal growth), TS assets baked into shared UI scenes, and inert
`GlobalRules` stubs (`visceroids`, `meteorites`, `weed_capacity`, `crew_escape`) that look live
but have no consumer. This breaks the "core supports all games via data toggles" contract and
must be resolved before the FS/RA2/YR content packs (#378–#380) can exercise it.

## What Changes

- **`GameDefinition.features`** — add the approved String→bool feature-toggle dictionary (#374)
  plus `has_feature(id)`, with a null-safe `GameContext.has_feature(id)` read-through.
- **Numeric extraction to `GlobalRules`** — power-bar scale/curve, logic FPS (ROF time base),
  refinery unload rate, homing turn conversion, harvest search radius; locomotor slope
  coefficients move onto the `Locomotor` resource, dropping the `"Track"`/`"Wheel"` string match.
- **Content strings → data flags** — `EntityData.breakable_surface`, `EntityData.resource_spawner`
  and a procedural-visual flag replace the `"ICE"` prefix and `"tiberium_tree"`/`"tiberium"`
  branches in `EntityFactory`/`EntityPlacer`; `EntityData.harvestable_categories` +
  `HarvestComponent.configure()`; neutral resource defaults; HUD/currency category no longer
  hardcodes `"tiberium"`.
- **Feature-gated TS mechanics** — `breakable_ice`, `resource_tree_regrowth`;
  flag off ⇒ behavior absent, no errors. Inert `GlobalRules` stubs resolved (removed or made
  real off-by-default features).
- **UI + art data-driven** — sidebar tabs built from per-game tab configuration, per-game menu
  theming (background + palette) sourced from data, resource crystal art moved to
  `ArtData`/`ResourceType`, terrain fallback scene declared by the game definition, slope tile
  families derived from catalog data. Dead `MainMenu01_old.tscn` deleted.
- **Cleanup** — internal `tib_*` identifiers → `res_*`, misleading TS comments neutralized,
  duplicated land-type sentinels deduped. Glossary-canonical terms (`bale`, `crystal`, `tree`,
  `resource category`, `power bar`) are **not** renamed.
- **Deferred (documented, not fixed here)** — map-format constants (`CELL_SIZE`, `HEIGHT_STEP`,
  `MAX_HEIGHT`, 50×50 grid defaults) and TS/YR-exclusive mechanics (superweapons, mind control,
  cloning, tech buildings, prism/tesla chaining, ion storms, visceroids, meteorites, crew escape)
  become follow-up issues under #374.

No new subsystems: toggles ride the approved `GameDefinition.features`; all numeric/behavioral
values ride `GlobalRules`; content variation rides existing data resources.

## Capabilities

### New Capabilities
- `feature-flags`: `GameDefinition.features` (String→bool) and the `has_feature` accessor
  contract, including flag-off-must-be-inert behavior and unknown-id handling.
- `game-menu`: per-game main-menu background and accent theming sourced from the game
  definition, with scene defaults when absent.

### Modified Capabilities
- `game-context`: `GameDefinition` resource shape gains `features`; GameContext exposes a
  null-safe feature read.
- `global-rules`: new power-bar, logic-FPS, refinery-unload and homing-turn
  fields, plus `primary_resource_category`; removal/repurposing of inert `visceroids`/`meteorites`/`weed_capacity`/`crew_escape`.
- `power-grid`: power-bar scale/curve sourced from rules rather than compile-time constants.
- `combat-firing`: weapon rate-of-fire time base read from rules.
- `locomotor`: uphill/downhill slope coefficients move from core constants to the resource.
- `entity-data`: `breakable_surface`, `resource_spawner`, procedural-visual and
  `harvestable_categories` fields.
- `entity-factory`: content-shape branches keyed on data flags, not TS id strings.
- `resource-harvesting`: harvestable categories from entity data.
- `resource-growth-system`: tree-seeded growth gated by `resource_tree_regrowth`.
- `resource-storage`: active-game currency category replaces the `"tiberium"` literal.
- `ice-drowning`: breakable-surface behavior gated by `breakable_ice`.
- `pathfinder`: ice footing only when the mechanic is enabled.
- `sidebar-build-order`: tab set/entity-type mapping built from per-game configuration.
- `terrain-catalog`: fallback terrain scene declared by the game definition; slope families
  derived from catalog data.

## Impact

- Scripts: `scripts/core/{GameContext,ResourceGrowthSystem,Pathfinder,SpatialHash,TerrainCatalog,TerrainSystem,AudioManager,UIUtil}.gd`,
  `scripts/data/{GameDefinition,GlobalRules,EntityData,Locomotor,ResourceType}.gd`,
  `scripts/components/{CombatComponent,DockUnloadComponent,ProjectileController,HarvestComponent,MovementController,IceComponent,ResourceComponent,ResourceTreeComponent,SelectComponent}.gd`,
  `scripts/entities/{EntityFactory,EntityPlacer}.gd`,
  `scripts/ui/{Sidebar,PowerBar,MainMenuItem01}.gd`, `scripts/economy/EconomyManager.gd`.
- Scenes: `scenes/ui/Sidebar.tscn`, `scenes/ui/MainMenu01.tscn` (theming source), removal of
  `scenes/ui/MainMenu01_old.tscn`; `games/ts/game.tres` gains a `features` block.
- Data: `games/ts/global_rules.tres` gains the new fields; resource/entity `.tres` gain the new
  flags where TS uses them.
- Tests: new flag on/off and sourcing tests using synthetic game fixtures; updates to
  `test_sidebar_power_ui`, `test_harvest_dock`, `test_resource_growth_system`,
  `test_terrain_catalog`, `test_ice_drowning`, `test_game_context`.
- Backward compatibility: existing `games/ts` content keeps identical behavior — extracted
  rule defaults equal today's literals, and flags default to inert so games that omit
  `features` are unaffected.
- Dependency: full cross-game verification (flags on/off per real game, 4-game boot) waits on
  #378–#380; this change proves it with fixtures.
