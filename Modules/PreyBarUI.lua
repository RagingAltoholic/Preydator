---@diagnostic disable

--[[
    Preydator: PreyBarUI
    Centralizes all bar frame creation, rendering, and visual styling.
    
    Ownership:
    - All bar frame elements (frame, fill, spark, border, labels, ticks)
    - Visual styling (colors, fonts, textures, positioning)
    - Tick mark rendering
    - State-driven display refresh logic
    
    Does NOT own:
    - State management (Preydator.lua)
    - Settings persistence (Settings module)
    - Event handling (Preydator.lua)
    - Audio/ambush effects (PreyAudio module)
]]

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local PreyBarUIModule = {}
Preydator:RegisterModule("PreyBarUI", PreyBarUIModule)

local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local IsEditModePreviewActive = _G.IsEditModePreviewActive
local UIParent = _G.UIParent
local math = _G.math
local string = _G.string
local table = _G.table
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local ORIENTATION_HORIZONTAL = "horizontal"
local ORIENTATION_VERTICAL = "vertical"
local FILL_DIRECTION_UP = "up"
local FILL_DIRECTION_DOWN = "down"
local FILL_INSET = 2
local PERCENT_DISPLAY_INSIDE = "inside"
local PERCENT_DISPLAY_INSIDE_BELOW = "inside_below"
local PERCENT_DISPLAY_BELOW_BAR = "below_bar"
local PERCENT_DISPLAY_ABOVE_BAR = "above_bar"
local PERCENT_DISPLAY_ABOVE_TICKS = "above_ticks"
local PERCENT_DISPLAY_UNDER_TICKS = "under_ticks"
local PERCENT_DISPLAY_OFF = "off"
local LABEL_ROW_ABOVE = "above"
local LABEL_ROW_BELOW = "below"
local LABEL_MODE_CENTER = "center"
local LABEL_MODE_LEFT = "left"
local LABEL_MODE_LEFT_COMBINED = "left_combined"
local LABEL_MODE_LEFT_SUFFIX = "left_suffix"
local LABEL_MODE_RIGHT = "right"
local LABEL_MODE_RIGHT_COMBINED = "right_combined"
local LABEL_MODE_RIGHT_PREFIX = "right_prefix"
local LABEL_MODE_SEPARATE = "separate"
local LABEL_MODE_NONE = "none"
local LAYER_MODE_ABOVE = "above"
local LAYER_MODE_BELOW = "below"
local PROGRESS_SEGMENTS_THIRDS = "thirds"
local PROGRESS_SEGMENTS_QUARTERS = "quarters"

local PROGRESS_SEGMENT_MARKS = {
    [PROGRESS_SEGMENTS_QUARTERS] = { 25, 50, 75 },
    [PROGRESS_SEGMENTS_THIRDS] = { 33, 66 },
}

local TEXTURE_PRESETS = {
    default = "Interface\\TargetingFrame\\UI-TargetingFrame-HealthBar-Fill",
    smooth = "Interface\\TargetingFrame\\UI-StatusBar",
    gradient = "Interface\\BUTTONS\\WHITE8X8",
}

local FONT_PATHS = {
    frizqt = "Fonts\\FRIZQT__.TTF",
    arialn = "Fonts\\ARIALN.TTF",
    skurri = "Fonts\\skurri.ttf",
    morpheus = "Fonts\\MORPHEUS.TTF",
}

--------------------------------------------------------------------------------
-- Module State
--------------------------------------------------------------------------------

local barFrame = nil
local barFill = nil  
local barSpark = nil
local barBorder = nil
local stageText = nil
local stageSuffixText = nil
local barText = nil
local barAlignmentDot = nil
local barTickMarks = {}
local barTickLabels = {}

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function GetCustomizationState()
    return Preydator and Preydator:GetModule("CustomizationStateV2")
end

local function GetConstants()
    return type(Preydator.Constants) == "table" and Preydator.Constants or {}
end

local function Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

local function ClampPercent(value)
    return Clamp(tonumber(value) or 0, 0, 100)
end

local function GetStageLabel(stage, settings)
    if settings and settings.stageLabels then
        local customLabel = settings.stageLabels[stage]
        if type(customLabel) == "string" and customLabel ~= "" then
            return customLabel
        end
    end
    
    local constants = GetConstants()
    local DEFAULT_STAGE_LABELS = {
        [1] = "Scent",
        [2] = "Blood",
        [3] = "Echoes",
        [4] = "Feast",
    }
    return DEFAULT_STAGE_LABELS[stage] or "Unknown"
