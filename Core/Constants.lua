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
    WHITE = "Interface\\Buttons\\WHITE8X8",
}

-- Warlock purple; the chat prefix and the bar accent.
ns.Colors = {
    ACCENT = { 0.58, 0.51, 0.79 },
    TEXT = { 1, 1, 1, 0.9 },
    MUTED = { 1, 1, 1, 0.6 },
}
