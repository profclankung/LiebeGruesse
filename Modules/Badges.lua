-- Achievements in three categories (dungeon, open world, raid), each with up
-- to eight tiers shown as badges: bronze, silver, gold, platinum, emerald,
-- diamond, master and challenger (reachable, but hard).
--   src "guild": computed by every client from shared data (community events,
--                pin board, guild feed) – known for every member
--   src "own":   from this character's own data (speedruns, boss stats,
--                quests …) – others see it through the profile (field "ac")
-- fun = true: the light-hearted ones (raid night, everyday life).
-- Unlock dates per character in char.achievements; a new tier pops up as a
-- notification (Modules/Achievements.lua has the page).
local _, ns = ...
local UI, Theme, L, Names = ns.UI, ns.Theme, ns.L, ns.Names
local Badges = {}
ns.Badges = Badges

local TIER_COLORS = { "tier1", "tier2", "tier3", "tier4", "tier5", "tier6", "tier7", "tier8" }
Badges.TIER_COLORS = TIER_COLORS
Badges.MAX_TIER = #TIER_COLORS
Badges.CATEGORIES = { "dungeon", "world", "raid" }

-- id: stable (stored); short: code in the profile; stat: key of the stats;
-- tiers: what each tier needs (bronze … challenger; fewer when the stat has a natural end)
Badges.LIST = {
    -- dungeon
    { id = "delver", short = "dv", cat = "dungeon", src = "own", icon = "castle", stat = "runs", tiers = { 10, 50, 100, 200, 350, 500, 750, 1000 } },
    { id = "speed", short = "sp", cat = "dungeon", src = "own", icon = "timer", stat = "pb", tiers = { 1, 5, 10, 25, 50, 75, 100, 150 } },
    { id = "record", short = "rh", cat = "dungeon", src = "own", icon = "trophy", stat = "records", tiers = { 1, 2, 3, 5, 8, 12, 16, 20 } },
    { id = "flawless", short = "fl", cat = "dungeon", src = "own", icon = "shield", stat = "flawless", tiers = { 5, 25, 50, 100, 175, 250, 400, 600 } },
    { id = "master", short = "ms", cat = "dungeon", src = "own", icon = "map-pin", stat = "wings", tiers = { 5, 10, 15, 20, 25, 30, 33, 35 } },
    { id = "firsttryd", short = "fd", cat = "dungeon", src = "own", icon = "zap", stat = "firstTryDungeon", tiers = { 25, 100, 200, 400, 700, 1000, 1500, 2500 } },
    { id = "allguild", short = "ag", cat = "dungeon", src = "own", icon = "users", stat = "allGuild", tiers = { 10, 25, 50, 100, 175, 250, 400, 600 } },
    { id = "interrupter", cat = "dungeon", src = "guild", icon = "swords", stat = "kick", tiers = { 25, 100, 250, 500, 1000, 2000, 3500, 5000 } },
    -- open world
    { id = "adventurer", short = "ad", cat = "world", src = "own", icon = "scroll-text", stat = "quests", tiers = { 100, 300, 600, 1000, 1500, 2000, 3000, 4000 } },
    { id = "explorer", short = "ex", cat = "world", src = "own", icon = "compass", stat = "zones", tiers = { 10, 15, 20, 25, 30, 35, 40, 45 } },
    { id = "rarehunter", short = "rr", cat = "world", src = "own", icon = "star", stat = "rares", tiers = { 5, 10, 20, 35, 50, 75, 100, 150 } },
    { id = "crafter", short = "cr", cat = "world", src = "own", icon = "hammer", stat = "profPoints", tiers = { 150, 300, 450, 600, 750, 900, 1200, 1500 } },
    { id = "flyer", cat = "world", src = "guild", icon = "arrow-left-right", stat = "taxi", tiers = { 25, 75, 150, 300, 500, 750, 1000, 1500 } },
    { id = "loyal", cat = "world", src = "guild", icon = "badge-check", stat = "streak", tiers = { 3, 7, 14, 30, 60, 100, 180, 365 } },
    { id = "welcome", cat = "world", src = "guild", fun = true, icon = "message-circle", stat = "greet1", tiers = { 3, 10, 25, 50, 100, 175, 250, 400 } },
    { id = "crowd", cat = "world", src = "guild", fun = true, icon = "star", stat = "likes", tiers = { 5, 15, 30, 50, 100, 175, 250, 400 } },
    { id = "quotable", cat = "world", src = "guild", fun = true, icon = "newspaper", stat = "qotw", tiers = { 1, 2, 3, 5, 8, 12, 16, 25 } },
    { id = "pepegaw", cat = "world", src = "guild", fun = true, icon = "skull", stat = "wdeath", tiers = { 10, 25, 50, 100, 175, 250, 400, 600 } },
    { id = "gravity", cat = "world", src = "guild", fun = true, icon = "move", stat = "wfall", tiers = { 3, 10, 20, 35, 50, 75, 100, 150 } },
    { id = "ghost", cat = "world", src = "guild", fun = true, icon = "skull", stat = "ghostMin", tiers = { 60, 180, 300, 600, 1000, 1500, 2500, 4000 }, unit = " min" },
    { id = "homesick", cat = "world", src = "guild", fun = true, icon = "rotate-ccw", stat = "hearth", tiers = { 25, 75, 150, 300, 500, 750, 1000, 1500 } },
    { id = "postman", cat = "world", src = "guild", fun = true, icon = "scroll-text", stat = "mail", tiers = { 25, 75, 150, 300, 500, 750, 1000, 1500 } },
    { id = "junk", cat = "world", src = "guild", fun = true, icon = "scale", stat = "junkGold", tiers = { 50, 150, 300, 600, 1000, 1500, 2500, 4000 }, unit = "g" },
    { id = "shopaholic", cat = "world", src = "guild", fun = true, icon = "gem", stat = "shopGold", tiers = { 100, 300, 600, 1000, 2000, 3500, 5000, 8000 }, unit = "g" },
    { id = "moneypit", cat = "world", src = "guild", fun = true, icon = "hammer", stat = "repairGold", tiers = { 100, 300, 600, 1000, 2000, 3500, 5000, 8000 }, unit = "g" },
    { id = "marathon", cat = "world", src = "guild", fun = true, icon = "timer", stat = "sessionHours", tiers = { 4, 6, 8, 10, 12, 14, 16, 20 }, unit = "h" },
    { id = "owl", cat = "world", src = "guild", fun = true, icon = "star", stat = "owl", tiers = { 3, 7, 15, 30, 50, 75, 100, 150 } },
    { id = "early", cat = "world", src = "guild", fun = true, icon = "star-filled", stat = "early", tiers = { 3, 7, 15, 30, 50, 75, 100, 150 } },
    -- raid (real raid instances only, no ten-player dungeons)
    { id = "slayer", cat = "raid", src = "guild", icon = "crown", stat = "kills", tiers = { 10, 50, 100, 200, 350, 500, 750, 1000 } },
    { id = "raider", cat = "raid", src = "guild", icon = "shield", stat = "nights", tiers = { 5, 15, 30, 50, 75, 100, 150, 200 } },
    { id = "firsttryr", short = "fr", cat = "raid", src = "own", icon = "zap", stat = "firstTryRaid", tiers = { 5, 15, 30, 50, 75, 100, 150, 250 } },
    { id = "deathless", short = "dl", cat = "raid", src = "own", icon = "shield", stat = "deathless", tiers = { 5, 15, 30, 50, 75, 100, 150, 250 } },
    { id = "fullclear", short = "fc", cat = "raid", src = "own", icon = "castle", stat = "clears", tiers = { 1, 3, 5, 10, 20, 30, 50, 75 } },
    { id = "attuned", short = "at", cat = "raid", src = "own", icon = "badge-check", stat = "attuned", tiers = { 1, 2, 3, 4 } },
    { id = "nevergiveup", short = "ng", cat = "raid", src = "own", icon = "swords", stat = "raidWipes", tiers = { 10, 25, 50, 100, 150, 250, 400, 600 } },
    { id = "lucky", cat = "raid", src = "guild", icon = "gem", stat = "epics", tiers = { 5, 10, 20, 35, 50, 75, 100, 150 } },
    { id = "failpull", cat = "raid", src = "guild", fun = true, icon = "swords", stat = "failpull", tiers = { 3, 10, 20, 35, 50, 75, 100, 150 } },
    { id = "oops", cat = "raid", src = "guild", fun = true, icon = "move", stat = "mispull", tiers = { 3, 10, 20, 35, 50, 75, 100, 150 } },
    { id = "pepega", cat = "raid", src = "guild", fun = true, icon = "skull", stat = "death", tiers = { 5, 15, 30, 50, 75, 100, 150, 250 } },
    { id = "canary", cat = "raid", src = "guild", fun = true, icon = "skull", stat = "first2die", tiers = { 3, 10, 25, 50, 75, 100, 150, 250 } },
    { id = "laststand", cat = "raid", src = "guild", fun = true, icon = "shield", stat = "laststand", tiers = { 1, 5, 10, 20, 35, 50, 75, 100 } },
    { id = "coffee", cat = "raid", src = "guild", fun = true, icon = "timer", stat = "afk", tiers = { 5, 15, 30, 50, 75, 100, 150, 250 } },
    { id = "kangaroo", cat = "raid", src = "guild", fun = true, icon = "sparkles", stat = "jumpNight", tiers = { 50, 100, 150, 200, 300, 400, 600, 1000 } },
    { id = "chatterbox", cat = "raid", src = "guild", fun = true, icon = "message-circle", stat = "chat", tiers = { 200, 500, 1000, 2500, 5000, 10000, 20000, 35000 } },
    { id = "jackpot", cat = "raid", src = "guild", fun = true, icon = "star", stat = "r100", tiers = { 1, 2, 3, 5, 8, 12, 16, 25 } },
    { id = "snakeeyes", cat = "raid", src = "guild", fun = true, icon = "x", stat = "r1", tiers = { 1, 2, 3, 5, 8, 12, 16, 25 } },
    { id = "notready", cat = "raid", src = "guild", fun = true, icon = "timer", stat = "nr", tiers = { 3, 10, 20, 35, 50, 75, 100, 150 } },
    { id = "chugger", cat = "raid", src = "guild", fun = true, icon = "zap", stat = "chug", tiers = { 25, 75, 150, 300, 500, 750, 1000, 1500 } },
    { id = "badluck", cat = "raid", src = "guild", fun = true, icon = "scale", stat = "badluck", tiers = { 2, 3, 4, 6, 8, 10, 13, 16 } },
}
Badges.BY_ID, Badges.BY_SHORT = {}, {}
for _, d in ipairs(Badges.LIST) do
    Badges.BY_ID[d.id] = d
    if d.short then Badges.BY_SHORT[d.short] = d end