end

local function GetStageFallbackPercent(stage, progressSegments)
    local marks = PROGRESS_SEGMENT_MARKS[progressSegments] or PROGRESS_SEGMENT_MARKS[PROGRESS_SEGMENTS_THIRDS]
    return marks[stage] or 0
end

local function GetStageFromState(progressState)
    local module = Preydator and Preydator.GetModule and Preydator:GetModule("PreyRuntime")
    local fn = module and module.GetStageFromProgressState
    if type(fn) == "function" then
        local ok, stage = pcall(fn, module, progressState)
        if ok and stage then
            return tonumber(stage) or 1
        end
    end
    return 1
end

--------------------------------------------------------------------------------
-- Public API - Initialization
--------------------------------------------------------------------------------

function PreyBarUIModule:EnsureBar()
    if barFrame then
        return
    end

    -- Create main frame
    barFrame = CreateFrame("Frame", "PreydatorBar", UIParent, "BackdropTemplate")
    barFrame:SetSize(160, 20)
    barFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    barFrame:SetFrameStrata("MEDIUM")
    barFrame:SetFrameLevel(5)
    barFrame:EnableMouse(true)
    barFrame:SetMovable(true)

    -- Background texture
    local bg = barFrame:CreateTexture(nil, "background")
    bg:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", FILL_INSET, FILL_INSET)
    bg:SetPoint("TOPRIGHT", barFrame, "TOPRIGHT", -FILL_INSET, -FILL_INSET)
    bg:SetColorTexture(0, 0, 0, 0.6)
    barFrame.BackgroundTexture = bg

    -- Fill texture
    barFill = barFrame:CreateTexture(nil, "artwork")
    barFill:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", FILL_INSET, FILL_INSET)
    barFill:SetSize(0, 18)
    barFill:SetTexCoord(0, 1, 0, 1)
    barFill:SetHorizTile(false)
    barFill:SetVertTile(false)
    barFill:SetColorTexture(0.85, 0.2, 0.2, 0.95)

    -- Spark line
    barSpark = barFrame:CreateTexture(nil, "overlay")
    barSpark:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", FILL_INSET, FILL_INSET)
    barSpark:SetSize(2, 18)
    barSpark:SetColorTexture(1, 0.95, 0.75, 0.9)
    barSpark:SetDrawLayer("OVERLAY", 3)
    barSpark:Hide()

    -- Border frame
    local border = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    border:SetBackdropBorderColor(0.8, 0.2, 0.2, 0.85)
    barBorder = border

    -- Stage label (above)
    stageText = barFrame:CreateFontString(nil, "overlay", "GameFontNormal")
    stageText:SetPoint("BOTTOM", barFrame, "TOP", 0, 4)
    stageText:SetJustifyH("CENTER")
    stageText:SetText("Preydator")

    -- Suffix label (above, right)
    stageSuffixText = barFrame:CreateFontString(nil, "overlay", "GameFontNormal")
    stageSuffixText:SetPoint("BOTTOMRIGHT", barFrame, "TOPRIGHT", -2, 4)
    stageSuffixText:SetJustifyH("RIGHT")
    stageSuffixText:SetText("")
    stageSuffixText:Hide()

    -- Percent text (centered or positioned)
    barText = barFrame:CreateFontString(nil, "overlay", "GameFontHighlightSmall")
    barText:SetPoint("center", barFrame, "center", 0, 0)
    barText:SetDrawLayer("OVERLAY", 9)
    barText:SetText("0%")

    -- Center alignment dot (debug)
    barAlignmentDot = barFrame:CreateTexture(nil, "OVERLAY")
    barAlignmentDot:SetSize(6, 6)
    barAlignmentDot:SetColorTexture(0, 1, 0, 1)
    barAlignmentDot:SetPoint("CENTER", barFrame, "CENTER", 0, 0)
    barAlignmentDot:SetDrawLayer("OVERLAY", 7)
    barAlignmentDot:Hide()

    -- Tick marks (25% increments, max 4)
    for index = 1, 4 do
        local pct = index * 25
        local tickMark = barFrame:CreateTexture(nil, "overlay")
        tickMark:SetColorTexture(1, 1, 1, 0.35)
        tickMark:SetDrawLayer("OVERLAY", 4)
        barTickMarks[index] = tickMark

        local tickLabel = barFrame:CreateFontString(nil, "overlay", "GameFontHighlightSmall")
        tickLabel:SetDrawLayer("OVERLAY", 8)
        tickLabel:SetText(tostring(pct))
        barTickLabels[index] = tickLabel
    end

    -- Drag handling
    barFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not (IsAltKeyDown and IsAltKeyDown()) then
            self:StartMoving()
        end
    end)
    barFrame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
    end)
