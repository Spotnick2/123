-- ============================================================================
-- OneTwoThreeProbe - dev-only API probe for 123 on WoW: Forever 1.60.1.
--
-- Measures what the Warlock features stand on before code relies on it
-- (issues #1 and #2; ledger in docs/FOREVER-PROBE.md). A ForeverProbe module
-- (..\ForeverProbe, docs/GUIDE.md): its lines go to the ForeverProbe console
-- (/fp), never to chat, and to OneTwoThreeProbeDB.log (SavedVariables). It
-- never logs what other players said: chat payloads by shape only.
--
--   /fp 123 book               candidate Warlock spell IDs: exist / known / name,
--                              then the spellbook as the client lists it
--   /fp 123 pet                active pet: GUID npc id, family, pet bar
--   /fp 123 stones             shards, healthstones, soulstones: count, cooldown, spell
--   /fp 123 watch on|off       log ritual casts, summon and trade events, chat
--                              payload shapes
--   /fp 123 secure <unit>      a secure button: left = Ritual of Summoning on
--                              <unit>, right = best soulstone on <unit>
--   /fp 123 trade <unit>       a button: click = InitiateTrade(<unit>); on
--                              TRADE_SHOW, records who the trade is with
--   /fp 123 tradeitem <id>     a button: click = put item <id> in the first
--                              empty trade slot; also tries once from TRADE_SHOW
--   /fp 123 say <chan> [text]  send to PARTY / RAID / INSTANCE_CHAT now (typed)
--                              and again 1 s later from a timer (not typed)
--   /fp 123 range              per group member: position, distance, map, range
--   /fp 123 auras              the player's buffs: name, spell ID, duration
--                              (Demonic Sacrifice's buff per demon, #20)
--   /fp 123 clear              empty the saved log
--
-- Every client call goes through Probe:Call (the whole return tuple, ABSENT
-- or ERROR), so one refusal can't stop the rest. Nothing here ships
-- (.pkgmeta ignores Tools).
-- ============================================================================

local ADDON, NS = ...
local MAX_LOG = 3000

local Probe = ForeverProbe:Module("OneTwoThreeProbe", { api = 1, cmd = "123" })

local function say(msg) Probe:Say(msg) end
local show = function(v) return Probe.Show(v, true) end

local function G(name) return rawget(_G, name) end

-- A client function by dotted name ("C_Spell.GetSpellName"), nil when absent.
local function resolve(path)
    local fn
    for part in path:gmatch("[^%.]+") do
        if fn == nil then fn = G(part) else fn = type(fn) == "table" and fn[part] or nil end
    end
    return fn
end

-- Logs the whole return tuple of a client function, by name.
local function call(label, path, ...)
    Probe:Call(label, resolve(path), ...)
end

local function isSecret(v)
    local test = G("issecretvalue")
    if not test then return false end
    local ok, is = pcall(test, v)
    return not ok or is == true
end

local function inCombat()
    local f = G("InCombatLockdown")
    return f and f() and true or false
end

------------------------------------------------------------
-- Candidate IDs (Vanilla's; Forever reuses them, FCA probe run 6).
------------------------------------------------------------

local SPELLS = {
    { 688, "Summon Imp" }, { 697, "Summon Voidwalker" }, { 712, "Summon Succubus" }, { 713, "Summon Incubus (Forever)" },
    { 691, "Summon Felhunter" }, { 1122, "Inferno" }, { 18540, "Ritual of Doom" },
    { 1225503, "Reagent Economy?" }, { 1262636, "Reagent Economy?" }, { 1262638, "Reagent Economy?" },
    { 1262643, "Reagent Economy?" }, { 1262647, "Reagent Economy?" }, { 1262650, "Reagent Economy?" },
    { 1262654, "Reagent Economy?" }, { 1262662, "Reagent Economy?" },
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

local function book()
    for _, s in ipairs(SPELLS) do
        local id, label = s[1], s[2]
        call("spell " .. id .. " " .. label .. " exists", "C_Spell.DoesSpellExist", id)
        call("spell " .. id .. " known", "C_SpellBook.IsSpellKnown", id)
        call("spell " .. id .. " player", "IsPlayerSpell", id)
        call("spell " .. id .. " name", "C_Spell.GetSpellName", id)
    end
    -- The spellbook as the client lists it, to catch Forever-only spells.
    local ok, n = Probe:Try("GetNumSpellBookSkillLines", resolve("C_SpellBook.GetNumSpellBookSkillLines"))
    if not ok or isSecret(n) or type(n) ~= "number" then say("book: unreadable " .. show(n)) return end
    local count = 0
    for line = 1, n do
        local okL, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
        if okL and type(info) == "table" and not isSecret(info.numSpellBookItems) then
            for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local okI, item = pcall(C_SpellBook.GetSpellBookItemInfo, i, Enum.SpellBookSpellBank.Player)
                if okI and type(item) == "table" then
                    count = count + 1
                    say("book " .. show(item.spellID) .. " " .. show(item.name) .. " (" .. show(info.name) .. ")")
                end
            end
        end
    end
    say(count .. " spellbook entries")
end

local function pet()
    call("pet exists", "UnitExists", "pet")
    call("pet guid", "UnitGUID", "pet")
    call("pet name", "UnitName", "pet")
    call("pet family", "UnitCreatureFamily", "pet")
    call("pet HasPetUI", "HasPetUI")
    call("pet PetHasActionBar", "PetHasActionBar")
    for i = 1, 10 do
        call("pet action " .. i, "GetPetActionInfo", i)
    end
end

local function stones()
    for _, it in ipairs(ITEMS) do
        local id, label = it[1], it[2]
        call("item " .. id .. " " .. label .. " count", "C_Item.GetItemCount", id)
        call("item " .. id .. " cooldown", "C_Container.GetItemCooldown", id)
        call("item " .. id .. " spell", "C_Item.GetItemSpell", id)
        call("item " .. id .. " name", "C_Item.GetItemNameByID", id)
    end
end

------------------------------------------------------------
-- watch: ritual casts, incoming summons, trade events, chat shapes
------------------------------------------------------------

local watcher = CreateFrame("Frame")
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

local function watch(on)
    if on then
        Probe:RegisterEvents(watcher, WATCHED)
    else
        watcher:UnregisterAllEvents()
    end
    say("watch " .. (on and "on" or "off"))
end

local tradeItem -- set by /fp 123 tradeitem

-- Bag and slot holding itemID, re-resolved at use time.
local function findItem(itemID)
    for bag = 0, 5 do
        local okN, slots = pcall(C_Container.GetContainerNumSlots, bag)
        if okN and not isSecret(slots) and type(slots) == "number" then
            for slot = 1, slots do
                local okI, id = pcall(C_Container.GetContainerItemID, bag, slot)
                if okI and not isSecret(id) and id == itemID then return bag, slot end
            end
        end
    end
end

local function firstEmptyTradeSlot()
    local f = G("GetTradePlayerItemInfo")
    for i = 1, 6 do
        local ok, name = pcall(f, i)
        if ok and not isSecret(name) and name == nil then return i end
    end
end

local function placeTradeItem(source)
    if not tradeItem then return end
    local bag, slot = findItem(tradeItem)
    local target = firstEmptyTradeSlot()
    if not bag or not target then
        say("tradeitem (" .. source .. "): item " .. tradeItem .. " bag " .. show(bag) .. ", empty trade slot " .. show(target))
        return
    end
    local okP, errP = pcall(C_Container.PickupContainerItem, bag, slot)
    local okH, cursor = pcall(G("CursorHasItem"))
    local okC, errC = pcall(G("ClickTradeButton"), target)
    local okR, placed = pcall(G("GetTradePlayerItemInfo"), target)
    say("tradeitem (" .. source .. "): pickup " .. show(okP and "ok" or errP) .. ", cursor " .. show(okH and cursor)
        .. ", click slot " .. target .. " " .. show(okC and "ok" or errC) .. ", slot now " .. show(okR and placed or "?"))
end

watcher:SetScript("OnEvent", function(_, event, ...)
    local args = Probe.Pack(...)
    if event:find("^UNIT_SPELLCAST") and args[1] ~= "player" then return end
    if event:find("^CHAT_MSG") then
        -- text, sender, ..., lineID (11), guid (12): shapes only, never
        -- what another player wrote.
        say(event .. ": text=" .. Probe.Shape(args[1]) .. " sender=" .. Probe.Shape(args[2])
            .. " lineID=" .. Probe.Shape(args[11]) .. " guid=" .. Probe.Shape(args[12]))
        return
    end
    local parts = {}
    for i = 1, args.n do parts[i] = show(args[i]) end
    say(event .. " " .. table.concat(parts, ", "))
    if event == "INCOMING_SUMMON_CHANGED" and args[1] then
        call("summon status " .. show(args[1]), "C_IncomingSummon.IncomingSummonStatus", args[1])
    elseif event == "TRADE_SHOW" then
        call("trade with (NPC unit)", "UnitName", "NPC")
        call("trade with guid", "UnitGUID", "NPC")
        placeTradeItem("from TRADE_SHOW, no click")
    end
end)

------------------------------------------------------------
-- Buttons: secure targeting, trade
------------------------------------------------------------

local buttons = {}

local function probeButton(name, label, template, y)
    local b = buttons[name]
    if not b then
        b = CreateFrame("Button", "OneTwoThreeProbe" .. name, UIParent, template)
        b:SetSize(220, 28)
        b:SetPoint("CENTER", UIParent, "CENTER", 0, y)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.2, 0.1, 0.3, 0.85)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("CENTER")
        buttons[name] = b
    end
    b.text:SetText(label)
    b:Show()
    return b
end

local function secure(unit)
    if inCombat() then say("secure: out of combat only") return end
    unit = unit ~= "" and unit or "target"
    local b = probeButton("Secure", "Ritual (L) / Soulstone (R) on " .. unit, "SecureActionButtonTemplate", 120)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type1", "spell")
    b:SetAttribute("spell1", 698)
    b:SetAttribute("unit1", unit)
    local stone
    for _, id in ipairs(SOULSTONES) do
        local ok, n = pcall(C_Item.GetItemCount, id)
        if ok and not isSecret(n) and type(n) == "number" and n > 0 then stone = id break end
    end
    if stone then
        b:SetAttribute("type2", "item")
        b:SetAttribute("item2", "item:" .. stone)
        b:SetAttribute("unit2", unit)
    end
    b:SetScript("PostClick", function(_, button, down)
        say("secure click " .. show(button) .. " down=" .. show(down) .. " unit=" .. unit
            .. " -> " .. show(UnitName(unit)) .. " (watch on to see the cast)")
    end)
    say("secure button ready: unit " .. unit .. ", soulstone " .. show(stone)
        .. ". Try both click edges, in combat, and after a roster change.")
end

local function trade(unit)
    unit = unit ~= "" and unit or "target"
    local b = probeButton("Trade", "Trade with " .. unit, nil, 80)
    b:SetScript("OnClick", function()
        call("InitiateTrade " .. unit, "InitiateTrade", unit)
    end)
    say("click the button to open a trade with " .. unit .. " (watch on to see TRADE_SHOW)")
end

local function tradeItemCmd(arg)
    tradeItem = tonumber(arg)
    if not tradeItem then say("usage: /fp 123 tradeitem <itemID>") return end
    local b = probeButton("TradeItem", "Put item " .. tradeItem .. " in trade", nil, 40)
    b:SetScript("OnClick", function() placeTradeItem("from a click") end)
    say("item " .. tradeItem .. " armed: tried once at TRADE_SHOW, and on each button click")
end

------------------------------------------------------------
-- Chat sends, range
------------------------------------------------------------

-- The sends are chat test stimuli (GUIDE.md section 5): the probe writes
-- them to group chat on purpose; what it learns goes through say.
local function sayTo(arg)
    local chan, text = arg:match("^(%S+)%s*(.*)$")
    chan = chan and chan:upper()
    if not chan then say("usage: /fp 123 say PARTY|RAID|INSTANCE_CHAT [text]") return end
    text = text ~= "" and text or "123 probe test"
    local send = resolve("C_ChatInfo.SendChatMessage") or G("SendChatMessage")
    local ok, err = pcall(send, text .. " (typed)", chan)
    say("say " .. chan .. " typed: " .. show(ok and "sent" or err))
    C_Timer.After(1, function()
        local okT, errT = pcall(send, text .. " (timer)", chan)
        say("say " .. chan .. " timer: " .. show(okT and "sent" or errT) .. " - did the other player see both?")
    end)
end

local function groupUnits()
    local units = {}
    local n = G("GetNumGroupMembers") and GetNumGroupMembers() or 0
    if isSecret(n) then n = 0 end
    local raid = G("IsInRaid") and IsInRaid()
    for i = 1, raid and n or math.max(n - 1, 0) do
        units[#units + 1] = (raid and "raid" or "party") .. i
    end
    return units
end

local function range()
    call("player map", "C_Map.GetBestMapForUnit", "player")
    call("player position", "UnitPosition", "player")
    call("instance", "GetInstanceInfo")
    local units = groupUnits()
    if #units == 0 then say("range: not in a group, nothing to measure") end
    for _, u in ipairs(units) do
        call(u .. " name", "GetUnitName", u, false)
        call(u .. " connected", "UnitIsConnected", u)
        call(u .. " visible", "UnitIsVisible", u)
        call(u .. " position", "UnitPosition", u)
        call(u .. " distanceSq", "UnitDistanceSquared", u)
        call(u .. " interact 4", "CheckInteractDistance", u, 4)
        call(u .. " inRange", "UnitInRange", u)
        call(u .. " map", "C_Map.GetBestMapForUnit", u)
        call(u .. " spell range 5697", "C_Spell.IsSpellInRange", 5697, u)
        call(u .. " summon status", "C_IncomingSummon.IncomingSummonStatus", u)
    end
end

-- The player's buffs, each read inside pcall (secret in combat).
local function auras()
    local n = 0
    for i = 1, 40 do
        local lib = G("C_UnitAuras")
        local ok, aura = pcall(lib and lib.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok then
            say("auras: blocked (combat?): " .. show(aura))
            return
        end
        if not aura then break end
        local okF, line = pcall(function()
            return string.format("%s  spell %s  duration %s", tostring(aura.name), tostring(aura.spellId),
                tostring(aura.duration))
        end)
        n = n + 1
        say("aura " .. i .. ": " .. (okF and line or "unreadable"))
    end
    say("auras: " .. n)
end

------------------------------------------------------------
-- Commands
------------------------------------------------------------

Probe:Command("book", book, "candidate Warlock spell IDs, then the spellbook")
Probe:Command("pet", pet, "the active pet: GUID, family, pet bar")
Probe:Command("stones", stones, "shards, healthstones, soulstones: count, cooldown, spell")
Probe:Command("watch", function(arg) watch(arg ~= "off") end, "on|off: casts, summons, trades, chat shapes")
Probe:Command("secure", secure, "<unit>: Ritual (left) / soulstone (right) secure button")
Probe:Command("trade", trade, "<unit>: a button that opens a trade")
Probe:Command("tradeitem", tradeItemCmd, "<itemID>: put the item in the trade window")
Probe:Command("say", sayTo, "<PARTY|RAID|INSTANCE_CHAT> [text]: typed, then from a timer")
Probe:Command("range", range, "per group member: position, distance, map, range")
Probe:Command("auras", auras, "the player's buffs (Demonic Sacrifice's, #20)")
Probe:Command("clear", function() Probe:ClearLog(); say("log cleared") end, "empty the saved log")

------------------------------------------------------------
-- disable (#39): can 123 turn itself off for one character?
------------------------------------------------------------

-- C_AddOns.GetAddOnEnableState(name, character) -> Enum.AddOnEnableState
-- (0 None, 1 Some, 2 All). A nil character asks about every character.
local function enableState(character)
    local fn = resolve("C_AddOns.GetAddOnEnableState")
    local ok, state = pcall(fn, "123", character)
    return ok and state or ("ERROR " .. show(state))
end

-- Every name form the client gives the player, to see which one
-- DisableAddOn accepts (Forever's names are "First Surname").
local function names()
    local okU, unitName, realm = pcall(G("UnitName"), "player")
    local okG, short = pcall(G("GetUnitName"), "player", false)
    local okR, full = pcall(G("GetUnitName"), "player", true)
    return okU and unitName or nil, okU and realm or nil, okG and short or nil, okR and full or nil
end

local function playerName() return (names()) end

local function states()
    local me = playerName()
    say("123 enable state: this character (" .. show(me) .. ") " .. show(enableState(me))
        .. ", every character " .. show(enableState(nil)))
    return enableState(me), enableState(nil)
end

Probe:Steps("disable", {
    title = "123 turns itself off for one character (#39)",
    { text = "On a NON-Warlock alt, out of combat, with 123 enabled for all characters in the AddOns list. "
        .. "Reading the names and 123's enable state.", auto = true, run = function()
          local unitName, realm, short, full = names()
          say("names: UnitName " .. show(unitName) .. " realm " .. show(realm) .. ", GetUnitName short "
              .. show(short) .. ", full " .. show(full))
          return unitName, realm, short, full, states()
      end },
    { text = "Turn 123 off for THIS character only (DisableAddOn with UnitName).", button = "Disable here",
      run = function()
          local me = playerName()
          local ok, err = pcall(resolve("C_AddOns.DisableAddOn"), "123", me)
          say("DisableAddOn(\"123\", " .. show(me) .. "): " .. (ok and "ok" or show(err)))
          -- The danger measured here: a character the client didn't take
          -- disables 123 for every character. Put it straight back.
          if enableState(nil) == 0 then
              pcall(resolve("C_AddOns.EnableAddOn"), "123")
              say("|cffff6060disabled for EVERY character: re-enabled for all at once|r")
          end
          return ok, states()
      end,
      check = function()
          local mine, all = enableState(playerName()), enableState(nil)
          return mine == 0 and all == 1, "this character " .. show(mine) .. " (want 0), every character "
              .. show(all) .. " (want 1: still on for the others)"
      end },
    { text = "Open the AddOns list (Esc > AddOns) with THIS character selected at the top: is 123 unchecked? "
        .. "Then switch the list's character dropdown to a Warlock: is 123 still checked there?", ask = true },
    { text = "Turn 123 back on for this character.", button = "Enable here", run = function()
          local me = playerName()
          local ok, err = pcall(resolve("C_AddOns.EnableAddOn"), "123", me)
          say("EnableAddOn(\"123\", " .. show(me) .. "): " .. (ok and "ok" or show(err)))
          return ok, states()
      end,
      check = function()
          local mine, all = enableState(playerName()), enableState(nil)
          return mine == 2 and all == 2, "this character " .. show(mine) .. ", every character " .. show(all)
              .. " (want 2 and 2)"
      end },
    { text = "Type /reload to save the results." , reload = true },
})

Probe:Command("disable", function() Probe:StartSteps("disable") end, "#39: can 123 turn itself off for one character?")

-- Saved tables only at our own ADDON_LOADED (they load after this file).
-- Earlier sessions' `runs` (before ForeverProbe) are left as they were.
local boot = CreateFrame("Frame")
Probe:RegisterEvents(boot, { "ADDON_LOADED" })
boot:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    Probe:Ready()
    if type(OneTwoThreeProbeDB) ~= "table" then OneTwoThreeProbeDB = {} end
    if type(OneTwoThreeProbeDB.log) ~= "table" then OneTwoThreeProbeDB.log = {} end
    Probe:UseLog(OneTwoThreeProbeDB.log, MAX_LOG)
    OneTwoThreeProbeDB.loads = (OneTwoThreeProbeDB.loads or 0) + 1
    say("loaded (" .. OneTwoThreeProbeDB.loads .. " loads). /fp 123 for the commands")
end)

NS._test = { Probe = Probe, buttons = buttons }
