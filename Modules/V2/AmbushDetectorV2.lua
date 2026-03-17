---@diagnostic disable

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local AmbushDetectorV2 = {}
Preydator:RegisterModule("AmbushDetectorV2", AmbushDetectorV2)

-- Returns true if ambush listening is permitted for the current V2 lifecycle state.
-- Pass zoneMapID for NPC chat events to also gate on instance type via ZoneGateV2:CanScan.
-- Omit zoneMapID for CHAT_MSG_SYSTEM (state gate only; being in_zone implies prey zone).
function AmbushDetectorV2:ShouldListen(v2State, zoneMapID)
    if v2State ~= "in_zone" then
        return false
    end

    if zoneMapID == nil then
        -- No zone context provided; lifecycle state alone is sufficient gate.
        return true
    end

    -- NPC path: also check instance exclusion via ZoneGateV2.
    local zoneGate = Preydator and Preydator.GetModule and Preydator:GetModule("ZoneGateV2")
    local gateFn = zoneGate and zoneGate.CanScan
    if type(gateFn) == "function" then
        local ok, canScan = pcall(gateFn, zoneGate, zoneMapID)
        if ok then
            return canScan == true
        end
    end

    -- ZoneGateV2 unavailable — deny to avoid false positives.
    return false
end

-- Detects ambush keyword in system messages (case-insensitive).
-- Prey-name match is intentionally excluded for CHAT_MSG_SYSTEM to avoid false
-- positives from quest-accepted system text containing the prey's name.
function AmbushDetectorV2:HandleSystemMessage(msg)
    if type(msg) ~= "string" or msg == "" then
        return false
    end
    return msg:lower():find("ambush", 1, true) ~= nil
end

-- Detects prey presence in NPC chat by matching prey name in message or speaker.
function AmbushDetectorV2:HandleNpcMessage(msg, speaker, preyName)
    if type(msg) ~= "string" or msg == "" then
        return false
    end
    if type(preyName) ~= "string" or preyName == "" then
        return false
    end
    local nameLower = preyName:lower()
    if msg:lower():find(nameLower, 1, true) then
        return true
    end
    if type(speaker) == "string" and speaker ~= "" then
        if speaker:lower():find(nameLower, 1, true) then
            return true
        end
    end
    return false
end
