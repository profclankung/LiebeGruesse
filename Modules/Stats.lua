-- Personal statistics per character: dungeon and raid runs, boss kills and
-- wipes, epics seen and received, deaths, quests and gold.
local _, ns = ...
local Stats = ns.NewModule("stats")
ns.Stats = Stats
local UI, Theme, L, Names, Items = ns.UI, ns.Theme, ns.L, ns.Names, ns.Items

local function data(char)
    char = char or ns.Database.Char()
    char.stats = char.stats or {}
    local s = char.stats
    s.bosses = s.bosses or {}
    s.instances = s.instances or {}
    for _, k in ipairs({ "epicsSeen", "epicsLooted", "legendary", "deaths", "quests", "goldIn", "goldOut", "kills" }) do
        s[k] = s[k] or 0
    end
    s.since = s.since or ns.Now()
    return s
end

---------------------------------------------------------------------------
-- Recording
---------------------------------------------------------------------------
local current      -- { name, id, type, entered }
local lastLeft = {}

local function checkInstance()
    local inside, kind = IsInInstance()
    local name, _, _, _, _, _, _, mapID = ns.Call(GetInstanceInfo)
    if inside and name and (kind == "party" or kind == "raid") then
        -- ten-player dungeons in a raid group count as dungeon
        if kind == "raid" and not ns.RaidInstance() then kind = "party" end
        if current and current.id == mapID then return end
        local s = data()
        local entry = s.instances[name] or { runs = 0, kind = kind }
        -- a new run unless we were inside the same instance in the last 30 minutes
        if not lastLeft[mapID] or ns.Now() - lastLeft[mapID] > 1800 then
            entry.runs = entry.runs + 1
            entry.last = ns.Now()
            Stats.NewRun()
        end
        entry.kind = kind
        s.instances[name] = entry
        current = { name = name, id = mapID, kind = kind }
    elseif current then
        lastLeft[current.id] = ns.Now()
        current = nil
    end
end
ns.On("PLAYER_ENTERING_WORLD", function() ns.After(2, checkInstance) end)
ns.On("ZONE_CHANGED_NEW_AREA", function() ns.After(2, checkInstance) end)

-- pulls, wipes, kills, fastest kill and first-try kills per boss. A first try is
-- a kill on the first pull of that boss since entering the instance (a new run).
local pullStart, runPulls = nil, {}
ns.On("ENCOUNTER_START", function(_, encounterID, name)
    if ns.IsSecret(name) or type(name) ~= "string" then return end
    pullStart = GetTime()
    local s = data()
    local b = s.bosses[name] or { k = 0, w = 0 }
    b.p = (b.p or 0) + 1
    b.where = current and current.name or b.where
    b.kind = current and current.kind or b.kind
    if ns.Num(encounterID) then b.id = encounterID end
    s.bosses[name] = b
    runPulls[name] = (runPulls[name] or 0) + 1
end)
ns.On("ENCOUNTER_END", function(_, _, name, _, _, success)
    if ns.IsSecret(name) or ns.IsSecret(success) or type(name) ~= "string" then return end
    local s = data()
    local b = s.bosses[name] or { k = 0, w = 0 }
    if success == 1 then
        b.k = b.k + 1; b.last = ns.Now()
        local dur = pullStart and math.floor(GetTime() - pullStart + 0.5)
        if dur and dur > 0 and (not b.best or dur < b.best) then b.best = dur end
        if (runPulls[name] or 1) <= 1 then
            b.ft = (b.ft or 0) + 1
            if ns.Achievements then ns.Achievements.Bump((b.kind == "raid") and "firstTryRaid" or "firstTryDungeon") end
        end
    else
        b.w = b.w + 1
    end
    pullStart = nil
    b.where = current and current.name or b.where
    b.kind = current and current.kind or b.kind
    s.bosses[name] = b
end)
-- a new instance visit starts the "first try" count again
function Stats.NewRun() wipe(runPulls) end

local seenSources = {}
ns.On("LOOT_OPENED", function()
    local s = data()
    for slot = 1, (ns.Call(GetNumLootItems) or 0) do
        local link = ns.Call(GetLootSlotLink, slot)
        local item = Items.String(link)
        local info = item and Items.Info(item)
        if info and (info.quality or 0) >= 4 then
            local source = GetLootSourceInfo and ns.Call(GetLootSourceInfo, slot) or tostring(slot)
            local key = tostring(source) .. ":" .. item
            if not seenSources[key] then
                seenSources[key] = true
                s.epicsSeen = s.epicsSeen + 1
            end
        end
    end
end)

