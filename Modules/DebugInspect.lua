---@diagnostic disable

local Preydator = _G.Preydator
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local C_QuestLog = _G.C_QuestLog
local C_Map = _G.C_Map
local geterrorhandler = _G.geterrorhandler
local GetTime = _G.GetTime
local GetZoneText = _G.GetZoneText

local function SendToErrorHandler(reportText)
    if type(reportText) ~= "string" or reportText == "" then
        return false, "empty report"
    end

    if type(geterrorhandler) ~= "function" then
        return false, "geterrorhandler unavailable"
    end

    local okHandler, handler = pcall(geterrorhandler)
    if not okHandler or type(handler) ~= "function" then
        return false, "error handler unavailable"
    end

    local header = "Preydator Inspect Report"
    local chunkSize = 1800
    local length = #reportText
    local chunks = math.max(1, math.ceil(length / chunkSize))
    for index = 1, chunks do
        local startPos = ((index - 1) * chunkSize) + 1
        local endPos = math.min(index * chunkSize, length)
        local chunk = string.sub(reportText, startPos, endPos)
        local okSend = pcall(handler, string.format("%s [%d/%d]\n%s", header, index, chunks, chunk))

        if not okSend then
            return false, "handler failed on chunk " .. tostring(index)
        end
    end

    return true, "sent"
end

