-- Runs callbacks after the current script/event stack unwinds, typically still the
-- same frame as UPDATE_UI_WIDGET (before draw). C_Timer.After(0) waits until next
-- frame and can let GameTooltip widget layouts visibly jump.
-- Loaded immediately after Preydator.lua in the TOC.

local Preydator = _G.Preydator
if type(Preydator) ~= "table" then
    return
end
local CreateFrame = _G.CreateFrame

do
    local afterScriptsFrame = CreateFrame("Frame")
    afterScriptsFrame:Hide()
    local afterScriptsQueue = {}

    Preydator.RunAfterCurrentScriptsPass = function(fn)
        if type(fn) ~= "function" then
            return
        end
        afterScriptsQueue[#afterScriptsQueue + 1] = fn
        afterScriptsFrame:SetScript("OnUpdate", function(self)
            self:SetScript("OnUpdate", nil)
            local q = afterScriptsQueue
            afterScriptsQueue = {}
            for i = 1, #q do
                q[i]()
            end
        end)
    end
end
