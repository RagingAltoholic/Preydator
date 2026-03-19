---@diagnostic disable

--[[
    Preydator: PreyData
    Centralizes read/write access to prey-related data consumed by runtime and UI.
    
    Ownership:
    - PreydatorDB.currency.preySnapshots (per-character hunt state snapshots)
    - PreydatorDB.currency.preyWeeklyProgress (weekly completion tracking by character/week)
    - Snapshot capture logic
    - Weekly progress update logic
    
    Does NOT own:
    - Account-wide unlock flags (WeeklyCaps responsibility)
    - Weekly reset detection (WeeklyCaps responsibility)
    - Cap derivation (WeeklyCaps responsibility)
]]

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local PreyDataModule = {}
Preydator:RegisterModule("PreyData", PreyDataModule)

local GetTime = _G.GetTime
local UnitClass = _G.UnitClass
local UnitLevel = _G.UnitLevel
local UnitName = _G.UnitName
local GetRealmName = _G.GetRealmName
local GetZoneText = _G.GetZoneText
local math = _G.math
local pairs = _G.pairs
local ipairs = _G.ipairs
local string = _G.string
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type
local table = _G.table

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local db -- Reference to PreydatorDB.currency (set by EnsureDB)

local function EnsureDB()
    _G.PreydatorDB = _G.PreydatorDB or {}
    _G.PreydatorDB.currency = _G.PreydatorDB.currency or {}
    local c = _G.PreydatorDB.currency
    c.preySnapshots = c.preySnapshots or {}
    c.preyWeeklyProgress = c.preyWeeklyProgress or {}
    db = c
    return db
end

local function CharacterKey()
    local name = UnitName and UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or "Unknown"
    return name .. "-" .. realm
end

local function GetCustomizationState()
    return Preydator and Preydator:GetModule("CustomizationStateV2")
end

--------------------------------------------------------------------------------
-- Write Operations
--------------------------------------------------------------------------------

-- Create or update a character's snapshot from current hunt state.
-- Reads from Preydator.GetState() and caller-provided availability data.
function PreyDataModule:CaptureSnapshot(charKey, state, availableCounts, availabilityKnown)
    if not self:IsEnabled() then
        return
    end

    if type(charKey) ~= "string" or type(state) ~= "table" then
        return
    end

    EnsureDB()

    local level = UnitLevel and (tonumber(UnitLevel("player")) or 0) or 0
    local zoneName = GetZoneText and (GetZoneText() or "") or ""
    local classFile = nil
    if UnitClass then
        local _, token = UnitClass("player")
        classFile = token
    end

    local weekKey = self:GetWeeklyResetKey()
    local weeklyCompleted = self:GetOrCreateWeeklyProgress(charKey, weekKey)

    -- Preserve existing availability if not known this capture
    local existingSnap = db.preySnapshots[charKey]
    local preservedAvailability = nil
    local preservedAvailabilityKnown = false
    if availabilityKnown ~= true and type(existingSnap) == "table" and existingSnap.preyAvailabilityKnown == true then
        preservedAvailability = existingSnap.preyAvailableCounts
        preservedAvailabilityKnown = true
    end

    -- If still no availability known but has weekly progress, infer it
    if availabilityKnown ~= true and preservedAvailabilityKnown ~= true then
        local hasWeeklyProgress = (tonumber(weeklyCompleted.normal) or 0) > 0
            or (tonumber(weeklyCompleted.hard) or 0) > 0
            or (tonumber(weeklyCompleted.nightmare) or 0) > 0
        if hasWeeklyProgress then
            availabilityKnown = true
        end
    end

    -- Merge availability from this capture or preserved from prior
    local finalAvailability = nil
    if availableCounts and type(availableCounts) == "table" then
        finalAvailability = {
            normal = math.max(0, tonumber(availableCounts.normal) or 0),
            hard = math.max(0, tonumber(availableCounts.hard) or 0),
            nightmare = math.max(0, tonumber(availableCounts.nightmare) or 0),
            capturedAt = math.max(0, tonumber(availableCounts.capturedAt) or GetTime() or 0),
        }
    elseif preservedAvailability and type(preservedAvailability) == "table" then
        finalAvailability = {
            normal = math.max(0, tonumber(preservedAvailability.normal) or 0),
            hard = math.max(0, tonumber(preservedAvailability.hard) or 0),
            nightmare = math.max(0, tonumber(preservedAvailability.nightmare) or 0),
            capturedAt = math.max(0, tonumber(preservedAvailability.capturedAt) or GetTime() or 0),
        }
    end

    -- Build rank label
    local rankLabel = "No active prey"
    if type(state.preyTargetDifficulty) == "string" and state.preyTargetDifficulty ~= "" then
        rankLabel = state.preyTargetDifficulty
    elseif tonumber(state.stage) and tonumber(state.stage) > 0 then
        rankLabel = string.format("Stage %d", tonumber(state.stage))
    end

    -- Store snapshot
    db.preySnapshots[charKey] = {
        stage = tonumber(state.stage) or 0,
        level = level,
        zoneName = zoneName,
        activeQuestID = tonumber(state.activeQuestID) or 0,
        inPreyZone = state.inPreyZone == true,
        preyTargetName = state.preyTargetName,
        preyTargetDifficulty = state.preyTargetDifficulty,
        rankLabel = rankLabel,
        weeklyKey = weekKey,
        weeklyCompleted = {
            normal = tonumber(weeklyCompleted.normal) or 0,
            hard = tonumber(weeklyCompleted.hard) or 0,
            nightmare = tonumber(weeklyCompleted.nightmare) or 0,
        },
        preyAvailableCounts = finalAvailability,
        preyAvailabilityKnown = availabilityKnown == true,
        lastSeen = GetTime and GetTime() or 0,
        classFile = classFile,
    }
