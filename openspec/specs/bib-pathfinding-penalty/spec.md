# bib-pathfinding-penalty Specification

## Purpose

Bib cells (short-cut strips around buildings, including refinery dock pads) remain reachable but incur a configurable pathfinding cost surcharge. Regular traffic routes around them; docking units and emergency crossers can still traverse them. The penalty value is data-driven via `GlobalRules`.

## Requirements
### Requirement: Bib cells incur a pathfinding cost penalty
`Pathfinder.find_path` SHALL apply an additional per-cell cost when expanding a neighbor cell that `SpatialHash.is_bib_cell()` reports as a bib cell. The penalty amount SHALL come from `GlobalRules.bib_cost_penalty` via `GlobalRules.get_current()`, applied additively to the tentative g-cost. Bib cells SHALL remain reachable — the penalty is a cost surcharge, not a hard block — so docking units and emergency crossers can still enter or traverse them.

#### Scenario: Bib cell raises path cost
- **WHEN** `find_path()` expands a neighbor that is a bib cell
- **THEN** the neighbor's tentative g-cost SHALL include `GlobalRules.bib_cost_penalty` in addition to the base movement and height cost

#### Scenario: Cheap detour preferred around bib
- **WHEN** a start-to-goal route crosses a bib cell but a non-bib detour exists whose total cost is below the bib-crossing cost
- **THEN** the returned path SHALL avoid the bib cell

#### Scenario: Bib cell is still reachable as destination
- **WHEN** the requested destination cell is itself a bib cell (e.g. a refinery dock pad)
- **THEN** `find_path()` SHALL return a non-empty path reaching that destination (the penalty does not block entry)

#### Scenario: No bib penalty without rules
- **WHEN** `GlobalRules.get_current()` returns null (editor or pre-autoload test context)
- **THEN** pathfinding SHALL apply no bib penalty (base cost only)

### Requirement: Bib penalty is globally configurable
`GlobalRules` SHALL expose `bib_cost_penalty` (float) in the Movement Coefficients group, defaulting to a value high enough to discourage ordinary traffic (≥ 4.0) while still permitting docking/emergency traversal. The value SHALL be readable by `Pathfinder` through `GlobalRules.get_current()`.

#### Scenario: Default value present
- **WHEN** a `GlobalRules` resource is loaded without an explicit override
- **THEN** `bib_cost_penalty` SHALL be a positive float ≥ 4.0
