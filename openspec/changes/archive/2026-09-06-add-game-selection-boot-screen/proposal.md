# Proposal: Game selection boot screen + --game CLI flag

Part of the multi-game support roadmap (#374), phase 2 of 8 (#376). Builds on the GameDefinition/GameContext core landed in #375.

## Why

There is no way to choose which game to play at runtime, and no CLI override for devs/CI to target one deterministically. GameContext already resolves a game at boot (`--game` → persisted → default), but nothing surfaces that choice to the player: the app boots straight into the TS-specific MainMenu01, and switching games requires editing the settings file by hand. The boot screen is the player-facing half of the "single binary, launcher selection menu" decision approved in #374.

## What Changes

- New `BootScreen` scene (`scenes/ui/BootScreen.tscn` + `scripts/ui/BootScreen.gd`) shown at boot, using plain placeholder controls (standard buttons on a neutral background) so the launcher references no per-game content:
  - One row per discovered GameDefinition (`GameContext.list_games()`), labeled with `display_name`
  - An `Options` row (disabled placeholder — no options UI exists yet, mirroring MainMenu01's current placeholder behavior)
  - A `Quit` row (exits the app)
- BootScreen is the **game-agnostic launcher**: it owns Options/Quit and uses no per-game assets because the existing MainMenu01 (and its TestMap02 target) is Tiberian Sun content and cannot be relied on for generic actions; per-game visual theming ships with the content packs
- Selection flow: pick a game → `GameContext.select_game(id)` (skipped when the id is already active, avoiding a wasteful re-register) → `GameContext.save_game_choice(id)` → BootScreen hides, MainMenu01 shows
- Exit paths: the `Quit` row and ESC exit the application; right-click does nothing (there is nothing to cancel before a game exists) — the launcher is always escapable, never stuck
- `--game <id>` skips the launcher entirely: BootScreen hides itself in `_ready()` before the first frame draws (no menu flash); boot lands on the game's main menu as today
- MainMenu01 is hidden while the launcher is visible (its `_input` hit-tests label rects even when visually covered, so covering alone is not safe)
- Known seam, deliberately deferred: with multiple games, picking a game lands on whatever menu scene MainScene hosts (today TS's). Per-game menus belong to the content packs (#378+)
- GameDefinition `maps_dir` doc comment corrected — it claims the boot screen consumes it; map selection is a later phase and `maps_dir` stays unconsumed
- Out of scope (per issue): per-game visual theming of the BootScreen; consuming `maps_dir`

## Capabilities

### New Capabilities
- `game-selection-boot-screen`: The boot-time launcher that lists discovered games and routes the player into a game (or its menu), including the `--game` skip path and the Quit/ESC exit paths

### Modified Capabilities

None — the `game-context` spec already covers discovery, selection, persistence, and flag resolution; the boot screen only consumes that existing contract. Consumer registration behavior (EntityFactory/TerrainCatalog/AudioManager) is likewise unchanged.

## Impact

- **New**: `scenes/ui/BootScreen.tscn`, `scripts/ui/BootScreen.gd`, `test/unit/test_boot_screen.gd`
- **Modified**: `scenes/MainScene.tscn` (one instanced node added after MainMenu01 so the launcher draws on top), `scripts/data/GameDefinition.gd` (one doc-comment line)
- **No changes** to GameContext, GameDefinition fields, MainMenu01, or any consumer autoload
- **Behavior change for players**: without `--game`, boot now shows the launcher before the TS main menu (with only `ts` discovered, the list has one game plus Options/Quit). Devs/CI passing `--game <id>` see today's boot flow unchanged
- **Scene compatibility**: MainMenu01.tscn and LoadingScreen.tscn are reused unmodified; the boot screen itself references zero per-game assets (no `res://games/` paths), keeping the launcher game-agnostic; MainScene.tscn gains a sibling node, no existing node paths change
