---@diagnostic disable

local Preydator = _G.Preydator
if type(Preydator) ~= "table" or type(Preydator.RegisterModule) ~= "function" then
    return
end

local DiagnosticsModule = {}

function DiagnosticsModule:OnSlashCommand(text, rest)
    local api = Preydator.API
    if type(api) ~= "table" then
        return false
    end

    if text == "mem" or text == "memory" then
        if type(api.PrintMemoryUsage) == "function" then
            api.PrintMemoryUsage()
            return true
        end
        return false
    end

    if text ~= "debug" then
        return false
    end

    local mode = string.lower(rest or "")

    if mode == "on" then
        if type(api.SetDebugLoggingEnabled) == "function" then
            api.SetDebugLoggingEnabled(true)
        end
        print("Preydator: Debug logging enabled.")
        return true
    end

    if mode == "off" then
        if type(api.SetDebugLoggingEnabled) == "function" then
            api.SetDebugLoggingEnabled(false)
        end
        print("Preydator: Debug logging disabled.")
        return true
    end

    if mode == "clear" then
        if type(api.ClearDebugLog) == "function" then
            api.ClearDebugLog()
        end
        print("Preydator: Debug log cleared.")
        return true
    end

    if mode == "show" or mode == "" then
        if type(api.GetDebugTail) ~= "function" then
            return false
        end

        local tail, total = api.GetDebugTail(20)
        total = tonumber(total) or 0

        if total == 0 then
            print("Preydator: Debug log is empty.")
            return true
        end

        local shown = type(tail) == "table" and #tail or 0
        print("Preydator: Debug log (last " .. tostring(shown) .. " of " .. tostring(total) .. ")")

        if type(tail) == "table" then
            for _, entry in ipairs(tail) do
                print("  " .. tostring(entry))
            end
        end

        return true
    end

    print("Preydator: debug commands are 'debug on', 'debug off', 'debug show', 'debug clear'.")
    return true
end

Preydator:RegisterModule("Diagnostics", DiagnosticsModule)
