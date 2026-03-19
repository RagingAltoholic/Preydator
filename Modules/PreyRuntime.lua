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

    if not (C_TaskQuest and C_TaskQuest.GetQuestZoneID and C_Map and C_Map.GetMapInfo) then
        -- Fall back to HuntScanner cache when C_TaskQuest APIs are unavailable.
        local scanner = Preydator and Preydator.GetModule and Preydator:GetModule("HuntScanner")
        if scanner and type(scanner.GetQuestZoneMapID) == "function" then
            local cachedMapID = scanner:GetQuestZoneMapID(questID)
            if cachedMapID then
                local cachedMapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(cachedMapID)
                if cachedMapInfo then
                    return cachedMapInfo.name, cachedMapID
                end
            end
        end
        return nil, nil
    end

    local mapID = C_TaskQuest.GetQuestZoneID(questID)
    if mapID then
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo then
            return mapInfo.name, mapID
        end
    end

    -- C_TaskQuest sometimes returns nil transiently; use scanner cache as a fallback.
    local scanner = Preydator and Preydator.GetModule and Preydator:GetModule("HuntScanner")
    if scanner and type(scanner.GetQuestZoneMapID) == "function" then
        local cachedMapID = scanner:GetQuestZoneMapID(questID)
        if cachedMapID then
            local cachedMapInfo = C_Map.GetMapInfo(cachedMapID)
            if cachedMapInfo then
                return cachedMapInfo.name, cachedMapID
            end
        end
    end

    return nil, nil
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

