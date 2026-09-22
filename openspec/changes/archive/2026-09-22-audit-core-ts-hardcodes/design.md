## Context

The core is a single GDScript codebase driving four planned games through `GameDefinition` /
`GameContext` content layering. An audit (three parallel passes over `scripts/core/`,
`scripts/components/` + `scripts/entities/`, and `scripts/ui/`) found that behavior is still
Tiberian-Shaped: TS numeric constants compiled into components, TS content strings branched in
`EntityFactory`, TS-only mechanics with no gate, TS assets in shared scenes, and inert
`GlobalRules` stubs. The existing toggles are two kinds: `GlobalRules` numeric/boolean fields
(per-game because each game owns a `global_rules.tres`) and content registries. There is no
per-game on/off mechanic toggle.

## Goals / Non-Goals

**Goals**

- Every TS assumption identified in the audit is either routed through data (GlobalRules field,
  `EntityData` flag, registry) or an explicit `GameDefinition.features` toggle, or captured as a
  follow-up issue.
- Pure renames/comments fixed inline; behavior changes minimal and data-gated.
- TS behavior byte-identical after extraction (defaults equal today's literals).
- Feature off ⇒ behavior absent, no errors.

**Non-Goals**

- No new subsystems. Toggles are a `Dictionary` on `GameDefinition`; values are `GlobalRules`.
- Not implementing TS/YR-exclusive mechanics (superweapons, mind control, cloning, tech
  buildings, prism/tesla chaining, ion storms, visceroids, meteorites, crew escape).
- Not extracting map-format constants (`CELL_SIZE`, `HEIGHT_STEP`, `MAX_HEIGHT`, 50×50 grid
  defaults) — follow-up.
- Not renaming glossary-canonical terms (`bale`, `crystal`, `tree`, `resource category`,
  `power bar`).

## Decisions

**D1. On/off mechanics use `GameDefinition.features`, values use `GlobalRules`.**
Rationale: numbers that vary by game (power scale, ROF base) belong with the other rules
numbers; presence/absence of a mechanic is categorical and belongs on the manifest. Alternative
considered: put everything in `GlobalRules` booleans (already per-game). Rejected because #374's
approved architecture specifies `features`, and mixing categorical gates into a 200-field rules
resource hurts discoverability. `has_feature` returns false for absent keys so flags default
off.

**D2. Extract constants into `GlobalRules` with defaults equal to current literals.**
Rationale: guarantees TS parity and makes the extraction a no-op behaviorally while relocating
the knob. Alternative: leave them and only comment. Rejected — criterion 2 ("no TS branch
without a data path") would fail.

**D3. Content-shape branches become `EntityData` boolean flags, not feature flags.**
Rationale: whether an entity is a resource spawner / procedural resource / breakable surface is
a property of that content unit, not of the whole game. `breakable_surface` is additionally
gated by the game-level `breakable_ice` feature because the mechanic implementation is
TS-shaped. Alternative: game features for all three. Rejected — over-broad; a game could have a
breakable surface without ice.

**D4. Slope coefficients move to `Locomotor`.**
Rationale: the coefficient set is per movement class, which is exactly what `Locomotor` models;
it removes the `"Track"`/`"Wheel"` id-string match. Defaults 1.0 = inert, TS tres carry the old
values. Alternative: keep GlobalRules tracked/wheeled and map via a data field. Rejected as
indirection.

**D5. HUD/currency category from `GlobalRules.primary_resource_category`.**
Rationale: `"tiberium"` is the TS category; RA2 uses `"ore"`. A rules field is the minimal
per-game knob and lets `EconomyManager` resolve its default dynamically. Alternative: hardcode
category lists per game in data registries. Rejected — the HUD needs one primary category.

**D6. Sidebar tabs declared on `GameDefinition` as an array of tab dictionaries.**
Rationale: keeps per-game layout in the manifest next to `data_sets`; `Sidebar` builds buttons
from it. Alternative: a separate `SidebarLayout` resource per game. Rejected as a new type for
one consumer. Feature-required tabs are hidden when the feature is off.

**D7. Menu theming and terrain fallback via new `GameDefinition` fields.**
Rationale: removes TS asset paths from shared scenes with the fewest new concepts. Alternative:
a per-game `UITheme` resource. Deferred unless the field set grows.

## Risks / Trade-offs

- **Packed scene edits** (`Sidebar.tscn`, `MainMenu01.tscn`) → verify in the Redot IDE, not only
  headless; keep node structure stable where possible.
- **Dynamic tab build changes node timing** → Sidebar builds tabs in `_ready`; ensure existing
  `@onready` references and hotkey wiring tolerate a data-built set.
- **`primary_resource_category` dynamic default in `EconomyManager`** → several tests assert the
  `"tiberium"` default; update them to set the rules field explicitly.
- **Resource art migration** changes visuals → verify on the TS test map; keep the current cube
  config as the TS `ArtData` value so output is unchanged.
- **20+ files across four systems** → land as ordered, independently testable phases; full
  suite after each.
- **Cross-game verification blocked** on #378–#380 → prove flag on/off with synthetic
  `GameDefinition` fixtures; note the residual risk in the PR.

## Migration Plan

1. Flag infrastructure first (additive; no behavior change).
2. GlobalRules fields (additive; defaults preserve behavior).
3. EntityData flags + factory/data migration; update `games/ts` content to set them.
4. Feature gates; TS `game.tres` declares the three features on.
5. UI/art data migration; scene edits verified in-editor.
6. Cleanup + follow-up issues.
7. Full test suite + lint.

Rollback: each phase is a separate commit; reverting a phase restores the prior behavior
because defaults preserve old literals.

## Open Questions

- Exact `GameDefinition` field names for menu theming (`menu_background`, `menu_accent_color`)
  vs a nested dictionary.
- Whether tab hotkeys should be generic indices (`tab_1..tab_N`) or remain the four named
  actions; if named, per-game tab sets cannot re-map inputs. Leaning generic indices.
- Whether the resource crystal art belongs on `ResourceType` or `ArtData`; leaning `ArtData`
  because the component already consumes art for other entity types.
