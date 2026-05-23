---@diagnostic disable
-- Prey hunt Blizzard widget mixin hook + snapshot cache. Loaded after ScriptDefer.lua in the TOC.
-- Initialization: Preydator installs runtime callbacks from OnAddonLoaded in Preydator.lua.

local Preydator = _G.Preydator
if type(Preydator) ~= "table" then
    return
end

local Enum = _G.Enum
local GetTime = _G.GetTime
local hooksecurefunc = _G.hooksecurefunc

local PreyWidgetRuntime = {}
PreyWidgetRuntime.name = "PreyWidgetRuntime"

local preyWidgetInfoCache = nil
local PREY_WIDGET_FRAMES = setmetatable({}, { __mode = "k" })
local preyHuntMixinHooked = false
local preyHuntIconFrame = nil

local ctx = nil

local function CoerceSanitizedNumber(value)
    local okString, asString = pcall(tostring, value)
    if not okString or type(asString) ~= "string" then
        return nil
    end

    local numericToken = string.match(asString, "^%s*([%+%-]?%d+%.?%d*)%s*$")
        or string.match(asString, "^%s*([%+%-]?%d*%.%d+)%s*$")
    if not numericToken then
        return nil
    end

    local okNumber, asNumber = pcall(tonumber, numericToken)
    if okNumber and type(asNumber) == "number" then
        return asNumber
    end

    return nil
end

local function IsPreyHuntProgressFrame(frameRef)
    if not frameRef then
        return false
    end
    return type(frameRef.ResetAnimState) == "function"
        and type(frameRef.AnimIn) == "function"
end

local function CaptureLivePreyHuntFrames()
    local container = _G.UIWidgetPowerBarContainerFrame
    if not container or not container.GetChildren then
        return
    end

    local okChildren, children = pcall(function()
        return { container:GetChildren() }
    end)
    if not okChildren or type(children) ~= "table" then
        return
    end

    for _, child in ipairs(children) do
        if IsPreyHuntProgressFrame(child) then
            PREY_WIDGET_FRAMES[child] = true
            preyHuntIconFrame = child
        end
    end
end

function PreyWidgetRuntime:TrackedWeakFrames()
    return PREY_WIDGET_FRAMES
end

function PreyWidgetRuntime:PrimaryIconFrame()
    return preyHuntIconFrame
end

function PreyWidgetRuntime:GetSnapshot()
    return preyWidgetInfoCache
end

function PreyWidgetRuntime:ClearSnapshot()
    preyWidgetInfoCache = nil
end

function PreyWidgetRuntime:IsAnyTrackedWidgetShown()
    if preyHuntIconFrame and preyHuntIconFrame.IsShown and preyHuntIconFrame:IsShown() then
        return true
    end

    for frameRef in pairs(PREY_WIDGET_FRAMES) do
        if frameRef and frameRef.IsShown and frameRef:IsShown() then
            return true
        end
    end

    return false
end

function PreyWidgetRuntime:CaptureLiveFrames()
    CaptureLivePreyHuntFrames()
end

function PreyWidgetRuntime:ExtractQuestID(info)
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
        local sanitized = CoerceSanitizedNumber(value)
        if sanitized ~= nil and sanitized > 0 then
            return math.floor(sanitized + 0.5)
        end
    end

    return nil
end

function PreyWidgetRuntime:FindProgressState(activeQuestID)
    local extractPct = ctx and ctx.extractProgressPercent
    local isQuest = ctx and ctx.isValidQuestID

    local info = preyWidgetInfoCache
    if not info then
        return nil, nil, nil, nil
    end

    local fallbackShown = (ctx and ctx.widgetShownFallthrough) or 1
    local shownStateShown = (Enum and Enum.WidgetShownState and Enum.WidgetShownState.Shown) or fallbackShown

    if info.shownState ~= nil and info.shownState ~= shownStateShown then
        return nil, nil, nil, nil
    end

    local tooltipLine = nil
    if type(info.tooltip) == "string" and info.tooltip ~= "" then
        tooltipLine = info.tooltip
    elseif type(info.barText) == "string" and info.barText ~= "" then
        tooltipLine = info.barText
    end

    local pct = type(extractPct) == "function" and extractPct(info, tooltipLine) or nil
    local ps = info.progressState

    if ps == nil and pct == nil then
        return nil, nil, nil, nil
    end

    local resolvedTooltipText = tooltipLine
    if type(isQuest) == "function" and isQuest(activeQuestID) then
        local widgetQuestID = self:ExtractQuestID(info)
        if widgetQuestID == activeQuestID or widgetQuestID == nil then
            return ps, resolvedTooltipText, pct, nil
        end
        return nil, nil, nil, nil
    end

    return ps, resolvedTooltipText, pct, nil
