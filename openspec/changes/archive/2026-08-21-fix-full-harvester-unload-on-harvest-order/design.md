## Context

HarvestComponent drives the harvester state machine: `IDLE → SEEK_NODE → HARVESTING → DELIVERING → …`. When a harvester's cargo is full (`get_cargo() >= capacity`), the HARVESTING branch and `_assess_next_action()` both call `_deliver_cargo()`, which transitions to DELIVERING and asks `DockClientComponent.seek_dock()` to route to a refinery.

`seek_dock()` has two silent early-return guards (`DockClientComponent.gd`):

```gdscript
if _state != State.IDLE:    return   # busy (e.g. interrupted dock)
if _retry_cooldown > 0.0:   return   # backoff for a blocked dock cell
```

When either guard trips, `_deliver_cargo()` has already set `_deliver_retry = 0.0`, and the DELIVERING `_process` branch only re-seeks when `_deliver_retry > 0`. So the harvester strands at the field with no recovery of its own — it only recovers if the interrupted dock happens to complete and emit `dock_undocked`. If that dock is permanently blocked (repeated pathfinding failure), the harvester idles forever.

The `resource-harvesting` spec additionally requires an ENTER cursor (direct-to-refinery) for a full harvester, which neither the code nor authentic Tiberian Sun behavior implements. The walk-to-field-then-unload behavior is the intended design and must be preserved.

## Goals / Non-Goals

**Goals:**
- A full harvester that reaches a tiberium field always routes to the refinery — never strands in DELIVERING.
- Preserve TS-authentic behavior: full harvester ordered to harvest walks to the tiberium cell first, then unloads.
- Self-healing recovery with no new docking/finding code.

**Non-Goals:**
- Not changing the HARVEST cursor or making the full harvester skip the field (that is Option B, rejected).
- Not touching the auto-path fullness check in `_assess_next_action()` (already correct).
- Not adding new signals, UI, or AI reactions to a "stuck" harvester (deferred — see Risks).

## Decisions

### D1: `seek_dock()` returns `bool` instead of `void`
`seek_dock()` SHALL return `true` when it engaged (entered MOVING or QUEUED) and `false` when it no-ops (busy guard, retry-cooldown guard, or no compatible host found).

Rationale: a return value is the only reliable way to distinguish "engaged" from "no-op". Comparing state before/after is ambiguous — the busy guard leaves a non-IDLE state that a naive IDLE-check would misread as "engaged". The signature change is additive: existing callers (which ignore the return) compile and behave unchanged.

Alternative considered: snapshot `get_state()` before/after the call. Rejected because the busy-guard case leaves a non-IDLE state, so "still IDLE" is not a valid "didn't engage" test. A second snapshot comparing non-IDLE→non-IDLE would conflate "busy, no-op" with "engaged-but-still-moving".

### D2: `_deliver_cargo()` sets the retry net when the seek doesn't engage
```gdscript
func _deliver_cargo(entity_parent: Node3D) -> void:
    _change_state(State.DELIVERING)
    if dock_client:
        if not dock_client.seek_dock(entity_parent):
            _deliver_retry = DELIVER_RETRY
```
When `seek_dock` reports failure, `_deliver_retry = DELIVER_RETRY` arms the existing DELIVERING `_process` branch (which already calls `seek_dock` again after the cooldown). No new retry machinery.

Rationale: root-cause fix in the shared function — every path that reaches `_deliver_cargo` (HARVESTING full check, `_assess_next_action`, `set_target_refinery`) is covered. The double-assignment when `dock_slot_failed` already set the retry is harmless (same constant).

### D3: `set_target_refinery()` gets the same net
The player-ordered dock enters DELIVERING via `set_target_refinery()` and can hit the identical no-op. Applying the same guard there closes the sibling path rather than patching only the ticket-named caller.

### D4: Spec correction — "Full cargo" stays HARVEST
The `resource-harvesting` "Full cargo" scenario is corrected from ENTER (direct-to-refinery) to HARVEST (walk to field, then unload), matching the code, authentic TS behavior, and the user's Option A decision.

### D5: Cancel the in-flight dock at order time (Variant A+)
The reported repro — a full harvester commanded to harvest while its auto-deliver dock is in flight (dock client MOVING/QUEUED) — strands because the harvest walk and the dock chase fight over the same `MovementController`, and the post-arrival `_deliver_cargo → seek_dock` silently no-ops against the busy client. Retry alone (D2/D3) can't fix a permanently busy client.

