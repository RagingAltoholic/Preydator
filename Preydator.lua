---@diagnostic disable

local ADDON_NAME = ...

local CreateFrame = _G.CreateFrame
local PlaySoundFile = _G.PlaySoundFile
local C_Timer = _G.C_Timer
local ColorPickerFrame = _G.ColorPickerFrame
local OpacitySliderFrame = _G.OpacitySliderFrame
local Enum = _G.Enum
local C_QuestLog = _G["C_QuestLog"]
local C_UIWidgetManager = _G["C_UIWidgetManager"]
local C_TaskQuest = _G["C_TaskQuest"]
local C_Map = _G["C_Map"]
local GetQuestProgressBarPercent = _G.GetQuestProgressBarPercent
local UIParent = _G.UIParent
local GetTime = _G.GetTime
local GetZoneText = _G.GetZoneText
local SlashCmdList = _G["SlashCmdList"]
local Settings = _G["Settings"]
local collectgarbage = _G.collectgarbage
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo
local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth
local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton

_G.SLASH_PREYDATOR1 = "/preydator"
_G.SLASH_PREYDATOR2 = "/pd"

local PREY_WIDGET_TYPE = 31
local PREY_PROGRESS_FINAL = 3
local WIDGET_SHOWN = 1
-- local IDLE_SOUND_PATH = "Interface\\AddOns\\Preydator\\sounds\\predator-idle.ogg"
local ALERT_SOUND_PATH = "Interface\\AddOns\\Preydator\\sounds\\predator-alert.ogg"
local AMBUSH_SOUND_PATH = "Interface\\AddOns\\Preydator\\sounds\\predator-ambush.ogg"
local TORMENT_SOUND_PATH = "Interface\\AddOns\\Preydator\\sounds\\predator-torment.ogg"
local KILL_SOUND_PATH = "Interface\\AddOns\\Preydator\\sounds\\predator-kill.ogg"
local DEBUG_LOG_LIMIT = 200
local DEFAULT_OUT_OF_ZONE_LABEL = "No Sign in These Fields"
local BAR_TICK_PCTS = { 0, 25, 50, 75 }
local PERCENT_DISPLAY_INSIDE = "inside"
local PERCENT_DISPLAY_BELOW_BAR = "below_bar"
local PERCENT_DISPLAY_UNDER_TICKS = "under_ticks"
local PERCENT_DISPLAY_OFF = "off"
local PERCENT_FALLBACK_STRICT = "strict"
local PERCENT_FALLBACK_STAGE = "stage"
local DEFAULT_STAGE_LABELS = {
    [1] = "Mark of the Hunt",
    [2] = "Scent in the Wind",
    [3] = "Blood in the Shadows",
    [4] = "Echoes of the Kill",
    [5] = "Feast of the Fang",
}
local STAGE_PCT = {
    [1] = 0,
    [2] = 25,
    [3] = 50,
    [4] = 75,
    [5] = 100,
}

local TEXTURE_PRESETS = {
    default = "Interface\\TARGETINGFRAME\\UI-StatusBar",
    flat = "Interface\\Buttons\\WHITE8x8",
    raid = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    classic = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
    nameplate = "Interface\\AddOns\\Blizzard_NamePlates\\UI-NamePlate-Fill",
}

local FONT_PRESETS = {
    frizqt = "Fonts\\FRIZQT__.TTF",
    arialn = "Fonts\\ARIALN.TTF",
    skurri = "Fonts\\SKURRI.TTF",
    morpheus = "Fonts\\MORPHEUS.TTF",
}

local DEFAULTS = {
    point = { anchor = "center", x = 0, y = -220 },
    width = 260,
    height = 18,
    scale = 1,
    fontSize = 12,
    locked = true,
    forceShowBar = false,
    showWhenNoPrey = true,
    fillColor = { 0.85, 0.2, 0.2, 0.95 },
    bgColor = { 0, 0, 0, 0.6 },
    titleColor = { 1, 0.82, 0, 1 },
    percentColor = { 1, 1, 1, 1 },
    textureKey = "default",
    titleFontKey = "frizqt",
    percentFontKey = "frizqt",
    outOfZoneLabel = DEFAULT_OUT_OF_ZONE_LABEL,
    stageLabels = {
        [1] = DEFAULT_STAGE_LABELS[1],
        [2] = DEFAULT_STAGE_LABELS[2],
        [3] = DEFAULT_STAGE_LABELS[3],
        [4] = DEFAULT_STAGE_LABELS[4],
        [5] = DEFAULT_STAGE_LABELS[5],
    },
    stageSounds = {
        [1] = nil, -- IDLE_SOUND_PATH,
        [2] = ALERT_SOUND_PATH,
        [3] = AMBUSH_SOUND_PATH,
        [4] = TORMENT_SOUND_PATH,
        [5] = KILL_SOUND_PATH,
    },
    soundsEnabled = true,
    soundChannel = "SFX",
    soundEnhance = 0,
    debugSounds = true,
    showTicks = true,
    percentDisplay = PERCENT_DISPLAY_INSIDE,
    percentFallbackMode = PERCENT_FALLBACK_STRICT,
}

local settings
local debugDB

local frame = CreateFrame("Frame")
local warnedMissingSound = false
local barFrame
local barFillContainer
local barFill
local barText
local stageText
local barTickMarks = {}
local barTickLabels = {}
local optionsPanel
local candidateWidgetSetIDs = {}
local ExtractWidgetQuestID
local state = {
    activeQuestID = nil,
    progressState = nil,
    progressPercent = nil,
    stageSoundPlayed = {},
    forceShowBar = false,
    killStageUntil = 0,
    stage = 1,
    preyZoneName = nil,
    preyZoneMapID = nil,
    inPreyZone = nil,
    preyTooltipText = nil,
    elapsedSinceUpdate = 0,
    lastWidgetSeenAt = 0,
    lastStateDebugSnapshot = nil,
    lastDisplayPct = 0,
    lastDisplayReason = "init",
    lastPercentSource = "none",
}

local UPDATE_INTERVAL_SECONDS = 0.5
local INSPECT_VERSION = "v3"

local function ApplyDefaults(dst, src)
    for key, value in pairs(src) do
        if type(value) == "table" then
            if type(dst[key]) ~= "table" then
                dst[key] = {}
            end
            ApplyDefaults(dst[key], value)
        elseif dst[key] == nil then
            dst[key] = value
        end
    end
end

local function GetStageLabel(stage)
    if settings and settings.stageLabels and settings.stageLabels[stage] then
        return settings.stageLabels[stage]
    end

    return DEFAULT_STAGE_LABELS[stage] or "Unknown"
end

local function Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function NormalizeLabelSettings()
    if type(settings.stageLabels) ~= "table" then
        settings.stageLabels = {}
    end

    for stage = 1, 5 do
        local label = settings.stageLabels[stage]
        if type(label) ~= "string" or label == "" then
            local legacy = settings.stageLabels[tostring(stage)]
            if type(legacy) == "string" and legacy ~= "" then
                label = legacy
            end
        end

        if type(label) ~= "string" or label == "" then
            label = DEFAULT_STAGE_LABELS[stage]
        end

        settings.stageLabels[stage] = label
    end

    if type(settings.outOfZoneLabel) ~= "string" or settings.outOfZoneLabel == "" then
        settings.outOfZoneLabel = DEFAULT_OUT_OF_ZONE_LABEL
    end
end

local function NormalizeColorSettings()
    local function normalizeColor(source, fallback)
        local color = type(source) == "table" and source or {}
        local r = Clamp(tonumber(color[1] or color.r) or fallback[1], 0, 1)
        local g = Clamp(tonumber(color[2] or color.g) or fallback[2], 0, 1)
        local b = Clamp(tonumber(color[3] or color.b) or fallback[3], 0, 1)
        local a = Clamp(tonumber(color[4] or color.a) or fallback[4], 0, 1)
        return { r, g, b, a }
    end

    settings.fillColor = normalizeColor(settings.fillColor, DEFAULTS.fillColor)
    settings.bgColor = normalizeColor(settings.bgColor, DEFAULTS.bgColor)
    settings.titleColor = normalizeColor(settings.titleColor, DEFAULTS.titleColor)
    settings.percentColor = normalizeColor(settings.percentColor, DEFAULTS.percentColor)
end

local function NormalizeDisplaySettings()
    settings.showTicks = settings.showTicks ~= false

    local mode = settings.percentDisplay
    if mode == "below" then
        mode = PERCENT_DISPLAY_BELOW_BAR
    end

    if mode ~= PERCENT_DISPLAY_INSIDE and mode ~= PERCENT_DISPLAY_BELOW_BAR and mode ~= PERCENT_DISPLAY_UNDER_TICKS and mode ~= PERCENT_DISPLAY_OFF then
        settings.percentDisplay = PERCENT_DISPLAY_INSIDE
        return
    end

    settings.percentDisplay = mode

    local fallbackMode = settings.percentFallbackMode
    if fallbackMode ~= PERCENT_FALLBACK_STRICT and fallbackMode ~= PERCENT_FALLBACK_STAGE then
        settings.percentFallbackMode = PERCENT_FALLBACK_STRICT
    end