end

-- Increment weekly completion count for a specific difficulty.
-- Updates both preyWeeklyProgress and preySnapshots.weeklyCompleted.
function PreyDataModule:RecordWeeklyCompletion(charKey, weekKey, difficulty)
    if not self:IsEnabled() then
        return
    end

    if type(charKey) ~= "string" or type(weekKey) ~= "string" or type(difficulty) ~= "string" then
        return
    end

    EnsureDB()

    local diffKey = self:NormalizeDifficultyKey(difficulty)
    local completed = self:GetOrCreateWeeklyProgress(charKey, weekKey)
    completed[diffKey] = (tonumber(completed[diffKey]) or 0) + 1

    -- Also update snapshot's weeklyCompleted if snapshot exists
    local snap = db.preySnapshots[charKey]
    if type(snap) == "table" and type(snap.weeklyCompleted) == "table" then
        snap.weeklyCompleted[diffKey] = (tonumber(snap.weeklyCompleted[diffKey]) or 0) + 1
    end
end

-- Get or create weekly progress entry for a character/week.
-- Returns reference to preyWeeklyProgress[charKey][weekKey], creating if missing.
function PreyDataModule:GetOrCreateWeeklyProgress(charKey, weekKey)
    if type(charKey) ~= "string" or type(weekKey) ~= "string" then
        return { normal = 0, hard = 0, nightmare = 0 }
    end

    EnsureDB()

    local weeks = db.preyWeeklyProgress[charKey]
    if type(weeks) ~= "table" then
        weeks = {}
        db.preyWeeklyProgress[charKey] = weeks
    end

    local entry = weeks[weekKey]
    if type(entry) ~= "table" then
        entry = { normal = 0, hard = 0, nightmare = 0 }
        weeks[weekKey] = entry
    end

    -- Ensure all fields are present and valid
    entry.normal = math.max(0, tonumber(entry.normal) or 0)
    entry.hard = math.max(0, tonumber(entry.hard) or 0)
    entry.nightmare = math.max(0, tonumber(entry.nightmare) or 0)

    return entry
end

