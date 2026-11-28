-- Speedruns: dungeon (and raid) runs from the first pull to the end boss.
-- A run is armed when you enter a known instance and starts with the first
-- fight (option: when entering). Every boss kill is a split; the end boss
-- (Modules/Runs/Data.lua) finishes it. Deaths in the group are counted
-- (Modules/DeathWatch.lua) and can add a penalty to the time (setting).
-- The run survives /reload and short trips outside (30 min).
--   char.runs.active   the run in progress
--   char.runs.history  own finished runs (newest last, 100)
-- Guild records, plausibility and sync: Modules/Runs/Sync.lua.
local _, ns = ...
local Runs = ns.NewModule("runs")
ns.Runs = Runs
local L, Names, Data = ns.L, ns.Names, ns.RunsData

local CONTINUE = 1800     -- back inside within 30 min: the same run
local MAX_HISTORY = 100

function Runs.Settings()
    local s = ns.Database.Settings()
    s.runs = s.runs or {}
    local r = s.runs
    local defaults = { enabled = true, raids = true, startOn = "pull", penalty = 0, compare = "guild", timer = false,
        splits = true, hideCombat = false, share = true, announce = true, accept = true, scale = 1, rows = 6 }
    for k, v in pairs(defaults) do if r[k] == nil then r[k] = v end end
    r.learned = nil
    -- 1.0.90 (Ben): the timer is off by default (once for everyone)
    if not r.timerOff then r.timerOff = true; r.timer = false end
    return r
end

local function on() return ns.Database.Settings().modules.runs ~= false and Runs.Settings().enabled end

function Runs.Store()
    local char = ns.Database.Char()
    char.runs = char.runs or {}
    char.runs.history = char.runs.history or {}
    return char.runs
end
function Runs.Active() return Runs.Store().active end

-- the penalty that counts for displayed times (own setting, same for every record)
function Runs.Penalty() return math.max(0, math.min(60, tonumber(Runs.Settings().penalty) or 0)) end
-- final time of a record: raw time plus penalty per death
function Runs.Final(r) return (r.raw or 0) + (r.d or 0) * Runs.Penalty() end

function Runs.Format(sec)
    sec = math.max(0, math.floor((sec or 0) + 0.5))
    local h, m, s = math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60
    if h > 0 then return ("%d:%02d:%02d"):format(h, m, s) end
    return ("%d:%02d"):format(m, s)
end
-- "-0:14" / "+0:08"
function Runs.Delta(sec)
    if not sec then return "" end
    local sign = sec < 0 and "-" or "+"
    return sign .. Runs.Format(math.abs(sec))
end

