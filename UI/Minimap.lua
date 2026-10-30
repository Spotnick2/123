-- The minimap button (LibDataBroker launcher shown by LibDBIcon, vendored in
-- Libs\) and the Addon Compartment entry (#15), as in Portal Roulette.
-- db.minimap = { minimapPos, hide } belongs to LibDBIcon.

local _, ns = ...
if ns.skip then return end

local Minimap = {}
ns.Minimap = Minimap

local NAME = "OneTwoThree"
local TITLE = "123"
local L = ns.L

local function onClick(_, mouseButton)
    if mouseButton == "RightButton" then
        ns.Options:Open()
    elseif IsShiftKeyDown() then
        ns.Bar:Toggle()
    else
        ns.Wheel:Toggle()
    end
end

local function onTooltip(tooltip)
    tooltip:AddLine(TITLE, ns.Colors.ACCENT[1], ns.Colors.ACCENT[2], ns.Colors.ACCENT[3])
    tooltip:AddLine(L["Click: the demon wheel"], 1, 1, 1)
    tooltip:AddLine(L["Shift-click: show or hide the bar"], 1, 1, 1)
    tooltip:AddLine(L["Right-click: options"], 1, 1, 1)
end

function Minimap:Initialize()
    local icon = ns.API.SpellIcon(ns.Data.RITUAL_OF_SUMMONING)
    local LDB = LibStub("LibDataBroker-1.1", true)
    local DBIcon = LibStub("LibDBIcon-1.0", true)
    if LDB and DBIcon and not self.object then
        self.object = LDB:NewDataObject(NAME, {
            type = "launcher",
            text = TITLE,
            icon = icon,
            OnClick = onClick,
            OnTooltipShow = onTooltip,
        })
        DBIcon:Register(NAME, self.object, ns.db.minimap)
        self.icon = DBIcon
    end

    if ns.db.showCompartment and AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon
        and not self.compartment then
        self.compartment = pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
            text = TITLE,
            icon = icon,
            notCheckable = true,
            -- The menu calls func(data, menuInputData, menu): the mouse
            -- button is menuInputData.buttonName (Blizzard_Minimap
            -- AddonCompartment.lua, Codex on #32).
            func = function(_, menuInputData)
                onClick(nil, type(menuInputData) == "table" and menuInputData.buttonName or nil)
            end,
            funcOnEnter = function(button)
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                onTooltip(GameTooltip)
                GameTooltip:Show()
            end,
            funcOnLeave = function() GameTooltip:Hide() end,
        })
    end
    self:RefreshVisibility()
end

function Minimap:RefreshVisibility()
    if not self.icon then return end
    ns.db.minimap.hide = not ns.db.showMinimapButton
    if ns.db.minimap.hide then
        self.icon:Hide(NAME)
    else
        self.icon:Show(NAME)
    end
end
