## Context

`UnitOrderGenerator` is the funnel for every player-issued unit command. `get_cursor()` and
`get_orders()` resolve over `SelectionManager.selected_entities`. Selection admits enemy
entities for viewing, but the funnel never checks who owns the *issuer*, and `MouseHandler`
treats enemy clicks specially. The reconstructed TS source is the behavioural reference:

- `object.cpp::ObjectClass::Select` allows selecting any selectable object, but clears the
  whole selection when the incoming object's player-control differs from the current head, or
  when the current head is not player-controlled — so enemy selection is exclusive.
- `techno.cpp::What_Action` routes an armed player unit over an enemy to `ACTION_ATTACK`, and
  everything else to `ACTION_SELECT`.
- `techno.cpp::Can_Player_Move` / `Can_Player_Fire` require `House->Is_Player_Control()`, so a
  non-player-controlled selection cannot move or fire.
- `display.cpp::Mouse_Left_Release` selects the hovered object when the action is select/none,
  and `Bandbox_Selection_Callback` only takes player-controlled objects.

## Goals / Non-Goals

**Goals:**
- No mixed own+enemy selection. Adding a non-local entity, or adding to a non-local selection,
  clears first; only local entities coexist.
- Unselected-entity clicks fall through to selection when the current selection produces no
  order (enemy and friendly alike).
- Non-local selected entities never generate orders or command cursors; an all-enemy selection
  shows `SELECT` over an unselected selectable target and `DEFAULT` otherwise, with empty orders.
- Local order-capable buildings (armed, undeployable) keep working.

**Non-Goals:**
- Changing box-select (keeps excluding enemies) or the friendly drag path.
- Changing `OrderResolver`'s contract or its direct-call tests.
- Sell/repair generators, which target a hovered building rather than the selection.

## Decisions

**Exclusivity enforced in `SelectionManager.select_entity`, not `add_entity`.**
`add_entity` is also the reconciliation path (`_synchronize_visual_selection`,
`_on_selection_state_changed`) and must not clear. `select_entity` is the input gate, matching
`ObjectClass::Select`. Rule: when shift-adding, clear first unless **both** the current head
and the incoming entity are local (equivalent to TS's `old != new || !old` clear condition).

**Unify enemy click routing in `MouseHandler`.**
Delete the enemy-specific early-return block so enemy targets flow through the same branch as
friendly/neutral: try orders (unless shift), else select. Attack routing is preserved because
the branch tries orders first. Alternative (keep a separate enemy branch) was rejected — it is
the source of both "enemy never gets selected on fallthrough" and code duplication.

**Ownership filter in `UnitOrderGenerator`, not `OrderResolver`.**
`OrderResolver` is a pure resolver whose spec promises "iterate all selected entities" and
which tests call directly. `UnitOrderGenerator` is the sole production caller and the policy
layer. With exclusivity in place this filter is the defence that keeps a lone enemy selection
inert (no command cursors, no orders); it also covers programme-added selections.

**Enemy cursor is SELECT-or-DEFAULT, never a command cursor.**
For a non-local selection, `get_cursor` returns `SELECT` when the hovered target is selectable
and not already selected (via `_is_already_selected`), otherwise `DEFAULT` — matching TS
`What_Action` returning `ACTION_SELECT` over a hovered selectable for a non-player-controlled
object. This lets the player click to re-select while keeping ground, self, and non-selectable
targets at `DEFAULT` and all command cursors suppressed.

**Hotkey commands share the ownership guard.**
The deploy (Ctrl+D) / stop (Ctrl+S) hotkeys act on the selection directly (they bypass
`OrderSystem`), so they need their own ownership filter or a lone enemy selection is
commandable. The loop is extracted as `MouseHandler.apply_selection_hotkey()` and gated with
`PlayerManager.is_entity_local`, covered by a regression test.

**Single ownership predicate.**
`PlayerManager.is_entity_local(entity, local_id)` is the one implementation of the rule;
`SelectionManager._is_local_entity_node` and `UnitOrderGenerator._is_local_entity` delegate to
it instead of duplicating it. The exclusivity clear is public
(`SelectionManager.clear_incompatible_selection`) so the box-select path does not reach into a
private method.

## Risks / Trade-offs

- [Neutral entities (`player_id < 0`) count as local, so an own unit and a neutral entity can
  coexist] → Existing `is_entity_local` semantics used throughout; changing them is out of
  scope.
- [Shift+click on an already-selected entity never reaches `select_entity`: the click path
  short-circuits `already_selected` into the order funnel and returns, so toggle-off is
  unreachable via real clicks] → Pre-existing; enemy shift+click-self is therefore a no-op,
  matching TS (which re-selects rather than toggles). `select_entity`'s toggle-off remains
  exercised only by direct API tests.
- [Box-select with shift while an enemy is selected adds own units; must not silently mix] →
  The box path also runs the exclusivity check before adding.
- [`_local_selection` allocates a filtered array per query (per frame)] → Bounded by selection
  size and dwarfed by existing resolver work; no memoization added.
