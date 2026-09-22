## MODIFIED Requirements

### Requirement: Start production
`start_production(player_id, entity_data, count)` SHALL add items to the queue after verifying that the entity has a `buildable_queue` and that prerequisites are met (via PrerequisiteSystem). It SHALL NOT require the player to afford the full cost up front — production is funded as it builds. Returns false if the queue type is empty or prerequisites fail.

#### Scenario: Start production — success
- **WHEN** player has prerequisites and queue is empty
- **THEN** item is added, `production_started` emits, returns true

#### Scenario: Start production — prerequisite fails
- **WHEN** player lacks required buildings
- **THEN** returns false, no item added

#### Scenario: Start production — zero balance still queues
- **WHEN** player has prerequisites but a zero credit balance
- **THEN** the item is added and `production_started` emits; it stalls until credits arrive

#### Scenario: Stack incrementing
- **WHEN** last queue item is the same entity type
- **THEN** count increments (up to MAX_STACK = 25) instead of adding new item

### Requirement: Gradual cost deduction
During production, credits SHALL be deducted gradually over the build time at rate `cost / build_time * speed`. A fractional accumulator prevents rounding loss. Progress SHALL advance only when the current increment's cost is successfully deducted; when `EconomyManager.deduct` returns false the queue SHALL stall — holding progress and the accumulator — and resume once funds are available. `item.deducted` SHALL increase only by amounts actually deducted. On completion, any remaining balance is deducted; if that deduction fails, completion SHALL be withheld until funds arrive.

#### Scenario: Gradual deduction during production
- **WHEN** a 1000-credit entity with 10s build time is producing with sufficient funds
- **THEN** approximately 100 credits are deducted per second

#### Scenario: Remaining balance on completion
- **WHEN** production completes and deducted total < cost
- **THEN** the remaining balance is deducted to reach exact cost

#### Scenario: Starved queue holds progress
- **WHEN** the player's balance reaches zero mid-production
- **THEN** progress stops advancing, no further credits are deducted, and the queue stalls

#### Scenario: Failed deduction is not counted
- **WHEN** an increment cannot be deducted
- **THEN** `item.deducted` is unchanged and the accumulator keeps the owed fraction

#### Scenario: Completion is withheld until paid
- **WHEN** progress reaches 100% but the residual balance cannot be deducted
- **THEN** the item does not complete, does not enter ready-to-place, and stalls

## ADDED Requirements

### Requirement: Production stalls and resumes on insufficient funds
`ProductionManager` SHALL emit `production_stalled(queue_key)` once when a queue transitions from funded to starved, and `production_resumed(queue_key)` once when it transitions back. The queue key is `"player_id:factory_type"`. The signals SHALL be edge-triggered so a starved queue emits exactly one stall signal regardless of how many frames it remains starved.

#### Scenario: Stall signal fires once
- **WHEN** a producing queue's balance drops below the current increment
- **THEN** `production_stalled` emits exactly once for that queue key

#### Scenario: Resume signal fires on recovery
- **WHEN** credits are added and the starved queue deducts its next increment
- **THEN** `production_resumed` emits once for that queue key

#### Scenario: No stall while funded
- **WHEN** a queue deducts every increment successfully
- **THEN** neither `production_stalled` nor `production_resumed` emits

#### Scenario: Stall state cleared with the queue
- **WHEN** a starved queue is cancelled or completes
- **THEN** its stall state is cleared and a later re-queue is not treated as already stalled
