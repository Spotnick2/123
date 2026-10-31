local addonName, ns = ...

-- Not a Warlock: nothing of 123 runs (#39). The client reads an enabled
-- addon's files whatever the class, so each file stops on its first line
-- (`if ns.skip then return end`; test_manifest checks every one). A class
-- not readable yet at load leaves skip false: the login gate in Init still
-- stops 123 there.
local okClass, _, classFile = pcall(UnitClass, "player")
ns.skip = okClass and type(classFile) == "string" and classFile ~= "WARLOCK"
if ns.skip then return end

ns.AddonName = addonName
ns.MediaRoot = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

ns.Constants = {
    -- Saved-variable schema.
    VERSION = 1,
    CLASS_WARLOCK = "WARLOCK",
    DEFAULTS = {
        version = 1,
        -- Ask before re-summoning the demon that is already out.
        confirmResummon = true,
        -- The names under the bar's icons (the tooltips say it). /123 labels.
        barLabels = false,
        -- The demons' voices on the wheel (hover, click). /123 sounds.
        sounds = true,
        -- Alert sounds (#14): a sound kit per alert, picked on the options
        -- page (Core/Sound.lua lists the choices).
        alertSounds = true,
        alerts = {
            summonRequest = 3081,
            stoneRequest = 880,
        },
        -- Summon queue (#9): who typed a keyword in group chat; minutes
        -- before a request drops off.
        queue = {
            enabled = true,
            keywords = { "123" },
            timeout = 10,
        },
        -- Healthstone requests (#8): a keyword in group chat or a whisper
        -- opens the trade prompt. Whispers from outside the group only
        -- with `strangers`.
        stones = {
            enabled = true,
            keywords = { "hs", "healthstone" },
            strangers = false,
        },
        -- Group chat when a Ritual of Summoning starts (#11). An empty text
        -- is the default line, in the client's language.
        announce = {
            summon = true,
            summonText = "",
            clickers = false,
            clickersText = "",
        },
        -- Minimap button (LibDBIcon) and Addon Compartment entry (#15).
        showMinimapButton = true,
        showCompartment = true,
        minimap = {},
        -- Opening the demon wheel (LibShowcase-1.0): hide the game UI and
        -- run the cinematic camera, as Portal Roulette does. /123 camera.
        cinematicCamera = true,
        hideGameUI = true,
        cameraOrbit = true,
        showcase = {},
        bar = {
            point = "CENTER",
            x = 0,
            y = -180,
            shown = true,
            scale = 1,
        },
    },
}

ns.Media = {
    -- Compact bar (#13, Tools/make_bar_art.py); neutral art tinted by Lua.
    BAR_FRAME = ns.MediaRoot .. "Bar_Frame_64.tga",
    BAR_RIM = ns.MediaRoot .. "Bar_RimLight_64.tga",
    BAR_GLOW = ns.MediaRoot .. "Bar_Glow_128.tga",
    BAR_GRIP = ns.MediaRoot .. "Bar_Grip_32.tga",
    BAR_DIVIDER = ns.MediaRoot .. "Bar_Divider_8x64.tga",
    -- The fel wheel (#13, Tools/make_wheel_art.py). WHEEL_NODE's opaque band
    -- hides the portrait model's square edges (a 3D model can't be masked).
    WHEEL_SHADOW = ns.MediaRoot .. "Wheel_Shadow_512.tga",
    WHEEL_CIRCLE = ns.MediaRoot .. "Wheel_Circle_512.tga",
    WHEEL_RUNES = ns.MediaRoot .. "Wheel_Runes_512.tga",
    WHEEL_MIST = ns.MediaRoot .. "Wheel_Mist_512.tga",
    WHEEL_FLAME = ns.MediaRoot .. "Wheel_Flame_512.tga",
    WHEEL_NODE = ns.MediaRoot .. "Wheel_Node_256.tga",
    WHEEL_NODE_LIGHT = ns.MediaRoot .. "Wheel_NodeLight_256.tga",
    WHEEL_CREST = ns.MediaRoot .. "Wheel_Crest_512.tga",
    WHEEL_SIGIL = ns.MediaRoot .. "Wheel_Sigil_256.tga",
    WHEEL_GLOW = ns.MediaRoot .. "Wheel_Glow_128.tga",
    WHEEL_EMBER = ns.MediaRoot .. "Wheel_Ember_64.tga",
    WHEEL_PLATE = ns.MediaRoot .. "Wheel_Plate_256.tga",
    WHITE = "Interface\\Buttons\\WHITE8X8",
}

-- Warlock purple; the chat prefix and the bar accent.
ns.Colors = {
    ACCENT = { 0.58, 0.51, 0.79 },
    -- The demon wheel's fel theme (owner's "Fel concept" mockup).
    FEL = { 0.48, 1, 0.12 },
    TEXT = { 1, 1, 1, 0.9 },
    MUTED = { 1, 1, 1, 0.6 },
}
