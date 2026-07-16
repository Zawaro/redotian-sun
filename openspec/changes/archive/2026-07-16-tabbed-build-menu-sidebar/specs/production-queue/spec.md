## ADDED Requirements

### Requirement: Queue per player per factory type
The system SHALL maintain separate production queues keyed by `player_id:factory_type`. All buildings of the same factory type contribute to one queue.

#### Scenario: Queue key format
- **WHEN** player 0 starts infantry production
- **THEN** the queue key is "0:INFANTRY"

#### Scenario: Separate queues per type
- **WHEN** player 0 has both barracks and war factory
- **THEN** infantry production uses "0:INFANTRY" queue and vehicle production uses "0:VEHICLE" queue independently

### Requirement: Deduct cost on queue start
The system SHALL deduct the entity's cost from the player's credits immediately when an item is added to the queue.

#### Scenario: Successful deduction
- **WHEN** player has 1500 credits
- **AND** starts production of entity costing 200
- **THEN** player credits become 1300
- **AND** entity is added to queue

#### Scenario: Insufficient funds
- **WHEN** player has 100 credits
- **AND** tries to start production of entity costing 200
- **THEN** production does not start
- **AND** credits remain 100

### Requirement: Full refund on cancel
The system SHALL refund the full cost when a queue item is cancelled. If an item has count > 1, cancelling decrements the count and refunds one unit's cost.

#### Scenario: Cancel single item
- **WHEN** player cancels a queued entity costing 200
- **THEN** player credits increase by 200
- **AND** item is removed from queue

#### Scenario: Decrement stacked item
- **WHEN** player has 3× infantry in queue (cost 100 each)
- **AND** right-clicks to cancel one
- **THEN** player credits increase by 100
- **AND** queue count becomes 2

### Requirement: Pause and resume production
The system SHALL allow pausing and resuming individual queue items. Paused items stop progressing but remain in the queue.

#### Scenario: Pause active item
- **WHEN** player right-clicks an actively building item
- **THEN** the item's progress freezes
- **AND** the next item in queue (if any) does NOT start (queue position preserved)

#### Scenario: Resume paused item
- **WHEN** player left-clicks a paused item
- **THEN** the item resumes building from its current progress

### Requirement: Production timer scales with game speed
The system SHALL use `_process(delta)` for timer progression. `Engine.time_scale` scales delta automatically, so build_time in game seconds works at any game speed.

#### Scenario: Normal speed
- **WHEN** Engine.time_scale = 1.0
- **AND** entity build_time = 30.0 seconds
- **THEN** production completes in 30 real seconds

#### Scenario: Fast speed
- **WHEN** Engine.time_scale = 2.0
- **AND** entity build_time = 30.0 seconds
- **THEN** production completes in 15 real seconds

### Requirement: Production speed bonus from multiple factories
The system SHALL apply a speed bonus based on the number of factories of the same type. Formula: `1.0 + (factory_count - 1) * 0.25`.

#### Scenario: Single factory
- **WHEN** player has 1 barracks
- **AND** production build_time = 60.0
- **THEN** effective build time = 60.0 seconds

#### Scenario: Multiple factories
- **WHEN** player has 3 barracks
- **AND** production build_time = 60.0
- **THEN** effective build time = 40.0 seconds (60 / 1.5)

### Requirement: Spawn unit on production complete
The system SHALL spawn the produced unit at the primary factory's exit point when production completes. If no free cell is available, scatter nearby units.

#### Scenario: Successful spawn
- **WHEN** infantry production completes
- **AND** primary barracks has a free adjacent cell
- **THEN** unit is created at that cell position

#### Scenario: Spawn with scatter
- **WHEN** infantry production completes
- **AND** all adjacent cells are blocked
- **THEN** nearby idle units are scattered
- **AND** unit spawns at the now-free cell

### Requirement: Enter build mode on building complete
The system SHALL enter BuildingManager's build mode when a building production completes, allowing the player to place the building.

#### Scenario: Building completes
- **WHEN** structure production completes
- **THEN** BuildingManager.enter_build_mode() is called with the completed entity data

### Requirement: Stack queue items
The system SHALL stack identical consecutive queue items up to 25 per entity type. Left-clicking an entity already in queue increments its count (if under 25) instead of adding a new entry.

#### Scenario: Stack increment
- **WHEN** player left-clicks infantry (cost 100) already in queue with count=2
- **AND** count < 25
- **THEN** queue count becomes 3
- **AND** 100 credits deducted

#### Scenario: Stack at limit
- **WHEN** player left-clicks infantry already in queue with count=25
- **THEN** no change (stack full)
