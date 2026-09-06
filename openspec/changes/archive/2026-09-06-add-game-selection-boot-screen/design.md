# Design: Game selection boot screen + --game CLI flag

## Context

#375 landed the core: `GameContext` (first autoload) resolves a game at `_ready()` (`--game` → persisted `[game] id` → default `"ts"`), discovers `res://games/*/game.tres`, exposes `list_games()` / `select_game(id)` / `save_game_choice(id)`, and consumers (EntityFactory, TerrainCatalog, AudioManager) register from `GameContext.current` in their own `_ready()` and re-register on `game_changed`. `select_game("")` (unload) and all seams exist and are spec'd in `openspec/specs/game-context/`.

Current boot: `MainScene.tscn` (Window root, no script) → `HUD/UI` hosts `MainMenu01` (visible, TS-specific; `New Campaign` → `change_scene_to_file(TestMap02.tscn)`) and `LoadingScreen` (hidden). MainMenu01's `_input` hit-tests `MainMenuItem01` label rects on **any** mouse press — including buttons hidden under an overlay. No options menu exists anywhere (MainMenu01's `Options` item falls through to a print placeholder). `games/ts/game.tres` has `maps_dir = ""`.

Key consequence of the core: **GameContext always has a resolved game before MainScene loads.** The boot screen is therefore a launcher overlay on an already-valid state, not a gate on a null state.

## Goals / Non-Goals

**Goals:**
- Launcher shown every boot without `--game`: one row per discovered game (`display_name`), plus `Options` (placeholder) and `Quit`
- Pick → `select_game` (skip if already active) → `save_game_choice` → land on the game's main menu
- `--game` skips the launcher before the first frame (no flash); today's boot flow preserved
- Right-click/ESC dismiss → proceed with the already-resolved game; never stuck
- Headless-testable without process relaunch, following the #375 seam conventions

**Non-Goals:**
- Real options UI (placeholder parity with MainMenu01)
- Per-game menu scenes, per-game visual theming of the launcher, `maps_dir` consumption, map selection — content-pack / later-phase work (#377+)
- Any GameContext or GameDefinition API change

## Decisions

### D1 — BootScreen as a sibling overlay in MainScene, self-gated in `_ready()`
`scenes/ui/BootScreen.tscn` instanced in `HUD/UI` after `MainMenu01` (later sibling = draws on top). Its script checks the flag itself and either hides (`--game`) or shows + builds rows.

*Alternatives:* making BootScreen the project main scene (scene churn, flag check happens after a visible frame — fails "no menu flash"); a MainScene root script orchestrating visibility (new script + coupling for two visibility toggles); wrapping BootScreen inside MainMenu01.tscn (conflates TS content with the generic launcher — exactly the mistake this change corrects).

### D2 — MainMenu01 visibility toggled AND its `_input` visibility-guarded
BootScreen's `_ready()` sets the MainMenu01 sibling `visible = false`; a pick restores it. *Implementation amendment:* hiding alone turned out insufficient — Godot delivers `_input` to hidden nodes (PauseMenu's ESC handler relies on the same while hidden), so MainMenu01's rect hit-test would still fire under the launcher. The root-cause fix is a one-line `if not visible: return` guard at the top of `MainMenu01._input` (BootScreen's own handlers gate on `visible` the same way), which also closes the same latent bug for any future overlay (e.g. LoadingScreen). Rationale for hiding anyway: occlusion is the visual contract; the guard is the input contract. Two sibling accesses beat a new orchestrator script.

### D3 — Flag gate as a static pure function
`static func should_skip(args: PackedStringArray) -> bool` returning `GameContext.extract_flag_id(args) != ""` (checks both `OS.get_cmdline_args()` and `OS.get_cmdline_user_args()` via the existing helper). `_ready()` calls it with real args. Mirrors #375's testability pattern (`extract_flag_id`, `resolve_game_id` are static for the same reason: process args can't be injected at runtime) and keeps the skip branch testable in-process.

### D4 — Pick = select → save, with a same-id guard
`pick(id)`: if `GameContext.current.id != id` call `select_game(id)` (validated, emits `game_changed`, consumers re-register); then `save_game_choice(id)`; then hide + reveal menu. The guard avoids a full consumer reset/re-register when the player picks the already-resolved game (the common case for a single-game install). Save happens after select so a refused selection (invalid rules — same validation ran at boot, but defense in depth) never persists a broken choice. Cancel never saves.

### D5 — ESC quits; right-click does nothing
ESC (the `pause` action — the binding PauseMenu already uses) exits the application via the same `_quit()` the Quit row uses: the launcher is the front door, and backing out of it means not playing. Right-click is deliberately unhandled — the project's right-click-is-cancel convention has nothing to cancel before a game exists, and an unhandled right-click is a no-op by construction. *Revision:* the original design dismissed to the already-resolved game's menu on right-click/ESC ("returns sensibly"); the user chose the AC's "quits" branch instead — no right-click trigger, ESC quits.

### D6 — Rows as plain placeholder buttons on a neutral background
Runtime-built standard `Button`s in the `Rows` VBoxContainer: one per discovered game (label = `display_name`, falling back to `id`; game id kept in meta and bound via `pressed`), a disabled `Options` placeholder, and `Quit`. Background is a neutral full-rect `ColorRect`. The launcher references zero per-game assets — TS art stays in TS content, and per-game boot theming ships with the content packs. *Revision:* the original design reused `MainMenuItem01` plus MainMenu01's background under the issue's "current main-menu styling" line, but the user clarified the launcher must stay game-agnostic — MainMenu01 is TS content, and only placeholder elements belong here. Signal-based buttons also deleted the label-rect hit-testing machinery.

### D7 — Launch target stays MainMenu01
The issue's "main menu loads" is kept literally: after a pick the player lands on MainMenu01 (today, TS's). Per-game menus are a content-pack concern (#378+); when those land, the reveal target becomes "the resolved game's menu" — the seam is noted in code.

## Risks / Trade-offs

- [Clicks passing through to hidden MainMenu01] → D2 hides the sibling; tests assert MainMenu01 hidden while launcher visible.
- [`select_game` re-register cost on game switch at boot] → synchronous dir scans + `.tres` loads, already paid at boot once; same-id guard (D4) avoids the common double pay. Acceptable for a one-shot launcher.
- [Empty `list_games()` (no `res://games/` at all)] → GameContext falls back to default `ts`, which is always in-repo; launcher would show zero game rows but Options/Quit still work. No special-casing.
- [BootScreen visible one frame with `--game` if `_ready()` ordering slips] → `_ready()` runs before the first draw; the hide happens there, so no flash. Covered by an assert-style test on visibility after instantiation.
- [Quit row killing the test runner if tests click it] → tests never invoke the quit handler; it is a one-line `get_tree().quit()` with no logic worth testing.

## Migration Plan

Additive: one scene, one script, one instanced node in MainScene.tscn, one comment fix, one test file. No API or scene-path changes; rollback = delete the instance node and the two new files.

## Open Questions

None — flow, ESC-quit semantics, placeholder Options, and the MainMenu01 landing target were settled in exploration and the follow-up review round.
