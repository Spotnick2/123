-- Soulstone target (#5): the Soulstone button's right click opens a picker;
-- a carried soulstone then goes to the one picked (a secure unit1), out of
-- combat only; someone who leaves the group is cleared, never retargeted.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

WoW.spells[693] = { name = "Create Soulstone (Minor)", known = true }
WoW.items[5232] = "Minor Soulstone"
WoW.counts[6265] = 3
WoW.inGroup = true
local ASHKA, BROM = "Player-1-AAA", "Player-1-BBB"
WoW.group = {
    { guid = ASHKA, name = "Ashka Vale", class = "MAGE" },
    { guid = BROM, name = "Brom Hollow", class = "WARRIOR" },
}
local ns = H.loadAddon()
local Bar, Picker, Target = ns.Bar, ns.SoulPicker, ns.SoulTarget
local ss = Bar:Button("soulstone")

local function armed()
    return ss:GetAttribute("type1"), ss:GetAttribute("item1") or ss:GetAttribute("spell1"), ss:GetAttribute("unit1")
end
local function rightClick()
    ss:GetScript("PostClick")(ss, "RightButton", true)
    ss:GetScript("PostClick")(ss, "RightButton", false)
end
local function pick(name)
    for _, row in ipairs(Picker.rows) do
        if row:IsShown() and row.text:GetText():find(name, 1, true) then
            row:GetScript("OnClick")(row)
            WoW.advance(0)
            return true
        end
    end
    return false
end
local function update()
    WoW.fire("BAG_UPDATE_DELAYED")
    WoW.advance(0)
end

-- No stone carried: the left click creates one, the right one is unarmed.
local t, v, u = armed()
eq(v, 693, "no soulstone carried: create one")
eq(ss:GetAttribute("type2"), nil, "the right click is unarmed")

-- The right click (its up edge only) opens the picker: you, then the group.
rightClick()
check(Picker:IsShown(), "the right click opens the picker")
eq(Picker.rows[1].text:GetText(), "Testcase Surname", "you first")
eq(Picker.rows[2].text:GetText(), "Ashka Vale", "then the group")
eq(Picker.rows[3].text:GetText(), "Brom Hollow", "in order")
check(not (Picker.rows[4] and Picker.rows[4]:IsShown()), "no Clear before anyone is picked")
local p = Picker.frame._points[1]
check(p and p[1] == "BOTTOM" and p[2] == UIParent, "above the Soulstone button, under UIParent")
check(UISpecialFrames[#UISpecialFrames] == "OneTwoThreeSoulPicker", "Escape closes it")

-- Picking Ashka: saved on her GUID; creating a stone has no target.
check(pick("Ashka"), "Ashka is in the list")
check(not Picker:IsShown(), "picking closes it")
eq(Target:Get().guid, ASHKA, "saved on her GUID")
eq(ns.char.soulTarget.name, "Ashka Vale", "per character")
eq(select(3, armed()), nil, "creating a stone: no target")
eq(ss.target:GetText(), "Ashka", "her first name on the icon")
eq(ss.target._textColor[1], 0.6, "grey while it doesn't go to her")

-- A soulstone in the bags: it goes to her.
WoW.counts[5232] = 1
update()
t, v, u = armed()
eq(v, "item:5232", "a carried soulstone is used")
eq(u, "party1", "on Ashka")
check(ss.target._textColor[1] ~= 0.6, "her name in class colour once it does")
ss:GetScript("OnEnter")(ss)
local lines = table.concat(GameTooltip._lines, "\n")
check(lines:find("Click: Use Minor Soulstone on Ashka Vale", 1, true) ~= nil, "the tooltip says on whom")
check(lines:find("Right-click: choose who gets it", 1, true) ~= nil, "and how to change it")

-- A reshuffle: the button follows her GUID to her new token at once.
WoW.group = { WoW.group[2], WoW.group[1] }
WoW.fire("GROUP_ROSTER_UPDATE")
eq(select(3, armed()), "party2", "she is party2 now: so is the stone's target")

-- Combat: the token comes off as it starts (it can't be rewritten there),
-- even when a count turns unreadable and the button keeps its stone.
WoW.counts[5232] = WoW.Secret("stack count")
WoW.enterCombat()
t, v, u = armed()
eq(v, "item:5232", "in combat: still the stone")
eq(u, nil, "on the target, never a token")
ss:GetScript("OnEnter")(ss)
lines = table.concat(GameTooltip._lines, "\n")
check(lines:find("Ashka Vale: in combat, on your target", 1, true) ~= nil, "the tooltip says so")
WoW.group = { WoW.group[2], WoW.group[1] }
WoW.fire("GROUP_ROSTER_UPDATE")
eq(select(3, armed()), nil, "a reshuffle in combat changes nothing")
WoW.counts[5232] = 1
WoW.leaveCombat()
WoW.advance(0)
eq(select(3, armed()), "party1", "after combat: Ashka again, at her token")

-- Picking yourself; then Clear.
rightClick()
check(pick("Testcase"), "you are in the list")
eq(select(3, armed()), "player", "on yourself")
rightClick()
check(Picker.rows[4]:IsShown() and Picker.rows[4].text:GetText() == "Clear", "Clear once someone is picked")
check(Picker.rows[1].text:GetText():find("^> ") ~= nil, "the one picked is marked")
check(pick("Clear"), "Clear is clickable")
eq(Target:Get(), nil, "cleared")
eq(select(3, armed()), nil, "the stone goes back to your target")
eq(ss.target:GetText(), "", "no name on the icon")

-- Someone who leaves is cleared, never retargeted: Brom takes her token.
rightClick()
pick("Ashka")
eq(select(3, armed()), "party1", "Ashka again")
WoW.chat = {}
table.remove(WoW.group, 1)
WoW.group[1] = { guid = BROM, name = "Brom Hollow", class = "WARRIOR" }
WoW.fire("GROUP_ROSTER_UPDATE")
WoW.advance(0)
eq(Target:Get(), nil, "she left: cleared")
eq(select(3, armed()), nil, "and Brom, now party1, isn't targeted")
check(H.messagesMatching("Ashka Vale left the group: no soulstone target") > 0, "said so")

-- The pick survives a reload (per character).
rightClick()
pick("Brom")
local saved = OneTwoThreeDB
WoW.reset()
WoW.items[5232], WoW.counts[5232], WoW.inGroup = "Minor Soulstone", 1, true
WoW.group = { { guid = BROM, name = "Brom Hollow", class = "WARRIOR" } }
ns = H.loadAddon({ savedDB = saved })
WoW.advance(0)
ss = ns.Bar:Button("soulstone")
eq(ss:GetAttribute("unit1"), "party1", "after a reload: still Brom")

done("test_soultarget")
