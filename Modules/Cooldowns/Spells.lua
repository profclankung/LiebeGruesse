-- Tracked cooldowns (World of Warcraft: Forever spell ids and base cooldowns).
-- group: default bar group ("raid", "kick" or "off"); the player can change it.
local _, ns = ...
local Spells = {}
ns.CooldownSpells = Spells

Spells.CATEGORIES = { "util", "immune", "external", "tank", "raid", "defensive", "offensive", "cc", "interrupt" }

-- { id, class, cooldown (s), category, default group, English fallback name }
local LIST = {
    -- Utility
    { 20707, "WARLOCK", 1800, "util", "raid", "Soulstone Resurrection" },
    { 6346, "PRIEST", 180, "util", "raid", "Fear Ward" },
    { 633, "PALADIN", 1200, "util", "raid", "Lay on Hands" },
    { 19752, "PALADIN", 3600, "util", "raid", "Divine Intervention" },
    -- Immunities
    { 11958, "MAGE", 300, "immune", "raid", "Ice Block" },
    { 642, "PALADIN", 300, "immune", "raid", "Divine Shield" },
    { 1044, "PALADIN", 20, "immune", "raid", "Blessing of Freedom" },
    { 1022, "PALADIN", 300, "immune", "raid", "Blessing of Protection" },
    -- Externals
    { 29166, "DRUID", 360, "external", "raid", "Innervate" },
    { 16190, "SHAMAN", 300, "external", "raid", "Mana Tide Totem" },
    { 10060, "PRIEST", 180, "external", "raid", "Power Infusion" },
    -- Tank cooldowns
    { 871, "WARRIOR", 900, "tank", "raid", "Shield Wall" },
    { 12975, "WARRIOR", 180, "tank", "raid", "Last Stand" },
    { 22812, "DRUID", 60, "tank", "raid", "Barkskin" },
    { 22842, "DRUID", 180, "tank", "raid", "Frenzied Regeneration" },
    { 6940, "PALADIN", 30, "tank", "raid", "Blessing of Sacrifice" },
    { 1311015, "PALADIN", 300, "tank", "raid", "Templar's Bulwark" },
    { 5209, "DRUID", 600, "tank", "off", "Challenging Roar" },
    { 1161, "WARRIOR", 600, "tank", "off", "Challenging Shout" },
    -- Raid cooldowns
    { 20484, "DRUID", 1800, "raid", "raid", "Rebirth" },
    { 740, "DRUID", 300, "raid", "raid", "Tranquility" },
    -- Interrupts
    { 1766, "ROGUE", 10, "interrupt", "kick", "Kick" },
    { 6552, "WARRIOR", 10, "interrupt", "kick", "Pummel" },
    { 72, "WARRIOR", 12, "interrupt", "kick", "Shield Bash" },
    { 2139, "MAGE", 30, "interrupt", "kick", "Counterspell" },
    { 15487, "PRIEST", 45, "interrupt", "kick", "Silence" },
    { 8042, "SHAMAN", 6, "interrupt", "kick", "Earth Shock" },
    -- Personal defensives
    { 19263, "HUNTER", 300, "defensive", "off", "Deterrence" },
    { 5384, "HUNTER", 30, "defensive", "off", "Feign Death" },
    { 11426, "MAGE", 30, "defensive", "off", "Ice Barrier" },
    { 13908, "PRIEST", 600, "defensive", "off", "Desperate Prayer" },
    { 5277, "ROGUE", 300, "defensive", "off", "Evasion" },
    { 1856, "ROGUE", 300, "defensive", "off", "Vanish" },
    { 20230, "WARRIOR", 900, "defensive", "off", "Retaliation" },
    -- Offensive
    { 17116, "DRUID", 180, "offensive", "off", "Nature's Swiftness" },
    { 3045, "HUNTER", 300, "offensive", "off", "Rapid Fire" },
    { 19574, "HUNTER", 120, "offensive", "off", "Bestial Wrath" },
    { 12042, "MAGE", 180, "offensive", "off", "Arcane Power" },
    { 11129, "MAGE", 180, "offensive", "off", "Combustion" },
    { 12043, "MAGE", 180, "offensive", "off", "Presence of Mind" },
    { 1310994, "PALADIN", 60, "offensive", "off", "Swift Judgement" },
    { 14751, "PRIEST", 180, "offensive", "off", "Inner Focus" },
    { 13750, "ROGUE", 300, "offensive", "off", "Adrenaline Rush" },
    { 13877, "ROGUE", 120, "offensive", "off", "Blade Flurry" },
    { 16188, "SHAMAN", 180, "offensive", "off", "Nature's Swiftness" },
    { 16166, "SHAMAN", 180, "offensive", "off", "Elemental Mastery" },
    { 425336, "SHAMAN", 180, "offensive", "off", "Rage of the Farseer" },
    { 18288, "WARLOCK", 180, "offensive", "off", "Amplify Curse" },
    { 17877, "WARLOCK", 15, "offensive", "off", "Shadowburn" },
    { 17962, "WARLOCK", 10, "offensive", "off", "Conflagrate" },
    { 1719, "WARRIOR", 1800, "offensive", "off", "Recklessness" },
    { 12328, "WARRIOR", 180, "offensive", "off", "Death Wish" },
    -- Utility (more)
    { 12472, "MAGE", 600, "util", "off", "Cold Snap" },
    { 12051, "MAGE", 480, "util", "off", "Evocation" },
    { 1277370, "PRIEST", 600, "util", "off", "Divine Grace" },
    { 1277462, "PRIEST", 600, "util", "off", "Contingency Plan" },
    { 1277326, "PRIEST", 600, "util", "off", "Dark Sacrifice" },
    { 2983, "ROGUE", 300, "util", "off", "Sprint" },
    { 14185, "ROGUE", 600, "util", "off", "Preparation" },
    { 8177, "SHAMAN", 15, "util", "off", "Grounding Totem" },
    { 437009, "SHAMAN", 30, "util", "off", "Totemic Call" },
    { 18708, "WARLOCK", 300, "util", "off", "Fel Domination" },
    -- Crowd control
    { 5211, "DRUID", 60, "cc", "off", "Bash" },
    { 19577, "HUNTER", 60, "cc", "off", "Intimidation" },
    { 1499, "HUNTER", 30, "cc", "off", "Freezing Trap" },
    { 13809, "HUNTER", 30, "cc", "off", "Frost Trap" },
    { 122, "MAGE", 25, "cc", "off", "Frost Nova" },
    { 853, "PALADIN", 60, "cc", "off", "Hammer of Justice" },
    { 8122, "PRIEST", 30, "cc", "off", "Psychic Scream" },
    { 1277455, "PRIEST", 120, "cc", "off", "Confounding Flash" },
    { 2094, "ROGUE", 300, "cc", "off", "Blind" },
    { 408, "ROGUE", 20, "cc", "off", "Kidney Shot" },
    { 6789, "WARLOCK", 120, "cc", "off", "Death Coil" },
    { 5484, "WARLOCK", 40, "cc", "off", "Howl of Terror" },
    { 5246, "WARRIOR", 180, "cc", "off", "Intimidating Shout" },
}

