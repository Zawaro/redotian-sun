## Context

`Faction.gd` and `games/ts/factions/*.tres` exist but have zero consumers. Faction
identity is hardcoded in three places: `PlayerManager._init_defaults`
(`"GDI"`/`"Nod"` + RGB), `Sidebar.CAMEO_COLORS` (owner → color), and
`Houses.IDS`/`DISPLAY_NAMES` (the house vocabulary). The game-content contract
says a game is data + assets only, so the roster must be loadable per game.

Two properties of the domain constrain the design:
- The house roster is an **ordered index**: legacy map `player_id` values alias
  onto house indices (`MapLoader`, `EditorSaveLoad`), and `EntityData.owner`
  strings must keep matching house ids. A directory scan is unordered, so the
  roster cannot be derived from scan order.
- `PlayerManager._ready()` needs factions at boot, but the existing content
  consumers (`EntityFactory`, `TerrainCatalog`, `AudioManager`) run late in the
  autoload order. A registry placed with them would not be visible in time.

## Goals / Non-Goals

**Goals:**
- Load faction resources from every game `data_sets/<root>/factions/` on boot and
  on game switch, mirroring the existing per-content-type catalogs.
- Make the ordered, playable roster data-driven, with stable indices.
- Drive the default player roster, sidebar cameo colors, and the house vocabulary
  from the loaded factions.
- Keep the change testable with non-game-specific fixtures.

**Non-Goals:**
- Wiring faction ids into `PrerequisiteSystem` / build gating (a natural follow-up
  once `faction_id` is reliable, but out of scope here).
- Reworking MapConfig-based player setup or the map load path.
- A generic shared directory scanner across all catalogs.
- Any gameplay logic under `games/` — new files there are data only.

## Decisions

### D1: A `FactionCatalog` autoload, registered right after `GameContext`

Mirror `TerrainCatalog`/`AudioManager`: own a `Dictionary` cache, a
`register_data_set(path)` scan, `reset_content()`, and a `game_changed`
connection. Place it in `project.godot` **between `GameContext` and
`PlayerManager`** so `PlayerManager._ready()` can read it.

- Alternatives: fold the registry into `GameContext` (blurs resolution with
  content), or into `PlayerManager` (makes the player registry own content
  loading and forces `Houses`/`Sidebar` to depend on players). A dedicated
  consumer autoload matches the established pattern and keeps ownership clean.
- Consequence: the stale `player-manager` spec claims PlayerManager is the first
  autoload; this change corrects that requirement to
  `GameContext → FactionCatalog → PlayerManager → rest`.

### D2: Explicit `order` and `playable` fields on `Faction`

`Faction` gains `order: int` (canonical roster index) and `playable: bool`
(default-roster eligibility). Roster order comes from `order`, tie-broken by `id`
for determinism. `playable: false` marks passive houses.

- Alternatives: rely on filesystem scan order (unstable and breaks legacy
  `player_id` aliasing); numeric filename prefixes (implicit and easy to break);
  a separate ordered list in `GlobalRules` (splits faction data across two
  files). An explicit field keeps each faction self-describing.
- This mirrors the original indexed `[Houses]` vocabulary while staying
  data-driven.

### D3: Ship Neutral and Special as non-playable faction resources

Add `games/ts/factions/neutral.tres` and `special.tres` with `playable = false`,
`order` 2 and 3. The loaded resource set is then the complete house vocabulary,
so `Houses` has a single source.

- Alternative: keep Neutral/Special as engine constants. Rejected — they are
  real houses in the rules-side list and appear as `EntityData.owner` values
  (`Neutral` ships in data), so treating them as factions removes the last
  hardcoded roster entries.

### D4: `Houses` is a projection snapshot applied by `FactionCatalog`

`Houses` stays a static helper module but its id/display-name arrays become
static state populated by `FactionCatalog.apply_roster()` / `clear_roster()` on
load and reset. `id_for`/`index_for`/`display_name_for` keep their signatures; a
new ordered-id accessor replaces direct `Houses.IDS` reads (`MapLoader`).
Before any roster is applied, `id_for` returns `""` and `index_for` returns `-1`.

- Alternatives: have static helpers reach the autoload via
  `Engine.get_main_loop()` (harder to test, hidden coupling); convert `Houses`
  into an instance autoload (churns the map-houses contract and its callers).
  A snapshot is small, deterministic, and directly testable.
- `Houses.IDS` changing from a `const` to mutable static state is the breaking
  API change called out in the proposal.

### D5: Default roster selection and rules access in `PlayerManager`

`_init_defaults()` reads `FactionCatalog`'s ordered playable list: player 0 gets
the first playable faction, player 1 the second, each with the faction's `color`.
If fewer than two playable factions are loaded, the missing slot uses `""` and
`Color.WHITE`. Also replace `_get_global_rules()`'s `/root/EntityFactory` lookup
with `GameContext.rules`, which is already resolved at PlayerManager's
`_ready()` — this removes a latent ordering bug where `starting_credits` always
fell back to 10000 because EntityFactory did not exist yet.

### D6: Sidebar resolves cameo tint from the registry

Replace `CAMEO_COLORS` with a lookup over `FactionCatalog`'s ordered roster,
matching `EntityData.owner` substrings to faction ids and returning the faction
`color`; unmatched owners fall back to `Color.GRAY`.

### D7: Do NOT extract a shared directory scanner

The three (soon four) `_scan_directory` copies stay. The reusable, low-risk part
is the `.tres`/`.remap` recursion, but a shared scanner would touch three working
autoloads and their tests for a modest line saving; per-content-type scanning is
also the established shape here. Leave a `ponytail:` note at the new scan
pointing at the duplication's upgrade path (a shared recursive
`resources_in(path)` helper) if a fifth consumer appears.

## Risks / Trade-offs

- [Static `Houses` state leaks between tests] → `FactionCatalog` clears the
  snapshot on reset; tests set the roster explicitly from fixtures and restore it.
- [`Houses.IDS` const → static var breaks callers] → update the two known readers
  (`MapLoader`, `EditorSaveLoad`) and the tests in the same change; grep for
  `Houses.IDS` before finishing.
- [Faction ids must match `EntityData.owner` casing exactly] → keep ids as the
  shipped strings (`GDI`, `Nod`, `Neutral`, `Special`); add a test asserting the
  roster ids cover the owner vocabulary.
- [Duplicate `order` values make the roster ambiguous] → tie-break by `id`
  ascending and cover it with a test.
- [Autoload insertion could surprise boot-order assumptions] → only ordering
  comments and the corrected `player-manager` requirements change; no packed
  scene references autoloads by index.
- [Late game-switch leaves PlayerManager's roster stale] → pre-existing behavior
  (the roster is built once at `_ready`); out of scope, but noted so it is not
  mistaken for a regression.

## Migration Plan

1. Add `FactionCatalog` and register it after `GameContext` in `project.godot`.
2. Extend `Faction.gd`; add `order`/`playable` to `gdi.tres`/`nod.tres`; add
   `neutral.tres`/`special.tres`.
3. Repoint `PlayerManager`, `Sidebar`, and `Houses` at the registry.
4. Update/replace tests and add fixtures. No saved-data migration is required —
   faction ids and house index order are unchanged.

## Open Questions

- Should `Houses` eventually be retired in favour of reading `FactionCatalog`
  directly, or is the projection snapshot the intended long-term shape?
- Does `order` need to be globally unique, or is per-game uniqueness sufficient
  (currently per-game, since registries reset per game)?