end

function PreyBarUIModule:IsEnabled()
    local customState = GetCustomizationState()
    if customState and type(customState.IsModuleEnabled) == "function" then
        return customState:IsModuleEnabled("bar") == true
    end
    return true
end

--------------------------------------------------------------------------------
-- Public API - Display Refresh
--------------------------------------------------------------------------------

function PreyBarUIModule:Refresh(state, settings)
    if not self:IsEnabled() then
        if barFrame then
            barFrame:Hide()
        end
        return
    end

    if not barFrame then
        self:EnsureBar()
    end

    if not state or not settings then
        return
    end

    local now = GetTime and GetTime() or 0
    local hasActiveQuest = tonumber(state.activeQuestID) ~= nil
    local forceKillStage = now < (tonumber(state.killStageUntil) or 0)
    local forceAmbushAlert = now < (tonumber(state.ambushAlertUntil) or 0)
    local isOutOfPreyZone = hasActiveQuest and state.inPreyZone ~= true
    local onlyShowInPreyZone = settings.onlyShowInPreyZone == true
    local editModePreview = settings.showInEditMode == true and IsEditModePreviewActive and IsEditModePreviewActive()
    local shouldShow = false

    -- Determine visibility
    if state.forceShowBar or forceKillStage or forceAmbushAlert or editModePreview then
        shouldShow = true
    elseif onlyShowInPreyZone then
        shouldShow = hasActiveQuest and not isOutOfPreyZone
    else
        shouldShow = true
    end

    if not shouldShow then
        barFrame:Hide()
        return
    end

    barFrame:Show()

    -- Determine display values
    local stage = forceKillStage and 4 or GetStageFromState(state.progressState)
    local pct = 0
    local displayReason = "default"
    
    if forceKillStage then
        pct = 100
        displayReason = "killStage"
    elseif editModePreview and not hasActiveQuest then
        pct = 0
        displayReason = "editModePreview"
    elseif not hasActiveQuest then
        pct = 0
        displayReason = "noActiveQuest"
    elseif isOutOfPreyZone then
        pct = 0
        displayReason = "outOfPreyZone"
    else
        if stage == 4 then
            pct = 100
        else
            pct = tonumber(state.progressPercent) or 0
            if stage >= 1 and pct <= 0 then
                pct = GetStageFallbackPercent(stage, settings.progressSegments)
            end
        end
        displayReason = "activeQuest"
    end

    pct = ClampPercent(pct)

    -- Update fill
    self:_UpdateFill(pct, settings)

    -- Update text labels
    local label = GetStageLabel(stage, settings)
    self:_UpdateLabels(label, state, pct, settings, forceAmbushAlert)

    -- Update ticks
    self:_UpdateTicks(settings)
end

