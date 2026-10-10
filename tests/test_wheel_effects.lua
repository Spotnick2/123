-- Animation lifecycle matters here: protected roots must never finish a
-- delayed close in combat, and an old close must never hide a reopened wheel.
dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")
WoW.spells[688] = { name = "Summon Imp", known = true }
WoW.spells[697] = { name = "Summon Voidwalker", known = true }
WoW.counts[6265] = 0
WoW.petGUID = "Pet-0-4613-0-1234-416-0000ABCDEF"
local ns = H.loadAddon()
local wheel, FX = ns.Wheel, ns.WheelEffects
wheel:Open()
local fx, imp, void = wheel.effects, wheel.nodes[5], wheel.nodes[1]
-- No clicks until every bead has faded in (code review, #23).
H.check(not imp.button:IsMouseEnabled() and not wheel.center:IsMouseEnabled(), "no input while igniting")
H.eq(fx.driver:GetParent(), WorldFrame, "the clock survives hiding UIParent")
H.check(not fx.driver:IsMouseEnabled(), "the clock cannot intercept clicks")
H.eq(FX.NodeState(imp), "active", "active demon has its own frame state")
H.eq(FX.NodeState(void), "missing", "missing shards show a red frame")
H.eq(FX.NodeState(wheel.nodes[2]), "unlearned", "unlearned takes priority over reagents")
imp.sacrificed = true
H.eq(FX.NodeState(imp), "sacrificed", "the future measured sacrifice state has its own treatment")
imp.sacrificed = nil

local writes = 0
for _, node in ipairs(wheel.nodes) do
    H.check(not node.visual:IsMouseEnabled(), "visual children do not intercept clicks")
    -- Secure geometry and action attributes have already been installed.
    -- Fail if animation later tries to alter them.
    for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetSize", "SetScale", "SetAttribute" }) do
        local old = node.button[method]
        node.button[method] = function(self, ...)
            writes = writes + 1
            return old(self, ...)
        end
    end
end
WoW.tick(.12)
H.check(void.visual:GetAlpha() > imp.visual:GetAlpha(), "ignition travels clockwise")
WoW.tick(.6)
H.eq(fx.phase, "idle", "opening settles")
H.check(imp.button:IsMouseEnabled() and wheel.center:IsMouseEnabled(), "input once every bead is in")
H.eq(imp.visual:GetAlpha(), 1, "portraits are fully visible when settled")
imp.button:GetScript("OnEnter")()
WoW.tick(.08)
H.check(imp.hoverLight > 0 and imp.hoverLight < 1, "hover eases instead of snapping")
H.check(imp.visual._scale > 1 and imp.visual._scale < 1.12, "the visual grows progressively")
WoW.tick(.10)
H.eq(imp.hoverLight, 1, "hover reaches full light")
H.eq(imp.visual._scale, 1.12, "hover reaches the tuned 12% growth")
H.eq(imp.button:GetWidth(), 76, "the secure click target stays its original size")
imp.button:GetScript("OnLeave")()
WoW.tick(.12)
H.check(imp.hoverLight > 0 and imp.hoverLight < 1, "hover fades on leave")
H.check(imp.visual._scale > 1 and imp.visual._scale < 1.12, "the visual shrinks progressively")
WoW.tick(.13)
H.eq(imp.hoverLight, 0, "hover returns to idle")
H.eq(imp.visual._scale, 1, "the visual returns to its resting size")
H.eq(writes, 0, "animation never writes secure geometry or attributes")

wheel:Close(imp.index)
H.check(not wheel.open and wheel:IsClosing(), "close enters its visual tail")
H.check(not imp.button:IsMouseEnabled() and not wheel.center:IsMouseEnabled(), "input stops at the start of close")
H.check(not wheel.escape:IsShown(), "Escape is disarmed at once")
H.eq(wheel.ticker, nil, "presentation retry stops at once")
WoW.tick(.1)
H.check(imp.visual:GetAlpha() < 1, "nodes extinguish with the field")
H.eq(fx.selected, imp.index, "the clicked summon gets the final pulse")
WoW.tick(.21)
H.check(not wheel.root:IsShown(), "the close hides all secure targets")
H.eq(fx.driver:GetScript("OnUpdate"), nil, "closed wheels do no animation work")
H.check(not imp.portrait.model:IsShown(), "closed portrait loads are cancelled")

-- Reopen during a close; the previous update has no lingering callback.
wheel:Open()
WoW.tick(.1)
local before = wheel.stage:GetAlpha()
wheel:Close()
WoW.tick(.01)
H.check(wheel.stage:GetAlpha() <= before, "early close never flashes to full alpha")
wheel:Open()
WoW.tick(.7)
H.check(wheel.open and wheel.root:IsShown(), "reopen cancels the previous close")
H.check(imp.button:IsMouseEnabled(), "reopen restores input")
H.eq(imp.hoverLight, 0, "reopen clears stale hover")
H.eq(imp.visual._scale, 1, "reopen clears stale hover growth")

-- Combat interrupts both entry and exit, synchronously while unlocked.
WoW.blocked = {}
imp.button:GetScript("OnEnter")()
WoW.tick(.20)
wheel:Close()
WoW.enterCombat()
H.check(not wheel:IsClosing() and not wheel.root:IsShown(), "combat interrupts an exit")
H.eq(fx.driver:GetScript("OnUpdate"), nil, "combat stops the effect clock")
H.eq(imp.visual._scale, 1, "combat resets a grown visual too")
WoW.tick(1)
H.eq(#WoW.blocked, 0, "no delayed protected operation lands in combat")
WoW.leaveCombat()
wheel:Open()
WoW.enterCombat()
H.check(not wheel.open and not wheel.root:IsShown(), "combat interrupts ignition too")
H.eq(#WoW.blocked, 0, "ignition abort has no protected writes")
WoW.leaveCombat()

wheel:Open()
wheel:OnForcedExit("ui-shown")
H.check(wheel:IsClosing(), "Escape through the cinematic UI gets the close animation")
WoW.tick(.31)
H.check(not wheel.root:IsShown(), "cinematic Escape finishes closing")
wheel:Open()
wheel:OnForcedExit("loading")
H.check(not wheel.root:IsShown() and not wheel:IsClosing(), "loading bypasses animation")

-- Unexpected late forced exit, under lockdown: the protected root can't hide
-- and its buttons can't drop the mouse, so they still cast until combat ends.
-- They stay visible (static) rather than become invisible armed targets
-- (code review, #23); the decoration fades and the player is told.
wheel:Open()
WoW.tick(.7)
WoW.inCombat = true
wheel:OnForcedExit("combat")
H.check(wheel.pendingHide, "late lockdown defers the protected hide")
H.eq(imp.visual:GetAlpha(), 1, "late lockdown keeps the armed beads visible")
H.eq(wheel.centerVisual:GetAlpha(), 1, "and the armed centre")
H.eq(wheel.stage:GetAlpha(), 0, "the decoration fades")
H.check(H.messagesMatching("closes when combat ends") > 0, "and the player is told")
H.eq(#WoW.blocked, 0, "late lockdown performs no protected operation")
WoW.leaveCombat()
H.check(not wheel.root:IsShown() and not wheel.pendingHide, "combat end finishes the deferred hide")

-- The idle repaint writes nothing for an unhovered, inactive bead.
WoW.leaveCombat()
wheel:Open()
WoW.tick(.7)
local scales = 0
local oldScale = void.visual.SetScale
void.visual.SetScale = function(self, v) scales = scales + 1 return oldScale(self, v) end
WoW.tick(.05) WoW.tick(.05)
H.eq(scales, 0, "no per-frame rescale of an idle bead")
void.visual.SetScale = oldScale
-- One fel green: the active bead's rim is the theme's colour.
H.eq(imp.edge._vertex and imp.edge._vertex[1], ns.Colors.FEL[1], "the active rim uses ns.Colors.FEL")
H.done("test_wheel_effects")
