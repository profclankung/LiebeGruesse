-- "Help & commands" page: search, area tabs, quick start tiles, one grouped
-- command table (run / put into chat) and side cards with chat commands,
-- tips and support. Built from the registry in Core/Slash.lua (ns.Commands).
-- The "/lg test …" commands have their own page (Modules/TestSuite.lua).
local _, ns = ...
local UI, Theme, L = ns.UI, ns.Theme, ns.L

local Help = {}
ns.Help = Help
local state = { area = "all", query = "" }

-- area tabs → command groups
local AREAS = {
    { key = "all" }, { key = "general", groups = { general = true } },
    { key = "guild", groups = { roster = true, community = true } }, { key = "raid", groups = { lc = true, raid = true } },
    { key = "cd", groups = { cd = true } }, { key = "crafts", groups = { crafts = true } },
    { key = "partner", groups = { partner = true } }, { key = "chat", groups = { chat = true } },
}
local AREA_TITLE = { all = "HELP_AREA_ALL", general = "HELP_AREA_GENERAL", guild = "HELP_AREA_GUILD", raid = "HELP_AREA_RAID",
    cd = "HELP_AREA_CD", crafts = "HELP_AREA_CRAFTS", partner = "HELP_AREA_PARTNER", chat = "HELP_AREA_CHAT" }

local QUICK = {
    { icon = "users", title = "PAGE_ROSTER", sub = "HELP_Q_ROSTER", cmd = "roster", page = "roster" },
    { icon = "gem", title = "PAGE_COUNCIL", sub = "HELP_Q_LC", cmd = "lc", page = "council" },
    { icon = "timer", title = "PAGE_COOLDOWNS", sub = "HELP_Q_CD", cmd = "cd", page = "cooldowns" },
    { icon = "settings", title = "HELP_Q_SETTINGS_T", sub = "HELP_Q_SETTINGS", cmd = "config", page = "general" },
}

local ROW_H = 32

-- commands that run without extra input get a "run" button
local function runnable(c, group)
    if group.chat then return false end
    if group.runnable and c.run then return true end
    return not c.args or c.args:sub(1, 1) == "["
end
local function run(c, group)
    if group.runnable and c.run then ns.Safe(c.run, ""); return end
    if SlashCmdList and SlashCmdList.LIEBEGRUESSE then SlashCmdList.LIEBEGRUESSE(c.cmd) end
end
local function toChat(c, group)
    local text = ns.CommandText(c, group):gsub("%s*[<%[].*$", "")
    if ChatFrame_OpenChat then ChatFrame_OpenChat(text .. ((c.args and " ") or "")) end
end