function PreyBarUIModule:ApplyVisualStyle(settings)
    if not barFrame or not settings then
        return
    end

    -- Fill color and texture
    if barFill and settings.fillColor then
        local fill = settings.fillColor
        barFill:SetVertexColor(fill[1], fill[2], fill[3], fill[4])
    end
    if barFill and settings.textureKey then
        barFill:SetTexture(TEXTURE_PRESETS[settings.textureKey] or TEXTURE_PRESETS.default)
    end

    -- Background color
    if barFrame.BackgroundTexture and settings.backgroundColor then
        local bg = settings.backgroundColor
        barFrame.BackgroundTexture:SetColorTexture(bg[1], bg[2], bg[3], bg[4])
    end

    -- Border color
    if barBorder and barBorder.SetBackdropBorderColor then
        if settings.borderColorLinked == false and settings.borderColor then
            local bc = settings.borderColor
            barBorder:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 0.85)
        elseif settings.fillColor then
            local bc = settings.fillColor
            barBorder:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 0.85)
        end
    end

    -- Text colors
    if stageText and settings.titleColor then
        local tc = settings.titleColor
        stageText:SetTextColor(tc[1], tc[2], tc[3], tc[4])
    end
    if barText and settings.percentColor then
        local pc = settings.percentColor
        barText:SetTextColor(pc[1], pc[2], pc[3], pc[4])
    end
    if stageSuffixText and settings.titleColor then
        local tc = settings.titleColor
        stageSuffixText:SetTextColor(tc[1], tc[2], tc[3], tc[4])
    end

    -- Tick colors
    for _, tickMark in ipairs(barTickMarks) do
        if tickMark and settings.tickColor then
            local tc = settings.tickColor
            tickMark:SetColorTexture(tc[1], tc[2], tc[3], tc[4])
        end
    end
    for _, tickLabel in ipairs(barTickLabels) do
        if tickLabel and settings.tickColor then
            local tc = settings.tickColor
            tickLabel:SetTextColor(tc[1], tc[2], tc[3], tc[4])
        end
    end

    -- Fonts
    if settings.titleFontKey or settings.fontSize then
        local fontPath = FONT_PATHS[settings.titleFontKey] or FONT_PATHS.frizqt
        local fontSize = tonumber(settings.fontSize) or 14
        if stageText then
            stageText:SetFont(fontPath, fontSize, "")
        end
        if stageSuffixText then
            stageSuffixText:SetFont(fontPath, fontSize - 2, "")
        end
    end
    if settings.textFontKey or settings.fontSize then
        local fontPath = FONT_PATHS[settings.textFontKey] or FONT_PATHS.arialn
        local fontSize = tonumber(settings.fontSize) or 14
        if barText then
            barText:SetFont(fontPath, fontSize - 2, "")
        end
    end
end

function PreyBarUIModule:ApplyLayout(settings)
    if not barFrame or not settings then
        return
    end

    local width = tonumber(settings.width) or 160
    local height = tonumber(settings.height) or 20
    local scale = tonumber(settings.scale) or 1.0

    barFrame:SetSize(width, height)
    barFrame:SetScale(scale)

    self:_LayoutTicksAndLabels(settings)
    self:_LayoutTextElements(settings)
end

--------------------------------------------------------------------------------
-- Internal Layout Functions
--------------------------------------------------------------------------------

function PreyBarUIModule:_UpdateFill(pct, settings)
    if not barFill or not settings then
        return
    end

    local barWidth = barFrame:GetWidth() or settings.width or 160
    local barHeight = barFrame:GetHeight() or settings.height or 20
    local innerFillWidth = math.max(0, barWidth - 2 * FILL_INSET)
    local innerFillHeight = math.max(0, barHeight - 2 * FILL_INSET)
    local isVertical = settings.orientation == ORIENTATION_VERTICAL
    local shouldHideFill = (pct <= 0)

    if shouldHideFill then
        barFill:SetWidth(0)
        barFill:SetHeight(0)
        barFill:Hide()
        if barSpark then
            barSpark:Hide()
        end
        return
    end

    barFill:Show()
    barFill:ClearAllPoints()

    if isVertical then
        local height = innerFillHeight * (pct / 100)
        barFill:SetSize(math.max(1, innerFillWidth), math.max(1, height))
        if settings.verticalFillDirection == FILL_DIRECTION_DOWN then
            barFill:SetPoint("TOPLEFT", barFrame, "TOPLEFT", FILL_INSET, -FILL_INSET)
        else
            barFill:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", FILL_INSET, FILL_INSET)
        end
    else
        local width = innerFillWidth * (pct / 100)
        barFill:SetSize(math.max(1, width), math.max(1, innerFillHeight))
        barFill:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", FILL_INSET, FILL_INSET)
    end

    -- Update spark
    if barSpark and settings.showSparkLine then
        barSpark:Show()
        barSpark:ClearAllPoints()
        local sparkWidth = 2
        if isVertical then
            local sparkY
            if settings.verticalFillDirection == FILL_DIRECTION_DOWN then
                sparkY = barHeight - FILL_INSET - math.max(1, innerFillHeight * (pct / 100))
            else
                sparkY = FILL_INSET + math.max(0, innerFillHeight * (pct / 100) - sparkWidth)
            end
            if pct >= 100 and settings.verticalFillDirection == FILL_DIRECTION_DOWN then
                sparkY = FILL_INSET
            elseif pct >= 100 then
                sparkY = barHeight - FILL_INSET - sparkWidth
            end
            barSpark:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", FILL_INSET, sparkY)
        else
            local sparkX = FILL_INSET + math.max(0, innerFillWidth * (pct / 100) - sparkWidth)
            if pct >= 100 then
                sparkX = barWidth - FILL_INSET - sparkWidth
            end
            barSpark:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", sparkX, FILL_INSET)
        end
    elseif barSpark then
        barSpark:Hide()
    end
