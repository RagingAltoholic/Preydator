---@diagnostic disable

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable

local PreyRuntimeModule = {}
Preydator:RegisterModule("PreyRuntime", PreyRuntimeModule)

local C_QuestLog = _G.C_QuestLog
local C_TaskQuest = _G.C_TaskQuest
local C_Map = _G.C_Map
local C_UIWidgetManager = _G.C_UIWidgetManager
local type = _G.type
local tonumber = _G.tonumber
local ipairs = _G.ipairs

function PreyRuntimeModule:GetStageFromProgressState(progressState)
    if progressState == nil then
        return 1
    end

    if progressState == 0 then
        return 1
    end

    if progressState == 1 then
        return 2
    end

    if progressState == 2 then
        return 3
    end

    if progressState == 3 then
        return 4
    end

    return 1
end

function PreyRuntimeModule:IsQuestStillActive(questID)
    if not questID or questID < 1 then
        return false
    end

    if C_QuestLog and C_QuestLog.GetActivePreyQuest then
        local activePreyQuestID = tonumber(C_QuestLog.GetActivePreyQuest())
        if activePreyQuestID and activePreyQuestID == questID then
            return true
        end
    end

    if C_QuestLog and C_QuestLog.IsOnQuest then
        return C_QuestLog.IsOnQuest(questID) and true or false
    end

    return true
end

function PreyRuntimeModule:GetCurrentActivePreyQuest()
    if C_QuestLog and C_QuestLog.GetActivePreyQuest then
        return C_QuestLog.GetActivePreyQuest()
    end

    return nil
end

function PreyRuntimeModule:GetPreyZoneInfo(questID)
    if not questID then
        return nil, nil
    end

    -- Query HuntScanner zone cache first — more reliable than C_TaskQuest for prey quests.
    local scanner = Preydator and Preydator.GetModule and Preydator:GetModule("HuntScanner")
    if scanner and type(scanner.GetQuestZoneMapID) == "function" then
        local mapID = scanner:GetQuestZoneMapID(questID)
        if mapID and C_Map and C_Map.GetMapInfo then
            local mapInfo = C_Map.GetMapInfo(mapID)
            if mapInfo then
                return mapInfo.name, mapID
            end
        end
    end

    if not (C_TaskQuest and C_TaskQuest.GetQuestZoneID and C_Map and C_Map.GetMapInfo) then
        return nil, nil
    end

    local mapID = C_TaskQuest.GetQuestZoneID(questID)
    if not mapID then
        return nil, nil
    end

    local mapInfo = C_Map.GetMapInfo(mapID)
    return (mapInfo and mapInfo.name or nil), mapID
end

function PreyRuntimeModule:IsPlayerInPreyZone(preyMapID)
    local zoneGate = Preydator and Preydator.GetModule and Preydator:GetModule("ZoneGateV2")
    local gateFn = zoneGate and zoneGate.IsInPreyZone
    if type(gateFn) == "function" then
        local ok, inZone = pcall(gateFn, zoneGate, preyMapID)
        if ok then
            return inZone == true
        end
    end

    if not preyMapID then
        return nil
    end

    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then
        return nil
    end

    local playerMapID = C_Map.GetBestMapForUnit("player")
    if not playerMapID then
        return nil
    end

    if playerMapID == preyMapID then
        return true
    end

    local guard = 0
    local currentMapID = playerMapID
    while currentMapID and guard < 20 do
        local mapInfo = C_Map.GetMapInfo(currentMapID)
        if not mapInfo then
            break
        end

        if mapInfo.parentMapID == preyMapID then
            return true
        end

        currentMapID = mapInfo.parentMapID
        guard = guard + 1
    end

    return false
end

function PreyRuntimeModule:ApplyResetStateForNewQuest(state, questID, preyTargetName, preyTargetDifficulty)
    if type(state) ~= "table" then
        return false
    end

    if state.activeQuestID == questID then
        return false
    end

    state.activeQuestID = questID
    state.lastNotifiedPreyEndQuestID = nil
    state.progressState = nil
    state.progressPercent = nil
    state.stageSoundPlayed = {}
    state.stage = 1
    state.preyZoneName, state.preyZoneMapID = self:GetPreyZoneInfo(questID)
    state.inPreyZone = self:IsPlayerInPreyZone(state.preyZoneMapID)
    state.preyTooltipText = nil
    state.preyTargetName = preyTargetName
    state.preyTargetDifficulty = preyTargetDifficulty
    state.ambushAlertUntil = 0
    state.lastAmbushSystemMessage = nil

    return true
