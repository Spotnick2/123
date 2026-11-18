dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")
WoW.spells[698] = { name = "Ritual", known = true }
WoW.counts[6265] = 3
local ns = H.loadAddon() -- no LibGlass: also exercises the plain fallback
local FX, bar = ns.BarEffects, ns.Bar
local b = bar:Button("summoning")
eq(b.barState, "normal", "learned with reagent")
ns.Queue.entries = { {} }
FX.Update(b)
eq(b.barState, "waiting", "queue lights summon")
check(b.pulse:IsPlaying(), "summon pulse plays")
b.short = true
FX.Update(b)
eq(b.barState, "missing", "missing reagent beats queue")
check(not b.pulse:IsPlaying(), "missing stops pulse")
local action = b.action
b.action = nil
FX.Update(b)
eq(b.barState, "unlearned", "unlearned beats reagent")
b.action, b.short = action, false
FX.Update(b)
-- Hover: the rim on the overlay shows with the button's own hover, and the
-- tooltip script still runs (the hook must not replace it).
for _, button in ipairs({ bar.wheelButton, unpack(bar.buttons) }) do
    check(not button.barHover:IsShown(), button:GetName() .. " hover rim starts hidden")
    button:GetScript("OnEnter")(button)
    check(button.barHover:IsShown(), button:GetName() .. " hover rim shows")
    check(GameTooltip:IsOwned(button), button:GetName() .. " tooltip still shows")
    button:GetScript("OnLeave")(button)
    check(not button.barHover:IsShown(), button:GetName() .. " hover rim hides")
end
local originalCreate = CreateFrame
-- QueueList lazily allocates rows; its behavior is outside this effects test.
ns.QueueList.Refresh = function() end
CreateFrame = function() error("frame created during combat refresh") end
local function forbidden() error("protected geometry changed") end
for _, frame in ipairs({ bar.frame, unpack(bar.buttons) }) do
    for _, method in ipairs({ "Show", "Hide", "SetPoint", "SetScale", "SetParent", "SetSize", "SetFrameLevel" }) do
        frame[method] = forbidden
    end
end
WoW.combat, ns.SecureAction.inCombat = true, true
WoW.combatSecret = true
bar:Refresh()
eq(b.barState, "waiting", "secret counts do not change waiting state")
ns.Queue.entries = {}
ns.Queue:Changed()
check(not b.pulse:IsPlaying(), "empty queue stops in combat")
ns.Queue.entries = { {} }
ns.Queue:Changed()
check(b.pulse:IsPlaying(), "queue starts in combat")
eq(b:GetWidth(), 36, "secure width retained")
eq(b:GetHeight(), 36, "secure height retained")
check(not b.cooldown:IsMouseEnabled(), "cooldown remains mouse disabled")
CreateFrame = originalCreate
done("test_bar_effects")
