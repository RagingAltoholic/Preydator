# PreyData Module Contract

## Ownership & Scope

**PreyData owns:**
- `PreydatorDB.currency.preySnapshots` (per-character snapshot table)
- `PreydatorDB.currency.preyWeeklyProgress` (weekly completion tracking per character/week)
- All snapshot creation logic (formerly in CurrencyTracker.SnapshotCurrentPreyCharacter)
- All weekly progress updates (formerly in CurrencyTracker.RecordPreyTurnIn)

**PreyData does NOT own:**
- `PreydatorDB.currency.accountFlags` (stays with WeeklyCaps; warband-specific behavior)
- Weekly reset detection (stays with WeeklyCaps; drives reset processing)
- Cap application (stays with WeeklyCaps; requires cap derivation logic)

**Why this split:**
- PreyData = "What did this character do this week?" (data container)
- WeeklyCaps = "When does reset happen and what are available/earned slots?" (warband business logic)

## Module API

### Data Capture (Write Operations)

```lua
-- Create or update a character's snapshot from current hunt state.
-- Called: On PLAYER_LOGIN, QUEST_ACCEPTED, QUEST_COMPLETE, zone change, quest state update.
-- State source: Preydator.GetState() provides activeQuestID, zone, target, difficulty, stage, inPreyZone
-- Availability: Passed from HuntScanner if available, or inferred from existing snapshot.
function PreyData:CaptureSnapshot(charKey, state, availableCounts, availabilityKnown)
  -> Updates preySnapshots[charKey] with {
     stage, level, zoneName, activeQuestID, inPreyZone, 
     preyTargetName, preyTargetDifficulty, 
     weeklyKey, weeklyCompleted, 
     preyAvailableCounts, preyAvailabilityKnown, 
     lastSeen, classFile, rankLabel
  }
end

-- Increment weekly completion count for a specific difficulty.
-- Called: After prey quest is turned in (QUEST_TURNED_IN event hook).
-- Consequence: Updates preySnapshots[charKey].weeklyCompleted + preyWeeklyProgress storage.
function PreyData:RecordWeeklyCompletion(charKey, weekKey, difficulty)
  -> Increments preyWeeklyProgress[charKey][weekKey][difficultyKey]
  -> Also updates preySnapshots[charKey].weeklyCompleted[difficultyKey]
end

-- Directly set weekly progress (atomic).
-- Called: By WeeklyCaps on reset (to zero out completed counts).
-- Consequence: Overwrites preyWeeklyProgress[charKey][weekKey] entirely.
function PreyData:SetWeeklyProgress(charKey, weekKey, progressTable)
  -> Sets preyWeeklyProgress[charKey][weekKey] = progressTable
  -> Also updates preySnapshots[charKey].weeklyCompleted if char has snapshot
end

-- Update only the availability counts in a snapshot.
-- Called: By WeeklyCaps.ApplyCapsToSnapshots() to distribute weekly caps.
-- Consequence: Updates preySnapshots[charKey].preyAvailableCounts without touching completed counts.
function PreyData:SetPreyAvailability(charKey, availableCounts, capturedAt)
  -> Updates preySnapshots[charKey].preyAvailableCounts = availableCounts
  -> Updates preySnapshots[charKey].preyAvailableCounts.capturedAt = capturedAt
end

-- Get or create weekly progress entry.
-- Called: By CurrencyTracker display logic to ensure week entry exists.
-- Returns: Reference to preyWeeklyProgress[charKey][weekKey], creating if missing.
function PreyData:GetOrCreateWeeklyProgress(charKey, weekKey)
  -> Returns reference to progress entry {normal=#, hard=#, nightmare=#}
  -> Creates missing entry (initialized to 0s) if needed
end
```

### Data Read (Read-Only Operations)

