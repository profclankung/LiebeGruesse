-- Paladin blessings: who blesses which class, who is missing what, and a
-- small bar for paladins with one-click (greater) blessings.
-- Assignments sync between paladins with this addon and with PallyPower users.
-- Cost: nothing outside a group; in a group only UNIT_AURA of group members,
-- throttled, and only while you are a paladin or the page is open.
local _, ns = ...
local L, Names, Comm = ns.L, ns.Names, ns.Comm
local B = ns.NewModule("blessings")
ns.Blessings = B

---------------------------------------------------------------------------
-- Spells (greater = whole class, WoW: Forever has them too). Forever has only
-- Kings, Might and Wisdom as blessings: no Salvation (it stacks there), no
-- Sanctuary, and Light became Oath of Light (one target, on top of a blessing –
-- a button on the bar, not an assignment). Blessings a paladin does not know are
-- never offered (Kings needs a talent); without the greater one the
-- bar casts the normal one. Ranks are also found by name in the spell book, and
-- blessing ids seen on players are learned (Forever can use other ids).
---------------------------------------------------------------------------
B.LIST = {
    { key = "kings", single = { 20217 }, greater = { 25898 }, short = "K" },
    { key = "might", single = { 19740, 19834, 19835, 19836, 19837, 19838, 25291 }, greater = { 25782, 25916 }, short = "M" },
    { key = "wisdom", single = { 19742, 19850, 19852, 19853, 19854, 25290 }, greater = { 25894, 25918 }, short = "W" },
}
B.BY_KEY = {}
for i, b in ipairs(B.LIST) do b.order = i; B.BY_KEY[b.key] = b end

B.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

---------------------------------------------------------------------------
-- Specs: what a player wants depends on what he plays (feral druid: Might,
-- restoration druid: Wisdom)
---------------------------------------------------------------------------
-- kind of player per class and talent tree (feral = cat or bear, decided by the group role)
local TREE_TYPES = {
    WARRIOR = { "melee", "melee", "tank" }, PALADIN = { "healer", "tank", "melee" },
    HUNTER = { "ranged", "ranged", "ranged" }, ROGUE = { "melee", "melee", "melee" },
    PRIEST = { "healer", "healer", "caster" }, SHAMAN = { "caster", "melee", "healer" },
    MAGE = { "caster", "caster", "caster" }, WARLOCK = { "caster", "caster", "caster" },
    DRUID = { "caster", "feral", "healer" },
}
-- without talents or role: what most of the class plays in a raid
local CLASS_TYPE = { WARRIOR = "melee", PALADIN = "healer", HUNTER = "ranged", ROGUE = "melee", PRIEST = "healer",
    SHAMAN = "healer", MAGE = "caster", WARLOCK = "caster", DRUID = "healer" }
local TANKS = { WARRIOR = true, PALADIN = true, DRUID = true }
local HEALERS = { PRIEST = true, PALADIN = true, SHAMAN = true, DRUID = true }
local DAMAGE = { WARRIOR = "melee", PALADIN = "melee", HUNTER = "ranged", ROGUE = "melee", PRIEST = "caster", MAGE = "caster", WARLOCK = "caster" }
-- best first
local TYPE_WISHES = {
    tank = { "kings", "might" },
    melee = { "kings", "might" },
    ranged = { "kings", "might", "wisdom" },
    caster = { "kings", "wisdom" },
    healer = { "kings", "wisdom" },
}
B.TYPES = { "tank", "melee", "ranged", "caster", "healer" }
B.CLASS_TYPE = CLASS_TYPE

