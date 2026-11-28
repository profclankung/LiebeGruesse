-- Achievements page (Personal): dungeon, open world and raid achievements with
-- progress bars, counters, tier badges and unlock dates, plus a guild overview
-- (who has which tier). Data and tiers: Modules/Badges.lua.
-- Own counters for achievements live in char.achStats (Achievements.Bump).
local _, ns = ...
local Achievements = ns.NewModule("achievements")
ns.Achievements = Achievements
local UI, Theme, L, Names = ns.UI, ns.Theme, ns.L, ns.Names
local Badges = ns.Badges

local state = { cat = "dungeon", filter = "all", scope = "char" }
Achievements.state = state

local function on() return ns.Database.Settings().modules.achievements ~= false end

-- own counters (first-try kills, deathless boss kills, personal bests …)
function Achievements.Bump(stat, n)
    local a = Badges.AchStats()
    a[stat] = (a[stat] or 0) + (n or 1)
    Badges.Invalidate()
    Badges.CheckSoon()
end

function Achievements.RunFinished(rec, pbBefore)
    if pbBefore and ns.Runs.Final(rec) < ns.Runs.Final(pbBefore) then Achievements.Bump("pb") end
    Badges.CheckSoon()
end

-- 1.0.90: ten-player dungeons in a raid group (Upper Blackrock Spire) were
-- counted as raid. There is no raid on the realm yet, so everything raid of
-- this character goes back to dungeon once and raid achievements start fresh.
local function isOnyxia(name) return type(name) == "string" and name:find("Onyxia", 1, true) ~= nil end
function Achievements.FixRaids(char)
    char = char or ns.Database.Char()
    if char.raidFix then return false end
    char.raidFix = 1
    local st = type(char.stats) == "table" and char.stats or {}
    for name, inst in pairs(type(st.instances) == "table" and st.instances or {}) do
        if type(inst) == "table" and inst.kind == "raid" and not isOnyxia(name) then inst.kind = "party" end
    end
    for _, b in pairs(type(st.bosses) == "table" and st.bosses or {}) do
        if type(b) == "table" and b.kind == "raid" and not isOnyxia(b.where) then b.kind = "party" end
    end
    local a = Badges.AchStats(char)
    a.firstTryDungeon = (a.firstTryDungeon or 0) + (a.firstTryRaid or 0)
    a.firstTryRaid, a.deathless = nil, nil
    char.lastRaid, char.jumps, char.chug = nil, nil, nil
    if type(char.achievements) == "table" then
        for _, def in ipairs(Badges.LIST) do
            if def.cat == "raid" then char.achievements[def.id] = nil end
        end
    end
    Badges.Invalidate()
    return true
end
ns.On("LG_READY", function() Achievements.FixRaids() end)

-- explorer: zones seen outside of instances (per character)
local function zone()
    if ns.Call(IsInInstance) == true then return end
    local z = ns.Call(GetRealZoneText)
    if type(z) ~= "string" or z == "" or ns.IsSecret(z) then return end
    local a = Badges.AchStats()
    a.zones = a.zones or {}
    if not a.zones[z] then
        a.zones[z] = true
        Badges.Invalidate()
        Badges.CheckSoon()
    end
end
ns.On("ZONE_CHANGED_NEW_AREA", function() ns.After(2, zone) end)
ns.On("PLAYER_ENTERING_WORLD", function() ns.After(4, zone) end)

-- rare hunter: a dead rare (elite) we loot, once per mob
local RARE = { rare = true, rareelite = true }
ns.On("LOOT_OPENED", function()
    if not ns.Call(UnitExists, "target") or ns.Call(UnitIsDead, "target") ~= true or ns.Call(UnitIsPlayer, "target") then return end
    local class = ns.Call(UnitClassification, "target")
    if not RARE[class] then return end
    local guid = ns.Call(UnitGUID, "target")
    if type(guid) ~= "string" then return end
    local a = Badges.AchStats()
    a.rares = a.rares or {}
    local n = 0
    for _ in pairs(a.rares) do n = n + 1 end
    if a.rares[guid] or n >= 500 then return end
    a.rares[guid] = true
    Badges.Invalidate()
    Badges.CheckSoon()
end)

---------------------------------------------------------------------------
-- Cards
---------------------------------------------------------------------------
local CARD_H, GAP, MIN_W = 96, 10, 290
local NEW_DAYS = 3

