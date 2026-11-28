-- Community extras: things every player records about themselves and shares
-- with the guild – deaths in the open world, repair bills, the longest online session –
-- plus who writes a login greeting first. Leaderboards in Modules/Community.lua.
local _, ns = ...
local Community = ns.Community
local Names = ns.Names
local Fun = {}
ns.CommunityFun = Fun

local function on() return ns.Database.Settings().modules.community ~= false and IsInGuild() end
local function me() return Names.Me() end

---------------------------------------------------------------------------
-- Pepega around Azeroth: own deaths in the open world (no instance), one
-- running entry per player and day ("wd:<player>:<day>"). How we died comes
-- without the combat log (the client forbids COMBAT_LOG_EVENT_UNFILTERED):
--  * drowning / fatigue: the breath or fatigue mirror timer ran out
--  * fall (incl. lava): we died out of combat – environmental damage never
--    starts combat, monsters and players do
---------------------------------------------------------------------------
local MIRROR_KINDS = { BREATH = "drown", EXHAUSTION = "fatigue" }
local mirror = {}         -- timer name -> true while it runs
local combatEndAt = 0     -- GetTime() of the last PLAYER_REGEN_ENABLED

ns.On("MIRROR_TIMER_START", function(_, name) if MIRROR_KINDS[name] then mirror[name] = true end end)
ns.On("MIRROR_TIMER_STOP", function(_, name) if MIRROR_KINDS[name] then mirror[name] = nil end end)
ns.On("PLAYER_REGEN_ENABLED", function() combatEndAt = GetTime() end)

-- the mirror timer that ran out (progress at 0), if any
local function expiredMirror()
    for name in pairs(mirror) do
        local left = ns.Call(GetMirrorTimerProgress, name)
        if ns.Num(left) and left <= 0 then return MIRROR_KINDS[name] end
    end
end

-- how the player died: "drown"/"fatigue"/"fall" or nil (a monster or player)
function Fun.DeathKind(inCombat)
    local kind = expiredMirror()
    if kind then return kind end
    if inCombat then return nil end
    return "fall"
end

local function worldStore()
    local char = ns.Database.Char()
    local day = date("%Y%m%d")
    if not char.wdeath or char.wdeath.day ~= day then char.wdeath = { day = day, n = 0, e = 0 } end
    return char.wdeath
end
function Fun.ShareWorldDeaths()
    local w = ns.Database.Char().wdeath
    if not on() or not w or (w.n or 0) < 1 then return end
    Community.AddEvent({ id = ("wd:%s:%s"):format(me(), w.day), t = ns.Now(), k = "wdeath", who = me(),
        d = { day = w.day, n = w.n, e = w.e > 0 and w.e or nil } }, true)
end
function Fun.RecordWorldDeath(kind)
    if not on() then return end
    local w = worldStore()
    w.n = math.min(500, w.n + 1)
    if kind then w.e = math.min(w.n, w.e + 1) end
    ns.Debounce("lg-wdeath", 30, Fun.ShareWorldDeaths)
end

ns.On("PLAYER_DEAD", function()
    -- combat ends with the death itself, so a fight that stopped a moment ago counts
    local fighting = ns.Call(UnitAffectingCombat, "player") == true or GetTime() - combatEndAt < 2
    local kind = Fun.DeathKind(fighting)
    wipe(mirror)
    if ns.Call(IsInInstance) == true then return end
    Fun.RecordWorldDeath(kind)
end)
ns.On("LG_READY", function() ns.After(50, Fun.ShareWorldDeaths) end)

---------------------------------------------------------------------------
-- Repair bill: what the repair cost drops by while a merchant is open
---------------------------------------------------------------------------
local merchant           -- { cost, spent }
local function repairCost()
    local cost = ns.Call(GetRepairAllCost)
    return type(cost) == "number" and cost or 0
end
ns.On("MERCHANT_SHOW", function() merchant = { cost = repairCost(), spent = 0 } end)
ns.On("UPDATE_INVENTORY_DURABILITY", function()
    local m = merchant
    if not m then return end
    local now = repairCost()
    if now < m.cost then m.spent = m.spent + (m.cost - now) end
    m.cost = now
end)

