## Context

The gameplay minimap (`scripts/ui/Minimap.gd`) renders unconditionally, and `RadarComponent` is a data holder whose only query, `has_radar()`, has no runtime caller. The `add-gameplay-minimap` change explicitly deferred the radar gate to #40/#246, and the power dependency is already live: `PowerGrid._fan_out` calls `PowerComponent.set_online(false)` on a low-power grid, and `has_radar()` already returns false while `is_online == false`.

Constraints: pure GDScript; packed scenes must remain loadable; the minimap must stay inert in the runtime MapEditor; several gameplay input handlers poll the `Input` singleton and rely on `UIUtil.is_mouse_over_minimap()` to ignore the minimap region; the minimap already refreshes fog/overlays at a fixed low rate (0.5 s) in `_process`.

## Goals / Non-Goals

**Goals:**
- A single source of truth for "does this player have radar", covering every spawn/destroy path and power-driven shutdown.
- Radar-gated minimap: offline placeholder when unavailable, live rendering when available, with no per-frame polling of the scene tree.
- Tiberian-Sun-style static-noise transition on radar availability flips.
- A debug override that forces radar availability without owning a radar structure.

**Non-Goals:**
- Radar jamming (enemy suppression fields) — future phase, noted in #40.
- A radar-driven shroud/fog reveal layer — reveal is owned by `VisionComponent`; radar only switches the minimap.
- Sidebar art for the offline panel — the black `OFFLINE` label is an explicit placeholder until sidebar art exists.
- Enemy/friendly-only minimap filtering beyond what the fog system already does.
- Networking.

## Decisions

### New `RadarSystem` autoload over a minimap-local scan

`RadarSystem` mirrors `PowerGrid`'s registry idiom: register every `RadarComponent` via `get_tree().node_added` / `node_removed`, resolve the owner through the parent's `StatsComponent.player_id`, and cache a per-player availability flag. Rationale: the availability query has more than the minimap as a future consumer (radar-dependent AI, minimap pings, #246 mission logic), the registry gives clean edge-triggered `radar_availability_changed` for the transition animation, and it keeps the minimap from reaching into arbitrary entity trees.

Alternative considered: scan the `entities` group inside the minimap's 0.5 s refresh and call `has_radar()` on each. Rejected — cheapest in the short term, but it re-derives availability every tick, gives no signal to drive the transition edge, and duplicates when a second consumer appears.

### Event-driven state, no polling

Power is the only thing that flips a radar's effective state outside node add/remove, and `PowerGrid` already fans power changes out as `PowerComponent.power_state_changed`. `RadarComponent` connects to its sibling `PowerComponent` and re-emits `radar_state_changed(is_active)` only on an actual flip; `RadarSystem` consumes that signal to update its per-player count incrementally. Registration/unregistration covers placement, map load, deploy, sale, and destruction. No `_process` scan anywhere.

Alternative considered: `RadarSystem` polls `has_radar()` each frame or listens to `PowerGrid.grid_state_changed` and re-scans. Rejected — per-frame work for a state that changes on events, and the signal contract is cleaner to test.

### Availability = count of online radars, with override at the query

`RadarSystem` keeps an integer online-radar count per player; `player_has_radar(pid)` returns `force_online or count > 0`. The `force_online` flag lives on `RadarSystem` and the debug-menu checkbox writes through to it, keeping one source of truth rather than a group-read flag that only the minimap honors.

### Offline is a black `OFFLINE` panel; static is the transition

Steady offline state is a black minimap rect with centered `OFFLINE` text — a deliberate placeholder until sidebar art lands. Static noise is the *transition*: on each availability flip a noise overlay's intensity eases in (radar lost) or out (radar gained) over a short duration, then settles to the steady state with no residual static. The offline placeholder is drawn with CanvasItem primitives in `_draw`; the noise overlay is a full-rect child using `shaders/ui/RadarStatic.gdshader` (a `TIME`-driven GPU noise shader), so the transition costs no CPU per frame and no texture upload.

Alternative considered: a dynamically generated `NoiseTexture2D` refreshed per frame. Rejected — CPU noise generation plus texture upload every frame for a sub-second effect.

### Minimap skips composition and input while offline

When offline, `_refresh()` returns early (no fog/overlay/entity composition), `_draw_view_rect()` is skipped, and `_gui_input` ignores clicks. The control keeps `mouse_filter = STOP` and `UIUtil.is_mouse_over_minimap()` stays true, so world handlers still ignore the offline panel region — a click on `OFFLINE` must not fall through and order units underneath.

### Static logic extracted as pure/testable helpers

The availability gate, transition easing, and offline predicate are expressed as pure functions on `Minimap` (mirroring the existing static test surface) so they can be exercised headless without instancing a `Control`.

## Risks / Trade-offs

- [Radar availability lag] `RadarSystem` updates synchronously on node/signal events; if a radar is registered before its `StatsComponent.player_id` is assigned (deploy path), availability could briefly read wrong. → Same constraint `PowerGrid` already handles: registration reads `player_id` at add time; the `RadarComponent` can re-emit on a player-id change or `RadarSystem` can re-resolve on the next signal. Cover with a test for the deploy ordering.
- [Signal double-fire] A `RadarComponent` whose `PowerComponent` flips during `_ready` order could emit before `RadarSystem` registered it. → `RadarSystem` reads current `has_radar()` at registration time so late subscribers start correct, and the signal only corrects flips after.
- [Transient vs persistent static] The chosen reading is transient — steady offline is black + `OFFLINE`. If playtesting wants static to persist while offline, only the overlay's target intensity changes. → Documented; isolated in one easing target.
- [Minimap offline placeholder is placeholder art] The black `OFFLINE` panel diverges from TS faction art. → Explicitly accepted; replaced when sidebar art lands.
- [Test surface] `RadarSystem` is an autoload, so unit tests must instantiate it or drive it through the scene tree. → Follow the `PowerGrid` test pattern (`test/unit/test_power_grid.gd`) and add integration coverage via `test/unit/test_minimap.gd`.
- [Packed scene compatibility] Adding a child node (noise overlay) to `Minimap.tscn` must not break scenes instancing it. → Add the overlay at runtime in `_ready` (precedent: `FogRenderer` builds its planes in code), avoiding any `.tscn` structural change.

## Migration Plan

1. Land `RadarSystem` + `RadarComponent` signal + autoload registration; existing behavior is unchanged while every player starts radar-available only if they own radar (radar-less maps intentionally change).
2. Land the minimap gate + offline placeholder; maps without radar now show `OFFLINE`.
3. Land the static shader/transition.
4. Land the debug toggle and GLOSSARY entry.
5. Rollback is per-step: reverting the gate restores the unconditional minimap; `RadarSystem` is inert if unused.

## Open Questions

- None blocking. The offline-panel art is deferred to the sidebar-art workstream; the static-durability reading is isolated and reversible.