end

function PreyRuntimeModule:EvaluateQuestLifecycle(state, questID, hasActiveQuest, hasWidgetData, now, maxStage)
    if type(state) ~= "table" then
        return false, false, false, false
    end

    local questCompleted = false
    if questID and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        questCompleted = C_QuestLog.IsQuestFlaggedCompleted(questID) and true or false
    end

    -- hasActiveQuest was already confirmed authoritative by the caller (via GetActivePreyQuest).
    -- Avoid re-calling IsQuestStillActive which can transiently disagree, causing a false clear
    -- that wipes state.activeQuestID and triggers a needsQuestBootstrap CPU loop.
    local questStillActive = hasActiveQuest or self:IsQuestStillActive(questID)
    local killStageUntil = tonumber(state.killStageUntil) or 0
    local currentTime = tonumber(now) or 0

    -- Do not clear while an active prey quest is still live; IsQuestFlaggedCompleted can be true
    -- in edge timing windows and would otherwise cause a tracked=nil bootstrap loop.
    local shouldClear = (not hasActiveQuest and not (killStageUntil > currentTime))
        or (hasActiveQuest and not questStillActive and not hasWidgetData)

    local completedTransition = questCompleted
        or (((not hasActiveQuest) or (not questStillActive)) and tonumber(state.stage) == tonumber(maxStage))

    return questCompleted, questStillActive, shouldClear, completedTransition
end

function PreyRuntimeModule:FindPreyWidgetProgressState(activeQuestID, context)
    local bridge = Preydator and Preydator.GetModule and Preydator:GetModule("PreyWidgetBridge")
    local bridgeFn = bridge and bridge.GetWidgetState
    if type(bridgeFn) == "function" then
        local ok, progressState, tooltipText, progressPercent = pcall(bridgeFn, bridge, activeQuestID)
        if ok then
            return true, progressState, tooltipText, progressPercent
        end
    end

    if not (C_UIWidgetManager and C_UIWidgetManager.GetAllWidgetsBySetID and C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo) then
        return false, nil, nil, nil
    end

    if type(context) ~= "table" then
        return false, nil, nil, nil
    end

    local getWidgetType = context.GetWidgetTypePreyHuntProgress
    local getShownState = context.GetShownStateShown
    local getCandidateSetIDs = context.GetCandidateWidgetSetIDs
    local extractPercent = context.ExtractProgressPercent
    local isValidQuestID = context.IsValidQuestID
    local extractWidgetQuestID = context.ExtractWidgetQuestID

    if type(getWidgetType) ~= "function"
        or type(getShownState) ~= "function"
        or type(getCandidateSetIDs) ~= "function"
        or type(extractPercent) ~= "function"
        or type(isValidQuestID) ~= "function"
        or type(extractWidgetQuestID) ~= "function"
    then
        return false, nil, nil, nil
    end

    local preyWidgetType = getWidgetType()
    local shownStateShown = getShownState()
    local fallbackState, fallbackTooltip, fallbackPct = nil, nil, nil

    for _, setID in ipairs(getCandidateSetIDs() or {}) do
        local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(setID)
        if widgets then
            for _, widget in ipairs(widgets) do
                if widget and widget.widgetType == preyWidgetType then
                    local info = C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo(widget.widgetID)
                    if info and info.shownState == shownStateShown then
                        local pct = extractPercent(info, info.tooltip)
                        if isValidQuestID(activeQuestID) then
                            local widgetQuestID = extractWidgetQuestID(info)
                            if widgetQuestID == activeQuestID then
                                return true, info.progressState, info.tooltip, pct
                            end

                            if widgetQuestID == nil and fallbackState == nil then
                                fallbackState, fallbackTooltip, fallbackPct = info.progressState, info.tooltip, pct
                            end
                        else
                            return true, info.progressState, info.tooltip, pct
                        end
                    end
                end
            end
        end
    end

    if isValidQuestID(activeQuestID) then
        return true, fallbackState, fallbackTooltip, fallbackPct
    end

    return true, nil, nil, nil
end
