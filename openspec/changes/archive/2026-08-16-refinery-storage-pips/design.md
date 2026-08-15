## Context

The economy was a single scalar `PlayerData.credits` mutated through `EconomyManager.add`/`deduct`. Storage capacity is a hardcoded 2000 in `EconomyManager.get_storage_capacity`. Refineries (`EntityData.refinery` field) accept only the `"tiberium"` resource category at their dock. Resources are grouped by `ResourceType.category` (`"tiberium"`, and `"weed"` for vein). The plan calls for a future hidden vein storage group (consumed only by the Tiberium Waste Facility / Chemical Missile) and, eventually, build costs that consume multiple resource types during the build. Buildings render their select box + health bar as 3D meshes built in `SelectComponent._ready` (structures bypass the 2D `SelectionOverlay` canvas path entirely).

## Goals / Non-Goals

**Goals:**
- A single source of truth for per-player stored value that is category-aware, so tiberium and future hidden groups (vein) are two instances of one mechanism, not two code paths.
- Category displayability lives in data (`ResourceType.display_in_hud`), so hidden groups can never leak into the HUD credits or build prices.
- Refinery storage pips: a full-width, health-bar-styled bar along the bottom/south of the refinery reflecting the owner's tiberium storage fill (stored / capacity).
- Category-aware `EconomyManager` API with a `"tiberium"` default so every existing call site keeps working unchanged.
- Backward compatibility for `PlayerData.credits` readers.

**Non-Goals:**
- Multi-resource installment build costs (`EntityData.cost` stays a single int; the installment-schedule seam is documented, not built).
- Live capacity summation from storage buildings (silos) with build/sell/death lifecycle invalidation.
- Harvester wait-at-full-storage behavior.
- Vein storage gameplay consumers (Tiberium Waste Facility, Chemical Missile).
- Per-group HUD breakdown or group-specific pips on silos.

## Decisions

### 1. Category-keyed wallet as the single source of truth
`PlayerData` replaces the `credits` field with `stored_by_category: Dictionary[String, int]`. A `credits` property (get/set) is retained as a legacy accessor that reads/writes the `"tiberium"` category, so `PlayerManager` init, existing `EconomyManager` reads, and tests keep compiling and behaving identically.

- *Why this shape:* a scalar treasury plus a bolted-on hidden dict guarantees bespoke per-currency plumbing the moment a mixed-cost build spans visible and hidden groups. One map, one code path.
- *Alternative considered:* keep scalar `credits` and add a separate `stored` dict for hidden groups → double-bookkeeping drift risk (a spend can update one and not the other); rejected.

### 2. Displayability is data, not branch logic
`ResourceType` gains `display_in_hud: bool = true`. `vein.tres` sets it false. `EconomyManager.get_balance(player_id)` (no category) sums stored values across categories where the resource type has `display_in_hud = true`.

- *Why this shape:* the hidden-vein rule must live next to the resource it describes, so a second hidden or mixed-visible group is a data entry, not an economy change.
- *Alternative considered:* a hardcoded set of visible categories in `EconomyManager` → violates the data-driven architecture; a `GlobalRules` list → decoupled from the data it describes; both rejected.
- *Implementation note:* `EconomyManager` resolves displayability via `EntityFactory.get_global_rules().get_resource_type(category).display_in_hud`, with unknown categories treated as displayable (the `ResourceType` default). Cost is a dict lookup on balance reads; no caching needed at this scale.

### 3. Category-aware EconomyManager API with a tiberium default
`add(player_id, amount, reason, category := "tiberium")`, `deduct(player_id, cost, reason, category := "tiberium")`, `can_afford(player_id, cost)` (displayable balance), `get_balance(player_id, category := "")` (empty = displayable sum). `credits_changed` carries the category. All existing callers are unchanged because of the defaults.

- *Why this shape:* the seam is the one place mutations flow through (`DockUnloadComponent` unloads, production deducts, refunds), so future multi-resource costs extend one routine instead of adding new ones.
- *Alternative considered:* new `stored_*` APIs beside the existing scalar ones → two mutation surfaces, drift risk; rejected.

### 4. Capacity: category-aware signature, hardcoded 2000, registry seam deferred
`get_storage_capacity(player_id, category)` returns 2000 for `"tiberium"` and 0 for unknown categories. `EntityData.storage_capacity: Dictionary[String, int]` is added now and set on both refineries (data the future registry would sum), but the live summation and place/sell/death invalidation are deferred until a silo building exists.

