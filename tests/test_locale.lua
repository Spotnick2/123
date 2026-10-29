-- Localization (#22): every string the code shows goes through ns.L, each
-- shipped locale translates all of them with the same placeholders, and on
-- a French client the wheel names its demons and finds Demonic Sacrifice's
-- line from the client's own French names.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

local LOCALES = { "frFR", "deDE" }

------------------------------------------------------------
-- Static: the keys the code uses, against each locale file
------------------------------------------------------------

-- Every L["..."] literal in a source file, unescaped.
local function keysIn(path, into)
    local src = assert(io.open(path)):read("*a")
    local i = 1
    while true do
        local s, e = src:find('L%["', i)
        if not s then break end
        local j = e + 1
        while src:sub(j, j) ~= '"' do
            j = j + (src:sub(j, j) == "\\" and 2 or 1)
        end
        local literal = src:sub(e, j)
        into[assert(loadstring("return " .. literal))()] = path
        i = j + 1
    end
end

local used = {}
for _, f in ipairs(H.tocFiles("123.toc")) do
    if f:find("%.lua$") and not f:find("^Libs/") and not f:find("^Locales/") then
        keysIn(f, used)
    end
end
local count = 0
for _ in pairs(used) do count = count + 1 end
H.check(count > 90, "the code's strings go through L (" .. count .. " keys)")

-- The placeholders of a string, in order ("%s%d"); "%%" is not one.
local function placeholders(text)
    return (text:gsub("%%%%", ""):gsub("[^%%]*(%%?[%-%d%.]*[sdif]?)", function(p)
        return p:find("^%%") and p or ""
    end))
end
H.eq(placeholders("%s: needs %s (100%%)"), "%s%s", "placeholders are read in order")

for _, locale in ipairs(LOCALES) do
    local path = "Locales/" .. locale .. ".lua"
    H.check(H.tocFiles("123.toc") and io.open(path) ~= nil, path .. " exists")
    local L = {}
    local ns = { skip = false, locale = locale, L = L }
    assert(loadfile(path))("123", ns)
    for key, value in pairs(L) do
        H.check(used[key] ~= nil, locale .. ": " .. key .. " is used by the code")
        H.check(type(value) == "string" and value ~= "", locale .. ": " .. key .. " has text")
        H.eq(placeholders(value), placeholders(key), locale .. ": " .. key .. " keeps its placeholders")
    end
    for key in pairs(used) do
        H.check(L[key] ~= nil, locale .. " translates " .. key)
    end
    -- Another client's file leaves the table alone.
    local other = {}
    assert(loadfile(path))("123", { skip = false, locale = "enUS", L = other })
    H.eq(next(other), nil, locale .. " stays out of other clients")
end

------------------------------------------------------------
-- A French client: names from the client, text from frFR.lua
------------------------------------------------------------

WoW.locale = "frFR"
WoW.families = {
    [15] = "Chasseur corrompu", [16] = "Marcheur du Vide", [17] = "Succube",
    [19] = "Garde funeste", [23] = "Diablotin", [302] = "Incube",
}
WoW.spells[688] = { name = "Invocation d'un diablotin", known = true }
WoW.spells[697] = { name = "Invocation d'un marcheur du Vide", known = true }
WoW.spells[712] = { name = "Invocation d'une succube", known = false }
WoW.spells[691] = { name = "Invocation d'un chasseur corrompu", known = false }
WoW.spells[713] = { name = "Invocation d'un incube", known = false }
WoW.spells[1122] = { name = "Inferno", known = false }
WoW.spells[18540] = { name = "Rituel funeste", known = false }
WoW.spells[18708] = { name = "Domination corrompue", known = true }
WoW.spells[18788] = { name = "Sacrifice démoniaque", known = true }
WoW.spellDescriptions[18788] = "Sacrifie votre démon invoqué.\n\n"
    .. "Diablotin : Augmente vos dégâts d'Ombre de 15%.\n\n"
    .. "Succube/Incube : Augmente vos dégâts de Feu de 15%."
WoW.items[6265] = "Fragment d'âme"
WoW.counts[6265] = 3
WoW.petGUID = "Pet-0-4613-0-1234-416-0000ABCDEF" -- the Imp

local ns = H.loadAddon()
local Wheel = ns.Wheel
H.eq(ns.locale, "frFR", "the client's language is read")
H.eq(ns.L["Soulstone"], "Pierre d'âme", "frFR.lua loaded")
H.eq(ns.L["not a key"], "not a key", "a missing string shows its English")

ns.Bar.wheelButton:GetScript("OnClick")()
local n = Wheel.nodes
H.eq(n[1].label:GetText(), "Marcheur du Vide", "the Voidwalker's bead, in French")
H.eq(n[3].label:GetText(), "Inferno", "Inferno keeps its own name")
H.eq(n[4].label:GetText(), "Garde funeste", "the Doomguard, from its family")
H.eq(n[5].label:GetText(), "Diablotin", "the Imp, not its whole summon")
H.eq(n[6].sub:GetText(), "Non appris", "an unlearned bead says so in French")
H.eq(Wheel.centerName:GetText(), "Diablotin", "the active demon in the centre")

-- Demonic Sacrifice's line, matched on the French name before " : ".
Wheel.center:GetScript("OnEnter")()
H.eq(Wheel.strip.hint:GetText(),
    "Clic droit : Sacrifice démoniaque - Diablotin : Augmente vos dégâts d'Ombre de 15%.",
    "the Imp's Sacrifice line, in French")
n[2].button:GetScript("OnEnter")(n[2].button)
H.eq(Wheel.strip.hint:GetText(), "Chasseur corrompu : pas encore appris", "a bead's hint in French")
n[1].button:GetScript("OnEnter")(n[1].button)
H.eq(Wheel.strip.hint:GetText(),
    "Clic : Invocation d'un marcheur du Vide    Maj : Domination corrompue d'abord",
    "Fel Domination by the client's own name")

-- The re-summon question names the demon in French.
ns.Resummon:Show(ns.Bar:Button("demon"), 688)
H.eq(ns.Resummon.text:GetText(), "Diablotin est déjà là. L'invoquer à nouveau ?", "the question, in French")
ns.Resummon:Hide()

-- Without the family API (unmeasured on Forever), nothing is nil: the
-- bead shows the summon's whole name, the Doomguard its translated label.
WoW.families = {}
Wheel:Paint()
H.eq(n[5].label:GetText(), "Invocation d'un diablotin", "no family: the whole summon name")
H.eq(n[4].label:GetText(), "Garde funeste", "no family: the Doomguard's label")

H.done("test_locale")
