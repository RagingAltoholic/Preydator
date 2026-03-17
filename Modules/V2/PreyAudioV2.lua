---@diagnostic disable

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local PreyAudioV2 = {}
Preydator:RegisterModule("PreyAudioV2", PreyAudioV2)

function PreyAudioV2:ResolveStageSoundPath(stage)
    local legacy = Preydator and Preydator.GetModule and Preydator:GetModule("PreyAudio")
    if legacy and type(legacy.ResolveStageSoundPath) == "function" then
        return legacy:ResolveStageSoundPath(stage)
    end
    return nil
end

function PreyAudioV2:TryPlaySound(path, ignoreSoundToggle)
    local legacy = Preydator and Preydator.GetModule and Preydator:GetModule("PreyAudio")
    if legacy and type(legacy.TryPlaySound) == "function" then
        return legacy:TryPlaySound(path, ignoreSoundToggle) == true
    end
    return false
end

function PreyAudioV2:TryPlayStageSound(stage, ignoreSoundToggle)
    local legacy = Preydator and Preydator.GetModule and Preydator:GetModule("PreyAudio")
    if legacy and type(legacy.TryPlayStageSound) == "function" then
        return legacy:TryPlayStageSound(stage, ignoreSoundToggle) == true
    end
    return false
end

function PreyAudioV2:TriggerAmbushAlert(message, source)
    local legacy = Preydator and Preydator.GetModule and Preydator:GetModule("PreyAudio")
    if legacy and type(legacy.TriggerAmbushAlert) == "function" then
        legacy:TriggerAmbushAlert(message, source)
    end
end