end

function PreyBarUIModule:_UpdateLabels(label, state, pct, settings, forceAmbushAlert)
    if not settings then
        return
    end

    local labelRowPosition = settings.labelRowPosition or LABEL_ROW_ABOVE
    local stageLabelMode = settings.stageLabelMode or LABEL_MODE_CENTER
    local centeredText = label
    local prefixText = (settings.stageSuffixLabels and settings.stageSuffixLabels[tonumber(state.stage)] or "")

    if forceAmbushAlert and settings.ambushCustomText then
        centeredText = settings.ambushCustomText
        prefixText = ""
    elseif labelRowPosition == LABEL_ROW_BELOW and stageLabelMode ~= LABEL_MODE_CENTER then
        if stageLabelMode == LABEL_MODE_LEFT or stageLabelMode == LABEL_MODE_LEFT_COMBINED then
            stageText:SetJustifyH("LEFT")
            centeredText = label
        elseif stageLabelMode == LABEL_MODE_LEFT_SUFFIX then
            stageText:SetJustifyH("LEFT")
            centeredText = ""
            prefixText = label
        elseif stageLabelMode == LABEL_MODE_RIGHT or stageLabelMode == LABEL_MODE_RIGHT_COMBINED then
            stageText:SetJustifyH("RIGHT")
            centeredText = label
        elseif stageLabelMode == LABEL_MODE_RIGHT_PREFIX then
            stageText:SetJustifyH("RIGHT")
            centeredText = ""
            prefixText = label
        end
    end

    if centeredText ~= "" then
        stageText:SetText(centeredText)
        stageText:Show()
    else
        stageText:SetText("")
        stageText:Hide()
    end

    if prefixText ~= "" then
        stageSuffixText:SetText(prefixText)
        stageSuffixText:Show()
    else
        stageSuffixText:SetText("")
        stageSuffixText:Hide()
    end

    -- Percent display
    barText:SetText(string.format("%d%%", pct))
    local percentDisplayMode = settings.percentDisplay or PERCENT_DISPLAY_INSIDE
    if settings.orientation == ORIENTATION_VERTICAL then
        percentDisplayMode = settings.verticalPercentDisplay or settings.percentDisplay or PERCENT_DISPLAY_INSIDE
    end

    if percentDisplayMode == PERCENT_DISPLAY_OFF then
        barText:Hide()
    elseif percentDisplayMode == PERCENT_DISPLAY_ABOVE_TICKS then
        barText:Hide()
    elseif percentDisplayMode == PERCENT_DISPLAY_BELOW_BAR then
        barText:Show()
        barText:ClearAllPoints()
        if settings.orientation == ORIENTATION_VERTICAL then
            barText:SetPoint("TOP", barFrame, "BOTTOM", 0, -math.max(2, tonumber(settings.verticalPercentOffset) or 10))
        else
            barText:SetPoint("TOP", barFrame, "BOTTOM", 0, -14)
        end
    elseif percentDisplayMode == PERCENT_DISPLAY_UNDER_TICKS then
        barText:Hide()
    else
        barText:Show()
        barText:ClearAllPoints()
        if settings.orientation == ORIENTATION_VERTICAL then
            barText:SetPoint("CENTER", barFrame, "CENTER", 0, 0)
            barText:SetDrawLayer("OVERLAY", 7)
        else
            barText:SetPoint("center", barFrame, "center", 0, 0)
        end
    end
end

function PreyBarUIModule:_UpdateTicks(settings)
    if not settings or not settings.showTicks then
        for _, tickMark in ipairs(barTickMarks) do
            if tickMark then tickMark:Hide() end
        end
        for _, tickLabel in ipairs(barTickLabels) do
            if tickLabel then tickLabel:Hide() end
        end
        return
    end

    self:_LayoutTicksAndLabels(settings)
end

