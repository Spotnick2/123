-- Compact bar decoration; no API reads or protected-frame mutations.
local _, ns = ...
if ns.skip then return end

local FX = {}
ns.BarEffects = FX
FX.PALETTE = {
    normal = ns.Colors.ACCENT, unlearned = { 0.40, 0.43, 0.37 },
    missing = { 1, 0.23, 0.12 }, armor = ns.Colors.ACCENT,
    waiting = ns.Colors.FEL, hover = { 0.85, 0.78, 1 },
    metal = { 0.8, 0.8, 0.8 }, grip = { 1, 1, 1 },
    rimAlpha = 0.7, hoverAlpha = 0.9, glowAlpha = 0.7, gripAlpha = 0.45,
}
FX.TIMING = { armor = 0.8, waiting = 1.4, low = 0.35, high = 1 }

local function tint(texture, color, alpha)
    texture:SetVertexColor(color[1], color[2], color[3], alpha or 1)
end

local function texture(parent, anchor, layer, path, size, sublevel)
    local t = parent:CreateTexture(nil, layer, nil, sublevel or 0)
    t:SetTexture(path)
    t:SetSize(size, size)
    t:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    return t
end

function FX.State(button)
    if button.barWheel then return "normal" end
    if not button.action then return "unlearned" end
    if button.short then return "missing" end
    if button.armorState == "missing" then return "armor" end
    if button.key == "summoning" and #ns.Queue.entries > 0 then return "waiting" end
    return "normal"
end

function FX.Update(button)
    local state = FX.State(button)
    button.barState = state
    tint(button.barRim, FX.PALETTE[state], FX.PALETTE.rimAlpha)
    if button.glow then
        local on = state == "armor" or state == "waiting"
        button.glow:SetShown(on)
        if on then
            tint(button.glow, FX.PALETTE[state], FX.PALETTE.glowAlpha)
            if not button.pulse:IsPlaying() then button.pulse:Play() end
        else
            button.pulse:Stop()
        end
    end
end

function FX.Attach(button, overlay, wheel)
    button.barWheel = wheel
    -- Sublevel 1: on the Demons button the frame shares the icon's layer
    -- and must draw over its edge.
    local frame = texture(overlay, button, "ARTWORK", ns.Media.BAR_FRAME, 40, 1)
    tint(frame, FX.PALETTE.metal)
    button.barRim = texture(overlay, button, "OVERLAY", ns.Media.BAR_RIM, 40)
    -- HIGHLIGHT on the button itself needs no hover scripts or clock.
    local hover = texture(button, button, "HIGHLIGHT", ns.Media.BAR_RIM, 40)
    hover:SetBlendMode("ADD")
    tint(hover, FX.PALETTE.hover, FX.PALETTE.hoverAlpha)
    if button.key == "armor" or button.key == "summoning" then
        button.glow = texture(overlay, button, "BACKGROUND", ns.Media.BAR_GLOW, 56)
        button.glow:SetBlendMode("ADD")
        local pulse = button.glow:CreateAnimationGroup()
        pulse:SetLooping("BOUNCE")
        local fade = pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(FX.TIMING.high)
        fade:SetToAlpha(FX.TIMING.low)
        fade:SetDuration(button.key == "armor" and FX.TIMING.armor or FX.TIMING.waiting)
        button.pulse = pulse
    end
    FX.Update(button)
end

function FX.Grip(handle)
    local grip = handle:CreateTexture(nil, "ARTWORK")
    grip:SetTexture(ns.Media.BAR_GRIP)
    grip:SetSize(10, 26)
    grip:SetPoint("RIGHT", handle, "LEFT", 3, 0)
    tint(grip, FX.PALETTE.grip, FX.PALETTE.gripAlpha)
end
