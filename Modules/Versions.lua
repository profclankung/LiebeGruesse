-- Version check: who runs which addon version (guild and current raid)
local _, ns = ...
local Versions = ns.NewModule("versions")
ns.Versions = Versions
local UI, Theme, L, Names, Comm = ns.UI, ns.Theme, ns.L, ns.Names, ns.Comm

Versions.heard = {}   -- [key] = { v, t, raw }
local raidReplies, raidAskedAt = {}, nil

function Versions.Heard(key, version, raw)
    if not key or type(version) ~= "string" then return end
    Versions.heard[key] = { v = version, t = ns.Now(), raw = raw }
    local m = ns.Database.Member(key)
    if m then m.v = version end
    -- a newer version heard: check (throttled) whether it is confirmed now
    if ns.CompareVersions(ns.version, version) < 0 then
        ns.Debounce("versions-update", 2, function() Versions.Notify() end)
    end
    ns.Debounce("versions-redraw", 0.5, function() ns.Window.Refresh("versions") end)
end

function Versions.Newest()
    local newest = ns.version
    -- only plausible versions (a fake "9.9.9" would mark everyone outdated)
    for _, h in pairs(Versions.heard) do
        if ns.CompareVersions(h.v, newest) > 0 and Versions.Plausible(h.v) then newest = h.v end
    end
    for _, m in pairs(ns.Database.Guild().members) do
        if m.v and ns.CompareVersions(m.v, newest) > 0 and Versions.Plausible(m.v) then newest = m.v end
    end
    local info = Versions.Available and Versions.Available()
    if info and ns.CompareVersions(info.v, newest) > 0 then newest = info.v end
    return newest
end

---------------------------------------------------------------------------
-- Update notice: a newer version counts only when an officer or at least
-- two guild members run it and it is plausible (same major, at most one
-- minor step ahead) – a single fake "9.9.9" cannot nag the guild.
-- Once per login a toast + chat line, afterwards only the sidebar chip and
-- the "UPDATE" badge at Versions until you updated.
---------------------------------------------------------------------------
local LOGIN_DELAY = 30
local update = { ready = false, shown = false }   -- ready: the login delay is over
Versions.test = nil                                 -- /lg test update: { v, by, count, keys }