Fix: in `get_order_for_target`'s HARVEST closure, when cargo is full, call `dock_client.cancel()` before `set_target_node(target)`:

```gdscript
func():
    if get_cargo() >= float(_get_storage_capacity()) and dock_client:
        dock_client.cancel()
    set_target_node(target)
```

`cancel()` releases the reserved/queued slot and resets the client to IDLE, so after the TS-authentic walk to the field, line 111's `_deliver_cargo` re-seeks into a clean client and the unload proceeds.

Rationale: root-cause at the point where the conflicting intent enters — a player's harvest order while full. Gated on `get_cargo() >= capacity` keeps the blast radius to the reported bug; a non-full reorder mid-deliver keeps today's behavior.

Alternatives considered:
- **Variant B (straight-to-refinery on full):** route the full harvester directly to the dock, skipping the field. More deterministic and the original issue "Desired", but diverges from TS-authentic behavior. Rejected by the user in favor of A+.
- **Unconditional `dock_client.cancel()` inside `set_target_node`:** also clears the dock for partial-cargo reorders and covers `FreeUnitComponent`'s caller. Broader behavior change; not needed for this bug.

### D6: The real-game strand was a MouseHandler fall-through (root cause of the failing repro)

Even with D1–D5 in place, the game still stranded while unit tests passed. Runtime `[HARV]`/`[DOCK]` logging of the actual repro showed the A+ closure working (dock cancelled → SEEK_NODE) followed immediately by `cancel_harvest()` → IDLE with full cargo.

Root cause: `MouseHandler._handle_left_click_normal` pass 2 (interact hitboxes — tiberium, dock) executes the order but **does not return**, so the function falls through to the "no entity → issue movement command" block. That block issues a MOVE order via `OrderSystem.get_orders(null, …)`, whose execute → `SelectionManager.request_move` → `_execute_move` → `harvest.cancel_harvest(true)` (`SelectionManager.gd:384-386`) → `_change_state(IDLE)` with cargo still full. IDLE never auto-delivers → the harvester stops idle after (or instead of) the walk, exactly as the issue describes.

The unit tests passed because they call `get_order_for_target().execute()` directly, bypassing `MouseHandler`.

Fix (`MouseHandler.gd:292`):

```gdscript
if target:
    var target_cell := CellUtil.world_to_cell(target.global_position)
    if _try_execute_orders(target, target_cell, target.global_position, modifiers):
        return
```

Mirrors pass 1's existing early-returns. A click that issues an interact order (harvest, dock-enter) no longer also issues a move. Selections with no applicable order still fall through to the move path (e.g. a tank clicking tiberium moves there). D1–D5 remain as the self-healing safety net for genuinely unreachable/busy docks.

Regression test upgraded: `test_full_harvester_harvest_order_cancels_inflight_dock` now mounts harvester + refinery in the real scene tree (`_pm.get_tree().root.add_child`) so `find_nearest_host`'s group scan runs, and asserts the dock re-engages MOVING toward the refinery after the walk — verifying the full walk→deliver chain, not just the DELIVERING state. (`test_hover_tooltip.gd` established the in-tree mount pattern.)

## Risks / Trade-offs

- [Recovery depends on DELIVERING retry polling every `DELIVER_RETRY` (2s)] → Self-healing latency up to 2s in the pathological blocked-dock case; acceptable for a harvester, and far better than a permanent strand.
- [`seek_dock()` return type change touches a "keep API stable" archived design note] → Additive change; no existing caller is broken, the archived note concerned the call signature, not the return value.
- [Busy-dock case may already self-recover via the interrupted dock completing] → The retry net is defense-in-depth: it guarantees recovery even when the interrupted dock is permanently blocked, and it is required to close the reported strand.
- [No player-visible "stuck" indicator] → Deferred. The `ponytail:` comment in DELIVERING already notes this; a stuck signal can be added if the AI/UI needs it.

## Migration Plan

- No data, scene, or resource migration. Pure GDScript behavior change.
- Rollback: revert the `HarvestComponent.gd` / `DockClientComponent.gd` diffs; tests lock both new and old behavior boundaries.
