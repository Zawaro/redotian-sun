## Why

TransportComponent stores passenger counts, dock target, and harvester flag, but infantry cannot actually ride transports: the ENTER order is a stub that fires transport→transport (nonsense gameplay-wise), no infantry ever despawns into an APC, nothing can exit, and destroyed transports leak their theoretical passengers. The economy loop (harvest → refinery) is done; transports are the last major component in issue #32 that is cursor-deep only.

## What Changes

- Infantry can load (board) a friendly stationary transport: infantry get a new `PassengerComponent` that offers an ENTER cursor/order against transports with free seats. Boarding despawns the real infantry node into the transport (detach — health, veterancy, and weapons survive the ride); no queue — every ordered infantry walks as an independent move order and boards on arrival while seats remain.
- Transports can unload: deploy hotkey or hover-self DEPLOY cursor + click starts a sequential eject (one passenger per short interval), gated on the transport being stationary and on land (amphibious cannot unload on water; subterranean stationary = surfaced). Stop key or any move order cancels a pending eject.
- Destroyed transports eject all passengers immediately at nearest free land cells.
- Passenger seat pips render per-passenger colors from a new `EntityData.pip_color` export; passenger weapons stay dormant while aboard (no fire-out), the transport keeps its own weapon and its own veterancy progression.
- No speed penalty when loaded; no passenger-fire behavior in this change.

## Capabilities

### New Capabilities

- `transport-passengers`: Infantry load/unload mechanics for transports — boarding rules (stationary, friendly, seats, no queue), detach-based passenger storage, unload command (deploy key / self-click DEPLOY cursor) with sequential eject and interrupts, eject-on-death, and per-passenger colored seat pips on the selection overlay.

### Modified Capabilities

- `entity-data`: adds the `pip_color` export (seat pip color for a passenger riding in a transport).
- `entity-factory`: Component addition rules gain `PassengerComponent` on infantry entities.
- `stop-command`: Stop cancels an in-progress unload sequence (new scenarios under the existing halt-all-activity requirement).

## Impact

- **Scripts**: new `scripts/components/PassengerComponent.gd`; `scripts/components/TransportComponent.gd` (passenger node list, board/unload state machine, `can_unload()` gates, self-hover DEPLOY cursor, eject-on-death; deletes the broken transport→transport ENTER stub); `scripts/entities/EntityFactory.gd` (attach PassengerComponent on infantry); `scripts/hud/MouseHandler.gd` (deploy hotkey path triggers transport unload; stop cancels unload); `scripts/data/EntityData.gd` (pip_color export); `scripts/data/GlobalRules.gd` (unload eject interval); `scripts/ui/SelectionOverlay.gd` (per-seat colored passenger pips).
- **Scenes**: none structurally changed — components attach dynamically via EntityFactory; existing `.tscn` files stay compatible (no new required nodes on packed scenes).
- **Data**: infantry `.tres` resources may set `pip_color`; transports need no new fields (`passengers` capacity already exists).
- **Systems touched**: order system (new component order targeter only — no OrderSystem changes), SelectionManager (no changes — group auto-cleanup covers detached passengers), SpatialHash/Vision (no changes — exit_tree hooks).
