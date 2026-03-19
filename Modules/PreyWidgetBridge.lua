---@diagnostic disable

--[[
    Preydator: PreyWidgetBridge
    Centralizes all widget detection, frame discovery, and state extraction.
    
    Ownership:
    - Widget state queries (progressState, progressPercent, tooltip)
    - Widget availability checks
    - Widget frame discovery and caching
    - Widget quest ID extraction
    - Widget aging tracking (lastWidgetSeenAt)
    
    Does NOT own:
    - Event registration (core event loop in Preydator.lua)
    - Bar rendering (delegated to PreyBarUI/Preydator.lua)
    - Icon suppression UI logic (stays in Preydator.lua)
    - Polling control (ShouldUseActivePolling in core)
]]

local _, addonTable = ...
local Preydator = _G.Preydator or addonTable
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local PreyWidgetBridgeModule = {}
Preydator:RegisterModule("PreyWidgetBridge", PreyWidgetBridgeModule)

local C_UIWidgetManager = _G.C_UIWidgetManager
local GetTime = _G.GetTime
local type = _G.type
local tonumber = _G.tonumber
local tostring = _G.tostring
local pairs = _G.pairs
local ipairs = _G.ipairs

--------------------------------------------------------------------------------
-- Module State
--------------------------------------------------------------------------------

-- Cache of discovered widget frames by widgetID
local widgetFrameCache = {}

-- Cached constants from C_UIWidgetManager (or fallback literals)
local widgetTypeConstant = nil
local shownStateConstant = nil

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function LazyInitializeConstants()
    if widgetTypeConstant ~= nil then
        return
    end

    -- Try to fetch widget type enum
    if C_UIWidgetManager and type(C_UIWidgetManager.WidgetType) == "table" then
        widgetTypeConstant = C_UIWidgetManager.WidgetType.PreyHuntProgress or 31
    else
        widgetTypeConstant = 31
    end

    -- Try to fetch shown state enum
    if C_UIWidgetManager and type(C_UIWidgetManager.WidgetShownState) == "table" then
        shownStateConstant = C_UIWidgetManager.WidgetShownState.Shown or 1
    else
        shownStateConstant = 1
    end
end

local function IsWardbandEnabled()
    local customization = Preydator.GetModule and Preydator:GetModule("CustomizationStateV2")
    if not customization or type(customization.IsModuleEnabled) ~= "function" then
        return true
    end
    return customization:IsModuleEnabled("warband")
end

--------------------------------------------------------------------------------
-- Public API - Widget Availability
--------------------------------------------------------------------------------

function PreyWidgetBridgeModule:IsWidgetAvailable()
    if not C_UIWidgetManager then
        return false
    end
    if type(C_UIWidgetManager.GetWidgetInfoByConditionID) ~= "function" then
        return false
    end
    return true
end

function PreyWidgetBridgeModule:GetWidgetTypePreyHuntProgress()
    LazyInitializeConstants()
    return widgetTypeConstant
end

function PreyWidgetBridgeModule:GetShownStateShown()
    LazyInitializeConstants()
    return shownStateConstant
end

--------------------------------------------------------------------------------
-- Public API - Widget State Detection
--------------------------------------------------------------------------------

-- Returns (progressState, tooltip, progressPercent) for active prey hunt widget
-- or (nil, nil, nil) if widget unavailable
-- progressState: 0 (Discovery), 1 (Tracking), 2 (Engage), 3 (Final)
function PreyWidgetBridgeModule:GetWidgetState(questID)
    if not self:IsWidgetAvailable() then
        return nil, nil, nil
    end

    if not questID or type(questID) ~= "number" or questID < 1 then
        return nil, nil, nil
    end

    LazyInitializeConstants()

    local widgetType = widgetTypeConstant
    local ok, widgetInfo = pcall(C_UIWidgetManager.GetWidgetInfoByConditionID, widgetType, questID)
    if not ok or type(widgetInfo) ~= "table" then
        return nil, nil, nil
    end

    -- Widget may be hidden; skip if not shown
    if widgetInfo.shownState ~= shownStateConstant then
        return nil, nil, nil
    end

    -- Extract fields with safe defaults
    local progressState = tonumber(widgetInfo.progressState)
    local progressPercent = tonumber(widgetInfo.progressPercent) or 0
    local tooltip = tostring(widgetInfo.tooltip or "")

    -- Clamp percent to 0-100
    if progressPercent < 0 then progressPercent = 0 end
    if progressPercent > 100 then progressPercent = 100 end

    return progressState, tooltip, progressPercent
end

