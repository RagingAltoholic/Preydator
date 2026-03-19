---@diagnostic disable

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local AmbushDetectorV2 = {}
Preydator:RegisterModule("AmbushDetectorV2", AmbushDetectorV2)

local string = _G.string
local IsInInstance = _G.IsInInstance

local function IsInAnyInstance()
    local zoneGate = Preydator and Preydator.GetModule and Preydator:GetModule("ZoneGateV2")
    local inInstanceFn = zoneGate and zoneGate.IsInInstance
    if type(inInstanceFn) == "function" then
        local ok, inInstance = pcall(inInstanceFn, zoneGate)
        if ok then
            return inInstance == true
        end
    end

    if type(IsInInstance) == "function" then
        local ok, inInstance = pcall(IsInInstance)
        if ok then
            return inInstance == true
        end
    end

    return false
end

-- Returns true if ambush listening is permitted for the current V2 lifecycle state.
-- Pass zoneMapID for NPC chat events to also gate on instance type via ZoneGateV2:CanScan.
-- Omit zoneMapID for CHAT_MSG_SYSTEM (state gate only; being in_zone implies prey zone).
function AmbushDetectorV2:ShouldListen(v2State, zoneMapID)
    -- Hard safety rail: ambush detection is never allowed inside instances,
    -- regardless of active quest or lifecycle state.
    if IsInAnyInstance() then
        return false
    end

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

    local okLower, msgLower = pcall(string.lower, msg)
    if not okLower or type(msgLower) ~= "string" then
        return false
    end

    local okFind, found = pcall(string.find, msgLower, "ambush", 1, true)
    return okFind and found ~= nil
end

function AmbushDetectorV2:MaybeHandleSystemMessage(v2State, msg)
    local canListen = self:ShouldListen(v2State)
    if not canListen then
        return false, false
    end

    local matched = self:HandleSystemMessage(msg)
    return matched, true
end

-- Detects prey presence in NPC chat by matching prey name in message or speaker.
function AmbushDetectorV2:HandleNpcMessage(msg, speaker, preyName)
    if type(preyName) ~= "string" or preyName == "" then
        return false
    end

    if type(msg) ~= "string" then
        return false
    end

    local okNameLower, nameLower = pcall(string.lower, preyName)
    if not okNameLower or type(nameLower) ~= "string" or nameLower == "" then
        return false
    end

    local okMsgLower, msgLower = pcall(string.lower, msg)
    if okMsgLower and type(msgLower) == "string" then
        local okFindMsg, msgFound = pcall(string.find, msgLower, nameLower, 1, true)
        if okFindMsg and msgFound ~= nil then
            return true
        end
    end

    if type(speaker) == "string" then
        local okSpeakerLower, speakerLower = pcall(string.lower, speaker)
        if okSpeakerLower and type(speakerLower) == "string" then
            local okFindSpeaker, speakerFound = pcall(string.find, speakerLower, nameLower, 1, true)
            if okFindSpeaker and speakerFound ~= nil then
                return true
            end
        end
    end

    return false
end

function AmbushDetectorV2:MaybeHandleNpcMessage(v2State, zoneMapID, msg, speaker, preyName)
    local canListen = self:ShouldListen(v2State, zoneMapID)
    if not canListen then
        return false, false
    end

    local matched = self:HandleNpcMessage(msg, speaker, preyName)
    return matched, true
end
