---@diagnostic disable

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local PlaySoundFile = _G.PlaySoundFile
local StopSound = _G.StopSound
local GetTime = _G.GetTime
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type
local ipairs = _G.ipairs

local PreyAudioModule = {}
Preydator:RegisterModule("PreyAudio", PreyAudioModule)

local lastTestSoundHandle = nil

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

function PreyAudioModule:ResolveStageSoundPath(stage)
    local settings = GetSettings()
    stage = tonumber(stage)
    if not stage then
        return nil
    end

    if settings and type(settings.stageSounds) == "table" and type(settings.stageSounds[stage]) == "string" and settings.stageSounds[stage] ~= "" then
        return settings.stageSounds[stage]
    end

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

function PreyAudioModule:TryPlaySound(path, ignoreSoundToggle)
    if type(path) ~= "string" or path == "" then
        AddDebugLog("Audio", "TryPlaySound suppressed: invalid path", false)
        return false
    end

    local settings = GetSettings()
    if not ignoreSoundToggle and settings and settings.soundsEnabled == false then
        AddDebugLog("Audio", "TryPlaySound suppressed: sounds disabled", false)
        return false
    end

    local channel = (settings and settings.soundChannel) or "SFX"
    local pcallOk, willPlay = pcall(PlaySoundFile, path, channel)
    if not (pcallOk and willPlay) then
        AddDebugLog("Audio", "TryPlaySound failed: path=" .. tostring(path) .. " | channel=" .. tostring(channel), false)
        return false
    end

    local extraPlays = tonumber(settings and settings.soundEnhance) or 0
    for _ = 1, extraPlays do
        pcall(PlaySoundFile, path, channel)
    end

    return true
end

function PreyAudioModule:TryPlayStageSound(stage, ignoreSoundToggle)
    local state = GetState()
    if type(state) ~= "table" then
        AddDebugLog("Audio", "TryPlayStageSound suppressed: no state", false)
        return false
    end

    stage = tonumber(stage)
    if not stage then
        AddDebugLog("Audio", "TryPlayStageSound suppressed: invalid stage", false)
        return false
    end

    state.stageSoundPlayed = type(state.stageSoundPlayed) == "table" and state.stageSoundPlayed or {}
    if state.stageSoundPlayed[stage] then
        AddDebugLog("Audio", "TryPlayStageSound deduped: stage " .. tostring(stage) .. " already played", false)
        return false
    end

    local path = self:ResolveStageSoundPath(stage)
    if not path then
        AddDebugLog("Audio", "TryPlayStageSound suppressed: no path for stage " .. tostring(stage), false)
        return false
    end

    local didPlay = self:TryPlaySound(path, ignoreSoundToggle)
    if didPlay then
        state.stageSoundPlayed[stage] = true
        AddDebugLog("Audio", "TryPlayStageSound success: stage " .. tostring(stage) .. " | path=" .. tostring(path), false)
    else
        AddDebugLog("Audio", "TryPlayStageSound failed: stage " .. tostring(stage) .. " | path=" .. tostring(path), false)
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

function PreyAudioModule:TriggerAmbushAlert(message, source)
    local state = GetState()
    local settings = GetSettings()
    if type(state) ~= "table" then
        return
    end

    if tonumber(state.stage) and tonumber(state.stage) >= 4 then
        AddDebugLog("Ambush", "Suppressed at stage " .. tostring(state.stage) .. " from " .. tostring(source), false)
        return
    end

    local now = GetTime and GetTime() or 0
    if ((state.lastAmbushAlertAt or 0) + 45.0) > now then
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

    if (not settings or settings.soundsEnabled ~= false) and (not settings or settings.ambushSoundEnabled ~= false) then
        local ambushPath = ResolveAmbushAlertSoundPath()
        if ambushPath then
            local channel = (settings and settings.soundChannel) or "SFX"
            pcall(PlaySoundFile, ambushPath, channel)
        end
    end

    AddDebugLog("Ambush", "Detected from " .. tostring(source) .. ": " .. tostring(message), true)
    UpdateBarDisplay()
end

function PreyAudioModule:ResolveAmbushSoundPath()
    local settings = GetSettings()
    local path = settings and settings.ambushSoundPath
    if type(path) == "string" and path ~= "" then
        return path
    end
    local c = GetConstants()
    return c.KILL_SOUND_PATH
end

function PreyAudioModule:PlayTestSound(path)
    if type(path) ~= "string" or path == "" then
        return false
    end
    local settings = GetSettings()
    local channel = (settings and settings.soundChannel) or "SFX"
    -- Stop previous test sound to prevent overlap-induced false failures.
    if lastTestSoundHandle ~= nil then
        pcall(StopSound, lastTestSoundHandle)
        lastTestSoundHandle = nil
    end
    local ok, willPlay, handle = pcall(PlaySoundFile, path, channel)
    if ok and willPlay then
        lastTestSoundHandle = type(handle) == "number" and handle or nil
        return true
    end
    return false
end