end

---------------------------------------------------------------------------
-- Shared stats per member (all time), cached until community data changes
---------------------------------------------------------------------------
local cache
local function inc(t, key, stat, n)
    if not key then return end
    local s = t[key]
    if not s then s = {}; t[key] = s end
    s[stat] = (s[stat] or 0) + (n or 1)
end
local function max(t, key, stat, n)
    if not key then return end
    local s = t[key]
    if not s then s = {}; t[key] = s end
    if n > (s[stat] or 0) then s[stat] = n end
end

local COUNTED = { failpull = true, mispull = true, death = true, fall = true, afk = true, greet1 = true, first2die = true, laststand = true }
function Badges.Stats()
    if cache then return cache end
    local t = {}
    local C = ns.Community
    local events = C and C.Store().events or {}
    if C and C.testEvents then
        local merged = {}
        for _, e in ipairs(events) do merged[#merged + 1] = e end
        for _, e in ipairs(C.testEvents) do merged[#merged + 1] = e end
        events = merged
    end
    for _, e in ipairs(events) do
        local d = type(e.d) == "table" and e.d or {}
        local k = C.Counts(e) and e.k or nil
        if COUNTED[k] then inc(t, e.who, k)
        elseif k == "repair" then inc(t, e.who, "repair", tonumber(d.c) or 0)
        elseif k == "session" then max(t, e.who, "session", tonumber(d.s) or 0)
        elseif k == "jump" then max(t, e.who, "jumpNight", tonumber(d.n) or 0)
        elseif k == "chug" then inc(t, e.who, "chug", tonumber(d.n) or 0)
        elseif k == "wdeath" then inc(t, e.who, "wdeath", tonumber(d.n) or 0); inc(t, e.who, "wfall", tonumber(d.e) or 0)
        elseif k == "rnight" then
            for _, f in ipairs({ "chat", "nr", "r1", "r100" }) do inc(t, e.who, f, tonumber(d[f]) or 0) end
        elseif k == "raidday" then inc(t, e.who, "nights"); inc(t, e.who, "kills", 3)
        elseif k == "epic" then inc(t, e.who, "epics")
        end
    end
    -- pin board: likes received, quotes of the week won
    local posts = C and C.Store().posts or {}
    local weeks = {}
    for _, p in ipairs(posts) do
        local n = 0
        for _ in pairs(p.likes or {}) do n = n + 1 end
        if n > 0 then inc(t, p.a, "likes", n) end
        if C then weeks[C.Week(p.t)] = true end
    end
    if C then
        local current = C.Week()
        for w in pairs(weeks) do
            if w < current then
                local best = C.QuoteOfWeek(w)
                if best then inc(t, best.a, "qotw") end
            end
        end
    end
    -- guild feed: raid boss kills, raid nights, epics in instances
    local nights = {}
    for _, e in ipairs(ns.Database.Guild().feed or {}) do
        local d = type(e) == "table" and type(e.d) == "table" and e.d
        if d then
            if e.k == "boss" and d.r == 2 and type(d.g) == "table" then
                local day = date("%Y%m%d", e.t or 0)
                for _, key in ipairs(d.g) do
                    inc(t, key, "kills")
                    nights[key] = nights[key] or {}
                    if not nights[key][day] then nights[key][day] = true; inc(t, key, "nights") end
                end
            elseif e.k == "loot" and (d.q or 0) >= 4 and d.r == 2 then
                inc(t, e.a, "epics")
            end
        end
    end
    -- daily counters (all time) and the longest raid-night streak without an epic
    if C then
        for who, d in pairs(C.DailyTotals(0, events)) do
            for k, v in pairs(d) do
                if k == "streak" then max(t, who, k, v) else inc(t, who, k, v) end
            end
        end
        for who, n in pairs(C.BadLuck(0)) do max(t, who, "badluck", n) end
    end
    for _, s in pairs(t) do
        s.ghostMin = math.floor((s.ghost or 0) / 60)
        s.junkGold = math.floor((s.junk or 0) / 10000)
        s.shopGold = math.floor((s.shop or 0) / 10000)
        s.repairGold = math.floor((s.repair or 0) / 10000)
        s.sessionHours = math.floor((s.session or 0) / 3600)
    end
    cache = t
    return t
end

local ownCache = {}
local function invalidate() cache = nil; wipe(ownCache) end
Badges.Invalidate = invalidate
ns.On("LG_COMMUNITY", invalidate)
ns.On("LG_PROFILE", invalidate)
ns.On("LG_RUNS", function() wipe(ownCache) end)

---------------------------------------------------------------------------
-- Own stats (this character, or every character of the account)
---------------------------------------------------------------------------
function Badges.AchStats(char)
    char = char or ns.Database.Char()
    char.achStats = char.achStats or {}
    return char.achStats
end

local function ownOf(charKey, char, out)
    local a = Badges.AchStats(char)
    for _, k in ipairs({ "pb", "firstTryDungeon", "firstTryRaid", "deathless" }) do out[k] = (out[k] or 0) + (a[k] or 0) end
    local zones = 0
    for _ in pairs(type(a.zones) == "table" and a.zones or {}) do zones = zones + 1 end
    out.zones = math.max(out.zones or 0, zones)
    local rares = 0
    for _ in pairs(type(a.rares) == "table" and a.rares or {}) do rares = rares + 1 end
    out.rares = (out.rares or 0) + rares
    -- speedruns
    local wings = out._wings or {}
    out._wings = wings
    for _, r in ipairs(type(char.runs) == "table" and char.runs.history or {}) do
        if r.ok and r.w then
            local kind = ns.RunsData and ns.RunsData.BY_KEY[r.w] and ns.RunsData.BY_KEY[r.w].kind
            if kind == "raid" then
                out.clears = (out.clears or 0) + 1
            else
                out.runs = (out.runs or 0) + 1
                wings[r.w] = true
                if (r.d or 0) == 0 then out.flawless = (out.flawless or 0) + 1 end
                local all = #(r.g or {}) > 0
                for _, m in ipairs(r.g or {}) do
                    if not (ns.Guild.IsMember(m.k) or Names.Same(m.k, charKey)) then all = false end
                end
                if all and #(r.g or {}) >= 3 then out.allGuild = (out.allGuild or 0) + 1 end
            end
        end
    end
    -- boss stats, quests
    local st = type(char.stats) == "table" and char.stats or {}
    out.quests = (out.quests or 0) + (tonumber(st.quests) or 0)
    for _, b in pairs(type(st.bosses) == "table" and st.bosses or {}) do
        if b.kind == "raid" then out.raidWipes = (out.raidWipes or 0) + (b.w or 0) end
    end
    -- professions at max and raid attunements (own profile)
    local m = ns.Database.Member(charKey)
    local points = 0
    for _, p in ipairs(m and type(m.pr) == "table" and m.pr or {}) do
        points = points + math.max(0, math.min(300, tonumber(p.s) or 0))
    end
    out.profPoints = math.max(out.profPoints or 0, points)
    local att = 0
    local done = m and ns.Attune and ns.Attune.Parse(m.at) or {}
    for _, e in ipairs(ns.Attune and ns.Attune.LIST or {}) do if e.kind == "attune" and done[e.key] then att = att + 1 end end
    out.attuned = math.max(out.attuned or 0, att)
end

-- guild records held: wings where the guild's best run has this character in the group
local function recordsHeld(keys)
    local n = 0
    if not ns.Runs or not ns.RunsData then return 0 end
    for _, d in ipairs(ns.RunsData.LIST) do
        local best = ns.Runs.Best(d.key, "guild")
        if best then
            for _, m in ipairs(best.g or {}) do if keys[m.k] then n = n + 1; break end end
        end
    end
    return n
end

-- the own characters (keys) for a scope ("char" or "account")
local function ownKeys(scope)
    local keys = {}
    if scope == "account" then
        for key in pairs(ns.db.chars or {}) do if key ~= "_" then keys[key] = true end end
    end
    keys[Names.Me()] = true
    return keys
end

function Badges.OwnStats(scope)
    scope = scope or "char"
    if ownCache[scope] then return ownCache[scope] end
    local out = {}
    for key in pairs(ownKeys(scope)) do
        local char = ns.db.chars[key]
        if char then ownOf(key, char, out) end
    end
    local wings = 0
    for _ in pairs(out._wings or {}) do wings = wings + 1 end
    out.wings, out._wings = wings, nil
    out.records = recordsHeld(ownKeys(scope))
    -- shared stats of the own characters
    local shared = Badges.Stats()
    for key in pairs(ownKeys(scope)) do
        for k, v in pairs(shared[key] or {}) do
            if k == "streak" or k == "jumpNight" or k == "session" or k == "badluck" or k == "sessionHours" then
                out[k] = math.max(out[k] or 0, v)
            else
                out[k] = (out[k] or 0) + v
            end
        end
    end
    ownCache[scope] = out
    return out
end

---------------------------------------------------------------------------
-- Tiers
---------------------------------------------------------------------------
function Badges.Tier(def, stats)
    local v = stats and stats[def.stat] or 0
    local tier = 0
    for i, need in ipairs(def.tiers) do if v >= need then tier = i end end
    return tier, v
end
-- the highest tier of an achievement (most have eight)
function Badges.Top(def) return #def.tiers end
function Badges.TierName(i) return L["BADGE_TIER" .. i] or tostring(i) end
function Badges.TierColor(i) return TIER_COLORS[i] or "muted" end

-- own achievements as "dv2,sp1,…" (profile field ac; only "own" ones with a tier)
function Badges.Pack()
    local stats = Badges.OwnStats("char")
    local parts = {}
    for _, def in ipairs(Badges.LIST) do
        if def.short then
            local tier = Badges.Tier(def, stats)
            if tier > 0 then parts[#parts + 1] = def.short .. tier end
        end
    end
    return #parts > 0 and table.concat(parts, ",") or nil
end
function Badges.Unpack(text)
    local out = {}
    if type(text) ~= "string" or #text > 200 then return out end
    for short, tier in text:gmatch("(%a%a)([1-8])") do
        local def = Badges.BY_SHORT[short]
        if def then out[def.id] = math.min(#def.tiers, tonumber(tier)) end
    end
    return out
end

-- every achievement of a member: { { def, tier, value } } (own data for yourself,
-- shared data and the profile's ac for others)
function Badges.Of(key, scope)
    local mine = Names.Same(key, Names.Me())
    local stats, packed
    if mine then
        stats = Badges.OwnStats(scope or "char")
    else
        for k, s in pairs(Badges.Stats()) do if Names.Same(k, key) then stats = s; break end end
        local m = ns.Database.Member(key)
        packed = Badges.Unpack(m and m.ac)
    end
    local list = {}
    for _, def in ipairs(Badges.LIST) do
        local tier, v = Badges.Tier(def, stats)
        if not mine and def.src == "own" then tier, v = packed[def.id] or 0, nil end
        list[#list + 1] = { def = def, tier = tier, value = v }
    end
    return list
end

local function valueText(def, v) return tostring(v) .. (def.unit or "") end
Badges.ValueText = valueText

function Badges.Name(def) return L["BADGE_" .. def.id:upper()] or def.id end
function Badges.Desc(def) return L["BADGE_" .. def.id:upper() .. "_TIP"] or "" end

-- tooltip lines for one achievement (with progress)
function Badges.TipLines(def, tier, v)
    local lines = { Badges.Desc(def), " " }
    for i, need in ipairs(def.tiers) do
        local got = tier >= i
        lines[#lines + 1] = Theme.HexColor(got and TIER_COLORS[i] or "muted",
            Badges.TierName(i) .. ": " .. valueText(def, need)) .. (got and ("  " .. UI.Glyph("badge-check", TIER_COLORS[i], 11)) or "")
    end
    if tier < #def.tiers and v then lines[#lines + 1] = Theme.HexColor("muted", L.BADGE_NOW:format(valueText(def, v))) end
    local u = Badges.Unlocked(def.id)
    if u and u.t then
        for i = #def.tiers, 1, -1 do
            if u.t[i] then lines[#lines + 1] = Theme.HexColor("muted", L.ACH_UNLOCKED_TIER:format(Badges.TierName(i), u.t[i] > 0 and ns.Date(u.t[i]) or L.ACH_EARLIER)); break end
        end
    end
    return lines
end

---------------------------------------------------------------------------
-- Armory card: earned badges as icons in tier colours (hover for details)
---------------------------------------------------------------------------
local ICON = 30
function Badges.FillCard(c, key, width, cat)
    c.icons = c.icons or {}
    local earned = {}
    local fun = Badges.Settings().fun
    for _, b in ipairs(Badges.Of(key)) do
        if b.tier > 0 and (not cat or b.def.cat == cat) and (fun or not b.def.fun) then earned[#earned + 1] = b end
    end
    table.sort(earned, function(a, b) if a.tier ~= b.tier then return a.tier > b.tier end return a.def.id < b.def.id end)
    local perRow = math.max(1, math.floor((width - 24 + 8) / (ICON + 8)))
    for i, b in ipairs(earned) do
        local f = c.icons[i]
        if not f then
            f = CreateFrame("Frame", nil, c, "BackdropTemplate")
            f:SetSize(ICON, ICON)
            UI.Skin(f, "input", "bronze")
            f.icon = UI.Icon(f, "star", 16, "bronze")
            f.icon:SetPoint("CENTER")
            f:EnableMouse(true)
            f:SetScript("OnEnter", function(self)
                UI.Tooltip(self, Badges.Name(self.b.def) .. "  " .. Theme.HexColor(TIER_COLORS[self.b.tier], Badges.TierName(self.b.tier)),
                    Badges.TipLines(self.b.def, self.b.tier, self.b.value))
            end)
            f:SetScript("OnLeave", function() GameTooltip:Hide() end)
            c.icons[i] = f
        end
        f.b = b
        Theme.SetIcon(f.icon, b.def.icon)
        f.icon:SetVertexColor(Theme.Color(TIER_COLORS[b.tier]))
        f:SetBackdropBorderColor(Theme.Color(TIER_COLORS[b.tier]))
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", 12 + ((i - 1) % perRow) * (ICON + 8), -38 - math.floor((i - 1) / perRow) * (ICON + 8))
        f:Show()
    end
    for i = #earned + 1, #c.icons do c.icons[i]:Hide() end
    c.right:SetText(#earned > 0 and ("%d/%d"):format(#earned, #Badges.LIST) or "")
    c.empty = c.empty or UI.Text(c, 12, "muted")
    c.empty:ClearAllPoints()
    c.empty:SetPoint("TOPLEFT", 12, -38)
    c.empty:SetText(#earned == 0 and L.BADGE_NONE or "")
    local rows = #earned > 0 and math.ceil(#earned / perRow) or 0
    local h = 38 + (rows > 0 and rows * (ICON + 8) or 22) + 8
    c:SetHeight(h)
    return h
end

---------------------------------------------------------------------------
-- Unlock dates and the notification for a new tier. The first run only
-- remembers what you already have (date unknown = 0).
---------------------------------------------------------------------------
function Badges.Settings()
    local s = ns.Database.Settings()
    s.achievements = s.achievements or {}
    local a = s.achievements
    if a.toast == nil then a.toast = true end
    if a.sound == nil then a.sound = true end
    if a.fun == nil then a.fun = true end
    if a.share == nil then a.share = true end
    return a
end

function Badges.Unlocked(id)
    local u = ns.Database.Char().achievements
    return u and u[id]
end

function Badges.Check(quiet)
    if ns.Database.Settings().modules.achievements == false then return end
    local char = ns.Database.Char()
    local first = char.achievements == nil
    char.achievements = char.achievements or {}
    local u = char.achievements
    -- from the old badge list (1.0.89): tiers without a date
    if first and type(char.badges) == "table" then
        for id, tier in pairs(char.badges) do
            if Badges.BY_ID[id] and tonumber(tier) and tier > 0 then
                u[id] = { tier = tier, t = {} }
                for i = 1, tier do u[id].t[i] = 0 end
            end
        end
        first = false
    end
    char.badges = nil
    local o = Badges.Settings()
    for _, b in ipairs(Badges.Of(Names.Me())) do
        local seen = u[b.def.id] or { tier = 0, t = {} }
        if b.tier > (seen.tier or 0) then
            for i = (seen.tier or 0) + 1, b.tier do seen.t[i] = first and 0 or ns.Now() end
            if not first and not quiet and o.toast and (o.fun or not b.def.fun) then
                local kicker = L.ACH_NEW
                UI.Toast(kicker, Badges.Name(b.def) .. "  " .. Theme.HexColor(TIER_COLORS[b.tier], Badges.TierName(b.tier)), nil,
                    { kicker = kicker, lines = { Badges.Desc(b.def) }, page = "achievements",
                      action = function() ns.Window.Show("achievements") end, actionText = L.ACH_CLICK })
                if o.sound then ns.Sound("milestone") end
            end
            seen.tier = b.tier
            u[b.def.id] = seen
        end
    end
end
-- checked at most every 30 s and never during a fight (community events come in
-- all the time during a raid)
local lastCheck = -30
function Badges.CheckSoon()
    if ns.Community and ns.Community.testEvents then return end
    local wait = math.max(3, 30 - (GetTime() - lastCheck))
    ns.Debounce("badges-check", wait, function()
        ns.AfterCombat("badges-check", function() lastCheck = GetTime(); Badges.Check() end)
    end)
end
ns.On("LG_COMMUNITY", Badges.CheckSoon)
ns.On("LG_RUNS", Badges.CheckSoon)
ns.On("LG_READY", function() ns.After(70, Badges.Check) end)

-- /lg test badge: the notification for a sample achievement (nothing stored)
function Badges.Test()
    local def = Badges.BY_ID.speed
    UI.Toast(L.TEST_TAG .. " " .. L.ACH_NEW, Badges.Name(def) .. "  " .. Theme.HexColor("tier6", Badges.TierName(6)), nil,
        { kicker = L.TEST_TAG .. " " .. L.ACH_NEW, lines = { Badges.Desc(def) } })
end
