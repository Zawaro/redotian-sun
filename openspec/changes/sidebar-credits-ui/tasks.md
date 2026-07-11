## 1. Rename BuildMenu to Sidebar

- [x] 1.1 Rename `scripts/ui/BuildMenu.gd` → `scripts/ui/Sidebar.gd`, update `extends` to `Control`
- [x] 1.2 Rename `scenes/ui/BuildMenu.tscn` → `scenes/ui/Sidebar.tscn`, update ext_resource to `Sidebar.gd`
- [x] 1.3 Restructure sidebar layout: Control root → CreditsLabel (layout_mode=0, top) + PanelContainer (layout_mode=0, below)
- [x] 1.4 Rename `BuildMenu.gd.uid` → `Sidebar.gd.uid`
- [x] 1.5 Update `MainScene.tscn` ext_resource + node name to Sidebar
- [x] 1.6 Update `MapBase01.tscn` ext_resource + node name to Sidebar
- [x] 1.7 Update `MouseHandler.gd` node name check from `"BuildMenu"` to `"Sidebar"`

## 2. Credit Display

- [x] 2.1 Set `starting_credits = 10000` in `resources/global_rules.tres`
- [x] 2.2 Wire CreditsLabel to EconomyManager in Sidebar.gd `_ready()`
- [x] 2.3 Connect `credits_changed` signal to update label text
- [x] 2.4 Implement `_compute_cheapest_cost()` and `_update_credits_color()` for insufficient funds feedback

## 3. Cost Tooltip

- [x] 3.1 Set `tooltip_text = "$%d" % bt.cost` on each cameo button in `_populate_buttons()`

## 4. Spec Update

- [x] 4.1 Update `openspec/specs/credit-ui/spec.md` — replace `BuildMenu` references with `Sidebar`
- [x] 4.2 Add `openspec/specs/cameo-tooltip/spec.md` with tooltip requirements