```lua
-- Get a single character's current snapshot.
-- Called: By Settings, Display logic to show specific character data.
-- Returns: Snapshot table or nil if never captured.
function PreyData:GetSnapshot(charKey)
  -> Returns preySnapshots[charKey] or nil
end

-- Iterate all character snapshots.
-- Called: By Settings, CurrencyTracker to build warband table.
-- Returns: Iterator or table of {charKey, snapshot} pairs, preserving row order.
function PreyData:GetAllSnapshots()
  -> Returns ordered list of snapshots: {{charKey=..., snap=...}, ...}
  -> Order: Current character first, then by charKey
end

-- Get weekly progress for a specific character/week (read-only).
-- Called: By display logic for audit/debug.
-- Returns: {normal=#, hard=#, nightmare=#} or {normal=0, hard=0, nightmare=0} if missing.
function PreyData:GetWeeklyProgress(charKey, weekKey)
  -> Returns preyWeeklyProgress[charKey][weekKey] or zeros
  -> Does not create missing entry (read-only)
end

-- Get snapshot's weekly completion counts (convenience).
-- Called: By display logic to show "0/4/1" triplet.
-- Returns: {normal=#, hard=#, nightmare=#} from snapshot or empty table.
function PreyData:GetWeeklyCompletedFromSnapshot(charKey)
  -> Returns snapshot.weeklyCompleted or {normal=0, hard=0, nightmare=0}
end

-- Expose latest captured availability for a character.
-- Called: By display logic to show "4/-/3" available triplet.
-- Returns: {normal=#, hard=#, nightmare=#} or nil if unknown.
function PreyData:GetPreyAvailability(charKey)
  -> Returns snapshot.preyAvailableCounts or nil
end
```

### Bulk Operations (Cooperation with Other Modules)

```lua
-- Apply weekly cap derivation across all snapshots.
-- Called: By WeeklyCaps.ProcessReset() to distribute fresh availability on reset.
-- capsFunc input: Takes (snapshot) and returns {normal=N, hard=H, nightmare=NI}.
-- Behavior: Calls capsFunc for each snapshot, stores result in preyAvailableCounts.
function PreyData:ApplyWeeklyResetToSnapshots(capsFunc, capturedAt)
  -> For each preySnapshots[charKey]:
     local caps = capsFunc(snap)
     snap.preyAvailableCounts = {normal=caps.normal, hard=caps.hard, nightmare=caps.nightmare, capturedAt=capturedAt}
end

-- Read weekly progress in bulk (optimization for WeeklyCaps).
-- Called: By WeeklyCaps to detect if character has any progress this week.
-- Returns: Table of all completed counts indexed by charKey.
function PreyData:GetAllWeeklyCompletedByKey(weekKey)
  -> Returns {charKey => {normal=#, hard=#, nightmare=#}, ...}
end
```

### Module Lifecycle & Debug

```lua
-- Check if PreyData is enabled (warband module toggle).
-- Called: By CurrencyTracker before snapshot operations.
-- Returns: true if warband is enabled, false otherwise.
function PreyData:IsEnabled()
  -> Checks CustomizationStateV2:IsModuleEnabled("warband")
  -> Returns boolean
end

-- Capture snapshot creation stops; data persists in SavedVariables.
-- Called: By CustomizationStateV2 when warband module is toggled off.
function PreyData:OnDisable()
  -> No-op; data is not cleared, just stops being updated.
end

-- Expose internal state for /pd inspect.
-- Called: By DebugInspect to include PreyData state in diagnostic output.
-- Returns: {snapshotCount=#, weekProgressKeys={...}, lastCapturedAt=...}.
function PreyData:GetDebugState()
  -> Returns diagnostic table
end
```

## Event Flow & Triggers

### On PLAYER_LOGIN
```
Preydator (core loop) detects active prey quest
  -> calls CurrencyTracker:SnapshotCurrentPreyCharacter()  [future: PreyData:CaptureSnapshot()]
     (reads state from Preydator.GetState, reads availability from HuntScanner if available)
  -> calls WeeklyCaps:ProcessReset()  (if reset detected, updates availability)
```