---------------------------------------------------------------------------
-- The group: key, class, role (T/H/D)
---------------------------------------------------------------------------
local ROLE = { TANK = "T", HEALER = "H", DAMAGER = "D" }
function Runs.Group()
    local list = {}
    for unit, key in ns.GroupUnits() do
        local _, class = ns.Call(UnitClass, unit)
        local role = ROLE[ns.Call(UnitGroupRolesAssigned, unit) or ""]
        if not role and Names.Same(key, Names.Me()) and ns.QoL and ns.QoL.WantedRole then role = ROLE[ns.QoL.WantedRole() or ""] end
        list[#list + 1] = { k = key, c = type(class) == "string" and class or nil, r = role or "D" }
    end
    if #list == 0 then
        local _, class = ns.Call(UnitClass, "player")
        list[1] = { k = Names.Me(), c = class, r = "D" }
    end
    table.sort(list, function(a, b) return a.k < b.k end)
    return list
end

---------------------------------------------------------------------------
-- Instance tracking
---------------------------------------------------------------------------
local function here()
    local inside, kind = ns.Call(IsInInstance)
    if inside ~= true or (kind ~= "party" and kind ~= "raid") then return nil end
    local name, _, _, _, _, _, _, inst = ns.Call(GetInstanceInfo)
    if not ns.Num(inst) then return nil end
    return inst, kind, type(name) == "string" and name or nil
end
Runs.Here = here

local function closeLeftover(run)
    -- unfinished runs with kills stay in the history (not on any leaderboard)
    if run and not run.fin and #(run.s or {}) > 0 and run.start then
        run.raw = (run.last or ns.Now()) - run.start
        run.t = run.last or ns.Now()
        run.ok = false
        Runs.AddHistory(run)
    end
end

function Runs.AddHistory(rec)
    local h = Runs.Store().history
    h[#h + 1] = rec
    while #h > MAX_HISTORY do table.remove(h, 1) end
    ns.Fire("LG_RUNS")
end

function Runs.Check()
    local store = Runs.Store()
    local run = store.active
    local inst, kind, name = here()
    -- only instances with known bosses (Modules/Runs/Data.lua)
    if not on() or not inst or not Data.BY_INST[inst] or (kind == "raid" and not Runs.Settings().raids) then
        if run then
            run.out = run.out or ns.Now()
            if run.fin or ns.Now() - run.out > CONTINUE then closeLeftover(run); store.active = nil end
        end
        ns.Fire("LG_RUNS")
        return
    end
    if run and run.i == inst and not run.fin and (not run.out or ns.Now() - run.out < CONTINUE) then
        run.out = nil
        ns.Fire("LG_RUNS")
        return
    end
    closeLeftover(run)
    run = { id = ("%s:%d:%d"):format(Names.Me() or "?", inst, ns.Now()), i = inst, k = kind, n = name or Data.InstanceName(inst),
        s = {}, d = 0, dk = {}, entered = ns.Now(), v = ns.version }
    store.active = run
    if ns.Stats and ns.Stats.NewRun then ns.Stats.NewRun() end
    if Runs.Settings().startOn == "enter" then Runs.Start() end
    ns.Fire("LG_RUNS")
end

function Runs.Start()
    local run = Runs.Active()
    if not run or run.start or run.fin then return end
    run.start = ns.Now()
    run.startGT = GetTime()
    run.g = Runs.Group()
    ns.Fire("LG_RUNS")
end

-- seconds since the start (GetTime precision within the session)
function Runs.Elapsed(run)
    run = run or Runs.Active()
    if not run or not run.start then return 0 end
    if run.fin then return run.raw or 0 end
    if run.startGT and run.startGT <= GetTime() then
        local sess = GetTime() - run.startGT
        -- after a /reload startGT is gone; server time is the truth then
        if math.abs(sess - (ns.Now() - run.start)) < 5 then return sess end
    end
    return ns.Now() - run.start
end

ns.On("PLAYER_ENTERING_WORLD", function() ns.After(2, Runs.Check) end)
ns.On("ZONE_CHANGED_NEW_AREA", function() ns.After(2, Runs.Check) end)
ns.On("PLAYER_REGEN_DISABLED", function()
    local run = Runs.Active()
    if run and not run.start and here() == run.i then Runs.Start() end
end)

---------------------------------------------------------------------------
-- Bosses and deaths
---------------------------------------------------------------------------
ns.On("ENCOUNTER_START", function(_, encounterID)
    local run = Runs.Active()
    if not run or run.fin or ns.IsSecret(encounterID) then return end
    if not run.start then Runs.Start() end
    run.p = run.p or {}
    local key = tostring(encounterID)
    run.p[key] = (run.p[key] or 0) + 1
end)

-- a boss died: by its encounter (ENCOUNTER_END) or seen dead (NPC ID). Splits use
-- the English boss name of the data, the same on every client.
function Runs.Kill(encounterID, name, npcID)
    local run = Runs.Active()
    if not run or run.fin or not run.start then return end
    local boss = Data.Boss(run.i, encounterID, name, npcID)
    if not boss then return end
    for _, sp in ipairs(run.s) do if sp.b == boss.n then return end end
    local t = math.floor(Runs.Elapsed(run) + 0.5)
    run.s[#run.s + 1] = { e = ns.Num(encounterID) and encounterID or 0, b = boss.n, s = t }
    run.last = ns.Now()
    -- the wing: the one of the first boss (wings of one instance share no boss)
    run.w = run.w or boss.wing.key
    if boss.final then Runs.Finish(boss.wing) else ns.Fire("LG_RUNS") end
end

---------------------------------------------------------------------------
-- Bosses without ENCOUNTER_END: seen dead as target, focus or boss frame, a
-- kill of the group (PARTY_KILL) or a corpse we loot. The unit events are
-- registered only while a run goes on inside its instance.
---------------------------------------------------------------------------
local watch = CreateFrame("Frame")
local watching = false
local UNITS = { { "target", "focus" }, { "boss1", "boss2" }, { "boss3", "boss4" }, { "boss5", "mouseover" } }
local unitFrames = {}
for i = 1, #UNITS do unitFrames[i] = CreateFrame("Frame") end

local function checkUnit(unit)
    if ns.Call(UnitIsDead, unit) ~= true then return end
    local npc = Data.NpcFromGuid(ns.Call(UnitGUID, unit))
    if npc then Runs.Kill(nil, nil, npc) end
end
for _, f in ipairs(unitFrames) do f:SetScript("OnEvent", function(_, _, unit) ns.Safe(checkUnit, unit) end) end
watch:SetScript("OnEvent", function(_, event, ...)
    if event == "PARTY_KILL" then
        local _, guid = ...
        local npc = Data.NpcFromGuid(guid)
        if npc then ns.Safe(Runs.Kill, nil, nil, npc) end
    elseif event == "PLAYER_TARGET_CHANGED" then
        ns.Safe(checkUnit, "target")
    end
end)

function Runs.Watch(on)
    if on == watching then return end
    watching = on
    if on then
        for i, pair in ipairs(UNITS) do
            if unitFrames[i].RegisterUnitEvent then pcall(unitFrames[i].RegisterUnitEvent, unitFrames[i], "UNIT_HEALTH", pair[1], pair[2]) end
        end
        pcall(watch.RegisterEvent, watch, "PARTY_KILL")
        watch:RegisterEvent("PLAYER_TARGET_CHANGED")
    else
        for _, f in ipairs(unitFrames) do f:UnregisterAllEvents() end
        watch:UnregisterAllEvents()
    end
end

-- loot from a corpse: whose corpse (only during a run)
ns.On("LOOT_OPENED", function()
    if not watching or not GetLootSourceInfo then return end
    for slot = 1, (ns.Call(GetNumLootItems) or 0) do
        local src = { ns.Call(GetLootSourceInfo, slot) }
        for i = 1, #src, 2 do
            local npc = Data.NpcFromGuid(src[i])
            if npc then Runs.Kill(nil, nil, npc) end
        end
    end
end)

ns.On("LG_RUNS", function()
    local run = Runs.Active()
    Runs.Watch(run ~= nil and run.start ~= nil and not run.fin and Runs.Here() == run.i)
end)

ns.On("ENCOUNTER_END", function(_, encounterID, name, _, _, success)
    if ns.IsSecret(success) or ns.IsSecret(name) or success ~= 1 then return end
    Runs.Kill(encounterID, name)
end)

function Runs.Died(key)
    local run = Runs.Active()
    if not run or run.fin or not run.start or not key then return end
    if here() ~= run.i then return end
    run.d = (run.d or 0) + 1
    run.dk[key] = (run.dk[key] or 0) + 1
    ns.Fire("LG_RUNS")
end
ns.On("LG_DEATH", function(_, key) Runs.Died(key) end)
-- alone there is no group to watch
ns.On("PLAYER_DEAD", function() if not IsInGroup() then Runs.Died(Names.Me()) end end)

---------------------------------------------------------------------------
-- Finish
---------------------------------------------------------------------------
-- the record that is shared and stored (no session fields)
function Runs.Record(run)
    return { id = run.id, w = run.w, i = run.i, k = run.k, t = run.t, raw = run.raw, d = run.d or 0, s = run.s, g = run.g,
        by = Names.Me(), v = run.v or ns.version, ok = run.ok, dps = run.dps }
end

function Runs.Finish(wing)
    local run = Runs.Active()
    if not run or run.fin then return end
    -- the time is the end boss split (the same second for everyone in the group)
    local last = run.s[#run.s]
    run.raw = last and last.s or math.floor(Runs.Elapsed(run) + 0.5)
    run.fin = true
    run.w = wing.key
    run.t = ns.Now()
    -- the group at the end (who joined late counts too)
    local g = Runs.Group()
    if #g >= #(run.g or {}) then run.g = g end
    if ns.RunsMeter then run.dps = ns.RunsMeter.Read(run) end
    local rec = Runs.Record(run)
    rec.ok = ns.RunsSync.Valid(rec) == true
    run.ok = rec.ok
    local pbBefore = Runs.Best(rec.w, "pb")
    Runs.AddHistory(rec)
    Runs.Store().active = nil
    if rec.ok then
        local guildBefore = Runs.Best(rec.w, "guild")
        ns.RunsSync.AddRecord(rec, true)
        Runs.Celebrate(rec, pbBefore, guildBefore)
        if ns.Achievements then ns.Achievements.RunFinished(rec, pbBefore) end
    end
    ns.Fire("LG_RUNS")
    return rec
end

-- toast for a new personal best / guild record
function Runs.Celebrate(rec, pb, guild)
    if not Runs.Settings().announce then return end
    local final = Runs.Final(rec)
    local isGuild = not guild or final < Runs.Final(guild)
    local isPb = not pb or final < Runs.Final(pb)
    if not isGuild and not isPb then return end
    local ref = isGuild and guild or pb
    local kicker = isGuild and L.RUN_NEW_GUILD or L.RUN_NEW_PB
    local lines = { L.RUN_TOAST_DEATHS:format(rec.d or 0) }
    if ref then lines[#lines + 1] = L.RUN_TOAST_BEAT:format(Runs.Format(Runs.Final(ref) - final)) end
    ns.UI.Toast(kicker, L.RUN_TOAST_TEXT:format(Data.Name(rec.w), Runs.Format(final)), nil,
        { kicker = kicker, big = true, lines = lines, sound = "milestone",
          action = function() ns.Window.Show("runs") end, actionText = L.RUN_TOAST_CLICK, page = "runs" })
end

---------------------------------------------------------------------------
-- Records: own history and guild list
---------------------------------------------------------------------------
-- verified records of a wing: "pb" (own, all characters of the account) or "guild"
function Runs.Records(wing, which)
    local out = {}
    if which == "pb" then
        for _, char in pairs(ns.db.chars or {}) do
            for _, r in ipairs(type(char.runs) == "table" and char.runs.history or {}) do
                if r.ok and (not wing or r.w == wing) then out[#out + 1] = r end
            end
        end
    else
        for _, r in ipairs(ns.RunsSync.List()) do
            if not wing or r.w == wing then out[#out + 1] = r end
        end
    end
    table.sort(out, function(a, b)
        local fa, fb = Runs.Final(a), Runs.Final(b)
        if fa ~= fb then return fa < fb end
        return (a.t or 0) < (b.t or 0)
    end)
    return out
end

function Runs.Best(wing, which) return Runs.Records(wing, which)[1] end

-- the run to compare splits with: the best record of the same instance that
-- has every boss we killed so far (wing still unknown in shared instances)
function Runs.Reference(run)
    run = run or Runs.Active()
    if not run then return nil end
    local best
    local which = Runs.Settings().compare
    for _, w in ipairs(Data.BY_INST[run.i] or {}) do
        for _, r in ipairs(Runs.Records(w.key, which)) do
            local has = {}
            for _, sp in ipairs(r.s or {}) do has[sp.b] = sp.s end
            local fits = true
            for _, sp in ipairs(run.s or {}) do if not has[sp.b] then fits = false; break end end
            if fits and (not best or Runs.Final(r) < Runs.Final(best)) then best = r end
            if fits then break end
        end
    end
    return best
end

-- split time of a boss (English name) in a record
function Runs.SplitOf(rec, boss)
    for _, sp in ipairs(rec and rec.s or {}) do if sp.b == boss then return sp.s end end
end

---------------------------------------------------------------------------
-- Sharing a record in chat and for Discord (click only)
---------------------------------------------------------------------------
local function members(rec)
    local by = { T = {}, H = {}, D = {} }
    for _, m in ipairs(rec.g or {}) do table.insert(by[m.r] or by.D, Names.Display(m.k)) end
    return by
end

function Runs.ChatLine(rec)
    local by = members(rec)
    local list = {}
    for _, r in ipairs({ "T", "H", "D" }) do for _, n in ipairs(by[r]) do list[#list + 1] = (n:match("^(%S+)") or n) end end
    local line = L.RUN_CHAT:format(Data.Name(rec.w), Runs.Format(Runs.Final(rec)), rec.d or 0, table.concat(list, ", "))
    if #line > 250 then line = line:sub(1, 247) .. "..." end
    return line
end

function Runs.Post(rec, chatType)
    if chatType == "PARTY" and not IsInGroup() then ns.Print(L.NOT_IN_GROUP); return false end
    return ns.SendChat(Runs.ChatLine(rec), chatType)
end

function Runs.DiscordText(rec, plain)
    local by = members(rec)
    local b = plain and "" or "**"
    local lines = {
        ("%s%s – %s%s"):format(b, ns.title or "Liebe Grüße", L.RUN_DISCORD_HEAD, b),
        ("%s%s%s in %s%s%s (%s)"):format(b, Data.Name(rec.w), b, b, Runs.Format(Runs.Final(rec)), b,
            L.RUN_DISCORD_DEATHS:format(rec.d or 0, Runs.Penalty())),
        date("%d.%m.%Y %H:%M", rec.t or 0),
        "",
        L.RUN_SPLITS,
    }
    if not plain then lines[#lines + 1] = "```" end
    for _, sp in ipairs(rec.s or {}) do
        local name = sp.b or "?"
        lines[#lines + 1] = ("%-26s %8s"):format(name:sub(1, 26), Runs.Format(sp.s))
    end
    if not plain then lines[#lines + 1] = "```" end
    local roles = {}
    for _, r in ipairs({ { "T", L.ROLE_TANK }, { "H", L.ROLE_HEAL }, { "D", L.ROLE_DPS } }) do
        if #by[r[1]] > 0 then roles[#roles + 1] = r[2] .. " " .. table.concat(by[r[1]], ", ") end
    end
    lines[#lines + 1] = table.concat(roles, " · ")
    return table.concat(lines, "\n")
end

function Runs.ShowDiscord(rec)
    ns.Share.ShowText(L.RUN_DISCORD_TITLE, L.COPY_HINT, Runs.DiscordText(rec))
end

---------------------------------------------------------------------------
-- /lg test runs [ids]
---------------------------------------------------------------------------
function Runs.Report(what)
    local run = Runs.Active()
    ns.Print(L.TEST_TAG .. " " .. L.RUN_REPORT)
    local inst, kind, name = here()
    print(("  here: %s %s (%s) · known: %s"):format(tostring(inst), tostring(name), tostring(kind), tostring(inst and Data.BY_INST[inst] ~= nil)))
    if run then
        print(("  run: %s · started %s · %s · %d splits · %d deaths"):format(tostring(run.n), tostring(run.start ~= nil),
            Runs.Format(Runs.Elapsed(run)), #run.s, run.d or 0))
        for _, sp in ipairs(run.s) do print(("    %s  [%s]  %s"):format(sp.b, tostring(sp.e), Runs.Format(sp.s))) end
    else
        print("  no run active")
    end
    if (what or ""):find("id") then
        local stats = ns.Database.Char().stats
        print("  encounter IDs seen (boss stats):")
        for bname, b in pairs(stats and stats.bosses or {}) do
            if b.id then print(("    %s = %d  (%s)"):format(bname, b.id, tostring(b.where))) end
        end
        print(("  fallback watch (NPC deaths): %s"):format(tostring(watching)))
    end
    if ns.RunsMeter then ns.RunsMeter.Report() end
end
