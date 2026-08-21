# Preydator core functionality audit

This file is a working issue document for the runtime paths that control the real addon behavior: quest tracking, prey-zone resolution, bar visibility, and the state that is consumed by the UI.

## Scope and intent

This is not a release note. It is a code-level reference for the actual logic that drives the active prey flow.

The code paths below are the ones that matter for the current bug:

- Preydator.lua
- Core/PreyContextRuntime.lua
- Core/BarRuntime.lua
- Core/EventRuntime.lua
- Modules/DebugInspect.lua
- Modules/Settings.lua
- Modules/SlashCommands.lua
- Core/Alerts.lua

---

## 1) Core files and responsibilities

### Preydator.lua

This is the main runtime orchestrator. It contains:

- the state table
- the active prey quest tracking
- `RefreshInPreyZoneStatus()`
- `ShouldScanPreyRuntimeNow()`
- `UpdatePreyState()`
- the top-level bar update delegate

Relevant logic:

```lua
local function RefreshInPreyZoneStatus(questID, force)
    local runtime = GetRuntimeModule("PreyContextRuntime")
    if runtime and type(runtime.RefreshInPreyZoneStatus) == "function" then
        if not IsValidQuestID(questID) and ((state.questListenUntil or 0) <= (GetTime and GetTime() or 0)) then
            state.inPreyZone = nil
            state.preyZoneName = nil
            state.preyZoneMapID = nil
            state.confirmedPreyZoneMapID = nil
            state.zoneCacheDirty = false
            return nil
        end

        local result = runtime:RefreshInPreyZoneStatus(questID, force, state, {
            isValidQuestID = IsValidQuestID,
            getTime = GetTime,
            questLog = C_QuestLog,
        })
        if result ~= nil then
            state.inPreyZone = result
        end
        return result
    end

    if not IsValidQuestID(questID) then
        local now = GetTime and GetTime() or 0
        if ((state.questListenUntil or 0) <= now) then
            state.inPreyZone = nil
            state.preyZoneName = nil
            state.preyZoneMapID = nil
            state.confirmedPreyZoneMapID = nil
            state.zoneCacheDirty = false
            return nil
        end
    end

    local now = GetTime and GetTime() or 0
    local inPreyZone = IsPreyQuestOnCurrentMap(questID)
    state.playerMapID = nil
    state.playerMapHierarchy = nil
    state.zoneCacheDirty = false
    state.inPreyZone = inPreyZone
    state.lastZoneStatusRefreshAt = now
    state.preyZoneMapID = nil
    state.confirmedPreyZoneMapID = nil
    return inPreyZone
end
```

```lua
local function ShouldScanPreyRuntimeNow()
    local now = GetTime and GetTime() or 0

    if type(IsQuestStillActive) ~= "function" then
        return ((state and state.questListenUntil) or 0) > now
    end

    if IsValidQuestID(state and state.activeQuestID) and not IsQuestStillActive(state.activeQuestID) then
        ClearTrackedPreyQuestState()
        return false
    end

    if IsValidQuestID(state and state.activeQuestID) and IsQuestStillActive(state.activeQuestID) then
        return true
    end

    local liveQuestID = GetCurrentActivePreyQuestCached(ACTIVE_PREY_QUEST_CACHE_SECONDS)
    if IsValidQuestID(liveQuestID) and IsQuestStillActive(liveQuestID) then
        return true
    end

    if ((state and state.questListenUntil) or 0) > now then
        return true
    end

    return false
end
```

```lua
UpdatePreyState = function()
    if not ShouldScanPreyRuntimeNow() then
        state.inPreyZone = nil
        state.preyZoneName = nil
        state.preyZoneMapID = nil
        state.confirmedPreyZoneMapID = nil
        state.zoneCacheDirty = false
        state.preyTooltipText = nil
        state.progressState = nil
        state.progressPercent = nil
        state.lastWidgetSeenAt = 0
        state.lastWidgetSetupAt = 0
        state.lastWidgetBoundQuestID = nil
        preyWidgetInfoCache = nil
        return
    end
```