function Fun.RecordRepair(copper)
    if not on() or type(copper) ~= "number" or copper < 100 then return end
    local now = ns.Now()
    Community.AddEvent({ id = ("rp:%s:%d"):format(me(), now), t = now, k = "repair", who = me(), d = { c = math.floor(copper) } }, true)
end
ns.On("MERCHANT_CLOSED", function()
    local m = merchant
    merchant = nil
    if m then Fun.RecordRepair(m.spent) end
end)

---------------------------------------------------------------------------
-- Marathon: the longest online session. A /reload or a short disconnect
-- (under 5 minutes) continues the session; it is shared on the next login.
---------------------------------------------------------------------------
local CONTINUE = 300
local MIN_SESSION = 3600

function Fun.RecordSession(start, stop)
    if not on() or type(start) ~= "number" or type(stop) ~= "number" then return end
    local len = stop - start
    if len < MIN_SESSION or len > 2 * 86400 then return end
    Community.AddEvent({ id = ("ss:%s:%d"):format(me(), start), t = stop, k = "session", who = me(), d = { s = len } }, true)
end

ns.On("LG_READY", function()
    local char = ns.Database.Char()
    local now = ns.Now()
    if char.sessionStart and char.lastLogout and now - char.lastLogout < CONTINUE then return end
    local start, stop = char.sessionStart, char.lastLogout
    char.sessionStart = now
    -- the guild channel is ready a little after login
    if start and stop then ns.After(30, function() Fun.RecordSession(start, stop) end) end
end)
ns.On("PLAYER_LOGOUT", function() ns.Database.Char().lastLogout = ns.Now() end)

---------------------------------------------------------------------------
-- Fastest greeter: the first one to write the login greeting in guild chat
-- after a greeted character came online. Every client sees the same order,
-- so the entry has the same id everywhere.
---------------------------------------------------------------------------
local waiting = {}       -- [greeting key] = GetTime() of the login line

ns.On("CHAT_MSG_SYSTEM", function(_, text)
    if ns.IsSecret(text) or not ns.Greet then return end
    local g = ns.Greet.For(ns.Greet.OnlineName(text))
    if g then waiting[g.key] = GetTime() end
end)

ns.On("CHAT_MSG_GUILD", function(_, text, sender)
    if ns.IsSecret(text) or ns.IsSecret(sender) or type(text) ~= "string" or type(sender) ~= "string" or not ns.Greet then return end
    local lower = text:lower()
    for _, g in ipairs(ns.Greet.LIST) do
        local since = waiting[g.key]
        if since and lower == g.text and GetTime() - since < 180 then
            waiting[g.key] = nil
            if on() then
                local now = ns.Now()
                Community.AddEvent({ id = ("g1:%s:%s"):format(g.key, date("%Y%m%d", now)), t = now, k = "greet1",
                    who = Names.Key(sender), d = { g = g.key } }, false)
            end
        end
    end
end)

---------------------------------------------------------------------------
-- AFK king: going AFK inside a raid instance (at most once per 2 minutes)
---------------------------------------------------------------------------
local wasAfk, lastAfk = false, 0
function Fun.RecordAfk()
    if not on() or GetTime() - lastAfk < 120 then return end
    lastAfk = GetTime()
    local now = ns.Now()
    Community.AddEvent({ id = ("af:%s:%d"):format(me(), now), t = now, k = "afk", who = me(), ri = 1, d = {} }, true)
end
ns.On("PLAYER_FLAGS_CHANGED", function(_, unit)
    if unit ~= "player" then return end
    local afk = ns.Call(UnitIsAFK, "player") == true
    if afk and not wasAfk and ns.CommunityRaid and ns.CommunityRaid.Active() then Fun.RecordAfk() end
    wasAfk = afk
end)

---------------------------------------------------------------------------
-- Jumper: real jumps inside a raid instance, one running entry per raid night.
-- Counted in a post-hook (no taint): no presses in mid-air, while swimming or
-- flying, and at most one jump per 0.5 s; shared a minute after the last jump.
---------------------------------------------------------------------------
local function jumpStore()
    local char = ns.Database.Char()
    local day = ns.CommunityRaid.Day()
    if not char.jumps or char.jumps.day ~= day then char.jumps = { day = day, n = 0 } end
    return char.jumps
