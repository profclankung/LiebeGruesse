-- Guild feed: level milestones, joins, boss kills, epic loot, professions,
-- guild firsts and loot council awards. Synced between members.
local _, ns = ...
local Feed = ns.NewModule("feed")
ns.Feed = Feed
local UI, Theme, L, Names, Comm, Items = ns.UI, ns.Theme, ns.L, ns.Names, ns.Comm, ns.Items

local MAX_ENTRIES = 600
local MILESTONES = { [10] = true, [20] = true, [30] = true, [40] = true, [50] = true, [60] = true }
local MAX_LEVEL = 60

local ICONS = {
    lvl = 136064, join = 136116, leave = 136116, boss = 135966, loot = 133784,
    prof = 136249, first = 236685, lc = 133785,
}

local function feed() return ns.Database.Guild().feed end

local function index()
    local byId = {}
    for i, e in ipairs(feed()) do byId[e.id] = i end
    return byId
end

local function today(t) return date("%Y%m%d", t or ns.Now()) end

-- Entries deleted by officers: [id@author] = { t = when, by = officer key }.
-- Keyed with the author, so deleting a forged "first" does not block the real one.
local REMOVED_KEEP = 90 * 86400
local function removed()
    local g = ns.Database.Guild()
    g.feedRemoved = g.feedRemoved or {}
    return g.feedRemoved
end
function Feed.RemovedKey(e) return tostring(e.id) .. "@" .. tostring(e.a or "") end