local function progressOf(def, tier, v)
    local top = #def.tiers
    if not v then return tier >= top and 1 or 0, nil end
    if tier >= top then return 1, def.tiers[top] end
    local prev = tier > 0 and def.tiers[tier] or 0
    local next = def.tiers[tier + 1]
    return math.max(0, math.min(1, (v - prev) / math.max(1, next - prev))), next
end

local function buildCard(parent)
    local c = UI.Panel(parent, "panel", "borderDim")
    c.tile = UI.Panel(c, "input", "borderDim")
    c.tile:SetSize(44, 44)
    c.tile:SetPoint("TOPLEFT", 12, -12)
    c.icon = UI.Icon(c.tile, "star", 22, "muted"); c.icon:SetPoint("CENTER")
    c.name = UI.Text(c, 13, "text", nil, nil, true); c.name:SetPoint("TOPLEFT", 68, -11); c.name:SetWordWrap(false)
    c.tier = UI.Text(c, 10, "bronze", nil, nil, true); c.tier:SetPoint("LEFT", c.name, "RIGHT", 6, 0)
    c.tag = UI.Text(c, 10, "accent", "RIGHT", nil, true); c.tag:SetPoint("TOPRIGHT", -10, -11)
    c.desc = UI.Text(c, 11, "muted"); c.desc:SetPoint("TOPLEFT", 68, -28); c.desc:SetWordWrap(false)
    c.track = UI.Panel(c, "input", "borderDim"); c.track:SetHeight(6); c.track:SetPoint("TOPLEFT", 68, -46)
    c.fill = UI.Fill(c.track, "accent", "ARTWORK"); c.fill:SetPoint("TOPLEFT", 1, -1); c.fill:SetPoint("BOTTOMLEFT", 1, 1)
    c.count = UI.Text(c, 11, "muted"); c.count:SetPoint("TOPLEFT", 68, -57); c.count:SetWordWrap(false)
    c.pips = {}
    for i = 1, Badges.MAX_TIER do
        local p = UI.Fill(c, "borderDim", "ARTWORK"); p:SetSize(7, 7)
        if p.SetRotation then p:SetRotation(math.rad(45)) end
        c.pips[i] = p
    end
    c.date = UI.Text(c, 11, "muted"); c.date:SetPoint("TOPLEFT", 68, -73); c.date:SetWordWrap(false)
    c:EnableMouse(true)
    c:SetScript("OnEnter", function(self)
        if not self.b then return end
        UI.Tooltip(self, Badges.Name(self.b.def), Badges.TipLines(self.b.def, self.b.tier, self.b.value))
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return c
end

local function fillCard(c, b, w)
    c.b = b
    local def, tier = b.def, b.tier
    local color = tier > 0 and Badges.TIER_COLORS[tier] or "muted"
    Theme.SetIcon(c.icon, def.icon)
    c.icon:SetVertexColor(Theme.Color(color))
    c.tile:SetBackdropBorderColor(Theme.Color(tier > 0 and color or "borderDim"))
    c:SetBackdropBorderColor(Theme.Color(tier > 0 and "bronzeDim" or "borderDim"))
    c.name:SetText(ns.Highlight(Badges.Name(def), state.query or ""))
    c.tier:SetText(tier > 0 and Theme.HexColor(color, ns.Upper(Badges.TierName(tier))) or "")
    local u = Badges.Unlocked(def.id)
    local last = u and u.t and u.t[tier]
    local new = last and last > 0 and ns.Now() - last < NEW_DAYS * 86400
    c.tag:SetText(new and L.ACH_TAG_NEW or (def.fun and Theme.HexColor("muted", L.ACH_TAG_FUN) or ""))
    c.desc:SetText(Badges.Desc(def))
    local inner = w - 68 - 12
    c.desc:SetWidth(inner)
    c.name:SetWidth(math.min(inner - 70, (c.name:GetStringWidth() or 100) + 4))
    local p, next = progressOf(def, tier, b.value)
    c.track:SetWidth(inner)
    c.fill:SetWidth(math.max(1, (inner - 2) * p))
    c.fill:SetShown(p > 0)
    local top = #def.tiers
    if b.value then
        local nextText = tier < top and L.ACH_NEXT:format(Theme.HexColor(Badges.TierColor(tier + 1), Badges.TierName(tier + 1))) or L.ACH_COMPLETE
        c.count:SetText(("%s / %s  %s"):format(Badges.ValueText(def, b.value), Badges.ValueText(def, next), Theme.HexColor("muted", nextText)))
    else
        c.count:SetText(tier >= top and L.ACH_COMPLETE or "")
    end
    c.count:SetWidth(inner - 11 * top - 6)
    -- one diamond per tier in its colour (dim while not reached)
    for i, pip in ipairs(c.pips) do
        pip:ClearAllPoints()
        pip:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12 - (top - i) * 11, -59)
        pip:SetColorTexture(Theme.Color(tier >= i and Badges.TIER_COLORS[i] or "borderDim"))
        pip:SetShown(i <= top)
    end
    if last then
        c.date:SetText(L.ACH_UNLOCKED:format(last > 0 and ns.Date(last) or L.ACH_EARLIER))
    else
        c.date:SetText(Theme.HexColor("muted", L.ACH_LOCKED))
    end
    c.date:SetWidth(inner)
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
UI.AddPage("achievements", L.PAGE_ACHIEVEMENTS, 72, function(content, page)
    local tabs = {}
    local holder = CreateFrame("Frame", nil, content)
    holder:SetPoint("TOPLEFT", 0, -38)
    holder:SetPoint("BOTTOMRIGHT")

    -- one view for the three categories
    local view = CreateFrame("Frame", nil, holder)
    view:SetAllPoints()
    local tiles = {}
    local TILE_H = 50
    for i, t in ipairs({ { "accent", L.ACH_UNLOCKED_N }, { "tier1", L.ACH_POINTS }, { "tier3", L.ACH_GOLD_PLUS }, { "tier8", L.ACH_BEST_TIER } }) do
        local tile = UI.Panel(view, "panel", "borderDim")
        tile:SetHeight(TILE_H)
        tile.mark = UI.Fill(tile, t[1], "ARTWORK"); tile.mark:SetSize(16, 16)
        if tile.mark.SetRotation then tile.mark:SetRotation(math.rad(45)) end
        tile.mark:SetPoint("LEFT", 16, 0)
        tile.value = UI.Text(tile, 20, "text", nil, nil, true); tile.value:SetPoint("TOPLEFT", 44, -7)
        tile.label = UI.Text(tile, 11, "muted"); tile.label:SetPoint("TOPLEFT", 44, -30); tile.label:SetText(t[2])
        tiles[i] = tile
    end
    local filters = UI.FilterChips(view, {
        { value = "all", text = L.ACH_FILTER_ALL, icon = "star" },
        { value = "got", text = L.ACH_FILTER_GOT, icon = "badge-check" },
        { value = "open", text = L.ACH_FILTER_OPEN, icon = "timer" },
    }, function() return state.filter end, function(v) state.filter = v; view.Refresh() end)
    local scopeSeg = UI.Segmented(view, 240, { { value = "char", text = L.STATS_THIS_CHAR }, { value = "account", text = L.STATS_ALL_CHARS } },
        function() return state.scope end, function(v) state.scope = v; view.Refresh() end)
    local scroll, body = UI.ScrollArea(view)
    local cards = {}
    local shown = {}
    local function layout()
        local W = view:GetWidth() or 900
        local tw = (W - 3 * 10) / 4
        for i, t in ipairs(tiles) do
            t:ClearAllPoints(); t:SetPoint("TOPLEFT", (i - 1) * (tw + 10), 0); t:SetWidth(tw)
        end
        filters:ClearAllPoints(); filters:SetPoint("TOPLEFT", 0, -(TILE_H + 12))
        scopeSeg:ClearAllPoints(); scopeSeg:SetPoint("TOPRIGHT", 0, -(TILE_H + 12))
        scopeSeg:SetShown(W > 520)
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", 0, -(TILE_H + 12 + 34))
        scroll:SetPoint("BOTTOMRIGHT")
        local w = (scroll:GetWidth() or W) - 8
        if w < 50 then w = W - 8 end
        local cols = math.max(1, math.floor((w + GAP) / (MIN_W + GAP)))
        local cw = (w - (cols - 1) * GAP) / cols
        for i, b in ipairs(shown) do
            local c = cards[i]
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", ((i - 1) % cols) * (cw + GAP), -math.floor((i - 1) / cols) * (CARD_H + GAP))
            c:SetSize(cw, CARD_H)
            fillCard(c, b, cw)
            c:Show()
        end
        for i = #shown + 1, #cards do cards[i]:Hide() end
        body:SetSize(w, math.max(1, math.ceil(#shown / cols) * (CARD_H + GAP)))
        if scroll.UpdateBar then scroll.UpdateBar() end
    end
    view:SetScript("OnSizeChanged", layout)
    function view.Rows(cat)
        local out = {}
        local o = Badges.Settings()
        for _, b in ipairs(Badges.Of(Names.Me(), state.scope)) do
            if b.def.cat == cat and (o.fun or not b.def.fun) then out[#out + 1] = b end
        end
        return out
    end
    function view.Refresh()
        filters:Refresh(); scopeSeg:Refresh()
        local all = view.Rows(state.cat)
        local got, points, maxPoints, goldPlus, best = 0, 0, 0, 0, 0
        for _, b in ipairs(all) do
            if b.tier > 0 then got = got + 1 end
            points, maxPoints = points + b.tier, maxPoints + #b.def.tiers
            if b.tier >= 3 then goldPlus = goldPlus + 1 end
            if b.tier > best then best = b.tier end
        end
        tiles[1].value:SetText(("%d / %d"):format(got, #all))
        tiles[2].value:SetText(("%d / %d"):format(points, maxPoints))
        tiles[3].value:SetText(tostring(goldPlus))
        tiles[4].value:SetText(best > 0 and Theme.HexColor(Badges.TierColor(best), Badges.TierName(best)) or Theme.HexColor("muted", "–"))
        tiles[4].mark:SetColorTexture(Theme.Color(best > 0 and Badges.TierColor(best) or "borderDim"))
        shown = {}
        local nGot, nOpen = 0, 0
        for _, b in ipairs(all) do
            local done = b.tier >= #b.def.tiers
            if b.tier > 0 then nGot = nGot + 1 end
            if not done then nOpen = nOpen + 1 end
            local keep = state.filter == "all" or (state.filter == "got" and b.tier > 0) or (state.filter == "open" and not done)
            if keep then shown[#shown + 1] = b end
        end
        filters:SetCount("all", #all); filters:SetCount("got", nGot); filters:SetCount("open", nOpen)
        -- unlocked first (best tier), then the closest to the next tier
        table.sort(shown, function(a, b)
            if (a.tier > 0) ~= (b.tier > 0) then return a.tier > 0 end
            local pa, pb = progressOf(a.def, a.tier, a.value), progressOf(b.def, b.tier, b.value)
            if a.tier ~= b.tier then return a.tier > b.tier end
            if pa ~= pb then return pa > pb end
            return Badges.Name(a.def) < Badges.Name(b.def)
        end)
        for i = 1, #shown do if not cards[i] then cards[i] = buildCard(body) end end
        layout()
    end
    function view.Count(q)
        local n = 0
        for _, b in ipairs(view.Rows(state.cat)) do
            if ns.SearchAny(Badges.Name(b.def) .. " " .. Badges.Desc(b.def), q) then n = n + 1 end
        end
        return n
    end
    -- one tab per category: they all show the same view
    for _, cat in ipairs(Badges.CATEGORIES) do
        local t = { cat = cat }
        function t:SetShown(on) if on then view:Show() end end
        function t.Refresh() state.cat = cat; view:Show(); view.Refresh() end
        function t.SearchHits(q)
            local n = 0
            for _, b in ipairs(view.Rows(cat)) do
                if ns.SearchAny(Badges.Name(b.def) .. " " .. Badges.Desc(b.def), q) then n = n + 1 end
            end
            return n
        end
        function t.SearchApply() view.Refresh() end
        tabs[cat] = t
    end

    -- guild overview: every achievement, who holds which tier
    local guild = Achievements.BuildGuild(holder)
    guild:SetAllPoints()
    tabs.guild = guild

    local settingsTab = UI.SettingsPane(holder, function(form)
        local o = Badges.Settings
        local s = form:Section(L.ACH_SET_SECTION)
        s:Toggle(L.ACH_SET_TOAST, function() return o().toast end, function(v) o().toast = v end, { tip = L.ACH_SET_TOAST_TIP })
        s:Toggle(L.ACH_SET_SOUND, function() return o().sound end, function(v) o().sound = v end)
        s:Toggle(L.ACH_SET_FUN, function() return o().fun end, function(v) o().fun = v; ns.Window.Refresh("achievements") end,
            { tip = L.ACH_SET_FUN_TIP })
        s:Toggle(L.ACH_SET_SHARE, function() return o().share end, function(v) o().share = v; if ns.Profile then ns.Profile.Update(true) end end,
            { tip = L.ACH_SET_SHARE_TIP })
        s:Buttons({ { L.ACH_SET_TEST, function() Badges.Test() end, width = 170, icon = "trophy" } })
    end)
    tabs.settings = settingsTab

    local bar = UI.SubTabs(content, {
        { key = "dungeon", title = L.ACH_CAT_DUNGEON }, { key = "world", title = L.ACH_CAT_WORLD },
        { key = "raid", title = L.ACH_CAT_RAID }, { key = "guild", title = L.ACH_TAB_GUILD },
        { key = "settings", title = L.SETTINGS_TAB, icon = "settings", iconOnly = true },
    }, function(key)
        local isCat = key == "dungeon" or key == "world" or key == "raid"
        view:SetShown(isCat)
        guild:SetShown(key == "guild")
        settingsTab:SetShown(key == "settings")
        tabs[key].Refresh()
    end)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -ns.Window.SearchReserve(), 0)
    bar:Select("dungeon")
    Achievements.bar = bar
    page.ShowSettings = function() bar:Select("settings") end
    settingsTab.form.reveal = page.ShowSettings
    page.searchHint = L.ACH_SEARCH
    guild.SearchHits = function(q) guild.Refresh(); return guild.list:SearchHits(q) end
    guild.SearchApply = function(q) guild.list:ShowFirstHit(q) end
    page.Search = function(text)
        page.query = text
        state.query = text
        return UI.TabSearch(bar, tabs, text)
    end
    page.OnShow = function()
        -- the counts on the tabs: unlocked / all
        tabs[bar.current].Refresh()
    end
end, { section = "me", icon = "trophy", module = "achievements" })

---------------------------------------------------------------------------
-- Guild overview, two views:
--   Members:      ranking by tier points, tier spread, the selected member's
--                 badges on the right
--   Achievements: every achievement with its holders and the highest tier
---------------------------------------------------------------------------
local DETAIL_W = 300

-- "1 Challenger · 2 Diamond · 4 Gold" (the three highest tiers someone holds)
local function spreadText(counts)
    local parts = {}
    for i = Badges.MAX_TIER, 1, -1 do
        if (counts[i] or 0) > 0 and #parts < 3 then
            parts[#parts + 1] = Theme.HexColor(Badges.TierColor(i), counts[i] .. " " .. Badges.TierName(i))
        end
    end
    return #parts > 0 and table.concat(parts, Theme.HexColor("muted", "  ·  ")) or Theme.HexColor("muted", "–")
end
Achievements.SpreadText = spreadText

local function memberName(key)
    local g = ns.Guild.Find(key)
    return ns.ColorName(g and g.name or Names.Display(key), g and g.class), g and g.name or Names.Display(key)
end

-- everybody the client knows (shared stats and profiles) with their tiers
function Achievements.GuildData(cat)
    local keys = {}
    for key in pairs(Badges.Stats()) do keys[key] = true end
    for key, m in pairs(ns.Database.Guild().members or {}) do if type(m) == "table" and m.ac then keys[key] = true end end
    keys[Names.Me()] = true
    local o = Badges.Settings()
    local members, byDef = {}, {}
    for key in pairs(keys) do
        if Names.Same(key, Names.Me()) or ns.Guild.IsMember(key) then
            local score, got, total, counts, tiers = 0, 0, 0, {}, {}
            for _, b in ipairs(Badges.Of(key)) do
                local def = b.def
                if (cat == "all" or def.cat == cat) and (o.fun or not def.fun) then
                    total = total + 1
                    if b.tier > 0 then
                        got, score = got + 1, score + b.tier
                        counts[b.tier] = (counts[b.tier] or 0) + 1
                        tiers[def.id] = b.tier
                        byDef[def.id] = byDef[def.id] or {}
                        table.insert(byDef[def.id], { key = key, tier = b.tier })
                    end
                end
            end
            if got > 0 or Names.Same(key, Names.Me()) then
                local display, plain = memberName(key)
                members[#members + 1] = { key = key, score = score, got = got, total = total, counts = counts,
                    display = display, plain = plain, spread = spreadText(counts) }
            end
        end
    end
    table.sort(members, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.got ~= b.got then return a.got > b.got end
        return a.plain < b.plain
    end)
    for i, m in ipairs(members) do m.rank = i end
    return members, byDef
end

function Achievements.BuildGuild(parent)
    local f = CreateFrame("Frame", nil, parent)
    local CAT = { dungeon = L.ACH_CAT_DUNGEON, world = L.ACH_CAT_WORLD, raid = L.ACH_CAT_RAID }
    local gs = { cat = "all", mode = "members" }
    f.state = gs
    local chips = UI.FilterChips(f, {
        { value = "all", text = L.ACH_FILTER_ALL, icon = "star" },
        { value = "dungeon", text = L.ACH_CAT_DUNGEON, icon = "castle" },
        { value = "world", text = L.ACH_CAT_WORLD, icon = "compass" },
        { value = "raid", text = L.ACH_CAT_RAID, icon = "crown" },
    }, function() return gs.cat end, function(v) gs.cat = v; f.Refresh() end)
    local modeSeg = UI.Segmented(f, 240, { { value = "members", text = L.ACH_BY_MEMBER }, { value = "achievements", text = L.ACH_BY_ACH } },
        function() return gs.mode end, function(v) gs.mode = v; f.Refresh() end)
    modeSeg:SetPoint("TOPRIGHT")
    chips:SetPoint("TOPLEFT")
    chips:SetPoint("TOPRIGHT", modeSeg, "TOPLEFT", -10, 0)

    -- members ranking
    local members
    members = UI.List(f, {
        sortKey = "score", sortDesc = true,
        columns = {
            { key = "rank", title = "#", width = 36, align = "CENTER", noHighlight = true,
              text = function(r) return Theme.HexColor(r.rank <= 3 and "accent" or "muted", tostring(r.rank)) end,
              sort = function(r) return -r.rank end },
            { key = "name", title = L.ACH_COL_MEMBER, width = 160, text = function(r) return r.display end, sort = function(r) return r.plain end },
            { key = "score", title = L.ACH_COL_POINTS, width = 70, align = "CENTER", defaultDesc = true, noHighlight = true,
              text = function(r) return tostring(r.score) end, sort = function(r) return r.score * 1000 + r.got end },
            { key = "got", title = L.ACH_UNLOCKED_N, width = 84, align = "CENTER", optional = 2, noHighlight = true,
              text = function(r) return Theme.HexColor("textDim", ("%d / %d"):format(r.got, r.total)) end, sort = function(r) return r.got end },
            { key = "tiers", title = L.ACH_COL_TIERS, flex = true, minWidth = 150, optional = 1, noHighlight = true,
              text = function(r) return r.spread end, sort = function(r) return r.score end },
        },
        onClick = function(r) gs.sel = r.key; members:Draw(); f.ShowMember() end,
        isSelected = function(r) return gs.sel ~= nil and r.key == gs.sel end,
        searchText = function(r) return r.plain end,
    })
    members:SetPoint("TOPLEFT", 0, -36)
    members:SetPoint("BOTTOMRIGHT", -(DETAIL_W + 10), 0)
    members:SetEmptyText(L.ACH_GUILD_EMPTY)

    -- the selected member's badges
    local detail = UI.Panel(f, "panel", "borderDim")
    detail:SetPoint("TOPRIGHT", 0, -36)
    detail:SetWidth(DETAIL_W)
    detail.right = UI.Text(detail, 10, "muted", "RIGHT")
    detail.right:SetPoint("TOPRIGHT", -12, -10)
    detail.title = UI.CardTitle(detail, "", detail.right)
    detail.sub = UI.Text(detail, 11, "muted")
    detail.sub:SetPoint("BOTTOMLEFT", 12, 10)
    detail.sub:SetWidth(DETAIL_W - 24)
    function f.ShowMember()
        local key = gs.sel or Names.Me()
        local display = memberName(key)
        detail.title:SetText(display)
        local cat = gs.cat ~= "all" and gs.cat or nil
        local h = Badges.FillCard(detail, key, DETAIL_W, cat)
        local row
        for _, r in ipairs(f.memberRows or {}) do if Names.Same(r.key, key) then row = r; break end end
        detail.right:SetText(row and L.ACH_POINTS_N:format(row.score) or "")
        detail.sub:SetText(row and row.spread or "")
        detail:SetHeight(h + 24)
    end

    -- every achievement with its holders
    local achList = UI.List(f, {
        sortKey = "best", sortDesc = true,
        columns = {
            { key = "name", title = L.BADGE_COL, width = 190,
              text = function(r) return Badges.Name(r.def) end,
              icon = function(r) return Theme.Icon(r.def.icon) end,
              sort = function(r) return Badges.Name(r.def) end },
            { key = "cat", title = L.ACH_COL_CAT, width = 90, optional = 2, noHighlight = true,
              text = function(r) return Theme.HexColor("muted", CAT[r.def.cat] or "") end, sort = function(r) return r.def.cat end },
            { key = "n", title = L.ACH_COL_HOLDERS, width = 70, align = "CENTER", noHighlight = true,
              text = function(r) return r.n > 0 and tostring(r.n) or Theme.HexColor("muted", "0") end, sort = function(r) return r.n end },
            { key = "best", title = L.ACH_COL_HIGHEST, flex = true, minWidth = 200, defaultDesc = true,
              text = function(r) return r.bestText end, sort = function(r) return r.top * 1000 + r.n end },
        },
        onEnter = function(frame, r)
            local lines = Badges.TipLines(r.def, 0, nil)
            lines[#lines + 1] = " "
            for i = #r.def.tiers, 1, -1 do
                local names = {}
                for _, h in ipairs(r.holders) do if h.tier == i then names[#names + 1] = memberName(h.key) end end
                if #names > 0 then
                    if #names > 8 then names = { table.concat(names, ", ", 1, 8) .. Theme.HexColor("muted", " +" .. (#names - 8)) } end
                    lines[#lines + 1] = Theme.HexColor(Badges.TierColor(i), Badges.TierName(i) .. ": ") .. table.concat(names, ", ")
                end
            end
            UI.Tooltip(frame, Badges.Name(r.def), lines)
        end,
        searchText = function(r) return r.hay end,
    })
    achList:SetPoint("TOPLEFT", 0, -36)
    achList:SetPoint("BOTTOMRIGHT")

    function f.Refresh()
        chips:Refresh(); modeSeg:Refresh()
        local rows, byDef = Achievements.GuildData(gs.cat)
        f.memberRows = rows
        local isMembers = gs.mode == "members"
        members:SetShown(isMembers); detail:SetShown(isMembers); achList:SetShown(not isMembers)
        f.list = isMembers and members or achList
        if isMembers then
            members:SetRows(rows)
            f.ShowMember()
        else
            local o = Badges.Settings()
            local list = {}
            for _, def in ipairs(Badges.LIST) do
                if (gs.cat == "all" or def.cat == gs.cat) and (o.fun or not def.fun) then
                    local holders = byDef[def.id] or {}
                    table.sort(holders, function(a, b)
                        if a.tier ~= b.tier then return a.tier > b.tier end
                        return Names.Display(a.key) < Names.Display(b.key)
                    end)
                    local top = holders[1] and holders[1].tier or 0
                    local bestText = Theme.HexColor("muted", L.ACH_NOBODY)
                    if top > 0 then
                        local names = {}
                        for _, h in ipairs(holders) do
                            if h.tier == top then
                                if #names == 3 then names[#names + 1] = Theme.HexColor("muted", "+"); break end
                                names[#names + 1] = (memberName(h.key))
                            end
                        end
                        bestText = Theme.HexColor(Badges.TierColor(top), Badges.TierName(top)) .. Theme.HexColor("muted", "  ·  ") .. table.concat(names, ", ")
                    end
                    local hay = Badges.Name(def) .. " " .. Badges.Desc(def)
                    for _, h in ipairs(holders) do hay = hay .. " " .. Names.Display(h.key) end
                    list[#list + 1] = { key = def.id, def = def, holders = holders, n = #holders, top = top, bestText = bestText, hay = hay }
                end
            end
            achList:SetRows(list)
        end
    end
    f.list = members
    return f
end

-- the profile carries the own achievements (only when shared)
function Achievements.Pack()
    if not on() or not Badges.Settings().share then return nil end
    return Badges.Pack()
end
