local _, ns = ...

local function printMessage(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff9482c9123|r: " .. message)
    end
end

ns.Print = printMessage

BINDING_NAME_ONETWOTHREE_TOGGLE = "Show or hide the 123 bar"

function OneTwoThree_Toggle()
    if ns.Bar then
        ns.Bar:Toggle()
    end
end

local function valueToText(value)
    if not ns.API.Readable(value) then
        return "<secret>"
    end
    return tostring(value)
end

local function printDebugState()
    printMessage("build " .. valueToText(ns.API.ClientBuild()) .. ", combat=" .. valueToText(InCombatLockdown())
        .. ", loads=" .. valueToText(ns.db.loadCount)
        .. ", glass=" .. (ns.Skin:Glass() and "LibGlass" or "fallback"))
    if #ns.API.eventFailures > 0 then
        printMessage("events refused: " .. table.concat(ns.API.eventFailures, ", "))
    end
end

local function registerSlashCommands()
    -- "/123" is tried after the chat channel parser, which falls through
    -- when no channel 123 exists; /onetwothree always works.
    SLASH_ONETWOTHREE1 = "/123"
    SLASH_ONETWOTHREE2 = "/onetwothree"

    SlashCmdList.ONETWOTHREE = function(commandText)
        local cmd = string.lower((commandText or ""):match("^%s*(%S*)"))
        if cmd == "debug" then
            local ok, err = pcall(printDebugState)
            if not ok then
                printMessage("debug failed: " .. tostring(err))
            end
        elseif cmd == "" then
            ns.Bar:Toggle()
        else
            printMessage("/123 | debug")
        end
    end
end

ns.Events:Register("PLAYER_LOGIN", function()
    ns.DB:Initialize()

    ns.isWarlock = ns.API.PlayerClass() == ns.Constants.CLASS_WARLOCK
    if not ns.isWarlock then
        return
    end

    ns.Bar:Initialize()
    registerSlashCommands()
end)
