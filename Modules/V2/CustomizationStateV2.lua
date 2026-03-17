---@diagnostic disable

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local CustomizationStateV2 = {
    subscribers = {},
}

Preydator:RegisterModule("CustomizationStateV2", CustomizationStateV2)

local function ResolveSettingsTable()
    if type(Preydator.GetSettings) == "function" then
        local settings = Preydator.GetSettings()
        if type(settings) == "table" then
            return settings
        end
    end
    return nil
end

function CustomizationStateV2:Get(path, fallback)
    local settings = ResolveSettingsTable()
    if type(settings) ~= "table" or type(path) ~= "string" or path == "" then
        return fallback
    end
    local value = settings[path]
    if value == nil then
        return fallback
    end
    return value
end

function CustomizationStateV2:Set(path, value)
    local settings = ResolveSettingsTable()
    if type(settings) ~= "table" or type(path) ~= "string" or path == "" then
        return false
    end
    settings[path] = value
    for _, callback in ipairs(self.subscribers) do
        pcall(callback, path, value)
    end
    return true
end

function CustomizationStateV2:GetEffectiveSettings()
    return ResolveSettingsTable() or {}
end

function CustomizationStateV2:SubscribeSettingsChanged(callback)
    if type(callback) ~= "function" then
        return false
    end
    self.subscribers[#self.subscribers + 1] = callback
    return true
end
