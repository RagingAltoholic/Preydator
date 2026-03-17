---@diagnostic disable

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local AmbushDetectorV2 = {}
Preydator:RegisterModule("AmbushDetectorV2", AmbushDetectorV2)

function AmbushDetectorV2:ShouldListen(activeState)
    if activeState == "stage4" then
        return false
    end
    return activeState == "in_zone"
end

function AmbushDetectorV2:HandleSystemMessage(msg)
    return type(msg) == "string" and msg ~= "" and msg:find("Ambush", 1, true) ~= nil
end

function AmbushDetectorV2:HandleNpcMessage(msg, speaker)
    if type(msg) ~= "string" or msg == "" then
        return false
    end
    if type(speaker) ~= "string" or speaker == "" then
        return false
    end
    return false
end