-- Directly set weekly progress for a character/week (atomic).
-- Called by WeeklyCaps on reset to zero out completion counts.
function PreyDataModule:SetWeeklyProgress(charKey, weekKey, progressTable)
    if type(charKey) ~= "string" or type(weekKey) ~= "string" or type(progressTable) ~= "table" then
        return
    end

    EnsureDB()

    local completed = self:GetOrCreateWeeklyProgress(charKey, weekKey)
    completed.normal = math.max(0, tonumber(progressTable.normal) or 0)
    completed.hard = math.max(0, tonumber(progressTable.hard) or 0)
    completed.nightmare = math.max(0, tonumber(progressTable.nightmare) or 0)

    -- Also update snapshot's weeklyCompleted if snapshot exists
    local snap = db.preySnapshots[charKey]
    if type(snap) == "table" and type(snap.weeklyCompleted) == "table" then
        snap.weeklyCompleted = {
            normal = completed.normal,
            hard = completed.hard,
            nightmare = completed.nightmare,
        }
    end
end

-- Update only the availability counts in a snapshot.
-- Called by WeeklyCaps to distribute weekly caps.
function PreyDataModule:SetPreyAvailability(charKey, availableCounts, capturedAt)
    if type(charKey) ~= "string" or type(availableCounts) ~= "table" then
        return
    end

    EnsureDB()

    local snap = db.preySnapshots[charKey]
    if type(snap) ~= "table" then
        return
    end

    snap.preyAvailableCounts = {
        normal = math.max(0, tonumber(availableCounts.normal) or 0),
        hard = math.max(0, tonumber(availableCounts.hard) or 0),
        nightmare = math.max(0, tonumber(availableCounts.nightmare) or 0),
        capturedAt = math.max(0, tonumber(capturedAt) or GetTime() or 0),
    }
end

--------------------------------------------------------------------------------
-- Read Operations
--------------------------------------------------------------------------------

-- Get a single character's snapshot.
function PreyDataModule:GetSnapshot(charKey)
    if type(charKey) ~= "string" then
        return nil
    end

    EnsureDB()
    return db.preySnapshots[charKey] or nil
end