### On QUEST_ACCEPTED
```
Preydator runtime detects new prey quest
  -> calls CurrencyTracker:SnapshotCurrentPreyCharacter()  [future: PreyData:CaptureSnapshot()]
     (updates snapshot with new questID, stage=1, difficulty, target)
```

### On QUEST_TURNED_IN (prey quest)
```
Preydator runtime detects prey quest completion
  -> calls CurrencyTracker:RecordPreyTurnIn(questID)  [future: PreyData:RecordWeeklyCompletion()]
     (increments weeklyProgress[charKey][weekKey][difficulty])
  -> preySnapshots[charKey].weeklyCompleted also updated
  -> calls WeeklyCaps:ObserveDifficulty(difficulty)  (promote unlock flags)
```

### On HuntScanner snapshot
```
HuntScanner captures available hunts from mission frame
  -> passes availableCounts to CurrencyTracker:SnapshotCurrentPreyCharacter()  [future: PreyData:CaptureSnapshot()]
     (updates snapshot.preyAvailableCounts)
```

### On weekly reset (detected by WeeklyCaps via epoch comparison)
```
WeeklyCaps:ProcessReset() detects reset
  -> calls WeeklyCaps:ApplyCapsToSnapshots()
     -> calls PreyData:ApplyWeeklyResetToSnapshots(capsFunc, now)
        (distributes fresh availability counts to all snapshots)
  -> calls PreyData:SetWeeklyProgress(charKey, newWeekKey, {normal=0, hard=0, nightmare=0})
     (zeros out completion counts for new week)
```

## Data Persistence & Consistency

**SavedVariables:**
```
PreydatorDB.currency.preySnapshots = {
  ["charName-RealmName"] = {snapshot_fields...},
  ...
}

PreydatorDB.currency.preyWeeklyProgress = {
  ["charName-RealmName"] = {
    ["week-2026-11"] = {normal=2, hard=1, nightmare=0},
    ["week-2026-12"] = {normal=0, hard=0, nightmare=0},
    ...
  },
  ...
}
```

**Consistency Guarantees:**
- Snapshot.weeklyCompleted always matches preyWeeklyProgress[charKey][weekKey]
- Snapshot.weeklyKey always matches the week key used to fetch weeklyCompleted
- On load, if preyWeeklyProgress entry is missing, GetOrCreateWeeklyProgress creates it
- On reset, both snapshot.weeklyCompleted and preyWeeklyProgress are updated atomically

## Interaction with Other Modules

**CurrencyTracker:**
- Currently creates snapshot via CurrencyTracker:SnapshotCurrentPreyCharacter()
- Future: Delegates to PreyData:CaptureSnapshot()
- Currently updates progress via direct table access
- Future: Calls PreyData:RecordWeeklyCompletion()
- Currently reads snapshots for display via db.preySnapshots[key]
- Future: Calls PreyData:GetSnapshot(key), PreyData:GetAllSnapshots()

**WeeklyCaps:**
- Currently reads/writes preySnapshots directly
- Future: Calls PreyData:ApplyWeeklyResetToSnapshots(capsFunc, now)
- Continues to own accountFlags and cap derivation
- Calls PreyData:SetWeeklyProgress() on reset to zero counts

**Settings:**
- Currently reads db.preySnapshots directly for display
- Future: Calls PreyData:GetAllSnapshots() for warband table

**DebugInspect:**
- Currently reads snapshots directly
- Future: Calls PreyData:GetDebugState() for diagnostic output

## Rollout Plan

1. Create Modules/PreyData.lua with full contract
2. Implement data access methods (getters/setters)
3. Refactor CurrencyTracker to call PreyData APIs instead of direct table access
4. Refactor WeeklyCaps to call PreyData:ApplyWeeklyResetToSnapshots()
5. Update Settings to call PreyData:GetAllSnapshots()
6. Update DebugInspect to call PreyData:GetDebugState()
7. Verify no Lua errors and snapshot integrity in-game
