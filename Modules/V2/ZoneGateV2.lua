---@diagnostic disable

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local C_Map = _G.C_Map
local IsInInstance = _G.IsInInstance
local GetZoneText = _G.GetZoneText
local string = _G.string

local ZoneGateV2 = {}
Preydator:RegisterModule("ZoneGateV2", ZoneGateV2)

local function NormalizeZoneName(name)
    if type(name) ~= "string" then
        return nil
    end
    local trimmed = name:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then
        return nil
    end
    return string.lower(trimmed)
end

local function BuildMapAncestrySet(mapID)
    if type(mapID) ~= "number" or not (C_Map and type(C_Map.GetMapInfo) == "function") then
        return nil
    end

    local set = {}
    local currentMapID = mapID
    local guard = 0
    while currentMapID and guard < 30 do
        if set[currentMapID] then
            break
        end
        set[currentMapID] = true

        local mapInfo = C_Map.GetMapInfo(currentMapID)
        if not mapInfo or not mapInfo.parentMapID or mapInfo.parentMapID == 0 then
            break
        end

        currentMapID = mapInfo.parentMapID
        guard = guard + 1
    end

    return set
end

function ZoneGateV2:IsInInstance()
    if type(IsInInstance) ~= "function" then
        return false, nil
    end
    local ok, inInstance, instanceType = pcall(IsInInstance)
    if not ok then
        return false, nil
    end
    return inInstance == true, instanceType
end

function ZoneGateV2:IsInPreyZone(preyMapID)
    if type(preyMapID) ~= "number" then
        return false
    end
    if not (C_Map and type(C_Map.GetBestMapForUnit) == "function" and type(C_Map.GetMapInfo) == "function") then
        return false
    end
    local playerMapID = C_Map.GetBestMapForUnit("player")
    if type(playerMapID) ~= "number" then
        return false
    end
    local playerChain = BuildMapAncestrySet(playerMapID)
    local preyChain = BuildMapAncestrySet(preyMapID)
    if not playerChain or not preyChain then
        return false
    end

    for mapID in pairs(playerChain) do
        if preyChain[mapID] then
            return true
        end
    end

    -- Compatibility fallback: some prey zones resolve as parallel/sibling map roots
    -- where ancestry does not intersect. In those cases, compare resolved names.
    local playerMapInfo = C_Map.GetMapInfo(playerMapID)
    local preyMapInfo = C_Map.GetMapInfo(preyMapID)
    local playerMapName = playerMapInfo and NormalizeZoneName(playerMapInfo.name) or nil
    local preyMapName = preyMapInfo and NormalizeZoneName(preyMapInfo.name) or nil
    local zoneTextName = NormalizeZoneName(GetZoneText and GetZoneText() or nil)

    if playerMapName and preyMapName and playerMapName == preyMapName then
        return true
    end
    if zoneTextName and preyMapName and zoneTextName == preyMapName then
        return true
    end

    return false
end

function ZoneGateV2:CanScan(activeHunt)
    local inInstance = self:IsInInstance()
    if inInstance then
        return false, "instance"
    end
    local mapID = nil
    if type(activeHunt) == "table" then
        mapID = activeHunt.zoneMapID
    elseif type(activeHunt) == "number" then
        mapID = activeHunt
    end
    if not self:IsInPreyZone(mapID) then
        return false, "out_of_zone"
    end
    return true, "ok"
end
