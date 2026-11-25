-- ============================================================
-- Grimoires (#59): at a demon trainer, hide the grimoires your demons
-- already know. On by default: a checkbox on the vendor window, mirrored
-- on the options page.
--
-- What a demon knows (docs/FOREVER-PROBE.md run 3, build 71139):
-- C_SpellBook.IsSpellKnown(petSpell, Enum.SpellBookSpellBank.Pet) answers
-- for the summoned demon only, and only its highest rank reads known. So
-- whenever one of the Warlock's own demons is out, its highest rank of each
-- of its abilities is remembered per character (ns.char.grimoires[summon]).
-- A grimoire is hidden when every demon of yours that can learn it has been
-- read and knows that rank or a higher one: a demon not read since 123 was
-- installed keeps its grimoires shown. Never hide on a guess.
--
-- The vendor window is Mainline's MerchantFrame (run 3). After Blizzard's
-- redraw (a post-hook, never a replacement) the ten slots are drawn again
-- from the list of grimoires still shown, as Blizzard draws a plain-gold
-- item (Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua,
-- MerchantFrame_UpdateMerchantInfo), and SetID(index) keeps buying and the
-- tooltip on the real item. Only a vendor whose every item is a grimoire
-- in the table, sold for gold, is touched. The window isn't protected.
-- ============================================================

local _, ns = ...
if ns.skip then return end

local API = ns.API
local Data = ns.Data
local L = ns.L

local Grimoires = {}
ns.Grimoires = Grimoires

-- The demons able to learn each ability, by summon spell.
local LEARNERS = {}
for summon, abilities in pairs(Data.DEMON_ABILITIES) do
    for _, ability in ipairs(abilities) do
        LEARNERS[ability] = LEARNERS[ability] or {}
        table.insert(LEARNERS[ability], summon)
    end
end
Grimoires.LEARNERS = LEARNERS

function Grimoires:Known()
    if type(ns.char.grimoires) ~= "table" then ns.char.grimoires = {} end
    return ns.char.grimoires
end

-- true / false, or nil when the client can't say.
local function petKnows(spellID)
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
    if not bank then return nil end
    local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID, bank)
    if not ok or not API.Readable(known) then return nil end
    return known == true
end