end

function PreyWidgetRuntime:EnsureMixinHook()
    if preyHuntMixinHooked then
        return
    end
    if type(ctx) ~= "table" then
        return
    end

    local mixin = _G.UIWidgetTemplatePreyHuntProgressMixin
    if not mixin or type(hooksecurefunc) ~= "function" then
        return
    end

    local ok = pcall(hooksecurefunc, mixin, "Setup", function(self, widgetInfo)
        preyHuntIconFrame = self
        PREY_WIDGET_FRAMES[self] = true
        if st then
            st.lastWidgetSetupAt = (GetTime and GetTime()) or 0
        end

        local shownState = nil
        local progressState = nil
        local tooltipText = nil
        local barTextSafe = nil
        local snapshotNumericFilled = false
        local captureSource = "none"
        local cacheBase = nil

        if type(widgetInfo) == "table" then
            shownState = CoerceSanitizedNumber(widgetInfo.shownState)
            progressState = CoerceSanitizedNumber(widgetInfo.progressState)
            local extractedQuestID = PreyWidgetRuntime:ExtractQuestID(widgetInfo)
            local widgetQuestID = CoerceSanitizedNumber(extractedQuestID)

            local isQuest = ctx.isValidQuestID
            if type(isQuest) == "function" and st then
                if isQuest(widgetQuestID) then
                    st.lastWidgetBoundQuestID = widgetQuestID
                elseif isQuest(st.activeQuestID) then
                    st.lastWidgetBoundQuestID = st.activeQuestID
                end
            end
            local okTip, rawTip = pcall(function()
                return widgetInfo.tooltip
            end)
            if okTip and type(rawTip) == "string" and rawTip ~= "" then
                tooltipText = rawTip
            end
            local okBt, rawBt = pcall(function()
                return widgetInfo.barText
            end)
            if okBt and type(rawBt) == "string" and rawBt ~= "" then
                barTextSafe = rawBt
            end

            cacheBase = {
                shownState = shownState,
                progressState = progressState,
                tooltip = tooltipText,
                barText = barTextSafe,
                questID = st and st.lastWidgetBoundQuestID,
                captureSource = captureSource,
                argType = type(widgetInfo),
            }
            if type(snapshotKeys) == "table" then
                for _, key in ipairs(snapshotKeys) do
                    local n = CoerceSanitizedNumber(widgetInfo[key])
                    if n ~= nil then
                        cacheBase[key] = n
                        snapshotNumericFilled = true
                    end
                end
            end

            if shownState ~= nil or progressState ~= nil or tooltipText ~= nil or barTextSafe ~= nil then
                captureSource = "widgetInfo"
            elseif snapshotNumericFilled then
                captureSource = "widgetInfo"
            end
            cacheBase.captureSource = captureSource
        end

        local hadWidgetCapture = type(cacheBase) == "table"
            and (snapshotNumericFilled
                or shownState ~= nil
                or progressState ~= nil
                or tooltipText ~= nil
                or barTextSafe ~= nil)

        if hadWidgetCapture then
            preyWidgetInfoCache = cacheBase
            if st then
                st.zoneCacheDirty = true
            end
        else
            preyWidgetInfoCache = nil
        end

        local function DeferredPostSetup()
            local ub = ctx.updateBarDisplay
            if hadWidgetCapture and type(ub) == "function" then
                ub()
            end
            local set = ctx.getSettings and ctx.getSettings()
            local applySuppress = ctx.applyWidgetFrameSuppression
            if set and set.disableDefaultPreyIcon == true and type(applySuppress) == "function" then
                applySuppress(self, true)
                if self.IsShown and self:IsShown()
                    and type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown()
                    and st
                then
                    st.pendingWidgetSuppressionAfterCombat = true
                end
            end
        end

        if type(Preydator.RunAfterCurrentScriptsPass) == "function" then
            Preydator.RunAfterCurrentScriptsPass(DeferredPostSetup)
        else
            DeferredPostSetup()
        end
    end)

    if ok then
        preyHuntMixinHooked = true
        CaptureLivePreyHuntFrames()
    end
end

function PreyWidgetRuntime:Install(instCtx)
    ctx = instCtx
end

Preydator:RegisterModule("PreyWidgetRuntime", PreyWidgetRuntime)
