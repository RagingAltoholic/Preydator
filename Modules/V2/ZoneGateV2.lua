---@diagnostic disable

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local C_Map = _G.C_Map
local IsInInstance = _G.IsInInstance

local ZoneGateV2 = {}
Preydator:RegisterModule("ZoneGateV2", ZoneGateV2)

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
