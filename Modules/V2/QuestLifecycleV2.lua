---@diagnostic disable

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local QuestLifecycleV2 = {
    state = "idle",
}

Preydator:RegisterModule("QuestLifecycleV2", QuestLifecycleV2)

function QuestLifecycleV2:Evaluate(eventName, context)
    local current = self.state
    local nextState = current

    if eventName == "PREY_QUEST_ACCEPTED" then
        if type(context) == "table" then
            local stage = tonumber(context.stage) or 1
            if stage >= 4 then
                nextState = "stage4"
            elseif context.inPreyZone == true then
                nextState = "in_zone"
            elseif context.inPreyZone == false then
                nextState = "out_of_zone"
            else
                nextState = "accepted"
            end
        else
            nextState = "accepted"
        end
    elseif eventName == "PREY_QUEST_CLEARED" then
        nextState = "ended"
    end

    return {
        event = eventName,
        state = current,
        nextState = nextState,
        context = context,
        activeHunt = context,
        reason = type(context) == "table" and context.reason or nil,
        changed = nextState ~= current,
    }
end

function QuestLifecycleV2:GetState()
    return self.state
end

function QuestLifecycleV2:SetState(nextState)
    if type(nextState) ~= "string" or nextState == "" then
        return false
    end

    self.state = nextState
    return true
end
