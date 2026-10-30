-- ============================================================
-- Localization (#22). ns.L["English text"] is that text in the client's
-- language. The English is the key, so a string a locale lacks shows in
-- English, never nil. Locales/<locale>.lua fill the table for their client
-- only, and load before every file that reads it.
--
-- Names the client already localizes are read from it, never translated
-- here: spell and item names (C_Spell, C_Item) and demon names (creature
-- families, C_CreatureInfo). Format strings keep their %s and %d in order:
-- the tests run plain Lua 5.1, which has no positional arguments.
-- ============================================================

local _, ns = ...
if ns.skip then return end

ns.L = setmetatable({}, { __index = function(_, key) return key end })

-- The client's language ("frFR"), read once.
local ok, locale = pcall(GetLocale)
ns.locale = ok and type(locale) == "string" and locale or "enUS"
