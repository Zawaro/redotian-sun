## Why

The build menu sidebar had layout issues where the credit display label was hidden behind the PanelContainer background. The scene was also misnamed "BuildMenu" when it serves as a general-purpose sidebar. The starting credits value was 0 (no visible economy during testing) and cameo buttons lacked cost information on hover.

## What Changes

- Rename `BuildMenu.tscn` → `Sidebar.tscn` and `BuildMenu.gd` → `Sidebar.gd`
- Replace PanelContainer root with Control root to fix child layout override issue
- Add CreditsLabel showing balance from EconomyManager via signal
- Set default starting credits to 10000 in global_rules.tres
- Add tooltip to each cameo button showing building credit cost
- Update all scene/script references (MainScene, MapBase01, MouseHandler)
- Update credit-ui spec to reference Sidebar instead of BuildMenu

## Capabilities

### New Capabilities
- `cameo-tooltip`: Tooltip on building cameo buttons showing credit cost on hover

### Modified Capabilities
- `credit-ui`: spec references `BuildMenu.tscn` — needs update to `Sidebar.tscn`

## Impact

- `scripts/ui/BuildMenu.gd` → `scripts/ui/Sidebar.gd` (script rename + root type change)
- `scenes/ui/BuildMenu.tscn` → `scenes/ui/Sidebar.tscn` (scene rename + layout restructure)
- `scenes/MainScene.tscn` — updated ext_resource path and node name
- `scenes/maps/MapBase01.tscn` — updated ext_resource path and node name
- `scripts/hud/MouseHandler.gd` — updated node name check
- `scripts/ui/Sidebar.gd` — added `tooltip_text` to cameo buttons
- `resources/global_rules.tres` — `starting_credits` set to 10000
- `openspec/specs/credit-ui/spec.md` — references updated to Sidebar
