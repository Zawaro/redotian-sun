## MODIFIED Requirements

### Requirement: Minimap surface in the gameplay HUD

The gameplay HUD SHALL display a minimap control during normal gameplay, centered in the right-hand HUD column, below the credit display and above the Sidebar build panel, at most 200 pixels along its longer axis. The minimap's live rendering SHALL be gated on local-player radar availability. While radar is available the minimap SHALL render, in order from bottom to top: terrain color, the player's fog state (shroud/fog/visible), resource and overlay objects, entities, and the gameplay camera view rectangle. While radar is unavailable the minimap SHALL render the offline placeholder instead of the live layers. The minimap SHALL NOT be created or rendered while the runtime MapEditor scene is active.

#### Scenario: Minimap appears during gameplay

- **WHEN** a normal gameplay map is loaded
- **THEN** a minimap control no larger than 200x200 pixels is visible in the right-hand HUD column, below the credit display and above the Sidebar build panel

#### Scenario: Minimap reflects the playable area

- **WHEN** the terrain grid is initialized with a `grid_cells` size and visible-bounds insets and local radar is available
- **THEN** the minimap's rendered area covers the revealable play area (the map diamond inset by those insets) and the permanently-shrouded rim outside it is not rendered

#### Scenario: Minimap absent in the map editor

- **WHEN** the runtime MapEditor scene is active
- **THEN** no gameplay minimap is present in its HUD

## ADDED Requirements

### Requirement: Radar gate on the minimap

The minimap SHALL derive its availability from `RadarSystem.player_has_radar(local_player_id)` (which includes the debug force-online override). While local radar is unavailable the minimap SHALL draw an offline placeholder — a black panel with a centered `OFFLINE` label — SHALL NOT compose terrain, fog, overlay, or entity layers, SHALL NOT draw the camera view rectangle, and SHALL NOT process or issue any click command (no orders, no snap-pan). While offline the minimap SHALL still own its pointer region so world handlers continue to ignore clicks over it. On regaining availability the minimap SHALL resume live rendering on its next refresh.

#### Scenario: Offline with no radar structure

- **WHEN** the local player owns no radar-available structure
- **THEN** the minimap shows the black `OFFLINE` placeholder and no terrain, fog, entity, or view-rectangle layer

#### Scenario: Online when radar is available

- **WHEN** the local player owns an online radar structure
- **THEN** the minimap resumes its live terrain/fog/entity rendering and draws the camera view rectangle

#### Scenario: Powered radar goes offline

- **WHEN** the local player's radar structure goes powered-down under a low-power grid
- **THEN** the minimap immediately transitions to the offline placeholder

#### Scenario: Offline input is suppressed

- **WHEN** the minimap is offline and the player left-clicks it
- **THEN** no order is issued and the camera is not panned

#### Scenario: Offline panel still owns the pointer

- **WHEN** the minimap is offline and the player clicks its region
- **THEN** world selection and placement handlers do not process that click

### Requirement: Radar online/offline static transition

On every radar availability flip the minimap SHALL play a static-noise transition: a `TIME`-driven noise overlay whose intensity rises from 0 to full coverage and then eases out, over a short fixed duration, in both flip directions. The flip's destination panel — the live map when coming online, the black `OFFLINE` placeholder when going offline — SHALL be swapped in underneath only once the static fully covers the control, so the destination content never shows through the rising burst. The transition SHALL settle to the steady state with no residual static.

#### Scenario: Static eases in on loss

- **WHEN** local radar availability flips to false
- **THEN** the static overlay rises from 0 toward full coverage — the panel swaps to the offline placeholder underneath — then eases out, settling with no residual static

#### Scenario: Static eases out on gain

- **WHEN** local radar availability flips to true
- **THEN** the static overlay rises from 0 toward full coverage — the panel swaps to the live map underneath — then eases out, revealing it

#### Scenario: No residual static when settled

- **WHEN** a transition has completed and radar availability is stable
- **THEN** the static overlay contributes nothing to the rendered minimap