end

local lastJumpShare = 0
function Fun.ShareJumps()
    lastJumpShare = GetTime()
    local j = ns.Database.Char().jumps
    if not on() or not j or (j.n or 0) < 1 then return end
    Community.AddEvent({ id = ("jp:%s:%s"):format(me(), j.day), t = ns.Now(), k = "jump", who = me(), ri = 1, d = { n = j.n } }, true)
end

local lastJump = 0
function Fun.IsRealJump()
    if ns.Call(IsFalling) == true or ns.Call(IsSwimming) == true or ns.Call(IsFlying) == true then return false end
    if GetTime() - lastJump < 0.5 then return false end
    lastJump = GetTime()
    return true
end
function Fun.Jumped()
    if not on() or not ns.CommunityRaid.Active() then return end
    if not Fun.IsRealJump() then return end
    local j = jumpStore()
    j.n = j.n + 1
    -- a minute after the last jump, and at least every 10 minutes while jumping on
    if GetTime() - lastJumpShare > 600 then Fun.ShareJumps() end
    ns.Debounce("lg-jumps", 60, Fun.ShareJumps)
end
if hooksecurefunc and JumpOrAscendStart then hooksecurefunc("JumpOrAscendStart", function() Fun.Jumped() end) end
-- a count from the last session that was never shared
ns.On("LG_READY", function() ns.After(45, Fun.ShareJumps) end)

---------------------------------------------------------------------------
-- /lg test boards: sample entries on every leaderboard (2 minutes, only here)
---------------------------------------------------------------------------
function Fun.Test()
    local keys = {}
    for _, key in ipairs(ns.Guild.order or {}) do keys[#keys + 1] = key; if #keys >= 6 then break end end
    if #keys == 0 then keys = { me() } end
    local function pick(i) return keys[(i - 1) % #keys + 1] end
    local now = ns.Now()
    local list = {}
    local function add(k, who, d) list[#list + 1] = { id = "test:" .. #list, t = now - #list * 60, k = k, who = who, d = d } end
    for i = 1, 8 do add("repair", pick(i), { c = 150000 + i * 83000 }) end
    for i = 1, #keys do add("session", pick(i), { s = 3600 * (2 + i) + 17 * 60 }) end
    for i = 1, 7 do add("greet1", pick(i % 2 + 1), { g = "salty" }) end
    for i = 1, 6 do add("failpull", pick(i % 4 + 1), {}) end
    for i = 1, 4 do add("mispull", pick(i % 3 + 2), {}) end
    for i = 1, 5 do add("death", pick(i), {}) end
    for i = 1, 8 do add("afk", pick(i % 3 + 1), {}) end
    for i, key in ipairs(keys) do add("jump", key, { n = 150 * i + 37 }) end
    for i, key in ipairs(keys) do
        for n = 1, 2 + i do
            add("daily", key, { day = ("202611%02d"):format(10 + n), login = 1, ghost = 300 * i, taxi = i + n, hearth = i,
                junk = 20000 * i, shop = 90000 * n, mail = i, kick = 4 * i, owl = (i + n) % 2, early = n % 2 })
            add("wdeath", key, { day = ("202611%02d"):format(10 + n), n = i + n, e = n % 2 })
        end
    end
    for i, key in ipairs(keys) do
        for n = 1, 2 + i % 3 do add("raidday", key, { day = "2026110" .. n }) end
        for _ = 1, (i * 2) % 5 do add("epic", key, {}) end
        if i % 2 == 0 then add("epicday", key, { day = "20261102" }) end
    end
    Community.testEvents = list
    Community.testPosts = { { id = "test:post", t = now - 3600, a = pick(2), k = "quote",
        text = "Who pulled? – Nobody, the boss just felt lonely.", likes = { a = true, b = true, c = true } } }
    ns.Print(ns.L.TEST_TAG .. " " .. ns.L.TEST_BOARDS)
    ns.Window.Show("community")
    ns.Window.Refresh("community")
    C_Timer.After(120, function()
        Community.testEvents, Community.testPosts = nil, nil
        ns.Window.Refresh("community")
    end)
end
