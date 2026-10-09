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

-- A rounded-rect glass pill. Returns g with g.top, the frame to parent
-- content above the glass to.
function Skin:Pill(host)
    local glass = self:Glass()
    if glass then
        local ok, g = pcall(glass.Apply, host, "small")
        if ok and g then
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