function PreyBarUIModule:_LayoutTicksAndLabels(settings)
    if not settings or not barFrame then
        return
    end

    local width = barFrame:GetWidth() or settings.width or 160
    local height = barFrame:GetHeight() or settings.height or 20
    local isVertical = settings.orientation == ORIENTATION_VERTICAL

    if not settings.showTicks then
        for _, tm in ipairs(barTickMarks) do
            if tm then tm:Hide() end
        end
        for _, tl in ipairs(barTickLabels) do
            if tl then tl:Hide() end
        end
        return
    end

    for index = 1, 4 do
        local tickMark = barTickMarks[index]
        if not tickMark then break end

        local pct = index * 25
        if isVertical then
            local yPos
            if settings.verticalFillDirection == FILL_DIRECTION_DOWN then
                yPos = -FILL_INSET - (height * (pct / 100))
            else
                yPos = FILL_INSET + (height * (pct / 100))
            end
            tickMark:SetSize(width - 2 * FILL_INSET, 1)
            tickMark:SetPoint("TOPLEFT", barFrame, "TOPLEFT", FILL_INSET, yPos)
            tickMark:Show()

            local tickLabel = barTickLabels[index]
            if tickLabel then
                tickLabel:SetPoint("LEFT", tickMark, "RIGHT", 4, 0)
                tickLabel:Show()
            end
        else
            local xPos = FILL_INSET + (width * (pct / 100))
            tickMark:SetSize(1, height - 2 * FILL_INSET)
            tickMark:SetPoint("TOPLEFT", barFrame, "TOPLEFT", xPos, -FILL_INSET)
            tickMark:Show()

            local tickLabel = barTickLabels[index]
            if tickLabel then
                tickLabel:SetPoint("TOP", tickMark, "BOTTOM", 0, -2)
                tickLabel:Show()
            end
        end
    end
end

function PreyBarUIModule:_LayoutTextElements(settings)
    if not settings or not barFrame then
        return
    end

    local labelRowPosition = settings.labelRowPosition or LABEL_ROW_ABOVE
    local isVertical = settings.orientation == ORIENTATION_VERTICAL

    if labelRowPosition == LABEL_ROW_ABOVE or isVertical then
        stageText:SetPoint("BOTTOM", barFrame, "TOP", 0, 4)
    else
        stageText:SetPoint("TOP", barFrame, "BOTTOM", 0, -4)
    end

    if labelRowPosition == LABEL_ROW_ABOVE or isVertical then
        stageSuffixText:SetPoint("BOTTOMRIGHT", barFrame, "TOPRIGHT", -2, 4)
    else
        stageSuffixText:SetPoint("TOPRIGHT", barFrame, "BOTTOMRIGHT", -2, -4)
    end
end

--------------------------------------------------------------------------------
-- Public API - Frame Registry
--------------------------------------------------------------------------------

-- Called by Preydator.lua after its EnsureBar() creates the frame hierarchy.
-- Populates PreyBarUI's module-private frame references so GetBarFrame /
-- GetLabelFrames become the canonical source for all external consumers.
function PreyBarUIModule:RegisterBarFrames(frames)
    if type(frames) ~= "table" then return end
    if frames.barFrame        ~= nil then barFrame        = frames.barFrame        end
    if frames.barFill         ~= nil then barFill         = frames.barFill         end
    if frames.barSpark        ~= nil then barSpark        = frames.barSpark        end
    if frames.barBorder       ~= nil then barBorder       = frames.barBorder       end
    if frames.stageText       ~= nil then stageText       = frames.stageText       end
    if frames.stageSuffixText ~= nil then stageSuffixText = frames.stageSuffixText end
    if frames.barText         ~= nil then barText         = frames.barText         end
    if frames.barAlignmentDot ~= nil then barAlignmentDot = frames.barAlignmentDot end
    if frames.barTickMarks    ~= nil then barTickMarks    = frames.barTickMarks    end
    if frames.barTickLabels   ~= nil then barTickLabels   = frames.barTickLabels   end
end

--------------------------------------------------------------------------------
-- Public API - Frame Access
--------------------------------------------------------------------------------

function PreyBarUIModule:GetBarFrame()
    return barFrame or nil
end

function PreyBarUIModule:GetLabelFrames()
    return {
        prefix = stageText,
        suffix = stageSuffixText,
        percent = barText,
        centerDot = barAlignmentDot,
    }
end

function PreyBarUIModule:GetDebugState()
    local frames = self:GetLabelFrames()
    if not barFrame then
        return { initialized = false }
    end

    return {
        initialized = true,
        isVisible = barFrame:IsVisible(),
        width = barFrame:GetWidth(),
        height = barFrame:GetHeight(),
        scale = barFrame:GetScale(),
        points = { barFrame:GetPoint(1) },
    }
end
