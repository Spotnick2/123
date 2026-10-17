local _, ns = ...
if ns.skip then return end

local function printMessage(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff9482c9123|r: " .. message)
    end
end

ns.Print = printMessage

BINDING_NAME_ONETWOTHREE_TOGGLE = "Show or hide the 123 bar"
BINDING_NAME_ONETWOTHREE_WHEEL = "Open or close the demon wheel"
-- Keys that click the bar's secure buttons (they cast, in combat too).
_G["BINDING_NAME_CLICK OneTwoThreeBarButton1:LeftButton"] = "Summon the last demon"
_G["BINDING_NAME_CLICK OneTwoThreeBarButton1:RightButton"] = "Demonic Sacrifice, or summon the last demon"
_G["BINDING_NAME_CLICK OneTwoThreeBarButton2:LeftButton"] = "Armor"
_G["BINDING_NAME_CLICK OneTwoThreeBarButton3:LeftButton"] = "Soulstone"
_G["BINDING_NAME_CLICK OneTwoThreeBarButton4:LeftButton"] = "Healthstone"
_G["BINDING_NAME_CLICK OneTwoThreeBarButton5:LeftButton"] = "Ritual of Summoning"

function OneTwoThree_Wheel()
    if ns.Wheel and ns.isWarlock then
        ns.Wheel:Toggle()
    end
end

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
    for _, button in ipairs(ns.Bar.buttons or {}) do
        local action = button.action
        printMessage(button.key .. ": " .. (action and (action.type .. " " .. (action.itemID or action.spellID)) or "nothing armed")
            .. (ns.SecureAction.HasAction(button) and "" or " (no attributes)"))
    end
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
        elseif cmd == "preview" then
            ns.Wheel:SetPreview(not ns.Wheel.preview)
        elseif cmd == "options" or cmd == "config" then
            ns.Options:Open()
        elseif cmd == "queue" then
            local sub = string.lower((commandText or ""):match("^%s*%S+%s+(%S*)") or "")
            if sub == "test" then
                printMessage(ns.Queue:Test() .. " test requests joined the summon queue (\"1234\" didn't match).")
            elseif sub == "clear" then
                ns.Queue:Clear()
            else
                printMessage(#ns.Queue.entries .. " waiting. /123 queue test | clear")
            end
        elseif cmd == "wheel" then
            ns.Wheel:Toggle()
        elseif cmd == "labels" then
            if InCombatLockdown() then
                printMessage("the bar can't change in combat.")
            else
                ns.db.barLabels = not ns.db.barLabels
                ns.Bar:ApplyLabels()
            end
        elseif cmd == "sounds" then
            ns.db.sounds = not ns.db.sounds
            printMessage(ns.db.sounds and "demon voices on." or "demon voices off.")
        elseif cmd == "camera" then
            local on = not ns.db.cinematicCamera
            ns.db.cinematicCamera, ns.db.hideGameUI = on, on
            printMessage(on and "the demon wheel opens with the cinematic camera and hides the game UI."
                or "the demon wheel opens over the game, no camera.")
        elseif cmd == "confirm" then
            ns.db.confirmResummon = not ns.db.confirmResummon
            printMessage(ns.db.confirmResummon and "will ask before re-summoning the demon that is out."
                or "won't ask before re-summoning the demon that is out.")
            ns.SecureAction.MarkDirty()
        elseif cmd == "" then
            ns.Bar:Toggle()
        else
            printMessage("/123 | options | queue (test, clear) | wheel | preview (every demon, nothing cast) | camera (cinematic opening) | sounds (demon voices) | labels (names under the icons) | confirm (ask before re-summoning) | debug")
        end
    end
end

ns.Events:Register("PLAYER_LOGIN", function()
    ns.DB:Initialize()

    ns.isWarlock = ns.API.PlayerClass() == ns.Constants.CLASS_WARLOCK
    if not ns.isWarlock then
        return
    end

    ns.SecureAction.Initialize()
    ns.Bar:Initialize()
    ns.Wheel:Initialize()
    ns.Queue:Initialize()
    ns.QueueList:Initialize()
    ns.Minimap:Initialize()
    ns.Options:Register()
    registerSlashCommands()
end)