-- Get all snapshots in display order (current character first, then by key).
function PreyDataModule:GetAllSnapshots()
    EnsureDB()

    local rows = {}
    for charKey, snap in pairs(db.preySnapshots) do
        rows[#rows + 1] = { charKey = charKey, snap = snap }
    end

    local currentKey = CharacterKey()
    table.sort(rows, function(a, b)
        local aIsCurrent = a.charKey == currentKey
        local bIsCurrent = b.charKey == currentKey
        if aIsCurrent ~= bIsCurrent then
            return aIsCurrent
        end
        return a.charKey < b.charKey
    end)

    return rows
end

-- Get weekly progress for a specific character/week (read-only).
-- Returns {normal=#, hard=#, nightmare=#} or zeros if missing.
function PreyDataModule:GetWeeklyProgress(charKey, weekKey)
    if type(charKey) ~= "string" or type(weekKey) ~= "string" then
        return { normal = 0, hard = 0, nightmare = 0 }
    end

    EnsureDB()

    local weeks = db.preyWeeklyProgress[charKey]
    if type(weeks) ~= "table" then
        return { normal = 0, hard = 0, nightmare = 0 }
    end

    local entry = weeks[weekKey]
    if type(entry) ~= "table" then
        return { normal = 0, hard = 0, nightmare = 0 }
    end

    return {
        normal = math.max(0, tonumber(entry.normal) or 0),
        hard = math.max(0, tonumber(entry.hard) or 0),
        nightmare = math.max(0, tonumber(entry.nightmare) or 0),
    }
end

-- Get snapshot's weekly completion counts (convenience).
function PreyDataModule:GetWeeklyCompletedFromSnapshot(charKey)
    local snap = self:GetSnapshot(charKey)
    if type(snap) == "table" and type(snap.weeklyCompleted) == "table" then
        return {
            normal = math.max(0, tonumber(snap.weeklyCompleted.normal) or 0),
            hard = math.max(0, tonumber(snap.weeklyCompleted.hard) or 0),
            nightmare = math.max(0, tonumber(snap.weeklyCompleted.nightmare) or 0),
        }
    end
    return { normal = 0, hard = 0, nightmare = 0 }
end

-- Get snapshot's availability counts.
function PreyDataModule:GetPreyAvailability(charKey)
    local snap = self:GetSnapshot(charKey)
    if type(snap) == "table" and type(snap.preyAvailableCounts) == "table" then
        return snap.preyAvailableCounts
    end
    return nil
end

--------------------------------------------------------------------------------
-- Bulk Operations
--------------------------------------------------------------------------------

-- Apply weekly cap derivation across all snapshots.
-- Called by WeeklyCaps:ProcessReset() to distribute fresh availability.
-- capsFunc should take (snapshot) and return {normal=N, hard=H, nightmare=NI}.
function PreyDataModule:ApplyWeeklyResetToSnapshots(capsFunc, capturedAt)
    if type(capsFunc) ~= "function" then
        return
    end

    EnsureDB()

    for charKey, snap in pairs(db.preySnapshots) do
        if type(snap) == "table" then
            local caps = capsFunc(snap)
            if type(caps) == "table" then
                self:SetPreyAvailability(charKey, caps, capturedAt)
            end
        end
    end
end

-- Read weekly progress in bulk (optimization for epoch/reset detection).
-- Returns table of all completed counts indexed by charKey.
function PreyDataModule:GetAllWeeklyCompletedByKey(weekKey)
    if type(weekKey) ~= "string" then
        return {}
    end

    EnsureDB()

    local result = {}
    for charKey, weeks in pairs(db.preyWeeklyProgress) do
        if type(weeks) == "table" and type(weeks[weekKey]) == "table" then
            result[charKey] = {
                normal = math.max(0, tonumber(weeks[weekKey].normal) or 0),
                hard = math.max(0, tonumber(weeks[weekKey].hard) or 0),
                nightmare = math.max(0, tonumber(weeks[weekKey].nightmare) or 0),
            }
        end
    end
    return result
end

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

-- Normalize difficulty string to key.
function PreyDataModule:NormalizeDifficultyKey(difficulty)
    local text = tostring(difficulty or "")
    if text:find("Nightmare", 1, true) then
        return "nightmare"
    end
    if text:find("Hard", 1, true) then
        return "hard"
    end
    return "normal"
end

-- Get the current weekly reset key (stable format).
function PreyDataModule:GetWeeklyResetKey()
    return "week-" .. _G.date("%Y-%U")
end

--------------------------------------------------------------------------------
-- Module Lifecycle
--------------------------------------------------------------------------------

-- Check if PreyData is enabled (gated by warband module).
function PreyDataModule:IsEnabled()
    local customState = GetCustomizationState()
    if customState and type(customState.IsModuleEnabled) == "function" then
        return customState:IsModuleEnabled("warband") == true
    end
    return true -- Default enabled if CustomizationStateV2 unavailable
end

-- Called when warband module is disabled.
-- Data persists in SavedVariables; snapshot creation just stops.
function PreyDataModule:OnDisable()
    -- No-op; data remains intact in SavedVariables.
end

--------------------------------------------------------------------------------
-- Debug
--------------------------------------------------------------------------------

-- Expose internal state for /pd inspect.
function PreyDataModule:GetDebugState()
    EnsureDB()

    local snapshotCount = 0
    for _ in pairs(db.preySnapshots) do
        snapshotCount = snapshotCount + 1
    end

    local weekKeys = {}
    for charKey, weeks in pairs(db.preyWeeklyProgress) do
        for weekKey in pairs(weeks) do
            if not weekKeys[weekKey] then
                weekKeys[weekKey] = true
            end
        end
    end

    local weekKeyList = {}
    for weekKey in pairs(weekKeys) do
        weekKeyList[#weekKeyList + 1] = weekKey
    end
    table.sort(weekKeyList)

    local lastCapturedAt = 0
    for _, snap in pairs(db.preySnapshots) do
        if type(snap) == "table" and tonumber(snap.lastSeen) then
            lastCapturedAt = math.max(lastCapturedAt, tonumber(snap.lastSeen))
        end
    end

    return {
        snapshotCount = snapshotCount,
        weekProgressKeys = weekKeyList,
        lastCapturedAt = lastCapturedAt,
    }
end