-- wish list of a kind of player
function B.Wishes(kind, class)
    local out = {}
    for _, b in ipairs(TYPE_WISHES[kind] or TYPE_WISHES.melee) do out[#out + 1] = b end
    -- paladins and shamans fight in melee but need mana
    if (kind == "melee" or kind == "tank") and (class == "PALADIN" or class == "SHAMAN") then
        table.insert(out, kind == "tank" and 2 or 3, "wisdom")
    end
    return out
end

B.testTypes = {}
-- what a group member plays: tank role, talents (own profile or inspect), group role, class
function B.UnitType(unit, key, class)
    if B.test then return B.testTypes[unit] or CLASS_TYPE[class] or "melee", "test" end
    local role = UnitGroupRolesAssigned and ns.Call(UnitGroupRolesAssigned, unit)
    if role == "TANK" and TANKS[class] then return "tank", "role" end
    local m = key and ns.Database.Member(key)
    local tree = m and ns.SpecTree(ns.SpecPoints(m))
    if not tree and m then
        -- only a spec name (data without points): find its tree
        local name = ns.SpecName(m.sp or (m.insp and m.insp.sp), class)
        for i, t in ipairs(ns.TreeNames(class)) do if name and t == name then tree = i end end
    end
    local kind = tree and TREE_TYPES[class] and TREE_TYPES[class][tree]
    if kind == "feral" then kind = "melee" end
    if kind then return kind, "talents" end
    if role == "HEALER" and HEALERS[class] then return "healer", "role" end
    if role == "DAMAGER" and DAMAGE[class] then return DAMAGE[class], "role" end
    return CLASS_TYPE[class] or "melee", "class"
end

local spellOf = {}    -- [spellId] = blessing key
local nameOf = {}     -- [localized aura name] = blessing key
for _, b in ipairs(B.LIST) do
    for _, kind in ipairs({ "single", "greater" }) do
        for _, id in ipairs(b[kind]) do spellOf[id] = b.key end
    end
end
local function learnNames()
    if next(nameOf) then return end
    local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    for id, key in pairs(spellOf) do
        local name = get and ns.Call(get, id)
        if type(name) == "string" and name ~= "" then nameOf[name] = key end
    end
end

local function known(id)
    if IsPlayerSpell then return ns.Call(IsPlayerSpell, id) == true end
    if IsSpellKnown then return ns.Call(IsSpellKnown, id) == true end
    return false
end
B.Known = known
-- any rank of this spell in the spell book, found by its name (ids may differ on Forever)
local function knownByName(id)
    local name = B.SpellName and B.SpellName(id)
    if type(name) ~= "string" or name == "" then return false end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = ns.Call(C_Spell.GetSpellInfo, name)
        if type(info) == "table" and info.spellID then return true end
    end
    if C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell then
        if ns.Call(C_SpellBook.FindSpellBookSlotForSpell, name) then return true end
    end
    return false
end
B.KnownByName = knownByName
-- highest known rank of a blessing ("single"/"greater"), as a spell id; casting
-- goes by name, so the game takes the highest rank you really have
function B.SpellFor(key, kind)
    local b = B.BY_KEY[key]
    local ids = b and b[kind] or {}
    for i = #ids, 1, -1 do if known(ids[i]) then return ids[i] end end
    if ids[1] and knownByName(ids[1]) then return ids[1] end
end

-- a blessing aura with an id this addon did not know (WoW: Forever): learn it,
-- so counting, own casts and the live strip know it too (saved per account)
function B.Learn(id, key, name, quiet)
    local b = B.BY_KEY[key]
    if type(id) ~= "number" or not b or spellOf[id] then return false end
    local gname = B.SpellName(b.greater[1])
    local kind = (name and gname and name == gname) and "greater" or "single"
    table.insert(b[kind], id)
    spellOf[id] = key
    if not quiet then
        local o = B.Settings()
        o.learned = o.learned or {}
        o.learned[id] = key .. ":" .. kind
        if ns.BlessNative and ns.BlessNative.ResetFilters then ns.BlessNative.ResetFilters() end
    end
    return true
end
ns.On("LG_READY", function()
    for id, v in pairs(B.Settings().learned or {}) do
        local key = type(v) == "string" and v:match("^(%a+)")
        local b = key and B.BY_KEY[key]
        local kind = v:match(":(%a+)$")
        if b and not spellOf[tonumber(id)] and (kind == "single" or kind == "greater") then
            table.insert(b[kind], tonumber(id)); spellOf[tonumber(id)] = key
        end
    end
end)
function B.SpellName(id)
    local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    return id and get and ns.Call(get, id) or nil
end
function B.Icon(key)
    local b = B.BY_KEY[key]
    if not b then return nil end
    local get = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
    return (get and ns.Call(get, b.greater[1])) or (get and ns.Call(get, b.single[1])) or 135995
end
function B.Name(key) return L["BLESS_" .. tostring(key):upper()] end

-- own abilities: { kings = 0/1/2, ... } (1 = single only, 2 = greater)
function B.OwnSkills()
    local out = {}
    for _, b in ipairs(B.LIST) do
        out[b.key] = (B.SpellFor(b.key, "greater") and 2) or (B.SpellFor(b.key, "single") and 1) or 0
    end
    return out
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
-- paladins[key] = { key, name, unit, addon = "lg"/"pp"/nil, can = {...}, set = { [class] = blessing } }
B.paladins = {}
B.status = {}     -- [class] = { total, have = { [b] = n }, left = { [b] = seconds }, units = { ... } }
B.missing = {}    -- { { key, name, class, list = { blessing, ... } } }

function B.Settings()
    local s = ns.Database.Settings()
    s.blessings = s.blessings or {}
    local o = s.blessings
    local d = { bar = true, raidOnly = false, solo = true, scale = 1, freeAssign = false, ppRead = true, ppSync = true, live = true,
        players = true, times = true, counts = true, side = "auto", aura = true, seal = false, fury = false, autoNew = true }
    -- 1.0.87: "left" was the stored default; the new default opens toward the screen centre
    if o.sideAuto == nil then
        if o.side == "left" or o.side == nil then o.side = "auto" end
        o.sideAuto = true
    end
    for k, v in pairs(d) do if o[k] == nil then o[k] = v end end
    return o
end
local function enabled() return ns.Database.Settings().modules.blessings ~= false end
B.Enabled = enabled

local function isPaladin() local _, c = ns.Call(UnitClass, "player"); return c == "PALADIN" end
B.IsPaladin = isPaladin

-- saved own choices survive /reload; assignments for others only live per group
-- drops blessings this addon does not know (any more): Salvation from 1.0.84 test builds
local function clean(t)
    for k, b in pairs(t) do if not B.BY_KEY[b] then t[k] = nil end end
    return t
end
local function ownSet()
    local char = ns.Database.Char()
    char.blessings = clean(char.blessings or {})
    return char.blessings
end
-- own single blessings: [player key] = blessing; pinned = set by hand (smart assign keeps them)
local function ownSingles()
    local char = ns.Database.Char()
    char.blessSingle = clean(char.blessSingle or {})
    char.blessPinned = char.blessPinned or {}
    return char.blessSingle, char.blessPinned
end

-- the blessing a paladin gives this player: his single one, else the class blessing
local function gives(p, key, class)
    return (key and p.single and p.single[key]) or (p.set and p.set[class]) or nil
end
B.Gives = gives

local function encode(set)
    local chars = {}
    for i, class in ipairs(B.CLASSES) do
        local b = set and set[class]
        chars[i] = b and B.BY_KEY[b] and B.BY_KEY[b].short or "."
    end
    return table.concat(chars)
end
local BY_SHORT = {}
for _, b in ipairs(B.LIST) do BY_SHORT[b.short] = b.key end
-- singles for the sync: { [player key] = "L" or "L!" (! = set by hand) }
local function encodeSingles(p)
    local out = {}
    for key, b in pairs(p.single or {}) do
        local s = B.BY_KEY[b] and B.BY_KEY[b].short
        if s then out[key] = s .. ((p.pinned and p.pinned[key]) and "!" or "") end
    end
    return out
end
local function decodeSingles(t)
    local single, pinned = {}, {}
    if type(t) ~= "table" then return nil end
    local n = 0
    for key, v in pairs(t) do
        if type(key) == "string" and type(v) == "string" and n < 60 then
            local b = BY_SHORT[v:sub(1, 1)]
            local k = Names.Key(key)
            if b and k then single[k] = b; pinned[k] = v:sub(2, 2) == "!" or nil; n = n + 1 end
        end
    end
    return single, pinned
end
B.EncodeSingles, B.DecodeSingles = encodeSingles, decodeSingles
local function decode(text)
    local set = {}
    if type(text) ~= "string" then return set end
    for i, class in ipairs(B.CLASSES) do set[class] = BY_SHORT[text:sub(i, i)] end
    return set
end
local function encodeSkills(can)
    local out = {}
    for i, b in ipairs(B.LIST) do out[i] = tostring(can and can[b.key] or 0) end
    return table.concat(out)
end
local function decodeSkills(text)
    local can = {}
    for i, b in ipairs(B.LIST) do can[b.key] = tonumber(tostring(text or ""):sub(i, i)) or 0 end
    return can
end

---------------------------------------------------------------------------
-- Group roster: paladins and class counts (rebuilt on roster changes)
---------------------------------------------------------------------------
local classUnits = {}   -- [class] = { unit, ... }
local lastGood = {}     -- last good aura reading per unit: [unit] = { guid, [blessing] = expires (GetTime) }
B.classUnits = classUnits
B.members = {}   -- [player key] = { key, name, unit, class }
B.unitKey = {}   -- [unit] = player key
B.unitHas = {}   -- [player key] = { has = { [blessing] = seconds left }, estimated }

local function addMember(unit, key, name, class)
    B.members[key] = { key = key, name = name, unit = unit, class = class }
    B.unitKey[unit] = key
end

local function mine(p)
    p.addon, p.me = "lg", true
    p.can = B.OwnSkills()
    p.set = ownSet()
    p.single, p.pinned = ownSingles()
end

-- B.incomplete: a group member the game does not know yet (just joined: no
-- class, name "Unknown") – the roster is read again a moment later
function B.Rebuild()
    if B.test then return end
    wipe(classUnits)   -- (lastGood stays: it checks the GUID behind each unit)
    wipe(B.members); wipe(B.unitKey)
    B.incomplete = false
    local seen = {}
    local me = Names.Me()
    local unknown = UNKNOWNOBJECT or "Unknown"
    local count = 0
    for unit, key, name in ns.GroupUnits() do
        local _, class = ns.Call(UnitClass, unit)
        count = count + 1
        if not class or name == unknown then B.incomplete = true end
        if class and name ~= unknown then
            classUnits[class] = classUnits[class] or {}
            table.insert(classUnits[class], unit)
            addMember(unit, key, name, class)
            if class == "PALADIN" then
                seen[key] = true
                local p = B.paladins[key] or { key = key, set = {}, can = {} }
                p.name, p.unit = name, unit
                if Names.Same(key, me) then mine(p) end
                B.paladins[key] = p
            end
        end
    end
    -- solo paladin: show yourself too
    if not IsInGroup() and isPaladin() then
        local p = B.paladins[me] or { key = me }
        mine(p)
        p.name, p.unit = Names.Unit("player"), "player"
        B.paladins[me] = p
        seen[me] = true
        local _, class = ns.Call(UnitClass, "player")
        if class then
            classUnits[class] = classUnits[class] or { "player" }
            addMember("player", me, p.name, class)
        end
    end
    for key in pairs(B.paladins) do if not seen[key] then B.paladins[key] = nil end end
    if IsInGroup() and GetNumGroupMembers and count < (ns.Call(GetNumGroupMembers) or 0) then B.incomplete = true end
end

function B.PaladinList()
    local list = {}
    for _, p in pairs(B.paladins) do list[#list + 1] = p end
    table.sort(list, function(a, b)
        if (a.me or false) ~= (b.me or false) then return a.me == true end
        if (a.addon ~= nil) ~= (b.addon ~= nil) then return a.addon ~= nil end
        return a.key < b.key
    end)
    return list
end

function B.Me() return B.paladins[Names.Me()] end

-- may I change this paladin's assignment?
function B.CanEdit(p)
    if not p then return false end
    if B.test then return true end
    if p.me then return true end
    if not IsInGroup() then return false end
    return ns.IsGroupLead("player") or p.free == true
end

---------------------------------------------------------------------------
-- Buff scan: who has which blessing (and how long it lasts)
---------------------------------------------------------------------------
local function auraBlessing(spellId, name)
    return (spellId and spellOf[spellId]) or (name and nameOf[name])
end

-- Reads the blessings on a unit. Returns out, reliable: in combat the game can
-- hide aura data (secret values); then the result is not trustworthy and the
-- caller keeps the last good reading instead of showing "nobody buffed".
local function unitBlessings(unit, out)
    wipe(out)
    local reliable = true
    for i = 1, 40 do
        local name, spellId, expires
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok or ns.IsSecret(a) then reliable = false; break end
            if type(a) ~= "table" then break end
            name, spellId, expires = a.name, a.spellId, a.expirationTime
        else
            local ok, n, _, _, _, _, exp, _, _, _, id = pcall(UnitBuff, unit, i)
            if not ok or ns.IsSecret(n) then reliable = false; break end
            if not n then break end
            name, spellId, expires = n, id, exp
        end
        if ns.IsSecret(name) then name = nil end
        if ns.IsSecret(spellId) then spellId = nil end
        if ns.IsSecret(expires) then expires = nil end
        if name == nil and spellId == nil then
            reliable = false
        else
            local key = auraBlessing(spellId, name)
            if key and type(spellId) == "number" and not spellOf[spellId] then B.Learn(spellId, key, name) end
            if key then out[key] = (type(expires) == "number" and expires > 0) and (expires - GetTime()) or 3600 end
        end
    end
    return out, reliable
end

local function rememberedBlessings(unit, out)
    wipe(out)
    local m = lastGood[unit]
    local guid = ns.Call(UnitGUID, unit)
    if not m or (guid and m.guid and m.guid ~= guid) then return out end
    local now = GetTime()
    for b, exp in pairs(m) do
        if b ~= "guid" and exp > now then out[b] = exp - now end
    end
    return out
end
local function remember(unit, has)
    local m = { guid = ns.Call(UnitGUID, unit) }
    local now = GetTime()
    for b, left in pairs(has) do m[b] = now + left end
    lastGood[unit] = m
end

---------------------------------------------------------------------------
-- Own casts: in combat the auras are hidden, so our own casts are the only
-- news. A player carries one blessing per paladin: whatever we cast on him
-- replaces the blessing we gave him before – also Protection, Freedom and
-- Sacrifice, which are not tracked themselves. Only the remembered state is
-- corrected; the next readable scan replaces it anyway.
---------------------------------------------------------------------------
local SHORT_IDS = { 1022, 5599, 10278, 1044, 6940, 20729 }   -- Protection, Freedom, Sacrifice
local shortNames
local function isShort(name)
    if type(name) ~= "string" then return false end
    if not shortNames then
        shortNames = {}
        for _, id in ipairs(SHORT_IDS) do
            local n = B.SpellName(id)
            if type(n) == "string" and n ~= "" then shortNames[n] = true end
        end
    end
    return shortNames[name] == true
end
local function isGreater(id)
    for _, b in ipairs(B.LIST) do
        for _, g in ipairs(b.greater) do if g == id then return true end end
    end
    return false
end
local function memo(unit)
    local guid = ns.Call(UnitGUID, unit)
    local m = lastGood[unit]
    if not m or (guid and m.guid and m.guid ~= guid) then
        m = { guid = guid }
        lastGood[unit] = m
    end
    return m
end
local function unitClass(unit)
    for class, units in pairs(classUnits) do
        for _, u in ipairs(units) do if u == unit then return class end end
    end
end
-- group unit (as used by the scan) for a name from the cast event
local function unitByName(name)
    if type(name) ~= "string" or name == "" or ns.IsSecret(name) then return nil end
    local key = Names.Key(Names.Strip and Names.Strip(name) or name)
    if not key then return nil end
    for _, units in pairs(classUnits) do
        for _, u in ipairs(units) do
            local n = Names.Unit(u)
            if n and (Names.Same(Names.Key(n), key) or Names.Same(Names.Key((n:match("^(%S+)"))), key)) then return u end
        end
    end
end

local pending   -- { unit, spell, at }: target of our next blessing cast
-- the bar knows its target when it is clicked (also in combat)
function B.NoteCastTarget(unit, spell)
    if B.test or type(unit) ~= "string" or type(spell) ~= "string" then return end
    pending = { unit = unit, spell = spell, at = GetTime() }
end

function B.OwnCast(unit, spellId)
    if B.test or not unit or not spellId then return false end
    local name = B.SpellName(spellId)
    local key = spellOf[spellId]
    if not key and not isShort(name) then return false end
    local class = unitClass(unit)
    if not class then return false end
    local me = B.Me()
    local mine = me and me.set and me.set[class]
    local targets = { unit }
    if key and isGreater(spellId) then targets = classUnits[class] or targets end
    local now = GetTime()
    for _, u in ipairs(targets) do
        local m = memo(u)
        if mine then m[mine] = nil end
        if key then m[key] = now + 3600 end
    end
    ns.Debounce("bless-scan", 0.3, B.Scan)
    return true
end

-- casts from macros or key binds: the target name of the cast event
ns.On("UNIT_SPELLCAST_SENT", function(_, unit, target, _, spellId)
    if unit ~= "player" or ns.IsSecret(spellId) or ns.IsSecret(target) or type(spellId) ~= "number" then return end
    if not isPaladin() then return end
    local name = B.SpellName(spellId)
    if not (spellOf[spellId] or isShort(name)) then return end
    if pending and GetTime() - pending.at < 1 and pending.spell == name then return end   -- the bar set it a moment ago
    local u = unitByName(target)
    if u then pending = { unit = u, spell = name, at = GetTime() } end
end)

ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellId)
    if unit ~= "player" or ns.IsSecret(spellId) or type(spellId) ~= "number" then return end
    if not pending or GetTime() - pending.at > 8 then return end
    local name = B.SpellName(spellId)
    if not name or name ~= pending.spell then return end
    local u = pending.unit
    pending = nil
    ns.Safe(B.OwnCast, u, spellId)
end)
B.IsShortBlessing, B.UnitByName = isShort, unitByName
B.Memory = function(unit) return lastGood[unit] end

