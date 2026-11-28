-- Speedruns: guild records, plausibility checks and sync.
--   SR   a new record (top 10 of its wing or a personal best), GUILD, one sender per group
--   SRQ  login: "anything newer than t?", GUILD
--   SRA  "I answer X" (the others stay quiet), GUILD
--   SRB  records for the asking player, WHISPER, only after own SRQ
-- Every record is checked before it is stored: known instance and wing, end
-- boss killed, realistic time, valid group, splits in order, fresh (live).
local _, ns = ...
local Sync = {}
ns.RunsSync = Sync
local Comm, Names, L, Data = ns.Comm, ns.Names, ns.L, ns.RunsData

local MAX_RECORDS, PER_WING = 400, 15
local LIVE = 1800          -- live records are at most 30 min old
local FUTURE = 120

local function store()
    local g = ns.Database.Guild()
    g.runs = g.runs or {}
    g.runs.list = g.runs.list or {}
    return g.runs
end
function Sync.List() return store().list end

---------------------------------------------------------------------------
-- Plausibility: returns true or false, reason
---------------------------------------------------------------------------
local ROLES = { T = true, H = true, D = true }
function Sync.Valid(r, sender, live)
    if type(r) ~= "table" then return false, "no record" end
    if type(r.id) ~= "string" or #r.id > 80 then return false, "id" end
    local wing = Data.BY_KEY[r.w]
    if not wing then return false, "unknown wing" end
    if r.i ~= wing.inst or r.k ~= wing.kind then return false, "instance" end
    if not ns.Num(r.raw) or r.raw < Data.MinTime(r.w) or r.raw > 6 * 3600 then return false, "time" end
    if not ns.Num(r.d) or r.d < 0 or r.d > 500 or r.d % 1 ~= 0 then return false, "deaths" end
    if not ns.Num(r.t) or r.t > ns.Now() + FUTURE then return false, "date" end
    if live and r.t < ns.Now() - LIVE then return false, "too old" end
    -- splits: in order, inside the run, the last one is the end of the run
    if type(r.s) ~= "table" or #r.s < 1 or #r.s > 40 then return false, "splits" end
    local prev = 0
    for _, sp in ipairs(r.s) do
        if type(sp) ~= "table" or not ns.Num(sp.s) or type(sp.b) ~= "string" or #sp.b > 60 then return false, "split" end
        -- every boss belongs to the wing (names from the shared data, the same on every client)
        if not Data.InWing(r.w, sp) then return false, "boss not in this instance" end
        if sp.s < prev or sp.s > r.raw + 5 then return false, "split order" end
        prev = sp.s
    end
    local last = r.s[#r.s]
    if math.abs(last.s - r.raw) > 10 then return false, "end" end
    -- the last split is the end boss of the wing
    if not Data.IsFinal(r.w, last) then return false, "end boss" end
    -- the group
    if type(r.g) ~= "table" then return false, "group" end
    local n = #r.g
    if wing.kind == "party" and (n < 1 or n > 5) then return false, "group size" end
    if wing.kind == "raid" and (n < 5 or n > 40) then return false, "group size" end
    local inGroup = false
    for _, m in ipairs(r.g) do
        if type(m) ~= "table" or type(m.k) ~= "string" or #m.k > 40 or not ROLES[m.r] then return false, "member" end
        if m.c ~= nil and (type(m.c) ~= "string" or #m.c > 12) then return false, "class" end
        if sender and Names.Same(m.k, sender) then inGroup = true end
    end
    if sender and live then
        if not inGroup then return false, "sender not in group" end
        if not Names.Same(r.by, sender) then return false, "author" end
    end
    return true
end

-- a stored copy with only known fields (strings cut, no extra data)
local function clean(r)
    r = ns.Clean(r, 4)
    if type(r) ~= "table" then return nil end
    local out = { id = r.id, w = r.w, i = r.i, k = r.k, t = r.t, raw = r.raw, d = r.d, by = r.by, v = r.v, s = {}, g = {} }
    for i, sp in ipairs(type(r.s) == "table" and r.s or {}) do
        if i > 40 then break end
        if type(sp) == "table" then out.s[#out.s + 1] = { e = tonumber(sp.e) or 0, b = sp.b, s = sp.s } end
    end
    for i, m in ipairs(type(r.g) == "table" and r.g or {}) do
        if i > 40 then break end
        if type(m) == "table" then
            local dps = type(m.dps) == "number" and m.dps or nil
            out.g[#out.g + 1] = { k = m.k, c = m.c, r = m.r, dps = dps, hps = type(m.hps) == "number" and m.hps or nil }
        end
    end
    return out
end
Sync.Clean = clean

local function memberSig(r)
    local keys = {}
    for _, m in ipairs(r.g or {}) do keys[#keys + 1] = m.k end
    table.sort(keys)
    return table.concat(keys, ",")
end

-- the same run recorded by several members: same wing, same group, about the same time
local function duplicate(r)
    local sig = memberSig(r)
    for _, o in ipairs(store().list) do
        if o.id == r.id then return o end
        if o.w == r.w and math.abs((o.t or 0) - (r.t or 0)) < 900 and memberSig(o) == sig then return o end
    end
end

local function prune()
    local list = store().list
    local byWing = {}
    for _, r in ipairs(list) do byWing[r.w] = byWing[r.w] or {}; table.insert(byWing[r.w], r) end
    local keep = {}
    for _, rs in pairs(byWing) do
        table.sort(rs, function(a, b) return a.raw + a.d * 5 < b.raw + b.d * 5 end)
        for i, r in ipairs(rs) do if i <= PER_WING then keep[r] = true end end
    end
    for i = #list, 1, -1 do if not keep[list[i]] then table.remove(list, i) end end
    table.sort(list, function(a, b) return (a.t or 0) < (b.t or 0) end)
    while #list > MAX_RECORDS do table.remove(list, 1) end
end

-- rank of a record in its wing (1 = guild record), nil when not in the top 10
function Sync.Rank(r)
    for i, o in ipairs(ns.Runs.Records(r.w, "guild")) do
        if i > 10 then return nil end
        if o == r or o.id == r.id then return i end
    end
end

-- stores a record; own records (from Runs.Finish) are shared when they made the list
function Sync.AddRecord(r, own)
    r = clean(r)
    if not r or not Sync.Valid(r) then return false end
    if duplicate(r) then return false end
    local list = store().list
    list[#list + 1] = r
    prune()
    ns.Fire("LG_RUNS")
    if own and Sync.Rank(r) then Sync.Share(r) end
    return true
end

---------------------------------------------------------------------------
-- Sending: one sender per group (the addon user with the lowest name)
---------------------------------------------------------------------------
function Sync.IsSender(r)
    local me = Names.Me()
    local best = me
    for _, m in ipairs(r.g or {}) do
        local h = ns.Versions and ns.Versions.heard[m.k]
        if h and ns.Now() - (h.t or 0) < 4 * 3600 and m.k < best then best = m.k end
    end
    return best == me
end

function Sync.Share(r)
    if not ns.Runs.Settings().share or not IsInGuild() or not Sync.IsSender(r) then return false end
    local copy = clean(r)
    copy.by = Names.Me()
    Comm.Send("SR", { r = copy }, "GUILD", { priority = "normal" })
    return true
end

local function newGuildRecord(r)
    local best = ns.Runs.Best(r.w, "guild")
    if best and best.id == r.id and ns.Runs.Settings().announce then
        local kicker = L.RUN_NEW_GUILD
        ns.UI.Toast(kicker, L.RUN_TOAST_TEXT:format(Data.Name(r.w), ns.Runs.Format(ns.Runs.Final(r))), nil,
            { kicker = kicker, lines = { L.RUN_TOAST_BY:format(Names.Display(r.by or "?")) },
              action = function() ns.Window.Show("runs") end, actionText = L.RUN_TOAST_CLICK, page = "runs" })
    end
end

Sync.rejected = {}
Comm.Register("SR", function(data, sender, channel)
    if channel ~= "GUILD" or not ns.Guild.IsMember(sender) or not ns.Runs.Settings().accept then return end
    local r = clean(data.r)
    local ok, why = Sync.Valid(r, sender, true)
    if not ok then
        Sync.rejected[#Sync.rejected + 1] = { by = sender, why = why, t = ns.Now() }
        while #Sync.rejected > 20 do table.remove(Sync.rejected, 1) end
        return
    end
    if Sync.AddRecord(r) then newGuildRecord(r) end
end)

---------------------------------------------------------------------------
-- Login sync
---------------------------------------------------------------------------
local function newest()
    local t = 0
    for _, r in ipairs(store().list) do if (r.t or 0) > t then t = r.t end end
    return t
end

Comm.Register("SRQ", function(data, sender, channel, raw)
    if channel ~= "GUILD" or not ns.Guild.IsMember(sender) then return end
    local since = tonumber(data.n) or 0
    local list = {}
    for _, r in ipairs(store().list) do if (r.t or 0) > since then list[#list + 1] = r end end
    if #list == 0 then return end
    Comm.ReplyOnce("runs:" .. sender, 3, 12, function()
        Comm.Send("SRA", { to = sender }, "GUILD", { priority = "bulk" })
        for i = 1, #list, 4 do
            Comm.Send("SRB", { r = { unpack(list, i, math.min(#list, i + 3)) } }, "WHISPER", { target = raw, priority = "bulk" })
        end
    end)
end)
Comm.Register("SRA", function(data, sender)
    if not data.to then return end
    Comm.Answered("runs:" .. data.to)
    if Names.Same(data.to, Names.Me()) then Comm.Expected("runs-sync", sender) end
end)
Comm.Register("SRB", function(data, sender, channel)
    if channel ~= "WHISPER" or type(data.r) ~= "table" or not ns.Guild.IsMember(sender) then return end
    if not Comm.Expected("runs-sync", sender) then return end
    for i, r in ipairs(data.r) do
        if i > 4 then break end
        r = clean(r)
        if r and Sync.Valid(r) then Sync.AddRecord(r) end
    end
end)

function Sync.Ask()
    if not IsInGuild() or ns.Database.Settings().modules.runs == false then return end
    Comm.Expect("runs-sync", 180)
    Comm.Send("SRQ", { n = newest() }, "GUILD", { priority = "bulk" })
end
ns.On("LG_READY", function() ns.After(65, Sync.Ask) end)

---------------------------------------------------------------------------
-- Damage meter: Forever blocks the combat log for addons. If the client has
-- its own damage meter API, it is read here; otherwise DPS/HPS stay empty.
---------------------------------------------------------------------------
local Meter = {}
ns.RunsMeter = Meter
function Meter.Available() return type(C_DamageMeter) == "table" end
function Meter.Read()
    -- prepared: the API of the built-in meter is not known yet (see /lg test runs)
    return nil
end
function Meter.Report()
    if not Meter.Available() then print("  damage meter API: none (DPS/HPS stay empty)"); return end
    local names = {}
    for k, v in pairs(C_DamageMeter) do if type(v) == "function" then names[#names + 1] = k end end
    table.sort(names)
    print("  damage meter API: C_DamageMeter." .. table.concat(names, ", C_DamageMeter."))
end