-- Adds an entry. Returns true if it was new.
function Feed.Add(entry, opts)
    opts = opts or {}
    if type(entry) ~= "table" or type(entry.id) ~= "string" or type(entry.t) ~= "number" then return false end
    if removed()[Feed.RemovedKey(entry)] then return false end
    local list = feed()
    local byId = index()
    local existing = byId[entry.id]
    if existing then
        -- for "firsts" the earliest claim wins – but only claims we checked
        -- live (never from a relayed history batch)
        if entry.k == "first" and list[existing].k == "first" and not opts.relay and list[existing].t > entry.t then
            list[existing] = entry
            return true
        end
        return false
    end
    list[#list + 1] = entry
    table.sort(list, function(a, b) return a.t < b.t end)
    while #list > MAX_ENTRIES do table.remove(list, 1) end
    if opts.broadcast and IsInGuild() then
        Comm.Send("FE", { e = entry }, "GUILD", { priority = "bulk" })
    end
    if opts.toast and ns.Notify then ns.Safe(ns.Notify.Feed, entry) end
    ns.Debounce("feed-redraw", 0.5, function() ns.Window.Refresh("feed"); ns.Window.UpdateStatus() end)
    return true
end

local function who(key)
    local g = ns.Guild.Find(key)
    local m = ns.Database.Member(key)
    return ns.ColorName(g and g.name or (m and m.name) or key, g and g.class or (m and m.c))
end

function Feed.CanDelete() return IsInGuild() and ns.Guild.IsOfficer(Names.Me()) end

-- deletes entries (keys from Feed.RemovedKey) here; by = officer key
local function applyRemove(keys, by, t)
    local store, list = removed(), feed()
    local drop, n = {}, 0
    for _, k in ipairs(keys) do
        if type(k) == "string" and #k <= 220 then
            if not store[k] then store[k] = { t = t or ns.Now(), by = by } end
            drop[k] = true
        end
    end
    for i = #list, 1, -1 do
        if drop[Feed.RemovedKey(list[i])] then table.remove(list, i); n = n + 1 end
    end
    ns.Debounce("feed-redraw", 0.2, function() ns.Window.Refresh("feed"); ns.Window.UpdateStatus() end)
    return n
end

-- officers: delete entries for the whole guild
function Feed.Remove(entries)
    if not Feed.CanDelete() then ns.Print(L.FEED_DELETE_OFFICERS); return 0 end
    local keys, shared = {}, {}
    for _, e in ipairs(entries) do
        local k = Feed.RemovedKey(e)
        keys[#keys + 1] = k
        if not e.test then shared[#shared + 1] = k end
    end
    local n = applyRemove(keys, Names.Me())
    for i = 1, #shared, 30 do
        local part = {}
        for j = i, math.min(i + 29, #shared) do part[#part + 1] = shared[j] end
        Comm.Send("FD", { r = part }, "GUILD", { priority = "normal" })
    end
    return n
end

function Feed.EntriesOf(key)
    local out = {}
    for _, e in ipairs(feed()) do if e.a and Names.Same(e.a, key) then out[#out + 1] = e end end
    return out
end

function Feed.Menu(e)
    local entries = { { title = L.PAGE_FEED } }
    local can = Feed.CanDelete()
    local tip = not can and L.FEED_DELETE_OFFICERS or nil
    entries[#entries + 1] = { text = L.FEED_DELETE, disabled = not can, tip = tip or L.FEED_DELETE_TIP, func = function()
        local n = Feed.Remove({ e })
        if n > 0 then ns.Print(L.FEED_DELETED:format(n)) end
    end }
    if e.a and e.k ~= "boss" then
        local name = Names.Display((ns.Guild.Find(e.a) or {}).name or e.a)
        entries[#entries + 1] = { text = L.FEED_DELETE_ALL:format(name), disabled = not can, tip = tip or L.FEED_DELETE_ALL_TIP,
            func = function()
                local n = Feed.Remove(Feed.EntriesOf(e.a))
                if n > 0 then ns.Print(L.FEED_DELETED:format(n)) end
            end }
    end
    UI.ContextMenu(entries)
end

-- entries newer than the last visit of the feed page (per character)
function Feed.NewCount()
    local char = ns.Database.Char()
    if not char.feedSeen then char.feedSeen = ns.Now(); return 0 end
    local seen = char.feedSeen
    local n = 0
    for _, e in ipairs(feed()) do if e.t > seen then n = n + 1 end end
    return n
end

-- Profession names come from the sender's client (e.g. German) → always English
function Feed.ProfLabel(name)
    if type(name) ~= "string" then return "?" end
    local C = ns.Crafts
    local key = C and C.ProfKey(name)
    local info = key and C.ProfInfo(key)
    return info and C.ProfName(key) or name
end

function Feed.Text(e)
    local d = e.d or {}
    if e.k == "lvl" then return L.FEED_LEVEL:format(who(e.a), d.l or 0)
    elseif e.k == "join" then return L.FEED_JOIN:format(who(e.a))
    elseif e.k == "leave" then return L.FEED_LEAVE:format(who(e.a))
    elseif e.k == "boss" then return L.FEED_BOSS:format(Theme.HexColor("gold", d.b or "?"), d.n or 0)
    elseif e.k == "loot" then return L.FEED_LOOT:format(who(e.a), Items.Link(d.i, d.n, d.q) or "?")
    elseif e.k == "prof" then return L.FEED_PROF:format(who(e.a), Feed.ProfLabel(d.p), d.s or 0)
    elseif e.k == "first" then
        local what = d.w == "lvl" and L.FIRST_LEVEL:format(d.l or MAX_LEVEL) or L.FIRST_PROF:format(Feed.ProfLabel(d.p), d.s or 0)
        return L.FEED_FIRST:format(who(e.a), what)
    elseif e.k == "lc" then return L.FEED_LC:format(who(e.a), Items.Link(d.i, d.n, d.q) or "?", d.r or "")
    end
    return e.k
end

---------------------------------------------------------------------------
-- Details: where, from what, with whom (stored in e.d, shown on hover)
-- d.z zone · d.ins instance · d.m source (mob/boss) · d.dur fight seconds ·
-- d.g guild members in the group (keys) · d.s group size
---------------------------------------------------------------------------
local function here()
    local zone = ns.Call(GetRealZoneText)
    local sub = ns.Call(GetSubZoneText)
    local ins, kind = ns.Call(GetInstanceInfo)
    zone = type(zone) == "string" and zone ~= "" and zone or nil
    if zone and type(sub) == "string" and sub ~= "" and sub ~= zone then zone = zone .. " – " .. sub end
    if kind == nil or kind == "none" or type(ins) ~= "string" or ins == "" then ins = nil end
    return zone, ins
end
Feed.Here = here

local function guildiesInGroup()
    local list = {}
    for _, key in ns.GroupUnits() do
        if ns.Guild.IsMember(key) and #list < 40 then list[#list + 1] = key end
    end
    return list
end

-- the source of loot: a dead target we just opened, else the last boss
local lastCorpse, lastBoss, fightStart = nil, nil, nil
local function lootSource()
    local now = GetTime()
    if lastCorpse and now - lastCorpse.at < 90 then return lastCorpse.name end
    if lastBoss and now - lastBoss.at < 900 then return lastBoss.name end
end
ns.On("LOOT_OPENED", function()
    for _, unit in ipairs({ "target", "mouseover" }) do
        if ns.Call(UnitExists, unit) and ns.Call(UnitIsDead, unit) and not ns.Call(UnitIsPlayer, unit) then
            local name = ns.Call(UnitName, unit)
            if type(name) == "string" then lastCorpse = { name = name, at = GetTime() }; return end
        end
    end
end)
ns.On("ENCOUNTER_START", function() fightStart = GetTime() end)

local function line(label, value)
    return Theme.HexColor("muted", label .. ": ") .. Theme.HexColor("text", tostring(value))
end

local function names(keys, max)
    local out = {}
    for i, key in ipairs(keys or {}) do
        if i > (max or 40) then out[#out + 1] = Theme.HexColor("muted", L.FEED_MORE:format(#keys - (max or 40))); break end
        out[#out + 1] = who(key)
    end
    return table.concat(out, ", ")
end

-- class of a member key (roster, then profile)
local function classOf(key)
    local g = ns.Guild.Find(key)
    local m = ns.Database.Member(key)
    return (g and g.class) or (m and m.c)
end

local function className(class)
    return class and ns.ClassName(class) or nil
end

-- what a toast shows: detail lines and a row of class icons
function Feed.ToastInfo(e)
    local d = e.d or {}
    local lines, classes = {}, nil
    local dot = Theme.HexColor("muted", "  ·  ")
    local function join(...)
        local out = {}
        for i = 1, select("#", ...) do
            local p = select(i, ...)
            if p and p ~= "" then out[#out + 1] = p end
        end
        return table.concat(out, dot)
    end
    if e.k == "lvl" or e.k == "join" or e.k == "first" then
        local class = classOf(e.a)
        local g = ns.Guild.Find(e.a)
        local m = ns.Database.Member(e.a)
        local r, gg, b = ns.ClassColor(class)
        local where = d.ins or d.z or (g and g.online and g.zone ~= "" and g.zone) or nil
        lines[#lines + 1] = join(class and ns.Hex(r, gg, b, className(class)) or nil,
            e.k == "join" and g and g.level and (L.LEVEL .. " " .. g.level) or nil,
            where and (UI.Glyph("dot", "muted", 8) .. " " .. where) or nil)
        if m and m.m and not Names.Same(m.m, e.a) then lines[#lines + 1] = L.ALT_OF:format(Names.Display(m.m)) end
    elseif e.k == "loot" or e.k == "lc" then
        local info = d.i and Items.Info(d.i)
        local level = d.i and Items.Level(d.i)
        local slot = info and info.equipLoc and _G[info.equipLoc]
        lines[#lines + 1] = join(level and L.ARM_ILVL:format(level) or nil, (slot and slot ~= "") and slot or nil,
            e.k == "lc" and d.r or nil)
        lines[#lines + 1] = join(d.m and (L.FEED_D_FROM:format(d.m)) or nil, d.ins or d.z)
    elseif e.k == "boss" then
        lines[#lines + 1] = join(d.ins or d.z, d.dur and ns.Duration(d.dur) or nil,
            d.s and d.s > 0 and L.FEED_D_PLAYERS:format(d.s) or nil)
        if d.g and #d.g > 0 then
            classes = {}
            for _, k in ipairs(d.g) do classes[#classes + 1] = classOf(k) or "WARRIOR" end
        end
    elseif e.k == "prof" then
        local class = classOf(e.a)
        local r, gg, b = ns.ClassColor(class)
        lines[#lines + 1] = join(class and ns.Hex(r, gg, b, className(class)) or nil, d.p and ("%s %d"):format(Feed.ProfLabel(d.p), d.s or 0) or nil)
    end
    local clean = {}
    for _, l in ipairs(lines) do if l ~= "" then clean[#clean + 1] = l end end
    return clean, classes
end

-- one short muted line under the toast text / in the feed list
function Feed.Sub(e)
    local d = e.d or {}
    local parts = {}
    if e.k == "loot" or e.k == "lc" then
        if d.m then parts[#parts + 1] = d.m end
        parts[#parts + 1] = d.ins or d.z
    elseif e.k == "boss" then
        parts[#parts + 1] = d.ins or d.z
        if d.dur then parts[#parts + 1] = ns.Duration(d.dur) end
    elseif e.k == "lvl" or e.k == "first" then
        parts[#parts + 1] = d.ins or d.z
    end
    return table.concat(parts, " · ")
end

-- tooltip lines for an entry (live roster info for the person)
function Feed.DetailLines(e)
    local d = e.d or {}
    local lines = {}
    if d.m then lines[#lines + 1] = line(e.k == "boss" and L.FEED_D_BOSS or L.FEED_D_SOURCE, d.m) end
    if d.ins then lines[#lines + 1] = line(L.FEED_D_INSTANCE, d.ins) end
    if d.z and d.z ~= d.ins then lines[#lines + 1] = line(L.FEED_D_ZONE, d.z) end
    if d.dur then lines[#lines + 1] = line(L.FEED_D_DURATION, ns.Duration(d.dur)) end
    if e.k == "boss" and d.s and d.s > 0 then lines[#lines + 1] = line(L.FEED_D_GROUP, d.s) end
    if e.k == "lc" and d.v then lines[#lines + 1] = line(L.FEED_D_VOTES, d.v) end
    if e.k == "prof" and d.p then lines[#lines + 1] = line(L.PROFESSION, ("%s %d"):format(Feed.ProfLabel(d.p), d.s or 0)) end
    -- the person, as the roster knows them now
    if e.a and e.k ~= "boss" then
        local g = ns.Guild.Find(e.a)
        local m = ns.Database.Member(e.a)
        local bits = {}
        local level = g and g.level or (m and m.l)
        if level then bits[#bits + 1] = L.LEVEL .. " " .. level end
        local class = g and g.class or (m and m.c)
        if class then bits[#bits + 1] = ns.ClassIcon(class, 12) .. " " .. ns.ClassName(class) end
        if g and g.rank then bits[#bits + 1] = g.rank end
        if #bits > 0 then lines[#lines + 1] = line(Names.Display(e.a), table.concat(bits, " · ")) end
        if m and m.m and not Names.Same(m.m, e.a) then lines[#lines + 1] = Theme.HexColor("muted", L.ALT_OF:format(Names.Display(m.m))) end
        if g and g.online and g.zone and g.zone ~= "" then lines[#lines + 1] = line(L.FEED_D_NOW, g.zone) end
    end
    if d.g and #d.g > 0 then
        lines[#lines + 1] = " "
        lines[#lines + 1] = Theme.HexColor("accent", L.FEED_D_GUILDIES:format(#d.g))
        lines[#lines + 1] = names(d.g, 25)
    end
    lines[#lines + 1] = " "
    lines[#lines + 1] = Theme.HexColor("muted", ns.Date(e.t) .. " · " .. ns.Ago(e.t))
    return lines
end

-- hover: item tooltip with the details below it, or a text tooltip
function Feed.ShowTooltip(owner, e, extra)
    local d = e.d or {}
    local lines = Feed.DetailLines(e)
    if (e.k == "loot" or e.k == "lc") and d.i then
        Items.ShowTooltip(owner, d.i)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(Feed.Text(e), 1, 1, 1, true)
        for _, l in ipairs(lines) do GameTooltip:AddLine(l, 0.8, 0.8, 0.8, true) end
    else
        ns.TipOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(Feed.Text(e), 1, 1, 1)
        for _, l in ipairs(lines) do GameTooltip:AddLine(l, 0.8, 0.8, 0.8, true) end
    end
    if extra then GameTooltip:AddLine(extra, 0.6, 0.6, 0.6, true) end
    if owner and owner.feedRow and Feed.CanDelete() then GameTooltip:AddLine(L.FEED_DELETE_HINT, 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Detection
---------------------------------------------------------------------------
local function checkFirstLevel(key, level, t)
    if level < MAX_LEVEL then return end
    Feed.Add({ id = "first:lvl" .. MAX_LEVEL, t = t, k = "first", a = key, d = { w = "lvl", l = MAX_LEVEL } }, { broadcast = true })
end

-- Roster diff: joins, leaves and level milestones (also for members without the addon)
local rosterLive = false
local function rosterDiff()
    local gdb = ns.Database.Guild()
    if not ns.Database.GuildKey() or not next(ns.Guild.members) then return end
    local snap = gdb.rosterSnap
    local now = ns.Now()
    local fresh = {}
    for key, g in pairs(ns.Guild.members) do fresh[key] = g.level or 0 end
    if snap and next(snap) then
        for key, level in pairs(fresh) do
            local old = snap[key]
            if not old then
                Feed.Add({ id = "join:" .. key .. ":" .. today(now), t = now, k = "join", a = key }, { toast = rosterLive })
            elseif level > old then
                for l = old + 1, level do
                    if MILESTONES[l] then
                        local gz = ns.Guild.members[key] and ns.Guild.members[key].zone
                        Feed.Add({ id = "lvl:" .. key .. ":" .. l, t = now, k = "lvl", a = key,
                            d = { l = l, z = (type(gz) == "string" and gz ~= "") and gz or nil } }, { toast = rosterLive })
                    end
                end
            end
        end
        for key in pairs(snap) do
            if not fresh[key] then
                Feed.Add({ id = "leave:" .. key .. ":" .. today(now), t = now, k = "leave", a = key }, { toast = rosterLive })
            end
        end
    end
    gdb.rosterSnap = fresh
    -- changes seen from now on happened while we are online: notify
    rosterLive = true
end
ns.On("LG_ROSTER", function() ns.Debounce("feed-roster", 3, rosterDiff) end)

ns.On("PLAYER_LEVEL_UP", function(_, level)
    level = tonumber(level)
    local me = Names.Me()
    if not level or not me or not MILESTONES[level] then return end
    local now = ns.Now()
    local zone, ins = here()
    Feed.Add({ id = "lvl:" .. me .. ":" .. level, t = now, k = "lvl", a = me, d = { l = level, z = zone, ins = ins } }, { broadcast = true })
    checkFirstLevel(me, level, now)
end)

-- Epic (or better) loot: own, and guild members in our group (also without addon)
local lootPatterns, otherPatterns
local function toPattern(fmt)
    local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
    return "^" .. p .. "$"
end
local function patterns()
    if lootPatterns then return lootPatterns, otherPatterns end
    lootPatterns, otherPatterns = {}, {}
    -- (names, not values: a missing global must not end the list)
    for _, name in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF" }) do
        local fmt = _G[name]
        if type(fmt) == "string" then lootPatterns[#lootPatterns + 1] = toPattern(fmt) end
    end
    for _, name in ipairs({ "LOOT_ITEM_MULTIPLE", "LOOT_ITEM", "LOOT_ITEM_PUSHED_MULTIPLE", "LOOT_ITEM_PUSHED" }) do
        local fmt = _G[name]
        if type(fmt) == "string" then otherPatterns[#otherPatterns + 1] = toPattern(fmt) end
    end
    return lootPatterns, otherPatterns
end

-- one id per player, item and minute, so every observer creates the same entry
local function lootEntry(key, s, now)
    local zone, ins = here()
    local info = Items.Info(s)
    return { id = ("loot:%s:%d:%d"):format(key, Items.ID(s) or 0, math.floor(now / 60)), t = now, k = "loot", a = key,
        d = { i = s, n = info and info.name, q = info and info.quality, m = lootSource(), z = zone, ins = ins,
              r = ns.RaidInstance() and 2 or nil } }
end

local function epic(link)
    local s = Items.String(link)
    local info = s and Items.Info(s)
    return info and info.quality and info.quality >= 4 and s or nil
end

ns.On("CHAT_MSG_LOOT", function(_, text)
    if ns.IsSecret(text) or type(text) ~= "string" or not IsInGuild() then return end
    if not (IsInGroup() or IsInInstance()) then return end
    local own, others = patterns()
    for _, p in ipairs(own) do
        local link = text:match(p)
        if link then
            local s = epic(link)
            if s then Feed.Add(lootEntry(Names.Me(), s, ns.Now()), { broadcast = true }) end
            return
        end
    end
    for _, p in ipairs(others) do
        local who, link = text:match(p)
        if who and link then
            local key = Names.Key(who)
            local s = epic(link)
            if key and s and ns.Guild.IsMember(key) then
                -- one recorder per group shares it; the others only note it
                local recorder = ns.Community and ns.Community.IsRecorder()
                Feed.Add(lootEntry(key, s, ns.Now()), { broadcast = recorder, toast = true })
            end
            return
        end
    end
end)

ns.On("ENCOUNTER_END", function(_, encounterID, name, _, groupSize, success)
    if ns.IsSecret(success) or ns.IsSecret(name) or success ~= 1 or not IsInGuild() then return end
    local guildies, total, leader = 0, 0, nil
    for unit, key in ns.GroupUnits() do
        total = total + 1
        if ns.Guild.IsMember(key) then guildies = guildies + 1 end
        if ns.Call(UnitIsGroupLeader, unit) then leader = key end
    end
    if type(name) == "string" then lastBoss = { name = name, at = GetTime() } end
    if total == 0 or guildies < math.max(2, total / 2) then return end
    local now = ns.Now()
    local dur = fightStart and math.floor(GetTime() - fightStart + 0.5) or nil
    fightStart = nil
    local zone, ins = here()
    local list = guildiesInGroup()
    -- 2 = a real raid instance (1.0.90; older entries: true, ten-player dungeons included)
    local raid = ns.RaidInstance() and 2 or nil
    ns.After(3, function()
        Feed.Add({ id = ("boss:%s:%s:%s"):format(tostring(encounterID), today(now), leader or "?"), t = now, k = "boss",
            a = leader or Names.Me(), d = { b = name, n = guildies, s = groupSize, dur = dur, z = zone, ins = ins, g = list, r = raid } },
            { broadcast = true })
    end)
end)

-- Profession milestones (own)
local seenSkill = {}
ns.On("LG_PROFILE", function(_, key)
    local me = Names.Me()
    if key ~= me then return end
    local m = ns.Database.Member(me)
    for _, p in ipairs(m and m.pr or {}) do
        local old = seenSkill[p.n]
        seenSkill[p.n] = p.s
        if old and p.s and p.s > old and p.s >= 300 and (p.s == p.m or p.s == 300) then
            local now = ns.Now()
            local pn = Feed.ProfLabel(p.n) -- English, so German and English clients share one "first"
            Feed.Add({ id = ("prof:%s:%s:%d"):format(me, pn, p.s), t = now, k = "prof", a = me, d = { p = pn, s = p.s } },
                { broadcast = true })
            Feed.Add({ id = ("first:prof:%s:%d"):format(pn, p.s), t = now, k = "first", a = me, d = { w = "prof", p = pn, s = p.s } },
                { broadcast = true })
        end
    end
end)

---------------------------------------------------------------------------
-- Sync
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Trust: entries from other players are checked before they are stored.
-- Live entries (FE, guild channel) must come from the player they are about
-- or from someone who could have seen it; relayed history (FB) is only taken
-- as the answer to our own request and can never overwrite an entry.
---------------------------------------------------------------------------
local KINDS_OK = { lvl = true, join = true, leave = true, boss = true, loot = true, prof = true, first = true, lc = true }
local FUTURE = 120          -- clock skew tolerance (server time)
local LIVE_AGE = 1800       -- live entries older than this are refused
local FIRST_AGE = 600       -- a "first" must be claimed right away (no backdating)
local TOAST_LIMIT = 6       -- toasts per sender and minute

local function wellFormed(raw)
    if type(raw) ~= "table" then return nil end
    local e = ns.Clean(raw, 3)
    if type(e.id) ~= "string" or #e.id > 160 or type(e.t) ~= "number" or type(e.k) ~= "string" or not KINDS_OK[e.k] then return nil end
    -- the id must belong to the kind (no "lvl" entry under a "first:" id)
    if e.id:sub(1, #e.k + 1) ~= e.k .. ":" then return nil end
    if e.a ~= nil and type(e.a) ~= "string" then return nil end
    if e.d ~= nil and type(e.d) ~= "table" then return nil end
    if e.t > ns.Now() + FUTURE then return nil end
    e.key = nil
    return e
end

local function rosterLevel(key)
    local g = key and ns.Guild.Find(key)
    return g and tonumber(g.level)
end

-- a level entry: id matches, and the roster does not contradict it
-- (slack: live messages arrive before our roster shows the new level)
local function plausibleLevel(e, slack)
    local l = e.d and tonumber(e.d.l)
    if not l or not e.a or e.id ~= ("lvl:%s:%d"):format(e.a, l) then return false end
    local rl = rosterLevel(e.a)
    return rl == nil or rl + (slack or 0) >= l
end

-- a "first": level firsts need a max-level guild member, profession firsts a member
local function plausibleFirst(e, slack)
    local d = e.d or {}
    if not e.a or not ns.Guild.IsMember(e.a) then return false end
    if d.w == "lvl" then
        return e.id == "first:lvl" .. MAX_LEVEL and (rosterLevel(e.a) or 0) + (slack or 0) >= MAX_LEVEL
    elseif d.w == "prof" then
        return type(d.p) == "string" and type(d.s) == "number" and e.id == ("first:prof:%s:%d"):format(d.p, d.s)
    end
    return false
end

local function listed(list, key)
    if type(list) ~= "table" then return false end
    for _, k in ipairs(list) do if type(k) == "string" and Names.Same(k, key) then return true end end
    return false
end

-- observed loot: the observer must be online in the looter's zone (guild roster)
local function sameZone(a, b)
    local ga, gb = ns.Guild.Find(a), ns.Guild.Find(b)
    if not ga or not gb or not ga.online or not gb.online then return false end
    return type(ga.zone) == "string" and ga.zone ~= "" and ga.zone == gb.zone
end

-- loot council awards: the loot master's history record (LH, arrives first) must match
local function councilConfirmed(e, sender)
    local rid = e.id:sub(4)
    local list = ns.Database.Guild().lootHistory
    for i = #list, 1, -1 do
        local r = list[i]
        if r.id == rid then return Names.Same(r.by, sender) and Names.Same(r.to, e.a) end
    end
    return false
end

local function liveOk(e, sender)
    if e.t < ns.Now() - LIVE_AGE then return false end
    local k = e.k
    if k == "lvl" then return Names.Same(e.a, sender) and plausibleLevel(e, 1) end
    if k == "prof" then return Names.Same(e.a, sender) end
    if k == "loot" then return e.a ~= nil and (Names.Same(e.a, sender) or (ns.Guild.IsMember(e.a) and sameZone(e.a, sender))) end
    if k == "boss" then return Names.Same(e.a, sender) or listed(e.d and e.d.g, sender) end
    if k == "first" then return e.t >= ns.Now() - FIRST_AGE and plausibleFirst(e, 1) end
    if k == "lc" then return councilConfirmed(e, sender) end
    return false   -- join/leave are never broadcast: every client sees them in the roster itself
end
Feed.LiveOk = liveOk

local function relayOk(e)
    if e.k == "lvl" then return plausibleLevel(e) end
    if e.k == "first" then return plausibleFirst(e) end
    if e.k == "join" or e.k == "leave" then return e.a ~= nil and e.id:sub(1, #e.k + #e.a + 2) == e.k .. ":" .. e.a .. ":" end
    return true
end

local toastBudget = {}
local function mayToast(sender)
    local now = GetTime()
    local b = toastBudget[sender]
    if not b or now - b.t > 60 then b = { t = now, n = 0 }; toastBudget[sender] = b end
    b.n = b.n + 1
    return b.n <= TOAST_LIMIT
end

---------------------------------------------------------------------------
-- Sync
---------------------------------------------------------------------------
Comm.Register("FE", function(data, sender, channel)
    if channel ~= "GUILD" then return end
    local e = wellFormed(data.e)
    if not e or not liveOk(e, sender) then return end
    local isNew = Feed.Add(e, { toast = mayToast(sender) })
    if isNew and e.k == "lvl" then checkFirstLevel(e.a, (e.d and e.d.l) or 0, e.t) end
end)

Comm.Register("FS", function(data, sender, channel, raw)
    -- only guild members may ask (a whisper could come from anyone)
    if channel ~= "GUILD" then return end
    local since = tonumber(data.since) or 0
    local list = feed()
    if #list == 0 or list[#list].t <= since then return end
    Comm.ReplyOnce("feed:" .. sender, 3, 12, function()
        Comm.Send("FA", { to = sender }, "GUILD", { priority = "alert" })
        -- deletions first, so the entries that follow are already filtered
        local rm = {}
        for k, x in pairs(removed()) do
            if type(x) == "table" and x.by and (x.t or 0) > since - 30 * 86400 and #rm < 200 then rm[#rm + 1] = { k = k, by = x.by, t = x.t } end
        end
        if #rm > 0 then Comm.Send("FR", { r = rm }, "WHISPER", { target = raw, priority = "bulk" }) end
        local batch = {}
        local sent = 0
        for _, e in ipairs(list) do
            if e.t > since and not e.test then
                batch[#batch + 1] = e
                sent = sent + 1
                if #batch == 15 then
                    Comm.Send("FB", { list = batch }, "WHISPER", { target = raw, priority = "bulk" })
                    batch = {}
                end
            end
        end
        if #batch > 0 then Comm.Send("FB", { list = batch }, "WHISPER", { target = raw, priority = "bulk" }) end
    end)
end)

-- deletions: only from officers of our guild
Comm.Register("FD", function(data, sender, channel)
    if channel ~= "GUILD" or type(data.r) ~= "table" or not ns.Guild.IsOfficer(sender) then return end
    local keys = {}
    for i, k in ipairs(data.r) do
        if i > 60 then break end
        if type(k) == "string" then keys[#keys + 1] = k end
    end
    applyRemove(keys, sender)
end)

-- deletions passed on with the history (each still needs an officer as author)
Comm.Register("FR", function(data, sender, channel)
    if channel ~= "WHISPER" or type(data.r) ~= "table" or not ns.Guild.IsMember(sender) then return end
    if not Comm.Expected("feed-sync", sender) then return end
    for i, x in ipairs(data.r) do
        if i > 200 then break end
        if type(x) == "table" and type(x.k) == "string" and type(x.by) == "string" and ns.Guild.IsOfficer(x.by) then
            local t = tonumber(x.t)
            applyRemove({ x.k }, x.by, t and math.min(t, ns.Now()) or nil)
        end
    end
end)

Comm.Register("FA", function(data, sender)
    if not data.to then return end
    Comm.Answered("feed:" .. data.to)
    -- someone answers our request: only take the history from that player
    if Names.Same(data.to, Names.Me()) then Comm.Expected("feed-sync", sender) end
end)

Comm.Register("FB", function(data, sender, channel)
    if channel ~= "WHISPER" or type(data.list) ~= "table" then return end
    if not ns.Guild.IsMember(sender) then return end
    local req = Comm.Expected("feed-sync", sender)
    if not req then return end
    for i, raw in ipairs(data.list) do
        if i > 15 or (req.count or 0) >= MAX_ENTRIES then break end
        local e = wellFormed(raw)
        if e and e.t > (req.since or 0) and relayOk(e) then
            req.count = (req.count or 0) + 1
            Feed.Add(e, { relay = true })
        end
    end
end)

function Feed:OnLogin()
    local now = ns.Now()
    for k, x in pairs(removed()) do
        if type(x) ~= "table" or now - (x.t or 0) > REMOVED_KEEP then removed()[k] = nil end
    end
    ns.After(45, function()
        if not IsInGuild() then return end
        local list = feed()
        local newest = #list > 0 and list[#list].t or 0
        local since = math.max(0, newest - 86400)
        Comm.Expect("feed-sync", 180, { since = since })
        Comm.Send("FS", { since = since }, "GUILD", { priority = "bulk" })
    end)
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local filter = "all"
local KINDS = { "all", "lvl", "boss", "loot", "prof", "first", "join", "lc" }

UI.AddPage("feed", L.PAGE_FEED, 20, function(root, page)
    -- tabs: the feed and its settings
    local content, tabs = UI.PageWithSettings(root, page, L.FEED_TAB, function(form)
        local st = ns.Database.Settings()
        local s = form:Section(L.PAGE_FEED)
        s:Toggle(L.SET_TOASTS, function() return st.toasts end, function(v) st.toasts = v end, { tip = L.SET_TOASTS_TIP })
        s:Buttons({ { L.PAGE_NOTIFY, function() ns.Window.Show("notifications") end, width = 170, icon = "newspaper" } })
    end)
    local list
    -- filter chips (one kind at a time); they end before the page search in the top right corner
    local items = {}
    for _, k in ipairs(KINDS) do
        items[#items + 1] = { value = k, text = L["FEED_CHIP_" .. k], icon = k == "all" and "newspaper" or ICONS[k], tip = L["FEED_KIND_" .. k] }
    end
    local chips = UI.FilterChips(content, items, function() return filter end, function(v)
        filter = v
        page.OnShow()
        if page.query and page.query ~= "" then list:ShowFirstHit(page.query) end
    end)
    chips:SetPoint("TOPLEFT")
    chips:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    page.feedChips = chips

    list = UI.List(content, {
        rowHeight = 24, sortKey = "t", sortDesc = true,
        columns = {
            { key = "t", title = L.COL_WHEN, width = 110, text = function(r) return Theme.HexColor("muted", ns.Ago(r.t)) end,
              sort = function(r) return r.t end, defaultDesc = true, icon = function(r) return ICONS[r.k] end },
            { key = "text", title = L.COL_EVENT, flex = true, minWidth = 220, text = function(r) return Feed.Text(r) end },
            { key = "where", title = L.COL_DETAILS, width = 220, optional = 1,
              text = function(r) return Theme.HexColor("muted", Feed.Sub(r)) end },
        },
        onEnter = function(frame, row) frame.feedRow = true; Feed.ShowTooltip(frame, row) end,
        onClick = function(row) if Feed.CanDelete() then Feed.Menu(row) end end,
    })
    list:SetPoint("TOPLEFT", 0, -32)
    list:SetPoint("BOTTOMRIGHT")
    list:SetEmptyText(L.FEED_EMPTY)

    -- header search: player, item, boss, zone …
    page.Search = function(text) page.query = text; page.OnShow(); return list:ShowFirstHit(text) end
    page.searchList = list
    page.OnShow = function()
        ns.Database.Char().feedSeen = ns.Now()
        ns.Window.UpdateStatus()
        local rows, counts = {}, { all = 0 }
        for _, e in ipairs(feed()) do
            local k = e.k == "leave" and "join" or e.k
            counts[k] = (counts[k] or 0) + 1
            counts.all = counts.all + 1
            local keep = filter == "all" or e.k == filter or (filter == "join" and e.k == "leave")
            if keep then
                e.key = e.id
                rows[#rows + 1] = e
            end
        end
        list:SetRows(rows)
        for _, k in ipairs(KINDS) do chips:SetCount(k, counts[k] or 0) end
        chips:Refresh()
        list:SetEmptyText(filter == "all" and L.FEED_EMPTY or L.FEED_EMPTY_KIND:format(L["FEED_KIND_" .. filter]))
    end
    tabs.Finish()
end, { section = "guild", icon = "newspaper", module = "feed" })

-- items load lazily: redraw the feed once their names arrive
ns.On("GET_ITEM_INFO_RECEIVED", function()
    ns.Debounce("feed-items", 1, function() if ns.Window and ns.Window.Refresh then ns.Window.Refresh("feed") end end)
end)
