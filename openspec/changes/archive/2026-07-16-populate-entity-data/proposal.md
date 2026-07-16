## Why

The build menu sidebar (issue #66) needs at least 2 entities per tab to validate the tabbed UI.
Currently only 1 infantry unit (E1) and 0 aircraft exist. We need TS-accurate unit data files
so the sidebar has real content to display across all 4 tabs.

## What Changes

- Add 2 infantry .tres files (E2 Disc Thrower, E3 Rocket Infantry) with rules.ini stats
- Add 2 vehicle .tres files (BIKE Attack Cycle, APC Amphibious APC) with rules.ini stats
- Add 2 aircraft .tres files (ORCA Orca Fighter, APACHE Harpy) with rules.ini stats
- Add 6 placeholder ArtData .tres files (one per new entity, no model_path, just placeholder_size)
- All new entities set `buildable = true` so they appear in the sidebar

## Capabilities

### New Capabilities

- `infantry-data`: E2 and E3 infantry entity definitions with correct TS stats
- `vehicle-data`: BIKE and APC vehicle entity definitions with correct TS stats
- `aircraft-data`: ORCA and APACHE aircraft entity definitions with correct TS stats

### Modified Capabilities

(none — this is pure data addition, no existing spec changes)

## Impact

- **Files created**: 12 new .tres files under `resources/entities/`
- **No code changes**: EntityFactory auto-discovers .tres files via `_scan_directory()`
- **Sidebar integration**: These entities will appear once the tabbed sidebar filters by `entity_type`
- **No breaking changes**: Existing entities untouched
