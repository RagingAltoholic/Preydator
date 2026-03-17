---@diagnostic disable

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local RuntimeCoordinatorV2 = {}
Preydator:RegisterModule("RuntimeCoordinatorV2", RuntimeCoordinatorV2)

local function GetModule(name)
    return Preydator and Preydator.GetModule and Preydator:GetModule(name) or nil
end

local function GetLifecycle()
    return GetModule("QuestLifecycleV2")
end

local function GetStore()
    return GetModule("HuntDataStoreV2")
end

function RuntimeCoordinatorV2:HandleInternalEvent(eventName, payload)
    if eventName ~= "PREY_QUEST_ACCEPTED" and eventName ~= "PREY_QUEST_CLEARED" then
        return nil
    end

    local lifecycle = GetLifecycle()
    if not lifecycle or type(lifecycle.Evaluate) ~= "function" then
        return nil
    end

    local transition = lifecycle:Evaluate(eventName, payload)
    if type(transition) ~= "table" then
        return nil
    end

    self:ApplyTransition(transition)
    self.lastTransition = transition
    return transition
end

function RuntimeCoordinatorV2:ApplyTransition(transition)
    if type(transition) ~= "table" then
        return nil
    end

    local store = GetStore()
    if transition.event == "PREY_QUEST_CLEARED" and store and type(store.GetActiveHunt) == "function" then
        local activeHunt = store:GetActiveHunt()
        local activeQuestID = type(activeHunt) == "table" and activeHunt.questID or nil
        local clearQuestID = type(transition.context) == "table" and transition.context.questID or nil
        if type(activeQuestID) ~= "number" or type(clearQuestID) ~= "number" or tonumber(activeQuestID) ~= tonumber(clearQuestID) then
            return nil
        end
    end

    local lifecycle = GetLifecycle()
    if lifecycle and type(lifecycle.SetState) == "function" then
        lifecycle:SetState(transition.nextState)
    end

    if store then
        if transition.event == "PREY_QUEST_ACCEPTED" and type(store.SetActiveHunt) == "function" then
            store:SetActiveHunt(transition.activeHunt or transition.context)
        elseif transition.event == "PREY_QUEST_CLEARED" and type(store.ClearActiveHunt) == "function" then
            store:ClearActiveHunt(transition.reason)
        end
    end

    if transition.event == "PREY_QUEST_CLEARED" then
        local scanner = GetModule("HuntScanner")
        local onPreyQuestEnded = scanner and scanner.OnPreyQuestEnded
        if type(onPreyQuestEnded) == "function" then
            pcall(onPreyQuestEnded, scanner, transition.context)
        end
    end

    return transition
end

function RuntimeCoordinatorV2:SyncUiFromState()
    return false
end

function RuntimeCoordinatorV2:GetLastTransition()
    return self.lastTransition
end