end

local function GetPreyZoneInfo(questID)
    if not questID then
        return nil, nil
    end

    if not (C_TaskQuest and C_TaskQuest.GetQuestZoneID and C_Map and C_Map.GetMapInfo) then
        return nil, nil
    end

    local mapID = C_TaskQuest.GetQuestZoneID(questID)
    if not mapID then
        return nil, nil
    end

    local mapInfo = C_Map.GetMapInfo(mapID)
    return (mapInfo and mapInfo.name or nil), mapID
end

local function IsPlayerInPreyZone(preyMapID)
    if not preyMapID then
        return nil
    end

    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then
        return nil
    end

    local playerMapID = C_Map.GetBestMapForUnit("player")
    if not playerMapID then
        return nil
    end

    if playerMapID == preyMapID then
        return true
    end

    local guard = 0
    local currentMapID = playerMapID
    while currentMapID and guard < 20 do
        local mapInfo = C_Map.GetMapInfo(currentMapID)
        if not mapInfo then
            break
        end

        if mapInfo.parentMapID == preyMapID then
            return true
        end

        currentMapID = mapInfo.parentMapID
        guard = guard + 1
    end

    return false
end

local function GetDefaultStageSoundPath(stage)
    if stage == 2 then
        return ALERT_SOUND_PATH
    end
    if stage == 3 then
        return AMBUSH_SOUND_PATH
    end
    if stage == 4 then
        return TORMENT_SOUND_PATH
    end
    if stage == 5 then
        return KILL_SOUND_PATH
    end

    return nil
end

local function GetWidgetTypePreyHuntProgress()
    if Enum and Enum.UIWidgetVisualizationType and Enum.UIWidgetVisualizationType.PreyHuntProgress then
        return Enum.UIWidgetVisualizationType.PreyHuntProgress
    end

    return PREY_WIDGET_TYPE
end

local function GetShownStateShown()
    if Enum and Enum.WidgetShownState and Enum.WidgetShownState.Shown then
        return Enum.WidgetShownState.Shown
    end

    return WIDGET_SHOWN
end

local function GetCurrentActivePreyQuest()
    if C_QuestLog and C_QuestLog.GetActivePreyQuest then
        return C_QuestLog.GetActivePreyQuest()
    end

    return nil
end

local function IsQuestStillActive(questID)
    if not questID or questID < 1 then
        return false
    end

    if C_QuestLog and C_QuestLog.IsOnQuest then
        return C_QuestLog.IsOnQuest(questID) and true or false
    end

    return true
end

local function IsValidQuestID(questID)
    return type(questID) == "number" and questID > 0
end

local function EnsureDebugDB()
    _G.PreydatorDebugDB = _G.PreydatorDebugDB or {}
    debugDB = _G.PreydatorDebugDB
    if type(debugDB.entries) ~= "table" then
        debugDB.entries = {}
    end
    if debugDB.enabled == nil then
        debugDB.enabled = true
    end
end

local function AddDebugLog(kind, message, forcePrint)
    if not debugDB then
        return
    end

    if not debugDB.enabled then
        return
    end

    local now = GetTime and GetTime() or 0
    local entry = string.format("%0.3f | %s | %s", now, tostring(kind or "?"), tostring(message or ""))
    table.insert(debugDB.entries, entry)

    while #debugDB.entries > DEBUG_LOG_LIMIT do
        table.remove(debugDB.entries, 1)
    end

    if forcePrint then
        print("Preydator DEBUG: " .. entry)
    end
end

local function TryPlaySound(path, ignoreSoundToggle)
    if not ignoreSoundToggle and settings and settings.soundsEnabled == false then
        AddDebugLog("TryPlaySound", "blocked by soundsEnabled=false | path=" .. tostring(path), false)
        return false
    end

    local channel = (settings and settings.soundChannel) or "SFX"
    local willPlay = PlaySoundFile(path, channel)
    AddDebugLog("TryPlaySound", "path=" .. tostring(path) .. " | channel=" .. tostring(channel) .. " | ignoreToggle=" .. tostring(ignoreSoundToggle) .. " | result=" .. tostring(willPlay), false)
    if willPlay then
        local enhance = (settings and tonumber(settings.soundEnhance)) or 0
        if enhance > 0 and C_Timer and C_Timer.After then
            local extraPlays = math.min(4, math.max(0, math.floor(enhance / 25)))
            for i = 1, extraPlays do
                local delay = i * 0.03
                C_Timer.After(delay, function()
                    PlaySoundFile(path, channel)
                end)
            end
            if extraPlays > 0 then
                AddDebugLog("TryPlaySound", "enhance=" .. tostring(enhance) .. " | extraPlays=" .. tostring(extraPlays), false)
            end
        end
        return true
    end

    if not warnedMissingSound then
        warnedMissingSound = true
        print("Preydator: Could not play custom sound. Check sounds/predator-alert.ogg, predator-ambush.ogg, predator-torment.ogg, predator-kill.ogg, then /reload.")
    end

    return false
end

local function ResolveStageSoundPath(stage)
    stage = tonumber(stage)
    if not stage then
        AddDebugLog("ResolveStageSoundPath", "invalid stage", false)
        return nil
    end

    local defaultPath = GetDefaultStageSoundPath(stage)

    if not settings then
        return defaultPath
    end

    settings.stageSounds = settings.stageSounds or {}
    local sounds = settings.stageSounds

    local savedPath = sounds[stage]
    if type(savedPath) == "string" and savedPath ~= "" then
        AddDebugLog("ResolveStageSoundPath", "stage=" .. stage .. " | source=saved | path=" .. savedPath, false)
        return savedPath
    end

    if defaultPath and defaultPath ~= "" then
        sounds[stage] = defaultPath
        AddDebugLog("ResolveStageSoundPath", "stage=" .. stage .. " | source=default | path=" .. defaultPath, false)
        return defaultPath
    end

    AddDebugLog("ResolveStageSoundPath", "stage=" .. stage .. " | source=none | default=nil", true)

    return nil
end

local function TryPlayStageSound(stage, ignoreSoundToggle)
    local path = ResolveStageSoundPath(stage)
    if not path then
        AddDebugLog("TryPlayStageSound", "stage=" .. tostring(stage) .. " | no resolved path", true)
        return false
    end

    if state.stageSoundPlayed[stage] then
        AddDebugLog("TryPlayStageSound", "stage=" .. tostring(stage) .. " | skipped already played", false)
        return false
    end

    if TryPlaySound(path, ignoreSoundToggle) then
        state.stageSoundPlayed[stage] = true
        AddDebugLog("TryPlayStageSound", "stage=" .. tostring(stage) .. " | success", false)
        return true
    end

    if stage == 5 then
        local fallbackPath = ResolveStageSoundPath(4)
        if fallbackPath then
            AddDebugLog("TryPlayStageSound", "stage=5 | primary failed, trying fallback stage=4 | path=" .. tostring(fallbackPath), true)
            if TryPlaySound(fallbackPath, ignoreSoundToggle) then
                state.stageSoundPlayed[stage] = true
                AddDebugLog("TryPlayStageSound", "stage=5 | fallback stage=4 success", true)
                return true
            end
            AddDebugLog("TryPlayStageSound", "stage=5 | fallback stage=4 also failed", true)
        end
    end

    local channel = (settings and settings.soundChannel) or "SFX"
    AddDebugLog("TryPlayStageSound", "stage=" .. tostring(stage) .. " | path=" .. tostring(path) .. " | channel=" .. tostring(channel) .. " | PlaySoundFile returned false", true)

    return false
end