-- a command as an accent "code chip"
local function chip(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetHeight(22)
    UI.Skin(f, "input", "borderDim")
    f.text = UI.Text(f, 12, "accent", "LEFT")
    f.text:SetPoint("LEFT", 8, 0)
    function f:Set(text, maxW, display)
        self.text:SetWidth(0)
        self.text:SetText(display or text)
        local tw = (self.text.GetUnboundedStringWidth and self.text:GetUnboundedStringWidth()) or self.text:GetStringWidth() or 40
        local w = math.min(maxW or 300, math.max(tw, #text * 6.4) + 18)
        self.text:SetWidth(w - 14)
        self:SetWidth(w)
    end
    return f
end

local function card(parent, title, right)
    local c = UI.Panel(parent, "panel", "borderDim")
    c.right = UI.Text(c, 10, "muted", "RIGHT")
    c.right:SetPoint("TOPRIGHT", -12, -11)
    c.right:SetText(right or "")
    c.title = UI.CardTitle(c, title, c.right)
    return c
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
UI.AddPage("help", L.PAGE_HELP, 97, function(content, page)
    -- toolbar: search · area tabs
    -- the search sits in the page header
    page.searchHint = L.HELP_SEARCH
    local tabs = {}
    for _, a in ipairs(AREAS) do tabs[#tabs + 1] = { key = a.key, title = L[AREA_TITLE[a.key]] } end
    local bar = UI.SubTabs(content, tabs, function(key) state.area = key; if Help.Fill then Help.Fill() end end)
    if bar.SetClipsChildren then bar:SetClipsChildren(true) end
    local scroll, body = UI.ScrollArea(content)
    -- area tabs next to the page search when they fit, otherwise in their own row below it
    local barRow
    local function placeTop()
        local tabsW = 0
        for _, b in ipairs(bar.buttons) do tabsW = tabsW + (b:GetWidth() or 80) + 6 end
        local fits = tabsW <= (content:GetWidth() or 900) - ns.Window.SearchReserve()
        if fits == barRow then return end
        barRow = fits
        bar:ClearAllPoints()
        scroll:ClearAllPoints()
        if fits then
            bar:SetPoint("TOPLEFT", 0, 0)
            bar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -ns.Window.SearchReserve(), 0)
            scroll:SetPoint("TOPLEFT", 0, -40)
        else
            bar:SetPoint("TOPLEFT", 0, -34)
            bar:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -34)
            scroll:SetPoint("TOPLEFT", 0, -74)
        end
        scroll:SetPoint("BOTTOMRIGHT", -8, 0)
    end
    placeTop()

    -- quick start
    local quickHead = UI.Text(body, 11, "bronze", "LEFT", nil, true)
    quickHead:SetPoint("TOPLEFT", 0, 0)
    quickHead:SetText(ns.Upper(L.HELP_QUICK))
    page.Search = function(text)
        state.query = (text or ""):lower()
        Help.Fill()
        -- nothing in this area: look in all areas
        if state.query ~= "" and Help.hits == 0 and state.area ~= "all" then bar:Select("all") end
        return Help.hits
    end
    local tiles = {}
    for i, q in ipairs(QUICK) do
        local t = CreateFrame("Button", nil, body, "BackdropTemplate")
        UI.Skin(t, "panel", "borderDim")
        UI.Corners(t)
        t:SetHeight(100)
        t.icon = UI.Icon(t, q.icon, 18, "bronze")
        t.icon:SetPoint("TOPLEFT", 12, -12)
        t.title = UI.Text(t, 16, "text")
        t.title:SetPoint("LEFT", t.icon, "RIGHT", 8, 0)
        t.title:SetText(L[q.title])
        t.sub = UI.Text(t, 12, "textDim")
        t.sub:SetPoint("TOPLEFT", 12, -38)
        t.sub:SetWordWrap(true)
        t.sub:SetJustifyV("TOP")
        t.sub:SetText(L[q.sub])
        t.chip = chip(t)
        t.chip:SetPoint("BOTTOMLEFT", 12, 10)
        t.chip:Set("/lg " .. q.cmd)
        t.open = UI.Text(t, 12, "accent", "RIGHT")
        t.open:SetPoint("BOTTOMRIGHT", -12, 14)
        t.open:SetText(L.HELP_OPEN .. " ›")
        t:SetScript("OnClick", function() ns.Window.Show(q.page) end)
        t:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(Theme.Color("accent")) end)
        t:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(Theme.Color("borderDim")) end)
        tiles[i] = t
    end

    -- command table
    local tableBox = UI.Panel(body, "bg", "borderDim")
    local heads, rows = {}, {}
    local function headLine(i)
        local h = heads[i]
        if h then return h end
        h = CreateFrame("Frame", nil, tableBox)
        h:SetHeight(30)
        h.diamond = UI.Fill(h, "bronze", "ARTWORK"); h.diamond:SetSize(5, 5); h.diamond:SetPoint("LEFT", 12, -3)
        if h.diamond.SetRotation then h.diamond:SetRotation(math.rad(45)) end
        h.text = UI.Text(h, 12, "text", "LEFT", nil, true)
        h.text:SetPoint("LEFT", 24, -3)
        h.count = UI.Text(h, 11, "muted", "LEFT")
        h.count:SetPoint("LEFT", h.text, "RIGHT", 8, 0)
        h.rule = UI.Fill(h, "borderDim", "ARTWORK"); h.rule:SetHeight(1)
        h.rule:SetPoint("LEFT", h.count, "RIGHT", 10, 0); h.rule:SetPoint("RIGHT", h, "RIGHT", -12, -3)
        h.note = UI.Text(h, 11, "warn", "RIGHT")
        h.note:SetPoint("RIGHT", -12, -3)
        heads[i] = h
        return h
    end
    local function rowLine(i)
        local r = rows[i]
        if r then return r end
        r = CreateFrame("Frame", nil, tableBox)
        r:SetHeight(ROW_H)
        r.bg = UI.Fill(r, "row", "BACKGROUND"); r.bg:SetAllPoints()
        r.hl = UI.Fill(r, "hover", "ARTWORK"); r.hl:SetAllPoints(); r.hl:Hide()
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self) self.hl:Show(); if self.tip then UI.Tooltip(self, self.tip[1], self.tip[2]) end end)
        r:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
        r.chip = chip(r)
        r.chip:SetPoint("LEFT", 12, 0)
        r.desc = UI.Text(r, 13, "textDim", "LEFT")
        r.chat = UI.IconButton(r, "message-circle", 22, function(self) toChat(self.c, self.g) end)
        r.chat:SetPoint("RIGHT", -10, 0)
        r.chat.tip = L.HELP_CLICK
        r.run = UI.IconButton(r, "chevron-right", 22, function(self) run(self.c, self.g) end)
        r.run:SetPoint("RIGHT", r.chat, "LEFT", -4, 0)
        r.run.tip = L.HELP_CLICK_RUN
        rows[i] = r
        return r
    end

    -- side cards
    local chatCard = card(body, L.HELP_CHAT_TITLE, L.HELP_CHAT_SUB)
    chatCard.items = {}
    for _, g in ipairs(ns.Commands) do
        if g.chat then
            for _, c in ipairs(g.commands) do
                local it = { chip = chip(chatCard), text = UI.Text(chatCard, 12, "textDim") }
                it.chip:Set(ns.CommandText(c, g), 280)
                it.text:SetWordWrap(true)
                it.text:SetJustifyV("TOP")
                it.text:SetText(c.desc or "")
                chatCard.items[#chatCard.items + 1] = it
            end
        end
    end
    local tipsCard = card(body, L.HELP_TIPS)
    tipsCard.lines = {}
    for i = 1, 4 do
        local d = UI.Fill(tipsCard, "bronze", "ARTWORK"); d:SetSize(4, 4)
        if d.SetRotation then d:SetRotation(math.rad(45)) end
        local t = UI.Text(tipsCard, 12, "textDim"); t:SetWordWrap(true); t:SetJustifyV("TOP")
        t:SetText(L["HELP_TIP" .. i])
        tipsCard.lines[i] = { dot = d, text = t }
    end
    local supportCard = card(body, L.HELP_SUPPORT)
    supportCard.text = UI.Text(supportCard, 12, "textDim"); supportCard.text:SetWordWrap(true); supportCard.text:SetJustifyV("TOP")
    supportCard.text:SetText(L.HELP_SUPPORT_TEXT)
    supportCard.test = UI.Button(supportCard, L.PAGE_TESTS, 130, 26, function() ns.Window.Show("tests") end, "badge-check")
    supportCard.credits = UI.Button(supportCard, L.PAGE_CREDITS, 110, 26, function() ns.Window.Show("credits") end, "star")

    local function placeText(fs, x, y, w)
        fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", x, y); fs:SetWidth(w)
        return (fs:GetStringHeight() or 14)
    end

    function Help.Fill()
        placeTop()
        local W = math.max(400, (scroll:GetWidth() or 900) - 4)
        local stacked = W < 860
        local sideW = stacked and W or 320
        local mainW = stacked and W or (W - sideW - 16)

        -- quick tiles: 4 in a row, 2 when narrow
        local perRow = mainW >= 620 and 4 or 2
        local tw = math.floor((mainW - (perRow - 1) * 10) / perRow)
        local th = 0
        for _, t in ipairs(tiles) do
            t.sub:SetWidth(tw - 24)
            th = math.max(th, 38 + (t.sub:GetStringHeight() or 14) + 42)
        end
        for i, t in ipairs(tiles) do
            local col, rowN = (i - 1) % perRow, math.floor((i - 1) / perRow)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", body, "TOPLEFT", col * (tw + 10), -20 - rowN * (th + 10))
            t:SetSize(tw, th)
        end
        local y = 20 + math.ceil(#tiles / perRow) * (th + 10) + 6

        -- table
        tableBox:ClearAllPoints()
        tableBox:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        tableBox:SetWidth(mainW)
        local area
        for _, a in ipairs(AREAS) do if a.key == state.area then area = a end end
        local q = state.query
        Help.hits, Help.firstY = 0, nil
        local ty, nh, nr = 4, 0, 0
        for _, g in ipairs(ns.Commands) do
            -- the tests are on their own page (test suite)
            local showGroup = g.key ~= "test" and (not area or not area.groups or area.groups[g.key])
            if showGroup then
                local list = {}
                for _, c in ipairs(g.commands) do list[#list + 1] = c end
                if #list > 0 then
                    nh = nh + 1
                    local h = headLine(nh)
                    h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -ty); h:SetWidth(mainW)
                    h.text:SetText(ns.Upper(g.title))
                    h.count:SetText(tostring(#list))
                    local off = g.module and ns.Database.Settings().modules[g.module] == false
                    h.note:SetText(off and L.HELP_MODULE_OFF or "")
                    h.rule:SetShown(not off)
                    h:Show()
                    ty = ty + 30
                    for i, c in ipairs(list) do
                        nr = nr + 1
                        local r = rowLine(nr)
                        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 1, -ty); r:SetWidth(mainW - 2)
                        r.bg:SetVertexColor(Theme.Color(i % 2 == 1 and "row" or "rowAlt"))
                        local cmdW = math.min(260, math.floor(mainW * 0.34))
                        r.chip:Set(ns.CommandText(c, g), cmdW, ns.Highlight(ns.CommandText(c, g), q, "text"))
                        r.desc:ClearAllPoints()
                        r.desc:SetPoint("LEFT", 12 + cmdW + 14, 0)
                        r.desc:SetWidth(math.max(60, mainW - cmdW - 12 - 14 - 70))
                        r.desc:SetText(ns.Highlight(c.desc or "", q))
                        -- search hit: accent bar and tint (nothing is hidden)
                        local hit = q ~= "" and ns.SearchAny(ns.CommandText(c, g) .. " " .. (c.desc or ""), q)
                        if not r.hitBg then
                            r.hitBg = UI.Fill(r, "accent", "BORDER"); r.hitBg:SetAllPoints(); r.hitBg:SetAlpha(0.12)
                            r.hitBar = UI.Fill(r, "accent", "OVERLAY"); r.hitBar:SetPoint("TOPLEFT"); r.hitBar:SetPoint("BOTTOMLEFT"); r.hitBar:SetWidth(3)
                        end
                        r.hitBg:SetShown(hit and true or false); r.hitBar:SetShown(hit and true or false)
                        if hit then Help.hits = Help.hits + 1; Help.firstY = Help.firstY or (y + ty) end
                        local canRun = runnable(c, g)
                        r.run:SetShown(canRun)
                        r.run.c, r.run.g, r.chat.c, r.chat.g = c, g, c, g
                        r.chat:SetShown(not g.runnable)
                        r.tip = { ns.CommandText(c, g), { c.desc or "", " ", g.runnable and L.HELP_CLICK_RUN or L.HELP_CLICK } }
                        r:Show()
                        ty = ty + ROW_H
                    end
                    ty = ty + 4
                end
            end
        end
        for i = nh + 1, #heads do heads[i]:Hide() end
        for i = nr + 1, #rows do rows[i]:Hide() end
        if not tableBox.empty then
            tableBox.empty = UI.Empty(tableBox, 360)
            tableBox.empty:SetPoint("TOP", 0, -24)
        end
        tableBox.empty:SetShown(nr == 0)
        if nr == 0 then
            if q ~= "" then UI.EmptySearch(tableBox.empty, q) else tableBox.empty:Set("book-open", L.HELP_NOTHING) end
        end
        tableBox:SetHeight(math.max(nr == 0 and 170 or 60, ty + 6))
        local mainBottom = y + math.max(nr == 0 and 170 or 60, ty + 6)

        -- side cards
        local sx = stacked and 0 or (mainW + 16)
        local sy = stacked and (mainBottom + 12) or 0
        local inner = sideW - 24
        local function place(c, h)
            c:ClearAllPoints(); c:SetPoint("TOPLEFT", body, "TOPLEFT", sx, -sy); c:SetWidth(sideW); c:SetHeight(h)
            sy = sy + h + 10
        end
        local cy = 38
        for _, it in ipairs(chatCard.items) do
            it.chip:ClearAllPoints(); it.chip:SetPoint("TOPLEFT", 12, -cy)
            cy = cy + 26 + placeText(it.text, 12, -(cy + 26), inner) + 10
        end
        place(chatCard, cy + 4)
        local ty2 = 38
        for _, l in ipairs(tipsCard.lines) do
            l.dot:ClearAllPoints(); l.dot:SetPoint("TOPLEFT", 14, -(ty2 + 6))
            ty2 = ty2 + placeText(l.text, 26, -ty2, inner - 14) + 8
        end
        place(tipsCard, ty2 + 4)
        local sh = 38 + placeText(supportCard.text, 12, -38, inner) + 10
        supportCard.test:ClearAllPoints(); supportCard.test:SetPoint("TOPLEFT", 12, -sh)
        supportCard.credits:ClearAllPoints(); supportCard.credits:SetPoint("LEFT", supportCard.test, "RIGHT", 6, 0)
        place(supportCard, sh + 38)

        body:SetHeight(math.max(mainBottom, sy) + 12)
        -- jump to the first hit
        if Help.firstY then
            local max = math.max(0, body:GetHeight() - (scroll:GetHeight() or 0))
            scroll:SetVerticalScroll(math.max(0, math.min(max, Help.firstY - 80)))
        elseif q == "" then
            scroll:SetVerticalScroll(0)
        end
        scroll.UpdateBar()
    end

    bar:Select("all")
    scroll:HookScript("OnSizeChanged", function() ns.Debounce("help-layout", 0.05, Help.Fill) end)
    page.OnShow = function() Help.Fill() end
end, { section = "settings", icon = "book-open" })
