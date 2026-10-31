-- ============================================================
-- Sacrifice (#20): the Demonic Sacrifice buff that is up, and what would
-- cancel it.
--
-- The buff is followed from its own cast (UNIT_SPELLCAST_SUCCEEDED for
-- Demonic Sacrifice, the demon out at SENT), saved per character with the
-- time, so it survives a reload. Out of combat the aura is checked too
-- (Data.SACRIFICE_BUFF), and a buff gone is forgotten; in combat auras are
-- secret, so the estimate stands. Dying ends it. Whenever it ends (the
-- player's UNIT_AURA, the two hours run out), the bar and the wheel are
-- rebuilt, so nothing stays held for a buff that is gone.
--
-- Summoning a demon cancels the buff, unless Demonic Pact is known: then
-- only the sacrificed demon cancels it. The Demon button and the wheel ask
-- before such a summon (Bar:HoldsDemon, Wheel:Resolve, ns.Resummon).
--
-- With Demonic Pact and a pair picked (Options), the Demon button's right
-- click walks it: summon the demon to sacrifice, sacrifice it, summon the
-- demon to keep (Sacrifice:PairStep). Each step is its own click, re-armed
-- out of combat between them.
-- ============================================================

local _, ns = ...
if ns.skip then return end

local API = ns.API
local Data = ns.Data

local Sacrifice = {}
ns.Sacrifice = Sacrifice

-- The aura may land a moment after the cast: no aura check before then.
local GRACE = 3

local OWN = {}
for _, spellID in ipairs(Data.DEMONS) do OWN[spellID] = true end

-- The buff ended: forgotten, and the held summons re-armed.
local function forget()
    ns.char.sacrifice = nil
    ns.SecureAction.MarkDirty()
end

-- { spell = the sacrificed demon's summon, at = time() }, or nil.
function Sacrifice:Active()
    local s = ns.char and ns.char.sacrifice
    if not s then return nil end
    local age = time() - s.at
    if age >= Data.SACRIFICE_LASTS then
        forget()
        return nil
    end
    local buff = Data.SACRIFICE_BUFF[s.spell]
    local name = buff and API.SpellName(buff)
    if name and age >= GRACE and not ns.SecureAction.inCombat then
        local has = API.HasAura("player", { [buff] = true }, { [name] = true })
        if has == false then
            forget()
            return nil
        end
    end
    return s
end

-- Looks again once the saved buff's two hours are up (no event says so).
function Sacrifice:WatchExpiry()
    local s = ns.char.sacrifice
    if not s then return end
    local left = s.at + Data.SACRIFICE_LASTS - time()
    C_Timer.After(math.max(left, 0) + 1, function() self:Active() end)
end

function Sacrifice.HasPact()
    return API.IsKnown(Data.DEMONIC_PACT)
end

-- True when summoning `spellID` now would throw the buff away.
function Sacrifice:Cancels(spellID)
    if not OWN[spellID] then return false end
    local s = self:Active()
    if not s then return false end
    return not Sacrifice.HasPact() or spellID == s.spell
end

-- The buff's name in the client's language, or nil.
function Sacrifice:BuffName()
    local s = self:Active()
    local buff = s and Data.SACRIFICE_BUFF[s.spell]
    return buff and API.SpellName(buff) or nil
end

local function spell(spellID, step)
    return { type = "spell", spell = spellID, spellID = spellID, step = step }
end

-- The pair picked in Options ({ sacrifice, keep }, summons), or nil.
function Sacrifice.Pair()
    local pair = ns.char and ns.char.sacrificePair
    local a, b = pair and pair.sacrifice, pair and pair.keep
    if not (OWN[a] and OWN[b]) or a == b then return nil end
    return a, b
end

-- The Demon button's right click with a pair and Demonic Pact: nil when
-- that doesn't apply (the usual right click), false once the pair is done
-- (unarmed: a stray click mustn't sacrifice the demon kept), else the
-- step's action (`step`: "summon", "sacrifice", "keep").
function Sacrifice:PairStep()
    local a, b = Sacrifice.Pair()
    if not a or not (API.IsKnown(Data.DEMONIC_SACRIFICE) and Sacrifice.HasPact()) then return nil end
    local out = ns.Bar.PetSummon()
    local s = self:Active()
    if s and s.spell == a then
        if out == b then return false end
        return API.IsKnown(b) and spell(b, "keep") or false
    end
    if out == a then return spell(Data.DEMONIC_SACRIFICE, "sacrifice") end
    return API.IsKnown(a) and spell(a, "summon") or false
end

function Sacrifice:Initialize()
    local Events = ns.Events
    Events:Register("UNIT_SPELLCAST_SENT", function(_, unit, _, _, spellID)
        if unit == "player" and API.Number(spellID) == Data.DEMONIC_SACRIFICE then
            self.pending = ns.Bar.PetSummon()
        end
    end)
    Events:Register("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
        if unit ~= "player" or API.Number(spellID) ~= Data.DEMONIC_SACRIFICE then return end
        local demon = self.pending or ns.Bar.PetSummon()
        self.pending = nil
        if demon then
            ns.char.sacrifice = { spell = demon, at = time() }
            ns.SecureAction.MarkDirty()
            self:WatchExpiry()
        end
    end)
    -- The buff cancelled or gone out of combat: Active forgets it.
    local auras = CreateFrame("Frame")
    API.RegisterUnitEvent(auras, "UNIT_AURA", "player")
    auras:SetScript("OnEvent", function()
        if ns.char.sacrifice and not ns.SecureAction.inCombat then self:Active() end
    end)
    self:WatchExpiry()
    -- A summon that cancels it (any demon, or with Demonic Pact the one
    -- sacrificed) ends it, in combat too.
    Events:Register("UNIT_PET", function(_, unit)
        if unit ~= "player" then return end
        local out = ns.Bar.PetSummon()
        if out and self:Cancels(out) then forget() end
    end)
    Events:Register("PLAYER_DEAD", function()
        if ns.char.sacrifice then forget() end
    end)
end
