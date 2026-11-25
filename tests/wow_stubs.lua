------------------------------------------------------------
-- wow_stubs.lua: 123's WoW: Forever mock for Lua 5.1 unit tests.
-- dofile("tests/wow_stubs.lua") FIRST in every test; drive it via the WoW table.
--
-- The mechanics come from WowTestKit (tests/kit.lua loads the commit
-- tests/kit.pin names; its README is the reference): strict globals, secrets,
-- event names checked against the pinned build, widgets that record every
-- method called, protected frames refused in combat, print (with the
-- stray-"|" check done() fails on), timers and the clock (WoW.now,
-- WoW.advance), fire / fireAllRegistered / tick, check / eq / done.
--
-- This file adds 123's own client APIs (adapted from Portal Roulette's and
-- Apotheca's), each verified in the API dump
-- (C:\Projects\WoW\References\Forever\api\forever-api-1.60.1.70959.md) or in
-- Blizzard's FrameXML (C:\Projects\WoW\wow-ui-source). Stub a global only
-- after confirming it there, with the client's signature. A name the client
-- does NOT have goes in the Kit.strict list at the bottom, so the addon has
-- to cope without it. A forgiving stub quietly certifies calls the client
-- will reject.
------------------------------------------------------------

dofile("tests/kit.lua")
local Methods = WoW.Methods
local newWidget = WoW.newWidget
local Secret = WoW.Secret

-- What a protected frame refuses in combat beyond the kit's list: the old
-- stub refused these too (AGENTS.md: no Hide, move, scale or reparent in
-- combat), so the tests asserting WoW.blocked stays empty still cover them.
WoW.PROTECTED.SetParent = true
WoW.PROTECTED.SetScale = true

------------------------------------------------------------
-- Templates
------------------------------------------------------------

-- UIPanelButtonTemplate's and UICheckButtonTemplate's Text font string, with
-- its template's font (a named frame's also as <name>Text, as the client's
-- $parent names do).
local TEMPLATE_REGIONS = {
    UICheckButtonTemplate = { "Text" },
    UIPanelButtonTemplate = { "Text" },
}
for template, regions in pairs(TEMPLATE_REGIONS) do
    WoW.templates[template] = function(w)
        for _, region in ipairs(regions) do
            local r = Methods.CreateFontString(w, nil, "ARTWORK", "GameFontNormal")
            w[region] = r
            if w._name then rawset(_G, w._name .. region, r) end
        end
    end
end

------------------------------------------------------------
-- Widget methods the kit's core doesn't have (each a real method of that
-- widget type on this build: Kit.checkMethods checks every call)
------------------------------------------------------------

-- A frame's own scale (the bar's size option, the wheel's hover growth:
-- tests read w._scale). 1 unless set.
function Methods.SetScale(w, s) w._scale = s end
function Methods.GetScale(w) return w._scale or 1 end
function Methods.GetNumPoints(w) return #w._points end
function Methods.GetTexture(t) return t._file end
-- The bar is dragged: IsMovable answers SetMovable.
function Methods.SetMovable(w, v) w._movable = v and true or false end
function Methods.IsMovable(w) return w._movable == true end
function Methods.StartMoving(w) w._moving = true end
function Methods.StopMovingOrSizing(w) w._moving = false end
-- The secure buttons' click edges (tests check both are registered).
function Methods.RegisterForClicks(b, ...) b._clicks = { ... } end
-- Frame:CreateLine (SimpleFrameAPI): a Line region of the frame.
function Methods.CreateLine(w, name)
    local l = WoW.addRegion(w, newWidget("Line", w, name))
    if name then rawset(_G, name, l) end
    return l
end
-- The stub has no layout engine. A frame whose rect a test hasn't set (the
-- kit's w._left / _right / _top / _bottom) is laid out at the centre of a
-- 1920x1080 screen with its own height, as the old stub laid out every
-- frame: the lists above the bar (test_queue, test_requests,
-- test_soultarget) hang at the Summoning, Healthstone and Soulstone buttons'
-- top centre, read through GetCenter and GetTop (UI/Bar.lua Bar:TopOf).
local kitGetCenter, kitGetTop = Methods.GetCenter, Methods.GetTop
function Methods.GetCenter(w)
    if w._left == nil and w._right == nil and w._top == nil and w._bottom == nil then return 960, 540 end
    return kitGetCenter(w)
end
function Methods.GetTop(w)
    if w._top == nil then return 540 + (w._height or 0) / 2 end
    return kitGetTop(w)
end
-- A Cooldown widget keeps what it was set to (start, duration).
function Methods.SetCooldown(c, start, duration) c._cooldown = { start, duration } end
function Methods.Clear(c) c._cooldown = nil end
function Methods.IsDesaturated(t) return t._desaturated == true end
-- Text is about half its font size wide per character (Arial Narrow), so a
-- test can tell a name that fits from one that doesn't (#22). The font's
-- size is the one set (SetFont), else 12.
function Methods.GetUnboundedStringWidth(fs)
    local chars = select(2, (fs._text or ""):gsub("[^\128-\191]", ""))
    local size = fs._font and fs._font[2] or 12
    return chars * size * 0.45
