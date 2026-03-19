# PreyWidgetBridge Module Contract

**Status**: Design Phase  
**Owner**: Centralizes all widget detection, frame discovery, and state extraction.  
**Not Owner**: Event dispatch, bar rendering, polling control, icon suppression UI effects.

---

## Module Purpose

Preydator hunts are rendered as WoW UI widgets (prey hunt progress widget, type 31). This module encapsulates:
- Widget availability checking (C_UIWidgetManager)
- Widget state extraction (progressState, progressPercent, tooltip)
- Widget frame discovery and caching (finding actual frame objects)
- Widget quest ID association
- Widget aging (how long since last detection)

Consumed by: `UpdatePreyState()` in Preydator.lua to determine if widget data should drive state updates.

---

## Public API

### Widget State Detection

```lua
-- Returns (progressState, tooltip, progressPercent) for active prey hunt widget
-- progressState: 0 (Discovery), 1 (Tracking), 2 (Engage), 3 (Final) or nil if widget unavailable
-- tooltip: Localized widget tooltip text or nil
-- progressPercent: 0-100 or nil
function PreyWidgetBridgeModule:GetWidgetState(questID)
```

**Behavior**:
- Queries `C_UIWidgetManager.GetWidgetInfoByConditionID(widgetType, questID)`
- Returns structure: `{ progressState, tooltip, progressPercent }` or `{ nil, nil, nil }`
- **Thread-safe**: No side effects, pure query

**Called by**:
- `UpdatePreyState()` once per event (when zone/quest/widget changes)

**Fallback Path**:
- Via PreyRuntime.FindPreyWidgetProgressState (same logic in PreyRuntime for consistency)

---

### Widget Availability

```lua
-- Returns true if widget manager appears functional and queryable
function PreyWidgetBridgeModule:IsWidgetAvailable()
```

**Behavior**:
- Checks `C_UIWidgetManager ~= nil`
- Checks `type(C_UIWidgetManager.GetWidgetInfoByConditionID) == "function"`
- Returns `true` if both available, `false` otherwise

**Purpose**: Graceful fallback if Blizzard APIs missing (e.g., older expansions)

---

### Widget Quest Matching

```lua
-- Extracts questID from widget info table (handles variant field names)
-- Returns string/number questID or nil
function PreyWidgetBridgeModule:ExtractWidgetQuestID(widgetInfo)
```

**Behavior**:
- Tries fields in order: `widgetInfo.questID`, `widgetInfo.questId`, `widgetInfo.associatedQuestID`
- Returns first non-nil match
- Returns nil if none found

**Used by**:
- `GetWidgetState()` validation
- Widget frame discovery (confirm quest association)

---

### Widget Frame Discovery

```lua
-- Scans global frame hierarchy to locate widget container frames
-- Caches results in module-private WidgetFrame cache
-- Returns table: { frame1, frame2, ... } or empty table
function PreyWidgetBridgeModule:FindGlobalFramesForWidgetID(widgetID)
```

**Behavior**:
- Checks cache first: `moduleScopedWidgetFrameCache[widgetID]`
- If cache miss:
  - Scans each candidate widget container: TopCenter, ObjectiveTracker, BelowMinimap, PowerBar
  - Recursively descends frame hierarchy (max depth 6)
  - Matches by `frame:GetID() == widgetID`
  - Caches result for next call
- Returns list of matched frame objects or empty table

**Called by**:
- `ApplyDefaultPreyIconVisibility()` (suppression of default icon texture)

**Cache Invalidation**:
- Cache persists for session (recreate on ADDON_LOADED if needed)
- No explicit invalidate needed; Blizzard widget IDs stable within session

---

### Widget Type & State Constants

```lua
-- Returns C_UIWidgetManager enum value for prey hunt widget type (31)
-- Falls back to literal 31 if enum missing
function PreyWidgetBridgeModule:GetWidgetTypePreyHuntProgress()

-- Returns C_UIWidgetManager enum value for "shown" widget state (1)
-- Falls back to literal 1 if enum missing
function PreyWidgetBridgeModule:GetShownStateShown()
```

**Purpose**: Wrap Blizzard enum lookups so changes don't scatter constants throughout codebase.

---

### Widget Aging Tracker

```lua
-- Updates state.lastWidgetSeenAt to current time if widget is active
-- Called after successful GetWidgetState() query
function PreyWidgetBridgeModule:MarkWidgetSeen(state, now)
```

**Behavior**:
- If `now` is number: `state.lastWidgetSeenAt = now`
- If `now` is nil: `state.lastWidgetSeenAt = GetTime() or 0`
- Returns void

**Purpose**: Track recency for heuristics like "widget was visible in last 8 seconds" (used by UpdatePreyState).

---

### Widget Candidate Enumeration

```lua
-- Returns list of candidate widget set IDs to scan
-- Maps to WoW's 4 container locations
function PreyWidgetBridgeModule:GetCandidateWidgetSetIDs()
```