local function BuildInspectReport()
    local lines = {}
    local function add(line)
        lines[#lines + 1] = tostring(line or "")
    end

    local state = (type(Preydator.GetState) == "function") and Preydator.GetState() or {}
    local settings = (type(Preydator.GetSettings) == "function") and Preydator.GetSettings() or {}
    local barFrame = (type(Preydator.GetBarFrame) == "function") and Preydator.GetBarFrame() or nil
    local labelFrames = (type(Preydator.GetLabelFrames) == "function") and Preydator.GetLabelFrames() or nil

    local function FormatPoint(frameRef)
        if not frameRef or not frameRef.GetPoint then
            return "<no-frame>"
        end

        local ok, point, relativeTo, relativePoint, xOfs, yOfs = pcall(frameRef.GetPoint, frameRef, 1)
        if not ok then
            return "<point-error>"
        end

        local relName = "<nil>"
        if relativeTo and relativeTo.GetName then
            relName = relativeTo:GetName() or "<unnamed>"
        end

        return string.format("%s -> %s:%s (%s,%s)", tostring(point), tostring(relName), tostring(relativePoint), tostring(xOfs), tostring(yOfs))
    end

    local liveQuestID = (C_QuestLog and C_QuestLog.GetActivePreyQuest) and C_QuestLog.GetActivePreyQuest() or nil
    local hasActiveQuest = type(liveQuestID) == "number" and liveQuestID > 0
    local now = GetTime and GetTime() or 0

    local playerMapID = (C_Map and C_Map.GetBestMapForUnit) and C_Map.GetBestMapForUnit("player") or nil
    local playerMapName = nil
    if playerMapID and C_Map and C_Map.GetMapInfo then
        local mapInfo = C_Map.GetMapInfo(playerMapID)
        playerMapName = mapInfo and mapInfo.name or nil
    end

    add("Preydator Inspect (module)")
    add("- time=" .. string.format("%.3f", now) .. " | zone=" .. tostring(GetZoneText and GetZoneText() or "?") .. " | playerMapID=" .. tostring(playerMapID) .. " | playerMap=" .. tostring(playerMapName))
    add("- quest live=" .. tostring(liveQuestID) .. " | hasActive=" .. tostring(hasActiveQuest) .. " | tracked=" .. tostring(state.activeQuestID))
    add("- state stage=" .. tostring(state.stage) .. " | progressState=" .. tostring(state.progressState) .. " | progressPercent=" .. tostring(state.progressPercent))
    add("- inPreyZone=" .. tostring(state.inPreyZone) .. " | disableDefaultPreyIcon=" .. tostring(settings and settings.disableDefaultPreyIcon == true))
    add("- settings size width=" .. tostring(settings and settings.width)
        .. " | height=" .. tostring(settings and settings.height)
        .. " | scale=" .. tostring(settings and settings.scale))
    add("- settings layout"
        .. " | orientation=" .. tostring(settings and settings.orientation)
        .. " | fillDir=" .. tostring(settings and settings.verticalFillDirection)
        .. " | labelMode=" .. tostring(settings and settings.stageLabelMode)
        .. " | labelRow=" .. tostring(settings and settings.labelRowPosition)
        .. " | vTextAlign=" .. tostring(settings and settings.verticalTextAlign)
        .. " | vTextSide=" .. tostring(settings and settings.verticalTextSide)
        .. " | vTextOffset=" .. tostring(settings and settings.verticalTextOffset)
        .. " | vPctDisplay=" .. tostring(settings and settings.verticalPercentDisplay)
        .. " | vPctSide=" .. tostring(settings and settings.verticalPercentSide)
        .. " | vPctOffset=" .. tostring(settings and settings.verticalPercentOffset))

    if barFrame then
        local liveWidth = barFrame.GetWidth and barFrame:GetWidth() or "?"
        local liveHeight = barFrame.GetHeight and barFrame:GetHeight() or "?"
        local liveScale = barFrame.GetScale and barFrame:GetScale() or "?"
        local liveEffectiveScale = barFrame.GetEffectiveScale and barFrame:GetEffectiveScale() or "?"
        add("- bar shown=" .. tostring(barFrame.IsShown and barFrame:IsShown() or false)
            .. " | mouse=" .. tostring(barFrame.IsMouseEnabled and barFrame:IsMouseEnabled() or false)
            .. " | width=" .. tostring(liveWidth)
            .. " | height=" .. tostring(liveHeight)
            .. " | scale=" .. tostring(liveScale)
            .. " | effectiveScale=" .. tostring(liveEffectiveScale))
    else
        add("- bar frame unavailable")
    end

    if type(labelFrames) == "table" then
        local prefix = labelFrames.prefix
        local suffix = labelFrames.suffix
        local percent = labelFrames.percent
        local centerDot = labelFrames.centerDot

        add("- prefix"
            .. " | shown=" .. tostring(prefix and prefix.IsShown and prefix:IsShown() or false)
            .. " | text='" .. tostring(prefix and prefix.GetText and prefix:GetText() or "") .. "'"
            .. " | point=" .. FormatPoint(prefix))
        add("- suffix"
            .. " | shown=" .. tostring(suffix and suffix.IsShown and suffix:IsShown() or false)
            .. " | text='" .. tostring(suffix and suffix.GetText and suffix:GetText() or "") .. "'"
            .. " | point=" .. FormatPoint(suffix))
        add("- percent"
            .. " | shown=" .. tostring(percent and percent.IsShown and percent:IsShown() or false)
            .. " | text='" .. tostring(percent and percent.GetText and percent:GetText() or "") .. "'"
            .. " | point=" .. FormatPoint(percent))
        add("- centerDot"
            .. " | enabledSetting=" .. tostring(settings and settings.showAlignmentDot == true)
            .. " | shown=" .. tostring(centerDot and centerDot.IsShown and centerDot:IsShown() or false)
            .. " | point=" .. FormatPoint(centerDot))
    end

    local reportText = table.concat(lines, "\n")
    _G.PreydatorLastInspectReport = reportText
    return lines, reportText
end

local DebugInspectModule = {}

function DebugInspectModule:OnSlashCommand(text, rest)
    if text ~= "inspect" and text ~= "inspectbug" and text ~= "inspectbugsack" and text ~= "inspectboth" then
        return false
    end

    local mode = "chat"
    if text == "inspectbug" or text == "inspectbugsack" then
        mode = "bugsack"
    elseif text == "inspectboth" then
        mode = "both"
    else
        local inspectMode = string.lower((rest or ""):match("^%s*(.-)%s*$"))
        if inspectMode == "bug" or inspectMode == "bugsack" then
            mode = "bugsack"
        elseif inspectMode == "both" then
            mode = "both"
        end
    end

    local lines, reportText = BuildInspectReport()

    if mode == "chat" or mode == "both" then
        for _, line in ipairs(lines) do
            print(line)
        end
    end

    if mode == "bugsack" or mode == "both" then
        local sent, reason = SendToErrorHandler(reportText)
        if sent then
            print("Preydator: Inspect report sent to BugSack via error handler (debug module).")
        else
            print("Preydator: Could not send inspect report to BugSack: " .. tostring(reason))
        end
    end

    print("Preydator: Inspect report cached in PreydatorLastInspectReport (debug module).")
    return true
end

Preydator:RegisterModule("DebugInspect", DebugInspectModule)
