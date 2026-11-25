-- Grimoires (#59): what each demon knows is remembered whenever it is out,
-- and a demon trainer's grimoires every learner knows are hidden; the
-- tooltip says what each demon knows.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

WoW.spells[688] = { name = "Summon Imp", known = true }
WoW.spells[697] = { name = "Summon Voidwalker", known = true }
WoW.spells[712] = { name = "Summon Succubus", known = false }
WoW.spells[713] = { name = "Summon Incubus", known = false }
WoW.spells[691] = { name = "Summon Felhunter", known = false }

local IMP = "Pet-0-58875-0-13999463-416-4D4587EE1C"        -- run 3's
local VOID = "Pet-0-65218-0-5724454-1860-CBEB860B18"       -- run 3's
local SUCCUBUS = "Pet-0-1-0-1-1863-000000000A"
local function pet(guid, spells)
    WoW.petGUID = guid
    WoW.petSpells = spells or {}
    WoW.fire("UNIT_PET", "player")
end

local ns = H.loadAddon()
local G, Data = ns.Grimoires, ns.Data

-- The table: 59 grimoires, each rank's spell in PET_RANKS, every ability
-- learnable by a demon.
local count = 0
for item, g in pairs(Data.GRIMOIRES) do
    count = count + 1
    check(Data.PET_RANKS[g[1]] and Data.PET_RANKS[g[1]][g[2]], "a spell for grimoire " .. item)
    check(G.LEARNERS[g[1]], "a demon learns " .. g[1])
end
eq(count, 59, "59 grimoires (client data 71139)")
eq(Data.PET_RANKS["Firebolt"][2], 7799, "Grimoire of Firebolt (Rank 2) teaches 7799 (run 3)")

-- The Imp: only its highest rank reads known (run 3: Firebolt 2, not 1).
pet(IMP, { [7799] = true, [6307] = true })
local imp = ns.char.grimoires[688]
eq(imp and imp["Firebolt"], 2, "the Imp's Firebolt: rank 2")
eq(imp["Blood Pact"], 1, "Blood Pact 1")
eq(imp["Fire Shield"], 0, "no Fire Shield")
-- A spellbook not filled yet (right after UNIT_PET) keeps what was read.
pet(IMP, {})
eq(ns.char.grimoires[688]["Firebolt"], 2, "an empty read keeps the record")
-- A subjugated demon isn't one of ours.
pet("Pet-0-1-0-1-6268-000000000B", { [3716] = true })
eq(ns.char.grimoires[697], nil, "a subjugated demon is ignored")
pet(nil)

-- The vendor: the Imp's Firebolt 2-4 and Blood Pact 1-2, the Voidwalker's
-- Torment 2 (in that order, as run 3's trainer lists them).
local function sells(list)
    WoW.merchant = list
    MerchantFrame.page = 1
    MerchantFrame:Show()
    WoW.fire("MERCHANT_SHOW")
    MerchantFrame_Update()
end
local function slotID(i) return _G["MerchantItem" .. i .. "ItemButton"]:GetID() end
local function slotShown(i) return _G["MerchantItem" .. i .. "ItemButton"]:IsShown() end
local STOCK = {
    { 16302, "Grimoire of Firebolt (Rank 2)", 100 }, { 16316, "Grimoire of Firebolt (Rank 3)", 1500 },
    { 16317, "Grimoire of Firebolt (Rank 4)", 5000 }, { 16321, "Grimoire of Blood Pact (Rank 1)", 100 },
    { 16322, "Grimoire of Blood Pact (Rank 2)", 900 }, { 16346, "Grimoire of Torment (Rank 2)", 2000 },
}
sells(STOCK)
check(G.check:IsShown(), "the checkbox shows at a demon trainer")
check(G.check:GetChecked(), "on by default")
eq(slotID(1), 2, "Firebolt 2 is known: the first slot is Firebolt 3")
eq(_G.MerchantItem1Name:GetText(), "Grimoire of Firebolt (Rank 3)", "with its name")
eq(_G.MerchantItem1MoneyFrame._price, 1500, "and its price")
eq(_G.MerchantItem1MoneyFrame._maxWidth, 120, "at Blizzard's price width (its file-local 120)")
eq(slotID(3), 5, "Blood Pact 1 known: Blood Pact 2 follows Firebolt 4")
eq(slotID(4), 6, "the Voidwalker not read yet: its Torment 2 stays")
check(not slotShown(5), "the slots after the last are empty")
eq(G.hidden, 2, "two hidden")

-- The Voidwalker read with Torment 1: Torment 2 is still to buy.
pet(VOID, { [3716] = true })
eq(ns.char.grimoires[697]["Torment"], 1, "the Voidwalker's Torment: rank 1")
eq(slotID(4), 6, "Torment 2 stays")
-- Rank 2 learned while its tooltip is up: hidden, without closing the
-- window (SPELLS_CHANGED), and the tooltip over the now-empty slot goes.
MerchantItemButton_OnEnter(_G.MerchantItem4ItemButton)
WoW.petSpells = { [7809] = true }
WoW.fire("SPELLS_CHANGED")
check(not slotShown(4), "Torment 2 learned: hidden at once")
check(not GameTooltip:IsShown(), "and the tooltip over its slot is hidden")
-- The Imp learns Firebolt 3 with its tooltip up: the slot now holds
-- Firebolt 4, and the tooltip is rebuilt for it before a click buys it.
MerchantItemButton_OnEnter(_G.MerchantItem1ItemButton)
eq(GameTooltip._text, "item:16316", "hovering Firebolt 3")
pet(IMP, { [7800] = true, [6307] = true })
eq(slotID(1), 3, "Firebolt 3 learned: the first slot is Firebolt 4")
check(GameTooltip:IsShown(), "the tooltip stays up")
eq(GameTooltip._text, "item:16317", "rebuilt for Firebolt 4, the item a click buys")
-- Nothing changed under it: left alone.
GameTooltip._text = "untouched"
MerchantFrame_Update()
eq(GameTooltip._text, "untouched", "a redraw that moves nothing leaves the tooltip")
-- Back to what follows expects: the Imp's run 3 ranks, the Voidwalker out.
ns.char.grimoires[688] = { ["Firebolt"] = 2, ["Blood Pact"] = 1, ["Fire Shield"] = 0, ["Phase Shift"] = 0 }
pet(VOID, { [7809] = true })

-- The tooltip: what each demon of yours knows.
local function tooltip(slot)
    GameTooltip:SetOwner(UIParent)
    GameTooltip:SetText("item")
    local id = GetMerchantItemID(_G["MerchantItem" .. slot .. "ItemButton"]:GetID())
    for _, fn in ipairs(WoW.tooltipPostCalls[0] or {}) do fn(GameTooltip, { id = id }) end
    return table.concat(GameTooltip._lines or {}, "\n")
end
check(tooltip(1):find("Imp: knows rank 2", 1, true), "Firebolt 3: the Imp knows rank 2")

-- The checkbox off: Blizzard's own page.
G.check:SetChecked(false)
G.check:GetScript("OnClick")(G.check)
eq(ns.db.hideKnownGrimoires, false, "the checkbox saves the option")
eq(slotID(1), 1, "off: nothing hidden")
check(tooltip(1):find("Imp: knows rank 2", 1, true), "the tooltip line stays")
G.check:SetChecked(true)
G.check:GetScript("OnClick")(G.check)
eq(slotID(1), 2, "on again")

-- Pages: run 3's trainer, 38 grimoires (the Imp's and the Voidwalker's).
-- The Imp knows every Firebolt and Blood Pact, the Voidwalker Torment 2:
-- 12 hidden, 26 on three pages; Blizzard's page 4 is brought back to 3.
local trainer = {}
for item = 16302, 16366 do
    if Data.GRIMOIRES[item] then trainer[#trainer + 1] = { item, "G" .. item, 100 } end
end
eq(#trainer, 38, "run 3's 38 grimoires")
ns.char.grimoires[688] = { ["Firebolt"] = 7, ["Blood Pact"] = 5, ["Fire Shield"] = 0, ["Phase Shift"] = 0 }
sells(trainer)
eq(G.hidden, 12, "Firebolt 2-7, Blood Pact 1-5 and Torment 2 hidden")
eq(slotID(1), 12, "page 1 starts at Fire Shield 1")
MerchantFrame.page = 4
MerchantFrame_Update()
eq(MerchantFrame.page, 3, "Blizzard's page 4 of 4 is our last, 3")
eq(MerchantPageText:GetText(), "Page 3 of 3", "the page text counts what is shown")
check(not MerchantNextPageButton:IsEnabled(), "no next page")
check(MerchantPrevPageButton:IsEnabled(), "a previous one")
eq(slotID(6), 38, "the last page ends on Suffering 4")
check(not slotShown(7), "and its other slots are empty")

-- Not a demon trainer (a Soul Shard among them): left alone.
sells({ { 16316, "Grimoire of Firebolt (Rank 3)", 1500 }, { 6265, "Soul Shard", 10 } })
check(not G.check:IsShown(), "no checkbox at another vendor")
eq(slotID(1), 1, "nothing hidden there")

-- The Succubus and the Incubus learn the same grimoires, each on its own
-- (the owner): hidden only when both (if you have both) know it; an Incubus
-- never summoned keeps it shown.
WoW.spells[712].known = true
pet(SUCCUBUS, { [7815] = true })   -- Lash of Pain 2
sells({ { 16368, "Grimoire of Lash of Pain (Rank 2)", 100 } })
check(not slotShown(1), "the Succubus knows Lash of Pain 2: hidden")
WoW.spells[713].known = true
MerchantFrame_Update()
check(slotShown(1), "with the Incubus learned and never read: shown")
check(tooltip(1):find("summon it once", 1, true), "and the tooltip says to summon it once")

-- Every widget method called exists on that widget type in the pinned build.
Kit.checkMethods()
eq(#WoW.strays, 0, "no stray |")
done("test_grimoires")
