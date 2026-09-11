# Load factions from game data sets and drop the hardcoded faction roster

## Why

The data-driven contract says a game is data + assets only. Faction resources
(`Faction.gd`, `games/ts/factions/*.tres`) exist, but nothing loads them: the
registry has zero consumers, and player identity, sidebar cameo colors, and the
map house vocabulary are hardcoded in three separate places. This makes the
faction roster impossible to change per game and silently couples engine code to
Tiberian Sun's GDI/Nod ids — exactly what the game-content contract forbids.

## What Changes

- Add a `FactionCatalog` autoload that registers `<layer root>/factions/` on boot
  and on `game_changed`, scanning `.tres` resources and caching them by id,
  mirroring `EntityFactory` / `TerrainCatalog` / `AudioManager`.
- Extend `Faction.gd` with `order` (int, explicit roster index) and `playable`
  (bool, whether the faction appears in the default roster). This makes the
  roster ordered and index-stable rather than an unordered directory scan.
- Ship `neutral.tres` and `special.tres` as non-playable factions so the loaded
  resource set is the complete house vocabulary (GDI, Nod, Neutral, Special).
- `PlayerManager._init_defaults` selects the default roster from the loaded
  factions (first two playable by `order`) and takes their colors from the
  resources instead of hardcoding `"GDI"`/`"Nod"` and RGB values.
- `Sidebar._get_cameo_color` resolves the tint from the faction registry instead
  of the hardcoded `CAMEO_COLORS` dictionary.
- **BREAKING** `Houses.ID`/`DISPLAY_NAMES` stop being hardcoded constants and
  become a projection of the ordered faction roster; direct field consumers use
  accessors and the legacy `player_id` → house index alias is preserved.
- Deliberately skip extracting a shared directory scanner (see design).

## Capabilities

### New Capabilities

- `factions`: the `Faction` resource shape (id, display name, color, order,
  playable), the `FactionCatalog` registry loaded from each game's `factions/`
  data-set subdirectory, ordered playable-roster access, and lifecycle
  (reset/reload on game switch).

### Modified Capabilities

- `game-content`: the ordered data-set layer-root convention gains the
  `factions/` consumer subdirectory.
- `player-manager`: the no-MapConfig default roster is derived from the loaded
  faction registry instead of hardcoded GDI/Nod values, and the autoload order
  is corrected to `GameContext` → `FactionCatalog` → `PlayerManager`.
- `map-houses`: the canonical house id vocabulary is projected from the ordered
  faction roster instead of a hardcoded `IDS`/`DISPLAY_NAMES` list.

## Impact

- New: `scripts/core/FactionCatalog.gd`, `games/ts/factions/neutral.tres`,
  `games/ts/factions/special.tres`, `test/unit/test_faction_catalog.gd`,
  faction fixtures under `test/fixtures/`.
- Changed: `project.godot` (autoload registration and order), `scripts/data/Faction.gd`,
  `scripts/data/Houses.gd`, `scripts/core/PlayerManager.gd`, `scripts/ui/Sidebar.gd`.
- Tests touched: `test/unit/test_houses.gd`, `test/unit/test_player_manager.gd`,
  `test/unit/test_game_content.gd`.
- No `.tscn` changes; no gameplay logic added under `games/`.
