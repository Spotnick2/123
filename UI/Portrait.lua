-- ============================================================
-- Portrait: the active demon's 3D model in the wheel's centre.
--
-- The recipe measured by AltStable (Scanner.lua, #75 there) and Gnomesweeper
-- (Models.lua, docs/MODELS.md):
--   * A demon's GUID carries its real NPC id, and a PlayerModel resolves that
--     to its single display ID on the spot (Voidwalker 1860 -> 1132).
--     SetCreature alone is not used to draw: for other creatures it picks a
--     random skin.
--   * A plain ModelScene with one actor, SetModelByCreatureDisplayID, a far
--     camera with a narrow lens, the actor scaled from its bounding box once
--     the model has streamed in (polled, then given up on).
-- Anything missing (no ModelScene, a refused display, no box in time): the
-- portrait reports failure and the wheel shows the summon icon instead.
-- ============================================================

local _, ns = ...

local Portrait = {}
ns.Portrait = Portrait

local FOV, CAMERA = 0.15, 40
local WAIT, POLL = 0.6, 0.1
-- How tall the model is drawn, as a share of the portrait. In game at 0.8
-- the Imp overflowed the disc and its flames were sliced at the scene's
-- edge: a creature's effects reach past its box (Gnomesweeper measured the
-- same), and the disc is round where the scene is square.
local FILL = 0.6

local resolver
-- The display ID of a creature NPC (single-skinned, as demons are), or nil.
function Portrait.DisplayID(npcID)
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

-- A portrait `size` px square on `parent`. p:Show(npcID, onFail), p:Hide().
function Portrait.Create(parent, size)
    local p = { size = size, token = 0 }
    local ok, scene = pcall(CreateFrame, "ModelScene", nil, parent)
    local okA, actor
    if ok and scene then okA, actor = pcall(scene.CreateActor, scene) end
    if not (okA and actor) then
        function p:Show(_, onFail) onFail() end
        function p:Hide() end
        return p
    end
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

    function p:Show(npcID, onFail)
        self.token = self.token + 1
        local mine = self.token
        scene:Hide()
        local display = npcID and Portrait.DisplayID(npcID)
        if not display then return onFail() end
        if self.display == display and self.height then
            scene:Show()
            return
        end
        pcall(actor.ClearModel, actor)
        local okSet, set = pcall(actor.SetModelByCreatureDisplayID, actor, display)
        if not okSet or set == false then return onFail() end
        self.display, self.height = display, nil
        local function poll(left)
            if self.token ~= mine then return end
            local height = readHeight(actor)
            if height then
                -- The view spans `span` scene units over `size` px: the model
                -- comes out FILL of the portrait tall.
                local span = 2 * CAMERA * math.tan(FOV / 2)
                pcall(actor.SetScale, actor, span * FILL / height)
                self.height = height
                scene:Show()
            elseif left > 0 then
                C_Timer.After(POLL, function() poll(left - 1) end)
            else
                onFail()
            end
        end
        poll(math.floor(WAIT / POLL + 0.5))
    end

    function p:Hide()
        self.token = self.token + 1
        scene:Hide()
    end

    return p
end
