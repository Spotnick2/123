-- ============================================================
-- Skin: the glass material, through LibGlass-1.0 when the loaded copy is
-- recent enough, else a plain fallback that keeps the addon usable. Every
-- surface is made here, so the rest of the UI never talks to LibGlass
-- directly. (Portal Roulette's UI/Skin.lua, trimmed to what 123 uses.)
-- ============================================================

local _, ns = ...

local Skin = {}
ns.Skin = Skin

local NEEDS_MINOR = 5
local WHITE = ns.Media.WHITE

-- The LibGlass instance, or nil when the library is missing or too old.
function Skin:Glass()
    if self.glass ~= nil then
        return self.glass or nil
    end
    self.glass = false
    local stub = _G.LibStub
    local lib, minor
    if stub then
        -- Not `stub and stub:GetLibrary(...)`: `and` keeps only one value.
        lib, minor = stub:GetLibrary("LibGlass-1.0", true)
    end
    if lib and minor and minor >= NEEDS_MINOR and lib.ready == minor then
        local ok, instance = pcall(lib.New, lib, { font = "arial" })
        if ok and instance then
            self.glass = instance
        end
    end
    if not self.glass and not self.warned then
        self.warned = true
        if ns.Print then
            ns.Print("|cffff6060LibGlass-1.0 r" .. NEEDS_MINOR .. "+ not found: using the plain look.|r")
        end
    end
    return self.glass or nil
end

local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function circleMask(frame, region)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(region or frame)
    return mask
end

-- A texture clipped to a circle covering `frame`.
function Skin:RoundTexture(frame, layer, sublevel)
    local texture = frame:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
    texture:SetAllPoints()
    texture:AddMaskTexture(circleMask(frame, texture))
    return texture
end

-- The class colour's share of the glass: AltStable's class-coloured glass
-- (#220 there), tried in game on its clear preset. At full strength the glass
-- went milky; at 60% it reads as a cast on the glass. The alpha stays the
-- surface's own (SetSurfaceTint with no alpha keeps the built one).
local CLASS_SHADE = 0.6

-- The Warlock colour: the client's class colour, else the addon's accent.
function Skin:ClassColor()
    local colors = RAID_CLASS_COLORS
    local c = type(colors) == "table" and colors.WARLOCK
    if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
    return ns.Colors.ACCENT[1], ns.Colors.ACCENT[2], ns.Colors.ACCENT[3]
end

-- Every LibGlass surface of 123 wears the Warlock colour.
function Skin:ClassTint(g)
    local glass = self:Glass()
    if not (glass and glass.SetSurfaceTint and g) then return false end
    local r, gg, b = self:ClassColor()
    local ok, done = pcall(glass.SetSurfaceTint, g, r * CLASS_SHADE, gg * CLASS_SHADE, b * CLASS_SHADE)
    return ok and done ~= false
end

-- A round glass surface on a square host (the wheel). Returns g with g.top,
-- the frame to parent content above the glass to, and g.rim when there is
-- one. size: "disc" (128 px and up) or "disc_small".
function Skin:Disc(host, size)
    local glass = self:Glass()
    if glass and glass.Disc then
        local ok, g = pcall(glass.Disc, host, size)
        if ok and g then
            self:ClassTint(g)
            return g
        end
    end
    -- Fallback: a light edge circle under a dark translucent fill.
    local g = {}
    local rim = self:RoundTexture(host, "BACKGROUND", -7)
    rim:SetTexture(WHITE)
    rim:SetVertexColor(0.85, 0.8, 1, 0.45)
    local fillHost = CreateFrame("Frame", nil, host)
    fillHost:SetPoint("TOPLEFT", 2, -2)
    fillHost:SetPoint("BOTTOMRIGHT", -2, 2)
    fillHost:SetFrameLevel(host:GetFrameLevel())
    local fill = self:RoundTexture(fillHost, "BACKGROUND", -6)
    fill:SetTexture(WHITE)
    fill:SetVertexColor(0.08, 0.06, 0.12, 0.72)
    local top = CreateFrame("Frame", nil, host)
    top:SetAllPoints()
    top:SetFrameLevel(host:GetFrameLevel() + 10)
    g.top, g.rim, g.fill = top, rim, fill
    return g
end

-- Tint a surface's rim toward an accent colour.
function Skin:SetRimColor(g, r, gg, b, a)
    local rim = g and g.rim
    if rim and rim.SetVertexColor then
        rim:SetVertexColor(r, gg, b, a or 1)
    end
end

-- A rounded-rect glass pill. Returns g with g.top, the frame to parent
-- content above the glass to.
function Skin:Pill(host)
    local glass = self:Glass()
    if glass then
        local ok, g = pcall(glass.Apply, host, "small")
        if ok and g then
            self:ClassTint(g)
            return g
        end
    end
    local g = {}
    local bg = host:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(WHITE)
    bg:SetVertexColor(0.08, 0.06, 0.12, 0.72)
    local edge = host:CreateTexture(nil, "BORDER")
    edge:SetPoint("TOPLEFT")
    edge:SetPoint("TOPRIGHT")
    edge:SetHeight(1)
    edge:SetTexture(WHITE)
    edge:SetVertexColor(1, 1, 1, 0.28)
    local top = CreateFrame("Frame", nil, host)
    top:SetAllPoints()
    top:SetFrameLevel(host:GetFrameLevel() + 10)
    g.top, g.bg = top, bg
    return g
end

-- A FontString in the glass font, or the game font.
function Skin:Font(parent, size, justify)
    local glass = self:Glass()
    if glass and glass.Font then
        local ok, fs = pcall(glass.Font, parent, size, justify)
        if ok and fs then
            return fs
        end
    end
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local font = fs:GetFont()
    if font then
        fs:SetFont(font, size or 12, "")
    end
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    if justify then
        fs:SetJustifyH(justify)
    end
    return fs
end