local function ApplyBarSettings()
    if not barFrame then
        return
    end

    local point = settings.point
    barFrame:ClearAllPoints()
    barFrame:SetPoint(point.anchor, UIParent, point.anchor, point.x, point.y)
    barFrame:SetSize(settings.width, settings.height)
    barFrame:SetScale(settings.scale)

    if barFill then
        local fill = settings.fillColor
        barFill:ClearAllPoints()
        barFill:SetPoint("left", barFrame, "left", 0, 0)
        barFill:SetSize(0, settings.height)
        barFill:SetTexture(TEXTURE_PRESETS[settings.textureKey] or TEXTURE_PRESETS.default)
        barFill:SetVertexColor(fill[1], fill[2], fill[3], fill[4])
        barFill:SetDrawLayer("ARTWORK", 0)
    end

    if barFrame.BackgroundTexture then
        local bg = settings.bgColor
        barFrame.BackgroundTexture:SetColorTexture(bg[1], bg[2], bg[3], bg[4])
    end

    if stageText then
        local _, _, flags = stageText:GetFont()
        local titleFont = FONT_PRESETS[settings.titleFontKey] or FONT_PRESETS.frizqt
        stageText:SetFont(titleFont, settings.fontSize, flags)
        local titleColor = settings.titleColor or DEFAULTS.titleColor
        stageText:SetTextColor(titleColor[1], titleColor[2], titleColor[3], titleColor[4] or 1)
    end

    if barText then
        local _, _, flags = barText:GetFont()
        local percentFont = FONT_PRESETS[settings.percentFontKey] or FONT_PRESETS.frizqt
        barText:SetFont(percentFont, math.max(8, settings.fontSize - 1), flags)
        local percentColor = settings.percentColor or DEFAULTS.percentColor
        barText:SetTextColor(percentColor[1], percentColor[2], percentColor[3], percentColor[4] or 1)
        barText:SetDrawLayer("OVERLAY", 7)
    end

    for index, tickLabel in ipairs(barTickLabels) do
        if tickLabel then
            local _, _, flags = tickLabel:GetFont()
            local percentFont = FONT_PRESETS[settings.percentFontKey] or FONT_PRESETS.frizqt
            tickLabel:SetFont(percentFont, math.max(7, settings.fontSize - 4), flags)
            local percentColor = settings.percentColor or DEFAULTS.percentColor
            tickLabel:SetTextColor(percentColor[1], percentColor[2], percentColor[3], 0.9)
        end

        local tickMark = barTickMarks[index]
        if tickMark then
            tickMark:SetColorTexture(1, 1, 1, 0.35)
            tickMark:SetDrawLayer("OVERLAY", 4)
            tickMark:SetShown(settings.showTicks)
        end
    end

    local barWidth = settings.width
    local barHeight = settings.height
    for index, pct in ipairs(BAR_TICK_PCTS) do
        local x = math.floor((barWidth * (pct / 100)) + 0.5)
        local tickMark = barTickMarks[index]
        if tickMark then
            tickMark:ClearAllPoints()
            if pct == 100 then
                tickMark:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", barWidth - 1, 0)
            else
                tickMark:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", x, 0)
            end
            tickMark:SetSize(1, barHeight)
        end

        local tickLabel = barTickLabels[index]
        if tickLabel then
            tickLabel:ClearAllPoints()
            if pct == 0 then
                tickLabel:SetPoint("TOPLEFT", barFrame, "BOTTOMLEFT", 0, -1)
            elseif pct == 100 then
                tickLabel:SetPoint("TOPRIGHT", barFrame, "BOTTOMRIGHT", 0, -1)
            else
                tickLabel:SetPoint("TOP", barFrame, "BOTTOMLEFT", x, -1)
            end
            tickLabel:SetText(tostring(pct))
            tickLabel:SetDrawLayer("OVERLAY", 8)
            tickLabel:SetShown(settings.showTicks and settings.percentDisplay == PERCENT_DISPLAY_UNDER_TICKS)
        end
    end

    if barText then
        if settings.percentDisplay == PERCENT_DISPLAY_OFF then
            barText:Hide()
        elseif settings.percentDisplay == PERCENT_DISPLAY_BELOW_BAR then
            barText:Show()
            barText:ClearAllPoints()
            barText:SetPoint("TOP", barFrame, "BOTTOM", 0, -14)
        elseif settings.percentDisplay == PERCENT_DISPLAY_UNDER_TICKS then
            barText:Hide()
        else
            barText:Show()
            barText:ClearAllPoints()
            barText:SetPoint("center", barFrame, "center", 0, 0)
        end
    end

    barFrame:SetMovable(true)
    barFrame:EnableMouse(not settings.locked)
end

local function EnsureBar()
    if barFrame then
        return
    end

    local createdBar = CreateFrame("Frame", "PreydatorProgressBar", UIParent)
    if not createdBar then
        return
    end

    createdBar:SetSize(260, 18)
    createdBar:SetPoint("center", UIParent, "center", 0, -220)
    createdBar:Hide()
    createdBar:SetClampedToScreen(true)
    barFrame = createdBar

    barFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and settings and not settings.locked then
            self:StartMoving()
        end
    end)

    barFrame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        local _, _, _, x, y = self:GetPoint(1)
        settings.point.anchor = "center"
        settings.point.x = math.floor(x + 0.5)
        settings.point.y = math.floor(y + 0.5)
    end)

    local bg = barFrame:CreateTexture(nil, "background")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    barFrame.BackgroundTexture = bg

    barFillContainer = CreateFrame("Frame", nil, barFrame)
    barFillContainer:SetAllPoints()
    barFillContainer:SetClipsChildren(true)

    barFill = barFillContainer:CreateTexture(nil, "artwork")
    barFill:SetPoint("left", barFillContainer, "left", 0, 0)
    barFill:SetSize(0, 18)
    barFill:SetTexCoord(0, 1, 0, 1)
    barFill:SetHorizTile(false)
    barFill:SetVertTile(false)
    barFill:SetColorTexture(0.85, 0.2, 0.2, 0.95)

    local border = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    border:SetBackdropBorderColor(0.8, 0.2, 0.2, 0.85)

    stageText = barFrame:CreateFontString(nil, "overlay", "GameFontNormal")
    stageText:SetPoint("BOTTOM", barFrame, "TOP", 0, 4)
    stageText:SetJustifyH("CENTER")
    stageText:SetText("Preydator")

    barText = barFrame:CreateFontString(nil, "overlay", "GameFontHighlightSmall")
    barText:SetPoint("center", barFrame, "center", 0, 0)
    barText:SetDrawLayer("OVERLAY", 9)
    barText:SetText("0%")

    for index, pct in ipairs(BAR_TICK_PCTS) do
        local tickMark = barFrame:CreateTexture(nil, "overlay")
        tickMark:SetColorTexture(1, 1, 1, 0.35)
        tickMark:SetDrawLayer("OVERLAY", 4)
        barTickMarks[index] = tickMark

        local tickLabel = barFrame:CreateFontString(nil, "overlay", "GameFontHighlightSmall")
        tickLabel:SetDrawLayer("OVERLAY", 8)
        tickLabel:SetText(tostring(pct))
        barTickLabels[index] = tickLabel
    end

    ApplyBarSettings()
end

local function GetStageFromState(progressState)
    if progressState == nil then
        return 1
    end

    if progressState == 0 then
        return 2
    end

    if progressState == 1 then
        return 3
    end

    if progressState == 2 then
        return 4
    end

    if progressState == PREY_PROGRESS_FINAL then
        return 5
    end

    return 1
end

local function ClampPercent(value)
    return Clamp(value, 0, 100)
end

local function NormalizePercentCandidate(value)
    if type(value) ~= "number" then
        return nil
    end

    if value >= 0 and value <= 1 then
        return ClampPercent(value * 100)
    end

    return ClampPercent(value)
end

