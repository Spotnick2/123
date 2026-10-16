-- ============================================================
-- Portrait: a demon's live, idling 3D model. Two kinds:
--   * Portrait.Create: the whole body in a ModelScene (the wheel's centre).
--   * Portrait.Head: a face portrait in a PlayerModel (the wheel's beads).
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
--   * Fallbacks: the client's round 2D portrait from the same display
--     (SetPortraitTextureFromCreatureDisplayID, TimeIsMoney's verified one),
--     then the caller's icon.
--   * Faces (GlassUnitFrames' measured unit-frame portraits): a PlayerModel
--     with SetPortraitZoom(1), the creature's own portrait camera, the one
--     target frames use. In game a crop of the model's top 0.40 (TimeIsMoney's
--     goblin crop) framed horns and wing tips instead of faces.
--   * SetCreature on the drawing model itself: the display lookup answers
--     only once the creature has loaded, and in game Inferno and the
--     Doomguard got the Felhunter's display, read just before (TimeIsMoney
--     measured the same: "SetCreature streams"). A PlayerModel streams its
--     own creature in.
-- ============================================================

local _, ns = ...
if ns.skip then return end

local Portrait = {}
ns.Portrait = Portrait

local FOV, CAMERA = 0.15, 40
local WAIT, POLL = 1.5, 0.1
-- Whole body: the model is drawn this share of the frame tall. In game at
-- 0.8 the Imp overflowed the disc and its flames were cut at the scene's
-- edge (a creature's effects reach past its box; Gnomesweeper measured it).
local FILL = 0.6

-- The display ID of a creature NPC, handed to `callback` (nil if none).
-- SetCreature streams: GetDisplayInfo answers only once the creature has
-- loaded, and a shared lookup model answered the PREVIOUS creature's
-- display meanwhile (in game: Inferno got the Felhunter). So each NPC gets
-- its own hidden PlayerModel, polled until it answers, and the answer is
-- kept for the session.
local displays, lookups = {}, {}
function Portrait.ResolveDisplay(npcID, callback)
    if not npcID then return callback(nil) end
    if displays[npcID] then return callback(displays[npcID]) end
    local model = lookups[npcID]
    if not model then
        local ok, m = pcall(CreateFrame, "PlayerModel", nil, UIParent)
        if not ok or not m then return callback(nil) end
        m:SetSize(1, 1)
        m:Hide()
        if not pcall(m.SetCreature, m, npcID) then return callback(nil) end
        lookups[npcID], model = m, m
    end
    local function poll(left)
        local ok, id = pcall(model.GetDisplayInfo, model)
        id = ok and ns.API.Number(id)
        if id and id > 0 then
            displays[npcID] = id
            return callback(id)
        end
        if left > 0 then
            C_Timer.After(POLL, function() poll(left - 1) end)
        else
            callback(nil)
        end
    end
    poll(math.floor(WAIT / POLL + 0.5))
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

-- The actor's scale for `height` in a square frame: the whole body at FILL.
function Portrait.Framing(height)
    local span = 2 * CAMERA * math.tan(FOV / 2)
    return span * FILL / height
end

-- A whole-body portrait `size` px square on `parent`, centred on it. The
-- fallbacks: p.flat (the 2D portrait), then onFail (the caller's icon).
--   p:Show(npcID, onFail), p:Hide(), p:SetDesaturated(bool)
function Portrait.Create(parent, size)
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
        Portrait.ResolveDisplay(npcID, function(display)
            if self.token == mine then self:Load(display, onFail) end
        end)
    end

    function p:Load(display, onFail)
        local mine = self.token
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
                pcall(actor.SetScale, actor, Portrait.Framing(height))
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

-- A face portrait `size` px square on `parent`: the creature `npcID` in a
-- PlayerModel through its own portrait camera, idling. Gives up for the
-- caller's icon when no model file has arrived after a while.
--   p:Show(npcID, onFail), p:Hide(), p:SetDesaturated(bool)
function Portrait.Head(parent, size)
    local p = { token = 0 }
    local ok, model = pcall(CreateFrame, "PlayerModel", nil, parent)
    if not ok or not model then
        function p:Show(_, onFail) onFail() end
        function p:Hide() end
        function p:SetDesaturated() end
        return p
    end
    model:SetSize(size, size)
    model:SetPoint("CENTER")
    model:EnableMouse(false)
    pcall(model.SetKeepModelOnHide, model, true)
    model:Hide()
    p.model = model

    function p:Show(npcID, onFail)
        self.token = self.token + 1
        local mine = self.token
        if not npcID then model:Hide() return onFail() end
        model:Show()
        if self.npc ~= npcID then
            self.npc = npcID
            pcall(model.ClearModel, model)
            pcall(model.SetCreature, model, npcID)
        end
        -- GlassUnitFrames' sequence after the model: zoom, then reset position.
        pcall(model.SetPortraitZoom, model, 1)
        pcall(model.SetPosition, model, 0, 0, 0)
        local function poll(left)
            if self.token ~= mine then return end
            local okF, file = pcall(model.GetModelFileID, model)
            if okF and ns.API.Number(file) and file > 0 then
                pcall(model.SetPortraitZoom, model, 1) -- again, once it is in
                return
            end
            if left > 0 then
                C_Timer.After(POLL, function() poll(left - 1) end)
            else
                self.npc = nil
                model:Hide()
                onFail()
            end
        end
        C_Timer.After(POLL, function() poll(math.floor(WAIT / POLL + 0.5)) end)
    end

    function p:Hide()
        self.token = self.token + 1
        model:Hide()
    end

    -- Not learned yet: greyed, like an icon.
    function p:SetDesaturated(on)
        pcall(model.SetDesaturation, model, on and 1 or 0)
        model:SetAlpha(on and 0.55 or 1)
    end

    return p
end
