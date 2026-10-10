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
        -- The demons' voices on the wheel (hover, click). /123 sounds.
        sounds = true,
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
        },
    },
}

ns.Media = {
    -- The wheel bead's ring (Tools/make_bead_ring.py): an opaque band that
    -- hides the portrait model's square edges, and its two edge lines.
    BEAD_RING = ns.MediaRoot .. "Bead_Ring_128.tga",
    BEAD_EDGE = ns.MediaRoot .. "Bead_Edge_128.tga",
    WHITE = "Interface\\Buttons\\WHITE8X8",
}

-- Warlock purple; the chat prefix and the bar accent.
ns.Colors = {
    ACCENT = { 0.58, 0.51, 0.79 },
    -- The demon wheel's fel theme (owner's "Fel concept" mockup).
    FEL = { 0.47, 0.95, 0.22 },
    TEXT = { 1, 1, 1, 0.9 },
    MUTED = { 1, 1, 1, 0.6 },
}
