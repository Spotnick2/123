-- Alert sounds (#14): the client's own sound kits, played by ID.
--
-- Vanilla-era kits play on Forever; PlaySoundFile refuses built-in paths
-- (PORTING-TBC-TO-FOREVER.md, Gnomesweeper/docs/SOUNDS.md). Spells (a demon
-- summoned, the Ritual, a stone created) already sound in game, so only
-- what the game doesn't announce gets one: a summon request ("123", #9) and
-- a healthstone request (#8). The demons' voices stay in UI/Wheel.lua.

local _, ns = ...
if ns.skip then return end

local Sound = {
    lastPlayedAt = {},
}
ns.Sound = Sound

-- Kit choices for every alert, picked by ear on the options page (each
-- choice plays when picked). IDs from SOUNDKIT (wow-ui-source 70338).
Sound.CHOICES = {
    { 3081, "Whisper" },        -- TELL_MESSAGE
    { 880, "Group invite" },    -- IG_PLAYER_INVITE
    { 8960, "Ready check" },    -- READY_CHECK
    { 8959, "Raid warning" },   -- RAID_WARNING
    { 0, "None" },
}

-- db.alerts key per alert, and the label the options page shows.
Sound.ALERTS = {
    { key = "summonRequest", label = "Summon request" },
    { key = "stoneRequest", label = "Healthstone request" },
}

-- A burst (several people typing "123" at once) plays one sound.
local THROTTLE = 1.5

-- Plays a kit now. Returns whether the client will play it (false when it
-- refuses the kit, so the options page can say so).
function Sound:PlayKit(kit)
    if type(kit) ~= "number" or kit <= 0 then return false end
    local ok, willPlay = pcall(PlaySound, kit, "SFX")
    return ok and willPlay == true
end

-- Plays an alert's chosen kit, unless alerts are off or it just played.
function Sound:Play(alert)
    local db = ns.db
    if not db or not db.alertSounds then return false end
    local now = GetTime()
    if now - (self.lastPlayedAt[alert] or -math.huge) < THROTTLE then return false end
    self.lastPlayedAt[alert] = now
    return self:PlayKit(db.alerts[alert])
end
