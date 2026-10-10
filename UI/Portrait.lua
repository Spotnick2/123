-- ============================================================
-- Portrait: a demon's live, idling 3D model, for the wheel's centre (whole
-- body) and its beads (a head crop).
--
-- The recipe measured by AltStable (Scanner.lua, #75 there), Gnomesweeper
-- (Models.lua) and TimeIsMoney (UI/Director.lua, docs/MODELS.md):
--   * A creature's display ID from a hidden PlayerModel: SetCreature(npc) ->
--     GetDisplayInfo() (Voidwalker 1860 -> 1132). A single-look creature, as
--     demons are, answers one display; a multi-look one may answer any.
--   * A plain ModelScene with one actor, SetModelByCreatureDisplayID, a camera
--     at +40 on X facing back, field of view 0.15, clip 0.1-100, the actor's
--     origin centred, the box polled until the model is in (a token drops a
--     late answer). The idle animation runs by itself.
--   * Head crop (TimeIsMoney): the top 0.40 of the model's height fills the
--     frame with headroom; the client scales the actor's position, so the
--     offset is divided by the scale. Particles off: they escape the frame.
--   * Fallbacks: the client's round 2D portrait from the same display
--     (SetPortraitTextureFromCreatureDisplayID, TimeIsMoney's verified one),
--     then the caller's icon.
-- No measured heights for demons yet: the framing reads the live box, which
-- follows the idle pose (TimeIsMoney pins measured heights instead).
-- ============================================================

local _, ns = ...

local Portrait = {}
ns.Portrait = Portrait

local FOV, CAMERA = 0.15, 40
local WAIT, POLL = 1.5, 0.1
-- Whole body: the model is drawn this share of the frame tall. In game at
-- 0.8 the Imp overflowed the disc and its flames were cut at the scene's
-- edge (a creature's effects reach past its box; Gnomesweeper measured it).
local FILL = 0.6
-- Head crop (TimeIsMoney's measured 0.40 / 1.15, with more headroom here: a
-- round bead hides the scene's corners).
Portrait.HEAD = { fraction = 0.40, margin = 1.35 }

local resolver
-- The display ID of a creature NPC, or nil.
function Portrait.DisplayID(npcID)
    if not npcID then return nil end
    if not resolver then
        local ok, model = pcall(CreateFrame, "PlayerModel", nil, UIParent)
        if not ok or not model then return nil end
        model:SetSize(1, 1)
        model:Hide()
        resolver = model
    end
    if not pcall(resolver.SetCreature, resolver, npcID) then return nil end
    local ok, id = pcall(resolver.GetDisplayInfo, resolver)
    pcall(resolver.ClearModel, resolver)
    id = ok and ns.API.Number(id)
    return (id and id > 0) and id or nil
end

-- The model's height in scene units, or nil until it has loaded. Forever
-- returns six numbers; Retail returns two vectors.
local function readHeight(actor)
    local r = { pcall(actor.GetActiveBoundingBox, actor) }
    if not r[1] then return nil end
    local z0, z1
    if type(r[2]) == "table" and type(r[3]) == "table" then
        z0, z1 = r[2].z, r[3].z
    else
        z0, z1 = r[4], r[7]
    end
    z0, z1 = ns.API.Number(z0), ns.API.Number(z1)
    if not (z0 and z1) or z1 - z0 <= 0.001 then return nil end
    return z1 - z0
end

-- Actor scale and vertical position for `height` in a square frame: the
-- whole body at FILL, or the top `crop.fraction` with `crop.margin`.
function Portrait.Framing(height, crop)
    local span = 2 * CAMERA * math.tan(FOV / 2)
    if not crop then
        return span * FILL / height, 0
    end
    local scale = span / (height * crop.fraction * crop.margin)
    local offset = -(1 - crop.fraction) / 2 * height * scale
    return scale, offset / scale
end

-- A portrait `size` px square on `parent`, centred on it. `crop`: nil for
-- the whole body, Portrait.HEAD for a head crop. The fallbacks: p.flat (the
-- 2D portrait), then onFail (the caller's icon).
--   p:Show(npcID, onFail), p:Hide(), p:SetDesaturated(bool)
function Portrait.Create(parent, size, crop)
    local p = { token = 0 }
    local flatHost = CreateFrame("Frame", nil, parent)
    flatHost:SetSize(size, size)
    flatHost:SetPoint("CENTER")
    flatHost:EnableMouse(false)
    p.flatHost = flatHost
    local flat = ns.Skin:RoundTexture(flatHost, "ARTWORK")
    flat:Hide()
    p.flat = flat

    local ok, scene = pcall(CreateFrame, "ModelScene", nil, parent)
    local okA, actor
    if ok and scene then okA, actor = pcall(scene.CreateActor, scene) end
    if okA and actor then
        scene:SetSize(size, size)
        scene:SetPoint("CENTER")
        scene:EnableMouse(false)
        pcall(scene.SetCameraFieldOfView, scene, FOV)
        pcall(scene.SetCameraNearClip, scene, 0.1)
        pcall(scene.SetCameraFarClip, scene, 100)
        pcall(scene.SetCameraPosition, scene, CAMERA, 0, 0)
        pcall(scene.SetCameraOrientationByYawPitchRoll, scene, math.pi, 0, 0)
        pcall(actor.SetUseCenterForOrigin, actor, true, true, true)
        pcall(actor.SetPosition, actor, 0, 0, 0)
        if crop then pcall(actor.SetParticleOverrideScale, actor, 0) end
        scene:Hide()
        p.scene, p.actor = scene, actor
    end

    -- The 2D portrait, else the caller's fallback.
    local function flatOrFail(display, onFail)
        if display and pcall(SetPortraitTextureFromCreatureDisplayID, flat, display) then
            flat:Show()
        else
            onFail()
        end
    end

    function p:Show(npcID, onFail)
        self.token = self.token + 1
        local mine = self.token
        if self.scene then self.scene:Hide() end
        flat:Hide()
        local display = Portrait.DisplayID(npcID)
        if not (display and self.scene) then return flatOrFail(display, onFail) end
        if self.display == display and self.height then
            self.scene:Show()
            return
        end
        pcall(actor.ClearModel, actor)
        local okSet, set = pcall(actor.SetModelByCreatureDisplayID, actor, display)
        if not okSet or set == false then return flatOrFail(display, onFail) end
        self.display, self.height = display, nil
        -- The first box can be the previous model's (TimeIsMoney measured):
        -- read it a poll step after loading, never at once.
        local function poll(left)
            if self.token ~= mine then return end
            local height = readHeight(actor)
            if height then
                local scale, z = Portrait.Framing(height, crop)
                pcall(actor.SetScale, actor, scale)
                pcall(actor.SetPosition, actor, 0, 0, z)
                self.height = height
                self.scene:Show()
            elseif left > 0 then
                C_Timer.After(POLL, function() poll(left - 1) end)
            else
                flatOrFail(display, onFail)
            end
        end
        C_Timer.After(POLL, function() poll(math.floor(WAIT / POLL + 0.5)) end)
    end

    function p:Hide()
        self.token = self.token + 1
        if self.scene then self.scene:Hide() end
        flat:Hide()
    end

    -- Not learned yet: greyed, like an icon.
    function p:SetDesaturated(on)
        if self.actor then pcall(self.actor.SetDesaturation, self.actor, on and 1 or 0) end
        flat:SetDesaturated(on)
        if self.scene then self.scene:SetAlpha(on and 0.55 or 1) end
        flat:SetAlpha(on and 0.55 or 1)
    end

    return p
end
