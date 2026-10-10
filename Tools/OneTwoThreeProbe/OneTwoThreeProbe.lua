-- ============================================================================
-- OneTwoThreeProbe - dev-only API probe for 123 on WoW: Forever 1.60.1.
--
-- Measures what the Warlock features stand on before code relies on it
-- (issues #1 and #2; ledger in docs/FOREVER-PROBE.md).
--
--   /123probe book               candidate Warlock spell IDs: exist / known / name
--   /123probe pet                active pet: GUID npc id, family, pet bar
--   /123probe stones             shards, healthstones, soulstones: count, cooldown, spell
--   /123probe watch on|off       log ritual casts, summon and trade events
--   /123probe secure <unit>      a secure button: left = Ritual of Summoning on
--                                <unit>, right = best soulstone on <unit>
--   /123probe trade <unit>       a button: click = InitiateTrade(<unit>); on
--                                TRADE_SHOW, records who the trade is with
--   /123probe tradeitem <id>     a button: click = put item <id> in the first
--                                empty trade slot; also tries once from TRADE_SHOW
--   /123probe say <chan> [text]  send to PARTY / RAID / INSTANCE_CHAT now (typed)
--                                and again 1 s later from a timer (not typed)
--   /123probe range              per group member: position, distance, map, range
--   /123probe report | reset
--
-- Results are printed and kept in OneTwoThreeProbeDB.runs (one entry per
-- session, older sessions kept), written on /reload or logout to
-- _classic_beta_\WTF\Account\<id>\SavedVariables\OneTwoThreeProbe.lua.
-- `reset` clears this session's run only.
--
-- Every client global is read with rawget, so an API this client lacks is
-- recorded as missing rather than throwing. Every touch of a returned value
-- happens inside pcall: a secret throws when compared or truth-tested.
--
-- Nothing here ships (.pkgmeta ignores Tools).
-- ============================================================================

local C = "|cff9482c9[123probe]|r "

local function G(name) return rawget(_G, name) end

local function Say(text)
    local chat = G("DEFAULT_CHAT_FRAME")
    if chat then chat:AddMessage(C .. text) end
end

OneTwoThreeProbe = {}

-- One run per session, appended to OneTwoThreeProbeDB.runs: a measurement
-- belongs to the session and build it was taken in, and a /reload between
-- probe commands must not lose the earlier ones. SavedVariables load AFTER
-- this file, so the run is attached to the saved table at ADDON_LOADED.
local DB = { results = {}, log = {} }

local function Attach()
    local saved = G("OneTwoThreeProbeDB")
    if type(saved) ~= "table" then saved = {} end
    if type(saved.runs) ~= "table" then
        -- Files written before runs existed held one session at the top.
        local legacy = saved.results and { build = saved.build, results = saved.results, log = saved.log, book = saved.book }
        saved = { runs = { legacy } }
    end
    DB.started = G("date") and date("%Y-%m-%d %H:%M:%S") or nil
    saved.runs[#saved.runs + 1] = DB
    OneTwoThreeProbeDB = saved
end

local loader = CreateFrame("Frame")
local okReg, registered = pcall(loader.RegisterEvent, loader, "ADDON_LOADED")
if not okReg or registered == false then
    Say("|cffff6060cannot watch ADDON_LOADED: results will not be saved|r")
end
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= "OneTwoThreeProbe" then return end
    Attach()
    self:UnregisterEvent("ADDON_LOADED")
end)

local function IsSecret(v)
    local test = G("issecretvalue")
    if not test then return false end
    local ok, is = pcall(test, v)
    return not ok or is == true
end

-- A value as text, never comparing a secret.
local function Show(v)
    if IsSecret(v) then return "<secret>" end
    if type(v) == "table" then
        local parts = {}
        for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. (IsSecret(x) and "<secret>" or tostring(x)) end
        table.sort(parts)
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

local function Record(key, ...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = Show((select(i, ...))) end
    local text = table.concat(parts, " | ")
    DB.results[key] = text
    Say(key .. ": |cffffffff" .. text .. "|r")
end

-- Call a client function by name (or a function), recording what it
-- returns or that it is missing / threw.
local function Try(key, fn, ...)
    if type(fn) == "string" then
        local name = fn
        local path = {}
        for part in name:gmatch("[^%.]+") do path[#path + 1] = part end
        fn = G(path[1])
        for i = 2, #path do fn = type(fn) == "table" and fn[path[i]] or nil end
        if type(fn) ~= "function" then
            Record(key, "MISSING " .. name)
            return
        end
    end
    local function finish(ok, ...)
        if not ok then
            Record(key, "THREW " .. tostring((...)))
            return
        end
        if select("#", ...) == 0 then Record(key, "(no values)") else Record(key, ...) end
        return ...
    end
    return finish(pcall(fn, ...))
end

local function Log(text)
    local now = G("GetTime") and G("GetTime")() or 0
    DB.log[#DB.log + 1] = string.format("%.2f %s", now, text)
    Say(text)
end

local function InCombat()
    local f = G("InCombatLockdown")
    return f and f() and true or false
end

------------------------------------------------------------
-- Candidate IDs (Vanilla's; Forever reuses them, FCA probe run 6).
------------------------------------------------------------

local SPELLS = {
    { 688, "Summon Imp" }, { 697, "Summon Voidwalker" }, { 712, "Summon Succubus" }, { 713, "Summon Incubus (Forever)" },
    { 691, "Summon Felhunter" }, { 1122, "Inferno" }, { 18540, "Ritual of Doom" },
    { 18708, "Fel Domination" }, { 18788, "Demonic Sacrifice" }, { 19028, "Soul Link" },
    { 698, "Ritual of Summoning" }, { 402265, "Grimoire: Portal of Summoning (learn)" },
    { 687, "Demon Skin 1" }, { 696, "Demon Skin 2" },
    { 706, "Demon Armor 1" }, { 1086, "Demon Armor 2" }, { 11733, "Demon Armor 3" },
    { 11734, "Demon Armor 4" }, { 11735, "Demon Armor 5" }, { 28176, "Fel Armor (TBC)" }, { 403619, "Fel Armor (Forever DB)" },
    { 6201, "Create Healthstone (Minor)" }, { 6202, "Create Healthstone (Lesser)" },
    { 5699, "Create Healthstone" }, { 11729, "Create Healthstone (Greater)" },
    { 11730, "Create Healthstone (Major)" },
    { 693, "Create Soulstone (Minor)" }, { 20752, "Create Soulstone (Lesser)" },
    { 20755, "Create Soulstone" }, { 20756, "Create Soulstone (Greater)" },
    { 20757, "Create Soulstone (Major)" },
    { 5697, "Unending Breath (30 yd range test)" },
}

local ITEMS = {
    { 6265, "Soul Shard" },
    { 5512, "Minor Healthstone" }, { 19004, "Minor Healthstone (1)" }, { 19005, "Minor Healthstone (2)" },
    { 5511, "Lesser Healthstone" }, { 19006, "Lesser Healthstone (1)" }, { 19007, "Lesser Healthstone (2)" },
    { 5509, "Healthstone" }, { 19008, "Healthstone (1)" }, { 19009, "Healthstone (2)" },
    { 5510, "Greater Healthstone" }, { 19010, "Greater Healthstone (1)" }, { 19011, "Greater Healthstone (2)" },
    { 9421, "Major Healthstone" }, { 19012, "Major Healthstone (1)" }, { 19013, "Major Healthstone (2)" },
    { 5232, "Minor Soulstone" }, { 16892, "Lesser Soulstone" }, { 16893, "Soulstone" },
    { 16895, "Greater Soulstone" }, { 16896, "Major Soulstone" },
    { 216748, "Grimoire of Portal of Summoning" },
}

local SOULSTONES = { 16896, 16895, 16893, 16892, 5232 }

------------------------------------------------------------
-- book, pet, stones
------------------------------------------------------------

local function Book()
    for _, s in ipairs(SPELLS) do
        local id, label = s[1], s[2]
        Try("spell " .. id .. " " .. label .. " exists", "C_Spell.DoesSpellExist", id)
        Try("spell " .. id .. " known", "C_SpellBook.IsSpellKnown", id)
        Try("spell " .. id .. " player", "IsPlayerSpell", id)
        Try("spell " .. id .. " name", "C_Spell.GetSpellName", id)
    end
    -- The spellbook as the client lists it, to catch Forever-only spells.
    local lines = G("C_SpellBook") and G("C_SpellBook").GetNumSpellBookSkillLines
    if not lines then Record("book", "MISSING C_SpellBook.GetNumSpellBookSkillLines") return end
    local ok, n = pcall(lines)
    if not ok or IsSecret(n) or type(n) ~= "number" then Record("book", "unreadable", n) return end
    local book = {}
    for line = 1, n do
        local okL, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
        if okL and type(info) == "table" and not IsSecret(info.numSpellBookItems) then
            for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local okI, item = pcall(C_SpellBook.GetSpellBookItemInfo, i, Enum.SpellBookSpellBank.Player)
                if okI and type(item) == "table" then
                    book[#book + 1] = Show(item.spellID) .. " " .. Show(item.name) .. " (" .. Show(info.name) .. ")"
                end
            end
        end
    end
    DB.book = book
    Say(#book .. " spellbook entries saved to this run's book")
end

local function Pet()
    Try("pet exists", "UnitExists", "pet")
    Try("pet guid", "UnitGUID", "pet")
    Try("pet name", "UnitName", "pet")
    Try("pet family", "UnitCreatureFamily", "pet")
    Try("pet HasPetUI", "HasPetUI")
    Try("pet PetHasActionBar", "PetHasActionBar")
    for i = 1, 10 do
        Try("pet action " .. i, "GetPetActionInfo", i)
    end
end

local function Stones()
    for _, it in ipairs(ITEMS) do
        local id, label = it[1], it[2]
        Try("item " .. id .. " " .. label .. " count", "C_Item.GetItemCount", id)
        Try("item " .. id .. " cooldown", "C_Container.GetItemCooldown", id)
        Try("item " .. id .. " spell", "C_Item.GetItemSpell", id)
        Try("item " .. id .. " name", "C_Item.GetItemNameByID", id)
    end
end

------------------------------------------------------------
-- watch: ritual casts, incoming summons, trade events
------------------------------------------------------------

local watcher = CreateFrame("Frame")
OneTwoThreeProbe.watcher = watcher
local WATCHED = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "INCOMING_SUMMON_CHANGED", "CONFIRM_SUMMON", "CANCEL_SUMMON",
    "TRADE_SHOW", "TRADE_CLOSED", "TRADE_REQUEST", "TRADE_ACCEPT_UPDATE",
    "TRADE_PLAYER_ITEM_CHANGED", "UI_ERROR_MESSAGE",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_WHISPER",
}

local function Watch(on)
    for _, e in ipairs(WATCHED) do
        local ok, res = pcall(on and watcher.RegisterEvent or watcher.UnregisterEvent, watcher, e)
        if on and (not ok or res == false) then Log("cannot watch " .. e .. ": " .. Show(res)) end
    end
    Say("watch " .. (on and "on" or "off"))
end

local tradeItem -- set by /123probe tradeitem

-- Bag and slot holding itemID, re-resolved at use time.
local function FindItem(itemID)
    for bag = 0, 5 do
        local okN, slots = pcall(C_Container.GetContainerNumSlots, bag)
        if okN and not IsSecret(slots) and type(slots) == "number" then
            for slot = 1, slots do
                local okI, id = pcall(C_Container.GetContainerItemID, bag, slot)
                if okI and not IsSecret(id) and id == itemID then return bag, slot end
            end
        end
    end
end

local function FirstEmptyTradeSlot()
    local f = G("GetTradePlayerItemInfo")
    for i = 1, 6 do
        local ok, name = pcall(f, i)
        if ok and not IsSecret(name) and name == nil then return i end
    end
end

local function PlaceTradeItem(source)
    if not tradeItem then return end
    local bag, slot = FindItem(tradeItem)
    local target = FirstEmptyTradeSlot()
    if not bag or not target then
        Log("tradeitem (" .. source .. "): item " .. tradeItem .. " bag " .. Show(bag) .. ", empty trade slot " .. Show(target))
        return
    end
    local okP, errP = pcall(C_Container.PickupContainerItem, bag, slot)
    local okH, cursor = pcall(G("CursorHasItem"))
    local okC, errC = pcall(G("ClickTradeButton"), target)
    local okR, placed = pcall(G("GetTradePlayerItemInfo"), target)
    Log("tradeitem (" .. source .. "): pickup " .. Show(okP and "ok" or errP) .. ", cursor " .. Show(cursor)
        .. ", click slot " .. target .. " " .. Show(okC and "ok" or errC) .. ", slot now " .. Show(okR and placed or "?"))
end

watcher:SetScript("OnEvent", function(_, event, ...)
    local args = { ... }
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = Show(args[i]) end
    if event:find("^UNIT_SPELLCAST") and args[1] ~= "player" then return end
    if event:find("^CHAT_MSG") then
        -- text, sender, ..., lineID (11), guid (12)
        Log(event .. ": text=" .. Show(args[1]) .. " sender=" .. Show(args[2]) .. " guid=" .. Show(args[12]))
        return
    end
    Log(event .. " " .. table.concat(parts, ", "))
    if event == "INCOMING_SUMMON_CHANGED" and args[1] then
        Try("summon status " .. Show(args[1]), "C_IncomingSummon.IncomingSummonStatus", args[1])
    elseif event == "TRADE_SHOW" then
        Try("trade with (NPC unit)", "UnitName", "NPC")
        Try("trade with guid", "UnitGUID", "NPC")
        PlaceTradeItem("from TRADE_SHOW, no click")
    end
end)

------------------------------------------------------------
-- Buttons: secure targeting, trade
------------------------------------------------------------

local function ProbeButton(name, label, template, y)
    local b = OneTwoThreeProbe[name]
    if not b then
        b = CreateFrame("Button", "OneTwoThreeProbe" .. name, UIParent, template)
        b:SetSize(220, 28)
        b:SetPoint("CENTER", UIParent, "CENTER", 0, y)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.2, 0.1, 0.3, 0.85)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("CENTER")
        OneTwoThreeProbe[name] = b
    end
    b.text:SetText(label)
    b:Show()
    return b
end

local function Secure(unit)
    if InCombat() then Say("out of combat only") return end
    unit = unit ~= "" and unit or "target"
    local b = ProbeButton("Secure", "Ritual (L) / Soulstone (R) on " .. unit, "SecureActionButtonTemplate", 120)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type1", "spell")
    b:SetAttribute("spell1", 698)
    b:SetAttribute("unit1", unit)
    local stone
    for _, id in ipairs(SOULSTONES) do
        local ok, n = pcall(C_Item.GetItemCount, id)
        if ok and not IsSecret(n) and type(n) == "number" and n > 0 then stone = id break end
    end
    if stone then
        b:SetAttribute("type2", "item")
        b:SetAttribute("item2", "item:" .. stone)
        b:SetAttribute("unit2", unit)
    end
    b:SetScript("PostClick", function(_, button, down)
        Log("secure click " .. Show(button) .. " down=" .. Show(down) .. " unit=" .. unit
            .. " -> " .. Show(UnitName(unit)) .. " (watch on to see the cast)")
    end)
    Say("secure button ready: unit " .. unit .. ", soulstone " .. Show(stone)
        .. ". Try both click edges, in combat, and after a roster change.")
end

local function Trade(unit)
    unit = unit ~= "" and unit or "target"
    local b = ProbeButton("Trade", "Trade with " .. unit, nil, 80)
    b:SetScript("OnClick", function()
        Try("InitiateTrade " .. unit, "InitiateTrade", unit)
    end)
    Say("click the button to open a trade with " .. unit .. " (watch on to see TRADE_SHOW)")
end

local function TradeItem(arg)
    tradeItem = tonumber(arg)
    if not tradeItem then Say("usage: /123probe tradeitem <itemID>") return end
    local b = ProbeButton("TradeItem", "Put item " .. tradeItem .. " in trade", nil, 40)
    b:SetScript("OnClick", function() PlaceTradeItem("from a click") end)
    Say("item " .. tradeItem .. " armed: tried once at TRADE_SHOW, and on each button click")
end

------------------------------------------------------------
-- Chat sends, range
------------------------------------------------------------

local function SayTo(arg)
    local chan, text = arg:match("^(%S+)%s*(.*)$")
    chan = chan and chan:upper()
    if not chan then Say("usage: /123probe say PARTY|RAID|INSTANCE_CHAT [text]") return end
    text = text ~= "" and text or "123 probe test"
    local send = G("C_ChatInfo") and G("C_ChatInfo").SendChatMessage or G("SendChatMessage")
    local ok, err = pcall(send, text .. " (typed)", chan)
    Log("say " .. chan .. " typed: " .. Show(ok and "sent" or err))
    C_Timer.After(1, function()
        local okT, errT = pcall(send, text .. " (timer)", chan)
        Log("say " .. chan .. " timer: " .. Show(okT and "sent" or errT) .. " - did the other player see both?")
    end)
end

local function GroupUnits()
    local units = {}
    local n = G("GetNumGroupMembers") and GetNumGroupMembers() or 0
    if IsSecret(n) then n = 0 end
    local raid = G("IsInRaid") and IsInRaid()
    for i = 1, raid and n or math.max(n - 1, 0) do
        units[#units + 1] = (raid and "raid" or "party") .. i
    end
    return units
end

local function Range()
    Try("player map", "C_Map.GetBestMapForUnit", "player")
    Try("player position", "UnitPosition", "player")
    Try("instance", "GetInstanceInfo")
    local units = GroupUnits()
    if #units == 0 then Say("not in a group: nothing to measure") end
    for _, u in ipairs(units) do
        Try(u .. " name", "GetUnitName", u, false)
        Try(u .. " connected", "UnitIsConnected", u)
        Try(u .. " visible", "UnitIsVisible", u)
        Try(u .. " position", "UnitPosition", u)
        Try(u .. " distanceSq", "UnitDistanceSquared", u)
        Try(u .. " interact 4", "CheckInteractDistance", u, 4)
        Try(u .. " inRange", "UnitInRange", u)
        Try(u .. " map", "C_Map.GetBestMapForUnit", u)
        Try(u .. " spell range 5697", "C_Spell.IsSpellInRange", 5697, u)
        Try(u .. " summon status", "C_IncomingSummon.IncomingSummonStatus", u)
    end
end

------------------------------------------------------------
-- Slash command
------------------------------------------------------------

local function Report()
    local keys = {}
    for k in pairs(DB.results) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do Say(k .. ": " .. DB.results[k]) end
    Say(#keys .. " results, " .. #DB.log .. " log lines")
end

local COMMANDS = {
    book = Book, pet = Pet, stones = Stones, range = Range, report = Report,
    secure = Secure, trade = Trade, tradeitem = TradeItem, say = SayTo,
    watch = function(arg) Watch(arg ~= "off") end,
    reset = function()
        DB.results, DB.log, DB.book = {}, {}, nil
        Say("cleared")
    end,
}

SLASH_ONETWOTHREEPROBE1 = "/123probe"
SlashCmdList.ONETWOTHREEPROBE = function(msg)
    local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local fn = COMMANDS[(cmd or ""):lower()]
    if not fn then
        Say("book | pet | stones | watch on|off | secure <unit> | trade <unit> | tradeitem <id> | say <chan> [text] | range | report | reset")
        return
    end
    DB.build = DB.build or select(2, GetBuildInfo())
    local ok, err = pcall(fn, arg or "")
    if not ok then Say("|cffff6060" .. cmd .. " failed: " .. tostring(err) .. "|r") end
end