local function parts(v)
    local p = {}
    for n in tostring(v or ""):gmatch("%d+") do p[#p + 1] = tonumber(n) end
    return p
end
function Versions.Plausible(v, mine)
    local a, b = parts(v), parts(mine or ns.version)
    if #a == 0 or #b == 0 then return false end
    if (a[1] or 0) ~= (b[1] or 0) then return false end
    return (a[2] or 0) <= (b[2] or 0) + 1
end

-- { v = "1.0.54", by = officer key or nil, count = members on it or newer, keys = {...} } or nil
function Versions.Available()
    if Versions.test then return Versions.test end
    if ns.version == "dev" then return nil end
    local seen = {}
    local function add(key, v)
        if type(key) ~= "string" or type(v) ~= "string" then return end
        if Names.Same(key, Names.Me()) or not ns.Guild.IsMember(key) then return end
        if ns.CompareVersions(v, ns.version) <= 0 or not Versions.Plausible(v) then return end
        if not seen[key] or ns.CompareVersions(v, seen[key]) > 0 then seen[key] = v end
    end
    for key, h in pairs(Versions.heard) do add(key, h.v) end
    for key, m in pairs(ns.Database.Guild().members or {}) do add(key, m.v) end
    -- newest confirmed version: everyone on it or newer counts
    local best
    for _, v in pairs(seen) do
        if not best or ns.CompareVersions(v, best.v) > 0 then
            local count, officer, keys = 0, nil, {}
            for key, sv in pairs(seen) do
                if ns.CompareVersions(sv, v) >= 0 then
                    count = count + 1
                    keys[#keys + 1] = key
                    if not officer and ns.Guild.IsOfficer(key) then officer = key end
                end
            end
            if officer or count >= 2 then best = { v = v, by = officer, count = count, keys = keys } end
        end
    end
    return best
end

-- "Ben Lienert (officer) and 11 others"
function Versions.UsedBy(info)
    if not info then return "" end
    local first = info.by or (info.keys and info.keys[1])
    local g = first and ns.Guild.Find(first)
    local label = first and ns.ColorName(Names.Display(g and g.name or first), g and g.class) or "?"
    if info.by then label = label .. " " .. L.UPDATE_OFFICER end
    local others = (info.count or 1) - 1
    if others <= 0 then return L.UPDATE_USED_ONE:format(label) end
    return L.UPDATE_USED:format(label, others, others == 1 and L.UPDATE_OTHER or L.UPDATE_OTHERS)
end

-- sidebar chip, nav badge and page follow the state
local lastState
local function refreshState()
    local info = Versions.Available()
    local v = info and info.v or nil
    if v ~= lastState then
        lastState = v
        if ns.Window.SetUpdate then ns.Window.SetUpdate(v, info) end
        ns.Window.BuildNav()
        ns.Window.Refresh("versions")
    end
    return info
end
Versions.RefreshState = refreshState

-- toast + chat line, once per login (force: tests)
function Versions.Notify(force)
    local info = refreshState()
    if not info then return end
    if not force then
        if update.shown or not update.ready then return end
        if ns.Database.Settings().updateMuted == info.v then return end
        if ns.Notify and ns.Notify.Settings().update == false then return end
    end
    update.shown = true
    local tag = Versions.test and (L.TEST_TAG .. " ") or ""
    ns.Print(tag .. L.UPDATE_CHAT:format(info.v, ns.version))
    UI.Toast(L.UPDATE_KICKER, L.UPDATE_TEXT:format(info.v, ns.version), ns.media .. "icon", {
        kicker = tag .. L.UPDATE_KICKER, big = true, duration = 15,
        lines = { Versions.UsedBy(info), L.UPDATE_HOW },
        action = function() ns.Window.Show("versions") end, actionText = L.UPDATE_CLICK, page = "versions",
    })
end

function Versions.Mute()
    local info = Versions.Available()
    if not info then return end
    if not Versions.test then ns.Database.Settings().updateMuted = info.v end
    ns.Print(L.UPDATE_MUTED:format(info.v))
    ns.Window.Refresh("versions")
end
function Versions.IsMuted(v) return ns.Database.Settings().updateMuted == v end

-- versions also travel with the profiles
ns.On("LG_PROFILE", function() if update.ready then ns.Debounce("versions-update", 2, function() Versions.Notify() end) end end)

ns.On("LG_READY", function()
    ns.After(LOGIN_DELAY, function()
        update.ready = true
        Versions.Notify()
    end)
end)

-- /lg test update: how the notice looks (nothing is sent or saved, 2 min)
function Versions.Test(off)
    if off then
        Versions.test = nil
        refreshState()
        return
    end
    local p = parts(ns.version)
    local fake = ("%d.%d.%d"):format(p[1] or 1, p[2] or 0, (p[3] or 0) + 2)
    local me = Names.Me()
    Versions.test = { v = fake, by = me, count = 12, keys = { me } }
    Versions.Notify(true)
    ns.After(120, function() if Versions.test and Versions.test.v == fake then Versions.Test(true) end end)
end

Comm.Register("VQ", function(data, sender, channel, raw)
    Versions.Heard(sender, data.v, raw)
    local reply = channel == "GUILD" and "GUILD" or "GROUP"
    Comm.Send("VR", { v = ns.version }, reply, { priority = "normal" })
end)

Comm.Register("VR", function(data, sender, _, raw)
    Versions.Heard(sender, data.v, raw)
    raidReplies[sender] = data.v
end)

function Versions.CheckGroup()
    if not IsInGroup() then ns.Print(L.NOT_IN_GROUP); return end
    wipe(raidReplies)
    raidAskedAt = GetTime()
    Comm.Send("VQ", { v = ns.version }, "GROUP", { priority = "alert" })
    ns.After(6, function()
        local missing, old = {}, {}
        local newest = Versions.Newest()
        for _, key, name in ns.GroupUnits() do
            if not Names.Same(key, Names.Me()) then
                local v = raidReplies[key]
                if not v then missing[#missing + 1] = Names.Display(name)
                elseif ns.CompareVersions(v, newest) < 0 then old[#old + 1] = ("%s (%s)"):format(Names.Display(name), v) end
            end
        end
        ns.Print(L.VERSION_RESULT:format(#missing == 0 and L.NOBODY or table.concat(missing, ", "),
            #old == 0 and L.NOBODY or table.concat(old, ", ")))
        ns.Window.Refresh("versions")
    end)
end

function Versions.CheckGuild()
    Comm.Send("VQ", { v = ns.version }, "GUILD", { priority = "normal" })
end

---------------------------------------------------------------------------
-- Officers remind members with an older version (VN). One guild message for
-- everybody (each client checks itself whether it is behind) or a whisper to
-- one player. Sender: cooldown (30 min, setting) and one reminder per player
-- and day; receiver: only from officers, only a plausible newer version, at
-- most once a day.
---------------------------------------------------------------------------
function Versions.NudgeSettings()
    local s = ns.Database.Settings()
    s.versionNudge = s.versionNudge or {}
    local o = s.versionNudge
    if o.cooldown == nil then o.cooldown = 30 end
    if o.accept == nil then o.accept = true end
    o.nudged = o.nudged or {}
    return o
end

function Versions.CanNudge() return IsInGuild() and ns.Guild.IsOfficer(Names.Me()) == true end

-- players (rows) on an older version than the newest, and how many of them are online
function Versions.Outdated(newest)
    newest = newest or Versions.Newest()
    local rows, online = {}, 0
    for _, r in ipairs(Versions.PlayerRows(newest)) do
        if r.v and ns.CompareVersions(r.v, newest) < 0 then
            rows[#rows + 1] = r
            if r.online then online = online + 1 end
        end
    end
    return rows, online
end

-- seconds until the guild-wide reminder may go out again (0 = now)
function Versions.NudgeWait()
    local o = Versions.NudgeSettings()
    return math.max(0, (o.at or 0) + o.cooldown * 60 - ns.Now())
end

function Versions.NudgeAll()
    if not Versions.CanNudge() then ns.Print(L.NUDGE_ONLY_OFFICERS); return false end
    local wait = Versions.NudgeWait()
    if wait > 0 then ns.Print(L.NUDGE_WAIT:format(math.ceil(wait / 60))); return false end
    local newest = Versions.Newest()
    local rows, online = Versions.Outdated(newest)
    if online == 0 then ns.Print(L.NUDGE_NOBODY); return false end
    local o = Versions.NudgeSettings()
    o.at = ns.Now()
    for _, r in ipairs(rows) do if r.online then o.nudged[r.key] = ns.Now() end end
    Comm.Send("VN", { v = newest, t = ns.Now() }, "GUILD", { priority = "normal" })
    ns.Print(L.NUDGE_SENT:format(online, newest))
    ns.Window.Refresh("versions")
    return true
end

-- reminded today already?
function Versions.Nudged(key)
    local t = Versions.NudgeSettings().nudged[key]
    return t and date("%Y%m%d", t) == date("%Y%m%d", ns.Now())
end

function Versions.NudgeOne(r)
    if not Versions.CanNudge() then ns.Print(L.NUDGE_ONLY_OFFICERS); return false end
    if Versions.Nudged(r.key) then ns.Print(L.NUDGE_TODAY:format(r.name or Names.Display(r.key))); return false end
    local newest = Versions.Newest()
    local sent = false
    for _, c in ipairs(r.chars or {}) do
        if c.online and c.v and ns.CompareVersions(c.v, newest) < 0 then
            Comm.Send("VN", { v = newest, t = ns.Now() }, "WHISPER", { target = c.name, priority = "normal" })
            sent = true
        end
    end
    if not sent then ns.Print(L.NUDGE_OFFLINE:format(r.name or Names.Display(r.key))); return false end
    Versions.NudgeSettings().nudged[r.key] = ns.Now()
    ns.Print(L.NUDGE_SENT_ONE:format(r.name or Names.Display(r.key)))
    ns.Window.Refresh("versions")
    return true
end

function Versions.ShowNudge(v, from, test)
    local g = ns.Guild.Find(from)
    local who = ns.ColorName(g and g.name or Names.Display(from), g and g.class)
    local kicker = (test and (L.TEST_TAG .. " ") or "") .. L.UPDATE_KICKER
    UI.Toast(kicker, L.NUDGE_TEXT:format(v), ns.media .. "icon", {
        kicker = kicker, big = true, duration = 15,
        lines = { L.NUDGE_LINE:format(ns.version, who), L.UPDATE_HOW },
        action = function() ns.Window.Show("versions") end, actionText = L.UPDATE_CLICK, page = "versions",
    })
    ns.Print(L.NUDGE_CHAT:format(who, v, ns.version))
end

Comm.Register("VN", function(data, sender, channel)
    if channel ~= "GUILD" and channel ~= "WHISPER" then return end
    if not ns.Guild.IsMember(sender) or not ns.Guild.IsOfficer(sender) then return end
    local v = type(data.v) == "string" and data.v or nil
    if not v or #v > 12 or ns.CompareVersions(v, ns.version) <= 0 or not Versions.Plausible(v) then return end
    local o = Versions.NudgeSettings()
    if not o.accept or (ns.Notify and ns.Notify.Settings().update == false) then return end
    local today = date("%Y%m%d", ns.Now())
    if o.seenDay == today then return end
    o.seenDay = today
    Versions.ShowNudge(v, sender)
end)

---------------------------------------------------------------------------
-- Players: one row per person – alts are grouped under their main
---------------------------------------------------------------------------
-- the main a guild character belongs to (own characters: the account main)
function Versions.OwnerOf(key)
    if Names.Same(key, Names.Me()) or (ns.db and ns.db.chars and ns.db.chars[key]) then
        return (ns.Account and ns.Account.Main()) or Names.Me()
    end
    local m = ns.Database.Member(key)
    local main = m and type(m.m) == "string" and Names.Key(m.m)
    return main or key
end

-- every guild member (with or without the addon), grouped per player
function Versions.PlayerRows(newest)
    local byOwner, rows = {}, {}
    for key, g in pairs(ns.Guild.members) do
        local h = Versions.heard[key]
        local m = ns.Database.Member(key)
        local v = Names.Same(key, Names.Me()) and ns.version or (h and h.v) or (m and m.v)
        local owner = Versions.OwnerOf(key)
        local r = byOwner[owner]
        if not r then
            r = { key = owner, chars = {}, newest = newest }
            byOwner[owner] = r
            rows[#rows + 1] = r
        end
        local t = h and h.t or (m and m.seen)
        r.chars[#r.chars + 1] = { key = key, name = g.name, class = g.class, v = v, online = g.online, t = t, level = g.level or 0 }
        if v and (not r.v or ns.CompareVersions(v, r.v) > 0) then r.v = v end
        if t and (not r.t or t > r.t) then r.t = t end
        if g.online then r.online = true end
    end
    for _, r in ipairs(rows) do
        -- the main first, then online characters, then by level
        table.sort(r.chars, function(a, b)
            local am, bm = Names.Same(a.key, r.key), Names.Same(b.key, r.key)
            if am ~= bm then return am end
            if (a.online and 1 or 0) ~= (b.online and 1 or 0) then return a.online == true end
            if a.level ~= b.level then return a.level > b.level end
            return a.key < b.key
        end)
        local first = r.chars[1]
        local mainHere = Names.Same(first.key, r.key)
        r.name, r.class = first.name, first.class
        if not mainHere then
            -- main outside the guild (or unknown): show the main's name, class from its profile if known
            local mm = ns.Database.Member(r.key)
            r.name = Names.Display(r.key)
            r.class = (mm and mm.c) or first.class
        end
        for _, c in ipairs(r.chars) do
            if c.online then
                if not Names.Same(c.key, r.key) then r.onlineAs = Names.Display(c.name) end
                break
            end
        end
    end
    return rows
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local mode = "guild"

UI.AddPage("versions", L.PAGE_VERSIONS, 30, function(content, page)
    -- update card (only while a newer version is confirmed)
    local card = UI.Panel(content, "panel", "borderDim")
    UI.Corners(card)
    card:SetPoint("TOPLEFT")
    card:SetPoint("TOPRIGHT", -ns.Window.SearchReserve(), 0)
    card.stripe = UI.Fill(card, "accent", "ARTWORK")
    card.stripe:SetPoint("TOPLEFT"); card.stripe:SetPoint("BOTTOMLEFT"); card.stripe:SetWidth(3)
    card.badge = UI.Panel(card, "input", "accent")
    card.badge:SetSize(52, 52)
    card.badge:SetPoint("TOPLEFT", 19, -16)
    card.icon = UI.Icon(card.badge, "circle-arrow-up", 26, "accent")
    card.icon:SetPoint("CENTER")
    card.kicker = UI.Text(card, 11, "accent", "LEFT", nil, true)
    card.kicker:SetText(ns.Upper(L.UPDATE_KICKER))
    card.title = UI.Text(card, 22, "text", "LEFT", nil, true)
    card.text = UI.Text(card, 13, "textDim", "LEFT")
    card.text:SetWordWrap(true); card.text:SetJustifyV("TOP")
    card.steps = {}
    for i = 1, 3 do
        local d = UI.Fill(card, "bronze", "ARTWORK"); d:SetSize(13, 13)
        if d.SetRotation then d:SetRotation(math.rad(45)) end
        local n = UI.Text(card, 11, "bg", "CENTER", nil, true); n:SetPoint("CENTER", d, "CENTER", 0, 0); n:SetText(tostring(i))
        local s = UI.Text(card, 12, "textDim", "LEFT"); s:SetWordWrap(true); s:SetJustifyV("TOP")
        s:SetText(L["UPDATE_STEP" .. i])
        card.steps[i] = { d = d, n = n, s = s }
    end
    card.dl = UI.Button(card, L.DL_BUTTON, 190, 24, function() ns.ShowDownloadLink() end, "copy")
    card.dl.tip = { L.DL_BUTTON_TIP }
    card.mute = UI.Button(card, "", 190, 24, function() Versions.Mute() end)
    card.mute.tip = { L.UPDATE_MUTE_TIP }
    card:Hide()

    -- officers: remind members with an older version
    local nudge = UI.Panel(content, "panel", "borderDim")
    nudge:SetPoint("TOPRIGHT", -ns.Window.SearchReserve(), 0)
    nudge:SetHeight(72)
    nudge.stripe = UI.Fill(nudge, "warn", "ARTWORK")
    nudge.stripe:SetPoint("TOPLEFT"); nudge.stripe:SetPoint("BOTTOMLEFT"); nudge.stripe:SetWidth(3)
    nudge.badge = UI.Panel(nudge, "input", "warn"); nudge.badge:SetSize(42, 42); nudge.badge:SetPoint("LEFT", 16, 0)
    nudge.icon = UI.Icon(nudge.badge, "circle-arrow-up", 22, "warn"); nudge.icon:SetPoint("CENTER")
    nudge.kicker = UI.Text(nudge, 11, "warn", nil, nil, true); nudge.kicker:SetPoint("TOPLEFT", 70, -12)
    nudge.kicker:SetText(ns.Upper(L.NUDGE_KICKER))
    nudge.title = UI.Text(nudge, 17, "text", nil, nil, true); nudge.title:SetPoint("TOPLEFT", 70, -26); nudge.title:SetWordWrap(false)
    nudge.text = UI.Text(nudge, 11, "muted"); nudge.text:SetPoint("TOPLEFT", 70, -48); nudge.text:SetWordWrap(false)
    nudge.btn = UI.Button(nudge, "", 200, 26, function() Versions.NudgeAll() end, "megaphone")
    nudge.btn:SetPoint("TOPRIGHT", -14, -14)
    nudge.hint = UI.Text(nudge, 10, "muted", "RIGHT"); nudge.hint:SetPoint("TOPRIGHT", -14, -46); nudge.hint:SetWordWrap(false)
    nudge:Hide()

    local guildBtn = UI.Button(content, L.CHECK_GUILD, 150, 22, function() mode = "guild"; Versions.CheckGuild(); page.OnShow() end)
    guildBtn:SetPoint("TOPLEFT")
    local groupBtn = UI.Button(content, L.CHECK_GROUP, 150, 22, function() mode = "group"; Versions.CheckGroup(); page.OnShow() end)
    groupBtn:SetPoint("LEFT", guildBtn, "RIGHT", 8, 0)
    local info = UI.Text(content, 11, "muted", "LEFT")
    info:SetPoint("LEFT", groupBtn, "RIGHT", 12, 0)
    info:SetWordWrap(false)
    -- the summary ends before the page search (top right corner)
    local function fitInfo() info:SetWidth(math.max(40, (content:GetWidth() or 800) - 320 - ns.Window.SearchReserve())) end
    content:HookScript("OnSizeChanged", fitInfo)
    fitInfo()

    local list = UI.List(content, {
        sortKey = "v", sortDesc = true,
        columns = {
            { key = "name", title = L.COL_NAME, flex = true,
              text = function(r)
                  local more = r.chars and #r.chars > 1 and Theme.HexColor("muted", "  " .. L.VERSION_MORE_CHARS:format(#r.chars - 1)) or ""
                  return ns.ColorName(r.name, r.class) .. more
              end,
              sort = function(r) return r.key end,
              tip = function(r)
                  if not r.chars or #r.chars < 2 then return end
                  local lines = {}
                  for _, c in ipairs(r.chars) do
                      local v = c.v and Theme.HexColor(ns.CompareVersions(c.v, r.newest) < 0 and "warn" or "good", c.v) or Theme.HexColor("muted", "–")
                      local on = c.online and ("  " .. Theme.HexColor("good", L.ONLINE)) or ""
                      lines[#lines + 1] = ns.ColorName(c.name, c.class) .. "   " .. v .. on
                  end
                  lines[#lines + 1] = " "
                  lines[#lines + 1] = Theme.HexColor("muted", L.VERSION_CHARS_HINT)
                  return L.VERSION_CHARS_TIP, lines
              end },
            { key = "v", title = L.COL_VERSION, width = 120,
              text = function(r)
                  if not r.v then return Theme.HexColor(r.inGroup and "bad" or "muted", r.inGroup and L.NO_ADDON or "–") end
                  local cmp = ns.CompareVersions(r.v, r.newest)
                  return Theme.HexColor(cmp < 0 and "warn" or "good", r.v)
              end,
              sort = function(r) return r.v and (r.v:gsub("(%d+)", function(n) return ("%05d"):format(tonumber(n)) end)) or "" end },
            { key = "t", title = L.COL_LAST_SEEN, width = 120, text = function(r) return Theme.HexColor("muted", r.t and ns.Ago(r.t) or "–") end,
              sort = function(r) return -(r.t or 0) end },
            { key = "remind", title = "", width = 34, align = "CENTER", noHighlight = true,
              text = function(r)
                  if not Versions.CanNudge() or not r.v or ns.CompareVersions(r.v, r.newest) >= 0 then return "" end
                  local ready = r.online and not Versions.Nudged(r.key)
                  return UI.Glyph("bell", ready and "accent" or "muted", 12)
              end,
              onClick = function(r) if Versions.CanNudge() and r.v and ns.CompareVersions(r.v, r.newest) < 0 then Versions.NudgeOne(r) end end,
              tip = function(r)
                  if not Versions.CanNudge() or not r.v or ns.CompareVersions(r.v, r.newest) >= 0 then return end
                  if Versions.Nudged(r.key) then return L.NUDGE_REMIND, { L.NUDGE_REMIND_DONE } end
                  if not r.online then return L.NUDGE_REMIND, { L.NUDGE_REMIND_OFFLINE } end
                  return L.NUDGE_REMIND, { L.NUDGE_REMIND_TIP:format(r.v, r.newest) }
              end },
            { key = "online", title = L.COL_STATUS, width = 170,
              text = function(r)
                  if not r.online then return Theme.HexColor("muted", L.OFFLINE) end
                  if r.onlineAs then return Theme.HexColor("good", L.ONLINE) .. Theme.HexColor("muted", " · " .. L.VERSION_ON_CHAR:format(r.onlineAs)) end
                  return Theme.HexColor("good", L.ONLINE)
              end,
              sort = function(r) return r.online and 0 or 1 end },
        },
        -- found by every character's name, not only the main's
        searchText = function(r)
            local parts = { r.name or "", r.v or "" }
            for _, c in ipairs(r.chars or {}) do parts[#parts + 1] = c.name end
            return table.concat(parts, " ")
        end,
    })
    list:SetPoint("TOPLEFT", guildBtn, "BOTTOMLEFT", 0, -10)
    list:SetPoint("BOTTOMRIGHT")

    -- the officers' reminder card sits below the update card (or at the top)
    local function layoutNudge(anchor)
        local newest = Versions.Newest()
        local rows, online = Versions.Outdated(newest)
        local show = Versions.CanNudge() and #rows > 0
        nudge:SetShown(show)
        guildBtn:ClearAllPoints()
        if not show then
            if anchor then guildBtn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12) else guildBtn:SetPoint("TOPLEFT") end
            return
        end
        nudge:ClearAllPoints()
        if anchor then
            nudge:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12); nudge:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -12)
        else
            nudge:SetPoint("TOPLEFT"); nudge:SetPoint("TOPRIGHT", -ns.Window.SearchReserve(), 0)
        end
        local W = math.max(300, (content:GetWidth() or 800) - (anchor and 8 or ns.Window.SearchReserve()))
        nudge.title:SetText(L.NUDGE_TITLE:format(#rows, newest))
        nudge.title:SetWidth(math.max(80, W - 70 - 230))
        nudge.text:SetText(L.NUDGE_HINT:format(online)); nudge.text:SetWidth(math.max(80, W - 70 - 230))
        local wait = Versions.NudgeWait()
        nudge.btn:SetText(L.NUDGE_BUTTON:format(online))
        nudge.btn:SetEnabled(wait == 0 and online > 0)
        nudge.btn.tip = { wait > 0 and L.NUDGE_WAIT:format(math.ceil(wait / 60)) or (online == 0 and L.NUDGE_NOBODY or L.NUDGE_BUTTON_TIP) }
        nudge.hint:SetText(wait > 0 and L.NUDGE_WAIT:format(math.ceil(wait / 60)) or L.NUDGE_RULES:format(Versions.NudgeSettings().cooldown))
        guildBtn:SetPoint("TOPLEFT", nudge, "BOTTOMLEFT", 0, -12)
    end

    local function layoutCard()
        local info = Versions.Available()
        card:SetShown(info ~= nil)
        guildBtn:ClearAllPoints()
        if not info then layoutNudge(nil); return end
        local W = math.max(300, (content:GetWidth() or 800) - 8)
        local narrow = W < 640
        local tx = 19 + 52 + 16
        local tw = W - tx - 16 - (narrow and 0 or 206)
        card.kicker:ClearAllPoints(); card.kicker:SetPoint("TOPLEFT", tx, -16)
        card.title:ClearAllPoints(); card.title:SetPoint("TOPLEFT", tx, -30); card.title:SetWidth(tw)
        card.title:SetText(L.UPDATE_TITLE:format(info.v))
        card.text:ClearAllPoints(); card.text:SetPoint("TOPLEFT", tx, -58); card.text:SetWidth(tw)
        local behind = 0
        local a, b = {}, {}
        for n in info.v:gmatch("%d+") do a[#a + 1] = tonumber(n) end
        for n in ns.version:gmatch("%d+") do b[#b + 1] = tonumber(n) end
        if a[1] == b[1] and a[2] == b[2] then behind = (a[3] or 0) - (b[3] or 0) end
        local mine = Theme.HexColor("warn", ns.version)
        local lead = behind > 1 and L.UPDATE_BEHIND_N:format(mine, behind) or L.UPDATE_BEHIND:format(mine)
        card.text:SetText(lead .. " " .. L.UPDATE_CONFIRMED:format(Versions.UsedBy(info)))
        local y = 58 + math.max(14, card.text:GetStringHeight() or 14) + 10
        -- how to update: one row when wide, stacked when narrow
        local colW = narrow and tw or math.floor((tw - 2 * 12) / 3)
        local rowH = 0
        for i, st in ipairs(card.steps) do
            local x = narrow and tx or (tx + (i - 1) * (colW + 12))
            local sy = narrow and y or y
            st.d:ClearAllPoints(); st.d:SetPoint("TOPLEFT", card, "TOPLEFT", x + 2, -(sy + 2))
            st.s:ClearAllPoints(); st.s:SetPoint("TOPLEFT", card, "TOPLEFT", x + 22, -sy); st.s:SetWidth(colW - 22)
            local h = math.max(16, st.s:GetStringHeight() or 14)
            if narrow then y = y + h + 6 else rowH = math.max(rowH, h) end
        end
        if not narrow then y = y + rowH + 4 end
        local muted = Versions.IsMuted(info.v)
        card.mute:SetText(muted and L.UPDATE_MUTED_BTN or L.UPDATE_MUTE:format(info.v))
        card.mute:SetEnabled(not muted)
        if muted then card.mute.tip = { L.UPDATE_MUTED_TIP } else card.mute.tip = { L.UPDATE_MUTE_TIP } end
        card.mute:ClearAllPoints()
        card.dl:ClearAllPoints()
        if narrow then
            card.dl:SetPoint("TOPLEFT", card, "TOPLEFT", tx, -(y + 4)); y = y + 30
            card.mute:SetPoint("TOPLEFT", card, "TOPLEFT", tx, -(y + 4)); y = y + 34
        else
            card.dl:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -16)
            card.mute:SetPoint("TOPRIGHT", card.dl, "BOTTOMRIGHT", 0, -6)
        end
        local h = math.max(y + 12, 16 + 52 + 16)
        card:SetHeight(h)
        layoutNudge(card)
    end
    content:HookScript("OnSizeChanged", function() if page.frame and page.frame:IsShown() then ns.Debounce("versions-card", 0.05, layoutCard) end end)

    page.searchHint = L.VERSION_SEARCH
    page.Search = function(text) page.query = text; page.OnShow(); return list:ShowFirstHit(text) end
    page.searchList = list
    page.OnShow = function()
        layoutCard()
        local newest = Versions.Newest()
        local rows = {}
        if mode == "group" and IsInGroup() then
            for _, key, name in ns.GroupUnits() do
                local h = Versions.heard[key]
                local v = Names.Same(key, Names.Me()) and ns.version or (raidReplies[key] or (h and h.v))
                local unit = ns.UnitForKey(key)
                local _, class = ns.Call(UnitClass, unit or "")
                rows[#rows + 1] = { key = key, name = name, class = class, v = v, t = h and h.t, online = true,
                    inGroup = true, newest = newest }
            end
        else
            rows = Versions.PlayerRows(newest)
        end
        list:SetRows(rows)
        local with = 0
        for _, r in ipairs(rows) do if r.v then with = with + 1 end end
        local fmt = (mode == "group" and IsInGroup()) and L.VERSION_SUMMARY or L.VERSION_PLAYERS
        info:SetText(fmt:format(ns.version, newest, with, #rows))
    end
end, { section = "guild", icon = "badge-check", badge = function()
    return Versions.Available() and L.UPDATE_BADGE or nil
end })

---------------------------------------------------------------------------
-- Refresh button (window header): asks the guild for fresh data once,
-- then redraws the current page. Throttled so spamming it costs nothing.
---------------------------------------------------------------------------
local lastRefresh = -999
function ns.RefreshData()
    local now = GetTime()
    if now - lastRefresh < 20 then
        ns.Print(L.REFRESH_WAIT:format(math.ceil(20 - (now - lastRefresh))))
        ns.Window.Refresh()
        return false
    end
    lastRefresh = now
    if ns.Guild and ns.Guild.Request then ns.Guild.Request() end
    if ns.Profile and ns.Profile.Update then ns.Profile.Update(true) end
    if IsInGuild() then
        Comm.Send("H", { v = ns.version }, "GUILD", { priority = "normal" })
        Versions.CheckGuild()
    end
    if IsInGroup and IsInGroup() then Comm.Send("VQ", { v = ns.version }, "GROUP", { priority = "normal" }) end
    if ns.Blessings and ns.Blessings.Request then ns.Blessings.Request() end
    ns.Print(L.REFRESH_DONE)
    -- answers arrive over the next seconds
    ns.After(1, function() ns.Window.Refresh() end)
    ns.After(6, function() ns.Window.Refresh() end)
    return true
end