- *Why defer:* a runtime capacity registry with lifecycle hooks has no consumer yet (no silo, no waste facility); the pips only need the tiberium number today. Building the registry now is speculative machinery.
- *Alternative considered:* full registry now → premature; rejected.

### 5. Refinery detection
Refinery status is the existing `EntityData.refinery` flag, now set to `true` on `gdi_refinery.tres` and `nod_refinery.tres`. `SelectionOverlay` reads it via `EntityFactory.get_entity_data(stats.id).refinery` (pattern already used by `DeployComponent`).

### 6. Storage bar rendering in SelectComponent (3D mesh path)
Buildings do not use the 2D `SelectionOverlay` path — `_collect_entities` skips structures (`if ent.select_box_type == 2: continue`), and buildings render their select box + health bar as 3D meshes built in `SelectComponent._ready`. The storage bar follows that path.

The structure health-bar build (BoxMesh fill + ImmediateMesh grid) is extracted into a shared `_build_segmented_bar(span_min, span_max, cross_min, cross_max, y_lo, y_hi, ratio, color, span_is_x)` helper that builds the grid as raw parent-space line vertices and the fill as a BoxMesh rotated 90° when the span runs along Z. The health bar is rebuilt through it with identical geometry; the storage bar uses it with `span_is_x = true`.

For a refinery (detected via parent `StatsComponent.id` → `EntityFactory.get_entity_data(id).refinery`, guarded by `not Engine.is_editor_hint()` since SelectComponent is `@tool`), `_ready` builds a `StorageBar` + `StorageBarGrid`:

- full-width bar along the building's **x-axis** at the base (`min_y` edge), one cube tall, centered in z,
- fill = `EconomyManager.get_balance(owner_id) / get_storage_capacity(owner_id)` (tiberium default), tiberium `ResourceType.color`,
- `update_storage_bar()` rescales the fill; `EconomyManager.credits_changed` (own `player_id`, tiberium category) refreshes it live,
- shown on select **or** hover via the existing generic visibility loop (the meshes are ordinary children, not excluded from the `child.visible = vis` sweep).

- *Why the 3D mesh path:* structures bypass the SelectionOverlay canvas entirely; a 2D bar there would never render for a real refinery.
- *Why bottom + full width:* explicit user direction — visually similar to the building health bar but on the bottom/south edge, full width (x-axis).
- *Why shared helper:* the health-bar grid build (~60 lines of hand-rolled z-axis line segments) is duplicated geometry; one axis-parameterized helper serves both bars.
- *Alternative considered:* cargo-style discrete 2D pip squares → rejected per direction; discrete squares are the transport-cargo idiom, not what was asked.

### 7. Migration
`PlayerManager` player init (starting credits from `GlobalRules`/`MapConfig`) writes into the tiberium category through the `credits` setter. No persistent save system serializes `PlayerData` beyond runtime, so the wallet change is contained; the `credits` property keeps any `.tres`/serialization references compatible.

## Risks / Trade-offs

- [Bypass leakage: a stale `.credits` reader or a direct `stored_by_category` mutation skips the choke point] → keep the wallet mutatable only through `EconomyManager`; the `credits` accessor is the only other writer and it targets the tiberium cathelper:* the health-bar grid build (~60 lines of hand-rolled z-axis line segments) is duplicated geometry; one axis-parameterized helper serves both bars.
- *Alternative considered:* cargo-style discrete 2D pip squares → rejected per direction; discrete squares are the transport-cargo idiom, not what was asked.

### 7. Migration
`PlayerManager` player init (starting credits from `GlobalRules`/`MapConfig`) writes into `free_credits`, not storage. No persistent save system serializes `PlayerData` beyond runtime, so the wallet change is contained.

## Risks / Trade-offs

- [Bypass leakage: a stale direct `stored_by_category` / `free_credits` mutation skips the choke point] → keep both pools mutatable only through `EconomyManager`; grep the fields in review and assert wallet invariants in tests.
- [Stored/free divergence: a spend or income updates one pool and not the other] → all mutations flow through the single `add`/`deduct` choke point, which enforces stored-first spending; tests pin the split.
- [Displayability lookup on every balance read] → one dict lookup per category; negligible at RTS scale; revisit only if profiling shows otherwise.
- [Capacity stays 2000 despite `storage_capacity` data on refineries] → the data field is ready for the future registry; until then capacity is a documented constant, consistent with the existing hardcode.
- [Sell refunds route to free credits, so selling a building doesn't fill the storage bar] → intentional: sell proceeds are cash, not stored tiberium.

## Open Questions

- None blocking. The silo-summation registry, multi-resource installment costs, and vein consumers are intentionally deferred and should be separate changes built on the seams defined here.
