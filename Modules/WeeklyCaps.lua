---@diagnostic disable

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local WeeklyCapsModule = {}
Preydator:RegisterModule("WeeklyCaps", WeeklyCapsModule)

local C_DateAndTime = _G.C_DateAndTime
local date = _G.date
local math = _G.math
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type
local pairs = _G.pairs

local function EnsureCurrencyDB()
    _G.PreydatorDB = _G.PreydatorDB or {}
    _G.PreydatorDB.currency = _G.PreydatorDB.currency or {}
    local c = _G.PreydatorDB.currency
    c.snapshots = c.snapshots or {}
    c.warbandTotal = c.warbandTotal or {}
    c.preySnapshots = c.preySnapshots or {}
    c.preyWeeklyProgress = c.preyWeeklyProgress or {}

    c.accountFlags = c.accountFlags or {}
    if c.accountFlags.hardUnlocked == nil then c.accountFlags.hardUnlocked = false end
    if c.accountFlags.nightmareUnlocked == nil then c.accountFlags.nightmareUnlocked = false end

    if not c.accountFlags.hardUnlocked or not c.accountFlags.nightmareUnlocked then
        for _, snap in pairs(c.preySnapshots) do
            if type(snap) == "table" then
                local diff = tostring(snap.preyTargetDifficulty or "")
                if diff:find("Hard", 1, true) or diff:find("Nightmare", 1, true) then
                    c.accountFlags.hardUnlocked = true
                end
                if diff:find("Nightmare", 1, true) or snap.nightmareUnlocked == true then
                    c.accountFlags.nightmareUnlocked = true
                    c.accountFlags.hardUnlocked = true
                end
            end
        end
    end

    return c
end

local function IsWarbandEnabled()
    local customization = Preydator.GetModule and Preydator:GetModule("CustomizationStateV2")
    if not customization or type(customization.IsModuleEnabled) ~= "function" then
        return true
    end
    return customization:IsModuleEnabled("warband")
end

local function GetPreyDataModule()
    return Preydator.GetModule and Preydator:GetModule("PreyData")
end

function WeeklyCapsModule:GetWeeklyResetKey()
    return "week-" .. date("%Y-%U")
end

function WeeklyCapsModule:NormalizeDifficultyKey(diff)
    local text = tostring(diff or "")
    if text:find("Nightmare", 1, true) then
        return "nightmare"
    end
    if text:find("Hard", 1, true) then
        return "hard"
    end
    return "normal"
end

function WeeklyCapsModule:GetOrCreateWeeklyCompleted(charKey, weekKey)
    local c = EnsureCurrencyDB()
    local key = type(weekKey) == "string" and weekKey or self:GetWeeklyResetKey()

    local weeks = c.preyWeeklyProgress[charKey]
    if type(weeks) ~= "table" then
        weeks = {}
        c.preyWeeklyProgress[charKey] = weeks
    end

    local entry = weeks[key]
    if type(entry) ~= "table" then
        entry = { normal = 0, hard = 0, nightmare = 0 }
        weeks[key] = entry
    end

    entry.normal = math.max(0, tonumber(entry.normal) or 0)
    entry.hard = math.max(0, tonumber(entry.hard) or 0)
    entry.nightmare = math.max(0, tonumber(entry.nightmare) or 0)
    return entry
end

function WeeklyCapsModule:BumpWeeklyCompleted(charKey, diff)
    if type(charKey) ~= "string" or charKey == "" then
        return
    end
    local key = self:GetWeeklyResetKey()
    local entry = self:GetOrCreateWeeklyCompleted(charKey, key)
    local diffKey = self:NormalizeDifficultyKey(diff)
    entry[diffKey] = (tonumber(entry[diffKey]) or 0) + 1
end

function WeeklyCapsModule:ObserveDifficulty(diff)
    local c = EnsureCurrencyDB()
    local diffKey = self:NormalizeDifficultyKey(diff)
    if diffKey == "hard" or diffKey == "nightmare" then
        c.accountFlags.hardUnlocked = true
    end
    if diffKey == "nightmare" then
        c.accountFlags.nightmareUnlocked = true
    end
end

function WeeklyCapsModule:GetAccountFlags()
    local c = EnsureCurrencyDB()
    return c.accountFlags or {}
end

function WeeklyCapsModule:GetCapsForLevel(level)
    local c = EnsureCurrencyDB()
    local flags = c.accountFlags or {}
    local nLevel = tonumber(level) or 0
    return {
        normal = (nLevel >= 78) and 4 or 0,
        hard = (nLevel >= 90 and (flags.hardUnlocked == true or flags.nightmareUnlocked == true)) and 4 or 0,
        nightmare = (flags.nightmareUnlocked == true) and 4 or 0,
    }
end

function WeeklyCapsModule:ApplyCapsToSnapshots(preySnapshots, capturedAt)
    if type(preySnapshots) ~= "table" then
        return
    end

    local stamp = tonumber(capturedAt) or 0
    for _, snap in pairs(preySnapshots) do
        if type(snap) == "table" then
            local caps = self:GetCapsForLevel(snap.level)
            snap.preyAvailableCounts = {
                normal = caps.normal,
                hard = caps.hard,
                nightmare = caps.nightmare,
                capturedAt = stamp,
            }
            snap.preyAvailabilityKnown = true
        end
    end
end

function WeeklyCapsModule:ProcessReset(preySnapshots, capturedAt)
    if not IsWarbandEnabled() then
        return false
    end

    local c = EnsureCurrencyDB()
    if not C_DateAndTime
        or type(C_DateAndTime.GetServerTime) ~= "function"
        or type(C_DateAndTime.GetSecondsUntilWeeklyReset) ~= "function"
    then
        return false
    end

    local serverNow = C_DateAndTime.GetServerTime()
    local secondsUntilReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
    if type(serverNow) ~= "number" or type(secondsUntilReset) ~= "number" then
        return false
    end

    local nextResetEpoch = serverNow + secondsUntilReset
    local storedEpoch = tonumber(c.nextWeeklyResetEpoch)

    if not storedEpoch or storedEpoch == 0 or serverNow >= storedEpoch then
        -- Use PreyData:ApplyWeeklyResetToSnapshots if available for newer architecture.
        local preyData = GetPreyDataModule()
        if preyData and type(preyData.ApplyWeeklyResetToSnapshots) == "function" then
            local self_instance = self
            local capsFunc = function(snap)
                return self_instance:GetCapsForLevel(tonumber(snap and snap.level) or 0)
            end
            preyData:ApplyWeeklyResetToSnapshots(capsFunc, capturedAt)
        else
            -- Fallback to direct mutation if PreyData unavailable.
            self:ApplyCapsToSnapshots(preySnapshots, capturedAt)
        end
    end

    c.nextWeeklyResetEpoch = nextResetEpoch
    return true
end

function WeeklyCapsModule:GetDebugState()
    local c = EnsureCurrencyDB()
    local flags = c.accountFlags or {}
    return {
        nextWeeklyResetEpoch = tonumber(c.nextWeeklyResetEpoch) or 0,
        hardUnlocked = flags.hardUnlocked == true,
        nightmareUnlocked = flags.nightmareUnlocked == true,
    }
end