Spells.list = {}
Spells.byId = {}
Spells.byName = {}
Spells.builtin = {}

local DEFAULT_COLUMN = { util = 1, immune = 2, external = 3, tank = 4, raid = 5 }
local CLASS_COLUMN = { WARRIOR = 1, PALADIN = 2, DRUID = 3, PRIEST = 4, SHAMAN = 5, MAGE = 6, WARLOCK = 7, ROGUE = 8, HUNTER = 9 }

do
    local rowsByKey = {}
    for order, e in ipairs(LIST) do
        local spell = { id = e[1], class = e[2], cd = e[3], cat = e[4], group = e[5], fallback = e[6], order = order, builtin = true }
        -- default placement: raid cooldowns in one column per category,
        -- interrupts in one column, everything else per class in the party icons
        local display = (spell.group == "raid" and "raid") or (spell.group == "kick" and "kick") or "party"
        local col = display == "raid" and (DEFAULT_COLUMN[spell.cat] or 1) or (display == "party" and CLASS_COLUMN[spell.class] or 1)
        local rowKey = display .. col
        rowsByKey[rowKey] = (rowsByKey[rowKey] or 0) + 1
        spell.defaults = { enabled = true, display = display, col = col, row = rowsByKey[rowKey] }
        Spells.builtin[#Spells.builtin + 1] = spell
    end
end

local function settings() return ns.Database.Settings().cd end

-- Rebuilds the list from built-in spells plus the player's own spells
function Spells.Rebuild()
    wipe(Spells.list)
    wipe(Spells.byId)
    for _, spell in ipairs(Spells.builtin) do
        Spells.list[#Spells.list + 1] = spell
        Spells.byId[spell.id] = spell
    end
    local custom = ns.db and settings().custom or {}
    local order = #Spells.builtin
    for id, c in pairs(custom) do
        if not Spells.byId[id] then
            order = order + 1
            local spell = { id = id, class = c.class or "ALL", cd = c.cd or 60, cat = "custom", fallback = c.name or ("Spell " .. id),
                order = order, custom = true, defaults = { enabled = true, display = "raid", col = 1, row = 99 } }
            Spells.list[#Spells.list + 1] = spell
            Spells.byId[id] = spell
        end
    end
    Spells.Index()
end

function Spells.Name(spell)
    if not spell.name then
        local name
        if C_Spell and C_Spell.GetSpellName then name = ns.Call(C_Spell.GetSpellName, spell.id) end
        if not name and GetSpellInfo then name = ns.Call(GetSpellInfo, spell.id) end
        if name then spell.name = name end
    end
    return spell.name or spell.fallback
end

function Spells.Icon(spell)
    if not spell.icon then
        local icon
        if C_Spell and C_Spell.GetSpellTexture then icon = ns.Call(C_Spell.GetSpellTexture, spell.id) end
        if not icon and GetSpellTexture then icon = ns.Call(GetSpellTexture, spell.id) end
        spell.icon = icon
    end
    return spell.icon or 134400
end

-- Builds the localized name index (other ranks share the name)
local resolved = {}   -- [any spell id] = tracked id or false (every cast in a raid asks: one lookup per id)
function Spells.Index()
    wipe(Spells.byName)
    wipe(resolved)
    for _, spell in ipairs(Spells.list) do
        local name = Spells.Name(spell)
        if name and not Spells.byName[name] then Spells.byName[name] = spell.id end
        if spell.fallback and not Spells.byName[spell.fallback] then Spells.byName[spell.fallback] = spell.id end
    end
end

-- Maps any rank's spell id to the tracked id
function Spells.Resolve(id)
    if type(id) ~= "number" or ns.IsSecret(id) then return nil end
    if Spells.byId[id] then return id end
    local r = resolved[id]
    if r ~= nil then return r or nil end
    local name
    if C_Spell and C_Spell.GetSpellName then name = ns.Call(C_Spell.GetSpellName, id) end
    if not name and GetSpellInfo then name = ns.Call(GetSpellInfo, id) end
    -- no name yet (spell data not loaded): ask again next time
    if name then resolved[id] = Spells.byName[name] or false end
    return name and Spells.byName[name]
end

-- Effective configuration of a spell: defaults plus the player's overrides
function Spells.Config(spell)
    local o = settings().spells[spell.id] or {}
    local d = spell.defaults
    local c = {
        enabled = o.enabled, display = o.display, col = o.col, row = o.row, cd = o.cd, filter = o.filter,
        tank = o.tank, healer = o.healer, damage = o.damage, color = o.color, label = o.label,
    }
    if c.enabled == nil then c.enabled = d.enabled end
    c.display = c.display or d.display
    c.col = c.col or d.col
    c.row = c.row or d.row
    c.cd = c.cd or spell.cd
    if c.tank == nil then c.tank = true end
    if c.healer == nil then c.healer = true end
    if c.damage == nil then c.damage = true end
    return c
end

-- Stores one override field (nil restores the default)
function Spells.Set(spell, field, value)
    local all = settings().spells
    all[spell.id] = all[spell.id] or {}
    all[spell.id][field] = value
    if not next(all[spell.id]) then all[spell.id] = nil end
    if spell.custom and field == "cd" then settings().custom[spell.id].cd = value end
    ns.Fire("LG_COOLDOWNS")
end

function Spells.Reset(spell)
    settings().spells[spell.id] = nil
    ns.Fire("LG_COOLDOWNS")
end

function Spells.Cooldown(spell)
    return Spells.Config(spell).cd or spell.cd
end

function Spells.AddCustom(id, class)
    id = tonumber(id)
    if not id then return false end
    if Spells.byId[id] then return false, "exists" end
    local name
    if C_Spell and C_Spell.GetSpellName then name = ns.Call(C_Spell.GetSpellName, id) end
    if not name and GetSpellInfo then name = ns.Call(GetSpellInfo, id) end
    if not name then return false, "unknown" end
    local _, myClass = ns.Call(UnitClass, "player")
    settings().custom[id] = { name = name, class = class or myClass or "ALL", cd = 60 }
    Spells.Rebuild()
    ns.Fire("LG_COOLDOWNS")
    return true
end

function Spells.RemoveCustom(id)
    settings().custom[id] = nil
    settings().spells[id] = nil
    Spells.Rebuild()
    ns.Fire("LG_COOLDOWNS")
end
