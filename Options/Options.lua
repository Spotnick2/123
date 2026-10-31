-- Options (#15): a Settings canvas category, Options > AddOns > 123.
--
-- As in Portal Roulette: registered at PLAYER_LOGIN, hidden right after
-- creation (a page shown once at creation renders blank on its first
-- visit), built on first show and re-read on every show. Plain template
-- widgets (UICheckButtonTemplate, UIPanelButtonTemplate); no UIDropDownMenu,
-- so choices cycle on a button and numbers use - / + steppers.

local _, ns = ...
if ns.skip then return end

local L = ns.L

local Options = {}
ns.Options = Options

local panel
local controls = {}

-- What a change does beyond saving it. A false return refuses it (the bar
-- holds secure buttons, so it can't change in combat) and the page
-- re-reads the saved value.
local APPLY = {
    barLabels = function() return ns.Bar:ApplyLabels() end,
    barShown = function() return ns.Bar:ApplyShown() end,
    barScale = function() return ns.Bar:ApplyScale() end,
    confirmResummon = function() ns.SecureAction.MarkDirty() end,
    ["pair.sacrifice"] = function() ns.SecureAction.MarkDirty() end,
    ["pair.keep"] = function() ns.SecureAction.MarkDirty() end,
    showMinimapButton = function() ns.Minimap:RefreshVisibility() end,
}

-- Where a key is saved: ns.db, except the bar's own, the alert kits, the
-- summon queue's, the announcements', the healthstone requests' and this
-- character's Demonic Sacrifice pair (#20).
local function path(key)
    local tbl, field = ns.db, key
    if key == "barShown" then tbl, field = ns.db.bar, "shown"
    elseif key == "barScale" then tbl, field = ns.db.bar, "scale"
    elseif key:find("^alerts%.") then tbl, field = ns.db.alerts, key:sub(8)
    elseif key:find("^queue%.") then tbl, field = ns.db.queue, key:sub(7)
    elseif key:find("^announce%.") then tbl, field = ns.db.announce, key:sub(10)
    elseif key:find("^stones%.") then tbl, field = ns.db.stones, key:sub(8)
    elseif key:find("^pair%.") then
        ns.char.sacrificePair = ns.char.sacrificePair or {}
        tbl, field = ns.char.sacrificePair, key:sub(6)
    end
    return tbl, field
end

local function get(key)
    local tbl, field = path(key)
    return tbl[field]
end

local function set(key, value)
    local tbl, field = path(key)
    local old = tbl[field]
    tbl[field] = value
    local apply = APPLY[key]
    if apply and apply() == false then
        tbl[field] = old
        ns.Print(L["the bar can't change in combat."])
    end
end
Options.Set = set

local function checkbox(parent, label)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(label)
    cb.label = fs
    return cb
end

local function button(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 24, 22)
    b:SetText(text)
    return b
end

local function heading(parent, text, anchor, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y or -18)
    fs:SetText(text)
    return fs
end

local function note(parent, text, anchor)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    fs:SetWidth(300)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function toggle(parent, anchor, key, label)
    local cb = checkbox(parent, label)
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    cb:SetScript("OnClick", function(self)
        set(key, self:GetChecked() == true)
        self:SetChecked(get(key) == true)
    end)
    controls[#controls + 1] = function() cb:SetChecked(get(key) == true) end
    return cb
end

-- choices = { { value, text }, ... }; onPick runs after a choice is made;
-- a choice `skip(value)` refuses is passed over.
local function cycle(parent, anchor, key, label, choices, onPick, skip)
    local b = button(parent, "", 140)
    b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", b, "RIGHT", 8, 0)
    fs:SetText(label)
    local function refresh()
        for _, c in ipairs(choices) do
            if c[1] == get(key) then b:SetText(c[2]) return end
        end
        b:SetText(choices[1][2])
    end
    b:SetScript("OnClick", function()
        local nextIndex = 1
        for i, c in ipairs(choices) do
            if c[1] == get(key) then nextIndex = i % #choices + 1 break end
        end
        for _ = 1, #choices do
            if not (skip and skip(choices[nextIndex][1])) then break end
            nextIndex = nextIndex % #choices + 1
        end
        set(key, choices[nextIndex][1])
        refresh()
        if onPick then onPick(choices[nextIndex][1]) end
    end)
    controls[#controls + 1] = refresh
    return b
end

local function stepper(parent, anchor, key, label, minV, maxV, step, fmt)
    local minus = button(parent, "-")
    minus:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetWidth(48)
    value:SetPoint("LEFT", minus, "RIGHT", 2, 0)
    local plus = button(parent, "+")
    plus:SetPoint("LEFT", value, "RIGHT", 2, 0)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", plus, "RIGHT", 8, 0)
    fs:SetText(label)
    local function refresh() value:SetText(string.format(fmt, tonumber(get(key)) or minV)) end
    local function bump(sign)
        local v = (tonumber(get(key)) or minV) + sign * step
        v = math.max(minV, math.min(maxV, math.floor(v / step + 0.5) * step))
        v = tonumber(string.format(fmt, v))  -- 0.95, not 0.9500000000000001
        set(key, v)
        refresh()
    end
    minus:SetScript("OnClick", function() bump(-1) end)
    plus:SetScript("OnClick", function() bump(1) end)
    controls[#controls + 1] = refresh
    return minus
end

-- A keyword list (the summon queue's, the healthstone requests'), comma-
-- separated, saved on Enter or when the box loses focus (an empty box goes
-- back to `fallback`).
local function keywords(parent, anchor, tbl, fallback)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(150, 20)
    box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 6, -8)
    box:SetAutoFocus(false)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", box, "RIGHT", 8, 0)
    fs:SetText(L["Keywords"])
    local function refresh() box:SetText(table.concat(tbl().keywords, ", ")) end
    local function save()
        tbl().keywords = ns.Queue.ParseKeywords(box:GetText(), fallback)
        refresh()
    end
    box:SetScript("OnEnterPressed", function(self) save(); self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", save)
    box:SetScript("OnEscapePressed", function(self) refresh(); self:ClearFocus() end)
    controls[#controls + 1] = refresh
    box.save = save
    return box
end

-- An announcement's text (#11): the saved one, or its default when blank.
-- Saved on Enter or when the box loses focus; the default text, or an
-- empty box, saves as blank (the default, in the client's language).
local function lineBox(parent, anchor, kind)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(290, 20)
    box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 6, -4)
    box:SetAutoFocus(false)
    box:SetMaxLetters(200)
    local function refresh() box:SetText(ns.Announce.Template(kind)) end
    local function save()
        local text = (box:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        ns.db.announce[kind .. "Text"] = text == ns.Announce.DEFAULT[kind] and "" or text
        refresh()
    end
    box:SetScript("OnEnterPressed", function(self) save(); self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", save)
    box:SetScript("OnEscapePressed", function(self) refresh(); self:ClearFocus() end)
    controls[#controls + 1] = refresh
    box.save = save
    return box
end

local function build()
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["123 — Warlock Summons, Demons & Stones"])
    local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetWidth(620)
    sub:SetJustifyH("LEFT")
    sub:SetText(L["/123 shows or hides the bar, /123 wheel opens the demon wheel, /123 options opens this page."]
        .. " " .. L["Key bindings: Options > Keybindings > AddOns > 123."])

    -- Left column.
    local h = heading(panel, L["Bar"], sub)
    local a = toggle(panel, h, "barShown", L["Show the bar"])
    a = toggle(panel, a, "barLabels", L["Names under the icons"])
    a = stepper(panel, a, "barScale", L["Bar scale"], 0.6, 1.6, 0.05, "%.2f")
    local reset = button(panel, L["Reset position"], 130)
    reset:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -8)
    reset:SetScript("OnClick", function() ns.Bar:ResetPosition() end)
    a = note(panel, L["Shift-drag the 123 handle to move the bar."], reset)

    h = heading(panel, L["Demon wheel"], a)
    a = toggle(panel, h, "confirmResummon", L["Ask before re-summoning the demon that is out"])
    a = toggle(panel, a, "cinematicCamera", L["Cinematic camera"])
    a = toggle(panel, a, "cameraOrbit", L["Slow camera orbit"])
    a = toggle(panel, a, "hideGameUI", L["Hide the game UI while the wheel is open"])
    local preview = button(panel, L["Preview the wheel"], 150)
    preview:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -8)
    preview:SetScript("OnClick", function() ns.Wheel:SetPreview(not ns.Wheel.preview) end)

    -- #20: the pair the Demon button's right click walks with Demonic Pact.
    local demons = { { 0, L["None"] } }
    for _, spellID in ipairs(ns.Data.DEMONS) do
        demons[#demons + 1] = { spellID, ns.Wheel.DemonName(spellID) }
    end
    h = heading(panel, L["Demonic Sacrifice"], preview)
    a = cycle(panel, h, "pair.sacrifice", L["Demon to sacrifice"], demons, function(v)
        local pair = ns.char.sacrificePair
        if v ~= 0 and pair.keep == v then pair.keep = 0 end
        Options.Refresh()
    end)
    a = cycle(panel, a, "pair.keep", L["Demon to keep"], demons, nil, function(v)
        return v ~= 0 and v == (ns.char.sacrificePair or {}).sacrifice
    end)
    a = note(panel, L["With Demonic Pact, the Demon button's right click walks the pair: summon the first, sacrifice it, then summon the second."], a)
    preview = a

    h = heading(panel, L["Summon announcements"], preview)
    a = toggle(panel, h, "announce.summon", L["Announce the summon in group chat"])
    a = lineBox(panel, a, "summon")
    a = toggle(panel, a, "announce.clickers", L["Ask for clickers when fewer than 2 are near"])
    a = lineBox(panel, a, "clickers")
    note(panel, L["{name} is who you summon. Sent to instance, raid or party chat when the ritual starts, at most every 10 seconds."], a)

    -- Right column.
    local right = CreateFrame("Frame", nil, panel)
    right:SetSize(1, 1)
    right:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 340, 0)
    h = heading(panel, L["Sound"], right)
    a = toggle(panel, h, "sounds", L["Demon voices on the wheel"])
    a = toggle(panel, a, "alertSounds", L["Alert sounds"])
    for _, alert in ipairs(ns.Sound.ALERTS) do
        a = cycle(panel, a, "alerts." .. alert.key, alert.label, ns.Sound.CHOICES, function(kit)
            if kit > 0 and not ns.Sound:PlayKit(kit) then
                ns.Print(L["the game didn't play that sound; pick another."])
            end
        end)
    end
    a = note(panel, L["Picking a sound plays it. Requests arrive with the summon queue and healthstone requests."], a)

    h = heading(panel, L["Summon queue"], a)
    a = toggle(panel, h, "queue.enabled", L["Queue group members who type a keyword"])
    local box = keywords(panel, a, function() return ns.db.queue end, "123")
    a = stepper(panel, box, "queue.timeout", L["Minutes before a request drops"], 2, 30, 1, "%d")
    a = note(panel, L["The whole message must be a keyword: \"123\" asks, \"1234\" or \"123 dps\" don't. /123 queue test tries it alone."], a)

    h = heading(panel, L["Healthstone requests"], a)
    a = toggle(panel, h, "stones.enabled", L["Prompt when someone asks for a healthstone"])
    a = keywords(panel, a, function() return ns.db.stones end, "hs")
    a = toggle(panel, a, "stones.strangers", L["Also whispers from outside the group"])
    a = note(panel, L["Whole message, in group chat or a whisper. You open the trade and place the stone; you accept. /123 hs test shows the prompt."], a)

    h = heading(panel, L["Minimap"], a)
    a = toggle(panel, h, "showMinimapButton", L["Minimap button"])
    a = toggle(panel, a, "showCompartment", L["Addon compartment entry (after /reload)"])
end

function Options.Refresh()
    for _, refresh in ipairs(controls) do
        refresh()
    end
end

function Options:Register()
    if panel then return end
    panel = CreateFrame("Frame", "OneTwoThreeOptions")
    panel.name = "123"
    panel:Hide()
    local built = false
    panel:SetScript("OnShow", function()
        if not built then
            built = true
            build()
        end
        Options.Refresh()
    end)
    self.panel = panel
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.category = category
    end
end

-- The Settings panel is Blizzard's; opening it in combat is refused.
function Options:Open()
    if InCombatLockdown() then
        ns.Print(L["options can't open in combat."])
        return
    end
    if self.category and Settings and Settings.OpenToCategory then
        pcall(Settings.OpenToCategory, self.category:GetID())
    end
end
