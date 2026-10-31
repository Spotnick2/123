-- ============================================================
-- Soulstone target (#5): whom the Soulstone button's stone goes to.
--
-- Picked in UI/SoulPicker.lua (the button's right click), keyed on GUID and
-- saved per character. Its unit token is read whenever the button is
-- rebuilt, out of combat only (Bar's RESOLVE.soulstone). Someone who leaves
-- the group is cleared, never retargeted: the button goes back to using the
-- stone on your target, and a token never points at someone else.
-- ============================================================

local _, ns = ...
if ns.skip then return end

local API = ns.API
local L = ns.L

local SoulTarget = {
    listeners = {},
}
ns.SoulTarget = SoulTarget

-- { guid, name, class }, or nil.
function SoulTarget:Get()
    return ns.char and ns.char.soulTarget or nil
end

function SoulTarget:OnChanged(fn)
    self.listeners[#self.listeners + 1] = fn
end

local function changed()
    for _, fn in ipairs(SoulTarget.listeners) do fn() end
    ns.SecureAction.MarkDirty()
end

function SoulTarget:Set(guid, name, class)
    ns.char.soulTarget = { guid = guid, name = name, class = class }
    changed()
end

function SoulTarget:Clear()
    if not self:Get() then return end
    ns.char.soulTarget = nil
    changed()
end

-- Their unit token now ("player" for yourself), or nil when they aren't
-- in the group.
function SoulTarget:Unit()
    local t = self:Get()
    if not t then return nil end
    if t.guid == API.UnitGUID("player") then return "player" end
    return ns.Queue.UnitOf(t.guid)
end

-- Gone from the group (or the group gone): cleared, and said so.
function SoulTarget:CheckRoster()
    local t = self:Get()
    if t and not self:Unit() then
        self:Clear()
        ns.Print(L["%s left the group: no soulstone target."]:format(t.name or "?"))
    end
end

function SoulTarget:Initialize()
    ns.Events:Register("GROUP_ROSTER_UPDATE", function() self:CheckRoster() end)
end
