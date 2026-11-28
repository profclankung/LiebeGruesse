-- Speedruns page (Raid tools): guild records / personal bests per dungeon,
-- own runs, boss statistics (pulls, wipes, first try) and the settings.
-- Every record has a share button: guild or party chat, or a copy box for Discord.
local _, ns = ...
local Page = {}
ns.RunsPage = Page
local UI, Theme, L, Names = ns.UI, ns.Theme, ns.L, ns.Names
local Runs, Data = ns.Runs, ns.RunsData

local state = { kind = "party", wing = "all", which = "guild", selected = nil, bossKind = "all", bossWhich = "char" }
Page.state = state

local function display(key)
    local g = ns.Guild.Find(key)
    return ns.ColorName(g and g.name or Names.Display(key), g and g.class)
end

local function shareMenu(anchor, rec)
    UI.OpenMenu(anchor, {
        { value = "GUILD", text = L.RUN_SHARE_GUILD },
        { value = "PARTY", text = L.RUN_SHARE_PARTY },
        { value = "discord", text = L.RUN_SHARE_DISCORD },
    }, function(v)
        if v == "discord" then Runs.ShowDiscord(rec) else Runs.Post(rec, v) end
    end, 180)
end
Page.ShareMenu = shareMenu

local function classIcons(rec)
    local out = {}
    for _, m in ipairs(rec.g or {}) do out[#out + 1] = ns.ClassIcon and ns.ClassIcon(m.c, 14) or "" end
    return table.concat(out, "")
end

---------------------------------------------------------------------------
-- Detail card (right side): time, splits, group, share
---------------------------------------------------------------------------
local function buildDetail(parent)
    local d = UI.Panel(parent, "panel", "borderDim")
    UI.Corners(d)
    local scroll, body = UI.ScrollArea(d)
    scroll:SetPoint("TOPLEFT", 12, -12)
    scroll:SetPoint("BOTTOMRIGHT", -12, 12)
    d.kicker = UI.Text(body, 11, "accent", nil, nil, true); d.kicker:SetPoint("TOPLEFT", 0, 0)
    d.kicker:SetWordWrap(false)
    d.time = UI.Text(body, 30, "text", nil, nil, true); d.time:SetPoint("TOPLEFT", 0, -16)
    d.sub = UI.Text(body, 11, "muted"); d.sub:SetPoint("TOPLEFT", 0, -52); d.sub:SetWordWrap(false)
    d.tags = UI.Text(body, 11, "textDim"); d.tags:SetPoint("TOPLEFT", 0, -68); d.tags:SetWordWrap(false)
    d.share = UI.Button(body, L.RUN_SHARE, 96, 24, function(self) if d.rec then shareMenu(self, d.rec) end end, "share-2")
    d.share:SetPoint("TOPRIGHT", 0, 0)
    d.share.tip = { L.RUN_SHARE_TIP }
    d.splitsTitle = UI.Text(body, 12, "bronze", nil, nil, true); d.splitsTitle:SetPoint("TOPLEFT", 0, -96)
    d.lines = {}
    d.empty = UI.Empty(d, 260)
    d.empty:SetPoint("CENTER")
    local function line(i)
        local l = d.lines[i]
        if l then return l end
        l = CreateFrame("Frame", nil, body)
        l:SetHeight(18)
        l.left = UI.Text(l, 12, "text"); l.left:SetPoint("LEFT"); l.left:SetWordWrap(false)
        l.right = UI.Text(l, 12, "text", "RIGHT", nil, true); l.right:SetPoint("RIGHT")
        l.mid = UI.Text(l, 12, "text", "RIGHT", nil, true); l.mid:SetPoint("RIGHT", -60, 0)
        d.lines[i] = l
        return l
    end
    function d.Show_(rec)
        d.rec = rec
        local has = rec ~= nil
        scroll:SetShown(has)
        d.empty:SetShown(not has)
        if not has then d.empty:Set("flag", L.RUN_PICK, L.RUN_PICK_HINT); return end
        local w = math.max(120, (scroll:GetWidth() or 300) - 4)
        body:SetWidth(w)
        local rank = rec.ok ~= false and ns.RunsSync.Rank(rec)
        local kick = rank == 1 and L.RUN_KICK_RECORD or (rank and L.RUN_KICK_RANK:format(rank) or L.RUN_KICK_RUN)
        d.kicker:SetText(ns.Upper(kick .. " · " .. Data.Name(rec.w)))
        d.kicker:SetWidth(w - 104)
        d.time:SetText(Runs.Format(Runs.Final(rec)))
        local pen = Runs.Penalty()
        d.sub:SetText(L.RUN_DETAIL_SUB:format(Runs.Format(rec.raw), rec.d or 0, pen, ns.Date(rec.t), rec.v or "?"))
        d.sub:SetWidth(w)
        local tags = {}
        if rec.ok ~= false then tags[#tags + 1] = Theme.HexColor("good", L.RUN_TAG_VERIFIED) else tags[#tags + 1] = Theme.HexColor("warn", L.RUN_TAG_UNFINISHED) end
        local guildies = 0
        for _, m in ipairs(rec.g or {}) do if ns.Guild.IsMember(m.k) or Names.Same(m.k, Names.Me()) then guildies = guildies + 1 end end
        tags[#tags + 1] = Theme.HexColor("lapis", L.RUN_TAG_GUILD:format(guildies, #(rec.g or {})))
        if (rec.d or 0) == 0 then tags[#tags + 1] = Theme.HexColor("good", L.RUN_TAG_FLAWLESS) end
        d.tags:SetText(table.concat(tags, Theme.HexColor("muted", "  ·  ")))
        d.tags:SetWidth(w)
        d.share:SetShown(rec.w ~= nil)
        -- splits against the next better record (or the record itself when it is the best)
        local list = Runs.Records(rec.w, "guild")
        local cmp
        for i, o in ipairs(list) do if o.id == rec.id then cmp = list[i + 1]; break end end
        cmp = cmp or (list[1] ~= nil and list[1].id ~= rec.id and list[1]) or nil
        d.splitsTitle:SetText(ns.Upper(L.RUN_SPLITS) .. (cmp and Theme.HexColor("muted", "   " .. L.RUN_VS:format(Runs.Format(Runs.Final(cmp)))) or ""))
        local y, n = -116, 0
        for _, sp in ipairs(rec.s or {}) do
            n = n + 1
            local l = line(n)
            l:ClearAllPoints(); l:SetPoint("TOPLEFT", 0, y); l:SetWidth(w)
            l.left:SetText(Data.BossName(sp.b or "?")); l.left:SetWidth(w - 130)
            l.mid:SetText(Runs.Format(sp.s))
            local other = cmp and Runs.SplitOf(cmp, sp.b)
            if other then
                local dv = sp.s - other
                l.right:SetText(Theme.HexColor(dv <= 0 and "good" or "bad", Runs.Delta(dv)))
            else
                l.right:SetText("")
            end
            l:Show()
            y = y - 19
        end
        y = y - 10
        n = n + 1
        local head = line(n)
        head:ClearAllPoints(); head:SetPoint("TOPLEFT", 0, y); head:SetWidth(w)
        head.left:SetText(Theme.HexColor("bronze", ns.Upper(L.RUN_GROUP))); head.left:SetWidth(w - 130)
        head.mid:SetText("")
        head.right:SetText(Theme.HexColor("muted", L.RUN_DPS_HPS))
        head:Show()
        y = y - 22
        local ROLE_ICON = { T = UI.Glyph("shield", "lapis", 12), H = UI.Glyph("sparkles", "good", 12), D = UI.Glyph("swords", "bad", 12) }
        for _, m in ipairs(rec.g or {}) do
            n = n + 1
            local l = line(n)
            l:ClearAllPoints(); l:SetPoint("TOPLEFT", 0, y); l:SetWidth(w)
            local g = ns.Guild.Find(m.k)
            l.left:SetText((ROLE_ICON[m.r] or "") .. "  " .. ns.ColorName(g and g.name or Names.Display(m.k), m.c or (g and g.class)))
            l.left:SetWidth(w - 70)
            l.mid:SetText("")
            local meter = (m.dps or m.hps) and (tostring(math.floor(m.dps or 0)) .. " / " .. tostring(math.floor(m.hps or 0))) or "–"
            l.right:SetText(Theme.HexColor("muted", meter))
            l:Show()
            y = y - 19
        end
        n = n + 1
        local note = line(n)
        note:ClearAllPoints(); note:SetPoint("TOPLEFT", 0, y - 4); note:SetWidth(w)
        note.left:SetText(Theme.HexColor("muted", ns.RunsMeter.Available() and "" or L.RUN_NO_METER)); note.left:SetWidth(w)
        note.mid:SetText(""); note.right:SetText("")
        note:Show()
        y = y - 24
        for i = n + 1, #d.lines do d.lines[i]:Hide() end
        body:SetHeight(-y + 8)
        if scroll.UpdateBar then scroll.UpdateBar() end
    end
    d:SetScript("OnSizeChanged", function() if d.rec then d.Show_(d.rec) end end)
    return d
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
UI.AddPage("runs", L.PAGE_RUNS, 52, function(content, page)
    local tabs = {}
    local holder = CreateFrame("Frame", nil, content)
    holder:SetPoint("TOPLEFT", 0, -38)
    holder:SetPoint("BOTTOMRIGHT")

    -- detail card for leaderboard and own runs
    local DETAIL_W = 340
    local main = CreateFrame("Frame", nil, holder)
    main:SetAllPoints()
    local detail = buildDetail(main)
    detail:SetPoint("TOPRIGHT", 0, -32)
    detail:SetPoint("BOTTOMRIGHT")
    detail:SetWidth(DETAIL_W)
    local area = CreateFrame("Frame", nil, main)
    area:SetPoint("TOPLEFT", 0, -32)
    area:SetPoint("BOTTOMRIGHT", detail, "BOTTOMLEFT", -12, 0)
    -- narrow: the detail gets less room
    main:SetScript("OnSizeChanged", function(self, w)
        detail:SetWidth((w or 900) < 760 and 270 or DETAIL_W)
    end)
    local function select(rec) state.selected = rec and rec.id or nil; detail.Show_(rec) end

    ---------------------------------------------------------------------
    -- Leaderboard
    ---------------------------------------------------------------------
    local lb = CreateFrame("Frame", nil, area)
    lb:SetAllPoints()
    local chips = UI.FilterChips(main, {
        { value = "party", text = L.RUN_DUNGEONS, icon = "castle" },
        { value = "raid", text = L.RUN_RAIDS, icon = "crown" },
    }, function() return state.kind end, function(v) state.kind = v; state.wing = "all"; page.OnShow() end)
    chips:SetPoint("TOPLEFT")
    chips:SetWidth(210)
    local wings = UI.Dropdown(main, 220, function()
        local items = { { value = "all", text = L.RUN_ALL_WINGS } }
        for _, d in ipairs(Data.LIST) do if d.kind == state.kind then items[#items + 1] = { value = d.key, text = d.name } end end
        return items
    end, function() return state.wing end, function(v) state.wing = v; page.OnShow() end)
    wings:SetPoint("TOPLEFT", chips, "TOPRIGHT", 10, 0)
    local whichSeg = UI.Segmented(main, 220, { { value = "guild", text = L.RUN_GUILD_RECORDS }, { value = "pb", text = L.RUN_PERSONAL } },
        function() return state.which end, function(v) state.which = v; page.OnShow() end)
    whichSeg:SetPoint("TOPLEFT", wings, "TOPRIGHT", 10, 0)
    local info = UI.Text(main, 11, "muted", "RIGHT")
    info:SetPoint("TOPRIGHT", 0, -6)
    info:SetWordWrap(false)
    local function fitTop()
        local w = main:GetWidth() or 900
        local used = 210 + 10 + 220 + 10 + 220 + 14
        info:SetWidth(math.max(1, w - used))
        info:SetShown(w - used > 120)
        whichSeg:SetShown(w > 560)
    end
    main:HookScript("OnSizeChanged", fitTop)

    local lbListRefresh
    local lbList = UI.List(lb, {
        sortKey = "wing", rowHeight = 28,
        columns = {
            { key = "rank", title = "#", width = 34, align = "CENTER",
              text = function(r) return r.rank == 1 and Theme.HexColor("gold", "1") or tostring(r.rank) end, sort = function(r) return r.rank end },
            { key = "wing", title = L.RUN_COL_DUNGEON, flex = true, minWidth = 150,
              text = function(r) return Data.Name(r.rec.w) end, sort = function(r) return Data.Name(r.rec.w) .. ("%03d"):format(r.rank) end },
            { key = "time", title = L.RUN_COL_TIME, width = 74, align = "RIGHT",
              text = function(r) return Theme.HexColor("text", Runs.Format(Runs.Final(r.rec))) end, sort = function(r) return Runs.Final(r.rec) end },
            { key = "deaths", title = L.RUN_COL_DEATHS, width = 60, align = "CENTER", optional = 2,
              text = function(r) return Theme.HexColor((r.rec.d or 0) == 0 and "good" or "warn", tostring(r.rec.d or 0)) end,
              sort = function(r) return r.rec.d or 0 end },
            { key = "group", title = L.RUN_COL_GROUP, width = 96, optional = 3, noHighlight = true,
              text = function(r) return classIcons(r.rec) end,
              tip = function(r)
                  local lines = {}
                  for _, m in ipairs(r.rec.g or {}) do lines[#lines + 1] = display(m.k) end
                  return L.RUN_GROUP, lines
              end },
            { key = "date", title = L.RUN_COL_DATE, width = 70, optional = 1,
              text = function(r) return Theme.HexColor("muted", date("%d.%m.", r.rec.t or 0)) end, sort = function(r) return -(r.rec.t or 0) end },
            { key = "share", title = "", width = 30, align = "CENTER", noHighlight = true,
              text = function() return UI.Glyph("share-2", "textDim", 12) end,
              onClick = function(r, _, cell) shareMenu(cell, r.rec) end,
              tip = function() return L.RUN_SHARE, { L.RUN_SHARE_TIP } end },
        },
        onClick = function(r) select(r.rec); lbListRefresh() end,
        isSelected = function(r) return state.selected == r.rec.id end,
        searchText = function(r)
            local parts = { Data.Name(r.rec.w) }
            for _, m in ipairs(r.rec.g or {}) do parts[#parts + 1] = Names.Display(m.k) end
            return table.concat(parts, " ")
        end,
    })
    lbList:SetAllPoints()
    lbList:SetEmptyText(L.RUN_EMPTY, L.RUN_EMPTY_HINT, "flag")
    lbListRefresh = function() lbList:Draw() end
    function lb.Refresh()
        chips:Show(); wings:Show(); whichSeg:Show(); fitTop()
        chips:Refresh(); wings:Refresh(); whichSeg:Refresh()
        local rows = {}
        for _, d in ipairs(Data.LIST) do
            if d.kind == state.kind and (state.wing == "all" or state.wing == d.key) then
                local recs = Runs.Records(d.key, state.which)
                local limit = state.wing == "all" and 3 or 10
                for i, rec in ipairs(recs) do
                    if i > limit then break end
                    rows[#rows + 1] = { key = rec.id, rank = i, rec = rec }
                end
            end
        end
        lbList:SetRows(rows)
        local pen = Runs.Penalty()
        info:SetText(pen > 0 and L.RUN_PENALTY_INFO:format(pen) or L.RUN_NO_PENALTY_INFO)
        local sel
        for _, r in ipairs(rows) do if r.rec.id == state.selected then sel = r.rec end end
        detail.Show_(sel or (rows[1] and rows[1].rec))
        if not sel and rows[1] then state.selected = rows[1].rec.id end
    end
    tabs.lb = lb

    ---------------------------------------------------------------------
    -- My runs
    ---------------------------------------------------------------------
    local mine = CreateFrame("Frame", nil, area)
    mine:SetAllPoints()
    local mineList = UI.List(mine, {
        sortKey = "date", sortDesc = true, rowHeight = 26,
        columns = {
            { key = "date", title = L.RUN_COL_DATE, width = 110, defaultDesc = true,
              text = function(r) return Theme.HexColor("muted", ns.Date(r.rec.t)) end, sort = function(r) return r.rec.t or 0 end },
            { key = "wing", title = L.RUN_COL_DUNGEON, flex = true, minWidth = 140,
              text = function(r) return r.rec.w and Data.Name(r.rec.w) or (Data.InstanceName(r.rec.i) or tostring(r.rec.i)) end },
            { key = "time", title = L.RUN_COL_TIME, width = 74, align = "RIGHT",
              text = function(r) return Runs.Format(Runs.Final(r.rec)) end, sort = function(r) return Runs.Final(r.rec) end },
            { key = "deaths", title = L.RUN_COL_DEATHS, width = 60, align = "CENTER", optional = 2,
              text = function(r) return tostring(r.rec.d or 0) end, sort = function(r) return r.rec.d or 0 end },
            { key = "status", title = L.RUN_COL_STATUS, width = 110, optional = 1,
              text = function(r)
                  if r.rec.ok == false then return Theme.HexColor("warn", L.RUN_TAG_UNFINISHED) end
                  if r.pb then return Theme.HexColor("gold", L.RUN_TAG_PB) end
                  return Theme.HexColor("good", L.RUN_TAG_VERIFIED)
              end },
            { key = "share", title = "", width = 30, align = "CENTER", noHighlight = true,
              text = function(r) return r.rec.w and UI.Glyph("share-2", "textDim", 12) or "" end,
              onClick = function(r, _, cell) if r.rec.w then shareMenu(cell, r.rec) end end,
              tip = function(r) if r.rec.w then return L.RUN_SHARE, { L.RUN_SHARE_TIP } end end },
        },
        onClick = function(r) select(r.rec); mineList:Draw() end,
        isSelected = function(r) return state.selected == r.rec.id end,
    })
    mineList:SetAllPoints()
    mineList:SetEmptyText(L.RUN_MINE_EMPTY, L.RUN_MINE_HINT, "timer")
    function mine.Refresh()
        chips:Hide(); wings:Hide(); whichSeg:Hide()
        info:Show()
        local rows = {}
        local best = {}
        for _, rec in ipairs(Runs.Store().history) do
            if rec.ok and rec.w and (not best[rec.w] or Runs.Final(rec) < Runs.Final(best[rec.w])) then best[rec.w] = rec end
        end
        for _, rec in ipairs(Runs.Store().history) do
            rows[#rows + 1] = { key = rec.id, rec = rec, pb = rec.w and best[rec.w] == rec }
        end
        mineList:SetRows(rows)
        local run = Runs.Active()
        info:SetText(run and L.RUN_ACTIVE_INFO:format(run.n or "?", Runs.Format(Runs.Elapsed(run))) or L.RUN_MINE_COUNT:format(#rows))
        local sel
        for _, r in ipairs(rows) do if r.rec.id == state.selected then sel = r.rec end end
        detail.Show_(sel)
    end
    tabs.mine = mine

    ---------------------------------------------------------------------
    -- Bosses: pulls, wipes, kills, first try
    ---------------------------------------------------------------------
    local boss = CreateFrame("Frame", nil, holder)
    boss:SetAllPoints()
    local bChips = UI.FilterChips(boss, {
        { value = "all", text = L.RUN_ALL, icon = "skull" },
        { value = "party", text = L.RUN_DUNGEONS, icon = "castle" },
        { value = "raid", text = L.RUN_RAIDS, icon = "crown" },
    }, function() return state.bossKind end, function(v) state.bossKind = v; boss.Refresh() end)
    bChips:SetPoint("TOPLEFT")
    bChips:SetWidth(330)
    local bSeg = UI.Segmented(boss, 240, { { value = "char", text = L.STATS_THIS_CHAR }, { value = "all", text = L.STATS_ALL_CHARS } },
        function() return state.bossWhich end, function(v) state.bossWhich = v; boss.Refresh() end)
    bSeg:SetPoint("TOPLEFT", bChips, "TOPRIGHT", 12, 0)
    local bossList = UI.List(boss, {
        sortKey = "p", sortDesc = true,
        columns = {
            { key = "name", title = L.RUN_COL_BOSS, flex = true, minWidth = 140, text = function(r) return r.name end, sort = function(r) return r.name end },
            { key = "where", title = L.RUN_COL_INSTANCE, width = 160, optional = 2,
              text = function(r) return Theme.HexColor("muted", r.where or "–") end, sort = function(r) return r.where or "" end },
            { key = "p", title = L.RUN_COL_PULLS, width = 56, align = "RIGHT", defaultDesc = true, text = function(r) return tostring(r.p or 0) end, sort = function(r) return r.p or 0 end },
            { key = "w", title = L.RUN_COL_WIPES, width = 56, align = "RIGHT", defaultDesc = true,
              text = function(r) return Theme.HexColor((r.w or 0) > 0 and "warn" or "muted", tostring(r.w or 0)) end, sort = function(r) return r.w or 0 end },
            { key = "k", title = L.RUN_COL_KILLS, width = 56, align = "RIGHT", defaultDesc = true, text = function(r) return tostring(r.k or 0) end, sort = function(r) return r.k or 0 end },
            { key = "rate", title = L.RUN_COL_RATE, width = 70, align = "RIGHT", optional = 1, defaultDesc = true,
              text = function(r)
                  local pct = math.floor(r.rate * 100 + 0.5)
                  return Theme.HexColor(pct >= 60 and "good" or (pct >= 30 and "warn" or "bad"), pct .. " %")
              end, sort = function(r) return r.rate end },
            { key = "best", title = L.RUN_COL_FASTEST, width = 70, align = "RIGHT", optional = 3,
              text = function(r) return r.best and Runs.Format(r.best) or Theme.HexColor("muted", "–") end, sort = function(r) return r.best or 1e9 end },
            { key = "ft", title = L.RUN_COL_FIRSTTRY, width = 70, align = "CENTER", defaultDesc = true,
              text = function(r) return (r.ft or 0) > 0 and Theme.HexColor("good", tostring(r.ft)) or Theme.HexColor("muted", "–") end,
              sort = function(r) return r.ft or 0 end },
            { key = "last", title = L.RUN_COL_LASTKILL, width = 90, optional = 4,
              text = function(r) return Theme.HexColor("muted", r.last and ns.Date(r.last) or "–") end, sort = function(r) return -(r.last or 0) end },
        },
    })
    bossList:SetPoint("TOPLEFT", 0, -32)
    bossList:SetPoint("BOTTOMRIGHT")
    bossList:SetEmptyText(L.STATS_EMPTY)
    function boss.Refresh()
        bChips:Refresh(); bSeg:Refresh()
        local s = ns.Stats.Collect(state.bossWhich)
        local rows, counts = {}, { all = 0, party = 0, raid = 0 }
        for _, b in pairs(s.bosses) do
            local kind = b.kind or "party"
            counts.all = counts.all + 1
            counts[kind] = (counts[kind] or 0) + 1
            if state.bossKind == "all" or state.bossKind == kind then
                local pulls = math.max(b.p or 0, (b.k or 0) + (b.w or 0))
                rows[#rows + 1] = { key = b.name, name = b.name, where = b.where, p = pulls, w = b.w, k = b.k, best = b.best,
                    ft = b.ft, last = b.last, rate = pulls > 0 and (b.k or 0) / pulls or 0 }
            end
        end
        for k, n in pairs(counts) do bChips:SetCount(k, n) end
        bossList:SetRows(rows)
    end
    tabs.boss = boss

    ---------------------------------------------------------------------
    -- Settings
    ---------------------------------------------------------------------
    local settingsTab = UI.SettingsPane(holder, function(form)
        local o = Runs.Settings
        local function get(k) return function() return o()[k] end end
        local function set(k, after) return function(v) o()[k] = v; if after then after() end; ns.Fire("LG_RUNS") end end
        local track = form:Section(L.RUN_SET_TRACKING)
        track:Toggle(L.RUN_SET_ENABLED, get("enabled"), set("enabled", Runs.Check), { tip = L.RUN_SET_ENABLED_TIP })
        track:Toggle(L.RUN_SET_RAIDS, get("raids"), set("raids", Runs.Check), { tip = L.RUN_SET_RAIDS_TIP })
        track:Segment(L.RUN_SET_START, { { value = "pull", text = L.RUN_SET_START_PULL }, { value = "enter", text = L.RUN_SET_START_ENTER } },
            get("startOn"), set("startOn"), { width = 200, tip = L.RUN_SET_START_TIP })
        track:Slider(L.RUN_SET_PENALTY, 0, 30, 1, get("penalty"), set("penalty", function() ns.Window.Refresh("runs") end),
            { tip = L.RUN_SET_PENALTY_TIP, fmt = function(v) return v == 0 and L.OFF or ("+" .. v .. " s") end })
        local timer = form:Section(L.RUN_SET_TIMER)
        timer:Toggle(L.RUN_SET_TIMER_SHOW, get("timer"), set("timer"), { tip = L.RUN_SET_TIMER_SHOW_TIP })
        timer:Toggle(L.RUN_SET_SPLITS, get("splits"), set("splits"))
        timer:Segment(L.RUN_SET_COMPARE, { { value = "pb", text = L.RUN_PERSONAL }, { value = "guild", text = L.RUN_GUILD_RECORD } },
            get("compare"), set("compare"), { width = 220, tip = L.RUN_SET_COMPARE_TIP })
        timer:Toggle(L.RUN_SET_HIDECOMBAT, get("hideCombat"), set("hideCombat"), { tip = L.RUN_SET_HIDECOMBAT_TIP })
        timer:Slider(L.RUN_SET_ROWS, 3, 12, 1, get("rows"), set("rows"))
        timer:Slider(L.CD_SCALE, 0.6, 1.6, 0.05, get("scale"), set("scale"), { fmt = function(v) return ("%d %%"):format(v * 100 + 0.5) end })
        timer:Buttons({ { L.MOVE_ELEMENTS, function() ns.Window.ToggleMovers() end, width = 160, icon = "move" },
            { L.RUN_SET_PREVIEW, function() ns.RunsTimer.Test() end, width = 160, icon = "flag" } }, { col = 0 })
        local share = form:Section(L.RUN_SET_SHARING)
        share:Toggle(L.RUN_SET_SHARE, get("share"), set("share"), { tip = L.RUN_SET_SHARE_TIP })
        share:Toggle(L.RUN_SET_ANNOUNCE, get("announce"), set("announce"), { tip = L.RUN_SET_ANNOUNCE_TIP })
        share:Toggle(L.RUN_SET_ACCEPT, get("accept"), set("accept"), { tip = L.RUN_SET_ACCEPT_TIP })
        local plaus = form:Section(L.RUN_SET_PLAUSIBLE)
        plaus:Note(L.RUN_SET_PLAUSIBLE_NOTE, { col = 0, height = 60 })
        plaus:Info(L.RUN_SET_REJECTED, function() return tostring(#ns.RunsSync.rejected) end, { tipFn = function()
            local out = {}
            for _, x in ipairs(ns.RunsSync.rejected) do out[#out + 1] = Names.Display(x.by) .. ": " .. tostring(x.why) end
            return #out > 0 and table.concat(out, "\n") or L.RUN_SET_REJECTED_NONE
        end })
    end)
    tabs.settings = settingsTab

    local bar = UI.SubTabs(content, {
        { key = "lb", title = L.RUN_TAB_LEADERBOARD }, { key = "mine", title = L.RUN_TAB_MINE },
        { key = "boss", title = L.RUN_TAB_BOSSES }, { key = "settings", title = L.SETTINGS_TAB, icon = "settings", iconOnly = true },
    }, function(key)
        main:SetShown(key == "lb" or key == "mine")
        lb:SetShown(key == "lb"); mine:SetShown(key == "mine")
        boss:SetShown(key == "boss"); settingsTab:SetShown(key == "settings")
        tabs[key].Refresh()
    end)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -ns.Window.SearchReserve(), 0)
    bar:Select("lb")
    Page.ShowTab = function(key) bar:Select(key == "settings" and "settings" or key) end
    page.ShowSettings = function() bar:Select("settings") end
    settingsTab.form.reveal = page.ShowSettings

    page.searchHint = L.RUN_SEARCH
    lb.SearchHits = function(q) lb.Refresh(); return lbList:SearchHits(q) end
    lb.SearchApply = function(q) lbList:ShowFirstHit(q) end
    mine.SearchHits = function(q) mine.Refresh(); return mineList:SearchHits(q) end
    mine.SearchApply = function(q) mineList:ShowFirstHit(q) end
    boss.SearchHits = function(q) boss.Refresh(); return bossList:SearchHits(q) end
    boss.SearchApply = function(q) bossList:ShowFirstHit(q) end
    page.Search = function(text)
        page.query = text
        return UI.TabSearch(bar, tabs, text)
    end
    page.OnShow = function() tabs[bar.current].Refresh() end
end, { section = "raid", icon = "flag", module = "runs" })

ns.On("LG_RUNS", function() ns.Debounce("runs-page", 0.3, function() ns.Window.Refresh("runs") end) end)
