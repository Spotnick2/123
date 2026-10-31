-- ============================================================
-- Healthstone requests (#8): who asked for a healthstone, and the trade.
--
-- A keyword ("hs", "healthstone", the player's own) in party, raid or
-- instance chat, or whispered, asks. The whole message must be a keyword,
-- compared as the summon queue does. People are keyed on GUID; asking
-- again refreshes. A whisper from outside the group asks only with
-- db.stones.strangers on; trading them needs them targeted (no group unit).
--
-- Nothing is delivered on its own: the player opens the trade (a click on
-- the prompt), places the stone (another click), and accepts in the
-- game's trade window. A trade the requester opens counts too. A request
-- ends when a trade with them closes with the stone in it, when they
-- leave the group, after TIMEOUT, or by Skip.
-- ============================================================

local _, ns = ...
if ns.skip then return end

local API = ns.API
local Data = ns.Data

local Requests = {
    entries = {},      -- { guid, name, class, at, stranger, test }, oldest first
    listeners = {},
}
ns.Requests = Requests

Requests.TIMEOUT = 5 * 60
local TICK = 15

local function indexOf(guid)
    for i, e in ipairs(Requests.entries) do
        if e.guid == guid then return i end
    end
    return nil
end

function Requests:Find(guid)
    local i = indexOf(guid)
    return i and self.entries[i] or nil
end

function Requests:OnChanged(fn)
    self.listeners[#self.listeners + 1] = fn
end

function Requests:Changed()
    for _, fn in ipairs(self.listeners) do fn() end
    if #self.entries == 0 then
        if self.ticker then self.ticker:Cancel(); self.ticker = nil end
    elseif not self.ticker then
        self.ticker = C_Timer.NewTicker(TICK, function() self:Prune() end)
    end
end

function Requests:Matches(text)
    if type(text) ~= "string" or not API.Readable(text) then return false end
    local said = ns.Queue.Normalize(text)
    for _, word in ipairs(ns.db.stones.keywords) do
        if said == word then return true end
    end
    return false
end

function Requests:Add(guid, name, class, stranger, test)
    local e = self:Find(guid)
    if e then
        e.at = GetTime()
        self:Changed()
        return false
    end
    self.entries[#self.entries + 1] = {
        guid = guid, name = name, class = class, at = GetTime(), stranger = stranger, test = test,
    }
    ns.Sound:Play("stoneRequest")
    self:Changed()
    return true
end

function Requests:Remove(guid)
    local i = indexOf(guid)
    if not i then return false end
    table.remove(self.entries, i)
    if self.trading == guid then self.trading, self.placed = nil, nil end
    self:Changed()
    return true
end

function Requests:Clear()
    if #self.entries == 0 then return end
    self.entries, self.trading, self.placed = {}, nil, nil
    self:Changed()
end

-- Drops whoever waited past TIMEOUT, and group members who left (a
-- stranger was never in the group; a test entry only times out).
function Requests:Prune()
    local now, kept = GetTime(), {}
    for _, e in ipairs(self.entries) do
        local gone = not e.stranger and not e.test and not ns.Queue.UnitOf(e.guid)
        if now - e.at < Requests.TIMEOUT and not gone then kept[#kept + 1] = e end
    end
    if #kept ~= #self.entries then
        self.entries = kept
        self:Changed()
    end
end

-- A chat line: text, sender name, ..., GUID (12th). `whisper` for
-- CHAT_MSG_WHISPER.
function Requests:OnChat(text, sender, guid, whisper)
    if not ns.db.stones.enabled or not self:Matches(text) then return false end
    if type(guid) ~= "string" or not API.Readable(guid) then return false end
    if guid == API.UnitGUID("player") then return false end
    local unit = ns.Queue.UnitOf(guid)
    if unit then
        local _, class = UnitClass(unit)
        return self:Add(guid, GetUnitName(unit, false), API.Readable(class) and class or nil)
    end
    if not (whisper and ns.db.stones.strangers) then return false end
    if type(sender) ~= "string" or not API.Readable(sender) then return false end
    return self:Add(guid, sender, nil, true)
end

------------------------------------------------------------
-- The trade
------------------------------------------------------------

-- The best healthstone carried, or nil. Any rank: the requester's needs,
-- not the player's level, decide what they can use.
function Requests.Stone()
    for _, tier in ipairs(Data.HEALTHSTONE_TIERS) do
        local id = API.FirstCarried(tier.items)
        if id then return id end
    end
    return nil
end

-- The unit to trade with: a member's token, or "target" when a stranger
-- is targeted. nil otherwise.
function Requests.UnitFor(entry)
    if entry.test then return nil end
    if entry.stranger then
        return API.UnitGUID("target") == entry.guid and "target" or nil
    end
    return ns.Queue.UnitOf(entry.guid)
end

-- The prompt's first button: open the trade with them. Returns true when
-- asked of the client, or false and why: "test", "target", "stone".
function Requests:OpenTrade(entry)
    if entry.test then return false, "test" end
    if not Requests.Stone() then return false, "stone" end
    local unit = Requests.UnitFor(entry)
    if not unit then return false, "target" end
    self.trading, self.placed = entry.guid, nil
    pcall(InitiateTrade, unit)
    return true
end

-- A healthstone (any rank) in the player's side of the open trade.
function Requests.TradeHasStone()
    for slot = 1, 6 do
        local id = API.TradeItemID(slot)
        for _, tier in ipairs(Data.HEALTHSTONE_TIERS) do
            for _, itemID in ipairs(tier.items) do
                if id == itemID then return true end
            end
        end
    end
    return false
end

-- The prompt's second button, once the trade with them is open: the best
-- healthstone into the first empty slot. Only that stone ever goes in
-- (Codex on #53): with something already on the cursor nothing is touched;
-- the slot is clicked only once the cursor holds the stone picked up (a
-- locked stone leaves it empty, run 2); and it counts as placed only if
-- the slot then holds that stone's ID. Returns true, or false and why:
-- "cursor" (holding something), "place". A stone already in the trade is
-- left there: a repeat click changes nothing (Codex on #53).
function Requests:PlaceStone()
    if Requests.TradeHasStone() then
        self.placed = true
        return true
    end
    if API.CursorItem() ~= nil then return false, "cursor" end
    local itemID = Requests.Stone()
    local bag, slot
    if itemID then bag, slot = API.FindItem(itemID) end
    local tradeSlot = API.TradeSlotFree()
    if not (bag and tradeSlot) then return false, "place" end
    pcall(C_Container.PickupContainerItem, bag, slot)
    local kind, held = API.CursorItem()
    if kind == "item" and held == itemID then pcall(ClickTradeButton, tradeSlot) end
    -- Whatever is on the cursor now came from that pickup: back to the bags.
    if API.CursorItem() ~= nil then pcall(ClearCursor) end
    self.placed = API.TradeItemID(tradeSlot) == itemID
    if self.placed then return true end
    return false, "place"
end

-- The open trade, if it is with someone who asked.
function Requests:TradeEntry()
    return self.tradeOpen and self.trading and self:Find(self.trading) or nil
end

function Requests:Initialize()
    for _, event in ipairs(ns.Queue.CHAT_EVENTS) do
        ns.Events:Register(event, function(_, ...)
            self:OnChat((...), (select(2, ...)), (select(12, ...)), false)
        end)
    end
    ns.Events:Register("CHAT_MSG_WHISPER", function(_, ...)
        self:OnChat((...), (select(2, ...)), (select(12, ...)), true)
    end)
    ns.Events:Register("GROUP_ROSTER_UPDATE", function() self:Prune() end)
    -- A trade with someone who asked, whoever opened it.
    ns.Events:Register("TRADE_SHOW", function()
        local partner = API.TradePartner()
        self.tradeOpen = true
        if partner and self:Find(partner) then
            if self.trading ~= partner then self.placed = nil end
            self.trading = partner
        else
            self.trading = nil
        end
        self:Changed()
    end)
    -- `placed` follows what the trade holds: a stone taken back out by
    -- hand isn't placed any more.
    ns.Events:Register("TRADE_PLAYER_ITEM_CHANGED", function()
        if not self.tradeOpen then return end
        self.placed = Requests.TradeHasStone()
        self:Changed()
    end)
    -- Closed after the stone was placed: their request is done, accepted
    -- or not (they can ask again). Closed before: it stays.
    ns.Events:Register("TRADE_CLOSED", function()
        local guid, placed = self.trading, self.placed
        self.tradeOpen, self.trading, self.placed = false, nil, nil
        if guid and placed then self:Remove(guid) else self:Changed() end
    end)
end

-- /123 hs test: a made-up request, to see the prompt alone.
function Requests:Test()
    return self:Add("Test-0-123-0009", "Ashka Vale", "MAGE", false, true)
end
