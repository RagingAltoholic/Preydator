---@diagnostic disable

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable

local MapAndWaypointModule = {}
Preydator:RegisterModule("MapAndWaypoint", MapAndWaypointModule)

local C_QuestLog = _G.C_QuestLog
local C_TaskQuest = _G.C_TaskQuest
local C_Map = _G.C_Map
local C_SuperTrack = _G.C_SuperTrack
local UiMapPoint = _G.UiMapPoint
local OpenQuestMap = _G.OpenQuestMap
local ToggleWorldMap = _G.ToggleWorldMap
local QuestMapFrame_OpenToQuestDetails = _G.QuestMapFrame_OpenToQuestDetails
local tonumber = _G.tonumber
local type = _G.type
local ipairs = _G.ipairs
local pcall = _G.pcall

local function GetState()
    local api = Preydator and Preydator.API
    if api and type(api.GetState) == "function" then
        return api.GetState()
    end

    return nil
end

local function IsValidQuestID(questID)
    local api = Preydator and Preydator.API
    if api and type(api.IsValidQuestID) == "function" then
        return api.IsValidQuestID(questID) == true
    end

    return type(questID) == "number" and questID > 0
end

function MapAndWaypointModule:TryGetPreyQuestWaypoint(questID)
    if not IsValidQuestID(questID) then
        return nil, nil, nil
    end

    if C_QuestLog and C_QuestLog.GetNextWaypoint then
        local waypoint = C_QuestLog.GetNextWaypoint(questID)
        if type(waypoint) == "table" then
            local waypointMapID = tonumber(waypoint.uiMapID or waypoint.mapID)
            local waypointX = tonumber((waypoint.position and waypoint.position.x) or waypoint.x)
            local waypointY = tonumber((waypoint.position and waypoint.position.y) or waypoint.y)
            if waypointMapID and waypointX and waypointY then
                return waypointMapID, waypointX, waypointY
            end
        end
    end

    local state = GetState()
    local mapCandidates = {}
    local seenMapIDs = {}

    local function AddMapCandidate(mapID)
        mapID = tonumber(mapID)
        if mapID and mapID > 0 and not seenMapIDs[mapID] then
            seenMapIDs[mapID] = true
            mapCandidates[#mapCandidates + 1] = mapID
        end
    end

    AddMapCandidate(state and state.preyZoneMapID)
    if C_Map and C_Map.GetBestMapForUnit then
        AddMapCandidate(C_Map.GetBestMapForUnit("player"))
    end

    if C_TaskQuest and C_TaskQuest.GetQuestLocation then
        for _, mapID in ipairs(mapCandidates) do
            local x, y = C_TaskQuest.GetQuestLocation(questID, mapID)
            if x and y then
                return mapID, x, y
            end
        end
    end

    if C_QuestLog and C_QuestLog.GetQuestsOnMap then
        for _, mapID in ipairs(mapCandidates) do
            local questsOnMap = C_QuestLog.GetQuestsOnMap(mapID)
            if type(questsOnMap) == "table" then
                for _, questInfo in ipairs(questsOnMap) do
                    if questInfo and questInfo.questID == questID and questInfo.x and questInfo.y then
                        return mapID, questInfo.x, questInfo.y
                    end
                end
            end
        end
    end

    return nil, nil, nil
end

function MapAndWaypointModule:TryOpenPreyQuestOnMap()
    local state = GetState()
    local questID = state and state.activeQuestID
    if not IsValidQuestID(questID) then
        return false
    end

    if OpenQuestMap then
        pcall(OpenQuestMap)
    elseif ToggleWorldMap then
        ToggleWorldMap()
    elseif _G.WorldMapFrame and _G.WorldMapFrame.Show then
        _G.WorldMapFrame:Show()
    end

    -- Supertrack the quest directly instead of placing a user waypoint pin.
    -- QuestMapFrame_OpenToQuestDetails and SetSuperTrackedUserWaypoint both
    -- trigger protected Blizzard internals (QuestFrameModelScene, SetPassThroughButtons)
    -- that produce ADDON_ACTION_BLOCKED errors.
    if C_SuperTrack and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
        pcall(C_SuperTrack.SetSuperTrackedQuestID, questID)
    end

    return true
end
