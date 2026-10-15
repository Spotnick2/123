local addonName, ns = ...

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