-------------------------------------------------------------------------------
-- Public API - Widget Quest Matching
--------------------------------------------------------------------------------

-- Extracts questID from widget info table (handles variant field names)
function PreyWidgetBridgeModule:ExtractWidgetQuestID(widgetInfo)
    if type(widgetInfo) ~= "table" then
        return nil
    end

    -- Try fields in order of likelihood
    if widgetInfo.questID ~= nil then
        return tonumber(widgetInfo.questID)
    end
    if widgetInfo.questId ~= nil then
        return tonumber(widgetInfo.questId)
    end
    if widgetInfo.associatedQuestID ~= nil then
        return tonumber(widgetInfo.associatedQuestID)
    end

    return nil
end

--------------------------------------------------------------------------------
-- Public API - Widget Frame Discovery
--------------------------------------------------------------------------------

-- Widget container frame names (localized in one place)
function PreyWidgetBridgeModule:GetCandidateWidgetSetIDs()
    return {
        "UIWidgetTopCenterContainerFrame",
        "UIWidgetObjectiveTrackerContainerFrame",
        "UIWidgetBelowMinimapContainerFrame",
        "UIWidgetPowerBarContainerFrame",
    }
end

-- Scans global frame hierarchy to locate widget frame objects
-- Caches results so subsequent lookups are O(1)
function PreyWidgetBridgeModule:FindGlobalFramesForWidgetID(widgetID)
    if type(widgetID) ~= "number" or widgetID < 1 then
        return {}
    end

    -- Check cache first
    if widgetFrameCache[widgetID] then
        return widgetFrameCache[widgetID]
    end

    local results = {}
    local maxDepth = 6
    local guardCount = 0

    local function ScanFrameHierarchy(parent, depth)
        guardCount = guardCount + 1
        if guardCount > 1000 then
            return
        end

        if not parent or depth > maxDepth then
            return
        end

        if type(parent.GetID) == "function" then
            local frameID = parent:GetID()
            if frameID == widgetID then
                results[#results + 1] = parent
            end
        end

        if type(parent.GetNumChildren) == "function" then
            local numChildren = parent:GetNumChildren()
            for i = 1, numChildren do
                local child = select(i, parent:GetChildren())
                if child then
                    ScanFrameHierarchy(child, depth + 1)
                end
            end
        end
    end

    -- Scan each candidate container
    local candidates = self:GetCandidateWidgetSetIDs()
    for _, containerName in ipairs(candidates) do
        local container = _G[containerName]
        if container then
            ScanFrameHierarchy(container, 0)
        end
    end

    -- Cache results for future calls
    widgetFrameCache[widgetID] = results
    return results
end

--------------------------------------------------------------------------------
-- Public API - Widget Aging
--------------------------------------------------------------------------------

-- Updates state.lastWidgetSeenAt to mark when widget was last detected
function PreyWidgetBridgeModule:MarkWidgetSeen(state, capturedAt)
    if type(state) ~= "table" then
        return
    end

    local timestamp = tonumber(capturedAt)
    if not timestamp or timestamp <= 0 then
        timestamp = GetTime and GetTime() or 0
    end

    state.lastWidgetSeenAt = timestamp
end

--------------------------------------------------------------------------------
-- Public API - Fallback to PreyRuntime
--------------------------------------------------------------------------------

-- Fallback widget state detection if this module's query fails
-- Delegates to PreyRuntime.FindPreyWidgetProgressState for redundancy
function PreyWidgetBridgeModule:GetWidgetStateFallback(questID)
    local runtime = Preydator.GetModule and Preydator:GetModule("PreyRuntime")
    if not runtime or type(runtime.FindPreyWidgetProgressState) ~= "function" then
        return nil, nil, nil
    end

    local ok, progressState, tooltip, progressPercent = pcall(runtime.FindPreyWidgetProgressState, runtime, questID)
    if ok then
        return progressState, tooltip, progressPercent
    end

    return nil, nil, nil
end

--------------------------------------------------------------------------------
-- Module Lifecycle
--------------------------------------------------------------------------------

function PreyWidgetBridgeModule:OnAddonLoaded()
    LazyInitializeConstants()
end

function PreyWidgetBridgeModule:OnDisable()
    if not IsWardbandEnabled() then
        -- Clear widget frame cache on warband disable
        widgetFrameCache = {}
    end
end

function PreyWidgetBridgeModule:GetDebugState()
    return {
        available = self:IsWidgetAvailable(),
        widgetType = self:GetWidgetTypePreyHuntProgress(),
        shownState = self:GetShownStateShown(),
        frameCacheSize = #widgetFrameCache,
    }
end
