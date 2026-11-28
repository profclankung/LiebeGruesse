-- Raid night boards: what happens in the raid – and only there. Everything in
-- here counts only inside a raid instance with a guild raid (at least half of
-- the group from the guild). Shared observations (deaths, ready checks, raid
-- chat, /roll, emotes) are recorded by one addon user per group (the
-- recorder); own things (potions) by every player for himself.
--   first2die  first death of a boss pull            (recorder)
--   laststand  last one alive when a boss wipes       (recorder)
--   death      died in a boss kill the raid survived  (recorder, "Pepega")
--   rnight     running counters per player and night: chat, emote, nr (not
--              ready), rolls, rsum, r1, r100           (recorder)
--   chug       own potions & healthstones in boss fights per night (self)
-- After a raid night "Tonight's awards" sums it up (toast + card).
local _, ns = ...
local Community = ns.Community
local Names, L, Theme, UI, Comm = ns.Names, ns.L, ns.Theme, ns.UI, ns.Comm
local Raid = {}
ns.CommunityRaid = Raid

local function on() return ns.Database.Settings().modules.community ~= false and IsInGuild() end

-- the raid night a moment belongs to: nights after midnight count to the day before
function Raid.Day(t)
    return date("%Y%m%d", (t or ns.Now()) - 6 * 3600)
end

-- inside a real raid instance (the group may be anything); ten-player
-- dungeons in a raid group (Upper Blackrock Spire) are no raid
function Raid.InRaid()
    if Raid.testInRaid then return true end
    return ns.RaidInstance()
end

-- counts right now: raid instance, guild raid, module on (kept for 2 s – raid
-- chat and emotes would ask many times a second)
local activeAt, activeValue = -10, false
function Raid.Active()
    if Raid.testInRaid then return true end
    local now = GetTime()
    if now - activeAt < 2 then return activeValue end
    activeAt = now
    activeValue = on() and Raid.InRaid() and (Community.GuildGroup and Community.GuildGroup() or false) or false
    return activeValue
end
function Raid.ResetActive() activeAt = -10 end
ns.On("ZONE_CHANGED_NEW_AREA", Raid.ResetActive)
ns.On("GROUP_ROSTER_UPDATE", Raid.ResetActive)
ns.On("PLAYER_ENTERING_WORLD", Raid.ResetActive)

local function recorder() return Raid.testInRaid or Community.IsRecorder() end

---------------------------------------------------------------------------
-- Running counters per player and night (recorder)
---------------------------------------------------------------------------
Raid.LIMITS = { chat = 5000, emote = 2000, nr = 100, rolls = 500, rsum = 50000, r1 = 500, r100 = 500 }
function Raid.Valid(d)
    if type(d) ~= "table" or type(d.day) ~= "string" or not d.day:match("^%d%d%d%d%d%d%d%d$") then return false end
    for k, v in pairs(d) do
        if k ~= "day" then
            local limit = Raid.LIMITS[k]
            if not limit or type(v) ~= "number" or v < 0 or v > limit then return false end
        end
    end
    return true
end

local nights = {}       -- [id] = event (local copy we count on)
local dirty = {}
local lastShare = 0

local function night(key)
    local day = Raid.Day()
    local id = ("rn:%s:%s"):format(key, day)
    local e = nights[id]
    if not e then
        e = { id = id, t = ns.Now(), k = "rnight", who = key, ri = 1, d = { day = day } }
        -- another recorder may have counted before: go on from there
        for _, old in ipairs(Community.Store().events) do
            if old.id == id and type(old.d) == "table" then
                for k, v in pairs(old.d) do if type(v) == "number" then e.d[k] = v end end
                break
            end
        end
        nights[id] = e
    end
    return e
end

function Raid.Share()
    lastShare = GetTime()
    for id in pairs(dirty) do
        local e = nights[id]
        if e then
            e.t = ns.Now()
            local copy = { id = e.id, t = e.t, k = e.k, who = e.who, ri = 1, d = {} }
            for k, v in pairs(e.d) do copy.d[k] = v end
            Community.AddEvent(copy, not Raid.testInRaid)
        end
    end
    wipe(dirty)
end

