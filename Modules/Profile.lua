-- Own character profile (gear, item level, spec, professions, recipes) and
-- guild-wide sync of everyone's profiles.
local _, ns = ...
local Profile = ns.NewModule("profile")
ns.Profile = Profile
local Comm, Items, Names = ns.Comm, ns.Items, ns.Names

local PROFESSIONS = {
    "Alchemy", "Alchimie", "Blacksmithing", "Schmiedekunst", "Enchanting", "Verzauberkunst",
    "Engineering", "Ingenieurskunst", "Herbalism", "Kräuterkunde", "Leatherworking", "Lederverarbeitung",
    "Mining", "Bergbau", "Skinning", "Kürschnerei", "Tailoring", "Schneiderei", "Jewelcrafting",
    "Juwelierskunst", "Inscription", "Inschriftenkunde", "Cooking", "Kochkunst", "First Aid",
    "Erste Hilfe", "Fishing", "Angeln",
}
local IS_PROFESSION = {}
for _, n in ipairs(PROFESSIONS) do IS_PROFESSION[n] = true end

---------------------------------------------------------------------------
-- Capture
---------------------------------------------------------------------------
local hasRangedSlot
local function rangedSlotExists()
    if hasRangedSlot == nil then
        hasRangedSlot = ns.Call(GetInventorySlotInfo, "RangedSlot") ~= nil
    end
    return hasRangedSlot
end

-- Average item level from a slot -> itemString/link map
function Profile.AverageLevel(gear)
    local total, slots = 0, rangedSlotExists() and 17 or 16
    local any = false
    for _, slot in ipairs(Items.SLOTS) do
        if slot.id ~= 18 or rangedSlotExists() then
            local item = gear[slot.id]
            local level = item and Items.Level(item)
            if level then total = total + level; any = true end
        end
    end
    -- a two-hander counts twice when the off hand is empty
    local main = gear[16]
    if main and not gear[17] then
        local info = Items.Info(main)
        if info and info.equipLoc == "INVTYPE_2HWEAPON" then
            total = total + (Items.Level(main) or 0)
        end
    end
    if not any then return nil end
    return math.floor(total / slots * 10 + 0.5) / 10
end

function Profile.ReadGear(unit)
    local gear = {}
    for _, slot in ipairs(Items.SLOTS) do
        local link = ns.Call(GetInventoryItemLink, unit, slot.id)
        local s = Items.String(link)
        if s then gear[slot.id] = s end
    end
    for _, slot in ipairs(Items.COSMETIC) do
        local s = Items.String(ns.Call(GetInventoryItemLink, unit, slot.id))
        if s then gear[slot.id] = s end
    end
    return gear
end

-- Talent trees of the player (or of the inspected unit): spec name (tree with
-- the most points), "x/y/z" and the tree names "A,B,C". The return order of
-- GetTalentTabInfo differs between clients, so the values are found by type;
-- when the tab reports no points, the ranks of the single talents are summed.
local function tabInfo(i, inspect)
    local r = { ns.Call(GetTalentTabInfo, i, inspect) }
    local name
    if type(r[1]) == "number" and type(r[2]) == "string" then name = r[2] end
    for j = 1, 3 do if not name and type(r[j]) == "string" and r[j] ~= "" then name = r[j] end end
    local spent = (type(r[1]) == "number" and type(r[5]) == "number" and r[5])
        or (type(r[3]) == "number" and r[3]) or (type(r[5]) == "number" and r[5]) or 0
    if spent == 0 and GetNumTalents and GetTalentInfo then
        local n = ns.Call(GetNumTalents, i, inspect)
        local sum = 0
        for j = 1, (type(n) == "number" and n or 0) do
            local rank = select(5, ns.Call(GetTalentInfo, i, j, inspect))
            if type(rank) == "number" then sum = sum + rank end
        end
        spent = sum
    end
    return name, spent
end

-- Forever uses the modern talent system (C_Traits): one tree per class whose
-- node groups are the three classic trees. Points per group = sum of the
-- purchased ranks of its nodes.
local function traitConfig(inspect)
    local T = C_Traits
    if type(T) ~= "table" then return nil end
    if inspect then
        if T.HasValidInspectData and ns.Call(T.HasValidInspectData) ~= true then return nil end
        local consts = Constants and Constants.TraitConsts
        return consts and consts.INSPECT_TRAIT_CONFIG_ID or -1
    end
    local S = C_SpecializationInfo
    if type(S) == "table" and S.GetCombatConfigIDForSpecGroup then
        local group = S.GetActiveSpecGroup and ns.Call(S.GetActiveSpecGroup) or 1
        local id = ns.Call(S.GetCombatConfigIDForSpecGroup, type(group) == "number" and group or 1)
        if type(id) == "number" then return id end
    end
    if type(C_ClassTalents) == "table" and C_ClassTalents.GetActiveConfigID then
        local id = ns.Call(C_ClassTalents.GetActiveConfigID)
        if type(id) == "number" then return id end
    end
end

