---@diagnostic disable

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local HuntDataStoreV2 = {
    activeHunt = nil,
    questMeta = {},
}

Preydator:RegisterModule("HuntDataStoreV2", HuntDataStoreV2)

function HuntDataStoreV2:SetActiveHunt(payload)
    if type(payload) ~= "table" then
        return false
    end
    self.activeHunt = payload
    if type(payload.questID) == "number" then
        self.questMeta[payload.questID] = payload
    end
    return true
end

function HuntDataStoreV2:ClearActiveHunt(reason)
    self.activeHunt = nil
    return reason or "unspecified"
end

function HuntDataStoreV2:GetActiveHunt()
    return self.activeHunt
end

function HuntDataStoreV2:GetQuestMeta(questID)
    if type(questID) ~= "number" then
        return nil
    end
    return self.questMeta[questID]
end

function HuntDataStoreV2:HasQuestMeta(questID)
    return self:GetQuestMeta(questID) ~= nil
end