end
function Methods.GetStringWidth() return 50 end
function Methods.GetStringHeight() return 12 end
-- PlayerModel (portraits): what it was asked to show.
function Methods.SetCreature(m, npc) m._creature = npc end
function Methods.SetPortraitZoom(m, z) m._zoom = z end
function Methods.SetDesaturation(m, d) m._desat = d end
function Methods.ClearModel(m) m._creature = nil end
-- GameTooltip: its owner, and the lines shown, title first, so a test can
-- read a tooltip.
function Methods.SetOwner(tip, owner) tip._owner = owner end
function Methods.IsOwned(tip, f) return tip._owner == f end
function Methods.AddLine(tip, t) tip._lines = tip._lines or {}; tip._lines[#tip._lines + 1] = t end
local kitSetText = Methods.SetText
function Methods.SetText(w, t, ...)
    if w._type == "GameTooltip" then w._text, w._lines = t, { t }; return end
    return kitSetText(w, t, ...)
end
-- Events: the core's check of the name against the build, plus two refusals
-- the tests simulate: WoW.badEvents throws, WoW.refusedEvents returns false
-- (ns.API.RegisterEvents must report both).
local kitRegister = Methods.RegisterEvent
function Methods.RegisterEvent(w, e)
    if WoW.badEvents[e] then error("Attempt to register unknown event \"" .. tostring(e) .. "\"", 2) end
    if WoW.refusedEvents[e] then return false end
    return kitRegister(w, e)
end

------------------------------------------------------------
-- State the tests reset
------------------------------------------------------------

table.insert(WoW.onReset, function()
    WoW.now          = 10000     -- the client's clock is never near 0
    WoW.build        = "70205"
    WoW.class        = "WARLOCK"
    WoW.instanceName, WoW.instanceType, WoW.instanceMap = "Kalimdor", "none", 1
    WoW.health, WoW.healthMax = 1000, 1000
    WoW.power,  WoW.powerMax  = 1000, 1000
    WoW.healthSecret = true      -- measured: secret at rest on 69977 and 70009
    WoW.aurasThrow   = false     -- combat: index reads throw
    WoW.combatSecret = false     -- cooldowns and stack counts secret (unmeasured; worst case)
    WoW.auras        = { HELPFUL = {}, HARMFUL = {} }
    WoW.bags         = {}        -- [bag] = { [slot] = { itemID=, stackCount= } }
    WoW.cooldowns    = {}        -- [itemID] = { start, duration }
    WoW.items        = {}        -- [itemID] = name; missing -> cache miss
    WoW.badEvents    = {}        -- RegisterEvent throws
    WoW.refusedEvents = {}       -- RegisterEvent returns false
    WoW.altDown      = false
    WoW.popups       = {}
    WoW.itemsUsed    = {}        -- names passed to C_Item.UseItemByName
    WoW.curvesRefused = false    -- simulate a client that refuses colour curves
    WoW.kits, WoW.refusedKits = {}, {}  -- sound kits played / refused
    WoW.group, WoW.inRaid = {}, false
    WoW.sent         = {}        -- SendChatMessage: { msg, channel }
end)

function WoW.AddItem(bag, slot, itemID, count, name)
    WoW.bags[bag] = WoW.bags[bag] or {}
    WoW.bags[bag][slot] = { itemID = itemID, stackCount = count or 1 }
    WoW.items[itemID] = name or ("Item " .. itemID)
end

function WoW.SetAura(filter, name, spellId)
    local list = WoW.auras[filter]
    list[#list + 1] = { name = name, spellId = spellId }
end

-- Measured on 70205: InCombatLockdown() is still false while
-- PLAYER_REGEN_DISABLED handlers run; lockdown starts right after.
function WoW.enterCombat()
    WoW.aurasThrow = true
    WoW.fire("PLAYER_REGEN_DISABLED")
    WoW.combat = true
end

function WoW.leaveCombat()
    WoW.combat, WoW.aurasThrow = false, false
    WoW.fire("PLAYER_REGEN_ENABLED")
end

------------------------------------------------------------
-- Frames the client makes
------------------------------------------------------------

GameTooltip = newWidget("GameTooltip", UIParent, "GameTooltip")
GameFontNormal, GameFontHighlight = {}, {}
WorldFrame = newWidget("Frame", nil, "WorldFrame")

------------------------------------------------------------
-- Globals present on this client (forever-api-1.60.1.70959.md)
------------------------------------------------------------

function time() return math.floor(WoW.now) end
function IsAltKeyDown() return WoW.altDown end
function GetBuildInfo() return "1.60.1", WoW.build, "Sep 22 2026", 16001 end
function GetRealmName() return "ClassicBetaPvE" end
function UnitName() return "Testcase Surname", nil end
WoW.petGUID = nil
WoW.petFamily = nil
function UnitCreatureFamily(unit)
    if unit == "pet" and WoW.petFamily then return WoW.petFamily[1], WoW.petFamily[2] end
    return nil
end
-- Creature families by ID, as the client names them (#22; the 70532 dump:
-- C_CreatureInfo.GetCreatureFamilyInfo -> { id, name, iconFile }). The
-- English names from Forever's CreatureFamily table; a test swaps in another
-- language or empties it.
WoW.families = {
    [15] = "Felhunter", [16] = "Voidwalker", [17] = "Succubus",
    [19] = "Doomguard", [23] = "Imp", [302] = "Incubus",
}
C_CreatureInfo = {}
function C_CreatureInfo.GetCreatureFamilyInfo(id)
    local name = WoW.families[id]
    return name and { id = id, name = name } or nil
end
-- The client's round 2D portrait of a creature display (TimeIsMoney's fallback).
function SetPortraitTextureFromCreatureDisplayID(texture, display) texture._portrait = display end
-- FrameXML's ClassColors.lua fills this at load.
RAID_CLASS_COLORS = { WARLOCK = { r = 0.53, g = 0.53, b = 0.93 } }
-- Pet bar: WoW.petActions[slot] = { name =, spellID = }.
WoW.petActions = {}
function GetPetActionInfo(slot)
    local a = WoW.petActions[slot]
    if not a then return nil end
    return a.name, 136235, false, false, false, false, a.spellID
end
WoW.playerGUID = "Player-4613-00ABCDEF"
-- The group: WoW.group = { { guid =, name =, class = }, ... } (others, not
-- the player), as party1.. or raid1.. (WoW.inRaid).
local function member(unit)
    local i = tonumber(unit:match("^party(%d+)$") or unit:match("^raid(%d+)$"))
    return i and WoW.group[i]
end
function GetNumGroupMembers() return #WoW.group > 0 and #WoW.group + 1 or 0 end
function UnitGUID(unit)
    if unit == "pet" then return WoW.petGUID end
    if unit == "player" then return WoW.playerGUID end
    if unit == "NPC" then return WoW.tradeWith end
    if unit == "target" then return WoW.targetGUID end
    local m = member(unit)
    return m and m.guid or nil
end
function UnitClass(unit)
    local m = unit and member(unit)
    local class = m and m.class or WoW.class
    return class:sub(1, 1) .. class:sub(2):lower(), class, 5
end
function GetUnitName(unit)
    local m = member(unit)
    return m and m.name or "Testcase Surname"
end
-- A member's summon (`summon`, Enum.SummonStatus; "secret" for a secret)
-- and distance (`distance` in yards; nil: the client can't tell).
C_IncomingSummon = {}
function C_IncomingSummon.IncomingSummonStatus(unit)
    local m = member(unit)
    if m and m.summon == "secret" then return Secret("IncomingSummonStatus") end
    return m and m.summon or 0
end
function UnitDistanceSquared(unit)
    local m = member(unit)
    if not (m and m.distance) then return 0, false end
    return m.distance * m.distance, true
end
-- Outdoors this client returns the CONTINENT, not an empty name.
function GetInstanceInfo() return WoW.instanceName, WoW.instanceType, 0, "", 0, 0, false, WoW.instanceMap end
-- Temporary weapon enchants by slot: { has, exp (ms), charges, id }. The
-- time left runs down from the first read, as the client's does.
WoW.enchants = {}
local function left(e)
    if type(e[2]) ~= "number" then return e[2] end
    e.t = e.t or WoW.now
    return e[2] - (WoW.now - e.t) * 1000
end
WoW.enchantThrow = false
function GetWeaponEnchantInfo()
    if WoW.enchantThrow then error("GetWeaponEnchantInfo refused") end
    local m, o = WoW.enchants[16] or {}, WoW.enchants[17] or {}
    return m[1] or false, left(m), m[3], m[4], o[1] or false, left(o), o[3], o[4], false
end
WoW.targeting, WoW.popup = false, nil
function SpellIsTargeting() return WoW.targeting end
function StaticPopup_Visible(which) return WoW.popup == which and {} or nil end

local function maybeSecret(v, label) if WoW.healthSecret then return Secret(label) end return v end
function UnitHealth()    return maybeSecret(WoW.health, "UnitHealth") end
function UnitHealthMax() return WoW.healthMax end
function UnitPower()     return maybeSecret(WoW.power, "UnitPower") end
function UnitPowerMax()  return WoW.powerMax end

NUM_BAG_SLOTS = 4
Enum = { BagIndex = { Backpack = 0, ReagentBag = 5 }, PowerType = { Mana = 0 },
    SummonStatus = { None = 0, Pending = 1, Accepted = 2, Declined = 3 },
    SpellBookSpellBank = { Player = 0, Pet = 1 }, TooltipDataType = { Item = 0 } }

C_Container = {}
function C_Container.GetContainerNumSlots(bag)
    local b = WoW.bags[bag]
    if not b then return 0 end
    local n = 0
    for slot in pairs(b) do if slot > n then n = slot end end
    return n
end
-- A pickup puts the item on the cursor; it stays in its slot (locked)
-- until a trade completes, as the client shows it. Holding something
-- already, the two swap. WoW.pickupFails: nothing happens (a locked item,
-- run 2).
function C_Container.PickupContainerItem(bag, slot)
    if WoW.pickupFails then return end
    WoW.bags[bag] = WoW.bags[bag] or {}
    local s = WoW.bags[bag][slot]
    local held = WoW.cursor
    if held then WoW.bags[bag][slot] = { itemID = held, stackCount = 1 } end
    WoW.cursor = s and s.itemID
end
function C_Container.GetContainerItemID(bag, slot)
    local s = WoW.bags[bag] and WoW.bags[bag][slot]
    return s and s.itemID
end
function C_Container.GetContainerItemInfo(bag, slot)
    local s = WoW.bags[bag] and WoW.bags[bag][slot]
    if not s then return nil end
    local count = WoW.combatSecret and Secret("stackCount") or s.stackCount
    return { itemID = s.itemID, stackCount = count, hyperlink = "item:" .. s.itemID }
end
function C_Container.GetItemCooldown(itemID)
    if WoW.combatSecret then return Secret("GetItemCooldown start"), Secret("GetItemCooldown duration"), 1 end
    local c = WoW.cooldowns[itemID]
    if c then return c[1], c[2], 1 end
    return 0, 0, 1
end

-- Hearth, toys, items.
WoW.hearthstone = 6948       -- C_Container.PlayerHasHearthstone() result
WoW.toys = {}                -- [itemID] = true (owned)
WoW.equippedItems = {}       -- [itemID] = true
WoW.counts = {}              -- [itemID] = count for C_Item.GetItemCount
function C_Container.PlayerHasHearthstone() return WoW.hearthstone end

C_Item = {}
-- Cache miss returns NO values, not nil.
function C_Item.GetItemInfo(itemID)
    local name = WoW.items[itemID]
    if not name then return end
    return name, "item:" .. itemID, 1, 1, 1, "Consumable", "Potion", 20, "", 134400
end
function C_Item.GetItemIconByID(itemID) return WoW.items[itemID] and 134400 or nil end
function C_Item.GetItemCount(itemID)
    if WoW.combatSecret then return Secret("GetItemCount") end
    return WoW.counts[itemID] or 0
end
function C_Item.UseItemByName(name) WoW.itemsUsed[#WoW.itemsUsed + 1] = name end
-- Reads the client's item DB: answers for any known ID, cache or not.
-- Item class by ID ({ classID, subClassID, subType }); consumables by
-- default. The type name follows the class, as the client's does.
WoW.itemClass = {}
local CLASS_NAME = { [2] = "Weapon", [4] = "Armor" }
function C_Item.GetItemInfoInstant(itemID)
    local c = WoW.itemClass[itemID]
    if c then return itemID, CLASS_NAME[c[1]] or "Miscellaneous", c[3] or "", "", 134400, c[1], c[2] end
    if not WoW.items[itemID] then return nil end
    return itemID, "Consumable", "Food & Drink", "", 134400, 0, 5
end
function C_Item.RequestLoadItemDataByID() end
-- Items the player cannot use now (C_Item.IsUsableItem false).
WoW.unusable = {}
function C_Item.IsUsableItem(itemID) return not WoW.unusable[itemID], false end
function C_Item.GetItemSpell(itemID)
    if WoW.items[itemID] then return "Food", 433 end
end
function C_Item.GetItemNameByID(itemID) return WoW.items[itemID] end
function C_Item.IsEquippedItem(itemID) return WoW.equippedItems[itemID] or false end
function C_Item.GetItemCooldown(itemID)
    local c = WoW.cooldowns[itemID]
    if c then return c[1], c[2], true end
    return 0, 0, true
end

-- Spells: WoW.spells[id] = { name=, icon=, known=, usable= }.
WoW.spells = {}
WoW.spellCooldowns = {}      -- [id] = { startTime, duration }
local function spell(id) return type(id) == "number" and WoW.spells[id] or nil end
C_Spell = {}
-- Spells whose name only appears after `n` load requests, like the client,
-- which answers nil until the data arrives (n = math.huge: never loads).
WoW.spellLoadAfter = {}
function C_Spell.RequestLoadSpellData(spellID)
    local e = WoW.spellLoadAfter[spellID]
    if e then
        e.n = e.n - 1
        if e.n <= 0 then WoW.spellNames[spellID], WoW.spellLoadAfter[spellID] = e.name, nil end
    end
end
-- Localized names by spell ID, for spells not in WoW.spells.
WoW.spellNames = {}
function C_Spell.GetSpellName(id)
    local s = spell(id)
    if s then return s.name end
    return WoW.spellNames[id]
end
function C_Spell.DoesSpellExist(id)
    return spell(id) ~= nil or WoW.spellNames[id] ~= nil or WoW.spellLoadAfter[id] ~= nil
end
WoW.spellDescriptions = {}
function C_Spell.GetSpellDescription(spellID)
    if spellID == 433 then return "Restores 61 health over 18 sec." end
    return WoW.spellDescriptions[spellID] or ""
end
function C_Spell.GetSpellInfo(id)
    local s = spell(id)
    if not s then return nil end
    return { name = s.name, iconID = s.icon or 136235, originalIconID = s.icon or 136235,
             castTime = s.castTime or 10000, minRange = 0, maxRange = 0, spellID = id }
end
function C_Spell.GetSpellTexture(id) local s = spell(id) return s and (s.icon or 136235) or nil end
function C_Spell.IsSpellUsable(id) local s = spell(id) return s and s.usable or false, false end
function C_Spell.GetSpellCooldown(id)
    if WoW.combatSecret then return Secret("GetSpellCooldown") end
    local c = WoW.spellCooldowns[id] or { 0, 0 }
    return { startTime = c[1], duration = c[2], isEnabled = true, modRate = 1 }
end
function C_Spell.GetSpellCooldownDuration(id) return { _duration = true, spellID = id } end
function C_Spell.GetSpellPowerCost() return {} end
C_SpellBook = {}
-- The pet bank (Enum.SpellBookSpellBank.Pet, 1) answers for the summoned
-- demon only (docs/FOREVER-PROBE.md run 3): WoW.petSpells[id] = true.
WoW.petSpells = {}
function C_SpellBook.IsSpellKnown(id, bank)
    if bank == 1 then return WoW.petSpells[id] == true end
    local s = spell(id) return s and s.known or false
end
function C_SpellBook.GetNumSpellBookSkillLines() return 0 end
function IsPlayerSpell(id) return C_SpellBook.IsSpellKnown(id) end

-- A profiling clock that advances with every read, so a per-frame time
-- budget really ends a frame's work in tests.
WoW.profileMs = 0
function debugprofilestop() WoW.profileMs = WoW.profileMs + 0.0005 return WoW.profileMs end

-- Levels.
WoW.level, WoW.maxLevel, WoW.xpDisabled = 3, 60, false
function UnitLevel() return WoW.level end
WoW.dead = false
function UnitIsDeadOrGhost() return WoW.dead end
function GetMaxPlayerLevel() return WoW.maxLevel end
function GetMaxLevelForPlayerExpansion() return WoW.maxLevel end
function IsXPUserDisabled() return WoW.xpDisabled end

C_TooltipInfo = {}
function C_TooltipInfo.GetItemByID(itemID)
    local name = WoW.items[itemID]
    if not name then return nil end
    return { lines = { { leftText = name }, { leftText = "Use: Restores 61 health over 18 sec." } } }
end
-- Spell tooltips: WoW.spellTips[id] = { lines... }; missing -> no data yet.
WoW.spellTips = {}
function C_TooltipInfo.GetSpellByID(id)
    local tip = WoW.spellTips[id]
    if not tip then return nil end
    local lines = {}
    for i, t in ipairs(tip) do lines[i] = { leftText = t } end
    return { lines = lines }
end

C_UnitAuras = {}
function C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
    if WoW.aurasThrow then
        error("Auras cannot be accessed when secret while tainted by 'OneTwoThree'", 2)
    end
    return WoW.auras[filter or "HELPFUL"][index]
end

C_AddOns = {}
function C_AddOns.GetAddOnMetadata(_, field) if field == "Version" then return "dev" end end
-- Per-character enable state (#39): WoW.addonOff[character] = true, or
-- WoW.addonOffAll. Enum.AddOnEnableState: 0 None, 1 Some, 2 All.
WoW.addonOff, WoW.addonOffAll = {}, false
function C_AddOns.DisableAddOn(_, character)
    if character == nil then WoW.addonOffAll = true else WoW.addonOff[character] = true end
end
function C_AddOns.EnableAddOn(_, character)
    if character == nil then WoW.addonOffAll, WoW.addonOff = false, {} else WoW.addonOff[character] = nil end
end
function C_AddOns.GetAddOnEnableState(_, character)
    if WoW.addonOffAll then return 0 end
    if character ~= nil then return WoW.addonOff[character] and 0 or 2 end
    return next(WoW.addonOff) and 1 or 2
end

C_Secrets = {}
function C_Secrets.ShouldAurasBeSecret() return WoW.combat end
function C_Secrets.ShouldCooldownsBeSecret() return false end
function C_Secrets.ShouldUnitHealthMaxBeSecret() return false end
function C_Secrets.ShouldUnitPowerBeSecret() return WoW.healthSecret end

-- Role sources. Solo by default: no group, no assigned role, and an empty
-- role selector.
function IsInGroup(category)
    if category and category ~= WoW.groupCategory then return false end
    return WoW.inGroup or false
end
function IsInRaid() return WoW.inRaid or false end
function UnitGroupRolesAssigned() return WoW.assignedRole or "NONE" end
function GetLFGRoles()
    local r = WoW.lfgRoles or {}
    return false, r.tank or false, r.healer or false, r.damage or false
end
C_LFGListRoles = {}
function C_LFGListRoles.GetRoles()
    local r = WoW.lfgRoles or {}
    return { tank = r.tank or false, healer = r.healer or false, dps = r.damage or false }
end
-- Saved roles can differ from the current ones (WoW.lfgSavedRoles).
function C_LFGListRoles.GetSavedRoles()
    local r = WoW.lfgSavedRoles or WoW.lfgRoles or {}
    return { tank = r.tank or false, healer = r.healer or false, dps = r.damage or false }
end
function UnitPowerType() return 0, "MANA" end
function GetInventoryItemID(_, slot) return WoW.equipped and WoW.equipped[slot] end

C_SpecializationInfo = {}
function C_SpecializationInfo.GetSpecialization() return 1 end
function C_SpecializationInfo.GetSpecializationInfo() return 62, "Arcane", "", 135932, "DAMAGER", 4, 0 end
function C_SpecializationInfo.GetNumSpecializationsForClassID() return 1 end

-- UnitHealthMissing / UnitHealthPercent etc. return secrets like UnitHealth.
-- Given a colour CURVE, the Percent functions evaluate it inside the client
-- and return a colour; the stub evaluates it on the true percentage, and
-- hands back secret channels when health is secret, as the client may.
function UnitHealthMissing() return Secret("UnitHealthMissing") end
function UnitPowerMissing() return Secret("UnitPowerMissing") end

local function curveColor(curve, pct)
    local r, g, b = curve:_eval(pct)
    if WoW.healthSecret then r, g, b = Secret("r"), Secret("g"), Secret("b") end
    return { GetRGB = function() return r, g, b end }
end
-- usePredicted: WoW.incomingHeal counts only when predicted is asked for.
function UnitHealthPercent(_, usePredicted, curve)
    if not curve then return Secret("UnitHealthPercent") end
    if WoW.curvesRefused then error("curve refused") end
    local h = WoW.health
    if usePredicted ~= false then h = math.min(WoW.healthMax, h + (WoW.incomingHeal or 0)) end
    WoW.lastPredicted = usePredicted
    return curveColor(curve, h / WoW.healthMax)
end
function UnitPowerPercent(_, _, _, curve)
    if not curve then return Secret("UnitPowerPercent") end
    if WoW.curvesRefused then error("curve refused") end
    return curveColor(curve, WoW.power / WoW.powerMax)
end

-- A linear colour curve, evaluated the way the client does.
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
C_CurveUtil = {}
function C_CurveUtil.CreateColorCurve()
    local pts = {}
    local c = {}
    function c:AddPoint(x, color) pts[#pts + 1] = { x = x, c = color } ; table.sort(pts, function(p, q) return p.x < q.x end) end
    function c:_eval(x)
        if x <= pts[1].x then local k = pts[1].c return k.r, k.g, k.b end
        for i = 2, #pts do
            local a, b = pts[i - 1], pts[i]
            if x <= b.x then
                local t = (x - a.x) / (b.x - a.x)
                return a.c.r + (b.c.r - a.c.r) * t, a.c.g + (b.c.g - a.c.g) * t, a.c.b + (b.c.b - a.c.b) * t
            end
        end
        local k = pts[#pts].c
        return k.r, k.g, k.b
    end
    return c
end

Settings = {}
function Settings.RegisterCanvasLayoutCategory(panel, name)
    return { GetID = function() return 1 end, name = name }
end
function Settings.RegisterAddOnCategory() end
function Settings.OpenToCategory() end

StaticPopupDialogs = {}
function StaticPopup_Show(which, a, b, data)
    WoW.popups[#WoW.popups + 1] = { which = which, a = a, b = b, data = data }
    return { data = data }
end

SlashCmdList = {}
function debugstack() return "stub:1: in function" end
C_Texture = { GetAtlasExists = function(name) return WoW.atlases == nil or WoW.atlases[name] == true end }
ChatFrameUtil = { ActivateChat = function() end }
WoW.shownDialogs = {}
function StaticPopupSpecial_Show(frame) if frame then frame:Show() end end
function StaticPopup_ForEachShownDialog(fn)
    for _, d in ipairs(WoW.shownDialogs) do fn(d) end
end

function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_Initialize(dd, fn) dd._init = fn end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton() end
function UIDropDownMenu_SetText(dd, t) dd._ddText = t end

WOW_PROJECT_ID = 18
function date(fmt) return os.date(fmt) end
function canaccessvalue(v) return not issecretvalue(v) end
function UnitRace() return "Human", "Human", 1 end
function UnitFactionGroup() return WoW.faction or "Alliance", WoW.faction or "Alliance" end

function GetBindLocation() return WoW.bindLocation or "Stormwind" end
function PlayerCanTeleport() return true end
function PlayerHasToy(itemID) return WoW.toys[itemID] or false end
C_ToyBox = {}
function C_ToyBox.GetNumToys() local n = 0 for _ in pairs(WoW.toys) do n = n + 1 end return n end
function C_ToyBox.GetNumLearnedDisplayedToys() return C_ToyBox.GetNumToys() end
function C_ToyBox.GetToyFromIndex(i)
    local ids = {}
    for id in pairs(WoW.toys) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids[i] or -1
end
function C_ToyBox.GetToyInfo(itemID) return itemID, WoW.items[itemID] or ("Toy " .. itemID), 134414 end
function C_ToyBox.IsToyUsable() return true end


-- Talents: Forever serves its legacy talent tree through C_Traits.
-- WoW.traits = { [nodeID] = { spellID=, rank=, maxRanks= } }
WoW.traits = {}
C_ClassTalents = {}
function C_ClassTalents.GetActiveConfigID() return 8684966 end
C_Traits = {}
function C_Traits.GetConfigInfo(configID) return { ID = configID, name = "Mage", treeIDs = { 1 } } end
function C_Traits.GetTreeNodes()
    local ids = {}
    for id in pairs(WoW.traits) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end
function C_Traits.GetNodeInfo(_, nodeID)
    local t = WoW.traits[nodeID]
    if not t then return nil end
    return { ID = nodeID, entryIDs = { nodeID * 10 }, currentRank = t.rank or 0, activeRank = t.rank or 0,
             isVisible = true, posX = 0, posY = 0 }
end
function C_Traits.GetEntryInfo(_, entryID)
    local t = WoW.traits[math.floor(entryID / 10)]
    return t and { definitionID = entryID, maxRanks = t.maxRanks or 1 } or nil
end
function C_Traits.GetDefinitionInfo(definitionID)
    local t = WoW.traits[math.floor(definitionID / 10)]
    return t and { spellID = t.spellID } or nil
end

-- Misc globals the addon reads. Not in the dump's lists: UISpecialFrames
-- is FrameXML's (Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:21),
-- YES / NO are GlobalStrings, and LE_PARTY_CATEGORY_INSTANCE is the
-- client's (FrameXML reads it: Blizzard_Channels/Mainline/VoiceUtils.lua:122).
UISpecialFrames = {}
strfind, strsub, format = string.find, string.sub, string.format
YES, NO = "Yes", "No"
LE_PARTY_CATEGORY_INSTANCE = 2
-- The chat frame shows a line as print does: the kit's print records it in
-- WoW.chat and checks it for a stray "|" (the addon prints through
-- DEFAULT_CHAT_FRAME:AddMessage).
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) print(msg) end }
function SendChatMessage(msg, channel) WoW.sent[#WoW.sent + 1] = { msg, channel } end
C_ChatInfo = { SendChatMessage = SendChatMessage }
-- Trade (#8): WoW.trades records InitiateTrade's units; the cursor holds an
-- item ID; WoW.tradeSlots[slot] = the item placed (WoW.tradeRefuses: the
-- slot takes nothing).
WoW.trades, WoW.tradeSlots = {}, {}
function InitiateTrade(unit) WoW.trades[#WoW.trades + 1] = unit end
function CursorHasItem() return WoW.cursor ~= nil end
function GetCursorInfo()
    if WoW.cursor then return "item", WoW.cursor, "item:" .. WoW.cursor end
end
function GetTradePlayerItemLink(slot)
    local id = WoW.tradeSlots[slot]
    return id and ("|Hitem:" .. id .. "::::|h[" .. (WoW.items[id] or "?") .. "]|h") or nil
end
function ClearCursor() WoW.cursor = nil end
function ClickTradeButton(slot)
    if WoW.cursor and not WoW.tradeRefuses then
        WoW.tradeSlots[slot], WoW.cursor = WoW.cursor, nil
        WoW.fire("TRADE_PLAYER_ITEM_CHANGED", slot)
    end
end
function GetTradePlayerItemInfo(slot)
    local id = WoW.tradeSlots[slot]
    return id and WoW.items[id] or nil
end
function IsShiftKeyDown() return WoW.shiftDown or false end
WoW.sounds = {}
WoW.soundHandle = 0
WoW.stopped = {}
function PlaySoundFile(path, channel)
    WoW.sounds[#WoW.sounds + 1] = path
    WoW.soundChannels = WoW.soundChannels or {}
    WoW.soundChannels[#WoW.sounds] = channel
    WoW.soundHandle = WoW.soundHandle + 1
    return true, WoW.soundHandle
end
function StopSound(handle) WoW.stopped[#WoW.stopped + 1] = handle end
-- Sound kits: WoW.kits records each played; WoW.refusedKits[kit] = true
-- makes the client refuse one (willPlay false).
function PlaySound(kit, channel)
    if WoW.refusedKits[kit] then return false end
    WoW.kits[#WoW.kits + 1] = kit
    WoW.soundHandle = WoW.soundHandle + 1
    return true, WoW.soundHandle
end
-- Macros and action bars (launcher).
function GetActionInfo() return nil end
function GetMacroInfo() return nil end
function GetMacroIndexByName() return 0 end
function GetNumMacros() return 0, 0 end
function GetBindingKey() return nil end
function GetBindingText(k) return k end

function IsLoggedIn() return true end
-- Camera (LibShowcase).
WoW.camera = { zoom = 10, views = {}, view = 1, yaw = 0 }
function GetCameraZoom() return WoW.camera.zoom end
function CameraZoomIn(d) WoW.camera.zoom = WoW.camera.zoom - (d or 0) end
function CameraZoomOut(d) WoW.camera.zoom = WoW.camera.zoom + (d or 0) end
function SaveView(slot) WoW.camera.views[slot] = WoW.camera.zoom end
function SetView(slot) WoW.camera.view = slot end
function ResetView() end
function MoveViewLeftStart(s) WoW.camera.yaw = -(s or 1) end
function MoveViewLeftStop() WoW.camera.yaw = 0 end
function MoveViewRightStart(s) WoW.camera.yaw = s or 1 end
function MoveViewRightStop() WoW.camera.yaw = 0 end
function ConsoleExec() end
function IsMounted() return false end

-- CVars and the game UI.
WoW.cvars = { ActionButtonUseKeyDown = "1" }
function GetCVar(name) return WoW.cvars[name] end
function SetCVar(name, value) WoW.cvars[name] = tostring(value) return true end
C_CVar = {}
function C_CVar.GetCVar(name) return WoW.cvars[name] end
function C_CVar.SetCVar(name, value) WoW.cvars[name] = tostring(value) return true end
WoW.uiVisible = true
function SetUIVisibility(v) WoW.uiVisible = v and true or false end
GameEvent = {}
function GameEvent.UnregisterInternalEvent() end
function GameEvent.RegisterInternalEvent() end
function GameEvent.HandleExperimentalCVarConfirmationNeeded() end


------------------------------------------------------------
-- The vendor window (#59): Mainline's MerchantFrame, as the client loads it
-- (docs/FOREVER-PROBE.md run 3; wow-ui-source Blizzard_UIPanels_Game/
-- Mainline/MerchantFrame.lua and .xml). WoW.merchant = { { id, name, price,
-- usable }, ... } is what the vendor sells. Blizzard's redraw is modelled
-- far enough for a test: each slot's button ID, name and price, the page.
------------------------------------------------------------

WoW.merchant = {}
MERCHANT_ITEMS_PER_PAGE = 10
MERCHANT_PAGE_NUMBER = "Page %s of %s"
MAX_MONEY_DISPLAY_WIDTH = 120
function GetMerchantNumItems() return #WoW.merchant end
function GetMerchantItemID(i) return WoW.merchant[i] and WoW.merchant[i][1] end
function GetMerchantItemLink(i) return WoW.merchant[i] and ("item:" .. WoW.merchant[i][1]) end
function CanAffordMerchantItem() return true end
C_MerchantFrame = {}
function C_MerchantFrame.GetItemInfo(i)
    local m = WoW.merchant[i]
    if not m then return nil end
    return { name = m[2], texture = 133738, price = m[3], stackCount = 1, numAvailable = -1,
             isPurchasable = true, isUsable = m[4] ~= false, hasExtendedCost = false }
end
function C_MerchantFrame.IsMerchantItemRefundable() return true end
-- A named frame is a global, as the client's are; the XML's font strings
-- inherit GameFontNormal (or a font like it).
local function named(kind, parent, name)
    local w = kind == "FontString" and Methods.CreateFontString(parent, name, "ARTWORK", "GameFontNormal")
        or newWidget(kind, parent, name)
    rawset(_G, name, w)
    return w
end
named("Frame", UIParent, "MerchantFrame")
MerchantFrame.page, MerchantFrame.selectedTab = 1, 1
MerchantFrame:Hide()
named("Frame", MerchantFrame, "MerchantExtraCurrencyInset")
named("FontString", MerchantFrame, "MerchantPageText")
named("Button", MerchantFrame, "MerchantPrevPageButton")
named("Button", MerchantFrame, "MerchantNextPageButton")
named("Button", MerchantFrame, "MerchantPageTurnIndicatorLeft")
named("Button", MerchantFrame, "MerchantPageTurnIndicatorRight")
MerchantPageTurnIndicatorLeft:Hide()
MerchantPageTurnIndicatorRight:Hide()
for i = 1, 10 do
    local slot = named("Frame", MerchantFrame, "MerchantItem" .. i)
    local button = named("Button", slot, "MerchantItem" .. i .. "ItemButton")
    button.IconQuestTexture = newWidget("Texture", button)
    named("FontString", slot, "MerchantItem" .. i .. "Name")
    named("Frame", slot, "MerchantItem" .. i .. "MoneyFrame")
    named("Frame", slot, "MerchantItem" .. i .. "AltCurrencyFrame")
end
-- ItemButtonTemplate's and MoneyFrame's helpers (SharedXML ItemButtonTemplate.lua,
-- MoneyFrame.lua): the price shown is kept on the money frame.
function SetItemButtonCount() end
function SetItemButtonStock() end
function SetItemButtonTexture(b, t) b._texture = t end
function SetItemButtonDesaturated() end
function SetItemButtonNameFrameVertexColor() end
function SetItemButtonSlotVertexColor() end
function SetItemButtonTextureVertexColor(b, r, g, bl) b._tint = { r, g, bl } end
function SetItemButtonNormalTextureVertexColor() end
function MoneyFrame_SetMaxDisplayWidth() end
function MoneyFrame_Update(name, price) _G[name]._price = price end
function SetMoneyFrameColor() end
function MerchantFrameItem_UpdateQuality() end
function MerchantFrame_UpdateMerchantInfo()
    local n = GetMerchantNumItems()
    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local index = (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE + i
        local button, info = _G["MerchantItem" .. i .. "ItemButton"], C_MerchantFrame.GetItemInfo(index)
        _G["MerchantItem" .. i .. "Name"]:SetText(info and info.name or "")
        _G["MerchantItem" .. i .. "MoneyFrame"]._price = info and info.price
        button:SetID(info and index or 0)
        button:SetShown(info ~= nil)
    end
    MerchantPageText:SetFormattedText(MERCHANT_PAGE_NUMBER, MerchantFrame.page, math.ceil(n / MERCHANT_ITEMS_PER_PAGE))
    MerchantNextPageButton:SetEnabled(MerchantFrame.page < math.ceil(n / MERCHANT_ITEMS_PER_PAGE))
end
function MerchantFrame_Update()
    if MerchantFrame.selectedTab == 1 then MerchantFrame_UpdateMerchantInfo() end
end
-- TooltipDataProcessor (Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua):
-- the post-calls registered per data type, for a test to run on a tooltip.
WoW.tooltipPostCalls = {}
TooltipDataProcessor = {}
function TooltipDataProcessor.AddTooltipPostCall(dataType, fn)
    WoW.tooltipPostCalls[dataType] = WoW.tooltipPostCalls[dataType] or {}
    table.insert(WoW.tooltipPostCalls[dataType], fn)
end
------------------------------------------------------------
-- Strict globals
------------------------------------------------------------

-- The onReset state above, set once before the first test line.
WoW.reset()

-- Names the client does not have, or that start nil. Reading one returns
-- nil instead of failing the test, so guarded feature checks still run.
-- Any other read of an undefined global fails the test.
Kit.strict({
    -- Removed on Forever (forever-api-1.60.1.70009.md).
    AnimateTexCoords = true, InterfaceOptions_AddCategory = true,
    InterfaceOptionsFrame_OpenToCategory = true, GetItemInfo = true,
    GetItemIcon = true, UnitBuff = true, UnitDebuff = true, UnitAura = true,
    GetTalentTabInfo = true, GetNumTalentTabs = true, UseItemByName = true,
    MouseIsOver = true, GetContainerNumSlots = true, GetContainerItemLink = true,
    GetContainerItemInfo = true, GetItemCooldown = true, MAX_PLAYER_LEVEL = true,
    -- SavedVariables, nil until the client would have loaded them.
    OneTwoThreeDB = true, OneTwoThreeProbeDB = true,
    -- PORTING-TBC-TO-FOREVER.md: the bare global is gone; use C_SpellBook.
    IsSpellKnown = true,
    -- Present on Mainline; the addon guards for it. Absent in the stub world.
    AddonCompartmentFrame = true,
    -- Libraries: nil until their file loads.
    LibStub = true,
})