```lua
if hasActiveQuest then
    ResetStateForNewQuest(questID)
    local inZoneBeforeRefresh = state.inPreyZone == true
    local liveInPreyZone = RefreshInPreyZoneStatus(questID, false)
    if liveInPreyZone ~= nil then
        state.inPreyZone = liveInPreyZone
    end
    enteredPreyZoneThisPass = (state.inPreyZone == true and not inZoneBeforeRefresh)

    if state.inPreyZone == false and not forceKillStage and not forceAmbushAlert then
        state.lastPercentSource = "none"
        state.preyTooltipText = nil
        ApplyDefaultPreyIconVisibility()
        UpdateBarDisplay()
        return
    end
end
```

### Core/PreyContextRuntime.lua

This is the zone-resolution and `isOnMap` authority code. It is responsible for the actual prey-zone check.

Relevant logic:

```lua
function PreyContextRuntime:IsPreyQuestOnCurrentMap(questID, ctx)
    local numericQuestID = SafeToNumber(questID)
    if not numericQuestID then
        return nil
    end

    local questLog = ctx and ctx.questLog
    if questLog and type(questLog.GetLogIndexForQuestID) == "function" and type(questLog.GetInfo) == "function" then
        local logIndex = questLog.GetLogIndexForQuestID(numericQuestID)
        if logIndex then
            local okInfo, info = pcall(questLog.GetInfo, logIndex)
            if okInfo and type(info) == "table" and info.isOnMap ~= nil then
                return info.isOnMap == true
            end
        end
    end

    return nil
end
```

```lua
function PreyContextRuntime:RefreshInPreyZoneStatus(questID, force, state, ctx)
    if type(state) ~= "table" then
        return nil
    end

    local isValidQuestID = ctx and ctx.isValidQuestID
    if type(isValidQuestID) ~= "function" or not isValidQuestID(questID) then
        state.inPreyZone = nil
        state.preyZoneMapID = nil
        state.confirmedPreyZoneMapID = nil
        state.zoneCacheDirty = false
        return nil
    end

    local getTime = ctx and ctx.getTime
    local now = (type(getTime) == "function" and getTime()) or 0

    local shouldRefresh = force == true
        or state.inPreyZone == nil
        or state.inPreyZone == false
        or state.zoneCacheDirty == true
    if not shouldRefresh then
        return state.inPreyZone
    end

    local inPreyZone = self:IsPreyQuestOnCurrentMap(questID, ctx)
    if inPreyZone == false then
        state.preyZoneMapID = nil
        state.confirmedPreyZoneMapID = nil
        state.playerMapID = nil
        state.playerMapHierarchy = nil
        state.inPreyZone = false
        state.zoneCacheDirty = false
        state.lastZoneStatusRefreshAt = now
        return false
    elseif inPreyZone == true then
        state.preyZoneMapID = nil
        state.confirmedPreyZoneMapID = nil
        state.playerMapID = nil
        state.playerMapHierarchy = nil
        state.inPreyZone = true
        state.zoneCacheDirty = false
        state.lastZoneStatusRefreshAt = now
        return true
    end

    state.preyZoneMapID = nil
    state.confirmedPreyZoneMapID = nil
    state.playerMapID = nil
    state.playerMapHierarchy = nil
    state.inPreyZone = nil
    state.zoneCacheDirty = false
    state.lastZoneStatusRefreshAt = now
    return nil
end
```

This is critical because it is the code that sets `state.inPreyZone` to `true`, `false`, or `nil` based on the actual quest-log result.

### Core/BarRuntime.lua

This is the final show/hide decision for the bar.

```lua
if hasActiveQuest and state.inPreyZone == nil and settings.onlyShowInPreyZone == true then
    local questID = tonumber(state.activeQuestID)
    if questID and questID > 0 and C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function"
        and type(C_QuestLog.GetInfo) == "function" then
        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        if logIndex then
            local okInfo, info = pcall(C_QuestLog.GetInfo, logIndex)
            if okInfo and type(info) == "table" and info.isOnMap ~= nil then
                state.inPreyZone = info.isOnMap == true
            end
        end
    end
end
```

```lua
elseif onlyShowInPreyZone then
    shouldShow = (hasActiveQuest and state.inPreyZone == true) or inStageFourInZone
else
    shouldShow = true
end
```

Once the decision is made, the actual show/hide is done here:

```lua
if not shouldShow then
    UI.barFrame:Hide()
    ctx.runModuleHook("OnAfterUpdateBarDisplay", {
        shouldShowBar = false,
        forceAmbushAlert = forceAmbushAlert,
        forceBloodyCommandAlert = forceBloodyCommandAlert,
        forceKillStage = forceKillStage,
        hasActiveQuest = hasActiveQuest,
        displayPercent = 0,
        stage = state.stage,
    })
    return
end

UI.barFrame:Show()
```

### Core/EventRuntime.lua

This is the event layer that clears and resets zone state. It is one of the biggest candidates for stale or nil rewrites after a fresh API result.

```lua
if event == "PLAYER_LOGIN"
    or event == "PLAYER_ENTERING_WORLD"
    or event == "ZONE_CHANGED"
    or event == "ZONE_CHANGED_INDOORS"
    or event == "ZONE_CHANGED_NEW_AREA" then
    if state.inPreyZone == false then
        state.zoneCacheDirty = true
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
        if event ~= "ZONE_CHANGED_NEW_AREA" or state.inPreyZone ~= true or state.confirmedPreyZoneMapID == nil then
            state.inPreyZone = nil
            state.confirmedPreyZoneMapID = nil
            state.zoneCacheDirty = true
        else
            state.zoneCacheDirty = true
        end
    elseif state.inPreyZone ~= true then
        state.zoneCacheDirty = true
    end
```

This is the exact place where the state can be intentionally nulled during zone transitions, and it explains why a correct `GetInfo(...).isOnMap` answer can still be lost if a later event resets `state.inPreyZone` before the bar decision runs.

### Modules/DebugInspect.lua

This module is what exposes the logs we reviewed. It prints the exact state that the runtime is using.

```lua
add("Preydator Inspect (module) | addon=" .. GetAddonVersionSafe())
add("- time=" .. string.format("%.3f", now) .. " | zone=" .. tostring(GetZoneText and GetZoneText() or "?") .. " | playerMapID=" .. tostring(playerMapID) .. " | playerMap=" .. tostring(playerMapName))
add("- instance inInstance=" .. tostring(inInstance) .. " | instanceType=" .. tostring(instanceType) .. " | playerMapType=" .. tostring(playerMapType))
add("- quest live=" .. tostring(liveQuestID) .. " | hasActive=" .. tostring(hasActiveQuest) .. " | tracked=" .. tostring(state.activeQuestID))
add("- state stage=" .. tostring(state.stage) .. " | progressState=" .. tostring(state.progressState) .. " | progressPercent=" .. tostring(state.progressPercent))
add("- preyZone mapID=" .. tostring(state.preyZoneMapID) .. " | preyZoneName=" .. tostring(state.preyZoneName) .. " | zoneCacheDirty=" .. tostring(state.zoneCacheDirty))
add("- inPreyZone=" .. tostring(state.inPreyZone)
    .. " | onlyShowInPreyZone=" .. tostring(settings and settings.onlyShowInPreyZone == true)
    .. " | disableDefaultPreyIcon=" .. tostring(settings and settings.disableDefaultPreyIcon == true))
```

```lua
local hasCertifiedWidgetZoneSignal = state and state.inPreyZone == nil
    and preyWidgetVisible
    and hasResolvedPreyZoneEvidence
```

```lua
elseif onlyShowInPreyZone then
    local inZoneSignal = (state and state.inPreyZone == true)
        or hasCertifiedWidgetZoneSignal
    shouldShowBar = (hasActiveQuest and inZoneSignal) or inStageFourInZone
    visibilityReason = shouldShowBar and "onlyShowInPreyZone-pass" or "onlyShowInPreyZone-block"
```

That is the final human-readable truth source for the bar decision.

---

## 2) What the logs prove

The evidence from the debug output shows the same pattern repeatedly:

- `liveQuestID` is present
- `hasActive=true`
- `state.inPreyZone=nil`
- `GetInfo(35).isOnMap=true` or `false`
- `bar shown=false` or `bar shown=true` depending on the state of the stale value and the path that last mutated it

Example from the logs:

