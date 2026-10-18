-- Fel ritual art and motion (#13). Only mouse-disabled visual children and
-- textures are animated. One visible-only clock, on WorldFrame like Portal
-- Roulette's Disc: hiding UIParent for the camera must not freeze the fire.
-- Assets: Tools/make_wheel_art.py. Widget APIs checked in the 70338 dump.
local _, ns = ...
if ns.skip then return end
local FX = {}
ns.WheelEffects = FX
local M = ns.Media
local PI2 = math.pi * 2
local OPEN, CLOSE = 0.58, 0.30
-- Portal Roulette's rune sway: four degrees out and back, two seconds per leg.
local RUNE_SWAY, RUNE_PERIOD = math.rad(2), 4
-- HearthOrb-style growth, strengthened for the wheel's smaller portraits.
local HOVER_GROWTH = 0.12
local FEL = ns.Colors.FEL
local PALETTE = {
    normal = { 0.38, 0.62, 0.19 }, active = FEL,
    unlearned = { 0.40, 0.43, 0.37 }, missing = { 1, 0.23, 0.12 },
    sacrificed = { 0.78, 0.32, 1 },
}

local function clamp(x) return math.max(0, math.min(1, x)) end
local function ease(x) x = clamp(x) return x * x * (3 - 2 * x) end

function FX.Texture(host, key, w, h, layer, additive)
    local tex = host:CreateTexture(nil, layer or "ARTWORK")
    tex:SetSize(w, h or w)
    tex:SetPoint("CENTER")
    tex:SetTexture(M[key])
    if additive then tex:SetBlendMode("ADD") end
    return tex
end

function FX.Plate(host)
    local tex = host:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints(host)
    tex:SetTexture(M.WHEEL_PLATE)
    return tex
end

-- The future #20 aura reader supplies a plain node.sacrificed boolean.
-- This renderer does not infer buffs or inspect secret aura values.
function FX.NodeState(node)
    if not node.known then return "unlearned" end
    if node.sacrificed then return "sacrificed" end
    if node.isActive then return "active" end
    if node.missingReagent then return "missing" end
    return "normal"
end

-- Called every frame for every bead: it writes only what changed (an idle,
-- unhovered bead costs a comparison), except the active bead's breathing.
function FX.PaintNode(node, t)
    local state = FX.NodeState(node)
    local hover = node.hoverLight or 0
    local key = state .. hover
    local active = state == "active"
    if key == node.paintKey and not active then return end
    local c = PALETTE[state]
    if key ~= node.paintKey then
        node.paintKey = key
        -- The portrait, mask-covering rim and labels are one visual child.
        -- Its secure parent retains its size, position and mouse footprint.
        node.visual:SetScale(1 + HOVER_GROWTH * hover)
        -- Disabled portraits stay grey, including the metal's small green gems.
        node.ring:SetDesaturated(state == "unlearned")
        node.edge:SetVertexColor(c[1], c[2], c[3])
        node.halo:SetVertexColor(c[1], c[2], c[3])
    end
    local pulse = active and (.5 + .5 * math.sin(t * PI2 / 2.8)) or 0
    node.edge:SetAlpha((state == "unlearned" and .22 or .64) + .20 * hover + .15 * pulse)
    node.halo:SetAlpha((active and .12 + .07 * pulse or .025) + hover * .16)
end

function FX.Create(wheel)
    local fx = { wheel = wheel, time = 0, phase = "stopped", age = 0, layers = {}, embers = {} }
    local disc = wheel.disc
    local size = disc:GetWidth()
    fx.size = size
    fx.shadow = FX.Texture(disc, "WHEEL_SHADOW", size, size, "BACKGROUND")
    fx.circle = FX.Texture(disc, "WHEEL_CIRCLE", size, size, "BORDER", true)
    fx.circle:SetVertexColor(.63, .82, .30, .85)
    local specs = {
        { "WHEEL_MIST", 1, 47, .30, .2 },
        { "WHEEL_FLAME", .99, -39, .40, 2.2 },
        { "WHEEL_FLAME", .94, 61, .26, 4.5 },
    }
    for i, spec in ipairs(specs) do
        local tex = FX.Texture(disc, spec[1], size * spec[2], size * spec[2], "ARTWORK", true)
        tex:SetVertexColor(i == 1 and .31 or .50, .92, .07)
        fx.layers[i] = { tex = tex, size = size * spec[2], turn = spec[3], alpha = spec[4], offset = spec[5] }
    end
    fx.runes = FX.Texture(disc, "WHEEL_RUNES", size, size, "OVERLAY", true)
    fx.runes:SetVertexColor(.62, 1, .16)
    fx.wave = FX.Texture(disc, "WHEEL_CIRCLE", size, size, "OVERLAY", true)
    fx.wave:SetVertexColor(.72, 1, .24)
    -- Rain-of-fire-inspired accents, confined to the outside of the ritual.
    -- A fixed pool, deterministic phases, no per-frame tables or timers.
    for i = 1, 14 do
        local angle = i * PI2 / 14 + .14
        local x, y = math.cos(angle) * size * .438, math.sin(angle) * size * .438
        local ember = FX.Texture(disc, "WHEEL_EMBER", 10, 36, "OVERLAY", true)
        ember:SetVertexColor(.63, 1, .13)
        local impact = FX.Texture(disc, "WHEEL_GLOW", 22, 12, "OVERLAY", true)
        impact:SetPoint("CENTER", disc, "CENTER", x, y)
        impact:SetVertexColor(.66, 1, .13)
        fx.embers[i] = { tex = ember, impact = impact, x = x, y = y, phase = i * .317 % 1 }
    end
    local center = wheel.centerVisual
    fx.floor = FX.Texture(center, "WHEEL_SIGIL", 144, 34, "BACKGROUND", true)
    fx.floor:SetPoint("CENTER", center, "CENTER", 0, -20)
    fx.floor:SetVertexColor(.49, 1, .09)
    fx.aura = FX.Texture(center, "WHEEL_GLOW", 120, 112, "BACKGROUND", true)
    fx.aura:SetPoint("CENTER", center, "CENTER", 0, 16)
    fx.aura:SetVertexColor(.37, .90, .05)
    fx.driver = CreateFrame("Frame", nil, WorldFrame)
    fx.driver:EnableMouse(false)
    fx.driver:Hide()
    return fx
end

local function alpha(wheel, value)
    wheel.stage:SetAlpha(value)
    wheel.centerVisual:SetAlpha(value)
    wheel.closeVisual:SetAlpha(value)
    for _, node in ipairs(wheel.nodes) do node.visual:SetAlpha(value) end
end

function FX.Start(fx)
    fx.time, fx.age, fx.phase, fx.selected = 0, 0, "opening", nil
    for _, node in ipairs(fx.wheel.nodes) do
        node.hovered, node.hoverLight = false, 0
    end
    alpha(fx.wheel, 0)
    FX.Update(fx, 0)
    fx.driver:SetScript("OnUpdate", function(_, dt) FX.Update(fx, dt) end)
    fx.driver:Show()
end

function FX.Close(fx, selected)
    -- Retain each current alpha so closing during ignition never flashes.
    fx.closeStage = fx.wheel.stage:GetAlpha()
    fx.closeCenter = fx.wheel.centerVisual:GetAlpha()
    fx.closeControl = fx.wheel.closeVisual:GetAlpha()
    for _, node in ipairs(fx.wheel.nodes) do node.closeAlpha = node.visual:GetAlpha() end
    fx.phase, fx.age, fx.selected = "closing", 0, selected
end

-- `keepButtons`: a close under combat lockdown, where the secure buttons
-- can neither hide nor drop their mouse input until combat ends. They keep
-- casting, so they stay visible (static, no effects) rather than become
-- invisible armed targets; the decoration fades.
function FX.Stop(fx, keepButtons)
    fx.driver:SetScript("OnUpdate", nil)
    fx.driver:Hide()
    fx.phase, fx.selected = "stopped", nil
    fx.wave:SetAlpha(0)
    for _, ember in ipairs(fx.embers) do
        ember.tex:SetAlpha(0)
        ember.impact:SetAlpha(0)
    end
    for _, node in ipairs(fx.wheel.nodes) do
        node.hovered, node.hoverLight, node.paintKey = false, 0, nil
        node.visual:SetScale(1)
    end
    alpha(fx.wheel, 0)
    if keepButtons then
        fx.wheel.centerVisual:SetAlpha(1)
        fx.wheel.closeVisual:SetAlpha(1)
        for _, node in ipairs(fx.wheel.nodes) do node.visual:SetAlpha(1) end
    end
end

function FX.Update(fx, dt)
    if fx.phase == "stopped" then return end
    fx.time, fx.age = fx.time + dt, fx.age + dt
    local t, age, wheel = fx.time, fx.age, fx.wheel
    if fx.phase == "closing" then
        if age >= CLOSE then wheel:FinishClose() return end
        local fade = 1 - ease(age / CLOSE)
        wheel.stage:SetAlpha(fx.closeStage * fade)
        wheel.centerVisual:SetAlpha(fx.closeCenter * fade)
        wheel.closeVisual:SetAlpha(fx.closeControl * fade)
        for _, node in ipairs(wheel.nodes) do node.visual:SetAlpha(node.closeAlpha * fade) end
        -- A final contraction; a chosen summon briefly feeds the circle.
        local scale = 1 - .34 * ease(age / CLOSE)
        fx.wave:SetSize(fx.size * scale, fx.size * scale)
        fx.wave:SetAlpha((fx.selected and 1 or .65) * math.sin(age / CLOSE * math.pi))
    elseif fx.phase == "opening" then
        wheel.stage:SetAlpha(ease(age / .28))
        wheel.centerVisual:SetAlpha(ease((age - .06) / .30))
        wheel.closeVisual:SetAlpha(ease(age / .18))
        for i, node in ipairs(wheel.nodes) do node.visual:SetAlpha(ease((age - .04 - (i - 1) * .035) / .26)) end
        local p = ease(age / OPEN)
        fx.wave:SetSize(fx.size * (.30 + .70 * p), fx.size * (.30 + .70 * p))
        fx.wave:SetAlpha(.9 * math.sin(p * math.pi))
        if age >= OPEN then
            fx.phase = "idle"
            alpha(wheel, 1)
            fx.wave:SetAlpha(0)
            -- Clicks only once every bead can be seen (code review, #23).
            wheel:OnOpened()
        end
    end
    -- The decoration only runs while the wheel can be seen (Alt+Z hides
    -- UIParent with the camera off); the fades above still finish.
    if not wheel.root:IsVisible() then return end
    for i, layer in ipairs(fx.layers) do
        layer.tex:SetRotation(layer.offset + t * PI2 / layer.turn)
        layer.tex:SetAlpha(layer.alpha * (.85 + .15 * math.sin(t * .8 + i * 2)))
    end
    fx.runes:SetRotation(RUNE_SWAY * (1 - math.cos(PI2 * t / RUNE_PERIOD)))
    fx.runes:SetAlpha(.57 + .09 * math.sin(t * .65))
    fx.floor:SetAlpha(wheel.petOut and (.66 + .13 * math.sin(t * 2)) or .26)
    fx.aura:SetAlpha(wheel.petOut and (.23 + .06 * math.sin(t * 2)) or .08)
    for _, ember in ipairs(fx.embers) do
        local p = (t / 2.6 + ember.phase) % 1
        if p < .72 then
            local fall = p / .72
            -- One CENTER anchor, replaced in place: no ClearAllPoints.
            ember.tex:SetPoint("CENTER", wheel.disc, "CENTER", ember.x + 4 * (1 - fall), ember.y + 32 * (1 - fall))
            ember.tex:SetAlpha(math.sin(fall * math.pi) * .56)
            if ember.landed then ember.impact:SetAlpha(0) ember.landed = false end
        else
            if not ember.landed then ember.tex:SetAlpha(0) ember.landed = true end
            ember.impact:SetAlpha(math.sin((p - .72) / .28 * math.pi) * .32)
        end
    end
    for _, node in ipairs(wheel.nodes) do
        local target = node.hovered and 1 or 0
        local value = node.hoverLight or 0
        if target > value then value = math.min(target, value + dt / .16)
        else value = math.max(target, value - dt / .24) end
        node.hoverLight = value
        FX.PaintNode(node, t)
        if fx.phase == "closing" and fx.selected == node.index then
            node.halo:SetAlpha(.2 + .7 * math.sin(age / CLOSE * math.pi))
            node.edge:SetAlpha(1)
        end
    end
end
