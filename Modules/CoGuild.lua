-- Partner guild: who of the partner guild is online, with level,
-- class and zone, remembered with "last seen". Works without any addon on the
-- other side: it uses the game's /who search for guild members (g-"Name").
-- A separate guild-to-guild chat addon keeps working next to it.
local _, ns = ...
local UI, Theme, L, Names, Comm = ns.UI, ns.Theme, ns.L, ns.Names, ns.Comm
local Co = ns.NewModule("coguild")
ns.CoGuild = Co

local QUERY_GAP = 30          -- seconds between automatic queries
local WHO_LIMIT = 50          -- the game returns at most 50 results

function Co.Settings()
    local s = ns.Database.Settings()
    s.coguild = s.coguild or {}
    local o = s.coguild
    if o.guilds == nil then o.guilds = "GaliGrü" end
    if o.onlineOnly == nil then o.onlineOnly = true end
    if o.notify == nil then o.notify = false end
    o.notes = o.notes or {}
    return o
end

local function store()
    local g = ns.Database.Guild()
    g.coguild = g.coguild or {}
    return g.coguild
end
Co.Store = store

-- partner guilds as seen from the current character: the configured ones plus
-- the home guild (on an alt in GaliGrü the partner is Liebe Grüße), never the own guild
function Co.Guilds()
    local list, seen = {}, {}
    local own = IsInGuild() and ns.Call(GetGuildInfo, "player")
    own = type(own) == "string" and own:lower() or nil
    local function add(name)
        name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local lower = name:lower()
        if name ~= "" and lower ~= own and not seen[lower] then seen[lower] = true; list[#list + 1] = name end
    end
    for name in (Co.Settings().guilds or ""):gmatch("[^,;]+") do add(name) end
    if ns.Account then add(ns.Account.Settings().homeGuild) end
    return list
end

Co.online = {}      -- [key] = true for the last completed query
Co.lastQuery = 0
Co.status = nil
local pending       -- guild names still to ask
local asking        -- guild currently asked

---------------------------------------------------------------------------
-- /who
---------------------------------------------------------------------------
local function whoCount()
    if C_FriendList and C_FriendList.GetNumWhoResults then return ns.Call(C_FriendList.GetNumWhoResults) or 0 end
    if GetNumWhoResults then return ns.Call(GetNumWhoResults) or 0 end
    return 0
end

local function whoInfo(i)
    if C_FriendList and C_FriendList.GetWhoInfo then
        local t = ns.Call(C_FriendList.GetWhoInfo, i)
        if type(t) == "table" then
            return t.fullName, t.fullGuildName, t.level, t.raceStr, t.classStr, t.area, t.filename
        end
    end
    if GetWhoInfo then return ns.Call(GetWhoInfo, i) end
end

-- keeps the friends/who window from popping up with our results: every other
-- frame listening to WHO_LIST_UPDATE is muted while we ask, then restored
local muted = {}
local listeners = {}   -- every frame ever seen listening to WHO_LIST_UPDATE (their windows are watched)
local function noteListeners()
    for _, f in pairs({ GetFramesRegisteredForEvent and GetFramesRegisteredForEvent("WHO_LIST_UPDATE") }) do
        if type(f) == "table" and f ~= ns.eventFrame then listeners[f] = true end
    end
end
local function quietFriendsFrame(on)
    if on then
        if #muted > 0 then return end
        noteListeners()
        local frames = { GetFramesRegisteredForEvent and GetFramesRegisteredForEvent("WHO_LIST_UPDATE") }
        if #frames == 0 then frames = { FriendsFrame, WhoFrame } end
        for _, f in pairs(frames) do
            if f and f ~= ns.eventFrame and f.UnregisterEvent then
                if pcall(f.UnregisterEvent, f, "WHO_LIST_UPDATE") then muted[#muted + 1] = f end
            end
        end
    else
        for _, f in ipairs(muted) do pcall(f.RegisterEvent, f, "WHO_LIST_UPDATE") end
        muted = {}
    end
end

-- Some clients open the friends/who window from code that does not listen to
-- WHO_LIST_UPDATE, and a late answer (after our timeout) opens it as well.
-- While we ask and up to LATE seconds after, a who/friends window that pops
-- up by itself is closed again – unless it was already open before.
local LATE = 60
local quietUntil, wasOpen, hooked = 0, {}, {}
Co.whoDiag = {}
local function diag(text)
    local d = Co.whoDiag
    d[#d + 1] = ("%.1f %s"):format(GetTime(), text)
    if #d > 12 then table.remove(d, 1) end
end
local function frameName(f)
    local ok, n = pcall(f.GetName, f)
    return ok and type(n) == "string" and n or "?"
end
-- the window a frame lives in: its last ancestor below UIParent
local function topLevel(f)
    local guard = 0
    while f and f.GetParent and guard < 20 do
        local ok, parent = pcall(f.GetParent, f)
        if not ok or not parent or parent == UIParent then return f end
        f, guard = parent, guard + 1
    end
    return f
end
local function whoWindows()
    local list, seen = {}, {}
    local function add(f)
        if type(f) == "table" and f.IsShown and not seen[f] then seen[f] = true; list[#list + 1] = f end
    end
    add(_G.FriendsFrame); add(_G.WhoFrame)
    for f in pairs(listeners) do add(f); add(topLevel(f)) end
    return list
end
local function whoish(f)
    if type(f) ~= "table" or not f.IsShown then return false end
    if f == _G.FriendsFrame or f == _G.WhoFrame or listeners[f] then return true end
    for l in pairs(listeners) do if topLevel(l) == f then return true end end
    local n = frameName(f)
    return n:find("Who", 1, true) ~= nil or n:find("Friends", 1, true) ~= nil
end
local function closeIfOurs(f, why)
    if GetTime() >= quietUntil or wasOpen[f] or not f:IsShown() then return end
    if HideUIPanel then pcall(HideUIPanel, f) end
    if f:IsShown() then pcall(f.Hide, f) end
    diag(("closed %s (%s)"):format(frameName(f), why or "show"))
end
local function hookFrame(f)
    if f and f.HookScript and not hooked[f] then
        hooked[f] = true
        f:HookScript("OnShow", function(self)
            if GetTime() < quietUntil then
                diag("shown " .. frameName(self) .. (wasOpen[self] and " (was open)" or ""))
                closeIfOurs(self, "OnShow")
                ns.After(0, function() closeIfOurs(self, "OnShow+") end)
            end
        end)
    end
end
local panelsHooked
local function hookPanels()
    if panelsHooked or not hooksecurefunc then return end
    panelsHooked = true
    local function onPanel(f, how)
        if GetTime() >= quietUntil then return end
        if not whoish(f) then
            if type(f) == "table" and f.GetName then diag(("%s %s (left open)"):format(how, frameName(f))) end
            return
        end
        diag(("%s %s"):format(how, frameName(f)))
        hookFrame(f)
        closeIfOurs(f, how)
        ns.After(0, function() closeIfOurs(f, how .. "+") end)
    end
    if ShowUIPanel then hooksecurefunc("ShowUIPanel", function(f) onPanel(f, "ShowUIPanel") end) end
    if ToggleFriendsFrame then
        hooksecurefunc("ToggleFriendsFrame", function() onPanel(_G.FriendsFrame, "ToggleFriendsFrame") end)
    end
    if FriendsFrame_ShowSubFrame then
        hooksecurefunc("FriendsFrame_ShowSubFrame", function() onPanel(_G.FriendsFrame, "ShowSubFrame") end)
    end
end
function Co.QuietWho(seconds, fresh)
    local was = GetTime() < quietUntil and not fresh
    quietUntil = math.max(quietUntil, GetTime() + seconds)
    noteListeners()
    hookPanels()
    for _, f in ipairs(whoWindows()) do
        if f and f.HookScript then
            -- open before we started asking → the player's own window, leave it
            if not was then wasOpen[f] = f:IsShown() and true or false end
            hookFrame(f)
        end
    end
end
local function closeNow(why)
    for _, f in ipairs(whoWindows()) do if f then closeIfOurs(f, why) end end
end
local lastAsk, lastGuild = 0, nil

local function sendWho(guild, first)
    asking = guild
    lastAsk, lastGuild = GetTime(), guild
    quietFriendsFrame(true)
    Co.QuietWho(LATE, first)
    diag("who " .. guild)
    if C_FriendList and C_FriendList.SetWhoToUi then ns.Call(C_FriendList.SetWhoToUi, true)
    elseif SetWhoToUI then ns.Call(SetWhoToUI, 1) end
    local filter = ('g-"%s"'):format(guild)
    local ok
    if C_FriendList and C_FriendList.SendWho then ok = pcall(C_FriendList.SendWho, filter)
    elseif SendWho then ok = pcall(SendWho, filter) end
    if not ok then
        asking = nil
        quietFriendsFrame(false)
        Co.status = L.CO_WHO_FAILED
        ns.Fire("LG_COGUILD")
        return
    end
    -- no answer (throttled): give the friends window its event back
    ns.After(15, function()
        if asking == guild then
            asking = nil
            quietFriendsFrame(false)
            diag("no answer " .. guild)
            quietUntil = GetTime() -- a late answer is caught in WHO_LIST_UPDATE
            Co.status = L.CO_WHO_BUSY
            ns.Fire("LG_COGUILD")
        end
    end)
end

-- /lg test who: what the game does with our /who
function Co.WhoReport()
    local frames = { GetFramesRegisteredForEvent and GetFramesRegisteredForEvent("WHO_LIST_UPDATE") }
    local names = {}
    for _, f in pairs(frames) do names[#names + 1] = frameName(f) end
    ns.Print(("Who: listeners %s · FriendsFrame %s · WhoFrame %s · asking %s · quiet %ds"):format(
        #names > 0 and table.concat(names, ", ") or "?", tostring(_G.FriendsFrame ~= nil), tostring(_G.WhoFrame ~= nil),
        tostring(asking), math.max(0, math.floor(quietUntil - GetTime()))))
    local watched = {}
    for _, f in ipairs(whoWindows()) do
        watched[#watched + 1] = frameName(f) .. (f:IsShown() and " (shown)" or "") .. (hooked[f] and "" or " (not hooked)")
    end
    ns.Print("  watched: " .. (#watched > 0 and table.concat(watched, ", ") or "none"))
    for _, l in ipairs(Co.whoDiag) do ns.Print("  " .. l) end
end

-- Starts a query for all partner guilds (call from a click: the game wants a key or mouse press for /who)
function Co.Query(force)
    if asking then return false end
    if not force and ns.Now() - Co.lastQuery < QUERY_GAP then return false end
    local guilds = Co.Guilds()
    if #guilds == 0 then Co.status = L.CO_NO_GUILD; ns.Fire("LG_COGUILD"); return false end
    Co.lastQuery = ns.Now()
    pending = {}
    for i = 2, #guilds do pending[#pending + 1] = guilds[i] end
    Co.seenNow = {}
    Co.status = L.CO_ASKING
    ns.Fire("LG_COGUILD")
    sendWho(guilds[1], true)
    return true
end

local function finish()
    Co.online = Co.seenNow or {}
    Co.seenNow = nil
    local n = 0
    for _ in pairs(Co.online) do n = n + 1 end
    Co.status = nil
    Co.lastCount = n
    ns.Fire("LG_COGUILD")
end

ns.On("WHO_LIST_UPDATE", function()
    local late = not asking and lastGuild and GetTime() - lastAsk < LATE
    if not asking and not late then return end
    local guild = asking or lastGuild
    asking = nil
    diag((late and "late answer " or "answer ") .. guild)
    quietUntil = math.max(quietUntil, GetTime() + 2)
    closeNow("answer")
    if late then
        -- the friends window got this event too: close it if it opened
        ns.After(0, function() closeNow("late") end)
        Co.seenNow = Co.seenNow or {}
    end
    local now = ns.Now()
    local n = whoCount()
    Co.truncated = n >= WHO_LIMIT
    local db = store()
    for i = 1, n do
        local name, gname, level, race, class, zone, classFile = whoInfo(i)
        if type(name) == "string" and type(gname) == "string" and gname:lower() == guild:lower() then
            local key = Names.Key(name)
            if key then
                local e = db[key] or { first = now }
                local oldLevel = e.level
                e.name, e.guild, e.level, e.race, e.class, e.zone, e.seen =
                    Names.Strip(name) or name, gname, tonumber(level) or e.level, race, classFile or e.class, zone, now
                db[key] = e
                Co.seenNow[key] = true
                if Co.Settings().notify and oldLevel and e.level and e.level > oldLevel and e.level % 10 == 0 then
                    UI.Toast(L.CO_TITLE, L.CO_LEVEL_UP:format(Names.Display(e.name), e.level), 136064)
                end
            end
        end
    end
    quietFriendsFrame(false)
    ns.After(0, function() closeNow("after answer") end)
    lastGuild = nil
    if late then finish(); return end
    if pending and #pending > 0 then
        local nextGuild = table.remove(pending, 1)
        ns.After(5, function() sendWho(nextGuild) end)
    else
        quietUntil = GetTime() + 2 -- the player may open the window himself afterwards
        finish()
    end
end)

---------------------------------------------------------------------------
-- Shared hidden channel ("Bund"): everyone with the addon in both guilds
-- reports when they are online (with level, zone, item level, spec, main).
-- Works without /who and also shows offline times.
--
-- The channel name and password come from a secret key. Officers (rank 0/1)
-- hand it out in the guild channel; a guild master without a key creates one.
-- Members of the partner guild get it from their own officers, from a twink
-- on the same account or by pasting it (Partner guild page → Key).
-- Until 1.0.44 name and password were fixed in the code – anyone with the
-- addon could join; that channel is left and never used again.
---------------------------------------------------------------------------
local HEARTBEAT, FRESH = 300, 420
local LEGACY_CHANNEL, LEGACY_PASSWORD = "LGBund", "liebegruesse"
local KEY_CHARS = "abcdefghijkmnpqrstuvwxyz23456789"
Co.presence = {}

local function bundSettings()
    local o = Co.Settings()
    if o.bund == nil then o.bund = true end
    if o.password == LEGACY_PASSWORD or o.channel == LEGACY_CHANNEL then
        o.password, o.channel, o.legacy = nil, nil, true
    end
    return o
end
Co.BundSettings = bundSettings

local function validKey(k) return type(k) == "string" and #k >= 12 and #k <= 32 and not k:find("[^%w]") end
Co.ValidKey = validKey

-- short, stable hash for the channel name (djb2, 32 bit, base 36)
local function hash(text)
    local h = 5381
    for i = 1, #text do h = (h * 33 + text:byte(i)) % 4294967296 end
    local digits, out = "0123456789abcdefghijklmnopqrstuvwxyz", ""
    for _ = 1, 7 do
        local n = h % 36
        out = digits:sub(n + 1, n + 1) .. out
        h = math.floor(h / 36)
    end
    return out
end

function Co.ChannelName()
    local key = bundSettings().key
    if not validKey(key) then return nil end
    return "LGB" .. hash("bund:" .. key)
end

function Co.ChannelId()
    local o = bundSettings()
    local name = Co.ChannelName()
    if not o.bund or not name or not GetChannelName then return nil end
    local id = ns.Call(GetChannelName, name)
    return (type(id) == "number" and id > 0) and id or nil
end

local function hideChannel(name)
    -- the channel carries only addon data: keep it out of every chat window
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame" .. i]
        if f and ChatFrame_RemoveChannel then pcall(ChatFrame_RemoveChannel, f, name) end
    end
end

local function myPresence(on)
    local me = Names.Unit("player")
    if not me then return nil end
    local _, class = ns.Call(UnitClass, "player")
    local m = ns.Database.Member(Names.Me()) or {}
    local guild = IsInGuild() and ns.Call(GetGuildInfo, "player") or nil
    local zone = GetRealZoneText and ns.Call(GetRealZoneText) or nil
    local profs = {}
    for _, p in ipairs(m.pr or {}) do profs[#profs + 1] = tostring(p.n) .. ":" .. tostring(p.s or "") end
    return { n = me, g = guild, c = class, l = ns.Call(UnitLevel, "player"), z = zone, il = m.il, sp = m.sp, m = m.m,
        v = ns.version, pr = table.concat(profs, ","), on = on ~= false and true or false }
end

function Co.Announce(on)
    local p = myPresence(on)
    if p then Comm.Send("BP", p, "BUND", { priority = on == false and "alert" or "bulk" }) end
end

local keyAsked = 0
function Co.RequestKey()
    if not IsInGuild() or GetTime() - keyAsked < 300 then return end
    keyAsked = GetTime()
    local o = bundSettings()
    Comm.Send("BKQ", { t = o.keyT or 0, has = validKey(o.key) }, "GUILD", { priority = "bulk" })
end

local function joinBund()
    local o = bundSettings()
    if o.legacy then
        -- the old public channel: leave it for good
        o.legacy = nil
        if LeaveChannelByName then pcall(LeaveChannelByName, LEGACY_CHANNEL) end
    end
    if not o.bund then return end
    local name = Co.ChannelName()
    if not name then Co.RequestKey(); ns.Fire("LG_COGUILD"); return end
    if not Co.ChannelId() then
        if JoinTemporaryChannel then pcall(JoinTemporaryChannel, name, o.key)
        elseif JoinChannelByName then pcall(JoinChannelByName, name, o.key) end
    end
    ns.After(2, function()
        hideChannel(name)
        if Co.ChannelId() then
            Co.Announce(true)
            Comm.Send("BH", {}, "BUND", { priority = "bulk" })
        end
        ns.Fire("LG_COGUILD")
    end)
end
Co.Join = joinBund

function Co.Leave()
    local name = Co.ChannelName()
    if name and Co.ChannelId() and LeaveChannelByName then pcall(LeaveChannelByName, name) end
end

-- t: when the key was made (newer keys from officers replace older ones; 0 = pasted by hand)
function Co.SetKey(key, t, share)
    if not validKey(key) then return false end
    local o = bundSettings()
    local same = o.key == key
    if not same then
        local oldName = Co.ChannelName()
        if oldName and LeaveChannelByName and GetChannelName and (ns.Call(GetChannelName, oldName) or 0) > 0 then
            pcall(LeaveChannelByName, oldName)
        end
        wipe(Co.presence)
    end
    o.key, o.keyT = key, tonumber(t) or 0
    if share and IsInGuild() then Comm.Send("BK", { key = key, t = o.keyT }, "GUILD", { priority = "normal" }) end
    if not same then ns.After(1, joinBund) end
    ns.Fire("LG_COGUILD")
    return true
end

function Co.CanManageKey() return IsInGuild() and ns.Guild.IsOfficer(Names.Me()) end

function Co.NewKey()
    if not Co.CanManageKey() then ns.Print(L.CO_KEY_OFFICERS); return false end
    local t = {}
    for i = 1, 20 do
        local n = math.random(1, #KEY_CHARS)
        t[i] = KEY_CHARS:sub(n, n)
    end
    Co.SetKey(table.concat(t), ns.Now(), true)
    ns.Print(L.CO_KEY_NEW)
    return true
end

-- key from an officer of our own guild (rank checked in our roster)
Comm.Register("BK", function(data, sender, channel)
    if channel ~= "GUILD" and channel ~= "WHISPER" then return end
    if not ns.Guild.IsOfficer(sender) or not validKey(data.key) then return end
    local o = bundSettings()
    local t = tonumber(data.t) or 0
    if validKey(o.key) and t <= (o.keyT or 0) then return end
    local changed = o.key ~= data.key
    Co.SetKey(data.key, t)
    if changed then ns.Print(L.CO_KEY_RECEIVED:format(Names.Display(sender))) end
end)

-- a member asks for the key: officers with a newer one answer by whisper
Comm.Register("BKQ", function(data, sender, channel, raw)
    if channel ~= "GUILD" or not Co.CanManageKey() then return end
    local o = bundSettings()
    if not validKey(o.key) then return end
    if data.has and (tonumber(data.t) or 0) >= (o.keyT or 0) then return end
    ns.After(1 + math.random() * 4, function()
        Comm.Send("BK", { key = o.key, t = o.keyT or 0 }, "WHISPER", { target = raw, priority = "normal" })
    end)
end)

-- the name in the data must be the real sender (no speaking for others)
function Co.PresenceOk(p, sender)
    if type(p) ~= "table" or type(p.n) ~= "string" then return false end
    local key = Names.Key(p.n)
    return key ~= nil and Names.Same(key, sender) and not Names.Same(key, Names.Me())
end

local function takePresence(p, sender)
    if type(p) ~= "table" then return end
    p = ns.Clean(p, 1)
    if not Co.PresenceOk(p, sender) then return end
    local key = Names.Key(p.n)
    local now = ns.Now()
    if p.on == false then
        Co.presence[key] = nil
    else
        Co.presence[key] = { name = p.n, guild = p.g, class = p.c, level = tonumber(p.l), zone = p.z, il = tonumber(p.il),
            sp = p.sp, main = p.m, v = p.v, pr = p.pr, t = now }
    end
    -- remember everyone from the other guilds for the partner list
    local own = IsInGuild() and ns.Call(GetGuildInfo, "player")
    if type(p.g) == "string" and not (type(own) == "string" and own:lower() == p.g:lower()) then
        local db = store()
        local e = db[key] or { first = now }
        e.name, e.guild, e.level, e.class, e.zone, e.seen = p.n, p.g, tonumber(p.l) or e.level, p.c or e.class, p.z or e.zone, now
        e.addon = true
        db[key] = e
    end
    ns.Debounce("coguild-presence", 1, function() ns.Fire("LG_COGUILD"); ns.Fire("LG_PRESENCE") end)
end

Comm.Register("BP", function(data, sender) takePresence(data, sender) end, { channel = true })
-- someone joined: everybody answers with their own presence (spread over a few seconds)
Comm.Register("BH", function(_, sender)
    if Names.Same(sender, Names.Me()) then return end
    ns.After(1 + math.random() * 6, function() Co.Announce(true) end)
end, { channel = true })

function Co.IsOnline(key)
    local p = Co.presence[key]
    if p and ns.Now() - (p.t or 0) < FRESH then return true end
    return Co.online[key] == true and ns.Now() - (Co.lastQuery or 0) < 900
end

function Co.Presence(key) return Co.presence[key] end

-- partner guild members currently online (channel presence or last /who)
function Co.OnlineCount()
    local n, seen = 0, {}
    -- the Bund channel also carries our own guild: count only players from another guild
    local own = IsInGuild() and ns.Call(GetGuildInfo, "player")
    own = type(own) == "string" and own:lower() or nil
    for key, p in pairs(Co.presence) do
        local other = type(p.guild) == "string" and p.guild:lower() ~= own
        if other and not seen[key] and Co.IsOnline(key) then seen[key] = true; n = n + 1 end
    end
    for key in pairs(Co.online) do if not seen[key] and Co.IsOnline(key) then seen[key] = true; n = n + 1 end end
    return n
end

ns.On("LG_READY", function()
    ns.After(8, joinBund)
    -- ask for a newer key; officers share theirs once; a guild master without one makes it
    ns.After(25, function()
        if not IsInGuild() then return end
        local o = bundSettings()
        if Co.CanManageKey() and validKey(o.key) then
            Comm.Send("BK", { key = o.key, t = o.keyT or 0 }, "GUILD", { priority = "bulk" })
        else
            Co.RequestKey()
        end
    end)
    ns.After(50, function()
        if IsInGuild() and not validKey(bundSettings().key) and ns.Guild.MyRankIndex() == 0 then Co.NewKey() end
    end)
    C_Timer.NewTicker(HEARTBEAT, function() if Co.ChannelId() then Co.Announce(true) end end)
end)
ns.On("PLAYER_LOGOUT", function() pcall(Co.Announce, false) end)
ns.On("PLAYER_GUILD_UPDATE", function() ns.Debounce("bund-announce", 5, function() Co.Announce(true) end) end)
ns.On("ZONE_CHANGED_NEW_AREA", function() ns.Debounce("bund-zone", 20, function() Co.Announce(true) end) end)

function Co.Rows()
    local rows = {}
    local o = Co.Settings()
    for key, e in pairs(store()) do
        local online = Co.IsOnline(key)
        if online or not o.onlineOnly then
            rows[#rows + 1] = { key = key, e = e, online = online, note = o.notes[key] }
        end
    end
    return rows
end

function Co.Test()
    local now = ns.Now()
    local db = store()
    local sample = {
        { "Mara Silvergrove", 60, "PRIEST", "Orgrimmar" }, { "Tor Ironfist", 60, "WARRIOR", "Molten Core" },
        { "Lin Duskglow", 47, "MAGE", "Tanaris" }, { "Kael Thornwatch", 60, "ROGUE", "Blackrock Mountain" },
    }
    Co.online = {}
    for _, s in ipairs(sample) do
        local key = Names.Key(s[1])
        db[key] = { name = s[1], guild = Co.Guilds()[1] or "GaliGrü", level = s[2], class = s[3], zone = s[4], seen = now, first = now, test = true }
        Co.online[key] = true
    end
    db[Names.Key("Ina Stormcall")] = { name = "Ina Stormcall", guild = Co.Guilds()[1] or "GaliGrü", level = 60, class = "DRUID", zone = "Darnassus",
        seen = now - 3 * 86400, first = now - 9 * 86400, test = true }
    Co.lastCount = #sample
    ns.Fire("LG_COGUILD")
end

function Co.ClearTest()
    local db = store()
    for key, e in pairs(db) do if e.test then db[key] = nil end end
    ns.Fire("LG_COGUILD")
end

-- sample members of /lg test partner are shown (test suite switch)
function Co.HasTest()
    for _, e in pairs(store()) do if e.test then return true end end
    return false
end

-- dialog: show the key (to pass it on) or paste one
function Co.ShowKey()
    local o = bundSettings()
    ns.Share.ShowText(L.CO_KEY_TITLE, L.CO_KEY_HINT, o.key or "")
    local dialog = _G.LiebeGruesseShareDialog
    if dialog then
        dialog.action:SetText(L.CO_SAVE)
        dialog.action:Show()
        dialog.onAction = function(text)
            text = (text or ""):gsub("%s+", "")
            if text == (o.key or "") then dialog:Hide(); return end
            if Co.SetKey(text, 0) then
                ns.Print(L.CO_KEY_SAVED)
                dialog:Hide()
            else
                ns.Print(L.CO_KEY_INVALID)
            end
        end
    end
end

function Co.KeyMenu()
    local can = Co.CanManageKey()
    UI.ContextMenu({
        { title = L.CO_KEY },
        { text = L.CO_KEY_SHOW, tip = L.CO_KEY_SHOW_TIP, func = Co.ShowKey },
        { text = L.CO_KEY_SHARE, disabled = not can or not validKey(bundSettings().key), tip = can and L.CO_KEY_SHARE_TIP or L.CO_KEY_OFFICERS,
          func = function()
              local o = bundSettings()
              Comm.Send("BK", { key = o.key, t = o.keyT or 0 }, "GUILD", { priority = "normal" })
              ns.Print(L.CO_KEY_SHARED)
          end },
        { text = L.CO_KEY_NEWKEY, disabled = not can, tip = can and L.CO_KEY_NEWKEY_TIP or L.CO_KEY_OFFICERS, func = Co.NewKey },
    })
end

-- one line for chat / tests: is the Bund channel working, and why not
function Co.BundStatus()
    local o = bundSettings()
    if not o.bund then return L.CO_BUND_OFF end
    if not validKey(o.key) then return L.CO_KEY_WAITING end
    if not Co.ChannelId() then return L.CO_BUND_JOINING end
    local n = 0
    for key in pairs(Co.presence) do if Co.IsOnline(key) then n = n + 1 end end
    return L.CO_BUND_COUNT:format(n) .. " · " .. (o.keyT and o.keyT > 0 and L.CO_KEY_FROM_OFFICER:format(ns.Date(o.keyT)) or L.CO_KEY_PASTED)
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local function menu(row)
    local e = row.e
    local name = e.name
    UI.ContextMenu({
        { title = Names.Display(name) },
        { text = L.CO_WHISPER, func = function()
            if ChatFrame_SendTell then ChatFrame_SendTell(name) elseif ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. name .. " ") end
        end },
        { text = L.CO_INVITE, func = function()
            if C_PartyInfo and C_PartyInfo.InviteUnit then ns.Call(C_PartyInfo.InviteUnit, name) elseif InviteUnit then ns.Call(InviteUnit, name) end
        end },
        { text = L.CO_ADD_FRIEND, func = function()
            if C_FriendList and C_FriendList.AddFriend then ns.Call(C_FriendList.AddFriend, name) elseif AddFriend then ns.Call(AddFriend, name) end
        end },
        { text = L.CO_NOTE, func = function()
            ns.Share.ShowText(L.CO_NOTE_TITLE:format(Names.Display(name)), L.CO_NOTE_HINT, Co.Settings().notes[row.key] or "")
            local dialog = _G.LiebeGruesseShareDialog
            if dialog then
                dialog.action:SetText(L.CO_SAVE)
                dialog.action:Show()
                dialog.onAction = function(text)
                    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    Co.Settings().notes[row.key] = text ~= "" and text or nil
                    dialog:Hide()
                    ns.Fire("LG_COGUILD")
                end
            end
        end },
        { divider = true },
        { text = L.CO_FORGET, func = function() store()[row.key] = nil; ns.Fire("LG_COGUILD") end },
    })
end

UI.AddPage("coguild", L.PAGE_COGUILD, 27, function(content, page)
    local o = Co.Settings()
    local guilds = UI.EditBox(content, 220, 26, L.CO_GUILDS_PH)
    guilds:SetPoint("TOPLEFT", 0, 0)
    guilds:SetText(o.guilds or "")
    guilds.onCommit = function(self) Co.Settings().guilds = self:GetText() or ""; ns.Fire("LG_COGUILD") end
    local ask = UI.Button(content, L.CO_QUERY, 150, 26, function()
        Co.Settings().guilds = guilds:GetText() or Co.Settings().guilds
        Co.Query(true)
    end, "search")
    ask:SetPoint("LEFT", guilds, "RIGHT", 8, 0)
    ask.tip = { L.CO_QUERY_TIP }
    local onlineOnly = UI.Check(content, L.ONLY_ONLINE, function() return Co.Settings().onlineOnly end,
        function(v) Co.Settings().onlineOnly = v; ns.Fire("LG_COGUILD") end)
    onlineOnly:SetPoint("LEFT", ask, "RIGHT", 16, 0)
    local bund = UI.Check(content, L.CO_BUND, function() return bundSettings().bund end, function(v)
        bundSettings().bund = v
        if v then joinBund() else Co.Leave() end
    end, L.CO_BUND_TIP)
    bund:SetPoint("LEFT", onlineOnly, "RIGHT", 16, 0)
    local keyBtn = UI.IconButton(content, "lock", 26, function() Co.KeyMenu() end)
    keyBtn:SetPoint("LEFT", bund, "RIGHT", 8, 0)
    keyBtn.tip, keyBtn.tipLines = L.CO_KEY, { L.CO_KEY_TIP }
    local autoWho = UI.Check(content, L.CO_AUTO_WHO, function() return Co.Settings().autoWho ~= false end,
        function(v) Co.Settings().autoWho = v end, L.CO_AUTO_WHO_TIP)
    autoWho:SetPoint("LEFT", keyBtn, "RIGHT", 16, 0)
    local status = UI.Text(content, 11, "muted")
    status:SetPoint("TOPLEFT", guilds, "BOTTOMLEFT", 0, -10)
    status:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    status:SetJustifyH("LEFT")
    status:SetWordWrap(false)
    -- the top right corner belongs to the page search: when the row gets too long,
    -- the last switch moves to the status line, then all switches get their own row
    local narrow
    local list
    local function fit()
        local w = content:GetWidth() or 0
        if w <= 0 then return end
        local room = w - ns.Window.SearchReserve()
        local mode = room >= 880 and "wide" or (room >= 700 and "mid" or "narrow")
        if mode == narrow then return end
        narrow = mode
        onlineOnly:ClearAllPoints(); autoWho:ClearAllPoints(); status:ClearAllPoints()
        if mode == "narrow" then
            onlineOnly:SetPoint("TOPLEFT", guilds, "BOTTOMLEFT", 0, -8)
            autoWho:SetPoint("LEFT", keyBtn, "RIGHT", 16, 0)
            status:SetPoint("TOPLEFT", onlineOnly, "BOTTOMLEFT", 0, -10)
            status:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        else
            onlineOnly:SetPoint("LEFT", ask, "RIGHT", 16, 0)
            status:SetPoint("TOPLEFT", guilds, "BOTTOMLEFT", 0, -10)
            if mode == "mid" then
                autoWho:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -32)
                status:SetPoint("RIGHT", autoWho, "LEFT", -12, 0)
            else
                autoWho:SetPoint("LEFT", keyBtn, "RIGHT", 16, 0)
                status:SetPoint("RIGHT", content, "RIGHT", 0, 0)
            end
        end
        if list then
            list:ClearAllPoints()
            list:SetPoint("TOPLEFT", 0, mode == "narrow" and -86 or -56)
            list:SetPoint("BOTTOMRIGHT")
        end
    end
    content:HookScript("OnSizeChanged", fit)

    list = UI.List(content, {
        sortKey = "name",
        columns = {
            { key = "name", title = L.COL_NAME, flex = 1, minWidth = 130,
              text = function(r)
                  local dot = r.online and UI.Glyph("dot", "good", 10) or UI.Glyph("ring", "muted", 10)
                  return dot .. " " .. ns.ColorName(Names.Display(r.e.name), r.e.class)
              end,
              sort = function(r) return (r.online and "0" or "1") .. r.key end },
            { key = "level", title = L.COL_LEVEL, width = 44, align = "CENTER", text = function(r) return tostring(r.e.level or "") end,
              sort = function(r) return r.e.level or 0 end, defaultDesc = true },
            { key = "zone", title = L.CO_ZONE, flex = 1, minWidth = 120,
              text = function(r) return r.online and (r.e.zone or "") or Theme.HexColor("muted", r.e.zone or "") end,
              sort = function(r) return r.e.zone or "" end },
            { key = "guild", title = L.CO_GUILD, width = 120, text = function(r) return Theme.HexColor("muted", r.e.guild or "") end },
            { key = "note", title = L.NOTE, flex = 0.8, minWidth = 80, text = function(r) return r.note and Theme.HexColor("textDim", r.note) or "" end },
            { key = "seen", title = L.COL_LAST_SEEN, width = 100,
              text = function(r) return r.online and Theme.HexColor("good", L.ONLINE) or Theme.HexColor("muted", ns.Ago(r.e.seen)) end,
              sort = function(r) return -(r.e.seen or 0) end },
        },
        onClick = function(row, button)
            if button == "RightButton" then menu(row)
            elseif IsShiftKeyDown() and ChatFrame_SendTell then ChatFrame_SendTell(row.e.name) end
        end,
    })
    list:SetPoint("TOPLEFT", 0, -56)
    list:SetPoint("BOTTOMRIGHT")
    list:SetEmptyText(L.CO_EMPTY)
    narrow = nil; fit()

    local function render()
        if not guilds:HasFocus() then guilds:SetText(Co.Settings().guilds or "") end
        onlineOnly:Refresh(); bund:Refresh(); autoWho:Refresh()
        local parts = {}
        if Co.status then parts[#parts + 1] = Theme.HexColor("warn", Co.status) end
        if Co.lastQuery > 0 then
            parts[#parts + 1] = L.CO_COUNT:format(Co.lastCount or 0, ns.Ago(Co.lastQuery))
            if Co.truncated then parts[#parts + 1] = Theme.HexColor("warn", L.CO_TRUNCATED) end
        else
            parts[#parts + 1] = L.CO_HINT
        end
        local withAddon = 0
        for key in pairs(Co.presence) do if Co.IsOnline(key) then withAddon = withAddon + 1 end end
        if Co.ChannelId() then parts[#parts + 1] = L.CO_BUND_COUNT:format(withAddon)
        elseif bundSettings().bund and not validKey(bundSettings().key) then parts[#parts + 1] = Theme.HexColor("warn", L.CO_KEY_WAITING) end
        if (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("GuildKit")) or (IsAddOnLoaded and IsAddOnLoaded("GuildKit")) then
            parts[#parts + 1] = L.CO_GUILDKIT
        end
        status:SetText(table.concat(parts, "  ·  "))
        local rows = Co.Rows()
        list:SetRows(rows)
    end
    page.searchHint = L.CO_SEARCH
    page.Search = function(text) page.query = text; render(); return list:ShowFirstHit(text) end
    page.searchList = list
    page.OnShow = function()
        fit()
        render()
        -- opening the page is a click: a good moment for a fresh /who
        -- (results never open the friends window)
        if Co.Settings().autoWho ~= false then Co.Query(false) end
    end
    ns.On("LG_COGUILD", function() if content:IsVisible() then render() end end)
end, { section = "guild", icon = "users" })
