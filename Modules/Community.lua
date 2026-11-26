-- Community: fun guild stats everybody contributes to.
--   * Fail-pull vote after a wipe ("who pulled?") and mispull reports
--   * "Pepega deaths": deaths while the rest of the group survived
--   * Consumables at ready checks (from the raid check)
--   * Pin board: quotes and shout-outs with likes
-- Everything is stored per guild and synced like the feed.
local _, ns = ...
local Community = ns.NewModule("community")
ns.Community = Community
local UI, Theme, L, Names, Comm = ns.UI, ns.Theme, ns.L, ns.Names, ns.Comm

local MAX_EVENTS, MAX_POSTS = 2000, 300

local function store()
    local g = ns.Database.Guild()
    g.community = g.community or { events = {}, posts = {} }
    g.community.events = g.community.events or {}
    g.community.posts = g.community.posts or {}
    g.community.removed = g.community.removed or {}
    return g.community
end
local function settings() return ns.Database.Settings().community end
Community.Store = store

local function display(key)
    local g = ns.Guild.Find(key)
    return ns.ColorName(g and g.name or key, g and g.class)
end

local function redraw()
    ns.Debounce("community-redraw", 0.4, function()
        ns.Window.Refresh("community")
        ns.Fire("LG_COMMUNITY")
    end)
end