```text
- quest live=95021 | hasActive=true | tracked=95021
- inPreyZone=nil | onlyShowInPreyZone=true | disableDefaultPreyIcon=false
- GetInfo(35)={..., isOnMap=true, ...}
- visibility shouldShowBar=false | reason=onlyShowInPreyZone-block
```

and the reverse case:

```text
- inPreyZone=nil | onlyShowInPreyZone=true
- GetInfo(35)={..., isOnMap=false, ...}
- bar shown=true
```

The exact bug is therefore not just “fallback code still runs.” The actual problem is that the runtime is allowing `state.inPreyZone` to stay nil or be overwritten after the live `isOnMap` read, and the bar gates on that stale/missing value.

---

## 3) Why this still happens even with the current code

There are multiple places that can clear or override the same state variable after the quest-log answer is gathered:

1. `ClearTrackedPreyQuestState()` explicitly sets:

```lua
state.inPreyZone = nil
```

2. `ShouldScanPreyRuntimeNow()` can trigger a clear path:

```lua
if IsValidQuestID(state and state.activeQuestID) and not IsQuestStillActive(state.activeQuestID) then
    ClearTrackedPreyQuestState()
    return false
end
```

3. `UpdatePreyState()` does this early exit:

```lua
if not ShouldScanPreyRuntimeNow() then
    state.inPreyZone = nil
    state.preyZoneName = nil
    state.preyZoneMapID = nil
    state.confirmedPreyZoneMapID = nil
    state.zoneCacheDirty = false
    return
end
```

4. `Core/EventRuntime.lua` sets `state.inPreyZone = nil` on login / entering world / zone transitions:

```lua
if event ~= "ZONE_CHANGED_NEW_AREA" or state.inPreyZone ~= true or state.confirmedPreyZoneMapID == nil then
    state.inPreyZone = nil
    state.confirmedPreyZoneMapID = nil
    state.zoneCacheDirty = true
end
```

5. `RefreshInPreyZoneStatus()` can also end by returning `nil` when `IsPreyQuestOnCurrentMap()` has no authoritative answer.

That means the bug is real: the live `GetInfo(...).isOnMap` answer can be fetched, but the state used for the UI can be cleared or left nil before the final bar gate is evaluated.

---

## 4) The actual root cause pattern

The key logic flow is:

1. active prey quest is present
2. the runtime checks `GetInfo(...).isOnMap`
3. `state.inPreyZone` is expected to adopt that answer
4. the UI bar gate reads `state.inPreyZone`
5. if `state.inPreyZone` is cleared or left nil later, the final visibility rule says hide or show based on stale/unknown data

This is exactly the pattern seen in the user logs:

- `GetInfo(...).isOnMap=true` while `state.inPreyZone=nil`
- `GetInfo(...).isOnMap=false` while `state.inPreyZone=nil`
- final `shouldShowBar` resolves to `onlyShowInPreyZone-block` even though the live API answer was already truthy/falsey

That is the bug being reproduced.

---

## 5) Minimal file list to keep in scope

If the fix remains focused on the root cause, the actual relevant code is this set:

- [Preydator.lua](../Preydator.lua)
- [Core/PreyContextRuntime.lua](../Core/PreyContextRuntime.lua)
- [Core/BarRuntime.lua](../Core/BarRuntime.lua)
- [Core/EventRuntime.lua](../Core/EventRuntime.lua)
- [Modules/DebugInspect.lua](../Modules/DebugInspect.lua)
- [Core/Alerts.lua](../Core/Alerts.lua)

Everything else should be treated as supporting logic, not the root of this bug.

---

## 6) Final assessment

The existing code is indeed structured around the correct runtime principle:

- `C_QuestLog.GetInfo(...).isOnMap` is the authority for the active prey zone decision
- `state.inPreyZone` is the state that the bar ultimately acts on

The bug is not that the code never asks the API. The bug is that the final gate is still vulnerable to stale and nil rewrites of the same state field after the API has already answered.

This is exactly why the logs still show:

- `isOnMap=true` but bar hidden
- `isOnMap=false` but bar shown
- `state.inPreyZone=nil` in both cases

The real fix is not to add another fallback. The real fix is to stop clearing or overwriting `state.inPreyZone` after the runtime has a live answer, and to ensure the final bar decision always consumes the current live value before deciding visible vs hidden.