-- Remember the summoned demon's ranks, if it is one of the Warlock's own
-- (a subjugated demon isn't in Data.DEMON_NPC). Every demon knows rank 1 of
-- something: a read with nothing known is a spellbook not filled yet (right
-- after UNIT_PET), and keeps what was remembered.
function Grimoires:ReadPet()
    local summon = ns.Bar.PetSummon()
    local abilities = summon and Data.DEMON_ABILITIES[summon]
    if not abilities then return false end
    local ranks, any = {}, false
    for _, ability in ipairs(abilities) do
        local spells = Data.PET_RANKS[ability]
        local best = 0
        for rank = #spells, 1, -1 do
            local known = petKnows(spells[rank])
            if known == nil then return false end
            if known then best = rank break end
        end
        ranks[ability] = best
        if best > 0 then any = true end
    end
    if not any then return false end
    self:Known()[summon] = ranks
    return true
end

-- Known by every demon of yours that can learn it (a summon you know), at
-- its rank or higher.
function Grimoires:IsKnown(itemID)
    local grimoire = Data.GRIMOIRES[itemID]
    if not grimoire then return false end
    local ability, rank = grimoire[1], grimoire[2]
    local known, any = self:Known(), false
    for _, summon in ipairs(LEARNERS[ability] or {}) do
        if API.IsKnown(summon) then
            any = true
            local demon = known[summon]
            if type(demon) ~= "table" or (tonumber(demon[ability]) or 0) < rank then return false end
        end
    end
    return any
end

------------------------------------------------------------
-- The vendor window
------------------------------------------------------------

-- A price's widest, as Blizzard draws a plain-gold item: its file-local
-- MAX_MONEY_DISPLAY_WIDTH (Mainline/MerchantFrame.lua:5), not a global
-- (Codex, PR #66).
local MONEY_WIDTH = 120

-- Every item a grimoire in the table, for gold: a demon trainer.
local function demonTrainer()
    local n = API.Number(GetMerchantNumItems())
    if not n or n == 0 then return nil end
    for index = 1, n do
        if not Data.GRIMOIRES[GetMerchantItemID(index)] then return nil end
        local info = C_MerchantFrame.GetItemInfo(index)
        if type(info) ~= "table" or info.hasExtendedCost or info.currencyID then return nil end
    end
    return n
end

-- One slot, as Blizzard draws a plain-gold item (or an empty slot).
local function drawSlot(slot, index)
    local merchantButton = _G["MerchantItem" .. slot]
    local itemButton = _G["MerchantItem" .. slot .. "ItemButton"]
    local name = _G["MerchantItem" .. slot .. "Name"]
    local money = _G["MerchantItem" .. slot .. "MoneyFrame"]
    local altCurrency = _G["MerchantItem" .. slot .. "AltCurrencyFrame"]
    local info = index and C_MerchantFrame.GetItemInfo(index)
    if type(info) ~= "table" then
        itemButton.price, itemButton.hasItem, itemButton.name = nil, nil, nil
        itemButton:Hide()
        SetItemButtonNameFrameVertexColor(merchantButton, 0.5, 0.5, 0.5)
        SetItemButtonSlotVertexColor(merchantButton, 0.4, 0.4, 0.4)
        name:SetText("")
        money:Hide()
        altCurrency:Hide()
        return
    end
    local link = GetMerchantItemLink(index)
    name:SetText(info.name)
    SetItemButtonCount(itemButton, info.stackCount)
    SetItemButtonStock(itemButton, info.numAvailable)
    SetItemButtonTexture(itemButton, info.texture)
    itemButton.price, itemButton.extendedCost = info.price, nil
    itemButton.name, itemButton.link, itemButton.texture = info.name, link, info.texture
    MoneyFrame_SetMaxDisplayWidth(money, MONEY_WIDTH)
    MoneyFrame_Update(money:GetName(), info.price)
    SetMoneyFrameColor(money:GetName(), CanAffordMerchantItem(index) == false and "gray" or nil)
    altCurrency:Hide()
    money:Show()
    itemButton.IconQuestTexture:Hide()
    MerchantFrameItem_UpdateQuality(merchantButton, link)
    itemButton.showNonrefundablePrompt = not C_MerchantFrame.IsMerchantItemRefundable(index)
    itemButton.hasItem = true
    itemButton:SetID(index)
    itemButton:Show()
    SetItemButtonDesaturated(itemButton, false)
    local tintRed = not info.isPurchasable or not info.isUsable
    if info.numAvailable == 0 then   -- sold out: dark red, or grey
        local gb = tintRed and 0 or 0.5
        SetItemButtonNameFrameVertexColor(merchantButton, 0.5, gb, gb)
        SetItemButtonSlotVertexColor(merchantButton, 0.5, gb, gb)
        SetItemButtonTextureVertexColor(itemButton, 0.5, gb, gb)
        SetItemButtonNormalTextureVertexColor(itemButton, 0.5, gb, gb)
    elseif tintRed then
        SetItemButtonNameFrameVertexColor(merchantButton, 1.0, 0, 0)
        SetItemButtonSlotVertexColor(merchantButton, 1.0, 0, 0)
        SetItemButtonTextureVertexColor(itemButton, 0.9, 0, 0)
        SetItemButtonNormalTextureVertexColor(itemButton, 0.9, 0, 0)
    else
        SetItemButtonNameFrameVertexColor(merchantButton, 0.5, 0.5, 0.5)
        SetItemButtonSlotVertexColor(merchantButton, 1.0, 1.0, 1.0)
        SetItemButtonTextureVertexColor(itemButton, 1.0, 1.0, 1.0)
        SetItemButtonNormalTextureVertexColor(itemButton, 1.0, 1.0, 1.0)
    end
end

-- The page buttons for `pages` pages (Blizzard's paging, on our count).
local function drawPaging(pages)
    local page = MerchantFrame.page
    MerchantPageText:SetFormattedText(MERCHANT_PAGE_NUMBER, page, pages)
    local multi = pages > 1
    MerchantPageText:SetShown(multi)
    MerchantPrevPageButton:SetEnabled(multi and page > 1)
    MerchantNextPageButton:SetEnabled(multi and page < pages)
    local gamepad = MerchantPageTurnIndicatorLeft and MerchantPageTurnIndicatorLeft:IsShown()
    if gamepad then
        MerchantPageTurnIndicatorLeft:SetEnabled(MerchantPrevPageButton:IsEnabled())
        MerchantPageTurnIndicatorRight:SetEnabled(MerchantNextPageButton:IsEnabled())
    else
        MerchantPrevPageButton:SetShown(multi)
        MerchantNextPageButton:SetShown(multi)
    end
end

-- The tooltip over a slot whose item just changed is rebuilt for the new
-- one, or hidden (Codex, PR #66): Blizzard's click buys the button's ID at
-- once, while the tooltip only refreshes on a timer, so a rank learned with
-- the window open could leave the old grimoire's tooltip over the next one.
-- `before` is what each slot showed until now.
local function settleTooltip(before)
    local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
    for slot = 1, MERCHANT_ITEMS_PER_PAGE do
        local button = _G["MerchantItem" .. slot .. "ItemButton"]
        if owner == button and before[slot] ~= Grimoires.slotIDs[slot] then
            if button:IsShown() and button.hasItem then
                MerchantItemButton_OnEnter(button)
            else
                GameTooltip:Hide()
            end
        end
    end
end

-- After Blizzard's redraw of the Merchant tab: ours, then the tooltip.
function Grimoires:Redraw()
    local before = self.slotIDs or {}
    self:Remap()
    self.slotIDs = {}
    for slot = 1, MERCHANT_ITEMS_PER_PAGE do
        local button = _G["MerchantItem" .. slot .. "ItemButton"]
        self.slotIDs[slot] = button:IsShown() and button:GetID() or 0
    end
    settleTooltip(before)
end

-- The grimoires still to show, on the ten slots and their pages.
function Grimoires:Remap()
    local n = demonTrainer()
    if self.check then
        self.check:SetShown(n ~= nil)
        self.check:SetChecked(ns.db.hideKnownGrimoires == true)
    end
    if not n or not ns.db.hideKnownGrimoires then return end
    local shown = {}
    for index = 1, n do
        if not self:IsKnown(GetMerchantItemID(index)) then shown[#shown + 1] = index end
    end
    self.hidden = n - #shown
    if #shown == n then return end   -- nothing to hide: Blizzard's page stands
    local perPage = MERCHANT_ITEMS_PER_PAGE
    local pages = math.max(1, math.ceil(#shown / perPage))
    if MerchantFrame.page > pages then MerchantFrame.page = pages end
    local first = (MerchantFrame.page - 1) * perPage
    for slot = 1, perPage do drawSlot(slot, shown[first + slot]) end
    drawPaging(pages)
end

-- Blizzard's redraw, which our hook follows; only while the Merchant tab
-- of an open vendor window is up.
function Grimoires:Refresh()
    if MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1 then
        MerchantFrame_Update()
    end
end

-- A grimoire's tooltip says what each demon of yours knows, so you know
-- what to buy without summoning anything at the trainer (the owner's ask):
-- the client's own "Already known" speaks for the summoned demon only.
-- Demons whose summon you don't know aren't listed.
function Grimoires:TooltipLines(itemID)
    local grimoire = Data.GRIMOIRES[itemID]
    if not grimoire then return {} end
    local ability, rank = grimoire[1], grimoire[2]
    local known, lines = self:Known(), {}
    for _, summon in ipairs(LEARNERS[ability] or {}) do
        if API.IsKnown(summon) then
            local name = ns.Wheel.DemonName(summon)
            local demon = known[summon]
            local has = type(demon) == "table" and tonumber(demon[ability]) or nil
            if not has then
                lines[#lines + 1] = { L["%s: summon it once so 123 can read it"]:format(name), 0.6, 0.6, 0.6 }
            elseif has >= rank then
                lines[#lines + 1] = { L["%s: knows rank %d"]:format(name, has), 0.25, 1, 0.25 }
            elseif has == 0 then
                lines[#lines + 1] = { L["%s: not learned"]:format(name), 1, 1, 1 }
            else
                lines[#lines + 1] = { L["%s: knows rank %d"]:format(name, has), 1, 1, 1 }
            end
        end
    end
    return lines
end

-- Every item tooltip that shows a grimoire (the vendor's, the bags', a
-- link's): a post-call runs on each build of the tooltip, refreshes
-- included, before it is shown (Blizzard_SharedXMLGame/Tooltip/
-- TooltipDataHandler.lua). As AltStable does on Forever.
local function addTooltipLines(tooltip, data)
    local itemID = API.Number(type(data) == "table" and data.id or nil)
    local lines = itemID and Grimoires:TooltipLines(itemID)
    if not lines or #lines == 0 then return end
    tooltip:AddLine(" ")
    for _, line in ipairs(lines) do tooltip:AddLine(line[1], line[2], line[3], line[4]) end
end

function Grimoires:CreateCheck()
    local check = CreateFrame("CheckButton", nil, MerchantFrame, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("LEFT", MerchantExtraCurrencyInset, "LEFT", 2, 0)
    check.Text:SetText(L["Hide known grimoires"])
    check:SetScript("OnClick", function(button)
        ns.db.hideKnownGrimoires = button:GetChecked() and true or false
        Grimoires:Refresh()
    end)
    check:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Hide known grimoires"])
        GameTooltip:AddLine(L["Hides a grimoire once every demon of yours that can learn it knows that rank. Summon each demon once so 123 can read what it knows."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function() GameTooltip:Hide() end)
    check:Hide()
    self.check = check
end

-- The vendor window's hook, once Blizzard's code is loaded: it is at login
-- on this client (run 3's probe hooked it), and MERCHANT_SHOW tries again.
function Grimoires:HookVendor()
    if self.hooked then return true end
    if not (MerchantFrame and type(MerchantFrame_UpdateMerchantInfo) == "function") then return false end
    self.hooked = true
    self:CreateCheck()
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function() Grimoires:Redraw() end)
    return true
end

function Grimoires:Initialize()
    if self.initialized then return end
    self.initialized = true
    if TooltipDataProcessor and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addTooltipLines)
    end
    local function petChanged(unit)
        if unit ~= nil and unit ~= "player" then return end
        if Grimoires:ReadPet() then Grimoires:Refresh() end
    end
    -- A demon change: UNIT_PET, then SPELLS_CHANGED once its spellbook is
    -- filled (run 3); a rank learned from a grimoire is unmeasured, and
    -- SPELLS_CHANGED is the event that should follow it.
    ns.Events:Register("UNIT_PET", function(_, unit) petChanged(unit) end)
    ns.Events:Register("SPELLS_CHANGED", function() petChanged() end)
    ns.Events:Register("MERCHANT_SHOW", function()
        local late = not Grimoires.hooked and Grimoires:HookVendor()
        Grimoires:ReadPet()
        if late then Grimoires:Refresh() end
    end)
    self:HookVendor()
    self:ReadPet()
end