-- adds n to a counter of a player (only while active, only the recorder)
function Raid.Bump(key, field, n)
    if not key or not Raid.Active() or not recorder() then return end
    if not ns.Guild.IsMember(key) and not Raid.testInRaid then return end
    local e = night(key)
    e.d[field] = math.min(Raid.LIMITS[field] or 1e6, (e.d[field] or 0) + (n or 1))
    dirty[e.id] = true
    -- a minute after the last change, at least every 10 minutes
    if GetTime() - lastShare > 600 then Raid.Share() end
    ns.Debounce("raid-night-share", 60, Raid.Share)
end

---------------------------------------------------------------------------
-- Boss pulls: order of deaths (first to die, last one standing, "Pepega")
---------------------------------------------------------------------------
local pull           -- { enc, name, start (server), alive = set, deaths = { {key, gt} } }
Raid.lastRaid = nil

local function groupKeys()
    local keys = {}
    for _, key in ns.GroupUnits() do keys[#keys + 1] = key end
    return keys
end

function Raid.PullStart(encounterID, name)
    if not Raid.Active() then pull = nil; return end
    if ns.DeathWatch then ns.DeathWatch.Scan() end
    local alive = {}
    for _, key in ipairs(groupKeys()) do
        if not (ns.DeathWatch and ns.DeathWatch.IsDead(key)) then alive[key] = true end
    end
    pull = { enc = encounterID, name = name, start = ns.Now(), alive = alive, deaths = {}, size = #groupKeys() }
end

ns.On("LG_DEATH", function(_, key, _, gt)
    if pull and pull.alive[key] and not pull.dead then
        pull.deaths[#pull.deaths + 1] = { key = key, gt = gt }
        pull.alive[key] = nil
    end
end)

local function add(e) e.ri = 1; Community.AddEvent(e, not Raid.testInRaid) end

function Raid.PullEnd(success, name)
    -- deaths of the last moment still count for this pull
    if pull and ns.DeathWatch then ns.DeathWatch.Scan() end
    local p = pull
    pull = nil
    if not p then return end
    local boss = p.name or name
    local char = ns.Database.Char()
    -- the raid night of this client (for the awards card)
    local day = Raid.Day()
    local lr = char.lastRaid
    if not lr or lr.day ~= day then lr = { day = day, kills = 0, wipes = 0 }; char.lastRaid = lr end
    local ins = ns.Call(GetInstanceInfo)
    if type(ins) == "string" then lr.ins = ins end
    if success then lr.kills = lr.kills + 1 else lr.wipes = lr.wipes + 1 end
    -- no deaths in a boss kill: own achievement counter
    if success and #p.deaths == 0 and ns.Achievements then ns.Achievements.Bump("deathless") end
    if not recorder() then return end
    local first = p.deaths[1]
    if first then
        add({ id = ("fd:%s:%d"):format(tostring(p.enc), p.start), t = ns.Now(), k = "first2die", who = first.key, d = { b = boss } })
    end
    if success then
        -- died while (at least 80 %) of the raid lived: "Pepega"
        if #p.deaths > 0 and #p.deaths < (p.size or 1) * 0.8 then
            for _, d in ipairs(p.deaths) do
                add({ id = ("pd:%s:%d"):format(d.key, p.start), t = ns.Now(), k = "death", who = d.key, d = { b = boss } })
            end
        end
    else
        -- wipe: the one still alive, or the last one to die
        local alive = {}
        for key in pairs(p.alive) do
            if not (ns.DeathWatch and ns.DeathWatch.IsDead(key)) then alive[#alive + 1] = key end
        end
        local last
        if #alive == 1 then last = alive[1]
        elseif #alive == 0 and #p.deaths > 0 then last = p.deaths[#p.deaths].key end
        if last then
            add({ id = ("ls:%s:%d"):format(tostring(p.enc), p.start), t = ns.Now(), k = "laststand", who = last, d = { b = boss } })
        end
    end
end

ns.On("ENCOUNTER_START", function(_, encounterID, name)
    if ns.IsSecret(encounterID) or ns.IsSecret(name) then return end
    Raid.PullStart(encounterID, type(name) == "string" and name or nil)
end)
ns.On("ENCOUNTER_END", function(_, _, name, _, _, success)
    if ns.IsSecret(success) then return end
    -- deaths of the last second are read first
    ns.After(1, function() Raid.PullEnd(success == 1, type(name) == "string" and name or nil) end)
end)

---------------------------------------------------------------------------
-- Ready checks: "not ready" or no answer at all
---------------------------------------------------------------------------
local check     -- { pending = set, notReady = set }
ns.On("READY_CHECK", function(_, initiator)
    if not Raid.Active() then check = nil; return end
    local starter = type(initiator) == "string" and not ns.IsSecret(initiator) and Names.Key(initiator)
    check = { pending = {}, notReady = {} }
    for _, key in ipairs(groupKeys()) do
        if not (starter and Names.Same(key, starter)) then check.pending[key] = true end
    end
end)
ns.On("READY_CHECK_CONFIRM", function(_, unit, isReady)
    if not check or ns.IsSecret(unit) or ns.IsSecret(isReady) then return end
    local name = Names.Unit(unit)
    local key = name and Names.Key(name)
    if not key then return end
    check.pending[key] = nil
    if not isReady then check.notReady[key] = true end
end)
ns.On("READY_CHECK_FINISHED", function()
    local c = check
    check = nil
    if not c then return end
    for key in pairs(c.pending) do Raid.Bump(key, "nr") end
    for key in pairs(c.notReady) do Raid.Bump(key, "nr") end
end)

---------------------------------------------------------------------------
-- Raid chat, emotes, /roll
---------------------------------------------------------------------------
local function chat(_, text, sender)
    if ns.IsSecret(sender) or type(sender) ~= "string" then return end
    Raid.Bump(Names.Key(sender), "chat")
end
ns.On("CHAT_MSG_RAID", chat)
ns.On("CHAT_MSG_RAID_LEADER", chat)
ns.On("CHAT_MSG_RAID_WARNING", chat)

local function emote(_, text, sender)
    -- emotes fire a lot in cities: nothing to do outside the raid
    if ns.IsSecret(sender) or type(sender) ~= "string" or not Raid.Active() then return end
    local key = Names.Key(sender)
    -- only raid members (emotes of strangers around us do not count)
    if key and ns.UnitForKey(key) then Raid.Bump(key, "emote") end
end
ns.On("CHAT_MSG_TEXT_EMOTE", emote)
ns.On("CHAT_MSG_EMOTE", emote)

local rollPattern
function Raid.ParseRoll(text)
    if type(text) ~= "string" or ns.IsSecret(text) then return nil end
    if not rollPattern then
        local fmt = type(RANDOM_ROLL_RESULT) == "string" and RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"
        rollPattern = "^" .. fmt:gsub("([%(%)%.%[%]%*%+%-%?%^%$])", "%%%1"):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)") .. "$"
    end
    local who, roll, low, high = text:match(rollPattern)
    if not who then return nil end
    return who, tonumber(roll), tonumber(low), tonumber(high)
end
ns.On("CHAT_MSG_SYSTEM", function(_, text)
    local who, roll, low, high = Raid.ParseRoll(text)
    if not who or low ~= 1 or high ~= 100 or not roll then return end
    local key = Names.Key(who)
    if not key or not ns.UnitForKey(key) then return end
    if not Raid.Active() or not recorder() then return end
    Raid.Bump(key, "rolls")
    Raid.Bump(key, "rsum", roll)
    if roll == 1 then Raid.Bump(key, "r1") end
    if roll == 100 then Raid.Bump(key, "r100") end
end)

---------------------------------------------------------------------------
-- Chugger: own potions and healthstones in boss fights (self, per night)
---------------------------------------------------------------------------
Raid.POTIONS = { 118, 858, 929, 1710, 3928, 13446, 18839, 2455, 3385, 3827, 6149, 13443, 13444, 18841, 2456, 18253,
    5512, 5511, 5509, 5510, 9421, 19004, 19005, 19006, 19007, 19008, 19009, 19010, 19011, 19012, 19013,
    12662, 20520, 13457, 13456, 13458, 13459, 13461, 6049, 6050, 6052, 3387, 5634, 9030, 13442, 5633, 20008, 13455 }
local potionSpells, potionNames, resolved = {}, {}, 0
function Raid.ResolvePotions()
    local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    if not getSpell then return 0 end
    resolved = 0
    for _, item in ipairs(Raid.POTIONS) do
        local name, id = ns.Call(getSpell, item)
        if ns.Num(id) then potionSpells[id] = true; resolved = resolved + 1 end
        if type(name) == "string" then potionNames[name] = true end
    end
    return resolved
end
ns.On("LG_READY", function() ns.After(20, Raid.ResolvePotions) end)
ns.On("GET_ITEM_INFO_RECEIVED", function() if resolved < 10 then ns.Debounce("raid-potions", 5, Raid.ResolvePotions) end end)

function Raid.IsPotion(spellID)
    if not ns.Num(spellID) then return false end
    if potionSpells[spellID] then return true end
    local name = C_Spell and C_Spell.GetSpellName and ns.Call(C_Spell.GetSpellName, spellID)
    return type(name) == "string" and potionNames[name] == true
end

local function chugStore()
    local char = ns.Database.Char()
    local day = Raid.Day()
    if not char.chug or char.chug.day ~= day then char.chug = { day = day, n = 0 } end
    return char.chug
end
function Raid.ShareChug()
    local c = ns.Database.Char().chug
    if not on() or not c or (c.n or 0) < 1 then return end
    local me = Names.Me()
    Community.AddEvent({ id = ("cg:%s:%s"):format(me, c.day), t = ns.Now(), k = "chug", who = me, ri = 1, d = { n = c.n } }, not Raid.testInRaid)
end
function Raid.Chugged()
    if not Raid.Active() or not ns.EncounterInProgress() and not Raid.testInRaid then return end
    local c = chugStore()
    c.n = c.n + 1
    ns.Debounce("raid-chug", 90, Raid.ShareChug)
end
ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
    if unit ~= "player" or ns.IsSecret(spellID) then return end
    if Raid.IsPotion(spellID) then Raid.Chugged() end
end)
ns.On("LG_READY", function() ns.After(50, Raid.ShareChug) end)

---------------------------------------------------------------------------
-- Tonight's awards: the night's winners (toast after the raid, card on the
-- community page, one click posts them to the guild chat)
---------------------------------------------------------------------------
local AWARDS = {
    { key = "first2die", icon = "skull", title = "AWARD_FIRST2DIE", fmt = "AWARD_TIMES" },
    { key = "laststand", icon = "shield", title = "AWARD_LASTSTAND", fmt = "AWARD_TIMES" },
    { key = "death", icon = "x", title = "AWARD_PEPEGA", fmt = "AWARD_TIMES" },
    { key = "jump", icon = "sparkles", title = "AWARD_KANGAROO", fmt = "AWARD_JUMPS" },
    { key = "chat", icon = "message-circle", title = "AWARD_CHATTERBOX", fmt = "AWARD_LINES" },
    { key = "roll", icon = "star", title = "AWARD_ROLLKING", fmt = "AWARD_AVG" },
    { key = "nr", icon = "timer", title = "AWARD_NOTREADY", fmt = "AWARD_CHECKS" },
    { key = "chug", icon = "zap", title = "AWARD_CHUGGER", fmt = "AWARD_POTIONS" },
}
Raid.AWARDS = AWARDS

-- the newest raid night with data (within maxDays)
function Raid.LastNight(maxDays)
    local best
    local since = ns.Now() - (maxDays or 7) * 86400
    for _, e in ipairs(Community.Store().events) do
        local d = type(e.d) == "table" and e.d
        if e.t >= since and Community.Counts(e) and (e.k == "rnight" or e.k == "first2die" or e.k == "laststand" or (e.k == "jump" and d and d.n)) then
            local day = (d and d.day) or Raid.Day(e.t)
            if not best or day > best then best = day end
        end
    end
    for _, e in ipairs(Community.testEvents or {}) do
        if e.k == "rnight" and e.d and e.d.day and (not best or e.d.day > best) then best = e.d.day end
    end
    return best
end

-- winners of one night: { { def, key, value, text } }
function Raid.Awards(day)
    if not day then return {} end
    local sums = {}
    local function put(kind, key, n) sums[kind] = sums[kind] or {}; sums[kind][key] = (sums[kind][key] or 0) + n end
    local rolls = {}
    local events = Community.Store().events
    if Community.testEvents then
        local merged = {}
        for _, e in ipairs(events) do merged[#merged + 1] = e end
        for _, e in ipairs(Community.testEvents) do merged[#merged + 1] = e end
        events = merged
    end
    for _, e in ipairs(events) do
        local d = type(e.d) == "table" and e.d or {}
        local eday = d.day or Raid.Day(e.t)
        if eday == day and e.who and Community.Counts(e) then
            if e.k == "first2die" or e.k == "laststand" or e.k == "death" then put(e.k, e.who, 1)
            elseif e.k == "jump" then put("jump", e.who, tonumber(d.n) or 0)
            elseif e.k == "chug" then put("chug", e.who, tonumber(d.n) or 0)
            elseif e.k == "rnight" then
                put("chat", e.who, tonumber(d.chat) or 0)
                put("nr", e.who, tonumber(d.nr) or 0)
                if (tonumber(d.rolls) or 0) >= 3 then rolls[e.who] = (tonumber(d.rsum) or 0) / d.rolls end
            end
        end
    end
    sums.roll = rolls
    local out = {}
    for _, def in ipairs(AWARDS) do
        local bestKey, bestV
        for key, v in pairs(sums[def.key] or {}) do
            if v > 0 and (not bestV or v > bestV or (v == bestV and key < bestKey)) then bestKey, bestV = key, v end
        end
        if bestKey then
            local v = def.key == "roll" and math.floor(bestV + 0.5) or bestV
            out[#out + 1] = { def = def, key = bestKey, value = v, text = L[def.fmt]:format(v) }
        end
    end
    return out
end

-- one chat line for the guild (≤ 255 characters, plain names)
function Raid.AwardsLine(day)
    local parts = {}
    for _, a in ipairs(Raid.Awards(day)) do
        parts[#parts + 1] = ("%s: %s (%s)"):format(L[a.def.title], Names.Display(a.key), a.text)
    end
    if #parts == 0 then return nil end
    local line = L.AWARDS_CHAT_PREFIX .. " " .. table.concat(parts, " · ")
    if #line > 250 then line = line:sub(1, 247) .. "..." end
    return line
end

function Raid.PostAwards(day)
    local line = Raid.AwardsLine(day or Raid.LastNight())
    if not line then ns.Print(L.AWARDS_NONE); return false end
    return ns.SendChat(line, "GUILD")
end

function Raid.ShowAwardsToast(day, test)
    local list = Raid.Awards(day)
    if #list == 0 then return false end
    local lines = {}
    for i, a in ipairs(list) do
        if i > 4 then break end
        local g = ns.Guild.Find(a.key)
        lines[#lines + 1] = Theme.HexColor("muted", L[a.def.title] .. ": ")
            .. ns.ColorName(g and g.name or Names.Display(a.key), g and g.class) .. Theme.HexColor("muted", "  " .. a.text)
    end
    local kicker = (test and (L.TEST_TAG .. " ") or "") .. L.AWARDS_KICKER
    UI.Toast(kicker, L.AWARDS_TITLE, nil, { kicker = kicker, big = true, duration = 20, lines = lines,
        action = function() ns.Window.Show("community") end, actionText = L.AWARDS_CLICK, page = "community" })
    return true
end

-- leaving the raid instance after a night with kills: the awards once per night
local wasInRaid = false
local function zoneChanged()
    local inside = Raid.InRaid()
    if wasInRaid and not inside then
        local lr = ns.Database.Char().lastRaid
        local st = ns.Database.Settings().community
        if lr and lr.day == Raid.Day() and (lr.kills or 0) > 0 and st.awards ~= false and st.awardsSeen ~= lr.day then
            ns.After(20, function()
                if Raid.ShowAwardsToast(lr.day) then st.awardsSeen = lr.day end
                Raid.Share()
                Raid.ShareChug()
            end)
        end
    end
    wasInRaid = inside
end
ns.On("ZONE_CHANGED_NEW_AREA", function() ns.After(3, zoneChanged) end)
ns.On("PLAYER_ENTERING_WORLD", function() ns.After(3, zoneChanged) end)
ns.On("PLAYER_LOGOUT", function() Raid.Share() end)

-- /lg test raidnight: what this client knows right now (nothing sent)
function Raid.Report()
    local inside, kind = ns.Call(IsInInstance)
    ns.Print(L.TEST_TAG .. " " .. L.RAIDNIGHT_REPORT)
    print(("  raid instance: %s (%s) · guild raid: %s · recorder: %s"):format(tostring(inside == true), tostring(kind),
        tostring(Community.GuildGroup and Community.GuildGroup() or false), tostring(Community.IsRecorder())))
    print(("  counting now: %s · potions known: %d · raid night: %s"):format(tostring(Raid.Active()), Raid.ResolvePotions(), Raid.Day()))
    local last = Raid.LastNight(30)
    print("  last raid night with data: " .. tostring(last or "–"))
    for _, a in ipairs(Raid.Awards(last)) do print(("    %s: %s (%s)"):format(L[a.def.title], Names.Display(a.key), a.text)) end
end
