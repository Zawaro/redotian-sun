## ADDED Requirements

### Requirement: Infantry load into stationary friendly transports
The system SHALL let infantry load into a friendly transport that has free seats by offering an ENTER cursor and ENTER order when the player orders infantry onto the transport. The offer SHALL appear only when the transport is stationary and has at least one free seat; otherwise the click SHALL fall through to normal movement. Loading SHALL NOT queue: each ordered infantry walks as an independent move order and boards on arrival only if the transport is still there, stationary, and has a free seat; infantry that arrive to no seat SHALL idle at their arrival cell.

#### Scenario: Infantry ordered onto stationary transport with seats
- **WHEN** infantry is selected and the player left-clicks a friendly, stationary transport with `current_passengers < passengers`
- **THEN** the cursor shows ENTER and the issued order walks the infantry to the transport and boards it

#### Scenario: Transport is moving
- **WHEN** the player left-clicks a friendly transport whose MovementController reports moving
- **THEN** no ENTER cursor or order is offered and the click resolves as a normal move order toward the click position

#### Scenario: Transport is full
- **WHEN** the player left-clicks a friendly stationary transport with `current_passengers == passengers`
- **THEN** no ENTER cursor or order is offered

#### Scenario: Multiple infantry ordered onto fewer seats
- **WHEN** the player orders five infantry onto a transport with two free seats
- **THEN** the first two arrivals board and the remaining three idle at their arrival cells

#### Scenario: Infantry arrives and the transport has moved away or filled up
- **WHEN** ordered infantry finishes walking to the transport's last cell and the transport is gone, moving, or full
- **THEN** the infantry idles at that cell without boarding

### Requirement: Boarding detaches the passenger node into the transport
The system SHALL store a boarded infantry as its actual node: TransportComponent SHALL detach the node from the scene tree, hold the node reference, and increment `current_passengers` via `add_passenger()`. While aboard, the passenger SHALL be invisible to targeting, selection, spatial hash, vision, and rendering (detached-node group semantics). The passenger node SHALL retain its health, veterancy, and weapon configuration for restore on unload.

#### Scenario: Boarded infantry leaves all registries
- **WHEN** infantry boards a transport
- **THEN** the infantry node is detached from the scene tree, held by TransportComponent, and no longer appears in the `entities`, `selectable`, or `drag_selectable` groups

#### Scenario: Boarded infantry cannot be selected or targeted
- **WHEN** the transport carrying passengers is on the map
- **THEN** raycast selection, drag selection, and enemy acquisition cannot reach the held passenger nodes

#### Scenario: Boarding infantry that was selected
- **WHEN** infantry with an active selection boards a transport
- **THEN** SelectionManager drops the boarding node before detach so no stale selection entry remains

### Requirement: Unload via the deploy command
The system SHALL unload a transport through the deploy command: the deploy hotkey on a selected transport, or hovering the selected transport and clicking when the DEPLOY cursor shows. The DEPLOY cursor SHALL show on hover-self only when `can_unload()` holds: the transport has passengers, is stationary, and stands on land (`get_land_type` is not water). Unload SHALL eject passengers one at a time, one per `GlobalRules.unload_interval` seconds, each re-added at the nearest free land cell.

#### Scenario: Deploy hotkey unloads selected transport
- **WHEN** the player presses the deploy hotkey with a transport selected that satisfies `can_unload()`
- **THEN** the transport begins ejecting passengers one per unload interval

#### Scenario: Hover-self deploy cursor
- **WHEN** the player hovers the selected stationary loaded transport standing on land
- **THEN** the cursor shows DEPLOY and clicking starts the unload

#### Scenario: Unload blocked while moving
- **WHEN** the transport's MovementController reports moving
- **THEN** `can_unload()` is false, no DEPLOY cursor shows on hover-self, and the deploy hotkey does not start an unload

#### Scenario: Unload blocked on water
- **WHEN** an amphibious transport stands on a water cell
- **THEN** `can_unload()` is false and no unload starts

#### Scenario: Subterranean transport unloads only surfaced
- **WHEN** a subterranean transport is ordered to unload
- **THEN** the unload starts only while the transport is stationary (surfaced); it cannot stop underground and unload there

#### Scenario: Sequential eject pacing
- **WHEN** an unload ejects multiple passengers
- **THEN** exactly one passenger is re-added per `GlobalRules.unload_interval` seconds until the transport is empty

#### Scenario: Ejected passenger placement
- **WHEN** a passenger is ejected
- **THEN** it re-enters the scene tree at the nearest free land cell with its pre-boarding health, veterancy, and weapons restored

### Requirement: Unload is interruptible
The system SHALL cancel an in-progress unload when the player issues a move order to the transport or presses the stop command. Cancelling SHALL keep remaining passengers aboard and leave the transport free to receive new orders.

#### Scenario: Move order interrupts unload
- **WHEN** a transport is ejecting passengers and receives a move order
- **THEN** the eject sequence cancels immediately and the transport moves with remaining passengers aboard

#### Scenario: Stop command interrupts unload
- **WHEN** a transport is ejecting passengers and the player issues the stop command
- **THEN** the eject sequence cancels and remaining passengers stay aboard

### Requirement: Destroyed transports eject passengers
The system SHALL eject all held passengers when a transport's health reaches zero, re-adding each at the nearest free land cell before the transport tears down. If no free cell exists for a passenger, that passenger SHALL stay held and the transport's own cell is used as fallback.

#### Scenario: Transport destroyed with passengers aboard
- **WHEN** a loaded transport's health reaches zero
- **THEN** all held passengers are re-added to the scene tree at nearest free land cells before the transport node is freed

#### Scenario: No free cell at death
- **WHEN** a transport is destroyed and no free land cell is found for a passenger
- **THEN** that passenger is re-added at the transport's own cell

### Requirement: Passenger seat pips render per-passenger colors
The selection overlay SHALL draw one seat pip per transport capacity, filled per occupied seat, where each filled pip uses the passenger's `EntityData.pip_color`. Unset colors SHALL fall back to white. Empty seats SHALL draw unfilled.

#### Scenario: Mixed passengers show distinct colors
- **WHEN** a transport carries infantry whose EntityData defines different `pip_color` values
- **THEN** each occupied seat pip draws in its passenger's color

#### Scenario: Passenger without pip_color
- **WHEN** a boarded passenger's EntityData leaves `pip_color` unset
- **THEN** its seat pip draws white

#### Scenario: Partial load
- **WHEN** a transport with four seats carries two passengers
- **THEN** the overlay shows two filled pips in passenger colors and two unfilled pips
