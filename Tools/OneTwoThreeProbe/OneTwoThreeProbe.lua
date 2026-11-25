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
--   /fp 123 summon             guided: the Summoning button on a queued member,
--                              the announcement, the summon's status (#10, #11)
--   /fp 123 soulstone          guided: the Soulstone button on a picked group
--                              member (#5)
--   /fp 123 healthstone        guided: a healthstone request, the trade (#8)
--   /fp 123 control            guided: Banish and Subjugate Demon, durations, the
--                              subjugated demon's break, dismiss and death (#29)
--   /fp 123 sacrifice          guided: Demonic Sacrifice's buff per demon, Demonic
--                              Pact, the summon that ends it (#20)
--   /fp 123 grimoires          guided: at a demon trainer, which grimoires the
--                              summoned demon knows, the vendor window (#59)
--   /fp 123 petbook            the summoned demon's spellbook and grimoire
--                              ranks, and the open vendor window's grimoires
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

-- #22: the client's language, the languages it ships, and the demons'
-- family names by CreatureFamily ID (Data.WHEEL's `family`), which name
-- the wheel's beads without a demon out.
local FAMILIES = { 15, 16, 17, 19, 23, 302 }
local function locale()
    call("locale", "GetLocale")
    call("locales available", "GetAvailableLocales")
    for _, id in ipairs(FAMILIES) do
        call("family " .. id, "C_CreatureInfo.GetCreatureFamilyInfo", id)
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
    "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "INCOMING_SUMMON_CHANGED", "CONFIRM_SUMMON", "CANCEL_SUMMON",
    "UNIT_PET", "UNIT_DIED", "PET_DISMISS_START",
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
    if event == "UNIT_SPELLCAST_SENT" then
        -- unit, target NAME (another player's: shape only), castGUID, spellID
        -- (#10 reads the name to know whom a ritual is on).
        say(event .. " " .. show(args[1]) .. ", target=" .. Probe.Shape(args[2]) .. ", "
            .. show(args[3]) .. ", " .. show(args[4]))
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
Probe:Command("locale", locale, "client language, shipped languages, demon family names (#22)")
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

-- The character as Blizzard's AddOns list names it: the player's GUID
-- (Blizzard_AddOnList/AddonList.lua:16). UnitName ("Kaleid") was accepted
-- and did nothing (owner, 70374, run #9).
local function playerName() return (G("UnitGUID")("player")) end

local function states()
    local me = playerName()
    say("123 enable state: this character (" .. show(me) .. ") " .. show(enableState(me))
        .. ", every character " .. show(enableState(nil)))
    return enableState(me), enableState(nil)
end

Probe:Steps("disable", {
    title = "123 turns itself off for one character (#39)",
    rev = 2,
    { text = "On a NON-Warlock alt, out of combat, with 123 enabled for all characters in the AddOns list. "
        .. "Reading the names and 123's enable state.", auto = true, run = function()
          local unitName, realm, short, full = names()
          say("names: UnitName " .. show(unitName) .. " realm " .. show(realm) .. ", GetUnitName short "
              .. show(short) .. ", full " .. show(full))
          return unitName, realm, short, full, states()
      end },
    { text = "Turn 123 off for THIS character only (DisableAddOn with the player's GUID, as the AddOns list does).", button = "Disable here",
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

------------------------------------------------------------
-- queue (#9, Codex on #38): does a group member's "123" reach the queue?
------------------------------------------------------------

-- The event steps log each payload by shape (shapeOnly): the GUID's
-- readability is what the queue stands on, never what was said. A step
-- listens for exactly one event, so each names its channel and who leads:
-- a leader's line is CHAT_MSG_PARTY_LEADER / _RAID_LEADER, a dungeon-finder
-- group's is CHAT_MSG_INSTANCE_CHAT (Codex on #38).
Probe:Steps("queue", {
    title = "Summon queue: another player's 123 (#9)",
    rev = 2,
    { text = "In a PARTY with a second player, outside instances, out of combat, with YOU as party leader. "
        .. "123 (the queue build) and this probe loaded. Press Next when ready." },
    { text = "Ask the other player (not the leader) to type 123 in PARTY chat.", event = "CHAT_MSG_PARTY",
      shapeOnly = true },
    { text = "Did their name appear in 123's Summons list above the Summoning button, with a sound?",
      ask = true, screenshot = "queue: party request" },
    { text = "Click the x on their row. Did the row go away and the list hide?", ask = true },
    { text = "Type /reload, so the next list is the first one after a reload.", reload = true },
    { text = "Get into combat and stay in it (a mob or a training dummy), then ask them (still not the "
        .. "leader) to type 123 in PARTY chat again.", event = "CHAT_MSG_PARTY", shapeOnly = true },
    { text = "Still in combat: did they join, and does the list sit above the Summoning button?", ask = true,
      screenshot = "queue: first list in combat" },
    { text = "Out of combat: shift-drag the bar elsewhere, then change the bar scale in Options > AddOns > 123. "
        .. "Did the list follow both times?", ask = true, screenshot = "queue: after moving" },
    { text = "Click their x. Then make THEM party leader and ask them to type 123 in PARTY chat "
        .. "(a leader's line is its own event).", event = "CHAT_MSG_PARTY_LEADER", shapeOnly = true },
    { text = "Did they join as party leader?", ask = true },
    { text = "Optional (Skip if not now): convert to a raid with YOU as leader, then ask them (a plain member, "
        .. "not leader or assistant) to type 123 in RAID chat.", event = "CHAT_MSG_RAID", shapeOnly = true },
    { text = "Did they join from raid chat? (Skip if you skipped the last step.)", ask = true },
    { text = "Optional (Skip if not now): inside a dungeon in a group you formed yourself, ask them (not the "
        .. "leader) to type 123 in PARTY chat.", event = "CHAT_MSG_PARTY", shapeOnly = true },
    { text = "Did they join inside the dungeon? (Skip if you skipped the last step.)", ask = true },
    { text = "Optional (Skip if not now): in a dungeon-finder group, ask them to type 123 in INSTANCE chat "
        .. "(/i).", event = "CHAT_MSG_INSTANCE_CHAT", shapeOnly = true },
    { text = "Did they join from instance chat? (Skip if you skipped the last step.)", ask = true },
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Command("queue", function() Probe:StartSteps("queue") end, "#9: does a group member's 123 reach the queue?")

------------------------------------------------------------
-- summon (#10, #11): Ritual of Summoning on a queued member, end to end.
-- watch on logs the ritual's events, each INCOMING_SUMMON_CHANGED with the
-- status read at once, and the group chat lines by shape (ledger rows 4, 5
-- and 7).
------------------------------------------------------------

Probe:Steps("summon", {
    title = "Summoning the next in the queue, announcements (#10, #11)",
    rev = 1,
    { text = "In a group, out of combat, with Ritual of Summoning learned and a Soul Shard; 123 and this "
        .. "probe loaded. The member to summon is far away (another zone is fine). Turning watch on.",
      auto = true, run = function() watch(true) return true end },
    { text = "Ask the far member to type 123 in group chat. Then hover the Summoning button: does its row "
        .. "say \"next\", and the tooltip \"Click: Ritual of Summoning on <them>\"?", ask = true,
      screenshot = "summon: aimed" },
    { text = "Clear your target (Esc), then click the Summoning button.", event = "UNIT_SPELLCAST_SENT",
      shapeOnly = true },
    { text = "Did the ritual start on THEM, with no target selected (portal up, you channel), and does "
        .. "their row say \"summoning\"?", ask = true, screenshot = "summon: ritual" },
    { text = "Did group chat show \"Summoning <them>, please click the portal\" once? Ask them too: did "
        .. "they get it? (A line sent from an event, row 7.)", ask = true },
    { text = "Optional (Skip if fewer than two others are with you): have two members click the portal. "
        .. "Their summon prompt should come up.", event = "INCOMING_SUMMON_CHANGED" },
    { text = "Does their row say \"pending\"? (Skip if you skipped the last step.)", ask = true },
    { text = "Ask them to accept. Once they stand beside you, wait 10 seconds: did they leave the list?",
      ask = true },
    { text = "Optional: summon someone again and have them decline. Does their row say \"declined\" and "
        .. "stay, and is the Summoning button no longer aimed at them?", ask = true },
    { text = "With someone waiting, get into combat and hover the Summoning button: no name in the tooltip "
        .. "(it casts on your target in combat)? Then leave combat: is their name back?", ask = true },
    { text = "In Options > AddOns > 123, turn on \"Ask for clickers\" and start a ritual with fewer than "
        .. "two others near you: did \"Need 2 clickers for the summon\" follow the summon line?", ask = true },
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Command("summon", function() Probe:StartSteps("summon") end,
    "#10, #11: the Summoning button on a queued member, its announcement and status")

------------------------------------------------------------
-- soulstone (#5): a carried soulstone on the picked group member, through
-- the Soulstone button's secure unit1 (ledger row 5: an item action on a
-- unit).
------------------------------------------------------------

Probe:Steps("soulstone", {
    title = "Soulstone on a picked group member (#5)",
    rev = 1,
    { text = "In a group with another player, out of combat, a soulstone in your bags (create one with the "
        .. "Soulstone button). 123 and this probe loaded. Turning watch on.",
      auto = true, run = function() watch(true) return true end },
    { text = "Right-click the Soulstone button: does a list open above it, you first, then the group? Click "
        .. "the other player. Is their first name on the icon, in class colour?", ask = true,
      screenshot = "soulstone: picker" },
    { text = "Clear your target (Esc), then click the Soulstone button.", event = "UNIT_SPELLCAST_SUCCEEDED" },
    { text = "Did THEY get Soulstone Resurrection (look at their buffs, or ask them)?", ask = true },
    { text = "Get into combat and hover the Soulstone button: does the tooltip say it goes to your target "
        .. "in combat, and is the name grey? Leave combat: back in colour?", ask = true },
    { text = "Ask them to leave the group: did 123 say they left, and did the name leave the icon?", ask = true },
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Command("soulstone", function() Probe:StartSteps("soulstone") end,
    "#5: the Soulstone button on a picked group member")

------------------------------------------------------------
-- healthstone (#8): a request in party chat and in a whisper, then the two
-- clicks (open the trade, place the stone). Ledger rows 6 (trade) and 7
-- (whisper GUIDs).
------------------------------------------------------------

Probe:Steps("healthstone", {
    title = "Healthstone request: the prompt and the trade (#8)",
    rev = 1,
    { text = "In a party with another player standing next to you, out of combat, a healthstone in your "
        .. "bags. 123 and this probe loaded. Turning watch on.",
      auto = true, run = function() watch(true) return true end },
    { text = "Ask the other player to type hs in PARTY chat.", event = "CHAT_MSG_PARTY", shapeOnly = true },
    { text = "Did a prompt open above the Healthstone button, with a sound, saying they ask?", ask = true,
      screenshot = "healthstone: prompt" },
    { text = "Click \"Open trade\" on the prompt.", event = "TRADE_SHOW" },
    { text = "Click \"Place the healthstone\" on the prompt.", event = "TRADE_PLAYER_ITEM_CHANGED" },
    { text = "Is the stone in the trade window, and nothing on your cursor? Accept, and ask them to "
        .. "accept: did they get it, and did the prompt go away?", ask = true, screenshot = "healthstone: trade" },
    { text = "Ask them to WHISPER you hs.", event = "CHAT_MSG_WHISPER", shapeOnly = true },
    { text = "Did the prompt open again from the whisper? Click Skip.", ask = true },
    { text = "Optional (Skip if not now): with \"Also whispers from outside the group\" on (Options), "
        .. "someone outside your group whispers hs. Does the prompt say to target them; once targeted, "
        .. "does \"Open trade\" open it?", ask = true },
    { text = "Optional: in combat, ask them to type hs again and click \"Open trade\": does a trade open?",
      ask = true },
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Command("healthstone", function() Probe:StartSteps("healthstone") end,
    "#8: a healthstone request, the prompt and the trade")

------------------------------------------------------------
-- control (#29): Banish's and Subjugate Demon's real durations, and what
-- the client fires when a subjugated demon breaks free, is dismissed or
-- dies (ledger row 11). watch on logs UNIT_PET / UNIT_DIED /
-- PET_DISMISS_START and the casts with their spell IDs.
------------------------------------------------------------

-- How long a debuff of ours lasts on the target, read out of combat.
local function ourDebuff(spellIDs)
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "target", i, "HARMFUL|PLAYER")
        if not ok or isSecret(aura) or type(aura) ~= "table" then return nil end
        for _, id in ipairs(spellIDs) do
            if aura.spellId == id then return id, aura.duration, aura.expirationTime end
        end
    end
end

Probe:Steps("control", {
    title = "Banish and Subjugate Demon (#29)",
    rev = 2,
    { text = "A Warlock with Banish (28) and, for the rest, Subjugate Demon (30) and a Soul Shard, near a "
        .. "demon or elemental to banish. 123 and this probe loaded. Turning watch on.",
      auto = true, run = function() watch(true) return true end },
    { text = "Is a Banish button on the bar after Summoning (and Subjugate once learned)?", ask = true,
      screenshot = "control: bar" },
    { text = "Target a demon or elemental and click Banish.", event = "UNIT_SPELLCAST_SUCCEEDED" },
    { text = "Reading Banish on the target: its real duration.", auto = true,
      run = function() return ourDebuff({ 710, 18647 }) end },
    { text = "Does the button count down and glow its last 5 seconds? Watch the debuff: did both end "
        .. "together?", ask = true, screenshot = "control: banish" },
    { text = "Target a demon you can subjugate and click Subjugate.", event = "UNIT_SPELLCAST_SUCCEEDED" },
    { text = "Reading Subjugate Demon on the pet: its real duration.", auto = true, run = function()
          for i = 1, 40 do
              local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "pet", i, "HARMFUL")
              if not ok or isSecret(aura) or type(aura) ~= "table" then break end
              if aura.spellId == 1098 or aura.spellId == 11725 or aura.spellId == 11726 then
                  return aura.spellId, aura.duration, aura.expirationTime
              end
          end
          return "no subjugate aura on the pet"
      end },
    { text = "Is it your pet, with a countdown on the button? Right-click the Subjugate button: was it "
        .. "dismissed (and no break-free alert)?", ask = true },
    { text = "Subjugate a demon again and let it break free (wait it out, or summon one of your own). Did "
        .. "123 say it broke free, with a sound and a red glow?", ask = true },
    { text = "Optional: subjugate one more and let it die in a fight. No break-free alert?", ask = true },
    { text = "Optional: with a demon subjugated, subjugate a second one. Does the first go hostile or "
        .. "vanish? 123 should say nothing about the first and count down the second.", ask = true },
    { text = "Summon one of your own demons, then right-click Subjugate: is your demon still out?",
      ask = true },
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Command("control", function() Probe:StartSteps("control") end,
    "#29: Banish and Subjugate Demon, their durations and the break")

------------------------------------------------------------
-- sacrifice (#20): the buff each demon's sacrifice gives (Wowhead's Forever
-- database: 18789-18792), Demonic Pact (425464), and which summon ends the
-- buff (ledger row 12).
------------------------------------------------------------

Probe:Steps("sacrifice", {
    title = "Demonic Sacrifice's buffs and Demonic Pact (#20)",
    rev = 1,
    { text = "A Demonology Warlock with Demonic Sacrifice, the Imp out, out of combat. 123 and this probe "
        .. "loaded. Reading Demonic Pact and turning watch on.", auto = true, run = function()
          watch(true)
          call("Demonic Pact known (IsPlayerSpell)", "IsPlayerSpell", 425464)
          call("Demonic Pact known (C_SpellBook)", "C_SpellBook.IsSpellKnown", 425464)
          call("Demonic Pact name", "C_Spell.GetSpellName", 425464)
          return true
      end },
    { text = "Right-click the Demon button (Demonic Sacrifice).", event = "UNIT_SPELLCAST_SUCCEEDED" },
    { text = "Reading your buffs: the Imp's sacrifice buff (expected 18789, \"Burning Shadow\").", auto = true,
      run = function() auras() return true end },
    { text = "Hover the Demon button: does it say a summon ends your Demonic Sacrifice and asks first? "
        .. "Click it: does the question name the buff? Cancel.", ask = true, screenshot = "sacrifice: ask" },
    { text = "Summon the Voidwalker from the wheel (answer Summon if asked), wait for it, and sacrifice it.",
      event = "UNIT_SPELLCAST_SUCCEEDED" },
    { text = "Reading your buffs: the Voidwalker's (expected 18790, Fel Stamina). Is the Imp's gone?",
      auto = true, run = function() auras() return true end },
    { text = "Optional, with Demonic Pact: summon the Succubus. Reading your buffs: is the Voidwalker's "
        .. "still up? Then sacrifice the Succubus (expected 18791) and the Incubus if learned (18791 too?).",
      auto = false, ask = true },
    { text = "Reading your buffs once more.", auto = true, run = function() auras() return true end },
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Command("sacrifice", function() Probe:StartSteps("sacrifice") end,
    "#20: Demonic Sacrifice's buffs and Demonic Pact")

------------------------------------------------------------
-- grimoires (#59): which grimoires the summoned demon already knows, read
-- from the pet's spellbook, and what a demon trainer's vendor window is
-- made of (Mainline or Vanilla MerchantFrame, its slots, its tooltips).
-- The item -> pet spell table is the client's own data (wago.tools DB2,
-- build 70532: itemsparse + itemxitemeffect + itemeffect + spelleffect,
-- effect 36 LEARN_SPELL). Rank 1 of Firebolt, Torment, Lash of Pain and
-- Devour Magic comes with the demon (no grimoire): INNATE, to see what a
-- lower rank reads once a higher one is learned.
------------------------------------------------------------

local GRIMOIRES = { -- { item, pet spell, ability, rank }
    { 16321, 6307, "Blood Pact", 1 }, { 16322, 7804, "Blood Pact", 2 }, { 16323, 7805, "Blood Pact", 3 },
    { 16324, 11766, "Blood Pact", 4 }, { 16325, 11767, "Blood Pact", 5 }, { 16357, 17767, "Consume Shadows", 1 },
    { 16358, 17850, "Consume Shadows", 2 }, { 16359, 17851, "Consume Shadows", 3 }, { 16360, 17852, "Consume Shadows", 4 },
    { 16361, 17853, "Consume Shadows", 5 }, { 16362, 17854, "Consume Shadows", 6 }, { 16381, 19731, "Devour Magic", 2 },
    { 16382, 19734, "Devour Magic", 3 }, { 16383, 19736, "Devour Magic", 4 }, { 16326, 2947, "Fire Shield", 1 },
    { 16327, 8316, "Fire Shield", 2 }, { 16328, 8317, "Fire Shield", 3 }, { 16329, 11770, "Fire Shield", 4 },
    { 16330, 11771, "Fire Shield", 5 }, { 16302, 7799, "Firebolt", 2 }, { 16316, 7800, "Firebolt", 3 },
    { 16317, 7801, "Firebolt", 4 }, { 16318, 7802, "Firebolt", 5 }, { 16319, 11762, "Firebolt", 6 },
    { 16320, 11763, "Firebolt", 7 }, { 16368, 7815, "Lash of Pain", 2 }, { 16371, 7816, "Lash of Pain", 3 },
    { 16372, 11778, "Lash of Pain", 4 }, { 16373, 11779, "Lash of Pain", 5 }, { 16374, 11780, "Lash of Pain", 6 },
    { 16380, 7870, "Lesser Invisibility", 1 }, { 16390, 19480, "Paranoia", 1 }, { 16331, 4511, "Phase Shift", 1 },
    { 16351, 7812, "Sacrifice", 1 }, { 16352, 19438, "Sacrifice", 2 }, { 16353, 19440, "Sacrifice", 3 },
    { 16354, 19441, "Sacrifice", 4 }, { 16355, 19442, "Sacrifice", 5 }, { 16356, 19443, "Sacrifice", 6 },
    { 16379, 6358, "Seduction", 1 }, { 16375, 6360, "Soothing Kiss", 1 }, { 16376, 7813, "Soothing Kiss", 2 },
    { 16377, 11784, "Soothing Kiss", 3 }, { 16378, 11785, "Soothing Kiss", 4 }, { 16388, 19244, "Spell Lock", 1 },
    { 16389, 19647, "Spell Lock", 2 }, { 16363, 17735, "Suffering", 1 }, { 16364, 17750, "Suffering", 2 },
    { 16365, 17751, "Suffering", 3 }, { 16366, 17752, "Suffering", 4 }, { 16384, 19478, "Tainted Blood", 1 },
    { 16385, 19655, "Tainted Blood", 2 }, { 16386, 19656, "Tainted Blood", 3 }, { 16387, 19660, "Tainted Blood", 4 },
    { 16346, 7809, "Torment", 2 }, { 16347, 7810, "Torment", 3 }, { 16348, 7811, "Torment", 4 },
    { 16349, 11774, "Torment", 5 }, { 16350, 11775, "Torment", 6 },
}
local INNATE = { -- { nil, pet spell, ability, rank }: no grimoire teaches them
    { nil, 3110, "Firebolt", 1 }, { nil, 3716, "Torment", 1 }, { nil, 7814, "Lash of Pain", 1 },
    { nil, 19505, "Devour Magic", 1 },
}
local GRIMOIRE_BY_ITEM = {}
for _, g in ipairs(GRIMOIRES) do GRIMOIRE_BY_ITEM[g[1]] = g end

local function petBank()
    local enum = G("Enum")
    return enum and enum.SpellBookSpellBank and enum.SpellBookSpellBank.Pet
end

-- The flags one pet spell reads with, as text.
local function petKnows(spellID)
    local bank = petBank()
    local okK, known = Probe:Try("IsSpellKnown(pet)", resolve("C_SpellBook.IsSpellKnown"), spellID, bank)
    local okB, inBook = Probe:Try("IsSpellInSpellBook(pet)", resolve("C_SpellBook.IsSpellInSpellBook"),
        spellID, bank, false)
    known, inBook = okK and known, okB and inBook
    return known == true or inBook == true, "IsSpellKnown=" .. show(known) .. " inBook=" .. show(inBook)
end

-- The summoned demon's spellbook as the client lists it, then every
-- grimoire ability's ranks: in full for an ability with any rank known,
-- one summary line for the rest.
local function petBook()
    call("pet guid", "UnitGUID", "pet")
    call("pet family", "UnitCreatureFamily", "pet")
    local bank = petBank()
    say("pet bank = " .. show(bank))
    local ok, n = Probe:Try("HasPetSpells", resolve("C_SpellBook.HasPetSpells"))
    say("HasPetSpells = " .. show(n))
    local info = resolve("C_SpellBook.GetSpellBookItemInfo")
    if ok and type(n) == "number" and not isSecret(n) and info then
        for i = 1, n do
            local okI, item = pcall(info, i, bank)
            if okI and type(item) == "table" then
                say("petbook " .. i .. " " .. show(item.spellID) .. " " .. show(item.name) .. " ("
                    .. show(item.subName) .. ") type " .. show(item.itemType) .. " passive " .. show(item.isPassive))
            else
                say("petbook " .. i .. " unreadable " .. show(item))
            end
        end
    end
    local rows, any, order = {}, {}, {}
    for _, list in ipairs({ INNATE, GRIMOIRES }) do
        for _, g in ipairs(list) do
            local known, flags = petKnows(g[2])
            if not rows[g[3]] then rows[g[3]] = {}; order[#order + 1] = g[3] end
            table.insert(rows[g[3]], { g[4], g[2], g[1], flags })
            if known then any[g[3]] = true end
        end
    end
    local none = {}
    for _, ability in ipairs(order) do
        if any[ability] then
            table.sort(rows[ability], function(a, b) return a[1] < b[1] end)
            for _, r in ipairs(rows[ability]) do
                say("rank " .. ability .. " " .. r[1] .. " (spell " .. r[2] .. ", item " .. show(r[3]) .. "): " .. r[4])
            end
        else
            none[#none + 1] = ability
        end
    end
    say("no rank known: " .. table.concat(none, ", "))
end

-- A tooltip line worth keeping: "Already known", or red (a requirement).
local function notableLines(data)
    local out = {}
    if type(data) ~= "table" or type(data.lines) ~= "table" then return "no tooltip data" end
    local knownText = G("ITEM_SPELL_KNOWN")
    for _, line in ipairs(data.lines) do
        local text, c = line.leftText, line.leftColor
        if type(text) == "string" and not isSecret(text) then
            local red = type(c) == "table" and type(c.r) == "number" and not isSecret(c.r)
                and c.r > 0.9 and c.g < 0.2 and c.b < 0.2
            if text == knownText or red then out[#out + 1] = (red and "red " or "") .. show(text) end
        end
    end
    return #out > 0 and table.concat(out, " / ") or "nothing red or known"
end

-- The vendor window open now: which MerchantFrame this client loads, the
-- items with their grimoire's pet spell, and the ten slots' button IDs.
local function merchant()
    local frame = G("MerchantFrame")
    say("MerchantFrame " .. show(frame ~= nil) .. " shown " .. show(frame and frame:IsShown())
        .. " FilterDropdown (Mainline) " .. show(frame and frame.FilterDropdown ~= nil)
        .. " page " .. show(frame and frame.page) .. " per page " .. show(G("MERCHANT_ITEMS_PER_PAGE")))
    call("merchant filter", "GetMerchantFilter")
    local ok, n = Probe:Try("GetMerchantNumItems", resolve("GetMerchantNumItems"))
    say("merchant items = " .. show(n))
    if not ok or type(n) ~= "number" or isSecret(n) then return end
    local grimoires = 0
    for i = 1, n do
        local _, id = Probe:Try("GetMerchantItemID", resolve("GetMerchantItemID"), i)
        local _, info = Probe:Try("C_MerchantFrame.GetItemInfo", resolve("C_MerchantFrame.GetItemInfo"), i)
        info = type(info) == "table" and info or {}
        local line = "merchant " .. i .. " item " .. show(id) .. " " .. show(info.name) .. " price "
            .. show(info.price) .. " usable " .. show(info.isUsable)
        local g = GRIMOIRE_BY_ITEM[id]
        if g then
            grimoires = grimoires + 1
            local _, spellName, spellID = Probe:Try("C_Item.GetItemSpell", resolve("C_Item.GetItemSpell"), id)
            local _, flags = petKnows(g[2])
            local _, data = Probe:Try("C_TooltipInfo.GetMerchantItem", resolve("C_TooltipInfo.GetMerchantItem"), i)
            line = line .. " -> " .. g[3] .. " " .. g[4] .. " (spell " .. g[2] .. ") itemSpell " .. show(spellID)
                .. " " .. show(spellName) .. " | pet " .. flags .. " | tooltip " .. notableLines(data)
        elseif id and tostring(info.name or ""):find("Grimoire") then
            line = line .. " -> a grimoire NOT in the table"
        end
        say(line)
    end
    say(grimoires .. " of " .. n .. " items are grimoires in the table")
    for s = 1, (G("MERCHANT_ITEMS_PER_PAGE") or 10) do
        local slot, button = G("MerchantItem" .. s), G("MerchantItem" .. s .. "ItemButton")
        say("slot " .. s .. " shown " .. show(slot and slot:IsShown()) .. " button id " .. show(button and button:GetID()))
    end
end

-- What fires around a demon change and a learned rank, and when Blizzard
-- redraws the vendor window (the hook a filter would follow).
local grimoireWatcher = CreateFrame("Frame")
local GRIMOIRE_EVENTS = { "UNIT_PET", "PET_BAR_UPDATE", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE",
    "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_FILTER_ITEM_UPDATE", "MERCHANT_CLOSED" }
grimoireWatcher:SetScript("OnEvent", function(_, event, a1)
    say("event " .. event .. " " .. show(a1))
end)
local redrawHooked, watching
local function grimoireWatch(on)
    watching = on
    if on then
        Probe:RegisterEvents(grimoireWatcher, GRIMOIRE_EVENTS)
        local hook = G("hooksecurefunc")
        if not redrawHooked and hook and G("MerchantFrame_UpdateMerchantInfo") then
            redrawHooked = true
            hook("MerchantFrame_UpdateMerchantInfo", function()
                if watching then say("MerchantFrame_UpdateMerchantInfo ran") end
            end)
        end
        say("grimoire watch on, redraw hook " .. show(redrawHooked == true))
    else
        grimoireWatcher:UnregisterAllEvents()
        say("grimoire watch off")
    end
end

Probe:Steps("grimoires", {
    title = "Grimoires your demon knows, at a demon trainer (#59)",
    rev = 1,
    { text = "A Warlock with one of your own demons out (the Imp is fine), out of combat. 123 and this "
        .. "probe loaded. Turning the grimoire watch on and reading the demon's spellbook.",
      auto = true, run = function() grimoireWatch(true) petBook() return true end },
    { text = "Open your spellbook on the Pet tab so the shot shows which ranks it lists, then press Next.",
      screenshot = "grimoires: pet book" },
    { text = "Go to a demon trainer and open their goods (the vendor window, not the trainer list).",
      event = "MERCHANT_SHOW" },
    { text = "Reading the vendor window: its items, which pet spell each grimoire teaches, and whether the "
        .. "demon knows it. Page through it if there are more pages, then press Next.",
      auto = true, run = function() merchant() return true end, screenshot = "grimoires: vendor" },
    { text = "Hover a grimoire your demon already knows (or the rank below the one it has). Does the tooltip "
        .. "or the item look different (\"Already known\", red text, a red icon)?", ask = true,
      screenshot = "grimoires: known tooltip" },
    { text = "Keep the vendor open if you can. Dismiss the demon, summon another of yours, wait until it "
        .. "is out, then press Run.", button = "Read again", run = function()
          petBook() merchant() return true end },
    { text = "When the demon changed, did the vendor window change by itself (a tint or tooltip that "
        .. "follows the new demon), without closing it?", ask = true, screenshot = "grimoires: other demon" },
    { text = "Optional (Skip if nothing fits or you can't afford it): buy a grimoire the summoned demon can "
        .. "learn but doesn't know, and use it.", event = "UNIT_SPELLCAST_SUCCEEDED" },
    { text = "Reading the demon's spellbook again: the new rank, and what the ranks below it read now.",
      auto = true, run = function() petBook() merchant() return true end },
    { text = "Has a demon of yours ever learned a new rank on its own, just by levelling, without a "
        .. "grimoire? (Not sure is fine.)", ask = true },
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Command("grimoires", function() Probe:StartSteps("grimoires") end,
    "#59: guided, at a demon trainer with a demon out")
Probe:Command("petbook", function() petBook() merchant() end,
    "#59: the demon's known pet spells, and the open vendor window's grimoires")

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
