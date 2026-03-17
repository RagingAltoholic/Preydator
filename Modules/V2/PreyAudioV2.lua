---@diagnostic disable

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local PreyAudioV2 = {}
Preydator:RegisterModule("PreyAudioV2", PreyAudioV2)

local PlaySoundFile = _G.PlaySoundFile
local GetTime = _G.GetTime
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type

local AMBUSH_CHAT_DEDUPE_SECONDS = 30

local function GetApi()
    return type(Preydator.API) == "table" and Preydator.API or nil
end

local function GetSettings()
    local api = GetApi()
    if api and type(api.GetSettings) == "function" then
        return api.GetSettings()
    end
    if type(Preydator.GetSettings) == "function" then
        return Preydator.GetSettings()
    end
    return nil
end

local function GetState()
    local api = GetApi()
    if api and type(api.GetState) == "function" then
        return api.GetState()
    end
    if type(Preydator.GetState) == "function" then
        return Preydator.GetState()
    end
    return nil
end

local function AddDebugLog(kind, message, forcePrint)
    local api = GetApi()
    if api and type(api.AddDebugLog) == "function" then
        api.AddDebugLog(kind, message, forcePrint)
    end
end

local function UpdateBarDisplay()
    local api = GetApi()
    if api and type(api.UpdateBarDisplay) == "function" then
        api.UpdateBarDisplay()
    end
end

local function GetConstants()
    return type(Preydator.Constants) == "table" and Preydator.Constants or {}
end

local function GetDefaultStageSoundPath(stage)
    local c = GetConstants()
    if stage == 1 then
        return c.ALERT_SOUND_PATH
    elseif stage == 2 then
        return c.AMBUSH_SOUND_PATH
    elseif stage == 3 then
        return c.TORMENT_SOUND_PATH
    elseif stage == 4 then
        return c.KILL_SOUND_PATH
    end
    return nil
end

function PreyAudioV2:ResolveStageSoundPath(stage)
    local settings = GetSettings()
    stage = tonumber(stage)
    if not stage then
        return nil
    end

    if settings and type(settings.stageSounds) == "table" and type(settings.stageSounds[stage]) == "string" and settings.stageSounds[stage] ~= "" then
        return settings.stageSounds[stage]
    end

    return GetDefaultStageSoundPath(stage)
end

function PreyAudioV2:TryPlaySound(path, ignoreSoundToggle)
    if type(path) ~= "string" or path == "" then
        return false
    end

    local settings = GetSettings()
    if not ignoreSoundToggle and settings and settings.soundsEnabled == false then
        return false
    end

    local channel = (settings and settings.soundChannel) or "SFX"
    local ok = PlaySoundFile(path, channel) and true or false
    if not ok then
        return false
    end

    local extraPlays = tonumber(settings and settings.soundEnhance) or 0
    for _ = 1, extraPlays do
        PlaySoundFile(path, channel)
    end

    return true
end

function PreyAudioV2:TryPlayStageSound(stage, ignoreSoundToggle)
    local state = GetState()
    if type(state) ~= "table" then
        return false
    end

    stage = tonumber(stage)
    if not stage then
        return false
    end

    state.stageSoundPlayed = type(state.stageSoundPlayed) == "table" and state.stageSoundPlayed or {}
    if state.stageSoundPlayed[stage] then
        return false
    end

    local path = self:ResolveStageSoundPath(stage)
    if not path then
        return false
    end

    local didPlay = self:TryPlaySound(path, ignoreSoundToggle)
    if didPlay then
        state.stageSoundPlayed[stage] = true
    end
    return didPlay == true
end

local function ResolveAmbushAlertSoundPath()
    local settings = GetSettings()
    local path = settings and settings.ambushSoundPath
    if type(path) == "string" and path ~= "" then
        return path
    end
    local c = GetConstants()
    return c.KILL_SOUND_PATH
end

function PreyAudioV2:TriggerAmbushAlert(message, source)
    local state = GetState()
    local settings = GetSettings()
    if type(state) ~= "table" then
        return
    end

    local now = GetTime and GetTime() or 0
    if ((state.lastAmbushAlertAt or 0) + AMBUSH_CHAT_DEDUPE_SECONDS) > now then
        AddDebugLog("Ambush", "Deduped from " .. tostring(source) .. ": " .. tostring(message), false)
        return
    end

    state.lastAmbushSystemMessage = message
    state.lastAmbushAlertAt = now
    state.nextAmbushScanAt = now + 120.0

    local c = GetConstants()
    local alertDuration = tonumber(c.AMBUSH_ALERT_DURATION_SECONDS) or 6
    if not settings or settings.ambushVisualEnabled ~= false then
        state.ambushAlertUntil = now + alertDuration
    end

    if not settings or settings.ambushSoundEnabled ~= false then
        local ambushPath = ResolveAmbushAlertSoundPath()
        if ambushPath then
            local channel = (settings and settings.soundChannel) or "SFX"
            PlaySoundFile(ambushPath, channel)
        end
    end

    AddDebugLog("Ambush", "Detected from " .. tostring(source) .. ": " .. tostring(message), true)
    UpdateBarDisplay()
end