-- spell of a talent node (the chosen entry, else the first one)
local function nodeSpell(T, configID, node)
    local entryID = (type(node.activeEntry) == "table" and node.activeEntry.entryID)
        or (type(node.entryIDs) == "table" and node.entryIDs[1])
    local entry = entryID and T.GetEntryInfo and ns.Call(T.GetEntryInfo, configID, entryID)
    local def = type(entry) == "table" and entry.definitionID and T.GetDefinitionInfo and ns.Call(T.GetDefinitionInfo, entry.definitionID)
    return type(def) == "table" and (def.spellID or def.overriddenSpellID) or nil
end

-- grid positions: the distinct x/y values of a tree become columns/rows 1..n
local function gridOf(list)
    local xs, ys, xi, yi = {}, {}, {}, {}
    for _, n in ipairs(list) do
        if not xi[n.x] then xi[n.x] = true; xs[#xs + 1] = n.x end
        if not yi[n.y] then yi[n.y] = true; ys[#ys + 1] = n.y end
    end
    table.sort(xs); table.sort(ys)
    for i, v in ipairs(xs) do xi[v] = i end
    for i, v in ipairs(ys) do yi[v] = i end
    return xi, yi
end

-- points per tree, tree names and (withLayout) every talent as
-- "tree,row,col,rank,max,spell[,icon]" joined by ";"
local function readTraitTrees(inspect, configOverride, withLayout)
    local T = C_Traits
    if type(T) ~= "table" then return nil end
    local configID = configOverride or traitConfig(inspect)
    if not configID or not T.GetConfigInfo then return nil end
    local config = ns.Call(T.GetConfigInfo, configID)
    local treeID = type(config) == "table" and type(config.treeIDs) == "table" and config.treeIDs[1]
    if not treeID then return nil end
    local groups = T.GetGroupDisplayInfoByTreeID and ns.Call(T.GetGroupDisplayInfoByTreeID, treeID)
    if type(groups) ~= "table" or #groups == 0 then return nil end
    local list = {}
    for _, g in ipairs(groups) do
        if type(g) == "table" and g.groupID then list[#list + 1] = g end
    end
    table.sort(list, function(x, y) return (x.orderIndex or 0) < (y.orderIndex or 0) end)
    local index, points, names, nodes = {}, {}, {}, {}
    for i, g in ipairs(list) do
        index[g.groupID] = i
        points[i] = 0
        names[i] = tostring(g.displayName or g.name or "?")
        nodes[i] = {}
    end
    for _, nodeID in ipairs(T.GetTreeNodes and ns.Call(T.GetTreeNodes, treeID) or {}) do
        local node = ns.Call(T.GetNodeInfo, configID, nodeID)
        if type(node) == "table" then
            local gi
            for _, gid in ipairs(type(node.groupIDs) == "table" and node.groupIDs or {}) do gi = gi or index[gid] end
            local rank = node.activeRank or node.ranksPurchased or 0
            if gi and type(rank) == "number" then
                if rank > 0 then points[gi] = points[gi] + rank end
                if withLayout and type(node.posX) == "number" and type(node.posY) == "number" then
                    local t = nodes[gi]
                    t[#t + 1] = { x = math.floor(node.posX + 0.5), y = math.floor(node.posY + 0.5), rank = rank,
                        max = node.maxRanks or rank, spell = nodeSpell(T, configID, node) or 0 }
                end
            end
        end
    end
    local layout
    if withLayout then
        local out = {}
        for gi, t in ipairs(nodes) do
            local xi, yi = gridOf(t)
            for _, n in ipairs(t) do
                out[#out + 1] = ("%d,%d,%d,%d,%d,%d"):format(gi, yi[n.y], xi[n.x], n.rank, n.max, n.spell)
            end
        end
        layout = #out > 0 and table.concat(out, ";") or nil
    end
    return points, names, layout
end

local function classicTrees(inspect, withLayout)
    local tabs = ns.Call(GetNumTalentTabs, inspect)
    if type(tabs) ~= "number" or tabs == 0 then return nil end
    local points, names, out = {}, {}, {}
    for i = 1, tabs do
        local name, spent = tabInfo(i, inspect)
        points[i] = spent
        names[i] = name or "?"
        if withLayout and GetNumTalents and GetTalentInfo then
            local n = ns.Call(GetNumTalents, i, inspect)
            for j = 1, (type(n) == "number" and n or 0) do
                local _, icon, tier, column, rank, maxRank = ns.Call(GetTalentInfo, i, j, inspect)
                if type(tier) == "number" and type(column) == "number" then
                    out[#out + 1] = ("%d,%d,%d,%d,%d,0,%s"):format(i, tier, column, rank or 0, maxRank or 0,
                        type(icon) == "number" and icon or 0)
                end
            end
        end
    end
    return points, names, #out > 0 and table.concat(out, ";") or nil
end

function Profile.ReadTalents(inspect, withLayout)
    local points, names, layout = classicTrees(inspect, withLayout)
    if not points or not table.concat(points, ","):find("[1-9]") then
        local p2, n2, l2 = readTraitTrees(inspect, nil, withLayout)
        if p2 then points, names, layout = p2, n2, l2 end
    end
    if not points then return nil end
    local best, bestPoints = nil, 0
    for i, spent in ipairs(points) do
        names[i] = (names[i]:gsub(",", " "))
        if spent > bestPoints then best, bestPoints = names[i], spent end
    end
    return best, table.concat(points, "/"), table.concat(names, ","), bestPoints, layout
end

-- points of the other talent group (dual spec), "x/y/z" or nil
function Profile.ReadSecondSpec()
    local S = C_SpecializationInfo
    if type(S) ~= "table" or not S.GetCombatConfigIDForSpecGroup then return nil end
    local count = (S.GetNumSpecGroups and ns.Call(S.GetNumSpecGroups)) or (GetNumSpecGroups and ns.Call(GetNumSpecGroups)) or 1
    if type(count) ~= "number" or count < 2 then return nil end
    local active = S.GetActiveSpecGroup and ns.Call(S.GetActiveSpecGroup) or 1
    local other = ns.Call(S.GetCombatConfigIDForSpecGroup, active == 1 and 2 or 1)
    if type(other) ~= "number" then return nil end
    local points = readTraitTrees(false, other, false)
    return points and table.concat(points, "/") or nil
end
Profile.TraitConfig = traitConfig

local function readSpec()
    local spec, points = nil, nil
    if GetSpecialization and GetSpecializationInfo then
        local index = ns.Call(GetSpecialization)
        if type(index) == "number" and index > 0 then
            local _, name = ns.Call(GetSpecializationInfo, index)
            if type(name) == "string" then spec = name end
        end
    end
    local best, tp = Profile.ReadTalents(false)
    return spec or best, tp
end

-- Profession specialisations (spell IDs of the classic specialisations)
local SPECS = { 28672, 28677, 28675, 9788, 9787, 17040, 17039, 17041, 10656, 10658, 10660,
    20219, 20222, 26798, 26801, 26797 }
local SPEC_PROF = { [28672] = "alchemy", [28677] = "alchemy", [28675] = "alchemy", [9788] = "blacksmithing",
    [9787] = "blacksmithing", [17040] = "blacksmithing", [17039] = "blacksmithing", [17041] = "blacksmithing",
    [10656] = "leatherworking", [10658] = "leatherworking", [10660] = "leatherworking", [20219] = "engineering",
    [20222] = "engineering", [26798] = "tailoring", [26801] = "tailoring", [26797] = "tailoring" }

local function knows(id)
    if IsPlayerSpell and ns.Call(IsPlayerSpell, id) == true then return true end
    if IsSpellKnown and ns.Call(IsSpellKnown, id) == true then return true end
    return false
end

local function addSpecs(list)
    if not ns.Crafts then return list end
    for _, id in ipairs(SPECS) do
        if knows(id) then
            for _, p in ipairs(list) do
                if ns.Crafts.ProfKey(p.n) == SPEC_PROF[id] then p.x = Profile.RecipeName(id) end
            end
        end
    end
    return list
end

local function readProfessions()
    return addSpecs(Profile.ReadProfessionsRaw())
end

function Profile.ReadProfessionsRaw()
    local list = {}
    if GetProfessions and GetProfessionInfo then
        local slots = { ns.Call(GetProfessions) }
        for i = 1, 6 do
            local index = slots[i]
            if index then
                local name, _, rank, maxRank = ns.Call(GetProfessionInfo, index)
                if name and rank and not (ns.Crafts and ns.Crafts.NotProfession(name)) then
                    list[#list + 1] = { n = name, s = rank, m = maxRank }
                end
            end
        end
        if #list > 0 then return list end
    end
    local count = ns.Call(GetNumSkillLines)
    if type(count) == "number" then
        for i = 1, count do
            local name, header, _, rank, _, _, maxRank = ns.Call(GetSkillLineInfo, i)
            if name and not header and IS_PROFESSION[name] then
                list[#list + 1] = { n = name, s = rank, m = maxRank }
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Account: all characters of this account (SavedVariables are per account).
-- The main is the account's character in the home guild (highest level);
-- every other character – also in the partner guild – counts as its alt.
---------------------------------------------------------------------------
local Account = {}
ns.Account = Account

function Account.Settings()
    local st = ns.Database.Settings()
    if st.homeGuild == nil then st.homeGuild = "Liebe Grüße" end
    if st.autoAlts == nil then st.autoAlts = true end
    return st
end

function Account.Record()
    local char = ns.Database.Char()
    local name = Names.Unit("player")
    if name then char.name = name end
    local _, class = ns.Call(UnitClass, "player")
    char.c = class or char.c
    char.l = ns.Call(UnitLevel, "player") or char.l
    if IsInGuild() then
        local g = ns.Call(GetGuildInfo, "player")
        if type(g) == "string" and g ~= "" then char.guild = g end
    else
        char.guild = nil
    end
    char.seen = ns.Now()
end

local function sameGuild(a, b) return type(a) == "string" and type(b) == "string" and a:lower() == b:lower() end
Account.SameGuild = sameGuild

-- key of the account's main (manual choice first)
function Account.Main()
    local st = Account.Settings()
    if st.accountMain and st.accountMain ~= "" then return Names.Key(st.accountMain) end
    local best, bestChar
    for key, c in pairs(ns.db.chars or {}) do
        if key ~= "_" and sameGuild(c.guild, st.homeGuild) then
            if not bestChar or (c.l or 0) > (bestChar.l or 0)
                or ((c.l or 0) == (bestChar.l or 0) and (c.seen or 0) > (bestChar.seen or 0)) then
                best, bestChar = key, c
            end
        end
    end
    return best
end

-- the account's other characters: { { key, name, guild, c, l } }
function Account.Alts()
    local main = Account.Main()
    local list = {}
    for key, c in pairs(ns.db.chars or {}) do
        if key ~= "_" and key ~= main and c.name then
            list[#list + 1] = { key = key, name = c.name, guild = c.guild, c = c.c, l = c.l }
        end
    end
    table.sort(list, function(a, b) return (a.l or 0) > (b.l or 0) end)
    return list
end

-- packed for the profile: "name|guild|class|level;…"
local function packAlts()
    local parts = {}
    for i, a in ipairs(Account.Alts()) do
        if i > 15 then break end
        parts[#parts + 1] = table.concat({ a.name, a.guild or "", a.c or "", tostring(a.l or "") }, "|")
    end
    return #parts > 0 and table.concat(parts, ";") or nil
end

function Account.Unpack(text)
    local list = {}
    for entry in (text or ""):gmatch("[^;]+") do
        local name, guild, class, level = entry:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
        if name and name ~= "" then
            list[#list + 1] = { name = name, guild = guild ~= "" and guild or nil, c = class ~= "" and class or nil, l = tonumber(level) }
        end
    end
    return list
end

local function readTrees()
    local _, _, names = Profile.ReadTalents(false)
    return names
end

-- a few character sheet stats, rounded ("hit,crit,ap,spellpower,healing,spellcrit,spellhit")
local function num(fn, ...)
    if type(fn) ~= "function" then return 0 end
    local v = ns.Call(fn, ...)       -- secret values come back as nil
    return ns.Num(v) and v or 0
end
-- hit from gear "+x %" plus hit rating (Forever items can carry ratings)
local function hitWith(fn, rating, fallback)
    local id = type(rating) == "number" and rating or fallback
    return num(fn) + num(GetCombatRatingBonus, id)
end
local function readStats()
    local base, pos, neg = 0, 0, 0
    if UnitAttackPower then
        local b, p, n = ns.Call(UnitAttackPower, "player")
        base, pos, neg = ns.Num(b) and b or 0, ns.Num(p) and p or 0, ns.Num(n) and n or 0
    end
    local sp = 0
    for school = 2, 7 do sp = math.max(sp, num(GetSpellBonusDamage, school)) end
    local fmt = function(v) return (("%.1f"):format(v):gsub("%.0$", "")) end
    local rap = 0
    if UnitRangedAttackPower then
        local b, p, n = ns.Call(UnitRangedAttackPower, "player")
        rap = (ns.Num(b) and b or 0) + (ns.Num(p) and p or 0) + (ns.Num(n) and n or 0)
    end
    return table.concat({ fmt(hitWith(GetHitModifier, CR_HIT_MELEE, 6)), fmt(num(GetCritChance)), math.floor(base + pos + neg + 0.5),
        math.floor(sp + 0.5), math.floor(num(GetSpellBonusHealing) + 0.5), fmt(num(GetSpellCritChance, 2)),
        fmt(hitWith(GetSpellHitModifier, CR_HIT_SPELL, 8)), math.floor(rap + 0.5), fmt(num(GetRangedCritChance)),
        fmt(hitWith(GetRangedHitModifier, CR_HIT_RANGED, 7)) }, ",")
end
Profile.ReadStats = readStats

function Profile.Capture()
    local char = ns.Database.Char()
    Account.Record()
    -- automatic main: the account's character in the home guild
    local main = char.main and Names.Key(char.main)
    if not main and Account.Settings().autoAlts then
        local auto = Account.Main()
        if auto and not Names.Same(auto, Names.Me()) then main = auto end
    end
    local name = Names.Unit("player")
    if not name then return nil end
    local _, class = ns.Call(UnitClass, "player")
    local race, raceFile, raceId = ns.Call(UnitRace, "player")
    local gear = Profile.ReadGear("player")
    local spec, points = readSpec()
    local _, _, _, _, layout = Profile.ReadTalents(false, true)
    return {
        name = name, c = class, l = ns.Call(UnitLevel, "player"), r = race,
        il = Profile.AverageLevel(gear), sp = spec, tp = points, pr = readProfessions(),
        g = gear, m = main, v = ns.version,
        -- the main lists the account's alts (also those in other guilds)
        a = (not main and Account.Settings().autoAlts) and packAlts() or nil,
        at = ns.Attune and ns.Attune.ReadOwn() or nil,
        rf = raceFile, ri = type(raceId) == "number" and raceId or nil, sx = ns.Call(UnitSex, "player"), tn = readTrees(), st = readStats(),
        tk = layout, tp2 = Profile.ReadSecondSpec(),
        -- own achievements (speedruns, quests …) as tiers, e.g. "dv2,sp1"
        ac = ns.Achievements and ns.Achievements.Pack() or nil,
    }
end

-- Stable signature for change detection (ignores timestamps)
local function signature(p)
    local parts = {}
    for _, v in ipairs({ p.name, p.c, p.l, p.il, p.sp, p.tp, p.m, p.v, p.a, p.at, p.rf, p.ri, p.sx, p.tn, p.tk, p.tp2, p.ac }) do parts[#parts + 1] = tostring(v) end
    for _, slot in ipairs(Items.SLOTS) do parts[#parts + 1] = p.g[slot.id] or "" end
    -- shirt and tabard change the look in the armory model
    for _, slot in ipairs(Items.COSMETIC) do parts[#parts + 1] = p.g[slot.id] or "" end
    for _, prof in ipairs(p.pr) do parts[#parts + 1] = tostring(prof.n) .. tostring(prof.s) .. tostring(prof.x) end
    return table.concat(parts, ";")
end

local lastSignature, lastBroadcast = nil, 0

-- Stores our own profile and broadcasts it if it changed
local talentRetries = 0
function Profile.Update(force)
    local p = Profile.Capture()
    if not p then return end
    -- talent data can arrive after login: read again a little later
    if (not p.tp or not p.tp:find("[1-9]")) and (p.l or 0) >= 10 and talentRetries < 4 then
        talentRetries = talentRetries + 1
        ns.Debounce("profile-talent-retry", 15, function() Profile.Update(false) end)
    end
    local sig = signature(p)
    local me = Names.Me()
    local m = ns.Database.Member(me, true)
    local changed = sig ~= lastSignature
    for k, v in pairs(p) do m[k] = v end
    m.seen = ns.Now()
    m.stt = ns.Now()
    if changed then
        m.t = ns.Now()
        lastSignature = sig
        ns.Fire("LG_PROFILE", me)
    end
    if force or changed or (GetTime() - lastBroadcast > 1800) then
        Profile.Broadcast()
    end
end

function Profile.Broadcast()
    if not IsInGuild() then return end
    local me = Names.Me()
    local m = ns.Database.Member(me)
    if not m or not m.t then return end
    lastBroadcast = GetTime()
    Comm.Send("P", { d = Profile.Export(m), o = me }, "GUILD", { priority = "bulk" })
end

local EXPORT = { "name", "c", "l", "r", "il", "sp", "tp", "pr", "g", "m", "v", "t", "a", "at", "rf", "ri", "sx", "tn", "st", "stt", "tk", "tp2", "ac" }
function Profile.Export(m)
    local out = {}
    for _, field in ipairs(EXPORT) do out[field] = m[field] end
    return out
end

-- Accepts a profile for `owner` if it is newer than what we have
local function accept(owner, d, direct)
    if type(d) ~= "table" or type(d.t) ~= "number" then return end
    if not owner or Names.Same(owner, Names.Me()) then return end
    local m = ns.Database.Member(owner, true)
    if m.t and m.t >= d.t then
        if direct then m.seen = ns.Now() end
        -- the profile is the same, but the character sheet stats are newer
        -- (they are not part of the signature, so d.t does not change)
        if type(d.st) == "string" and type(d.stt) == "number" and d.stt > (m.stt or 0) then
            m.st, m.stt = d.st, d.stt
            ns.Debounce("profile-fire", 1, function() ns.Fire("LG_PROFILE") end)
        end
        return
    end
    for _, field in ipairs(EXPORT) do m[field] = d[field] end
    if type(m.g) ~= "table" then m.g = {} end
    if type(m.pr) ~= "table" then m.pr = {} end
    Profile.StripNonProfessions(m)
    if direct then m.seen = ns.Now() end
    ns.Debounce("profile-fire", 1, function() ns.Fire("LG_PROFILE") end)
end

---------------------------------------------------------------------------
-- Recipes
---------------------------------------------------------------------------
local function packIds(ids)
    table.sort(ids)
    return table.concat(ids, ",")
end

-- returns true when the list changed (nil: nothing stored)
local function storeRecipes(prof, ids)
    if not prof or #ids == 0 then return end
    if ns.Crafts and ns.Crafts.NotProfession(prof) then return end
    local me = Names.Me()
    local m = ns.Database.Member(me, true)
    m.rc = m.rc or {}
    m.rct = m.rct or {}
    local packed = packIds(ids)
    -- the same profession under another name (e.g. an old empty one) is replaced
    local key = ns.Crafts and ns.Crafts.ProfKey(prof)
    for name in pairs(m.rc) do
        if name ~= prof and key and ns.Crafts.ProfKey(name) == key then m.rc[name] = nil; m.rct[name] = nil end
    end
    if m.rc[prof] == packed then return false end
    m.rc[prof] = packed
    m.rct[prof] = ns.Now()
    ns.Debounce("recipes-send-" .. prof, 10, function()
        Comm.Send("RC", { o = me, p = prof, ids = m.rc[prof], t = m.rct[prof] }, "GUILD", { priority = "bulk" })
        if ns.Crafts then ns.Crafts.ShareOwn(prof, m.rc[prof]) end
    end)
    ns.Fire("LG_PROFILE", me)
    return true
end

-- tells the sync feedback (Modules/ProfSync.lua) what one scan found
local function scanned(prof, ids, changed)
    if prof and #ids > 0 and not (ns.Crafts and ns.Crafts.NotProfession(prof)) then ns.Fire("LG_PROF_SCANNED", prof, #ids, changed == true) end
end

local function scanModern()
    local T = C_TradeSkillUI
    if not (T and T.GetBaseProfessionInfo and T.GetAllRecipeIDs and T.GetRecipeInfo) then return false end
    if ns.Call(T.IsTradeSkillLinked) == true or ns.Call(T.IsTradeSkillGuild) == true then return true end
    local info = ns.Call(T.GetBaseProfessionInfo)
    local prof = type(info) == "table" and info.professionName
    local all = ns.Call(T.GetAllRecipeIDs)
    if not prof or type(all) ~= "table" then return true end
    local ids = {}
    for _, id in ipairs(all) do
        local recipe = ns.Call(T.GetRecipeInfo, id)
        if type(recipe) == "table" and recipe.learned then
            ids[#ids + 1] = id
            if ns.Professions then ns.Safe(ns.Professions.CaptureModern, id, prof, recipe.name) end
        end
    end
    scanned(prof, ids, storeRecipes(prof, ids))
    return true
end

-- Repair (1.0.49): older versions filed other professions' recipes under
-- enchanting when the client answered the craft functions for every window.
-- A recipe the same player also has in another profession is removed there.
function Profile.CleanEnchanting(m)
    if type(m) ~= "table" or type(m.rc) ~= "table" then return {} end
    local other = {}
    for name, ids in pairs(m.rc) do
        if type(ids) == "string" and ns.Crafts.ProfKey(name) ~= "enchanting" then
            for raw in ids:gmatch("%d+") do other[raw] = true end
        end
    end
    local changed = {}
    for name, ids in pairs(m.rc) do
        if type(ids) == "string" and ns.Crafts.ProfKey(name) == "enchanting" then
            local keep = {}
            for raw in ids:gmatch("%d+") do if not other[raw] then keep[#keep + 1] = tonumber(raw) end end
            table.sort(keep)
            local packed = table.concat(keep, ",")
            if packed ~= ids then m.rc[name] = packed; changed[#changed + 1] = name end
        end
    end
    return changed
end

-- Poisons (rogues) and pet training are no professions: older versions stored
-- them like one. Removes them from a profile's skills and recipe lists.
function Profile.StripNonProfessions(m)
    if type(m) ~= "table" or not ns.Crafts then return false end
    local stripped = false
    if type(m.pr) == "table" then
        for i = #m.pr, 1, -1 do
            local p = m.pr[i]
            if type(p) == "table" and ns.Crafts.NotProfession(p.n) then table.remove(m.pr, i); stripped = true end
        end
    end
    for _, field in ipairs({ "rc", "rct" }) do
        if type(m[field]) == "table" then
            for name in pairs(m[field]) do
                if ns.Crafts.NotProfession(name) then m[field][name] = nil; stripped = true end
            end
        end
    end
    return stripped
end

local function stripAllNonProfessions()
    local any = false
    for _, g in pairs(ns.db.guilds or {}) do
        for _, m in pairs(type(g) == "table" and g.members or {}) do
            if Profile.StripNonProfessions(m) then any = true end
        end
    end
    -- catalog entries filed under such a "profession"
    for _, e in pairs(ns.db.catalog or {}) do
        if type(e) == "table" and ns.Crafts.NotProfession(e.p) then e.p = nil; any = true end
    end
    if any then ns.Fire("LG_PROFILE") end
end
ns.On("LG_READY", function() ns.Safe(stripAllNonProfessions) end)

local function repairOwnRecipes()
    local me = Names.Me()
    local m = me and ns.Database.Member(me)
    if not m then return end
    for _, name in ipairs(Profile.CleanEnchanting(m)) do
        m.rct = m.rct or {}
        m.rct[name] = ns.Now()
        Comm.Send("RC", { o = me, p = name, ids = m.rc[name], t = m.rct[name] }, "GUILD", { priority = "bulk" })
    end
end
ns.On("LG_READY", function() ns.After(20, repairOwnRecipes) end)

local looksLikeEnchanting

local function spellFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("|Henchant:(%d+)") or link:match("|Hspell:(%d+)"))
end

local function scanClassic()
    if not GetNumTradeSkills then return end
    local prof = ns.Call(GetTradeSkillLine)
    local count = ns.Call(GetNumTradeSkills)
    if type(prof) ~= "string" or type(count) ~= "number" or count == 0 then return end
    local ids = {}
    for i = 1, count do
        local _, kind = ns.Call(GetTradeSkillInfo, i)
        if kind ~= "header" then
            local link = ns.Call(GetTradeSkillRecipeLink, i)
            local id = spellFromLink(link)
            if id then
                ids[#ids + 1] = id
                if ns.Crafts then ns.Crafts.RememberLink(id, link) end
                if ns.Professions then ns.Safe(ns.Professions.CaptureClassic, id, prof, i) end
            end
        end
    end
    scanned(prof, ids, storeRecipes(prof, ids))
end

-- trade skill window open (TRADE_SKILL_SHOW … TRADE_SKILL_CLOSE)
local tradeOpen = false

-- a craft list without a name is only taken as enchanting when it looks like it:
-- at least a third of the entries are "Enchant …" (every recipe link is an
-- "enchant:" link on these clients, so the link says nothing)
local ENCHANT_WORDS = { "^enchant", "^verzauber" }
looksLikeEnchanting = function(count)
    local hits, total = 0, 0
    for i = 1, count do
        local name, kind = ns.Call(GetCraftInfo, i)
        if type(name) == "string" and kind ~= "header" then
            total = total + 1
            local lower = name:lower()
            for _, w in ipairs(ENCHANT_WORDS) do if lower:find(w) then hits = hits + 1; break end end
        end
    end
    return total > 0 and hits * 3 >= total
end

local function scanCraft()
    if not GetNumCrafts then return end
    -- the craft window's name: some clients return an empty string here
    local prof
    for _, fn in ipairs({ GetCraftName, GetCraftDisplaySkillLine }) do
        local v = fn and ns.Call(fn)
        if type(v) == "string" and v:match("%S") then prof = v; break end
    end
    if not prof and GetCraftSkillLine then
        local v = ns.Call(GetCraftSkillLine, 1)
        if type(v) == "string" and v:match("%S") then prof = v end
    end
    local count = ns.Call(GetNumCrafts)
    if type(count) ~= "number" or count == 0 then return end
    -- some clients answer the craft functions for every profession window:
    -- while a trade skill is open, its own scan is the right one
    if tradeOpen and not prof then return end
    if not prof and looksLikeEnchanting(count) then prof = ns.Crafts.ProfName("enchanting") end
    -- hunters' pet training uses the same window: not a profession
    if not prof or not ns.Crafts.ProfKey(prof) then return end
    local ids = {}
    for i = 1, count do
        local link = ns.Call(GetCraftRecipeLink, i)
        local id = spellFromLink(link)
        if id then
            ids[#ids + 1] = id
            ns.Crafts.RememberLink(id, link)
            if ns.Crafts and GetCraftNumReagents then
                local reagents = {}
                for j = 1, (ns.Call(GetCraftNumReagents, i) or 0) do
                    local _, _, count = ns.Call(GetCraftReagentInfo, i, j)
                    local item = Items.ID(Items.String(ns.Call(GetCraftReagentItemLink, i, j)))
                    if item and type(count) == "number" then reagents[item] = (reagents[item] or 0) + count end
                end
                ns.Safe(ns.Crafts.Learn, id, prof, ns.Call(GetCraftInfo, i), nil, 1, reagents)
            end
        end
    end
    scanned(prof, ids, storeRecipes(prof, ids))
end

local function scanTradeSkill()
    if not scanModern() then scanClassic() end
end

function Profile.RecipeName(id)
    if C_Spell and C_Spell.GetSpellName then
        local name = ns.Call(C_Spell.GetSpellName, id)
        if name then return name end
    end
    return (ns.Call(GetSpellInfo, id))
end

---------------------------------------------------------------------------
-- Sync: index exchange so that newcomers get offline members' data
---------------------------------------------------------------------------
local function myIndex()
    local idx = {}
    for key, m in pairs(ns.Database.Guild().members) do
        if m.t then
            local entry = { m.t }
            if m.rct then
                for prof, t in pairs(m.rct) do entry[#entry + 1] = prof .. "=" .. t end
            end
            idx[key] = table.concat(entry, ";")
        end
    end
    return idx
end

local function parseIndex(text)
    local t, rest = text:match("^(%d+);?(.*)$")
    local recipes = {}
    for prof, rt in (rest or ""):gmatch("([^;=]+)=(%d+)") do recipes[prof] = tonumber(rt) end
    return tonumber(t), recipes
end

Comm.Register("P", function(data, sender, _, raw)
    if ns.Versions and type(data.d) == "table" and Names.Same(data.o or sender, sender) then
        ns.Versions.Heard(sender, data.d.v, raw)
    end
    accept(data.o or sender, data.d, Names.Same(data.o or sender, sender))
end)

Comm.Register("RC", function(data, sender, _, raw)
    local owner = data.o or sender
    if not owner or Names.Same(owner, Names.Me()) or type(data.p) ~= "string" or type(data.ids) ~= "string" then return end
    if ns.Crafts and ns.Crafts.NotProfession(data.p) then return end
    local m = ns.Database.Member(owner, true)
    m.rc, m.rct = m.rc or {}, m.rct or {}
    if (m.rct[data.p] or 0) >= (data.t or 0) then return end
    m.rc[data.p], m.rct[data.p] = data.ids, data.t
    if ns.Crafts and raw then ns.Crafts.Missing(data.ids, raw) end
    ns.Debounce("profile-fire", 1, function() ns.Fire("LG_PROFILE") end)
end)

-- A newcomer asks for the index; one member answers.
Comm.Register("IX", function(_, sender, _, raw)
    if not IsInGuild() then return end
    Comm.ReplyOnce("index:" .. sender, 2, 9, function()
        Comm.Send("IA", { to = sender }, "GUILD", { priority = "alert" })
        Comm.Send("IR", { idx = myIndex() }, "WHISPER", { target = raw, priority = "bulk" })
    end)
end)

Comm.Register("IA", function(data)
    if data.to then Comm.Answered("index:" .. data.to) end
end)

-- Index received: ask the sender for everything newer than ours
Comm.Register("IR", function(data, sender, _, raw)
    if type(data.idx) ~= "table" then return end
    local wanted = {}
    local members = ns.Database.Guild().members
    for key, text in pairs(data.idx) do
        if type(text) == "string" and not Names.Same(key, Names.Me()) then
            local t, recipes = parseIndex(text)
            local m = members[key]
            local want = (t and (not m or not m.t or m.t < t))
            for prof, rt in pairs(recipes) do
                if not m or not m.rct or (m.rct[prof] or 0) < rt then want = true end
            end
            if want then wanted[#wanted + 1] = key end
        end
    end
    if #wanted > 0 then
        Comm.Send("PQ", { keys = wanted }, "WHISPER", { target = raw, priority = "normal" })
    end
end)

Comm.Register("PQ", function(data, _, _, raw)
    if type(data.keys) ~= "table" then return end
    local members = ns.Database.Guild().members
    for i, key in ipairs(data.keys) do
        if i > 300 then break end
        local m = members[key]
        if m and m.t then
            Comm.Send("P", { d = Profile.Export(m), o = key }, "WHISPER", { target = raw, priority = "bulk" })
            for prof, ids in pairs(m.rc or {}) do
                Comm.Send("RC", { o = key, p = prof, ids = ids, t = m.rct and m.rct[prof] or 0 }, "WHISPER",
                    { target = raw, priority = "bulk" })
            end
        end
    end
end)

-- Hello: someone came online. Re-send our profile if we did not do so lately.
Comm.Register("H", function(data, sender, _, raw)
    if ns.Versions then ns.Versions.Heard(sender, data.v, raw) end
    if GetTime() - lastBroadcast > 600 then
        Comm.ReplyOnce("hello-profile", 5, 40, function()
            if GetTime() - lastBroadcast > 600 then Profile.Broadcast() end
        end)
    end
end)


---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function Profile:OnLogin()
    ns.After(8, function() Profile.Update(false) end)
    ns.After(12, function()
        if IsInGuild() then
            Comm.Send("H", { v = ns.version }, "GUILD", { priority = "normal" })
        end
    end)
    ns.After(30, function()
        if IsInGuild() then Comm.Send("IX", {}, "GUILD", { priority = "bulk" }) end
    end)
end

local function soon() ns.Debounce("profile-update", 5, function() ns.AfterCombat("profile-update", function() Profile.Update(false) end) end) end
ns.On("PLAYER_EQUIPMENT_CHANGED", soon)
ns.On("PLAYER_LEVEL_UP", soon)
ns.On("SKILL_LINES_CHANGED", soon)
ns.On("CHARACTER_POINTS_CHANGED", soon)
ns.On("PLAYER_TALENT_UPDATE", soon)
ns.On("TRAIT_CONFIG_UPDATED", soon)
ns.On("TRAIT_CONFIG_LIST_UPDATED", soon)          -- talent data ready after login
ns.On("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", soon)
ns.On("GET_ITEM_INFO_RECEIVED", function()
    ns.Debounce("item-info", 1, function() ns.Fire("LG_ITEMS") end)
end)
ns.On("TRADE_SKILL_SHOW", function() tradeOpen = true; ns.After(1, scanTradeSkill) end)
ns.On("TRADE_SKILL_CLOSE", function() tradeOpen = false end)
ns.On("TRADE_SKILL_LIST_UPDATE", function() ns.Debounce("trade-scan", 2, scanTradeSkill) end)
ns.On("TRADE_SKILL_UPDATE", function() ns.Debounce("trade-scan", 2, scanTradeSkill) end)
ns.On("CRAFT_SHOW", function() ns.After(1, scanCraft) end)
ns.On("CRAFT_UPDATE", function() ns.Debounce("craft-scan", 2, scanCraft) end)
