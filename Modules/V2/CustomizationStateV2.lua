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

local V2_SCHEMA_VERSION = 1

local function GetTimeStamp()
    local getTime = _G.GetTime
    if type(getTime) == "function" then
        local ok, now = pcall(getTime)
        if ok then
            return tonumber(now) or 0
        end
    end
    return 0
end

local function ResolveSettingsTable()
    if type(Preydator.GetSettings) == "function" then
        local settings = Preydator.GetSettings()
        if type(settings) == "table" then
            return settings
        end
    end
    return nil
end

local function EnsureTable(parent, key)
    if type(parent) ~= "table" or type(key) ~= "string" or key == "" then
        return nil
    end
    if type(parent[key]) ~= "table" then
        parent[key] = {}
    end
    return parent[key]
end

local function EnsureBootstrap(settings)
    if type(settings) ~= "table" then
        return nil
    end

    local v2 = EnsureTable(settings, "customizationV2")
    if type(v2) ~= "table" then
        return nil
    end

    local wasInitialized = v2.initialized == true
    if not wasInitialized then
        v2.schemaVersion = V2_SCHEMA_VERSION
        v2.initialized = true
        v2.migratedAt = GetTimeStamp()
        v2.migrationSource = "legacy-flat-settings"
        v2.migrationComplete = false
    end

    local moduleEnabled = EnsureTable(v2, "moduleEnabled")
    if moduleEnabled then
        if moduleEnabled.bar == nil then moduleEnabled.bar = true end
        if moduleEnabled.sounds == nil then moduleEnabled.sounds = true end
        if moduleEnabled.currency == nil then moduleEnabled.currency = true end
        if moduleEnabled.warband == nil then moduleEnabled.warband = true end
        if moduleEnabled.achievement == nil then moduleEnabled.achievement = true end
        if moduleEnabled.hunt == nil then moduleEnabled.hunt = true end
    end

    local sharedTheme = EnsureTable(v2, "sharedTheme")
    if sharedTheme then
        if type(sharedTheme.fontKey) ~= "string" or sharedTheme.fontKey == "" then
            sharedTheme.fontKey = settings.titleFontKey or settings.percentFontKey or "frizqt"
        end
        if type(sharedTheme.scale) ~= "number" then
            sharedTheme.scale = tonumber(settings.scale) or 1
        end
        local palette = EnsureTable(sharedTheme, "palette")
        if palette then
            if type(palette.titleColor) ~= "table" and type(settings.titleColor) == "table" then
                palette.titleColor = settings.titleColor
            end
            if type(palette.percentColor) ~= "table" and type(settings.percentColor) == "table" then
                palette.percentColor = settings.percentColor
            end
            if type(palette.borderColor) ~= "table" and type(settings.borderColor) == "table" then
                palette.borderColor = settings.borderColor
            end
        end
    end

    local difficultySymbols = EnsureTable(v2, "difficultySymbols")
    if difficultySymbols then
        EnsureTable(difficultySymbols, "auto")
        EnsureTable(difficultySymbols, "override")
        EnsureTable(difficultySymbols, "color")
    end

    if v2.migrationComplete == nil then
        v2.migrationComplete = true
    end

    return v2
end

local function ResolvePath(settings, path, createMissing)
    if type(settings) ~= "table" or type(path) ~= "string" or path == "" then
        return nil, nil
    end

    local dot = string.find(path, ".", 1, true)
    if not dot then
        return settings, path
    end

    local cursor = settings
    local startIndex = 1
    while true do
        local nextDot = string.find(path, ".", startIndex, true)
        if not nextDot then
            local leaf = string.sub(path, startIndex)
            if leaf == "" then
                return nil, nil
            end
            return cursor, leaf
        end

        local segment = string.sub(path, startIndex, nextDot - 1)
        if segment == "" then
            return nil, nil
        end

        local nextValue = cursor[segment]
        if type(nextValue) ~= "table" then
            if not createMissing then
                return nil, nil
            end
            nextValue = {}
            cursor[segment] = nextValue
        end

        cursor = nextValue
        startIndex = nextDot + 1
    end
end

function CustomizationStateV2:Get(path, fallback)
    local settings = ResolveSettingsTable()
    if type(settings) ~= "table" or type(path) ~= "string" or path == "" then
        return fallback
    end

    EnsureBootstrap(settings)
    local parent, key = ResolvePath(settings, path, false)
    if type(parent) ~= "table" or type(key) ~= "string" or key == "" then
        return fallback
    end

    local value = parent[key]
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

    EnsureBootstrap(settings)
    local parent, key = ResolvePath(settings, path, true)
    if type(parent) ~= "table" or type(key) ~= "string" or key == "" then
        return false
    end

    parent[key] = value
    for _, callback in ipairs(self.subscribers) do
        pcall(callback, path, value)
    end
    return true
end

function CustomizationStateV2:GetEffectiveSettings()
    local settings = ResolveSettingsTable() or {}
    EnsureBootstrap(settings)
    return settings
end

function CustomizationStateV2:GetMigrationState()
    local settings = ResolveSettingsTable()
    if type(settings) ~= "table" then
        return nil
    end

    local v2 = EnsureBootstrap(settings)
    if type(v2) ~= "table" then
        return nil
    end

    return {
        schemaVersion = v2.schemaVersion,
        initialized = v2.initialized == true,
        migrationComplete = v2.migrationComplete == true,
        migratedAt = v2.migratedAt,
        migrationSource = v2.migrationSource,
    }
end

function CustomizationStateV2:IsModuleEnabled(moduleKey)
    local settings = ResolveSettingsTable()
    if type(settings) ~= "table" or type(moduleKey) ~= "string" or moduleKey == "" then
        return true
    end

    local v2 = EnsureBootstrap(settings)
    local enabledTable = type(v2) == "table" and v2.moduleEnabled or nil
    if type(enabledTable) ~= "table" then
        return true
    end

    local value = enabledTable[moduleKey]
    if value == nil then
        return true
    end
    return value == true
end

function CustomizationStateV2:SubscribeSettingsChanged(callback)
    if type(callback) ~= "function" then
        return false
    end
    self.subscribers[#self.subscribers + 1] = callback
    return true
end