local function ExtractProgressPercentFromInfoScan(info)
    if type(info) ~= "table" then
        return nil
    end

    for key, value in pairs(info) do
        if type(value) == "number" then
            local keyText = string.lower(tostring(key))
            if string.find(keyText, "percent", 1, true) then
                local pct = NormalizePercentCandidate(value)
                if pct ~= nil then
                    return pct
                end
            end
        end
    end

    local currentValues = {}
    local maxValues = {}
    for key, value in pairs(info) do
        if type(value) == "number" and value >= 0 then
            local keyText = string.lower(tostring(key))
            if string.find(keyText, "current", 1, true)
                or string.find(keyText, "value", 1, true)
                or string.find(keyText, "progress", 1, true)
                or string.find(keyText, "fulfilled", 1, true)
                or string.find(keyText, "completed", 1, true)
            then
                currentValues[#currentValues + 1] = value
            end

            if string.find(keyText, "max", 1, true)
                or string.find(keyText, "total", 1, true)
                or string.find(keyText, "required", 1, true)
            then
                maxValues[#maxValues + 1] = value
            end
        end
    end

    for _, current in ipairs(currentValues) do
        for _, maxValue in ipairs(maxValues) do
            if maxValue > 0 and current <= maxValue then
                local pct = ClampPercent((current / maxValue) * 100)
                if pct >= 0 and pct <= 100 then
                    return pct
                end
            end
        end
    end

    return nil
end

local function SummarizeInfoFields(info)
    if type(info) ~= "table" then
        return ""
    end

    local parts = {}
    local count = 0
    for key, value in pairs(info) do
        if key ~= "tooltip" and (type(value) == "number" or type(value) == "string" or type(value) == "boolean") then
            count = count + 1
            if count > 10 then
                parts[#parts + 1] = "..."
                break
            end
            parts[#parts + 1] = tostring(key) .. "=" .. tostring(value)
        end
    end

    return table.concat(parts, ", ")
end

local function ExtractProgressPercent(info, tooltipText)
    if type(info) == "table" then
        local directFields = {
            "progressPercentage",
            "progressPercent",
            "fillPercentage",
            "percentage",
            "percent",
            "progress",
            "progressValue",
        }

        for _, fieldName in ipairs(directFields) do
            local pct = NormalizePercentCandidate(info[fieldName])
            if pct ~= nil then
                return pct
            end
        end

        local valueFields = { "barValue", "value", "currentValue" }
        local maxFields = { "barMax", "maxValue", "totalValue", "total", "max" }
        for _, valueField in ipairs(valueFields) do
            local current = info[valueField]
            if type(current) == "number" then
                for _, maxField in ipairs(maxFields) do
                    local maxValue = info[maxField]
                    if type(maxValue) == "number" and maxValue > 0 then
                        return ClampPercent((current / maxValue) * 100)
                    end
                end
            end
        end
    end

    local scannedPct = ExtractProgressPercentFromInfoScan(info)
    if scannedPct ~= nil then
        return scannedPct
    end

    if type(tooltipText) == "string" then
        local pctText = tooltipText:match("(%d+)%s*%%")
        local pctValue = tonumber(pctText)
        if pctValue then
            return ClampPercent(pctValue)
        end
    end

    return nil
end

local function ExtractQuestObjectivePercent(questID)
    if not IsValidQuestID(questID) then
        return nil
    end

    local questBarPct = nil
    if GetQuestProgressBarPercent then
        local rawQuestBarPct = tonumber(GetQuestProgressBarPercent(questID))
        if rawQuestBarPct ~= nil then
            questBarPct = ClampPercent(rawQuestBarPct)
        end
    end

    if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then
        return nil
    end

    local objectives = C_QuestLog.GetQuestObjectives(questID)
    if type(objectives) ~= "table" or #objectives == 0 then
        return nil
    end

    local totalFulfilled = 0
    local totalRequired = 0
    local anyNumericObjective = false

    for _, objective in ipairs(objectives) do
        if type(objective) == "table" then
            local fulfilled = tonumber(objective.numFulfilled)
            local required = tonumber(objective.numRequired)

            if fulfilled == nil then
                fulfilled = tonumber(objective.fulfilled)
            end
            if required == nil then
                required = tonumber(objective.required)
            end

            if fulfilled ~= nil and required == nil and objective.finished ~= nil then
                required = 1
                fulfilled = objective.finished and 1 or math.max(0, fulfilled)
            end

            if fulfilled and required and required > 0 then
                anyNumericObjective = true
                totalFulfilled = totalFulfilled + math.max(0, fulfilled)
                totalRequired = totalRequired + math.max(0, required)
            else
                local text = objective.text
                if type(text) == "string" and text ~= "" then
                    local curText, maxText = text:match("(%d+)%s*/%s*(%d+)")
                    local curValue = tonumber(curText)
                    local maxValue = tonumber(maxText)
                    if curValue and maxValue and maxValue > 0 then
                        anyNumericObjective = true
                        totalFulfilled = totalFulfilled + math.max(0, curValue)
                        totalRequired = totalRequired + math.max(0, maxValue)
                    else
                        local pctText = text:match("(%d+)%s*%%")
                        local pctValue = tonumber(pctText)
                        if pctValue then
                            return ClampPercent(pctValue)
                        end
                    end
                end
            end
        end
    end

    local objectivePct = nil
    if anyNumericObjective and totalRequired > 0 then
        objectivePct = ClampPercent((totalFulfilled / totalRequired) * 100)
    end

    if objectivePct ~= nil and questBarPct ~= nil then
        return math.max(objectivePct, questBarPct)
    end

    if objectivePct ~= nil then
        return objectivePct
    end

    if questBarPct ~= nil then
        return questBarPct
    end

    return nil
end

local function UpdateBarDisplay()
    EnsureBar()

    local now = GetTime and GetTime() or 0
    local hasActiveQuest = state.activeQuestID ~= nil
    local forceKillStage = now < (state.killStageUntil or 0)
    local shouldShow = state.forceShowBar or hasActiveQuest or forceKillStage or settings.showWhenNoPrey

    if not shouldShow then
        barFrame:Hide()
        return
    end

    barFrame:Show()

    local stage = forceKillStage and 5 or GetStageFromState(state.progressState)
    local pct = 0
    local displayReason = "default"
    local isOutOfPreyZone = hasActiveQuest and state.inPreyZone ~= true
    if forceKillStage then
        pct = 100
        displayReason = "killStage"
    elseif not hasActiveQuest then
        pct = 0
        displayReason = "noActiveQuest"
    elseif isOutOfPreyZone then
        pct = 0
        displayReason = "outOfPreyZone"
    else
        if stage == 5 and state.progressPercent == nil then
            pct = 100
            if state.lastPercentSource == "none" then
                state.lastPercentSource = "final"
            end
        else
            pct = state.progressPercent
            local shouldUseStageFallback = (pct == nil)
                or (settings.percentFallbackMode == PERCENT_FALLBACK_STAGE and stage > 1 and pct <= 0)

            if shouldUseStageFallback then
                if settings.percentFallbackMode == PERCENT_FALLBACK_STAGE then
                    pct = STAGE_PCT[stage] or 0
                    if state.lastPercentSource == "none" then
                        state.lastPercentSource = "stage"
                    end
                else
                    pct = 0
                end
            end
        end
        displayReason = "activeQuest"
    end
    local label = GetStageLabel(stage)
    local barWidth = settings.width

    if barFill then
        local width = barWidth * (pct / 100)
        local shouldHideFill = (pct <= 0) or (not hasActiveQuest and not forceKillStage)
        if shouldHideFill then
            barFill:SetWidth(0)
            barFill:Hide()
        else
            barFill:SetWidth(math.max(1, width))
            barFill:Show()
        end
    end

    state.lastDisplayPct = pct
    state.lastDisplayReason = displayReason

    state.stage = stage

    if isOutOfPreyZone and not forceKillStage then
        stageText:SetText(settings.outOfZoneLabel or DEFAULT_OUT_OF_ZONE_LABEL)
    elseif not hasActiveQuest and not forceKillStage then
        local zoneName = GetZoneText and GetZoneText() or "Unknown Zone"
        stageText:SetText(zoneName)
    else
        stageText:SetText(label)
    end

    barText:SetText(string.format("%d%%", pct))
end

local function ClearPreyStateAndDisplay()
    state.activeQuestID = nil
    state.progressState = nil
    state.progressPercent = 0
    state.preyZoneName = nil
    state.preyZoneMapID = nil
    state.inPreyZone = nil
    state.preyTooltipText = nil
    state.stage = 1
    state.killStageUntil = 0
    state.lastWidgetSeenAt = 0
    state.stageSoundPlayed = {}
    state.lastStateDebugSnapshot = nil

    if barFill then
        barFill:SetWidth(0)
    end
end

local function DebugLogPreyState(origin, questID, hasWidgetData, progressState, progressPercent, inPreyZone)
    if not (debugDB and debugDB.enabled) then
        return
    end

    local snapshot = table.concat({
        tostring(origin),
        tostring(questID),
        tostring(hasWidgetData),
        tostring(progressState),
        tostring(progressPercent),
        tostring(inPreyZone),
    }, "|")

    if snapshot == state.lastStateDebugSnapshot then
        return
    end

    state.lastStateDebugSnapshot = snapshot
    AddDebugLog("PreyState", "origin=" .. tostring(origin)
        .. " | questID=" .. tostring(questID)
        .. " | widget=" .. tostring(hasWidgetData)
        .. " | state=" .. tostring(progressState)
        .. " | pct=" .. tostring(progressPercent)
        .. " | inZone=" .. tostring(inPreyZone), false)
end

local function GetCandidateWidgetSetIDs()
    for index = #candidateWidgetSetIDs, 1, -1 do
        candidateWidgetSetIDs[index] = nil
    end

    if C_UIWidgetManager and C_UIWidgetManager.GetTopCenterWidgetSetID then
        candidateWidgetSetIDs[#candidateWidgetSetIDs + 1] = C_UIWidgetManager.GetTopCenterWidgetSetID()
    end
    if C_UIWidgetManager and C_UIWidgetManager.GetObjectiveTrackerWidgetSetID then
        candidateWidgetSetIDs[#candidateWidgetSetIDs + 1] = C_UIWidgetManager.GetObjectiveTrackerWidgetSetID()
    end
    if C_UIWidgetManager and C_UIWidgetManager.GetBelowMinimapWidgetSetID then
        candidateWidgetSetIDs[#candidateWidgetSetIDs + 1] = C_UIWidgetManager.GetBelowMinimapWidgetSetID()
    end
    if C_UIWidgetManager and C_UIWidgetManager.GetPowerBarWidgetSetID then
        candidateWidgetSetIDs[#candidateWidgetSetIDs + 1] = C_UIWidgetManager.GetPowerBarWidgetSetID()
    end

    return candidateWidgetSetIDs
end

local function FormatMemoryKB(value)
    return string.format("%.1f", value or 0)
end

local function PrintMemoryUsage()
    if not collectgarbage then
        print("Preydator: collectgarbage API unavailable.")
        return
    end

    local before = collectgarbage("count")
    collectgarbage("collect")
    local after = collectgarbage("count")
    local delta = before - after

    print("Preydator memory (KB): before=" .. FormatMemoryKB(before) .. " afterGC=" .. FormatMemoryKB(after) .. " reclaimed=" .. FormatMemoryKB(delta))
end

local function BuildStageSoundPlayedSummary()
    local parts = {}
    for stage = 1, 5 do
        parts[#parts + 1] = tostring(stage) .. "=" .. tostring(state.stageSoundPlayed and state.stageSoundPlayed[stage] == true)
    end
    return table.concat(parts, ", ")
end

local function TrimText(value, maxLen)
    if type(value) ~= "string" then
        return ""
    end

    maxLen = tonumber(maxLen) or 80
    if #value <= maxLen then
        return value
    end

    return string.sub(value, 1, maxLen - 3) .. "..."
end

local function PrintInspectState()
    EnsureBar()
    UpdateBarDisplay()

    local now = GetTime and GetTime() or 0
    local liveQuestID = GetCurrentActivePreyQuest()
    local hasActiveQuest = IsValidQuestID(liveQuestID)
    local questOnLog = IsQuestStillActive(liveQuestID)
    local questCompleted = false
    if hasActiveQuest and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        questCompleted = C_QuestLog.IsQuestFlaggedCompleted(liveQuestID) and true or false
    end

    local playerMapID = (C_Map and C_Map.GetBestMapForUnit) and C_Map.GetBestMapForUnit("player") or nil
    local playerMapName = nil
    if playerMapID and C_Map and C_Map.GetMapInfo then
        local mapInfo = C_Map.GetMapInfo(playerMapID)
        playerMapName = mapInfo and mapInfo.name or nil
    end

    local shownWidgets = 0
    local objectivePct = ExtractQuestObjectivePercent(liveQuestID)
    local objectives = (hasActiveQuest and C_QuestLog and C_QuestLog.GetQuestObjectives) and C_QuestLog.GetQuestObjectives(liveQuestID) or nil
    local preyWidgetType = GetWidgetTypePreyHuntProgress()
    local shownStateShown = GetShownStateShown()

    print("Preydator Inspect (" .. INSPECT_VERSION .. ")")
    print("- time=" .. string.format("%.3f", now) .. " | zone=" .. tostring(GetZoneText and GetZoneText() or "?") .. " | playerMapID=" .. tostring(playerMapID) .. " | playerMap=" .. tostring(playerMapName))
    print("- quest live=" .. tostring(liveQuestID) .. " | hasActive=" .. tostring(hasActiveQuest) .. " | isOnQuest=" .. tostring(questOnLog) .. " | completed=" .. tostring(questCompleted))
    print("- quest tracked=" .. tostring(state.activeQuestID) .. " | progressState=" .. tostring(state.progressState) .. " | progressPercent=" .. tostring(state.progressPercent) .. " | stage=" .. tostring(state.stage) .. " (" .. tostring(GetStageLabel(state.stage)) .. ")")
    print("- preyZone mapID=" .. tostring(state.preyZoneMapID) .. " | preyZoneName=" .. tostring(state.preyZoneName) .. " | inPreyZone=" .. tostring(state.inPreyZone))
    print("- killStageRemaining=" .. string.format("%.2f", math.max(0, (state.killStageUntil or 0) - now)) .. " | lastWidgetAge=" .. string.format("%.2f", math.max(0, now - (state.lastWidgetSeenAt or 0))))
    print("- sounds enabled=" .. tostring(settings and settings.soundsEnabled) .. " | channel=" .. tostring(settings and settings.soundChannel) .. " | stagePlayed={" .. BuildStageSoundPlayedSummary() .. "}")
    print("- percent source=" .. tostring(state.lastPercentSource) .. " | fallbackMode=" .. tostring(settings and settings.percentFallbackMode) .. " | objectivePct=" .. tostring(objectivePct))
    if type(objectives) == "table" and #objectives > 0 then
        local shown = 0
        for index, objective in ipairs(objectives) do
            if type(objective) == "table" then
                shown = shown + 1
                if shown > 4 then
                    print("  objective ... (" .. tostring(#objectives - 4) .. " more)")
                    break
                end

                print("  objective " .. tostring(index)
                    .. " fulfilled=" .. tostring(objective.numFulfilled or objective.fulfilled)
                    .. " required=" .. tostring(objective.numRequired or objective.required)
                    .. " finished=" .. tostring(objective.finished)
                    .. " text='" .. TrimText(objective.text, 80) .. "'")
            end
        end
    else
        print("  objective none")
    end
    print("- bar shown=" .. tostring(barFrame and barFrame:IsShown() or false) .. " | forceShow=" .. tostring(state.forceShowBar) .. " | showWhenNoPrey=" .. tostring(settings and settings.showWhenNoPrey))
    local frameWidth = barFrame and barFrame:GetWidth() or 0
    local fillWidth = barFill and barFill:GetWidth() or 0
    local fillPct = 0
    if frameWidth and frameWidth > 0 then
        fillPct = (fillWidth / frameWidth) * 100
    end
    print("- display pct=" .. tostring(state.lastDisplayPct) .. " | reason=" .. tostring(state.lastDisplayReason)
        .. " | frameWidth=" .. string.format("%.2f", frameWidth)
        .. " | fillWidth=" .. string.format("%.2f", fillWidth)
        .. " | fillPct=" .. string.format("%.2f", fillPct))
    print("- frame local=" .. tostring(barFrame) .. " | frame global=" .. tostring(_G.PreydatorProgressBar)
        .. " | same=" .. tostring(barFrame ~= nil and _G.PreydatorProgressBar ~= nil and barFrame == _G.PreydatorProgressBar))

    if C_UIWidgetManager and C_UIWidgetManager.GetAllWidgetsBySetID and C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo then
        for _, setID in ipairs(GetCandidateWidgetSetIDs()) do
            local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(setID)
            if widgets and #widgets > 0 then
                for _, widget in ipairs(widgets) do
                    if widget and widget.widgetType == preyWidgetType then
                        local info = C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo(widget.widgetID)
                        if info and info.shownState == shownStateShown then
                            shownWidgets = shownWidgets + 1
                            local pct = ExtractProgressPercent(info, info.tooltip)
                            local widgetQuestID = ExtractWidgetQuestID(info)
                            print("  widget set=" .. tostring(setID) .. " widgetID=" .. tostring(widget.widgetID)
                                .. " questID=" .. tostring(widgetQuestID)
                                .. " state=" .. tostring(info.progressState)
                                .. " pct=" .. tostring(pct)
                                .. " tooltip='" .. TrimText(info.tooltip, 90) .. "'")
                            print("    fields: " .. TrimText(SummarizeInfoFields(info), 200))
                        end
                    end
                end
            end
        end
    end

    if shownWidgets == 0 then
        print("  widget none shown")
    end
end

ExtractWidgetQuestID = function(info)
    if type(info) ~= "table" then
        return nil
    end

    local possibleFields = {
        "questID",
        "questId",
        "associatedQuestID",
        "associatedQuestId",
    }

    for _, fieldName in ipairs(possibleFields) do
        local value = info[fieldName]
        if type(value) == "number" and value > 0 then
            return value
        end
    end

    return nil
end

local function FindPreyWidgetProgressState(activeQuestID)
    if not (C_UIWidgetManager and C_UIWidgetManager.GetAllWidgetsBySetID and C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo) then
        return nil
    end

    local preyWidgetType = GetWidgetTypePreyHuntProgress()
    local shownStateShown = GetShownStateShown()
    local fallbackState, fallbackTooltip, fallbackPct = nil, nil, nil

    for _, setID in ipairs(GetCandidateWidgetSetIDs()) do
        local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(setID)
        if widgets then
            for _, widget in ipairs(widgets) do
                if widget and widget.widgetType == preyWidgetType then
                    local info = C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo(widget.widgetID)
                    if info and info.shownState == shownStateShown then
                        local pct = ExtractProgressPercent(info, info.tooltip)
                        if IsValidQuestID(activeQuestID) then
                            local widgetQuestID = ExtractWidgetQuestID(info)
                            if widgetQuestID == activeQuestID then
                                return info.progressState, info.tooltip, pct
                            end

                            if widgetQuestID == nil and fallbackState == nil then
                                fallbackState, fallbackTooltip, fallbackPct = info.progressState, info.tooltip, pct
                            end
                        else
                            return info.progressState, info.tooltip, pct
                        end
                    end
                end
            end
        end
    end

    if IsValidQuestID(activeQuestID) then
        return fallbackState, fallbackTooltip, fallbackPct
    end

    return nil, nil, nil
end

local function ResetStateForNewQuest(questID)
    if state.activeQuestID ~= questID then
        state.activeQuestID = questID
        state.progressState = nil
        state.progressPercent = nil
        state.stageSoundPlayed = {}
        state.stage = 1
        state.preyZoneName, state.preyZoneMapID = GetPreyZoneInfo(questID)
        state.inPreyZone = IsPlayerInPreyZone(state.preyZoneMapID)
        state.preyTooltipText = nil
    end
end

local function UpdatePreyState()
    local questID = GetCurrentActivePreyQuest()
    local hasActiveQuest = IsValidQuestID(questID)
    local newProgressState, tooltipText, newProgressPercent = FindPreyWidgetProgressState(hasActiveQuest and questID or nil)
    local now = GetTime and GetTime() or 0
    local hasWidgetData = newProgressState ~= nil

    if hasWidgetData then
        state.lastWidgetSeenAt = now
    end

    local effectiveQuestID = hasActiveQuest and questID or nil

    local questCompleted = false
    if questID and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        questCompleted = C_QuestLog.IsQuestFlaggedCompleted(questID) and true or false
    end

    local questStillActive = IsQuestStillActive(questID)
    if (not hasActiveQuest and not ((state.killStageUntil or 0) > now)) or questCompleted or (hasActiveQuest and not questStillActive and not hasWidgetData) then
        DebugLogPreyState("clear", questID, hasWidgetData, state.progressState, state.progressPercent, state.inPreyZone)
        ClearPreyStateAndDisplay()
        UpdateBarDisplay()
        return
    end

    ResetStateForNewQuest(effectiveQuestID)
    if hasWidgetData then
        state.inPreyZone = true
    else
        state.inPreyZone = IsPlayerInPreyZone(state.preyZoneMapID)
    end

    local oldProgressState = state.progressState
    local percentSource = "none"
    if newProgressState ~= nil then
        state.progressState = newProgressState
        state.inPreyZone = true
    end
    if newProgressPercent ~= nil then
        state.progressPercent = newProgressPercent
        percentSource = "widget"
    else
        local objectivePercent = ExtractQuestObjectivePercent(questID)
        if objectivePercent ~= nil and (objectivePercent > 0 or newProgressState == PREY_PROGRESS_FINAL) then
            state.progressPercent = objectivePercent
            percentSource = "objective"
        end
    end

    if newProgressPercent == nil and percentSource == "none" and newProgressState ~= nil then
        if newProgressState == PREY_PROGRESS_FINAL then
            state.progressPercent = 100
            percentSource = "final"
        else
            state.progressPercent = nil
        end
    elseif newProgressPercent == nil and percentSource == "none" and (now - (state.lastWidgetSeenAt or 0)) > 2 then
        state.progressPercent = nil
        state.progressState = nil
    end
    state.lastPercentSource = percentSource
    state.preyTooltipText = tooltipText
    DebugLogPreyState("update", effectiveQuestID, hasWidgetData, state.progressState, state.progressPercent, state.inPreyZone)

    local oldStage = state.stage
    local newStage = GetStageFromState(state.progressState)

    local stageChanged = newStage ~= oldStage
    if stageChanged then
        TryPlayStageSound(newStage)
    end

    if newProgressState ~= PREY_PROGRESS_FINAL or oldProgressState == PREY_PROGRESS_FINAL then
        UpdateBarDisplay()
        return
    end

    if state.stageSoundPlayed[5] then
        UpdateBarDisplay()
        return
    end

    TryPlayStageSound(5)

    UpdateBarDisplay()
end

local function OnAddonLoaded()
    _G.PreydatorDB = _G.PreydatorDB or {}
    settings = _G.PreydatorDB
    ApplyDefaults(settings, DEFAULTS)
    EnsureDebugDB()
    debugDB.enabled = settings.debugSounds and true or false

    if type(settings.stageSounds) ~= "table" then
        settings.stageSounds = {}
    end

    for stage = 2, 5 do
        local configuredPath = settings.stageSounds[stage]
        if type(configuredPath) ~= "string" or configuredPath == "" then
            local legacyPath = settings.stageSounds[tostring(stage)]
            if type(legacyPath) == "string" and legacyPath ~= "" then
                configuredPath = legacyPath
            end
        end

        if type(configuredPath) == "string" and string.find(string.lower(configuredPath), "predator%-idle%.ogg", 1, false) then
            configuredPath = nil
        end

        if type(configuredPath) ~= "string" or configuredPath == "" then
            configuredPath = GetDefaultStageSoundPath(stage)
        end

        settings.stageSounds[stage] = configuredPath
    end

    settings.stageSounds[1] = nil
    NormalizeLabelSettings()
    NormalizeColorSettings()
    NormalizeDisplaySettings()
    AddDebugLog("OnAddonLoaded", "debug=" .. tostring(debugDB.enabled) .. " | stage5=" .. tostring(settings.stageSounds[5]), true)

    state.forceShowBar = settings.forceShowBar

    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:RegisterEvent("UPDATE_ALL_UI_WIDGETS")
    frame:RegisterEvent("UPDATE_UI_WIDGET")
    frame:RegisterEvent("QUEST_TURNED_IN")
    frame:RegisterEvent("ZONE_CHANGED")
    frame:RegisterEvent("ZONE_CHANGED_INDOORS")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
end

local function AddCheckbox(parent, label, x, y, getter, setter)
    local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    checkbox.Text:SetText(label)
    checkbox:SetChecked(getter())
    checkbox:SetScript("OnClick", function(self)
        setter(self:GetChecked())
    end)
    return checkbox
end

local function AddSlider(parent, label, x, y, minValue, maxValue, step, getter, setter)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetWidth(240)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(getter())
    slider.Text:SetText(label)
    slider.Low:SetText(tostring(minValue))
    slider.High:SetText(tostring(maxValue))
    slider:SetScript("OnValueChanged", function(self, value)
        setter(value)
    end)
    return slider
end

local function AddDropdown(parent, label, x, y, width, options, getter, setter)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    title:SetText(label)

    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -16, -4)

    local function RefreshText()
        local key = getter()
        local entry = options[key]
        UIDropDownMenu_SetText(dropdown, entry and entry.text or "Select")
    end

    UIDropDownMenu_SetWidth(dropdown, width)
    UIDropDownMenu_Initialize(dropdown, function(_, _, _)
        for key, entry in pairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = entry.text
            info.func = function()
                setter(key)
                RefreshText()
            end
            info.checked = getter() == key
            UIDropDownMenu_AddButton(info)
        end
    end)

    RefreshText()
    return dropdown
end

local function AddColorSwatch(parent, x, y, getter, setter, allowAlpha)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(28, 22)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText("")

    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    swatch:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)

    local function Refresh()
        local c = getter()
        local a = (allowAlpha and c[4]) or 1
        swatch:SetColorTexture(c[1], c[2], c[3], a)
    end

    local function NormalizeColorInput(value, fallback)
        local fb = fallback or { 1, 1, 1, 1 }
        local r = value and (value[1] or value.r) or fb[1]
        local g = value and (value[2] or value.g) or fb[2]
        local b = value and (value[3] or value.b) or fb[3]

        local a = fb[4]
        if allowAlpha then
            if value then
                if value[4] ~= nil then
                    a = value[4]
                elseif value.a ~= nil then
                    a = value.a
                elseif value.opacity ~= nil then
                    a = 1 - value.opacity
                end
            end
        else
            a = 1
        end

        r = Clamp(tonumber(r) or fb[1] or 1, 0, 1)
        g = Clamp(tonumber(g) or fb[2] or 1, 0, 1)
        b = Clamp(tonumber(b) or fb[3] or 1, 0, 1)
        a = Clamp(tonumber(a) or fb[4] or 1, 0, 1)

        return { r, g, b, a }
    end

    button:SetScript("OnClick", function()
        if not ColorPickerFrame then
            return
        end

        local start = getter()
        local startColor = {
            start[1] or 1,
            start[2] or 1,
            start[3] or 1,
            start[4] or 1,
        }

        local function ApplyColor()
            local r, g, b
            if ColorPickerFrame.GetColorRGB then
                r, g, b = ColorPickerFrame:GetColorRGB()
            elseif ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker and ColorPickerFrame.Content.ColorPicker.GetColorRGB then
                r, g, b = ColorPickerFrame.Content.ColorPicker:GetColorRGB()
            else
                r, g, b = startColor[1], startColor[2], startColor[3]
            end
            local a = startColor[4]
            if allowAlpha and OpacitySliderFrame and OpacitySliderFrame.GetValue then
                a = 1 - OpacitySliderFrame:GetValue()
            end
            setter(NormalizeColorInput({ r, g, b, a }, startColor))
            Refresh()
        end

        local function CancelColor(previousValues)
            if type(previousValues) ~= "table" then
                previousValues = startColor
            end
            setter(NormalizeColorInput(previousValues, startColor))
            Refresh()
        end

        ColorPickerFrame.hasOpacity = allowAlpha and true or false
        ColorPickerFrame.opacity = allowAlpha and (1 - startColor[4]) or 0
        ColorPickerFrame.previousValues = { startColor[1], startColor[2], startColor[3], startColor[4] }
        if ColorPickerFrame.SetColorRGB then
            ColorPickerFrame:SetColorRGB(startColor[1], startColor[2], startColor[3])
        elseif ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker and ColorPickerFrame.Content.ColorPicker.SetColorRGB then
            ColorPickerFrame.Content.ColorPicker:SetColorRGB(startColor[1], startColor[2], startColor[3])
        end
        ColorPickerFrame.func = ApplyColor
        ColorPickerFrame.swatchFunc = ApplyColor
        ColorPickerFrame.opacityFunc = ApplyColor
        ColorPickerFrame.cancelFunc = CancelColor

        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end)

    Refresh()
    return button
end

local function EnsureOptionsPanel()
    if optionsPanel then
        return
    end

    local panel = CreateFrame("Frame", "PreydatorOptionsPanel")
    panel.name = "Preydator"

    NormalizeLabelSettings()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Preydator")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Bar movement, scale, font, texture, and sound settings.")
    subtitle:SetWidth(700)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetWordWrap(true)

    AddCheckbox(panel, "Lock Bar", 20, -50, function() return settings.locked end, function(value)
        settings.locked = value
        ApplyBarSettings()
    end)

    AddCheckbox(panel, "Show when no active prey", 20, -80, function() return settings.showWhenNoPrey end, function(value)
        settings.showWhenNoPrey = value
        UpdateBarDisplay()
    end)

    AddSlider(panel, "Scale", 20, -130, 0.5, 2, 0.05, function() return settings.scale end, function(value)
        settings.scale = Clamp(value, 0.5, 2)
        ApplyBarSettings()
    end)

    AddSlider(panel, "Width", 20, -190, 160, 500, 1, function() return settings.width end, function(value)
        settings.width = Clamp(math.floor(value + 0.5), 160, 500)
        ApplyBarSettings()
        UpdateBarDisplay()
    end)

    AddSlider(panel, "Height", 20, -250, 10, 40, 1, function() return settings.height end, function(value)
        settings.height = Clamp(math.floor(value + 0.5), 10, 40)
        ApplyBarSettings()
        UpdateBarDisplay()
    end)

    AddSlider(panel, "Font Size", 20, -310, 8, 24, 1, function() return settings.fontSize end, function(value)
        settings.fontSize = Clamp(math.floor(value + 0.5), 8, 24)
        ApplyBarSettings()
    end)

    local stageNamesTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    stageNamesTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -360)
    stageNamesTitle:SetText("Stage Names")

    local stageNameEdits = {}
    for stageIndex = 1, 5 do
        local rowY = -360 - (stageIndex * 26)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, rowY)
        label:SetText(tostring(stageIndex) .. ":")

        local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        edit:SetSize(180, 20)
        edit:SetAutoFocus(false)
        edit:SetTextInsets(6, 6, 0, 0)
        edit:SetPoint("TOPLEFT", panel, "TOPLEFT", 40, rowY + 3)
        edit:SetText(GetStageLabel(stageIndex))
        edit:SetScript("OnEnterPressed", function(self)
            settings.stageLabels[stageIndex] = self:GetText()
            NormalizeLabelSettings()
            self:SetText(settings.stageLabels[stageIndex])
            self:ClearFocus()
            UpdateBarDisplay()
        end)
        edit:SetScript("OnEditFocusLost", function(self)
            settings.stageLabels[stageIndex] = self:GetText()
            NormalizeLabelSettings()
            self:SetText(settings.stageLabels[stageIndex])
            UpdateBarDisplay()
        end)
        stageNameEdits[stageIndex] = edit
    end

    local outZoneRowY = -360 - (6 * 26)
    local outZoneLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    outZoneLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, outZoneRowY)
    outZoneLabel:SetText("Out:")

    local outZoneEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    outZoneEdit:SetSize(156, 20)
    outZoneEdit:SetAutoFocus(false)
    outZoneEdit:SetTextInsets(6, 6, 0, 0)
    outZoneEdit:SetPoint("TOPLEFT", panel, "TOPLEFT", 64, outZoneRowY + 3)
    outZoneEdit:SetText(settings.outOfZoneLabel or DEFAULT_OUT_OF_ZONE_LABEL)
    outZoneEdit:SetScript("OnEnterPressed", function(self)
        settings.outOfZoneLabel = self:GetText()
        NormalizeLabelSettings()
        self:SetText(settings.outOfZoneLabel)
        self:ClearFocus()
        UpdateBarDisplay()
    end)
    outZoneEdit:SetScript("OnEditFocusLost", function(self)
        settings.outOfZoneLabel = self:GetText()
        NormalizeLabelSettings()
        self:SetText(settings.outOfZoneLabel)
        UpdateBarDisplay()
    end)

    local restoreNamesButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    restoreNamesButton:SetSize(180, 24)
    restoreNamesButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 40, -548)
    restoreNamesButton:SetText("Restore Default Names")
    restoreNamesButton:SetScript("OnClick", function()
        for stageIndex = 1, 5 do
            settings.stageLabels[stageIndex] = DEFAULT_STAGE_LABELS[stageIndex]
            stageNameEdits[stageIndex]:SetText(DEFAULT_STAGE_LABELS[stageIndex])
        end
        settings.outOfZoneLabel = DEFAULT_OUT_OF_ZONE_LABEL
        outZoneEdit:SetText(DEFAULT_OUT_OF_ZONE_LABEL)
        UpdateBarDisplay()
    end)

    panel:SetScript("OnShow", function()
        NormalizeLabelSettings()
        for stageIndex = 1, 5 do
            stageNameEdits[stageIndex]:SetText(settings.stageLabels[stageIndex])
        end
        outZoneEdit:SetText(settings.outOfZoneLabel)
    end)

    local textureOptions = {
        default = { text = "Default" },
        flat = { text = "Flat" },
        raid = { text = "Raid HP Fill" },
        classic = { text = "Classic Skill Bar" },
        nameplate = { text = "Nameplate Fill" },
    }

    local fontOptions = {
        frizqt = { text = "Friz Quadrata" },
        arialn = { text = "Arial Narrow" },
        skurri = { text = "Skurri" },
        morpheus = { text = "Morpheus" },
    }

    local channelOptions = {
        Master = { text = "Master" },
        SFX = { text = "SFX" },
        Dialog = { text = "Dialog" },
        Ambience = { text = "Ambience" },
    }

    local percentDisplayOptions = {
        [PERCENT_DISPLAY_INSIDE] = { text = "In Bar" },
        [PERCENT_DISPLAY_UNDER_TICKS] = { text = "Under Ticks" },
        [PERCENT_DISPLAY_BELOW_BAR] = { text = "Below Bar" },
        [PERCENT_DISPLAY_OFF] = { text = "Off" },
    }

    AddDropdown(panel, "Texture", 320, -130, 170, textureOptions, function()
        return settings.textureKey
    end, function(key)
        settings.textureKey = key
        ApplyBarSettings()
    end)
    AddColorSwatch(panel, 530, -150, function()
        return settings.fillColor
    end, function(color)
        settings.fillColor = { color[1], color[2], color[3], color[4] }
        ApplyBarSettings()
    end, true)

    AddDropdown(panel, "Title Font", 320, -185, 170, fontOptions, function()
        return settings.titleFontKey
    end, function(key)
        settings.titleFontKey = key
        ApplyBarSettings()
    end)
    AddColorSwatch(panel, 530, -200, function()
        return settings.titleColor
    end, function(color)
        settings.titleColor = { color[1], color[2], color[3], color[4] }
        ApplyBarSettings()
        UpdateBarDisplay()
    end, true)

    AddDropdown(panel, "Percent Font", 320, -232, 170, fontOptions, function()
        return settings.percentFontKey
    end, function(key)
        settings.percentFontKey = key
        ApplyBarSettings()
    end)
    AddColorSwatch(panel, 530, -260, function()
        return settings.percentColor
    end, function(color)
        settings.percentColor = { color[1], color[2], color[3], color[4] }
        ApplyBarSettings()
        UpdateBarDisplay()
    end, true)

    AddCheckbox(panel, "Enable sounds", 320, -360, function() return settings.soundsEnabled end, function(value)
        settings.soundsEnabled = value
    end)

    AddDropdown(panel, "Sound Channel", 320, -295, 170, channelOptions, function()
        return settings.soundChannel
    end, function(key)
        settings.soundChannel = key
    end)

    AddSlider(panel, "Enhance Sounds", 320, -400, 0, 100, 5, function()
        return settings.soundEnhance or 0
    end, function(value)
        settings.soundEnhance = Clamp(math.floor(value + 0.5), 0, 100)
    end)

    AddCheckbox(panel, "Show tick marks", 320, -50, function() return settings.showTicks end, function(value)
        settings.showTicks = value
        ApplyBarSettings()
        UpdateBarDisplay()
    end)

    AddDropdown(panel, "Percent Display", 320, -80, 170, percentDisplayOptions, function()
        return settings.percentDisplay
    end, function(key)
        settings.percentDisplay = key
        NormalizeDisplaySettings()
        ApplyBarSettings()
        UpdateBarDisplay()
    end)

    local function AddSoundTestButton(text, x, y, stageIndex)
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(140, 24)
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
        button:SetText(text)
        button:SetScript("OnClick", function()
            state.stageSoundPlayed[stageIndex] = nil
            if not ResolveStageSoundPath(stageIndex) then
                print("Preydator: No stage " .. stageIndex .. " sound configured.")
                return
            end

            if not TryPlayStageSound(stageIndex, true) then
                print("Preydator: Stage " .. stageIndex .. " sound failed to play. Check file path and channel volume.")
            end
        end)
    end

    AddSoundTestButton("Test 25%", 320, -430, 2)
    AddSoundTestButton("Test 50%", 320, -460, 3)
    AddSoundTestButton("Test 75%", 320, -492, 4)
    AddSoundTestButton("Test 100%", 320, -522, 5)

    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", panel, "TOPLEFT", 320, -552)
    note:SetWidth(280)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText("Enhance Sounds layers extra plays for perceived loudness. WoW does not expose true per-addon file volume.")

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Preydator", "Preydator")
        Settings.RegisterAddOnCategory(category)
    elseif _G.InterfaceOptions_AddCategory then
        _G.InterfaceOptions_AddCategory(panel)
    end

    optionsPanel = panel
end

local function HandleSlashCommand(message)
    local trimmed = (message or ""):match("^%s*(.-)%s*$")
    local command, rest = trimmed:match("^(%S+)%s*(.-)$")
    local text = string.lower(command or "")

    if text == "test" then
        state.stageSoundPlayed[5] = nil
        if not ResolveStageSoundPath(5) then
            AddDebugLog("SlashTest", "stage=5 | ResolveStageSoundPath returned nil", true)
            print("Preydator: No stage 5 sound configured.")
            return
        end

        if TryPlayStageSound(5, true) then
            print("Preydator: Test stage 5 sound played.")
        else
            print("Preydator: Stage 5 sound failed to play. Check file path and channel volume.")
        end
        return
    end

    if text == "testalert" then
        state.stageSoundPlayed[3] = nil
        if not ResolveStageSoundPath(3) then
            AddDebugLog("SlashTest", "stage=3 | ResolveStageSoundPath returned nil", true)
            print("Preydator: No stage 3 sound configured.")
            return
        end

        if TryPlayStageSound(3, true) then
            print("Preydator: Test stage 3 sound played.")
        else
            print("Preydator: Stage 3 sound failed to play. Check file path and channel volume.")
        end
        return
    end

    if text == "debug" then
        EnsureDebugDB()
        local mode = string.lower(rest or "")

        if mode == "on" then
            settings.debugSounds = true
            debugDB.enabled = true
            print("Preydator: Debug logging enabled.")
            return
        end

        if mode == "off" then
            settings.debugSounds = false
            debugDB.enabled = false
            print("Preydator: Debug logging disabled.")
            return
        end

        if mode == "clear" then
            debugDB.entries = {}
            print("Preydator: Debug log cleared.")
            return
        end

        if mode == "show" or mode == "" then
            local total = #debugDB.entries
            if total == 0 then
                print("Preydator: Debug log is empty.")
                return
            end

            local fromIndex = math.max(1, total - 19)
            print("Preydator: Debug log (last " .. (total - fromIndex + 1) .. " of " .. total .. ")")
            for index = fromIndex, total do
                print("  " .. debugDB.entries[index])
            end
            return
        end

        print("Preydator: debug commands are 'debug on', 'debug off', 'debug show', 'debug clear'.")
        return
    end

    if text == "inspect" then
        PrintInspectState()
        return
    end

    if text == "fillmode" then
        local mode = string.lower(rest or "")
        if mode ~= PERCENT_FALLBACK_STRICT and mode ~= PERCENT_FALLBACK_STAGE then
            print("Preydator: usage /preydator fillmode <strict|stage>")
            print("Preydator: current fillmode is " .. tostring(settings.percentFallbackMode))
            return
        end

        settings.percentFallbackMode = mode
        NormalizeDisplaySettings()
        UpdateBarDisplay()
        print("Preydator: fillmode set to " .. tostring(settings.percentFallbackMode))
        return
    end

    if text == "show" then
        state.forceShowBar = true
        settings.forceShowBar = true
        UpdateBarDisplay()
        print("Preydator: Progress bar forced visible.")
        return
    end

    if text == "hide" then
        state.forceShowBar = false
        settings.forceShowBar = false
        UpdateBarDisplay()
        print("Preydator: Progress bar auto mode restored.")
        return
    end

    if text == "toggle" then
        state.forceShowBar = not state.forceShowBar
        settings.forceShowBar = state.forceShowBar
        UpdateBarDisplay()
        print("Preydator: Progress bar force show = " .. tostring(state.forceShowBar))
        return
    end

    if text == "unlock" then
        settings.locked = false
        ApplyBarSettings()
        print("Preydator: Bar unlocked. Drag with left mouse.")
        return
    end

    if text == "lock" then
        settings.locked = true
        ApplyBarSettings()
        print("Preydator: Bar locked.")
        return
    end

    if text == "reset" then
        settings.point.anchor = DEFAULTS.point.anchor
        settings.point.x = DEFAULTS.point.x
        settings.point.y = DEFAULTS.point.y
        settings.textureKey = DEFAULTS.textureKey
        settings.fillColor = { DEFAULTS.fillColor[1], DEFAULTS.fillColor[2], DEFAULTS.fillColor[3], DEFAULTS.fillColor[4] }
        settings.bgColor = { DEFAULTS.bgColor[1], DEFAULTS.bgColor[2], DEFAULTS.bgColor[3], DEFAULTS.bgColor[4] }
        ApplyBarSettings()
        UpdateBarDisplay()
        print("Preydator: Bar position and appearance reset.")
        return
    end

    if text == "texture" then
        local key = string.lower(rest or "")
        if not TEXTURE_PRESETS[key] then
            print("Preydator: texture options are 'default', 'flat', 'raid', 'classic', 'nameplate'.")
            return
        end

        settings.textureKey = key
        ApplyBarSettings()
        print("Preydator: Texture set to " .. key)
        return
    end

    if text == "color" then
        local r, g, b = rest:match("^(%S+)%s+(%S+)%s+(%S+)$")
        r, g, b = tonumber(r), tonumber(g), tonumber(b)
        if not r or not g or not b then
            print("Preydator: usage /preydator color <r> <g> <b> (0-1)")
            return
        end

        settings.fillColor[1] = math.max(0, math.min(1, r))
        settings.fillColor[2] = math.max(0, math.min(1, g))
        settings.fillColor[3] = math.max(0, math.min(1, b))
        ApplyBarSettings()
        print("Preydator: Fill color updated.")
        return
    end

    if text == "stage" then
        local stageIndex, newLabel = rest:match("^(%d+)%s+(.+)$")
        local stageNumber = tonumber(stageIndex)
        if not stageNumber or stageNumber < 1 or stageNumber > 5 or not newLabel then
            print("Preydator: usage /preydator stage <1-5> <label>")
            return
        end

        settings.stageLabels[stageNumber] = newLabel
        UpdateBarDisplay()
        print("Preydator: Stage " .. stageNumber .. " renamed to '" .. newLabel .. "'.")
        return
    end

    if text == "options" or text == "open" then
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("Preydator")
        elseif _G.InterfaceOptionsFrame_OpenToCategory then
            _G.InterfaceOptionsFrame_OpenToCategory("Preydator")
        end
        return
    end

    if text == "mem" or text == "memory" then
        PrintMemoryUsage()
        return
    end

    print("Preydator commands: options | test | testalert | inspect | fillmode <strict|stage> | show | hide | toggle | unlock | lock | reset | texture <default|flat|raid|classic|nameplate> | color <r g b> | stage <1-5> <label> | mem | debug <on|off|show|clear>")
end

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        OnAddonLoaded()
        EnsureOptionsPanel()
        SlashCmdList["PREYDATOR"] = HandleSlashCommand
        return
    end

    if event == "ADDON_LOADED" then
        return
    end

    if event == "PLAYER_LOGIN" then
        EnsureBar()
        ApplyBarSettings()
        UpdateBarDisplay()
        return
    end

    if event == "QUEST_TURNED_IN" and state.activeQuestID and arg1 == state.activeQuestID then
        state.killStageUntil = (GetTime and GetTime() or 0) + 8
        state.progressState = PREY_PROGRESS_FINAL
        UpdateBarDisplay()
    end

    UpdatePreyState()
end)

frame:SetScript("OnUpdate", function(_, elapsed)
    state.elapsedSinceUpdate = (state.elapsedSinceUpdate or 0) + (elapsed or 0)
    if state.elapsedSinceUpdate < UPDATE_INTERVAL_SECONDS then
        return
    end

    state.elapsedSinceUpdate = 0
    UpdatePreyState()
end)

frame:RegisterEvent("ADDON_LOADED")