local lootPatterns
ns.On("CHAT_MSG_LOOT", function(_, text)
    if ns.IsSecret(text) or type(text) ~= "string" then return end
    if not lootPatterns then
        lootPatterns = {}
        for _, name in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF" }) do
            local fmt = _G[name]
            if type(fmt) == "string" then
                lootPatterns[#lootPatterns + 1] = "^" .. fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)") .. "$"
            end
        end
    end
    for _, p in ipairs(lootPatterns) do
        local link = text:match(p)
        if link then
            local info = Items.Info(Items.String(link))
            if info and (info.quality or 0) >= 4 then
                local s = data()
                s.epicsLooted = s.epicsLooted + 1
                if info.quality >= 5 then s.legendary = s.legendary + 1 end
                s.lastEpic = Items.String(link)
            end
            return
        end
    end
end)

ns.On("PLAYER_DEAD", function() local s = data(); s.deaths = s.deaths + 1 end)
ns.On("QUEST_TURNED_IN", function() local s = data(); s.quests = s.quests + 1 end)

local lastMoney
ns.On("PLAYER_MONEY", function()
    local money = ns.Call(GetMoney)
    if not money then return end
    if lastMoney then
        local s = data()
        local diff = money - lastMoney
        if diff > 0 then s.goldIn = s.goldIn + diff else s.goldOut = s.goldOut - diff end
    end
    lastMoney = money
end)
function Stats:OnLogin() lastMoney = ns.Call(GetMoney); ns.After(3, checkInstance) end

---------------------------------------------------------------------------
-- Aggregation (one character or all characters of the account)
---------------------------------------------------------------------------
function Stats.Collect(which)
    local chars = {}
    if which == "all" then
        for _, char in pairs(ns.db.chars) do if char.stats then chars[#chars + 1] = char end end
    else
        chars[1] = ns.Database.Char()
    end
    local out = { bosses = {}, instances = {}, epicsSeen = 0, epicsLooted = 0, legendary = 0, deaths = 0, quests = 0,
        goldIn = 0, goldOut = 0, dungeons = 0, raids = 0, kills = 0, wipes = 0 }
    for _, char in ipairs(chars) do
        local s = data(char)
        for _, k in ipairs({ "epicsSeen", "epicsLooted", "legendary", "deaths", "quests", "goldIn", "goldOut" }) do out[k] = out[k] + s[k] end
        for name, b in pairs(s.bosses) do
            local o = out.bosses[name] or { name = name, k = 0, w = 0, p = 0, ft = 0, where = b.where, kind = b.kind }
            o.k, o.w = o.k + b.k, o.w + b.w
            o.p, o.ft = o.p + (b.p or (b.k + b.w)), o.ft + (b.ft or 0)
            if b.best and (not o.best or b.best < o.best) then o.best = b.best end
            o.kind = o.kind or b.kind
            o.last = math.max(o.last or 0, b.last or 0)
            out.bosses[name] = o
            out.kills, out.wipes = out.kills + b.k, out.wipes + b.w
        end
        for name, inst in pairs(s.instances) do
            local o = out.instances[name] or { name = name, runs = 0, kind = inst.kind }
            o.runs = o.runs + inst.runs
            o.last = math.max(o.last or 0, inst.last or 0)
            out.instances[name] = o
            if inst.kind == "raid" then out.raids = out.raids + inst.runs else out.dungeons = out.dungeons + inst.runs end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local which = "char"

UI.AddPage("stats", L.PAGE_STATS, 70, function(root, page)
    local tabs = {}
    local holder = CreateFrame("Frame", nil, root)
    holder:SetPoint("TOPLEFT", 0, -40)
    holder:SetPoint("BOTTOMRIGHT")

    ---------------------------------------------------------------------
    -- Life statistics (own sheet)
    ---------------------------------------------------------------------
    local Life = ns.LifeStats
    local lifeTab = CreateFrame("Frame", nil, holder)
    lifeTab:SetAllPoints()
    local lifeView = Life.BuildSheet(lifeTab)
    lifeView:SetPoint("TOPLEFT")
    lifeView:SetPoint("BOTTOMRIGHT")
    local refresh = UI.Button(lifeTab, L.LIFE_REFRESH, 130, 24, function()
        if not Life.Capture(true) then ns.Print(L.LIFE_CANNOT_READ) end
        lifeTab.Refresh()
    end, "rotate-ccw")
    refresh:SetPoint("TOPRIGHT", 0, -2)
    local openWin = UI.Button(lifeTab, L.LIFE_OPEN_WINDOW, 150, 24, function() ns.LifeWindow.Show(ns.Names.Me()) end, "book-open")
    openWin:SetPoint("RIGHT", refresh, "LEFT", -8, 0)
    local targetBtn = UI.Button(lifeTab, L.LIFE_TARGET, 80, 24, function() ns.LifeStats.Inspect("target") end)
    targetBtn:SetPoint("RIGHT", openWin, "LEFT", -8, 0)
    function lifeTab.Refresh()
        lifeView:Show_(Life.Sheet(ns.Names.Me()))
    end
    tabs.life = lifeTab

    ---------------------------------------------------------------------
    -- Guild: everybody's sheet
    ---------------------------------------------------------------------
    local guildTab = CreateFrame("Frame", nil, holder)
    guildTab:SetAllPoints()
    local selected, compare = nil, true
    local guildList = UI.List(guildTab, {
        sortKey = "kills", sortDesc = true,
        columns = {
            { key = "name", title = L.COL_NAME, flex = true,
              text = function(r) return ns.ColorName(ns.Names.Display(r.sheet.n or r.key), r.sheet.c) end, sort = function(r) return r.key end },
            { key = "level", title = L.COL_LEVEL, width = 40, align = "CENTER", text = function(r) return tostring(r.sheet.l or "") end,
              sort = function(r) return r.sheet.l or 0 end, defaultDesc = true },
            { key = "kills", title = Life.BY_KEY.kills.label, width = 100, align = "RIGHT",
              text = function(r) return Life.Format("kills", Life.Value(r.sheet, "kills")) end,
              sort = function(r) return Life.Value(r.sheet, "kills") or 0 end, defaultDesc = true },
            { key = "quests", title = L.STATS_QUESTS, width = 70, align = "RIGHT",
              text = function(r) return Life.Format("quests", Life.Value(r.sheet, "quests")) end,
              sort = function(r) return Life.Value(r.sheet, "quests") or 0 end, defaultDesc = true },
            { key = "deaths", title = L.STATS_DEATHS, width = 60, align = "RIGHT",
              text = function(r) return Life.Format("deaths", Life.Value(r.sheet, "deaths")) end,
              sort = function(r) return Life.Value(r.sheet, "deaths") or 0 end, defaultDesc = true },
            { key = "dungeons", title = L.STATS_DUNGEONS, width = 80, align = "RIGHT",
              text = function(r) return Life.Format("dungeons", Life.Value(r.sheet, "dungeons")) end,
              sort = function(r) return Life.Value(r.sheet, "dungeons") or 0 end, defaultDesc = true },
            { key = "bosses", title = L.LIFE_BOSSES, width = 70, align = "RIGHT", text = function(r) return tostring(r.bosses) end,
              sort = function(r) return r.bosses end, defaultDesc = true },
            { key = "hk", title = Life.BY_KEY.honorKills.label, width = 90, align = "RIGHT",
              text = function(r) return Life.Format("honorKills", Life.Value(r.sheet, "honorKills")) end,
              sort = function(r) return Life.Value(r.sheet, "honorKills") or 0 end, defaultDesc = true },
            { key = "gold", title = Life.BY_KEY.peakGold.label, width = 110, align = "RIGHT",
              text = function(r) return Life.Format("peakGold", Life.Value(r.sheet, "peakGold")) end,
              sort = function(r) return Life.Value(r.sheet, "peakGold") or 0 end, defaultDesc = true },
            { key = "t", title = L.COL_LAST_SEEN, width = 80, text = function(r) return Theme.HexColor("muted", ns.Ago(r.sheet.t)) end,
              sort = function(r) return r.sheet.t or 0 end, defaultDesc = true },
        },
        onClick = function(row) selected = row.key; guildTab.Refresh() end,
    })
    guildList:SetPoint("TOPLEFT", 0, -34)
    guildList:SetPoint("BOTTOMRIGHT")
    guildList:SetEmptyText(L.LIFE_GUILD_EMPTY)
    local guildHint = UI.Text(guildTab, 11, "muted")
    guildHint:SetPoint("TOPLEFT", 2, -8)
    guildHint:SetText(L.LIFE_GUILD_HINT)
    local detail = CreateFrame("Frame", nil, guildTab)
    detail:SetAllPoints()
    local back = UI.Button(detail, L.LIFE_BACK, 110, 24, function() selected = nil; guildTab.Refresh() end, "chevron-right")
    back:SetPoint("TOPLEFT")
    local cmpCheck = UI.Check(detail, L.LIFE_COMPARE, function() return compare end, function(v) compare = v; guildTab.Refresh() end)
    cmpCheck:SetPoint("LEFT", back, "RIGHT", 14, 0)
    local inWindow = UI.Button(detail, L.LIFE_OPEN_WINDOW, 150, 24, function() if selected then ns.LifeWindow.Show(selected) end end, "book-open")
    inWindow:SetPoint("TOPRIGHT", 0, 0)
    local otherView = Life.BuildSheet(detail)
    otherView:SetPoint("TOPLEFT", 0, -34)
    otherView:SetPoint("BOTTOMRIGHT")
    function guildTab.Refresh()
        local sheet = selected and Life.Sheet(selected)
        detail:SetShown(sheet ~= nil)
        guildList:SetShown(sheet == nil)
        guildHint:SetShown(sheet == nil)
        if sheet then
            cmpCheck:Refresh()
            local mine = Life.Sheet(ns.Names.Me())
            otherView:Show_(sheet, compare and mine ~= sheet and mine or nil)
        else
            guildList:SetRows(Life.GuildRows())
        end
    end
    tabs.guild = guildTab

    ---------------------------------------------------------------------
    -- Addon statistics (recorded by this addon)
    ---------------------------------------------------------------------
    local content = CreateFrame("Frame", nil, holder)
    content:SetAllPoints()
    tabs.addon = content

    local bar = UI.SubTabs(root, { { key = "life", title = L.LIFE_TAB_MINE }, { key = "guild", title = L.LIFE_TAB_GUILD },
        { key = "addon", title = L.LIFE_TAB_ADDON } }, function(key)
        for k, t in pairs(tabs) do t:SetShown(k == key) end
        if key == "addon" then content.Refresh() else tabs[key].Refresh() end
    end)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    Life.ShowGuildMember = function(key) selected = key; bar:Select("guild") end

    local seg = UI.Segmented(content, 260, { { value = "char", text = L.STATS_THIS_CHAR }, { value = "all", text = L.STATS_ALL_CHARS } },
        function() return which end, function(v) which = v; content.Refresh() end)
    seg:SetPoint("TOPLEFT")

    local tiles = {}
    local TILES = {
        { "dungeons", "STATS_DUNGEONS", "book-open" }, { "raids", "STATS_RAIDS", "crown" }, { "kills", "STATS_KILLS", "swords" },
        { "wipes", "STATS_WIPES", "x" }, { "epicsSeen", "STATS_EPICS_SEEN", "gem" }, { "epicsLooted", "STATS_EPICS_LOOTED", "sparkles" },
        { "deaths", "STATS_DEATHS", "minus" }, { "quests", "STATS_QUESTS", "scroll-text" },
    }
    for i, def in ipairs(TILES) do
        local t = UI.Panel(content, "panel", "borderDim")
        UI.Corners(t)
        t.icon = UI.Icon(t, def[3], 16, "bronze"); t.icon:SetPoint("TOPLEFT", 12, -12)
        t.label = UI.Text(t, 11, "muted"); t.label:SetPoint("LEFT", t.icon, "RIGHT", 8, 0); t.label:SetText(ns.Upper(L[def[2]]))
        t.value = UI.Text(t, 22, "text"); t.value:SetPoint("BOTTOMLEFT", 12, 10)
        t.key = def[1]
        tiles[i] = t
    end
    local gold = UI.Text(content, 12, "textDim")
    local function layout()
        local w = content:GetWidth() or 900
        local tw = (w - 3 * 10) / 4
        for i, t in ipairs(tiles) do
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", ((i - 1) % 4) * (tw + 10), -36 - math.floor((i - 1) / 4) * 82)
            t:SetSize(tw, 72)
        end
    end
    content:HookScript("OnSizeChanged", layout)
    gold:SetPoint("TOPLEFT", 2, -206)

    local bosses = UI.List(content, {
        sortKey = "k", sortDesc = true,
        columns = {
            { key = "name", title = L.STATS_BOSS, flex = true, text = function(r) return r.name end },
            { key = "where", title = L.STATS_WHERE, width = 150, text = function(r) return Theme.HexColor("muted", r.where or "") end },
            { key = "k", title = L.STATS_KILLS, width = 70, align = "CENTER", text = function(r) return Theme.HexColor("good", r.k) end,
              sort = function(r) return r.k end, defaultDesc = true },
            { key = "w", title = L.STATS_WIPES, width = 70, align = "CENTER", text = function(r) return Theme.HexColor("bad", r.w) end,
              sort = function(r) return r.w end, defaultDesc = true },
        },
    })
    local instances = UI.List(content, {
        sortKey = "runs", sortDesc = true,
        columns = {
            { key = "name", title = L.STATS_INSTANCE, flex = true, text = function(r) return r.name end },
            { key = "kind", title = "", width = 60, text = function(r) return Theme.HexColor("muted", r.kind == "raid" and "Raid" or L.STATS_DUNGEON) end },
            { key = "runs", title = L.STATS_RUNS, width = 60, align = "CENTER", text = function(r) return tostring(r.runs) end,
              sort = function(r) return r.runs end, defaultDesc = true },
            { key = "last", title = L.COL_LAST_SEEN, width = 90, text = function(r) return Theme.HexColor("muted", ns.Ago(r.last)) end,
              sort = function(r) return -(r.last or 0) end },
        },
    })
    instances:SetPoint("TOPLEFT", 0, -232)
    instances:SetPoint("BOTTOMLEFT")
    bosses:SetPoint("TOPLEFT", instances, "TOPRIGHT", 14, 0)
    bosses:SetPoint("BOTTOMRIGHT")
    instances:SetEmptyText(L.STATS_EMPTY)
    bosses:SetEmptyText(L.STATS_EMPTY)

    function content.Refresh()
        seg:Refresh()
        layout()
        instances:SetWidth(math.max(300, ((content:GetWidth() or 900) - 14) * 0.45))
        local s = Stats.Collect(which)
        for _, t in ipairs(tiles) do t.value:SetText(tostring(s[t.key] or 0)) end
        gold:SetText(L.STATS_GOLD:format(ns.Professions.Money(s.goldIn), ns.Professions.Money(s.goldOut), s.legendary))
        local b, i = {}, {}
        for _, v in pairs(s.bosses) do v.key = v.name; b[#b + 1] = v end
        for _, v in pairs(s.instances) do v.key = v.name; i[#i + 1] = v end
        bosses:SetRows(b)
        instances:SetRows(i)
    end
    bar:Select("life")
    -- header search: lines of the life sheet, members (guild tab), bosses and instances
    page.searchHint = L.STATS_SEARCH
    -- every tab is searched; the tab with hits opens
    lifeTab.SearchHits = function(q) lifeView.query = q; lifeTab.Refresh(); return lifeView.hits or 0 end
    lifeTab.SearchApply = function() lifeTab.Refresh() end
    guildTab.SearchHits = function(q)
        otherView.query = q
        if selected then guildTab.Refresh(); return otherView.hits or 0 end
        guildList:SetRows(Life.GuildRows())
        return guildList:SearchHits(q)
    end
    guildTab.SearchApply = function(q) guildTab.Refresh(); if not selected then guildList:ShowFirstHit(q) end end
    content.SearchHits = function(q) content.Refresh(); return bosses:SearchHits(q) + instances:SearchHits(q) end
    content.SearchApply = function(q) content.Refresh(); bosses:ShowFirstHit(q); instances:ShowFirstHit(q) end
    page.Search = function(text)
        page.query = text
        lifeView.query, otherView.query = text, text
        return UI.TabSearch(bar, tabs, text)
    end
    page.OnShow = function()
        if bar.current == "addon" then content.Refresh() else tabs[bar.current].Refresh() end
    end
end, { section = "me", icon = "badge-check", module = "stats" })
