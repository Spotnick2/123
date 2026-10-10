local _, ns = ...

local DB = {}
ns.DB = DB

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nestedValue in pairs(value) do
        copy[key] = deepCopy(nestedValue)
    end
    return copy
end
DB.DeepCopy = deepCopy

local function mergeDefaults(defaults, current)
    local result = deepCopy(defaults)
    if type(current) ~= "table" then
        return result
    end

    for key, value in pairs(current) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = mergeDefaults(result[key], value)
        else
            result[key] = value
        end
    end
    return result
end

-- This character's own table (the demon last out differs per Warlock),
-- keyed on the player's GUID inside the account-wide saved table.
function DB:Character(saved)
    local key = ns.API.UnitGUID("player") or "unknown"
    saved.characters = type(saved.characters) == "table" and saved.characters or {}
    local char = saved.characters[key]
    if type(char) ~= "table" then
        char = {}
        saved.characters[key] = char
    end
    return char
end

-- Called at PLAYER_LOGIN: SavedVariables load after the addon's files, so
-- OneTwoThreeDB is not readable at file scope.
function DB:Initialize()
    local saved = OneTwoThreeDB
    if type(saved) ~= "table" then
        saved = {}
    end

    saved = mergeDefaults(ns.Constants.DEFAULTS, saved)
    saved.version = ns.Constants.VERSION
    -- A sentinel that proves saved data survives a full client restart.
    saved.loadCount = (tonumber(saved.loadCount) or 0) + 1

    OneTwoThreeDB = saved
    self.data = saved
    ns.db = saved
    ns.char = self:Character(saved)
    return saved
end