---------------------------------------------------------------------------
-- Storage and sync
---------------------------------------------------------------------------
local function addEvent(e, broadcast)
    if type(e) ~= "table" or type(e.id) ~= "string" or type(e.t) ~= "number" or type(e.k) ~= "string" then return false end
    if store().removed[e.id] then return false end
    local list = store().events
    for _, old in ipairs(list) do
        if old.id == e.id then
            -- running counters (jumps of a raid night, daily counters) grow: keep the higher values
            if (e.k == "jump" or e.k == "daily") and e.k == old.k and type(e.d) == "table" and type(old.d) == "table" then
                local grew = false
                for k, v in pairs(e.d) do
                    if type(v) == "number" and v > (tonumber(old.d[k]) or 0) then old.d[k] = v; grew = true end
                end
                if not grew then return false end
                old.t = math.max(old.t, e.t)
                if broadcast and IsInGuild() then Comm.Send("CE", { e = e }, "GUILD", { priority = "bulk" }) end
                redraw()
                return true
            end
            return false
        end
    end
    list[#list + 1] = e
    table.sort(list, function(a, b) return a.t < b.t end)
    while #list > MAX_EVENTS do table.remove(list, 1) end
    if broadcast and IsInGuild() then Comm.Send("CE", { e = e }, "GUILD", { priority = "bulk" }) end
    redraw()
    return true
end
Community.AddEvent = addEvent

local function findPost(id)
    for _, p in ipairs(store().posts) do if p.id == id then return p end end
end

local function addPost(p, broadcast)
    if type(p) ~= "table" or type(p.id) ~= "string" or type(p.text) ~= "string" or #p.text > 300 then return false end
    if store().removed[p.id] then return false end
    if findPost(p.id) then return false end
    p.likes = type(p.likes) == "table" and p.likes or {}
    local list = store().posts
    list[#list + 1] = p
    table.sort(list, function(a, b) return a.t < b.t end)
    while #list > MAX_POSTS do table.remove(list, 1) end
    if broadcast and IsInGuild() then Comm.Send("CP", { p = p }, "GUILD", { priority = "normal" }) end
    redraw()
    return true
end

function Community.Post(kind, text, about)
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #text < 2 then return false end
    local me = Names.Me()
    addPost({ id = me .. ":" .. ns.Now() .. ":" .. math.random(1000), t = ns.Now(), a = me, k = kind, text = text:sub(1, 300),
        about = about and Names.Key(about) or nil, likes = {} }, true)
    return true
end

function Community.Like(id)
    local p = findPost(id)
    if not p then return end
    local me = Names.Me()
    local on = not p.likes[me]
    p.likes[me] = on or nil
    if IsInGuild() then Comm.Send("CK", { id = id, on = on }, "GUILD", { priority = "normal" }) end
    redraw()
end

---------------------------------------------------------------------------
-- Moderation: officers / guild master (rank 0 and 1) may remove posts and
-- events, authors may remove their own posts. Removals are synced as tombstones.
---------------------------------------------------------------------------
local MOD_RANK = 1
function Community.IsModerator(key)
    if Names.Same(key, Names.Me()) then
        local index = ns.Guild.MyRankIndex()
        if type(index) == "number" and index <= MOD_RANK then return true end
        if CanGuildRemove and ns.Call(CanGuildRemove) == true then return true end
        return false
    end
    local g = ns.Guild.Find(key)
    return g ~= nil and type(g.rankIndex) == "number" and g.rankIndex <= MOD_RANK
end

local function itemById(id)
    for i, p in ipairs(store().posts) do if p.id == id then return "post", p, i end end
    for i, e in ipairs(store().events) do if e.id == id then return "event", e, i end end
end

function Community.CanRemove(id, key)
    key = key or Names.Me()
    local kind, obj = itemById(id)
    if not kind then return false end
    if Community.IsModerator(key) then return true end
    return kind == "post" and Names.Same(obj.a, key)
end

local function applyRemove(id)
    local c = store()
    c.removed[id] = ns.Now()
    local kind, _, index = itemById(id)
    if kind == "post" then table.remove(c.posts, index) elseif kind == "event" then table.remove(c.events, index) end
    redraw()
end

function Community.Remove(id)
    if not Community.CanRemove(id) then ns.Print(L.COMM_REMOVE_DENIED); return false end
    applyRemove(id)
    if IsInGuild() then Comm.Send("CR", { id = id }, "GUILD", { priority = "normal" }) end
    return true
end

Comm.Register("CR", function(data, sender)
    if type(data.id) ~= "string" or store().removed[data.id] then return end
    local kind = itemById(data.id)
    -- unknown here: remember the removal only when an officer sent it
    if not kind then
        if Community.IsModerator(sender) then store().removed[data.id] = ns.Now() end
        return
    end
    if Community.CanRemove(data.id, sender) then applyRemove(data.id) end
end)

-- kinds every player records about themselves: only from that player, only in guild chat
local SELF_KINDS = { fall = true, repair = true, session = true, afk = true, jump = true, daily = true }
local function selfEventOk(e, sender)
    if not Names.Same(e.who, sender) or type(e.d) ~= "table" then return false end
    if e.t > ns.Now() + 120 then return false end
    if e.k == "repair" then return type(e.d.c) == "number" and e.d.c > 0 and e.d.c < 1e8 end
    if e.k == "session" then return type(e.d.s) == "number" and e.d.s > 0 and e.d.s <= 2 * 86400 end
    if e.k == "fall" then return type(e.d.c) == "string" and #e.d.c <= 10 end
    if e.k == "afk" then return true end
    if e.k == "daily" then return ns.CommunityDaily ~= nil and ns.CommunityDaily.Valid(e.d) end
    if e.k == "jump" then return type(e.d.n) == "number" and e.d.n > 0 and e.d.n < 50000 end
    return false
end
Community.SelfEventOk = selfEventOk

Comm.Register("CE", function(data, sender, channel)
    local e = type(data.e) == "table" and ns.Clean(data.e, 4)
    if not e then return end
    if SELF_KINDS[e.k] and (channel ~= "GUILD" or not selfEventOk(e, sender)) then return end
    addEvent(e)
end)
Comm.Register("CP", function(data) addPost(data.p) end)
Comm.Register("CK", function(data, sender)
    local p = type(data.id) == "string" and findPost(data.id)
    if p then p.likes[sender] = data.on and true or nil; redraw() end
end)
Comm.Register("CS", function(data, sender, _, raw)
    local since = tonumber(data.since) or 0
    local events, posts = store().events, store().posts
    local newer = (#events > 0 and events[#events].t > since) or (#posts > 0 and posts[#posts].t > since)
    if not newer then return end
    Comm.ReplyOnce("community:" .. sender, 4, 14, function()
        Comm.Send("CA", { to = sender }, "GUILD", { priority = "alert" })
        local batch = {}
        local function flush(kind)
            if #batch > 0 then Comm.Send("CB", { [kind] = batch }, "WHISPER", { target = raw, priority = "bulk" }) end
            batch = {}
        end
        for _, e in ipairs(events) do
            if e.t > since then batch[#batch + 1] = e; if #batch == 20 then flush("e") end end
        end
        flush("e")
        for _, p in ipairs(posts) do
            if p.t > since - 30 * 86400 then batch[#batch + 1] = p; if #batch == 8 then flush("p") end end
        end
        flush("p")
        local ids = {}
        for id, t in pairs(store().removed) do if t > since - 30 * 86400 then ids[#ids + 1] = id end end
        for i = 1, #ids, 30 do
            Comm.Send("CB", { r = { unpack(ids, i, math.min(#ids, i + 29)) } }, "WHISPER", { target = raw, priority = "bulk" })
        end
    end)
end)
Comm.Register("CA", function(data) if data.to then Comm.Answered("community:" .. data.to) end end)
Comm.Register("CB", function(data, sender)
    for _, id in ipairs(type(data.r) == "table" and data.r or {}) do
        if type(id) == "string" and not store().removed[id] then applyRemove(id) end
    end
    for _, e in ipairs(type(data.e) == "table" and data.e or {}) do addEvent(e) end
    for _, p in ipairs(type(data.p) == "table" and data.p or {}) do
        local old = type(p) == "table" and findPost(p.id)
        if old then
            for k, v in pairs(type(p.likes) == "table" and p.likes or {}) do old.likes[k] = v end
        else
            addPost(p)
        end
    end
end)

function Community:OnLogin()
    ns.After(55, function()
        if not IsInGuild() then return end
        local events = store().events
        local newest = #events > 0 and events[#events].t or 0
        Comm.Send("CS", { since = math.max(0, newest - 86400) }, "GUILD", { priority = "bulk" })
    end)
end

---------------------------------------------------------------------------
-- Recorder: one addon user per group records shared events
---------------------------------------------------------------------------
function Community.IsRecorder()
    local me = Names.Me()
    local best = me
    for _, key in ns.GroupUnits() do
        local heard = ns.Versions.heard[key]
        if heard and ns.Now() - heard.t < 4 * 3600 and key < best then best = key end
    end
    return best == me
end

local function guildGroup()
    if not IsInGuild() or not IsInGroup() then return false end
    local total, guildies = 0, 0
    for _, key in ns.GroupUnits() do
        total = total + 1
        if ns.Guild.IsMember(key) then guildies = guildies + 1 end
    end
    return guildies >= math.max(2, total / 2)
end

local function today() return date("%Y%m%d") end

---------------------------------------------------------------------------
-- Fail-pull vote after a wipe
---------------------------------------------------------------------------
local vote          -- { id, boss, votes = { [voter] = target|"none" }, closes }
local votePopup
local voteIcon      -- small square: click opens the vote (Ben: the popup after a wipe was too much)
local showVote

local function tally()
    if not vote then return end
    local v = vote
    vote = nil
    if votePopup then votePopup:Hide() end
    if voteIcon then voteIcon:Hide() end
    local counts, voters = {}, 0
    for _, target in pairs(v.votes) do
        voters = voters + 1
        counts[target] = (counts[target] or 0) + 1
    end
    local best, bestN = nil, 0
    for target, n in pairs(counts) do
        if n > bestN or (n == bestN and best and target < best) then best, bestN = target, n end
    end
    if not best or best == "none" or bestN < math.max(2, math.ceil(voters * 0.3)) then
        if voters > 0 then ns.Print(L.FP_NO_RESULT) end
        return
    end
    if v.test then
        ns.Print(L.TEST_TAG .. " " .. L.FP_RESULT:format(Names.Display(best), bestN, voters, v.boss or "?"))
        UI.Toast(L.TEST_TAG .. " " .. L.BOARD_FAILPULL, L.EV_FAILPULL:format(Names.Display(best), v.boss or "?", bestN, voters))
        return
    end
    ns.Print(L.FP_RESULT:format(Names.Display(best), bestN, voters, v.boss or "?"))
    addEvent({ id = "fp:" .. v.id, t = ns.Now(), k = "failpull", who = best, d = { b = v.boss, n = bestN, of = voters } },
        Community.IsRecorder())
end

local function castVote(target)
    if not vote then return end
    if vote.test then
        vote.votes[Names.Me()] = target
        if votePopup then votePopup.done:SetText(L.FP_VOTED:format(target == "none" and L.FP_NOBODY or Names.Display(target))) end
        return
    end
    Comm.Send("FV", { id = vote.id, who = target }, "GROUP", { priority = "alert", loopback = true })
    if votePopup then votePopup.done:SetText(L.FP_VOTED:format(target == "none" and L.FP_NOBODY or Names.Display(target))) end
end

-- the square: swords icon and the seconds left; click = vote, movable with "Move elements"
local function showVoteIcon()
    if not voteIcon then
        voteIcon = CreateFrame("Button", "LiebeGruesseFailVoteIcon", UIParent, "BackdropTemplate")
        voteIcon:SetSize(36, 36)
        voteIcon:SetFrameStrata("MEDIUM")
        voteIcon:SetClampedToScreen(true)
        UI.Skin(voteIcon, "bg", "accent")
        voteIcon.icon = UI.Icon(voteIcon, "swords", 18, "accent")
        voteIcon.icon:SetPoint("CENTER", 0, 3)
        voteIcon.time = UI.Text(voteIcon, 9, "muted", "CENTER")
        voteIcon.time:SetPoint("BOTTOM", 0, 2)
        voteIcon:SetScript("OnClick", function(self)
            self:Hide()
            if vote then showVote() end
        end)
        voteIcon:SetScript("OnEnter", function(self)
            UI.Tooltip(self, vote and L.FP_TITLE:format(vote.boss or "?") or L.MOVER_FAILVOTE, { L.FP_ICON_TIP })
        end)
        voteIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- seconds left, only while the square is shown (hidden = no updates)
        voteIcon.elapsed = 0
        voteIcon:SetScript("OnUpdate", function(self, dt)
            self.elapsed = self.elapsed + dt
            if self.elapsed < 0.5 then return end
            self.elapsed = 0
            if vote then self.time:SetText(math.max(0, math.floor(vote.closes - GetTime()))) else self:Hide() end
        end)
        ns.Movers.Attach("failVoteIcon", voteIcon)
    end
    voteIcon.time:SetText(vote and math.max(0, math.floor(vote.closes - GetTime())) or "")
    voteIcon:Show()
end
Community.ShowVoteIcon = showVoteIcon

showVote = function()
    if not votePopup then
        votePopup = UI.Panel(UIParent, "bg", "border")
        UI.Float(votePopup)
        votePopup:EnableMouse(true)
        votePopup:SetMovable(true)
        votePopup:RegisterForDrag("LeftButton")
        votePopup:SetScript("OnDragStart", votePopup.StartMoving)
        votePopup:SetScript("OnDragStop", votePopup.StopMovingOrSizing)
        ns.Movers.Attach("failVote", votePopup)
        votePopup.title = UI.Text(votePopup, 15, "text")
        votePopup.title:SetPoint("TOPLEFT", 14, -12)
        votePopup.sub = UI.Text(votePopup, 11, "muted")
        votePopup.sub:SetPoint("TOPLEFT", votePopup.title, "BOTTOMLEFT", 0, -4)
        votePopup.done = UI.Text(votePopup, 12, "gold")
        votePopup.done:SetPoint("BOTTOMLEFT", 14, 12)
        local close = UI.IconButton(votePopup, "x", 22, function() votePopup:Hide() end, true)
        close:SetPoint("TOPRIGHT", -8, -8)
        votePopup.none = UI.Button(votePopup, L.FP_NOBODY, 160, 24, function() castVote("none") end)
        votePopup.none:SetPoint("BOTTOMRIGHT", -12, 8)
        votePopup.buttons = {}
        votePopup:SetWidth(4 * 130 + 3 * 6 + 28)
        votePopup.defaultSize = { 4 * 130 + 3 * 6 + 28, 200 }
        -- resizable width: the name buttons wrap into as many columns as fit
        UI.Resizable(votePopup, "failVote", 300, 120, 1400, 900, function() if votePopup.layout then votePopup.layout() end end)
        votePopup:SetScript("OnUpdate", function(self)
            if vote then self.sub:SetText(L.FP_SUB:format(math.max(0, math.floor(vote.closes - GetTime())))) end
        end)
    end
    local members = {}
    if vote and vote.members then
        members = vote.members
    else
        for unit, key, name in ns.GroupUnits() do
            local _, class = ns.Call(UnitClass, unit)
            members[#members + 1] = { key = key, name = name, class = class }
        end
    end
    table.sort(members, function(a, b) return a.key < b.key end)
    function votePopup.layout()
        local w, h = 130, 24
        local width = votePopup:GetWidth() or (4 * w + 46)
        local cols = math.max(1, math.floor((width - 28 + 6) / (w + 6)))
        w = math.floor((width - 28 - (cols - 1) * 6) / cols)
        for i, m in ipairs(members) do
            local b = votePopup.buttons[i]
            if not b then
                b = UI.Button(votePopup, "", w, h)
                votePopup.buttons[i] = b
            end
            b:SetWidth(w)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 14 + ((i - 1) % cols) * (w + 6), -52 - math.floor((i - 1) / cols) * (h + 4))
            b:SetText(ns.ColorName(m.name, m.class))
            b:SetScript("OnClick", function() castVote(m.key) end)
            b:Show()
        end
        for i = #members + 1, #votePopup.buttons do votePopup.buttons[i]:Hide() end
        local height = 52 + math.ceil(#members / cols) * (h + 4) + 44
        votePopup:SetHeight(height)
        if votePopup.SetResizeBounds then votePopup:SetResizeBounds(300, height, 1400, height) end
    end
    votePopup.layout()
    votePopup.title:SetText((vote.test and (L.TEST_TAG .. " ") or "") .. L.FP_TITLE:format(vote.boss or "?"))
    votePopup.done:SetText("")
    votePopup:Show()
end

local function openVote(id, boss)
    if vote and vote.id == id then return end
    vote = { id = id, boss = boss, votes = {}, closes = GetTime() + 45 }
    C_Timer.After(45, function() if vote and vote.id == id then tally() end end)
    -- off by default (Ben); when on, only a small square that opens the vote
    if settings().failVote == true then showVoteIcon() end
end

function Community.Vote(target) castVote(target) end

-- Test: a local fail-pull vote with made-up raiders (nothing is sent or saved)
local FAKE = { { "Arwen Silverleaf", "PRIEST" }, { "Borin Ironfist", "WARRIOR" }, { "Celia Morningdew", "MAGE" },
    { "Dorn Shadowpath", "ROGUE" }, { "Elara Stormcall", "SHAMAN" }, { "Finn Greengrove", "DRUID" }, { "Greta Sparkstrike", "WARLOCK" } }
function Community.TestVote()
    local members = {}
    for _, f in ipairs(FAKE) do members[#members + 1] = { key = Names.Key(f[1]), name = f[1], class = f[2] } end
    local me = Names.Me()
    local _, myClass = ns.Call(UnitClass, "player")
    members[#members + 1] = { key = me, name = Names.Unit("player") or me, class = myClass }
    local id = "test:" .. GetTime()
    vote = { id = id, boss = L.TEST_BOSS, votes = {}, closes = GetTime() + 20, test = true, members = members }
    showVoteIcon()
    local suspect = members[math.random(1, #FAKE)].key
    for i = 1, #FAKE do
        C_Timer.After(1 + i * 0.6, function()
            if vote and vote.id == id then vote.votes[members[i].key] = (math.random() < 0.7) and suspect or "none" end
        end)
    end
    C_Timer.After(20, function() if vote and vote.id == id then tally() end end)
end

-- Test: how an event would look (shown as notification, not saved)
function Community.TestEvent(kind)
    local who = Names.Me()
    local e = { id = "test", t = ns.Now(), k = kind, who = who, by = who,
        d = { b = L.TEST_BOSS, n = 3, of = 5, list = {} } }
    local text = Community.EventText(e)
    UI.Toast(L.TEST_TAG .. " " .. L.PAGE_COMMUNITY, text)
    ns.Print(L.TEST_TAG .. " " .. text)
end

Comm.Register("FV", function(data, sender)
    if type(data.id) ~= "string" or type(data.who) ~= "string" then return end
    if not vote or vote.id ~= data.id then return end
    vote.votes[sender] = data.who
end)
Comm.Register("FO", function(data) if type(data.id) == "string" then openVote(data.id, data.b) end end)

ns.On("ENCOUNTER_END", function(_, encounterID, name, _, _, success)
    if ns.IsSecret(success) or ns.IsSecret(name) then return end
    if ns.Database.Settings().modules.community == false or not guildGroup() then return end
    if success == 1 then return end
    local id = ("%s:%s:%d"):format(tostring(encounterID), today(), math.floor(ns.Now() / 60))
    ns.After(2, function()
        openVote(id, name)
        if Community.IsRecorder() then Comm.Send("FO", { id = id, b = name }, "GROUP", { priority = "alert" }) end
    end)
end)

-- Manual report (trash pull): one click from the community page
function Community.ReportMispull(key)
    if not key then return end
    addEvent({ id = "mp:" .. key .. ":" .. ns.Now() .. ":" .. (Names.Me() or "?"), t = ns.Now(), k = "mispull", who = key,
        by = Names.Me() }, true)
    ns.Print(L.MP_REPORTED:format(Names.Display(key)))
end

---------------------------------------------------------------------------
-- Pepega deaths: died while the group did not wipe
---------------------------------------------------------------------------
local dead, watching = {}, false
local function poll()
    if not watching then return end
    for unit, key in ns.GroupUnits() do
        local isDead = ns.Call(UnitIsDeadOrGhost, unit)
        if isDead == true and not dead[key] then dead[key] = ns.Now() end
    end
    C_Timer.After(1, poll)
end

local function finishFight(wiped, boss)
    watching = false
    local total, deaths = 0, 0
    for _ in ns.GroupUnits() do total = total + 1 end
    for _ in pairs(dead) do deaths = deaths + 1 end
    if not wiped and deaths > 0 and deaths < total * 0.8 and guildGroup() and ns.Database.Settings().modules.community ~= false then
        local recorder = Community.IsRecorder()
        for key, t in pairs(dead) do
            addEvent({ id = ("pd:%s:%d"):format(key, math.floor(t / 60)), t = t, k = "death", who = key, d = { b = boss } }, recorder)
        end
    end
    wipe(dead)
end

ns.On("PLAYER_REGEN_DISABLED", function()
    if not IsInGroup() or watching then return end
    wipe(dead)
    watching = true
    C_Timer.After(1, poll)
end)
ns.On("ENCOUNTER_START", function()
    if not IsInGroup() then return end
    wipe(dead)
    if not watching then watching = true; C_Timer.After(1, poll) end
end)
ns.On("ENCOUNTER_END", function(_, _, name, _, _, success)
    if ns.IsSecret(success) then return end
    ns.After(1, function() finishFight(success ~= 1, name) end)
end)
ns.On("PLAYER_REGEN_ENABLED", function()
    ns.After(2, function()
        if watching and not ns.EncounterInProgress() then
            -- a trash fight ended: everyone dead (or nearly) counts as a wipe
            local total, alive = 0, 0
            for unit in ns.GroupUnits() do
                total = total + 1
                if ns.Call(UnitIsDeadOrGhost, unit) ~= true then alive = alive + 1 end
            end
            finishFight(alive == 0, nil)
        end
    end)
end)

---------------------------------------------------------------------------
-- Consumables from the raid check
---------------------------------------------------------------------------
local lastConsum = 0
function Community.RecordConsumables(rows)
    if not guildGroup() or GetTime() - lastConsum < 600 or ns.Database.Settings().modules.community == false then return end
    lastConsum = GetTime()
    local list = {}
    for _, r in ipairs(rows) do
        if r.scanned then list[r.key] = (r.flask and "F" or "") .. ("E"):rep(math.min(2, #r.elixirs)) .. (r.food and "S" or "") end
    end
    if not next(list) then return end
    addEvent({ id = "cs:" .. (Names.Me() or "?") .. ":" .. ns.Now(), t = ns.Now(), k = "consum", d = { list = list } },
        Community.IsRecorder())
end

---------------------------------------------------------------------------
-- Leaderboards
---------------------------------------------------------------------------
-- sample events for /lg test boards (never stored or sent)
Community.testEvents = nil

local function allEvents()
    local list = store().events
    local test = Community.testEvents
    if not test then return list end
    local merged = {}
    for _, e in ipairs(list) do merged[#merged + 1] = e end
    for _, e in ipairs(test) do merged[#merged + 1] = e end
    return merged
end

local function hours(sec)
    sec = math.floor(sec or 0)
    return ("%dh %02dm"):format(math.floor(sec / 3600), math.floor(sec / 60) % 60)
end

local function gold(copper)
    local g = math.floor((copper or 0) / 10000)
    if g >= 1 then return ("%d|cffffd700g|r"):format(g) end
    return ("%d|cffc7c7cfs|r"):format(math.floor((copper or 0) / 100))
end

-- Lucky dog / unlucky: epics per raid evening from the guild feed.
-- An evening = a day with a raid boss kill the player was listed in.
local function lootLuck(since)
    local evenings, epics = {}, {}
    local function evening(key, day)
        evenings[key] = evenings[key] or {}
        evenings[key][day] = true
    end
    for _, e in ipairs(ns.Database.Guild().feed or {}) do
        if type(e) == "table" and (e.t or 0) >= since and type(e.d) == "table" then
            if e.k == "boss" and e.d.r and type(e.d.g) == "table" then
                local day = date("%Y%m%d", e.t)
                for _, key in ipairs(e.d.g) do evening(key, day) end
            elseif e.k == "loot" and (e.d.q or 0) >= 4 and e.d.ins and e.a then
                epics[e.a] = (epics[e.a] or 0) + 1
            end
        end
    end
    for _, e in ipairs(Community.testEvents or {}) do
        if e.k == "raidday" then evening(e.who, e.d.day) elseif e.k == "epic" then epics[e.who] = (epics[e.who] or 0) + 1 end
    end
    local rows = {}
    for key, days in pairs(evenings) do
        local n = 0
        for _ in pairs(days) do n = n + 1 end
        local ep = epics[key] or 0
        rows[#rows + 1] = { key = key, evenings = n, epics = ep, rate = ep / n }
    end
    return rows
end

-- daily counters per player in the period: sums, plus the longest run of login days
function Community.DailyTotals(since, events)
    local sums, days = {}, {}
    for _, e in ipairs(events or allEvents()) do
        if e.k == "daily" and e.who and type(e.d) == "table" and e.t >= (since or 0) then
            local s = sums[e.who] or {}
            sums[e.who] = s
            for k, v in pairs(e.d) do if k ~= "day" and type(v) == "number" then s[k] = (s[k] or 0) + v end end
            if (e.d.login or 0) > 0 and type(e.d.day) == "string" then
                days[e.who] = days[e.who] or {}
                days[e.who][e.d.day] = true
            end
        end
    end
    -- longest streak of consecutive login days
    for who, set in pairs(days) do
        local list = {}
        for day in pairs(set) do
            local y, m, d = day:match("^(%d%d%d%d)(%d%d)(%d%d)$")
            if y then list[#list + 1] = math.floor(time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }) / 86400) end
        end
        table.sort(list)
        local best, run = 0, 0
        for i, n in ipairs(list) do
            run = (i > 1 and n == list[i - 1] + 1) and run + 1 or 1
            if run > best then best = run end
        end
        sums[who] = sums[who] or {}
        sums[who].streak = best
    end
    return sums
end

-- longest run of raid nights without an epic, per player
function Community.BadLuck(since)
    local nights, epicDays = {}, {}
    for _, e in ipairs(ns.Database.Guild().feed or {}) do
        if type(e) == "table" and (e.t or 0) >= (since or 0) and type(e.d) == "table" then
            local day = date("%Y%m%d", e.t)
            if e.k == "boss" and e.d.r and type(e.d.g) == "table" then
                for _, key in ipairs(e.d.g) do nights[key] = nights[key] or {}; nights[key][day] = true end
            elseif e.k == "loot" and (e.d.q or 0) >= 4 and e.d.ins and e.a then
                epicDays[e.a] = epicDays[e.a] or {}; epicDays[e.a][day] = true
            end
        end
    end
    for _, e in ipairs(Community.testEvents or {}) do
        if e.k == "raidday" then nights[e.who] = nights[e.who] or {}; nights[e.who][e.d.day] = true
        elseif e.k == "epicday" then epicDays[e.who] = epicDays[e.who] or {}; epicDays[e.who][e.d.day] = true end
    end
    local out = {}
    for key, set in pairs(nights) do
        local list = {}
        for day in pairs(set) do list[#list + 1] = day end
        table.sort(list)
        local best, run = 0, 0
        for _, day in ipairs(list) do
            if epicDays[key] and epicDays[key][day] then run = 0 else run = run + 1 end
            if run > best then best = run end
        end
        if best > 0 then out[key] = best end
    end
    return out
end

local function luckText(r)
    return (r.epics == 1 and L.BOARD_LUCK_EPIC or L.BOARD_LUCK_EPICS):format(r.epics) .. " · "
        .. (r.evenings == 1 and L.BOARD_LUCK_NIGHT or L.BOARD_LUCK_NIGHTS):format(r.evenings)
end

function Community.Boards(days)
    local since = days and (ns.Now() - days * 86400) or 0
    local fail, mispull, death, flasks, noFood, checks = {}, {}, {}, {}, {}, {}
    local falls, repair, session, greet, afk, jumps, jumpNights = {}, {}, {}, {}, {}, {}, {}
    for _, e in ipairs(allEvents()) do
        if e.t >= since then
            if e.k == "failpull" and e.who then fail[e.who] = (fail[e.who] or 0) + 1
            elseif e.k == "mispull" and e.who then mispull[e.who] = (mispull[e.who] or 0) + 1
            elseif e.k == "death" and e.who then death[e.who] = (death[e.who] or 0) + 1
            elseif e.k == "fall" and e.who then falls[e.who] = (falls[e.who] or 0) + 1
            elseif e.k == "repair" and e.who and e.d then repair[e.who] = (repair[e.who] or 0) + (tonumber(e.d.c) or 0)
            elseif e.k == "session" and e.who and e.d then
                local len = tonumber(e.d.s) or 0
                if len > (session[e.who] or 0) then session[e.who] = len end
            elseif e.k == "greet1" and e.who then greet[e.who] = (greet[e.who] or 0) + 1
            elseif e.k == "afk" and e.who then afk[e.who] = (afk[e.who] or 0) + 1
            elseif e.k == "jump" and e.who and e.d then
                jumps[e.who] = (jumps[e.who] or 0) + (tonumber(e.d.n) or 0)
                jumpNights[e.who] = (jumpNights[e.who] or 0) + 1
            elseif e.k == "consum" and e.d and type(e.d.list) == "table" then
                for key, code in pairs(e.d.list) do
                    checks[key] = (checks[key] or 0) + 1
                    if tostring(code):find("F", 1, true) then flasks[key] = (flasks[key] or 0) + 1 end
                    if not tostring(code):find("S", 1, true) then noFood[key] = (noFood[key] or 0) + 1 end
                end
            end
        end
    end
    local function top(map, n, fmt)
        local list = {}
        for key, v in pairs(map) do list[#list + 1] = { key = key, n = v, text = fmt and fmt(v) or nil } end
        table.sort(list, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.key < b.key end)
        while #list > (n or 5) do table.remove(list) end
        return list
    end
    local perNight = {}
    for key, n in pairs(jumps) do perNight[key] = math.floor(n / math.max(1, jumpNights[key] or 1) + 0.5) end
    local luck = lootLuck(since)
    local lucky, unlucky = {}, {}
    for _, r in ipairs(luck) do
        if r.epics > 0 then lucky[#lucky + 1] = { key = r.key, n = r.rate, epics = r.epics, text = luckText(r) } end
        if r.evenings >= 2 then unlucky[#unlucky + 1] = { key = r.key, n = r.rate, evenings = r.evenings, text = luckText(r) } end
    end
    table.sort(lucky, function(a, b) if a.n ~= b.n then return a.n > b.n end if a.epics ~= b.epics then return a.epics > b.epics end return a.key < b.key end)
    table.sort(unlucky, function(a, b) if a.n ~= b.n then return a.n < b.n end if a.evenings ~= b.evenings then return a.evenings > b.evenings end return a.key < b.key end)
    local daily = Community.DailyTotals(since)
    local function stat(key, fmt)
        local map = {}
        for who, t in pairs(daily) do if (t[key] or 0) > 0 then map[who] = t[key] end end
        return top(map, 5, fmt)
    end
    local function minutes(v) return L.BOARD_MINUTES:format(math.floor(v / 60)) end
    local function days(v) return (v == 1 and L.BOARD_DAY or L.BOARD_DAYS):format(v) end
    while #lucky > 5 do table.remove(lucky) end
    while #unlucky > 5 do table.remove(unlucky) end
    return {
        { title = L.BOARD_FAILPULL, tip = L.BOARD_TIP_FAILPULL, icon = "swords", list = top(fail) },
        { title = L.BOARD_MISPULL, tip = L.BOARD_TIP_MISPULL, icon = "move", list = top(mispull) },
        { title = L.BOARD_DEATHS, tip = L.BOARD_TIP_DEATHS, icon = "x", list = top(death) },
        { title = L.BOARD_LUCKY, tip = L.BOARD_TIP_LUCKY, icon = "gem", list = lucky },
        { title = L.BOARD_UNLUCKY, tip = L.BOARD_TIP_UNLUCKY, icon = "scale", list = unlucky },
        { title = L.BOARD_REPAIR, tip = L.BOARD_TIP_REPAIR, icon = "hammer", list = top(repair, 5, gold) },
        { title = L.BOARD_MARATHON, tip = L.BOARD_TIP_MARATHON, icon = "timer", list = top(session, 5, hours) },
        { title = L.BOARD_GREETER, tip = L.BOARD_TIP_GREETER, icon = "message-circle", list = top(greet) },
        { title = L.BOARD_AFK, tip = L.BOARD_TIP_AFK, icon = "timer", list = top(afk) },
        { title = L.BOARD_JUMPER, tip = L.BOARD_TIP_JUMPER, icon = "sparkles", list = top(perNight, 5, function(v) return L.BOARD_PER_NIGHT:format(v) end) },
        { title = L.BOARD_BADLUCK, tip = L.BOARD_TIP_BADLUCK, icon = "scale", list = top(Community.BadLuck(since), 5, function(v) return (v == 1 and L.BOARD_NIGHT or L.BOARD_NIGHTS):format(v) end) },
        { title = L.BOARD_GHOST, tip = L.BOARD_TIP_GHOST, icon = "x", list = stat("ghost", minutes) },
        { title = L.BOARD_GUARD, tip = L.BOARD_TIP_GUARD, icon = "shield", list = stat("guard") },
        { title = L.BOARD_SPIRIT, tip = L.BOARD_TIP_SPIRIT, icon = "sparkles", list = stat("spirit") },
        { title = L.BOARD_TAXI, tip = L.BOARD_TIP_TAXI, icon = "arrow-left-right", list = stat("taxi") },
        { title = L.BOARD_HEARTH, tip = L.BOARD_TIP_HEARTH, icon = "rotate-ccw", list = stat("hearth") },
        { title = L.BOARD_JUNK, tip = L.BOARD_TIP_JUNK, icon = "scale", list = stat("junk", gold) },
        { title = L.BOARD_SHOP, tip = L.BOARD_TIP_SHOP, icon = "gem", list = stat("shop", gold) },
        { title = L.BOARD_AH, tip = L.BOARD_TIP_AH, icon = "hammer", list = stat("ah") },
        { title = L.BOARD_MAIL, tip = L.BOARD_TIP_MAIL, icon = "scroll-text", list = stat("mail") },
        { title = L.BOARD_KICK, tip = L.BOARD_TIP_KICK, icon = "swords", list = stat("kick") },
        { title = L.BOARD_OWL, tip = L.BOARD_TIP_OWL, icon = "star", list = stat("owl", days) },
        { title = L.BOARD_EARLY, tip = L.BOARD_TIP_EARLY, icon = "star-filled", list = stat("early", days) },
        { title = L.BOARD_STREAK, tip = L.BOARD_TIP_STREAK, icon = "badge-check", list = stat("streak", days) },
        { title = L.BOARD_QUOTES, tip = L.BOARD_TIP_QUOTES, icon = "newspaper", list = (function()
            local likes = {}
            local posts = store().posts
            if Community.testPosts then
                posts = {}
                for _, p in ipairs(store().posts) do posts[#posts + 1] = p end
                for _, p in ipairs(Community.testPosts) do posts[#posts + 1] = p end
            end
            for _, p in ipairs(posts) do
                if p.t >= since then
                    local n = 0
                    for _ in pairs(p.likes or {}) do n = n + 1 end
                    likes[p.a] = (likes[p.a] or 0) + n
                end
            end
            return top(likes)
        end)() },
    }
end

---------------------------------------------------------------------------
-- Quote of the week: the most liked pin board post of a week (Monday–Sunday).
-- Everyone computes the same winner; last week's winner shows once as a toast.
---------------------------------------------------------------------------
function Community.Week(t) return math.floor(((t or ns.Now()) + 3 * 86400) / (7 * 86400)) end

function Community.QuoteOfWeek(week)
    week = week or Community.Week()
    local best, bestN
    local posts = store().posts
    if Community.testPosts then
        posts = {}
        for _, p in ipairs(store().posts) do posts[#posts + 1] = p end
        for _, p in ipairs(Community.testPosts) do posts[#posts + 1] = p end
    end
    for _, p in ipairs(posts) do
        if Community.Week(p.t) == week then
            local n = 0
            for _ in pairs(p.likes or {}) do n = n + 1 end
            if n > 0 and (not best or n > bestN or (n == bestN and p.t < best.t)) then best, bestN = p, n end
        end
    end
    return best, bestN
end

function Community.QuoteText(p, n)
    local text = p.text
    if #text > 140 then text = text:sub(1, 137) .. "…" end
    return L.QOTW_LINE:format(text, display(p.a), n)
end

ns.On("LG_READY", function()
    ns.After(40, function()
        if ns.Database.Settings().modules.community == false or not IsInGuild() then return end
        local last = Community.Week() - 1
        local s = ns.Database.Settings()
        if (s.qotwSeen or 0) >= last then return end
        local p, n = Community.QuoteOfWeek(last)
        s.qotwSeen = last
        if p then UI.Toast(L.QOTW_LAST, Community.QuoteText(p, n)) end
    end)
end)

function Community.EventText(e)
    local d = e.d or {}
    if e.k == "failpull" then return L.EV_FAILPULL:format(display(e.who), d.b or "?", d.n or 0, d.of or 0)
    elseif e.k == "mispull" then return L.EV_MISPULL:format(display(e.who), e.by and Names.Display(e.by) or "?")
    elseif e.k == "death" then return L.EV_DEATH:format(display(e.who), d.b and (" (" .. d.b .. ")") or "")
    elseif e.k == "fall" then return L.EV_FALL:format(display(e.who), L["FALL_" .. tostring(d.c or "fall"):upper()] or d.c or "?")
    elseif e.k == "repair" then return L.EV_REPAIR:format(display(e.who), gold(d.c))
    elseif e.k == "session" then return L.EV_SESSION:format(display(e.who), hours(d.s))
    elseif e.k == "greet1" then return L.EV_GREET1:format(display(e.who))
    elseif e.k == "afk" then return L.EV_AFK:format(display(e.who))
    elseif e.k == "daily" then return L.EV_DAILY:format(display(e.who), tostring(d.day or "?"))
    elseif e.k == "jump" then return L.EV_JUMP:format(display(e.who), tonumber(d.n) or 0)
    elseif e.k == "consum" then
        local n, f = 0, 0
        for _, code in pairs(d.list or {}) do n = n + 1; if tostring(code):find("F", 1, true) then f = f + 1 end end
        return L.EV_CONSUM:format(f, n)
    end
    return e.k
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local period = 30

function Community.ConfirmRemove(id)
    StaticPopupDialogs.LIEBEGRUESSE_COMM_REMOVE = {
        text = L.COMM_REMOVE_CONFIRM, button1 = YES or "Yes", button2 = NO or "No",
        OnAccept = function(_, data) Community.Remove(data) end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("LIEBEGRUESSE_COMM_REMOVE", nil, nil, id)
end

UI.AddPage("community", L.PAGE_COMMUNITY, 25, function(content, page)
    local tabs = {}
    local holder = CreateFrame("Frame", nil, content)
    holder:SetPoint("TOPLEFT", 0, -38)
    holder:SetPoint("BOTTOMRIGHT")

    -- leaderboards
    local boards = CreateFrame("Frame", nil, holder)
    boards:SetAllPoints()
    local periodSeg = UI.Segmented(boards, 300, { { value = 7, text = L.PERIOD_WEEK }, { value = 30, text = L.PERIOD_MONTH },
        { value = 0, text = L.PERIOD_ALL } }, function() return period end, function(v) period = v; boards.Refresh() end)
    periodSeg:SetPoint("TOPLEFT")
    local mispullBtn = UI.Button(boards, L.MP_REPORT, 170, 24, function(self)
        local items = {}
        for _, key, name in ns.GroupUnits() do items[#items + 1] = { value = key, text = Names.Display(name) } end
        if #items == 0 then ns.Print(L.NOT_IN_GROUP); return end
        UI.OpenMenu(self, items, function(key) Community.ReportMispull(key) end, 200)
    end, "move")
    mispullBtn:SetPoint("TOPRIGHT")
    mispullBtn.tip = { L.MP_REPORT_TIP }
    -- quote of the week: one line above the boards
    local qotw = UI.Panel(boards, "panel", "borderDim")
    qotw:SetPoint("TOPLEFT", 0, -32)
    qotw:SetPoint("TOPRIGHT", 0, -32)
    qotw:SetHeight(34)
    qotw.bar = UI.Fill(qotw, "bronze", "ARTWORK")
    qotw.bar:SetPoint("TOPLEFT"); qotw.bar:SetPoint("BOTTOMLEFT"); qotw.bar:SetWidth(2)
    qotw.icon = UI.Icon(qotw, "newspaper", 14, "bronze")
    qotw.icon:SetPoint("LEFT", 12, 0)
    qotw.label = UI.Text(qotw, 11, "bronze", nil, nil, true)
    qotw.label:SetPoint("LEFT", qotw.icon, "RIGHT", 8, 0)
    qotw.text = UI.Text(qotw, 12, "text")
    qotw.text:SetPoint("LEFT", qotw.label, "RIGHT", 12, 0)
    qotw.text:SetWordWrap(false)
    qotw:EnableMouse(true)
    qotw:SetScript("OnEnter", function(self)
        local p, n = Community.QuoteOfWeek()
        local last, lastN = Community.QuoteOfWeek(Community.Week() - 1)
        local lines = { p and Community.QuoteText(p, n) or L.QOTW_NONE, " ", Theme.HexColor("muted", L.QOTW_TIP) }
        if last then table.insert(lines, 3, Theme.HexColor("bronze", L.QOTW_LAST) .. "  " .. Community.QuoteText(last, lastN)) end
        UI.Tooltip(self, L.QOTW_TITLE, lines)
    end)
    qotw:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- leaderboard cards in as many columns as fit, scrolling when needed
    local scroll, body = UI.ScrollArea(boards)
    scroll:SetPoint("TOPLEFT", 0, -74)
    scroll:SetPoint("BOTTOMRIGHT")
    local cards = {}
    local CARD_H, GAP, MIN_W, LINES = 128, 8, 250, 5
    local function card(i)
        local c = cards[i]
        if c then return c end
        c = UI.Panel(body, "panel", "borderDim")
        UI.Corners(c)
        c.icon = UI.Icon(c, "sparkles", 14, "accent"); c.icon:SetPoint("TOPLEFT", 12, -11)
        c.title = UI.Text(c, 13, "text"); c.title:SetPoint("LEFT", c.icon, "RIGHT", 7, 0)
        -- "?" with how the board is counted
        c.help = CreateFrame("Button", nil, c, "BackdropTemplate")
        c.help:SetSize(16, 16)
        c.help:SetPoint("TOPRIGHT", -10, -10)
        UI.Skin(c.help, "button", "borderDim")
        c.help.text = UI.Text(c.help, 11, "muted", "CENTER", nil, true)
        c.help.text:SetPoint("CENTER", 0, 0)
        c.help.text:SetText("?")
        c.help:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(Theme.Color("accent")); self.text:SetTextColor(Theme.Color("accent"))
            UI.Tooltip(self, c.title:GetText() or "", { c.tip or "", Theme.HexColor("muted", L.BOARD_TIP_PERIOD) })
        end)
        c.help:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(Theme.Color("borderDim")); self.text:SetTextColor(Theme.Color("muted")); GameTooltip:Hide()
        end)
        c.rule = UI.Fill(c, "borderDim", "ARTWORK"); c.rule:SetHeight(1)
        c.rule:SetPoint("LEFT", c.title, "RIGHT", 10, 0); c.rule:SetPoint("RIGHT", c.help, "LEFT", -8, 0)
        c.lines, c.values = {}, {}
        for k = 1, LINES do
            local line = UI.Text(c, 12, "textDim")
            line:SetPoint("TOPLEFT", 14, -34 - (k - 1) * 18)
            line:SetWordWrap(false)
            local value = UI.Text(c, 12, "muted", "RIGHT")
            value:SetPoint("TOPRIGHT", -14, -34 - (k - 1) * 18)
            c.lines[k], c.values[k] = line, value
        end
        cards[i] = c
        return c
    end
    local shown = 0
    local function layoutCards()
        local w = scroll:GetWidth() or 900
        if w < 50 then w = boards:GetWidth() or 900 end
        w = w - 10
        local cols = math.max(1, math.floor((w + GAP) / (MIN_W + GAP)))
        local cw = (w - (cols - 1) * GAP) / cols
        for i = 1, shown do
            local c = cards[i]
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", ((i - 1) % cols) * (cw + GAP), -math.floor((i - 1) / cols) * (CARD_H + GAP))
            c:SetSize(cw, CARD_H)
            for k = 1, LINES do
                c.values[k]:SetWidth(90)
                c.lines[k]:SetWidth(math.max(40, cw - 28 - 96))
            end
            c:Show()
        end
        for i = shown + 1, #cards do cards[i]:Hide() end
        body:SetSize(w, math.max(1, math.ceil(shown / cols) * (CARD_H + GAP)))
        if scroll.UpdateBar then scroll.UpdateBar() end
    end
    boards:SetScript("OnSizeChanged", layoutCards)
    function boards.Refresh()
        periodSeg:Refresh()
        local p, n = Community.QuoteOfWeek()
        qotw.label:SetText(ns.Upper(L.QOTW_TITLE))
        qotw.text:SetText(p and Community.QuoteText(p, n) or Theme.HexColor("muted", L.QOTW_NONE))
        qotw.text:SetWidth(math.max(60, (boards:GetWidth() or 900) - 60 - (qotw.label:GetStringWidth() or 120)))
        local list = Community.Boards(period > 0 and period or nil)
        shown = #list
        for i, b in ipairs(list) do
            local c = card(i)
            c.title:SetText(ns.Highlight(b.title, page.query or ""))
            -- search hit: accent frame around the board
            local hay = b.title or ""
            for k = 1, LINES do local e = b.list[k]; if e then hay = hay .. " " .. Names.Display(e.key or "") end end
            local hit = (page.query or ""):find("%S") and ns.SearchAny(hay, page.query)
            c:SetBackdropBorderColor(Theme.Color(hit and "accent" or "borderDim"))
            c.tip = b.tip
            c.help:SetShown(b.tip ~= nil)
            Theme.SetIcon(c.icon, b.icon)
            for k = 1, LINES do
                local entry = b.list[k]
                local medal = k == 1 and Theme.HexColor("gold", "1.") or Theme.HexColor("muted", k .. ".")
                c.lines[k]:SetText(entry and ("%s  %s"):format(medal, ns.Highlight(display(entry.key), page.query or ""))
                    or (k == 1 and Theme.HexColor("muted", L.BOARD_EMPTY) or ""))
                c.values[k]:SetText(entry and (entry.text or tostring(entry.n)) or "")
            end
        end
        layoutCards()
    end
    tabs.boards = boards

    -- pin board
    local pins = CreateFrame("Frame", nil, holder)
    pins:SetAllPoints()
    local kind = "quote"
    local compose = CreateFrame("Frame", nil, pins)
    compose:SetPoint("TOPLEFT")
    compose:SetPoint("TOPRIGHT")
    compose:SetHeight(64)
    local kindSeg = UI.Segmented(compose, 200, { { value = "quote", text = L.POST_QUOTE }, { value = "shout", text = L.POST_SHOUT } },
        function() return kind end, function(v) kind = v end)
    kindSeg:SetPoint("TOPLEFT")
    local about = UI.EditBox(compose, 240, 26, L.POST_ABOUT)
    about:SetPoint("LEFT", kindSeg, "RIGHT", 8, 0)
    local status = UI.Text(compose, 11, "muted")
    status:SetPoint("LEFT", about, "RIGHT", 12, 0)
    status:SetPoint("RIGHT", compose, "RIGHT", 0, 0)
    local text = UI.EditBox(compose, 400, 28, L.POST_TEXT)
    text:SetPoint("TOPLEFT", 0, -34)
    text:SetPoint("TOPRIGHT", -126, -34)
    text:SetMaxLetters(300)
    local function submit()
        local body = (text:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if #body < 2 then
            status:SetText(Theme.HexColor("warn", L.POST_TOO_SHORT))
            text:SetFocus()
            return
        end
        local aboutText = (about:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if Community.Post(kind, body, aboutText ~= "" and aboutText or nil) then
            text:SetText(""); about:SetText("")
            text:ClearFocus(); about:ClearFocus()
            status:SetText(Theme.HexColor("good", IsInGuild() and L.POST_DONE or L.POST_DONE_LOCAL))
            pins.Refresh()
        else
            status:SetText(Theme.HexColor("bad", L.POST_FAILED))
        end
    end
    local send = UI.Button(compose, L.POST_SEND, 118, 28, submit, "newspaper")
    send:SetPoint("TOPRIGHT", 0, -34)
    text.onEnter = submit
    about.onEnter = function() text:SetFocus() end
    about:SetScript("OnTabPressed", function() text:SetFocus() end)
    text:SetScript("OnTabPressed", function() about:SetFocus() end)
    local postList = UI.List(pins, {
        rowHeight = 46, sortKey = "text", sortDesc = true, noHeader = true,
        columns = {
            { key = "text", title = "", flex = true, wrap = true, text = function(r)
                local p = r.p
                local head = (p.k == "quote" and Theme.HexColor("gold", L.POST_QUOTE) or Theme.HexColor("accent", L.POST_SHOUT))
                    .. Theme.HexColor("muted", ("  %s %s · %s"):format(L.POST_BY, Names.Display(p.a), ns.Ago(p.t)))
                    .. (p.about and Theme.HexColor("muted", "  · " .. L.POST_ABOUT_SHORT .. " ") .. display(p.about) or "")
                local body = p.k == "quote" and ("“" .. p.text .. "”") or p.text
                return head .. "\n" .. Theme.HexColor("text", body)
            end, sort = function(r) return r.p.t end },
            { key = "likes", title = "", width = 80, align = "CENTER", text = function(r)
                local n, mine = 0, r.p.likes[Names.Me()]
                for _ in pairs(r.p.likes) do n = n + 1 end
                return Theme.HexColor(mine and "accent" or "muted", ("+%d"):format(n))
            end, sort = function(r) local n = 0; for _ in pairs(r.p.likes) do n = n + 1 end return n end },
            { key = "del", title = "", width = 30, align = "CENTER",
              text = function(r) return Community.CanRemove(r.p.id) and UI.Glyph("x", "bad", 12) or "" end,
              onClick = function(r) if Community.CanRemove(r.p.id) then Community.ConfirmRemove(r.p.id) end end,
              tip = function(r) if Community.CanRemove(r.p.id) then return L.COMM_REMOVE, { L.COMM_REMOVE_TIP } end end },
        },
        onClick = function(row, button)
            if button == "RightButton" then
                local entries = { { title = Names.Display(row.p.a) },
                    { text = row.p.likes[Names.Me()] and L.COMM_UNLIKE or L.COMM_LIKE, func = function() Community.Like(row.p.id); pins.Refresh() end } }
                if Community.CanRemove(row.p.id) then
                    entries[#entries + 1] = { divider = true }
                    entries[#entries + 1] = { text = L.COMM_REMOVE, color = "bad", func = function() Community.ConfirmRemove(row.p.id) end }
                end
                UI.ContextMenu(entries)
                return
            end
            Community.Like(row.p.id); pins.Refresh()
        end,
        onEnter = function(frame, row) UI.Tooltip(frame, L.POST_LIKE_TIP, {}) end,
    })
    postList:SetPoint("TOPLEFT", 0, -74)
    postList:SetPoint("BOTTOMRIGHT")
    postList:SetEmptyText(L.POST_EMPTY)
    function pins.Refresh()
        kindSeg:Refresh()
        local rows = {}
        for _, p in ipairs(store().posts) do rows[#rows + 1] = { key = p.id, p = p, t = p.t } end
        postList:SetRows(rows)
    end
    tabs.pins = pins

    -- history
    local history = CreateFrame("Frame", nil, holder)
    history:SetAllPoints()
    local histList = UI.List(history, {
        sortKey = "t", sortDesc = true,
        columns = {
            { key = "t", title = L.COL_WHEN, width = 120, text = function(r) return Theme.HexColor("muted", ns.Date(r.e.t)) end,
              sort = function(r) return r.e.t end, defaultDesc = true },
            { key = "text", title = L.COL_EVENT, flex = true, text = function(r) return Community.EventText(r.e) end },
            { key = "del", title = "", width = 30, align = "CENTER",
              text = function(r) return Community.CanRemove(r.e.id) and UI.Glyph("x", "bad", 12) or "" end,
              onClick = function(r) if Community.CanRemove(r.e.id) then Community.ConfirmRemove(r.e.id) end end,
              tip = function(r) if Community.CanRemove(r.e.id) then return L.COMM_REMOVE, { L.COMM_REMOVE_EVENT_TIP } end end },
        },
    })
    histList:SetAllPoints()
    histList:SetEmptyText(L.BOARD_EMPTY)
    function history.Refresh()
        local rows = {}
        -- running counters (daily stats, jumps) are no history entries
        for _, e in ipairs(store().events) do
            if e.k ~= "daily" and e.k ~= "jump" then rows[#rows + 1] = { key = e.id, e = e } end
        end
        histList:SetRows(rows)
    end
    tabs.history = history

    -- badges: every badge with its holders (Modules/Badges.lua)
    local badges = ns.Badges.BuildPage(holder)
    badges:SetAllPoints()
    tabs.badges = badges

    local bar = UI.SubTabs(content, { { key = "boards", title = L.COMM_TAB_BOARDS }, { key = "badges", title = L.BADGES },
        { key = "pins", title = L.COMM_TAB_PINS }, { key = "history", title = L.COMM_TAB_HISTORY } }, function(key)
        for k, t in pairs(tabs) do t:SetShown(k == key) end
        tabs[key].Refresh()
    end)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:Select("boards")
    page.searchHint = L.COMM_SEARCH
    -- every tab is searched (boards, badges, posts, history); the tab with hits opens
    boards.SearchHits = function(q)
        local n = 0
        for _, b in ipairs(Community.Boards(period > 0 and period or nil)) do
            local hay = b.title or ""
            for k = 1, LINES do local e = b.list[k]; if e then hay = hay .. " " .. Names.Display(e.key or "") end end
            if ns.SearchAny(hay, q) then n = n + 1 end
        end
        return n
    end
    boards.SearchApply = function() boards.Refresh() end
    pins.SearchHits = function(q) pins.Refresh(); return postList:SearchHits(q) end
    pins.SearchApply = function(q) postList:ShowFirstHit(q) end
    history.SearchHits = function(q) history.Refresh(); return histList:SearchHits(q) end
    history.SearchApply = function(q) histList:ShowFirstHit(q) end
    badges.SearchHits = function(q) badges.Refresh(); return badges.list:SearchHits(q) end
    badges.SearchApply = function(q) badges.list:ShowFirstHit(q) end
    page.Search = function(text)
        page.query = text
        return UI.TabSearch(bar, tabs, text)
    end
    page.OnShow = function() tabs[bar.current].Refresh() end
end, { section = "guild", icon = "crown", module = "community" })

-- all text of a post or event (names displayed), for the page search
function Community.SearchText(t)
    local parts = {}
    for k, v in pairs(t or {}) do
        if type(v) == "string" and k ~= "id" then
            parts[#parts + 1] = v
            if Names.Key(v) then parts[#parts + 1] = Names.Display(v) end
        end
    end
    return table.concat(parts, " ")
end

ns.On("LG_READY", function()
    ns.Movers.Anchor("failVote", L.MOVER_FAILVOTE, { "TOP", "TOP", 0, -430 }, 580, 150, nil,
        { icon = "swords", scalable = true, settings = function() ns.Window.Show("community") end })
    ns.Movers.Anchor("failVoteIcon", L.MOVER_FAILVOTE_ICON, { "TOP", "TOP", 160, -200 }, 36, 36, nil,
        { icon = "swords", scalable = true, settings = function() ns.Window.Show("notifications") end })
end)
