## Why

The gameplay minimap shipped in `add-gameplay-minimap` renders unconditionally, but the archived design deferred the radar gate:

> Radar gating (minimap hidden until a radar structure exists) — deferred to #40/#246.

`RadarComponent` still stores a boolean with no consumer (`has_radar()` has zero callers outside tests), so a player with no radar structure gets a free full-map minimap. Power dependency is already wired (`PowerGrid` sets `PowerComponent.is_online`, and `has_radar()` honors it), so the only missing link is turning "this player owns an online radar" into a minimap on/off state — with the Tiberian Sun offline feedback (a static-noise transition and a dead panel) and a debug override so the gate can be exercised without building a radar.

## What Changes

- **New `RadarSystem` autoload**: tracks every `RadarComponent` via scene-tree add/remove signals and maintains per-player radar availability (`player_has_radar(player_id)`), emitting `radar_availability_changed(player_id)` when a player's availability flips.
- **`RadarComponent` gains `radar_state_changed(is_active: bool)`**: fired when the component's effective radar state flips — including power-driven flips via the sibling `PowerComponent.power_state_changed` — so availability tracking is event-driven, never polled.
- **Minimap radar gate**: when the local player has no online radar, the minimap enters an offline state — black panel with an `OFFLINE` placeholder label, no fog/entity composition, no camera view rectangle, and no click command handling. When the player gains or loses radar, a static-noise transition eases in and out over the panel. The existing `UIUtil.is_mouse_over_minimap()` guards continue to keep world handlers off the minimap region in both states.
- **Debug override**: a `Force radar online` checkbox in the debug menu sets `RadarSystem.force_online`, overriding the availability result for all consumers; reset with the other cheats on scene change.
- **New UI static shader**: `shaders/ui/RadarStatic.gdshader`, a `TIME`-driven noise overlay drawn on the minimap during transitions.

## Capabilities

### New Capabilities
- `radar`: Per-player radar availability aggregation (`RadarSystem`), the `RadarComponent` state signal and query contract, and the debug force-online override.

### Modified Capabilities
- `gameplay-minimap`: The minimap is no longer unconditionally live — it is gated on local-player radar availability, with an offline placeholder, a static transition, and suppressed input/composition while offline.
- `debug-menu`: The cheat set gains a `Force radar online` toggle that overrides radar availability, reset on scene change.

## Impact

- **New scripts**: `scripts/core/RadarSystem.gd` (autoload), `shaders/ui/RadarStatic.gdshader`.
- **Modified scripts**: `scripts/components/RadarComponent.gd` (state signal), `scripts/ui/Minimap.gd` (gate, offline placeholder, transition), `scripts/ui/DebugMenu.gd` (override toggle), `project.godot` (autoload registration).
- **Modified scene**: `scenes/ui/DebugMenu.tscn` (checkbox), `scenes/ui/Minimap.tscn` (static overlay child/node wiring if needed).
- **Docs**: `GLOSSARY.md` gains a `radar gate` entry.
- **No breaking changes**: packed scenes stay loadable; the minimap still instantiates the same way and remains inert in the runtime MapEditor. Radar-less maps simply start with the minimap offline.
- **Overlap**: this is the mechanism half of #246 (`feat: radar/minimap — GDI1 base radar`); #246's map content exercises it.