**Returns**: 
```lua
{
    "UIWidgetTopCenterContainer",
    "UIWidgetObjectiveTrackerContainer",
    "UIWidgetBelowMinimapContainer",
    "UIWidgetPowerBarContainer",
}
```

**Purpose**: Localize widget container frame names so Updates don't hardcode them.

---

### Module Lifecycle

```lua
function PreyWidgetBridgeModule:OnAddonLoaded()
    -- Initialize widget constants (C_UIWidgetManager checks)
    -- Validate availability via IsWidgetAvailable()
end

function PreyWidgetBridgeModule:OnDisable()
    -- Clear widget frame cache if warband module disabled
    -- (Preserves consistency: no widget scanning if warband disabled)
end
```

---

## State Contract

### Managed State

**In module-private scope**:
- `widgetFrameCache` – Table of `{ [widgetID] = {frame1, frame2, ...} }`
- `widgetTypeConstant` – Cached C_UIWidgetManager.WidgetType.PreyHuntProgress or 31
- `shownStateConstant` – Cached C_UIWidgetManager.WidgetShownState.Shown or 1

### Mutated External State

**In `state` table (passed from Preydator.lua)**:
- `state.lastWidgetSeenAt` – Unix timestamp of last widget detection (written by MarkWidgetSeen)
- `state.progressState` – NOT written by Bridge; caller (UpdatePreyState) writes based on returned value
- `state.progressPercent` – NOT written by Bridge; caller (UpdatePreyState) writes based on returned value

**Rationale**: Bridge is pure query + lightweight timestamp; doesn't mutate quest/progress data.

---

## Event Flow

```
UpdatePreyState() [Preydator.lua]
  ↓
  Bridge:GetWidgetState(state.activeQuestID)
  ↓ returns {progressState, tooltip, progressPercent}
  ↓
  Update state.progressState, state.progressPercent locally
  ↓
  Call Bridge:MarkWidgetSeen(state, now) if widget was found
  ↓
  Render bar, emit events, etc.
```

**No event listeners in Bridge**: Core event handler (Preydator.lua) decides when to call GetWidgetState().

---

## Dependencies (Injected)

**Preydator.lua provides** (via `GetModule` calls):
- `PreyRuntime:FindPreyWidgetProgressState()` – Fallback widget query
- `PreyRuntime:GetStageFromProgressState()` – Stage derivation

**Settings** (read-only):
- `settings.disableDefaultPreyIcon` – Used by `ApplyDefaultPreyIconVisibility()`

**Global Blizzard APIs**:
- `C_UIWidgetManager` (optional; gracefully unavailable if nil)
- `CreateFrame`, `UIParent` (for widget frame discovery)

---

## Not Owned by PreyWidgetBridge

1. **Bar Rendering**: PreyBarUI / Preydator.lua; Bridge just detects "is widget active"
2. **Icon Suppression UI Logic**: Stays in Preydator.lua as `ApplyDefaultPreyIconVisibility()` (no coupling to Bridge)
3. **Event Registration**: Core event loop in Preydator.lua decides when to call Bridge
4. **Polling Control**: `ShouldUseActivePolling()` logic stays in core
5. **Quest Lifecycle**: PreyRuntime owns quest state, lifecycle, zone checks
6. **Zone Validation**: PreyRuntime / ZoneGateV2 owns zone boundary checks

---

## Implementation Scope

**Lines of code**: ~200 (widget detection, frame discovery, constants, helpers)

**Files changed**:
- Create: `Modules/PreyWidgetBridge.lua`
- Update: `Preydator.toc` (add module load order)
- Update: `Preydator.lua` (one call site: `local bridge = GetModule("PreyWidgetBridge")`)
- Minimal `UpdatePreyState()` refactor: Replace inline `FindPreyWidgetProgressState()` with `bridge:GetWidgetState()`

---

## Validation Checklist

- [ ] GetWidgetState() returns expected tuple or error-safe defaults
- [ ] IsWidgetAvailable() correctly detects missing C_UIWidgetManager
- [ ] ExtractWidgetQuestID() handles all 3 field name variants
- [ ] FindGlobalFramesForWidgetID() caches and returns correct frames
- [ ] Widget aging (lastWidgetSeenAt) updates on detection
- [ ] No direct widget frame mutations (read-only scanning)
- [ ] Fallback to PreyRuntime.FindPreyWidgetProgressState() if broken
- [ ] Compiles without errors

---

## Rollout Plan

1. **Create module** → Implement public APIs above
2. **Register in toc** → Load after PreyBarUI, before HuntScanner
3. **Test GetWidgetState()** → Verify with /inspect command
4. **Refactor UpdatePreyState()** → Replace inline calls with `bridge:GetWidgetState()`
5. **Validate icon suppression** → Confirm ApplyDefaultPreyIconVisibility() still works
6. **Compile & test in-game** → Widget detection, bar updates, quest transitions
