-- Every widget method 123 calls exists on that widget type in the pinned
-- build (Kit.checkMethods). The exercise loads the addon (with the LibGlass
-- and LibShowcase checkouts when they are there), fires every registered
-- event, runs every slash command, opens the bar's lists and prompts (the
-- summon queue, a healthstone request, the soulstone picker, the re-summon
-- prompt), the demon wheel (preview too) with its 3D portraits and the
-- options page, hovers and clicks every frame with a handler, and goes in
-- and out of combat.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

-- 123 calls many client methods through pcall (the portraits' model scenes,
-- the cooldown swipes, the event registrations): a method this build lacks
-- reads as nil there, the call fails inside the pcall, and nothing is
-- recorded for Kit.checkMethods to see. Every error a pcall catches during
-- the exercise is kept (Gnomesweeper's check): there must be none.
local swallowed = {}
do
    local corePcall = pcall
    local function keep(ok, ...)
        if not ok then swallowed[#swallowed + 1] = tostring((...)) end
        return ok, ...
    end
    function pcall(f, ...) return keep(corePcall(f, ...)) end
end

local libs = {}
for _, lib in ipairs({ { os.getenv("LIBGLASS") or "../LibGlass", "LibGlass.lua" },
                       { os.getenv("LIBSHOWCASE") or "../LibShowcase", "LibShowcase.lua" } }) do
    local file = lib[1] .. "/" .. lib[2]
    local f = io.open(file)
    if f then f:close() libs[#libs + 1] = file end
end

-- Every demon, stone and summon known (test_wheel's, test_bar's), a group,
-- shards, a pet out with Sacrifice on its bar.
for id, name in pairs({
    [688] = "Summon Imp", [697] = "Summon Voidwalker", [712] = "Summon Succubus",
    [691] = "Summon Felhunter", [713] = "Summon Incubus", [1122] = "Inferno",
    [18540] = "Ritual of Doom", [7812] = "Sacrifice", [18708] = "Fel Domination",
    [18788] = "Demonic Sacrifice", [698] = "Ritual of Summoning", [693] = "Create Soulstone (Minor)",
    [6201] = "Create Healthstone (Minor)", [706] = "Demon Armor", [687] = "Demon Skin",
    [710] = "Banish", [1098] = "Enslave Demon",
}) do
    WoW.spells[id] = { name = name, known = true, usable = true }
end
WoW.items[5565], WoW.items[6265], WoW.items[5232] = "Infernal Stone", "Soul Shard", "Minor Soulstone"
WoW.counts[6265], WoW.counts[5565], WoW.counts[5232] = 3, 1, 1
WoW.petGUID = "Pet-0-4613-0-1234-1860-0000ABCDEF"
WoW.petActions[5] = { name = "Sacrifice", spellID = 7812 }
WoW.inGroup = true
WoW.group = {
    { guid = "Player-1-AAA", name = "Ashka Vale", class = "MAGE" },
    { guid = "Player-1-BBB", name = "Brom Hollow", class = "WARRIOR" },
}

-- The 3D portraits (UI/Portrait.lua), which the other tests leave on their
-- fallback: a PlayerModel answers its creature's display, and a model
-- scene makes an actor whose model loads at once (Forever's six-number
-- bounding box, 2 units tall). The kit makes the actor (a ModelSceneActor,
-- checked against the build like any widget).
local Methods = WoW.Methods
function Methods.GetDisplayInfo(m) return m._creature and (100000 + m._creature) or 0 end
function Methods.SetModelByCreatureDisplayID(a, id) a._model = id; return true end
function Methods.GetActiveBoundingBox(a) if a._model then return -0.5, -0.5, 0, 0.5, 0.5, 2 end end

local ns = H.loadAddon({ libs = libs })
WoW.fireAllRegistered()
for _ = 1, 5 do WoW.step(0.05) end
WoW.fire("UNIT_PET", "player")
WoW.advance(1)

-- Hover, press, drag and click every frame that answers to it, as the
-- player would. A secure button's own click (the kit's secure action) is
-- left out: PreClick and PostClick run, as the client runs them.
local function click(f, button, down)
    if f then WoW.click(f, button or "LeftButton", down or false) end
end
local function poke()
    local list = {}
    for _, f in ipairs(WoW.frames) do list[#list + 1] = f end
    for _, f in ipairs(list) do
        local s = f._scripts
        if s.OnEnter then s.OnEnter(f) end
        WoW.step(0.05)
        if s.OnMouseDown then s.OnMouseDown(f, "LeftButton") end
        if s.OnMouseUp then s.OnMouseUp(f, "LeftButton") end
        if s.OnDragStart then s.OnDragStart(f, "LeftButton") end
        if s.OnDragStop then s.OnDragStop(f) end
        if s.OnLeave then s.OnLeave(f) end
        WoW.step(0.05)
    end
end
local function clickAll(buttons)
    for _, b in ipairs(buttons) do
        click(b, "LeftButton", true); click(b, "LeftButton", false)
        click(b, "RightButton", true); click(b, "RightButton", false)
        WoW.advance(0.1)
    end
end

-- The bar: its buttons both ways (the soulstone picker and the re-summon
-- prompt open on the right click), then everything hovered.
clickAll(ns.Bar.buttons)
poke()
for _, row in ipairs(ns.SoulPicker.rows or {}) do
    if row:IsShown() then click(row); break end
end

-- The lists above the bar: the summon queue and the healthstone requests.
H.slash("ONETWOTHREE", "queue test")
H.slash("ONETWOTHREE", "hs test")
WoW.advance(1)
poke()
H.slash("ONETWOTHREE", "queue clear")
H.slash("ONETWOTHREE", "hs clear")

-- The demon wheel, then its preview: hover and click every bead.
H.slash("ONETWOTHREE", "wheel")
for _ = 1, 40 do WoW.step(0.05) end
poke()
H.slash("ONETWOTHREE", "preview")
for _ = 1, 10 do WoW.step(0.05) end
poke()
H.slash("ONETWOTHREE", "preview")
if ns.Wheel.open then ns.Wheel:Toggle() end
for _ = 1, 20 do WoW.step(0.05) end

-- The options page: every control clicked.
H.slash("ONETWOTHREE", "options")
local panel = ns.Options.panel
if panel._scripts.OnShow then panel._scripts.OnShow(panel) end
do
    local list = {}
    for _, f in ipairs(WoW.frames) do list[#list + 1] = f end
    for _, f in ipairs(list) do
        if f._scripts.OnClick and not f._protected then click(f) end
        if f._scripts.OnEnterPressed then f._scripts.OnEnterPressed(f) end
        if f._scripts.OnEditFocusLost then f._scripts.OnEditFocusLost(f) end
    end
end
if panel._scripts.OnHide then panel._scripts.OnHide(panel) end

-- Every slash command, the toggles twice.
for _, cmd in ipairs({ "debug", "queue", "hs", "labels", "labels", "sounds", "sounds", "camera", "camera",
                       "confirm", "confirm", "config", "", "", "bogus" }) do
    H.slash("ONETWOTHREE", cmd)
    WoW.step(0.05)
end

-- Combat with the wheel open, then out of it.
H.slash("ONETWOTHREE", "wheel")
for _ = 1, 10 do WoW.step(0.05) end
WoW.enterCombat()
WoW.advance(1)
H.slash("ONETWOTHREE", "wheel")
WoW.leaveCombat()
WoW.advance(1)
for _ = 1, 20 do WoW.step(0.05) end

local actors = 0
for pair in pairs(WoW.methodsCalled) do
    if pair:find("^ModelSceneActor:") then actors = actors + 1 end
end
check(actors >= 6, "the exercise reached the 3D portraits (" .. actors .. " actor methods called)")

-- The floor is what the exercise records today, rounded down (163 with both
-- libraries, 152 on the addon's fallbacks without them): it keeps the
-- exercise from quietly shrinking.
local recorded = Kit.checkMethods()
local floor = #libs == 2 and 160 or 150
check(recorded >= floor, "the exercise reached the windows (" .. recorded .. " recorded)")

eq(#swallowed, 0, "no error was swallowed by a pcall during the exercise: " .. tostring(swallowed[1]))

done("test_methods")