local scratch = {}
function B.Scan()
    if B.test then return B.TestScan() end
    B.lastScan = GetTime()
    learnNames()
    wipe(B.status)
    wipe(B.missing)
    wipe(B.unitHas)
    for class, units in pairs(classUnits) do
        -- want/units: who should have a blessing (a single from that paladin replaces his class blessing)
        local st = { total = 0, have = {}, left = {}, need = {}, want = {}, units = {} }
        for _, unit in ipairs(units) do
            if ns.Call(UnitExists, unit) then
                st.total = st.total + 1
                local key = B.unitKey[unit]
                local has, reliable = unitBlessings(unit, scratch)
                if reliable then remember(unit, has) else has = rememberedBlessings(unit, scratch); st.estimated = true end
                local copy = {}
                for b, left in pairs(has) do copy[b] = left end
                if key then B.unitHas[key] = { has = copy, estimated = not reliable } end
                B.CountUnit(st, unit, key, class, copy)
            end
        end
        B.status[class] = st
    end
    table.sort(B.missing, function(a, b) return a.key < b.key end)
    ns.Fire("LG_BLESSINGS")
end

-- adds one player to the class status and the missing list
function B.CountUnit(st, unit, key, class, has)
    local wantU = {}
    for _, p in pairs(B.paladins) do
        local b = gives(p, key, class)
        if b then wantU[b] = true end
    end
    local miss = {}
    for _, info in ipairs(B.LIST) do
        local b = info.key
        if wantU[b] then
            st.want[b] = (st.want[b] or 0) + 1
            st.units[b] = st.units[b] or {}
            table.insert(st.units[b], unit)
            if has[b] then
                st.have[b] = (st.have[b] or 0) + 1
                st.left[b] = math.min(st.left[b] or math.huge, has[b])
            else
                miss[#miss + 1] = b
                st.need[b] = st.need[b] or {}
                table.insert(st.need[b], unit)
            end
        end
    end
    if #miss > 0 then
        local m = key and B.members[key]
        local name = (m and m.name) or Names.Unit(unit) or unit
        B.missing[#B.missing + 1] = { key = key or Names.Key(name), name = name, class = class, list = miss, unit = unit }
    end
end

-- players who should get blessing b in this class (count for a bar row / grid cell)
function B.Wanted(class, b)
    local st = B.status[class]
    if not st then return 0, 0 end
    return st.have[b] or 0, st.want[b] or 0
end

-- state of a single blessing: has (bool), seconds left, estimated, unit
function B.SingleState(key, b)
    local m = B.members[key]
    local u = B.unitHas[key]
    local left = u and u.has[b]
    return left ~= nil, left, u and u.estimated, m and m.unit
end

-- counts for the page header
function B.Summary()
    local pal, synced = 0, 0
    for _, p in pairs(B.paladins) do pal = pal + 1; if p.addon then synced = synced + 1 end end
    local dup = 0
    local given = {}
    for _, p in pairs(B.paladins) do
        for class, b in pairs(p.set or {}) do
            local k = class .. b
            if given[k] then dup = dup + 1 end
            given[k] = true
        end
    end
    return { paladins = pal, synced = synced, missing = #B.missing, duplicates = dup }
end

---------------------------------------------------------------------------
-- Changing assignments
---------------------------------------------------------------------------
local function changed(p, quiet)
    if p.me and not B.test then
        -- p.set usually IS the saved table (Rebuild): wiping it would lose
        -- every assignment, so copy only when they are different tables
        local saved = ownSet()
        if saved ~= p.set then
            wipe(saved)
            for class, b in pairs(p.set or {}) do saved[class] = b end
        end
        local single, pinned = ownSingles()
        if single ~= p.single then
            wipe(single)
            for k, b in pairs(p.single or {}) do single[k] = b end
        end
        if pinned ~= p.pinned then
            wipe(pinned)
            for k, v in pairs(p.pinned or {}) do pinned[k] = v end
        end
    end
    if not quiet then B.Share(p) end
    ns.Debounce("bless-scan", 0.3, B.Scan)
    if ns.BlessingsBar then ns.BlessingsBar.Update() end
end

function B.Set(p, class, blessing)
    if not B.CanEdit(p) then return false end
    p.set = p.set or {}
    p.set[class] = blessing
    changed(p)
    return true
end

-- blessings this paladin can cast (unknown skills: everything)
local function canCast(p, b)
    local can = p.can and p.can[b]
    return can == nil or can > 0 or not p.addon
end
B.CanCast = canCast

-- Mouse wheel: next/previous blessing the paladin knows (then "none").
-- Assignments change at once; the sync is sent once the wheel rests.
function B.Cycle(p, class, delta, keep)
    if not B.CanEdit(p) then return false end
    local options = {}
    for _, b in ipairs(B.LIST) do
        if canCast(p, b.key) then options[#options + 1] = b.key end
    end
    if not keep then options[#options + 1] = false end   -- the bar keeps its row
    if #options == 0 then return false end
    p.set = p.set or {}
    local current = p.set[class] or false
    local pos = keep and 0 or #options
    for i, v in ipairs(options) do if v == current then pos = i end end
    pos = ((pos - 1 + (delta < 0 and 1 or -1)) % #options) + 1
    p.set[class] = options[pos] or nil
    changed(p, true)
    ns.Debounce("bless-wheel-share", 1, function() B.Share(p) end)
    return true
end

-- Shift + mouse wheel: the whole row of a paladin – this class cycles, every
-- class in the group (solo: all) gets the same blessing.
function B.CycleRow(p, class, delta, keep)
    if not B.Cycle(p, class, delta, keep) then return false end
    local b = p.set[class]
    local solo = not IsInGroup() and not B.test
    for _, c in ipairs(B.CLASSES) do
        if solo or (B.classUnits[c] and #B.classUnits[c] > 0) or c == class then p.set[c] = b end
    end
    changed(p, true)
    ns.Debounce("bless-wheel-share", 1, function() B.Share(p) end)
    return true
end
local function shift() return IsShiftKeyDown and IsShiftKeyDown() and true or false end
-- wheel on a class: shift = whole row
function B.WheelClass(p, class, delta, keep)
    if shift() then return B.CycleRow(p, class, delta, keep) end
    return B.Cycle(p, class, delta, keep)
end

-- Single blessing for one player (replaces this paladin's class blessing on him).
-- Set by hand = pinned: smart assign keeps it. blessing nil removes it.
function B.SetSingle(p, key, blessing, auto)
    if not B.CanEdit(p) or type(key) ~= "string" then return false end
    p.single = p.single or {}
    p.pinned = p.pinned or {}
    p.single[key] = blessing or nil
    p.pinned[key] = (blessing and not auto) and true or nil
    changed(p)
    return true
end

-- mouse wheel on a player: his class blessing (no single), then every other
-- blessing this paladin knows as a single one (set by hand)
function B.CycleSingle(p, key, delta)
    if not B.CanEdit(p) or type(key) ~= "string" then return false end
    local m = B.members[key]
    local classB = m and p.set and p.set[m.class]
    local options = { false }
    for _, b in ipairs(B.LIST) do
        if canCast(p, b.key) and b.key ~= classB then options[#options + 1] = b.key end
    end
    if #options == 1 then return false end
    p.single = p.single or {}
    p.pinned = p.pinned or {}
    local pos = 1
    for i, v in ipairs(options) do if v == (p.single[key] or false) then pos = i end end
    pos = ((pos - 1 + (delta < 0 and 1 or -1)) % #options) + 1
    local b = options[pos] or nil
    p.single[key], p.pinned[key] = b, b and true or nil
    changed(p, true)
    ns.Debounce("bless-wheel-share", 1, function() B.Share(p) end)
    return true
end

-- singles of a paladin for players in the group, sorted by class and name
function B.Singles(p)
    local out = {}
    for key, b in pairs(p and p.single or {}) do
        local m = B.members[key]
        if m then out[#out + 1] = { key = key, blessing = b, member = m, pinned = p.pinned and p.pinned[key] or false } end
    end
    local order = {}
    for i, c in ipairs(B.CLASSES) do order[c] = i end
    table.sort(out, function(a, b)
        local ca, cb = order[a.member.class] or 99, order[b.member.class] or 99
        if ca ~= cb then return ca < cb end
        return a.key < b.key
    end)
    return out
end

-- removes every single blessing of one player (all paladins you may change)
function B.ClearSingles(key)
    local n = 0
    for _, p in ipairs(B.PaladinList()) do
        if p.single and p.single[key] and B.CanEdit(p) then
            p.single[key] = nil
            if p.pinned then p.pinned[key] = nil end
            changed(p)
            n = n + 1
        end
    end
    return n
end

-- what each paladin gives a player: { { p, blessing, single, classB } }
function B.GivenTo(key, class)
    local out = {}
    for _, p in ipairs(B.PaladinList()) do
        local single = p.single and p.single[key]
        local classB = p.set and p.set[class]
        if single or classB then out[#out + 1] = { p = p, blessing = single or classB, single = single ~= nil, classB = classB } end
    end
    return out
end

function B.Clear(p)
    if not B.CanEdit(p) then return false end
    p.set, p.single, p.pinned = {}, {}, {}
    changed(p)
    return true
end

---------------------------------------------------------------------------
-- Smart assign: class blessings from what the players of each class play,
-- then single blessings for players who want something else than their
-- class gets (feral druid among restoration druids, a tank among holy
-- paladins). Singles set by hand stay; paladins you may not change keep
-- their blessings and count as given.
---------------------------------------------------------------------------
local function weights(members)
    local w = {}
    for _, m in ipairs(members) do
        local n = #m.wishes
        for i, b in ipairs(m.wishes) do w[b] = (w[b] or 0) + (n - i + 1) end
    end
    return w
end
local function ordered(w)
    local list = {}
    for b, v in pairs(w) do if v > 0 then list[#list + 1] = b end end
    table.sort(list, function(a, b)
        if w[a] ~= w[b] then return w[a] > w[b] end
        return B.BY_KEY[a].order < B.BY_KEY[b].order
    end)
    return list
end

-- group members by class with what they play: { [class] = { { key, unit, kind, wishes } } }
function B.GroupWishes()
    local members, classes = {}, {}
    if IsInGroup() or B.test then
        for _, class in ipairs(B.CLASSES) do
            local units = classUnits[class]
            if units and #units > 0 then
                classes[#classes + 1] = class
                members[class] = {}
                for _, unit in ipairs(units) do
                    local key = B.unitKey[unit]
                    local kind, source = B.UnitType(unit, key, class)
                    table.insert(members[class], { key = key, unit = unit, kind = kind, source = source, wishes = B.Wishes(kind, class) })
                end
            end
        end
    else
        -- solo there is nobody to count: plan every class for later
        for _, class in ipairs(B.CLASSES) do
            classes[#classes + 1] = class
            members[class] = { { kind = CLASS_TYPE[class], wishes = B.Wishes(CLASS_TYPE[class], class) } }
        end
    end
    return members, classes
end

-- onlyMe: change only your own assignments (first start of the bar).
function B.Suggest(onlyMe)
    local list = {}
    for _, p in ipairs(B.PaladinList()) do if B.CanEdit(p) or not IsInGroup() then list[#list + 1] = p end end
    if #list == 0 then return false end
    local all = B.PaladinList()
    local members, classes = B.GroupWishes()
    local function editable(p) return B.CanEdit(p) and (not onlyMe or p.me) end

    local new, edit, fixedMain = {}, {}, {}
    for _, p in ipairs(all) do
        if editable(p) then
            new[p.key] = {}
            edit[#edit + 1] = p
        else
            -- kept as it is; his most given blessing needs no other paladin
            local copy, count = {}, {}
            for class, b in pairs(p.set or {}) do copy[class] = b; count[b] = (count[b] or 0) + 1 end
            new[p.key] = copy
            local best
            for b, n in pairs(count) do if not best or n > count[best] then best = b end end
            if best then fixedMain[best] = true end
        end
    end
    -- the main blessing of each paladin: the most wanted blessing goes to the
    -- paladin with the fewest alternatives (Kings stays with whoever has the talent)
    local function options(p)
        local n = 0
        for _, b in ipairs(B.LIST) do if canCast(p, b.key) then n = n + 1 end end
        return n
    end
    local global = {}
    for _, class in ipairs(classes) do
        for b, v in pairs(weights(members[class])) do global[b] = (global[b] or 0) + v end
    end
    local primary = {}
    for _, b in ipairs(ordered(global)) do
        if not fixedMain[b] then
            local best
            for _, p in ipairs(edit) do
                if not primary[p.key] and canCast(p, b) and (not best or options(p) < options(best)) then best = p end
            end
            if best then primary[best.key] = b end
        end
    end
    -- per class: main blessings where the class wants them, then the best free wish
    for _, class in ipairs(classes) do
        local order = ordered(weights(members[class]))
        local wanted, taken = {}, {}
        for _, b in ipairs(order) do wanted[b] = true end
        for _, p in ipairs(all) do
            if not editable(p) and new[p.key][class] then taken[new[p.key][class]] = true end
        end
        for _, p in ipairs(edit) do
            local b = primary[p.key]
            if b and wanted[b] and not taken[b] then new[p.key][class] = b; taken[b] = true end
        end
        for _, p in ipairs(edit) do
            if not new[p.key][class] then
                for _, b in ipairs(order) do
                    if not taken[b] and canCast(p, b) then new[p.key][class] = b; taken[b] = true; break end
                end
            end
        end
    end
    -- singles: pinned ones stay (and those of paladins we may not change)
    local singles = {}
    for _, p in ipairs(all) do
        local s = {}
        for key, b in pairs(p.single or {}) do
            if not editable(p) or (p.pinned and p.pinned[key]) then s[key] = b end
        end
        singles[p.key] = s
    end
    for _, class in ipairs(classes) do
        for _, m in ipairs(members[class]) do
            if m.key then
                local wish = {}
                for i, b in ipairs(m.wishes) do wish[b] = i end
                -- fixed first: what he surely gets
                local covered, redo = {}, {}
                local function look(p, fixed)
                    local b = singles[p.key][m.key] or new[p.key][class]
                    if not b then return end
                    if wish[b] and not covered[b] then covered[b] = true
                    elseif not fixed then redo[#redo + 1] = p end
                end
                for _, p in ipairs(all) do
                    if not editable(p) or (p.pinned and p.pinned[m.key]) then look(p, true) end
                end
                for _, p in ipairs(edit) do
                    if not (p.pinned and p.pinned[m.key]) then look(p, false) end
                end
                -- an unwanted or doubled blessing becomes the best wish still open
                for _, p in ipairs(redo) do
                    for _, b in ipairs(m.wishes) do
                        if not covered[b] and canCast(p, b) then
                            if b ~= new[p.key][class] then singles[p.key][m.key] = b end
                            covered[b] = true
                            break
                        end
                    end
                end
            end
        end
    end
    for _, p in ipairs(all) do
        if editable(p) then
            p.set = new[p.key]
            local pinned = {}
            for key in pairs(p.pinned or {}) do if singles[p.key][key] then pinned[key] = true end end
            p.single, p.pinned = singles[p.key], pinned
            changed(p)
        end
    end
    return true
end

---------------------------------------------------------------------------
-- New in the group: a class you do not bless yet gets a blessing from you
-- right away (own assignments only, option "autoNew"). Your main blessing if
-- the class wants it, else the best wish no other paladin gives that class
-- (main blessings of other addon paladins are left to them – they fill in too).
---------------------------------------------------------------------------
local function mainBlessing(p)
    local count, best = {}, nil
    for _, b in pairs(p.set or {}) do count[b] = (count[b] or 0) + 1 end
    for _, info in ipairs(B.LIST) do
        local n = count[info.key]
        if n and (not best or n > count[best]) then best = info.key end
    end
    return best
end
B.MainBlessing = mainBlessing

-- classes: { [class] = true }; returns { [class] = blessing } of what was filled in
function B.FillNew(classes)
    local me = B.Me()
    if not me or not me.me or not (IsInGroup() or B.test) or B.Settings().autoNew == false or not classes then return nil end
    me.can = B.test and me.can or B.OwnSkills()
    local myMain = mainBlessing(me)
    local othersMain = {}
    for _, p in pairs(B.paladins) do
        if not p.me and p.addon == "lg" then local m = mainBlessing(p); if m then othersMain[m] = true end end
    end
    local members = B.GroupWishes()
    local filled = {}
    for _, class in ipairs(B.CLASSES) do
        local units = classUnits[class]
        if classes[class] and units and #units > 0 and not (me.set and me.set[class]) then
            local taken = {}
            for _, p in pairs(B.paladins) do
                if not p.me and p.set and p.set[class] then taken[p.set[class]] = true end
            end
            local order = ordered(weights(members[class] or {}))
            local wanted = {}
            for _, b in ipairs(order) do wanted[b] = true end
            local pick
            if myMain and wanted[myMain] and not taken[myMain] and canCast(me, myMain) then pick = myMain end
            for pass = 1, 2 do
                if pick then break end
                for _, b in ipairs(order) do
                    if not taken[b] and canCast(me, b) and (pass == 2 or not othersMain[b]) then pick = b; break end
                end
            end
            if pick then
                me.set = me.set or {}
                me.set[class] = pick
                filled[class] = pick
            end
        end
    end
    if not next(filled) then return nil end
    changed(me)
    local parts = {}
    for _, class in ipairs(B.CLASSES) do
        if filled[class] then parts[#parts + 1] = ns.ClassName(class) .. ": " .. B.Name(filled[class]) end
    end
    ns.Print(L.BLESS_NEW_CLASS:format(table.concat(parts, ", ")))
    return filled
end

---------------------------------------------------------------------------
-- Telling people: whisper each paladin, announce in the group
---------------------------------------------------------------------------
local function describe(set)
    local byB = {}
    for _, class in ipairs(B.CLASSES) do
        local b = set and set[class]
        if b and classUnits[class] then
            byB[b] = byB[b] or {}
            local cname = ns.ClassName(class)
            table.insert(byB[b], cname)
        end
    end
    local parts = {}
    for _, b in ipairs(B.LIST) do
        if byB[b.key] then parts[#parts + 1] = B.Name(b.key) .. ": " .. table.concat(byB[b.key], ", ") end
    end
    return #parts > 0 and table.concat(parts, " · ") or nil
end
B.Describe = describe
-- singles of a paladin as one line ("Single: Light → Dyaxler, Might → Borin"), nil without
local function describeSingles(p)
    local parts = {}
    for _, s in ipairs(B.Singles(p)) do
        parts[#parts + 1] = ("%s → %s"):format(B.Name(s.blessing), Names.Display(s.member.name))
    end
    if #parts == 0 then return nil end
    local text = L.BLESS_SINGLE_LINE:format(table.concat(parts, ", "))
    return #text > 240 and (text:sub(1, 237) .. "...") or text
end
B.DescribeSingles = describeSingles

function B.WhisperAll()
    local n = 0
    for _, p in ipairs(B.PaladinList()) do
        local text, single = describe(p.set), describeSingles(p)
        if (text or single) and not p.me then
            local msg = ns.Messages.Format("blessWhisper", { blessings = text or single, player = Names.Display(p.name) })
            local extra = text and single or nil
            if B.test then
                ns.Print(L.TEST_TAG .. " " .. p.name .. ": " .. msg)
                if extra then ns.Print(L.TEST_TAG .. " " .. p.name .. ": " .. extra) end
            else
                ns.SendChat(msg, "WHISPER", p.name)
                if extra then ns.SendChat(extra, "WHISPER", p.name) end
            end
            n = n + 1
        end
    end
    ns.Print(L.BLESS_WHISPERED:format(n))
end

function B.Announce()
    if B.test then
        ns.Print(L.TEST_TAG .. " " .. L.BLESS_ANNOUNCE_HEAD)
        for _, p in ipairs(B.PaladinList()) do
            local text = describe(p.set)
            if text then ns.Print(L.TEST_TAG .. " " .. ("%s – %s"):format(Names.Display(p.name), text)) end
            local single = describeSingles(p)
            if single then ns.Print(L.TEST_TAG .. " " .. ("%s – %s"):format(Names.Display(p.name), single)) end
        end
        return
    end
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY") or nil
    if not channel then ns.Print(L.NOT_IN_GROUP); return end
    ns.SendChat(L.BLESS_ANNOUNCE_HEAD, channel)
    for _, p in ipairs(B.PaladinList()) do
        local text = describe(p.set)
        if text then ns.SendChat(("%s – %s"):format(Names.Display(p.name), text), channel) end
        local single = describeSingles(p)
        if single then ns.SendChat(("%s – %s"):format(Names.Display(p.name), single), channel) end
    end
end

---------------------------------------------------------------------------
-- Sync: own protocol ("BL") plus PallyPower ("PLPWR")
---------------------------------------------------------------------------
local PP = "PLPWR"
local PP_CLASSES = { "WARRIOR", "ROGUE", "PRIEST", "DRUID", "PALADIN", "HUNTER", "MAGE", "WARLOCK", "SHAMAN" }
-- 4 = Salvation (not a blessing on Forever), 7 = Sacrifice: kept as they are
local PP_BLESS = { ["1"] = "wisdom", ["2"] = "might", ["3"] = "kings" }
local PP_DIGIT = { wisdom = "1", might = "2", kings = "3" }
local PP_SKILLS = { "wisdom", "might", "kings", false, false, false }   -- order of the skill pairs in SELF
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then ns.Call(C_ChatInfo.RegisterAddonMessagePrefix, PP) end
local senderMayAssign   -- defined below

-- PallyPower runs on this client itself: it speaks for us, we only listen
local function ppSelfLoaded()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return loaded and ns.Call(loaded, "PallyPower") and true or false
end
local function ppSend() return B.Settings().ppSync and not ppSelfLoaded() end
local function ppRead() return B.Settings().ppRead end

-- 9 class digits plus the unused tenth; digits this addon does not know
-- (4–9: none of them is a blessing on Forever) stay as they were
local function ppSet(set, other)
    local out = {}
    for i, class in ipairs(PP_CLASSES) do
        out[i] = (set and PP_DIGIT[set[class]]) or (other and other[class]) or "n"
    end
    return table.concat(out) .. "n"
end
-- reads 9 class digits: known blessings, other digits kept apart
local function ppParse(text)
    local set, other = {}, {}
    for i, class in ipairs(PP_CLASSES) do
        local c = text:sub(i, i)
        if PP_BLESS[c] then set[class] = PP_BLESS[c] elseif c:find("^[4-9]$") then other[class] = c end
    end
    return set, other
end
-- own skills: highest known rank (hex) and a talent digit per blessing
local function ppSkills()
    local out = {}
    for _, key in ipairs(PP_SKILLS) do
        local id, rank = key and B.SpellFor(key, "single"), nil
        for i, sid in ipairs(key and B.BY_KEY[key].single or {}) do if sid == id then rank = i end end
        out[#out + 1] = rank and ("%x0"):format(rank) or "nn"
    end
    return table.concat(out)
end
B.PPSet, B.PPParse, B.PPSkills = ppSet, ppParse, ppSkills

-- PallyPower single blessings: "NASSIGN <paladin> <class no.> <player> <digit>", names with
-- "_" instead of the space, up to five per message joined by "@"; digit 0 = removed
local PP_CLASS_NO = {}
for i, c in ipairs(PP_CLASSES) do PP_CLASS_NO[c] = i end
local function wire(name) return (tostring(name or ""):gsub(" ", "_")) end
local function unwire(name) return (tostring(name or ""):gsub("_", " ")) end
function B.PPSingles(p)
    local list, now = {}, {}
    local pname = wire(p.name or Names.Display(p.key))
    for key, b in pairs(p.single or {}) do
        local m = B.members[key]
        local digit, no = PP_DIGIT[b], m and PP_CLASS_NO[m.class]
        if m and digit and no then
            list[#list + 1] = ("%s %d %s %s"):format(pname, no, wire(m.name), digit)
            now[key] = no
        end
    end
    -- removed since the last message: digit 0
    for key, no in pairs(p.ppSent or {}) do
        local m = B.members[key]
        if not now[key] and m then list[#list + 1] = ("%s %d %s 0"):format(pname, no, wire(m.name)) end
    end
    table.sort(list)
    local out = {}
    for i = 1, #list, 5 do out[#out + 1] = "NASSIGN " .. table.concat(list, "@", i, math.min(i + 4, #list)) end
    return out, now
end
local function sendPPSingles(p, channel)
    local msgs, now = B.PPSingles(p)
    p.ppSent = now
    for _, m in ipairs(msgs) do Comm.SendRaw(PP, m, channel, { priority = "normal" }) end
end

function B.Share(p)
    if B.test then return end
    if not IsInGroup() or not enabled() then return end
    local me = Names.Me()
    p = p or B.Me()
    if not p then return end
    local mine = Names.Same(p.key, me)
    Comm.Send("BL", { p = p.key, s = encode(p.set), i = encodeSingles(p), c = mine and encodeSkills(p.can) or nil, f = mine and (B.Settings().freeAssign and 1 or nil) or nil },
        "GROUP", { priority = "normal" })
    -- PallyPower users (guests without this addon) see it too
    local channel = ns.GroupChannel()
    if channel and ppSend() then
        if mine then
            if not isPaladin() then return end
            Comm.SendRaw(PP, "SELF " .. ppSkills() .. "@" .. ppSet(p.set), channel, { priority = "normal" })
            sendPPSingles(p, channel)
            Comm.SendRaw(PP, "FREEASSIGN " .. (B.Settings().freeAssign and "YES" or "NO"), channel, { priority = "normal" })
        elseif senderMayAssign(me, p.key) then
            Comm.SendRaw(PP, ("PASSIGN %s@%s"):format(p.name or Names.Display(p.key), ppSet(p.set, p.ppOther)), channel, { priority = "normal" })
            sendPPSingles(p, channel)
            -- a guest answers REQ with SELF: shows whether the change arrived
            if p.addon == "pp" then
                ns.Debounce("bless-pp-verify", 1.5, function()
                    local ch = ns.GroupChannel()
                    if ch and ppSend() then Comm.SendRaw(PP, "REQ", ch, { priority = "normal" }) end
                end)
            end
        end
    end
end

function B.Request()
    if not IsInGroup() or not enabled() then return end
    Comm.Send("BLQ", {}, "GROUP", { priority = "normal" })
    local channel = ns.GroupChannel()
    if channel and (ppRead() or ppSend()) then Comm.SendRaw(PP, "REQ", channel, { priority = "normal" }) end
end

senderMayAssign = function(senderKey, targetKey)
    if Names.Same(senderKey, targetKey) then return true end
    local unit = ns.UnitForKey(senderKey)
    if unit and ns.IsGroupLead(unit) then return true end
    local target = B.paladins[targetKey]
    return target ~= nil and target.free == true
end

-- singles: { single, pinned } or nil (sender without singles: keep ours)
local function apply(targetKey, set, can, free, via, other, singles)
    B.Rebuild()
    local p = B.paladins[targetKey]
    if not p then return end
    if singles then p.single, p.pinned = singles[1], singles[2] end
    if p.me then
        -- someone (lead) assigned us: take it over
        p.set = set
        changed(p, true)
    else
        p.set = set
        if via == "pp" then p.ppOther = other or {} end
        if can then p.can = can end
        if free ~= nil then p.free = free end
        p.addon = p.addon == "lg" and "lg" or via
        ns.Debounce("bless-scan", 0.3, B.Scan)
        if ns.BlessingsBar then ns.BlessingsBar.Update() end
    end
end

Comm.Register("BL", function(data, sender)
    if not enabled() or type(data.p) ~= "string" then return end
    local target = Names.Key(data.p)
    if not target or not senderMayAssign(sender, target) then return end
    if Names.Same(sender, Names.Me()) then return end
    local p = B.paladins[target]
    if p and Names.Same(target, sender) then p.addon = "lg" end
    local single, pinned = decodeSingles(data.i)
    apply(target, decode(data.s), data.c and decodeSkills(data.c) or nil, data.c and (data.f == 1) or nil, "lg", nil,
        single and { single, pinned } or nil)
end)

Comm.Register("BLQ", function()
    if not enabled() or not isPaladin() then return end
    ns.Debounce("bless-reply", 1 + math.random() * 2, function() B.Rebuild(); B.Share(B.Me()) end)
end)

local function hearPallyPower(text, senderKey)
    local me = Names.Me()
    if Names.Same(senderKey, me) then return end
    B.Rebuild()
    if text == "REQ" then
        if isPaladin() and ppSend() then ns.Debounce("bless-reply", 1 + math.random() * 2, function() B.Share(B.Me()) end) end
        return
    end
    if not ppRead() then return end
    local free = text:match("^FREEASSIGN (%u+)")
    if free then
        local p = B.paladins[senderKey]
        if p and p.addon ~= "lg" and (free == "YES" or free == "NO") then p.free = free == "YES" end
        return
    end
    local skills, set = text:match("^SELF ([0-9a-fn]*)@([0-9n]*)")
    if skills then
        local p = B.paladins[senderKey]
        if not p or #skills < 6 then return end
        local can = {}
        for i, k in ipairs(PP_SKILLS) do
            local c = skills:sub(2 * i - 1, 2 * i - 1)
            if k then can[k] = (c == "" or c == "n") and 0 or 2 end
        end
        local s, other = ppParse(set)
        if p.addon ~= "lg" then apply(senderKey, s, can, nil, "pp", other) end
        return
    end
    local function target(name)
        local key = Names.Key(Names.Strip(name))
        if key and B.paladins[key] and senderMayAssign(senderKey, key) then return key end
    end
    local function current(key)
        local p = B.paladins[key]
        local s, o = {}, {}
        for c, b in pairs(p.set or {}) do s[c] = b end
        for c, d in pairs(p.ppOther or {}) do o[c] = d end
        return s, o
    end
    local name, classIdx, digit = text:match("^ASSIGN (.*) (%d+) (%d+)$")
    if name then
        local key, class = target(name), PP_CLASSES[tonumber(classIdx)]
        if key and class then
            local s, o = current(key)
            s[class], o[class] = PP_BLESS[digit], (digit:find("^[4-9]$") and digit) or nil
            apply(key, s, nil, nil, "pp", o)
        end
        return
    end
    local pname, pset = text:match("^PASSIGN (.*)@([0-9n]*)$")
    if pname then
        local key = target(pname)
        if key then
            local s, o = ppParse(pset)
            apply(key, s, nil, nil, "pp", o)
        end
        return
    end
    if text:find("^NASSIGN ") then
        local touched = {}
        for entry in text:sub(9):gmatch("[^@]+") do
            local pname, no, tname, digit = entry:match("^(%S+) (%d+) (%S+) (%d+)$")
            local key = pname and target(unwire(pname))
            local tkey = tname and Names.Key(unwire(tname))
            local p = key and B.paladins[key]
            if p and tkey and PP_CLASSES[tonumber(no)] then
                p.single, p.pinned = p.single or {}, p.pinned or {}
                local b = PP_BLESS[digit]
                p.single[tkey] = b
                p.pinned[tkey] = b and true or nil   -- set by a person
                touched[p] = true
            end
        end
        for p in pairs(touched) do
            if p.me then changed(p, true)
            else
                if p.addon ~= "lg" then p.addon = "pp" end
                ns.Debounce("bless-scan", 0.3, B.Scan)
                if ns.BlessingsBar then ns.BlessingsBar.Update() end
            end
        end
        return
    end
    local mname, mdigit = text:match("^MASSIGN (.*) (%d+)$")
    if mname then
        local key = target(mname)
        if key then
            local s, o = ppParse(mdigit:sub(1, 1):rep(#PP_CLASSES))
            apply(key, s, nil, nil, "pp", o)
        end
        return
    end
    if text:find("^CLEAR") then
        for key in pairs(B.paladins) do if senderMayAssign(senderKey, key) then apply(key, {}, nil, nil, "pp", {}) end end
    end
end

ns.On("CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
    if prefix ~= PP or not enabled() then return end
    if ns.IsSecret(text) or ns.IsSecret(sender) or type(text) ~= "string" then return end
    if channel ~= "RAID" and channel ~= "PARTY" and channel ~= "WHISPER" and channel ~= "INSTANCE_CHAT" then return end
    local key = Names.Key(Names.Strip(sender))
    if key then ns.Safe(hearPallyPower, text, key) end
end)

---------------------------------------------------------------------------
-- Events (cheap: nothing outside a group unless you are a paladin)
---------------------------------------------------------------------------
local function wanted()
    if B.test then return true end
    local shown = ns.Window.IsShown("blessings") and true or false
    if not enabled() then return shown end
    if isPaladin() then
        local o = B.Settings()
        -- solo: the bar shows your own buffs (only "player" auras get scanned)
        if o.bar and (IsInGroup() or o.solo) then return true end
        return shown
    end
    if not IsInGroup() then return shown end
    return shown
end
B.Active = wanted

-- classes present at the last look (nil: not in a group) and classes that
-- joined since, filled in once the other paladins had time to sync
local present, newClasses, retries, joinedAt = nil, {}, 0, -999
local function fillLater()
    if not IsInGroup() or not next(newClasses) then return end
    if InCombatLockdown and InCombatLockdown() then ns.AfterCombat("bless-fill", fillLater); return end
    local list = newClasses
    newClasses = {}
    B.Rebuild()
    ns.Safe(B.FillNew, list)
end
local function rosterChanged()
    if not enabled() then return end
    B.Rebuild()
    -- someone joined and the game does not know him yet: look again shortly
    if B.incomplete and retries < 10 then
        retries = retries + 1
        ns.Debounce("bless-roster-retry", 2, rosterChanged)
    elseif not B.incomplete then
        retries = 0
    end
    if IsInGroup() and not B.test then
        local now = {}
        for class, units in pairs(classUnits) do if #units > 0 then now[class] = true end end
        -- after a login or /reload inside a group nothing is new; after joining everything is
        if present or GetTime() - joinedAt < 20 then
            for class in pairs(now) do
                if not present or not present[class] then newClasses[class] = true end
            end
        end
        present = now
        if next(newClasses) and isPaladin() then ns.Debounce("bless-fill-new", 6, fillLater) end
    else
        present, newClasses = nil, {}
    end
    if wanted() then ns.Debounce("bless-scan", 0.5, B.Scan) end
    if ns.BlessingsBar then ns.BlessingsBar.Update() end
end
B.RosterChanged = rosterChanged
ns.On("GROUP_ROSTER_UPDATE", function() ns.Debounce("bless-roster", 1, rosterChanged) end)
ns.On("PLAYER_ENTERING_WORLD", function() ns.Debounce("bless-roster", 2, rosterChanged) end)
ns.On("GROUP_JOINED", function() joinedAt = GetTime(); ns.After(3, B.Request) end)
ns.On("SPELLS_CHANGED", function()
    if not isPaladin() then return end
    ns.Debounce("bless-skills", 2, function()
        local p = B.Me()
        if p then p.can = B.OwnSkills() end
    end)
end)
-- raids fire UNIT_AURA constantly: one scan at most every 1.5 s (5 s in combat);
-- a throttle, not a debounce, so it still runs while auras keep changing
local scanPending = false
ns.On("UNIT_AURA", function(_, unit)
    if scanPending or type(unit) ~= "string" then return end
    if not (unit == "player" or unit:find("^raid%d") or unit:find("^party%d")) then return end
    if not wanted() then return end
    scanPending = true
    ns.After((InCombatLockdown and InCombatLockdown()) and 5 or 1.5, function() scanPending = false; B.Scan() end)
end)
ns.On("LG_READY", function()
    if isPaladin() then ns.After(4, rosterChanged) end
end)

---------------------------------------------------------------------------
-- Test mode (/lg test bless): made-up paladins and raiders for 3 minutes.
-- Nothing is sent, whispered or saved; the bar shows even for non-paladins
-- and its clicks cast nothing.
---------------------------------------------------------------------------
local TEST_RAID = { WARRIOR = 6, ROGUE = 3, HUNTER = 3, PRIEST = 4, MAGE = 5, WARLOCK = 3, DRUID = 3, PALADIN = 4 }
local TEST_FIRST = { "Arwen", "Borin", "Cara", "Dorn", "Elin", "Falk", "Gwen", "Hask", "Ilsa", "Jory", "Kael", "Lyra", "Miro",
    "Nessa", "Orin", "Pella", "Quin", "Rhea", "Soren", "Tamsin", "Ulric", "Vela", "Wren", "Xander", "Yara", "Zeno", "Aldo",
    "Brin", "Cyra", "Dexter", "Edda", "Fenn" }
local TEST_LAST = { "Stormwind", "Ironfist", "Lightweaver", "Shadowsong", "Morningdew", "Greyholt", "Ashvale", "Brightwater" }
-- what the made-up raiders play: a warrior tank, a protection paladin, a feral druid
local TEST_TYPES = { ["lgtest-warrior-1"] = "tank", ["lgtest-paladin-4"] = "tank", ["lgtest-druid-3"] = "melee" }

function B.TestScan()
    wipe(B.status)
    wipe(B.missing)
    wipe(B.unitHas)
    for class, units in pairs(classUnits) do
        local st = { total = #units, have = {}, left = {}, need = {}, want = {}, units = {} }
        for i, unit in ipairs(units) do
            local key = B.unitKey[unit]
            -- some players miss a blessing, some run out soon
            local has = {}
            for _, b in ipairs(B.LIST) do
                local hash = (#class * 7 + #b.key * 3 + i * 5) % 9
                if hash ~= 0 then has[b.key] = hash == 1 and 140 or (600 + hash * 120) end
            end
            if key then B.unitHas[key] = { has = has } end
            B.CountUnit(st, unit, key, class, has)
        end
        B.status[class] = st
    end
    table.sort(B.missing, function(a, b) return a.key < b.key end)
    ns.Fire("LG_BLESSINGS")
end

function B.Test(seconds)
    seconds = seconds or 180
    B.test = GetTime() + seconds
    wipe(B.paladins)
    wipe(classUnits)
    wipe(B.members); wipe(B.unitKey); wipe(B.testTypes)
    local n = 0
    for _, class in ipairs(B.CLASSES) do
        local count = TEST_RAID[class]
        if count then
            classUnits[class] = {}
            for i = 1, count do
                local unit = ("lgtest-%s-%d"):format(class:lower(), i)
                classUnits[class][i] = unit
                n = n + 1
                local name = TEST_FIRST[(n - 1) % #TEST_FIRST + 1] .. " " .. TEST_LAST[(n - 1) % #TEST_LAST + 1]
                addMember(unit, Names.Key(name), name, class)
                B.testTypes[unit] = TEST_TYPES[unit]
            end
        end
    end
    local function keyOf(unit) return B.unitKey[unit] end
    local me = Names.Me()
    local full = { kings = 2, might = 2, wisdom = 2 }
    -- you: Light for every paladin, but Might for the protection paladin (set by hand)
    B.paladins[me] = { key = me, name = Names.Unit("player") or Names.Display(me), unit = "player", addon = "lg", me = true,
        can = isPaladin() and B.OwnSkills() or full, set = { WARRIOR = "might", ROGUE = "might", HUNTER = "might", PALADIN = "wisdom" },
        single = { [keyOf("lgtest-paladin-4")] = "might" }, pinned = { [keyOf("lgtest-paladin-4")] = true } }
    B.paladins["test lightbringer"] = { key = "test lightbringer", name = "Test Lightbringer", addon = "lg", can = full,
        set = { WARRIOR = "kings", ROGUE = "kings", PRIEST = "kings", MAGE = "kings", PALADIN = "kings" } }
    -- Wisdom for the druids, the feral one gets Might instead (smart assign)
    B.paladins["test silverhand"] = { key = "test silverhand", name = "Test Silverhand", addon = "lg", can = { kings = 0, might = 2, wisdom = 2 },
        set = { PRIEST = "wisdom", MAGE = "wisdom", WARLOCK = "wisdom", DRUID = "wisdom", PALADIN = "wisdom" },
        single = { [keyOf("lgtest-druid-3")] = "might" }, pinned = {} }
    B.paladins["test pallypower"] = { key = "test pallypower", name = "Test PallyPower", addon = "pp", can = full, set = {} }
    B.TestScan()
    if ns.BlessingsBar then ns.BlessingsBar.Update() end
    ns.Window.Show("blessings")
    ns.Print(L.TEST_TAG .. " " .. L.BLESS_TEST_ON:format(math.floor(seconds / 60)))
    ns.After(seconds, function()
        if not B.test or GetTime() < B.test - 1 then return end
        B.StopTest()
    end)
end

-- /lg test blessspells: which ranks you know (by id or by name), learned ids
function B.SpellReport()
    learnNames()
    for _, b in ipairs(B.LIST) do
        local function part(kind)
            local id = B.SpellFor(b.key, kind)
            local how = id and (known(id) and ("id " .. id) or L.BLESS_SPELLS_BYNAME) or "–"
            return how
        end
        local learned = {}
        for id, v in pairs(B.Settings().learned or {}) do if tostring(v):match("^" .. b.key .. ":") then learned[#learned + 1] = tostring(id) end end
        ns.Print(L.BLESS_SPELLS_LINE:format(B.Name(b.key), part("single"), part("greater"),
            #learned > 0 and table.concat(learned, ", ") or "–"))
    end
end

-- /lg test blessspec: what every group member plays and wants, and what you give him
function B.SpecReport()
    if not B.test then B.Rebuild() end
    local members, classes = B.GroupWishes()
    if not IsInGroup() and not B.test then ns.Print(L.BLESS_SPEC_SOLO); return end
    local me = B.Me()
    for _, class in ipairs(classes) do
        for _, m in ipairs(members[class]) do
            local info = m.key and B.members[m.key]
            local names = {}
            for _, b in ipairs(m.wishes) do names[#names + 1] = B.Name(b) end
            local mine = me and gives(me, m.key, class)
            ns.Print(L.BLESS_SPEC_LINE:format(ns.ColorName(info and info.name or m.unit or "?", class), L["BLESS_TYPE_" .. m.kind:upper()] or m.kind,
                L["BLESS_SRC_" .. tostring(m.source):upper()] or tostring(m.source), table.concat(names, ", "),
                mine and B.Name(mine) or "–"))
        end
    end
end

function B.StopTest()
    if not B.test then return end
    B.test = nil
    wipe(B.paladins)
    wipe(B.status)
    wipe(B.missing)
    wipe(B.testTypes)
    rosterChanged()
    if wanted() then B.Scan() else ns.Fire("LG_BLESSINGS") end
    ns.AfterCombat("bless-bar", function() if ns.BlessingsBar then ns.BlessingsBar.Update() end end)
    ns.Print(L.TEST_TAG .. " " .. L.BLESS_TEST_OFF)
end
