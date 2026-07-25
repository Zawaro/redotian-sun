## MODIFIED Requirements

### Requirement: Dock interaction via HarvestComponent targeter
Dock interaction SHALL be handled by HarvestComponent's `get_order_for_target()` returning an ENTER order when the target has DockHostComponent. SelectionManager.request_dock() SHALL be removed. DockHostComponent.request_dock() remains as the low-level dock binding API (called by HarvestComponent's execute callback).

#### Scenario: Docking via order targeter
- **WHEN** a harvester is selected and cursor is over a DockHostComponent entity
- **THEN** HarvestComponent.get_order_for_target() SHALL return ENTER cursor and dock execute callback

#### Scenario: DockHostComponent.request_dock stays
- **WHEN** HarvestComponent's execute callback needs to bind to a dock
- **THEN** it SHALL call DockHostComponent.request_dock() directly (not through SelectionManager)

#### Scenario: SelectionManager.request_dock removed
- **WHEN** SelectionManager.request_dock() is called
- **THEN** it SHALL not exist (method removed)
