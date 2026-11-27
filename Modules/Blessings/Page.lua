-- Blessings page: assignment grid (paladin × class) with live buff status,
-- missing players, suggest / whisper / announce; settings of bar and sync in the tab "Settings".
local _, ns = ...
local UI, Theme, L, Names = ns.UI, ns.Theme, ns.L, ns.Names
local B = ns.Blessings
local P = ns.BlessPlayers

local COL_W, ROW_H, NAME_W = 96, 48, 170
local CELL_TOP = 44   -- single lines below icon and count

local function className(class)
    return ns.ClassName(class)
end

local function blessingMenu(anchor, p, class)
    local items = {}
    for _, b in ipairs(B.LIST) do
        local note = B.MenuNote(p, class, b.key)
        items[#items + 1] = { value = b.key, text = ("|T%s:16:16:0:0:64:64:5:59:5:59|t  %s%s"):format(B.Icon(b.key), B.Name(b.key), note) }
    end
    items[#items + 1] = { value = "none", text = Theme.HexColor("muted", L.BLESS_NONE) }
    UI.OpenMenu(anchor, items, function(v) B.Set(p, class, v ~= "none" and v or nil) end, 190, p.set and p.set[class] or "none")
end

UI.AddPage("blessings", L.PAGE_BLESSINGS, 33, function(root, page)
    -- tabs: assignments and the settings of bar and sync
    local content, tabs = UI.PageWithSettings(root, page, L.BLESS_ASSIGNMENTS, function(form)
        local function o() return B.Settings() end
        local function barUpdate() ns.AfterCombat("bless-bar", ns.BlessingsBar.Update) end
        local bar = form:Section(L.BLESS_BAR)
        bar:Toggle(L.BLESS_SHOW_BAR, function() return o().bar end, function(v) o().bar = v; barUpdate() end, { tip = L.BLESS_SHOW_BAR_TIP })
        bar:Toggle(L.BLESS_RAID_ONLY, function() return o().raidOnly end, function(v) o().raidOnly = v; barUpdate() end)
        bar:Toggle(L.BLESS_SOLO, function() return o().solo end, function(v) o().solo = v; barUpdate() end, { tip = L.BLESS_SOLO_TIP })
        bar:Toggle(L.BLESS_LIVE, function() return o().live ~= false end, function(v) o().live = v; barUpdate() end, { tip = L.BLESS_LIVE_TIP })
        bar:Toggle(L.BLESS_AUTO_NEW, function() return o().autoNew ~= false end, function(v) o().autoNew = v end, { tip = L.BLESS_AUTO_NEW_TIP })
        local look = form:Section(L.BLESS_LOOK)
        look:Toggle(L.BLESS_COMPACT, function() return o().compact == true end, function(v) o().compact = v; barUpdate() end, { tip = L.BLESS_COMPACT_TIP })
        look:Toggle(L.BLESS_OPT_PLAYERS, function() return o().players ~= false end, function(v) o().players = v; barUpdate() end, { tip = L.BLESS_OPT_PLAYERS_TIP })
        look:Segment(L.BLESS_OPT_SIDE, { { value = "auto", text = L.BLESS_SIDE_AUTO }, { value = "left", text = L.BLESS_SIDE_LEFT }, { value = "right", text = L.BLESS_SIDE_RIGHT } },
            function() return o().side or "auto" end, function(v) o().side = v; barUpdate() end, { width = 210, tip = L.BLESS_OPT_SIDE_TIP })
        look:Toggle(L.BLESS_OPT_TIMES, function() return o().times ~= false end, function(v) o().times = v; barUpdate() end, { tip = L.BLESS_OPT_TIMES_TIP })
        look:Toggle(L.BLESS_OPT_COUNTS, function() return o().counts ~= false end, function(v) o().counts = v; barUpdate() end)
        look:Slider(L.BLESS_OPT_SCALE, 0.6, 1.6, 0.05, function() return ns.BlessingsBar.Scale() end,
            function(v) ns.BlessingsBar.SetScale(v) end, { fmt = function(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end })
        local selfB = form:Section(L.BLESS_SELF_SECTION)
        local function choices(list) return function() return ns.BlessingsBar.SelfChoices(list) end end
        selfB:Toggle(L.BLESS_SELF_AURA, function() return o().aura == true end, function(v) o().aura = v; barUpdate() end, { tip = L.BLESS_SELF_TIP })
        selfB:Dropdown(L.BLESS_SELF_AURA_PICK, choices(ns.BlessingsBar.AURAS), function() return o().auraSpell or ns.BlessingsBar.SelfChoice("aura") end,
            function(v) o().auraSpell = v; barUpdate() end, { show = function() return o().aura == true end })
        selfB:Toggle(L.BLESS_SELF_SEAL, function() return o().seal == true end, function(v) o().seal = v; barUpdate() end, { tip = L.BLESS_SELF_TIP })
        selfB:Dropdown(L.BLESS_SELF_SEAL_PICK, choices(ns.BlessingsBar.SEALS), function() return o().sealSpell or ns.BlessingsBar.SelfChoice("seal") end,
            function(v) o().sealSpell = v; barUpdate() end, { show = function() return o().seal == true end })
        selfB:Toggle(L.BLESS_SELF_FURY, function() return o().fury == true end, function(v) o().fury = v; barUpdate() end, { tip = L.BLESS_SELF_FURY_TIP_OPT })
        selfB:Toggle(L.BLESS_SELF_OATH_OPT, function() return o().oath ~= false end, function(v) o().oath = v; barUpdate() end, { tip = L.BLESS_SELF_OATH_OPT_TIP })
        local sync = form:Section(L.BLESS_SYNC)
        sync:Toggle(L.BLESS_WHISPER_GUESTS, function() return o().whisperGuests ~= false end, function(v) o().whisperGuests = v end, { tip = L.BLESS_WHISPER_GUESTS_TIP })
        sync:Toggle(L.BLESS_FREE, function() return o().freeAssign end, function(v) o().freeAssign = v; B.Share(B.Me()) end, { tip = L.BLESS_FREE_TIP })
        -- PallyPower: guests without this addon (read) and sending to them (sync)
        sync:Toggle(L.BLESS_PP_READ, function() return o().ppRead end, function(v) o().ppRead = v; if v then B.Request() end end, { tip = L.BLESS_PP_READ_TIP })
        sync:Toggle(L.BLESS_PP_SYNC, function() return o().ppSync end, function(v) o().ppSync = v; if v then B.Share(B.Me()) end end, { tip = L.BLESS_PP_SYNC_TIP })
        local msgs = form:Section(L.MSG_SECTION, { wide = true })
        ns.Messages.Rows(msgs, { "blessWhisper" })
    end)
    -- head: kicker, title, three counters
    local kicker = UI.Text(content, 10, "accent")
    kicker:SetPoint("TOPLEFT", 2, -2)
    kicker:SetText(L.BLESS_ASSIGNMENTS:upper())
    local title = UI.Text(content, 24, "text")
    title:SetPoint("TOPLEFT", kicker, "BOTTOMLEFT", 0, -6)
    local counters = {}
    for i, key in ipairs({ "duplicates", "missing", "paladins" }) do
        local c = CreateFrame("Frame", nil, content)
        c:SetSize(96, 46)
        -- the top right corner belongs to the page search
        if i == 1 then c:SetPoint("TOPRIGHT", 0, 0) else c:SetPoint("RIGHT", counters[i - 1], "LEFT", -8, 0) end
        c.value = UI.Text(c, 20, "text", "CENTER")
        c.value:SetPoint("TOP", 0, -2)
        c.label = UI.Text(c, 10, "muted", "CENTER")
        c.label:SetPoint("TOP", c.value, "BOTTOM", 0, -4)
        c.label:SetText(L["BLESS_COUNT_" .. key:upper()]:upper())
        counters[i] = c
        counters[key] = c
    end

    -- toolbar
    local suggest = UI.Button(content, L.BLESS_SMART, 130, 26, function()
        if B.Suggest() then ns.Print(L.BLESS_SUGGESTED) else ns.Print(L.BLESS_CANT_EDIT) end
    end, "sparkles")
    suggest:SetPoint("TOPLEFT", 0, -62)
    suggest.tip = { L.BLESS_SMART_TIP }
    local single = UI.Button(content, L.BLESS_SINGLE_ADD_BTN, 120, 26, function(self)
        if not B.Me() then ns.Print(L.BLESS_SINGLE_NOT_PALADIN); return end
        ns.BlessingsBar.AddSingle(self)
    end, "users")
    single:SetPoint("LEFT", suggest, "RIGHT", 8, 0)
    single.tipTitle = L.BLESS_SINGLE_ADD_TITLE
    single.tip = { L.BLESS_SINGLE_ADD_TIP }
    local clear = UI.Button(content, L.BLESS_CLEAR_MINE, 110, 26, function() local me = B.Me(); if me then B.Clear(me) end end, "x")
    clear:SetPoint("LEFT", single, "RIGHT", 8, 0)
    local announce = UI.Button(content, L.BLESS_ANNOUNCE, 110, 26, function() B.Announce() end, "megaphone")
    announce:SetPoint("TOPRIGHT", 0, -62)
    local whisper = UI.Button(content, L.BLESS_WHISPER_BTN, 110, 26, function() B.WhisperAll() end, "message-circle")
    whisper:SetPoint("RIGHT", announce, "LEFT", -8, 0)
    local quick = UI.Button(content, L.BLESS_QUICK_SHORT, 110, 26, function() ns.BlessAssign.Toggle() end, "layout-grid")
    quick:SetPoint("RIGHT", whisper, "LEFT", -8, 0)
    quick.tipTitle, quick.tip = L.BLESS_QUICK, { L.BLESS_QUICK_TIP }
    local info = UI.Text(content, 11, "muted")
    info:SetPoint("LEFT", clear, "RIGHT", 12, 0)
    info:SetPoint("RIGHT", quick, "LEFT", -12, 0)
    info:SetWordWrap(false)

    local scroll, body = UI.ScrollArea(content)
    scroll:SetPoint("TOPLEFT", 0, -100)
    scroll:SetPoint("BOTTOMRIGHT", -6, 0)

    -- grid pieces are created on demand and reused
    local headCells, rowsUI, missUI = {}, {}, {}
    local playerUI = {}   -- [column] = player buttons under the class name
    local plHead = UI.Text(body, 10, "accent")
    plHead:SetText(L.BLESS_PLAYERS_HEAD:upper())
    local plHint = UI.Text(body, 10, "muted")
    plHint:SetWordWrap(true)
    plHint:SetJustifyH("LEFT")
    plHint:SetWidth(NAME_W - 16)
    plHint:SetText(L.BLESS_PLAYERS_HINT)
    local gridHead = UI.Text(body, 10, "muted")
    gridHead:SetText(L.BLESS_PALADIN:upper())
    local gridLine = UI.Divider(body)
    local legend = UI.Text(body, 11, "muted")
    legend:SetWordWrap(true)
    legend:SetJustifyH("LEFT")
    local singleHead = UI.Text(body, 10, "accent")
    singleHead:SetText(L.BLESS_SINGLES_TITLE:upper())
    local singleLine = UI.Divider(body)
    local singleNote = UI.Text(body, 11, "muted")
    local singleUI = {}
    local missHead = UI.Text(body, 10, "accent")
    missHead:SetText(L.BLESS_MISSING:upper())
    local missLine = UI.Divider(body)
    local empty = UI.Empty(body, 420)

    local function cell(row, i)
        local c = row.cells[i]
        if c then return c end
        c = CreateFrame("Button", nil, row)
        c:SetSize(COL_W - 4, ROW_H - 6)
        c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        c.hl = UI.Fill(c, "hover", "HIGHLIGHT"); c.hl:SetAllPoints()
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(24, 24)
        c.icon:SetPoint("TOPLEFT", 4, -8)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.count = UI.Text(c, 12, "text")
        c.count:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 5, 1)
        c.left = UI.Text(c, 10, "muted")
        c.left:SetPoint("BOTTOMLEFT", c.icon, "BOTTOMRIGHT", 5, -1)
        c.dash = UI.Text(c, 12, "borderDim", "CENTER")
        c.dash:SetPoint("TOP", 0, -14)
        c.dash:SetText("—")
        c:SetScript("OnClick", function(self, button)
            if not self.p then return end
            if not B.CanEdit(self.p) then ns.Print(L.BLESS_CANT_EDIT); return end
            if button == "RightButton" then B.Set(self.p, self.class, nil) else blessingMenu(self, self.p, self.class) end
        end)
        c:EnableMouseWheel(true)
        c:SetScript("OnMouseWheel", function(self, delta)
            if not self.p then return end
            if not B.CanEdit(self.p) then ns.Print(L.BLESS_CANT_EDIT); return end
            B.WheelClass(self.p, self.class, delta)
            if B.PageDraw then B.PageDraw() else ns.Window.Refresh("blessings") end
            P.Retip()
        end)
        c:SetScript("OnEnter", function(self)
            if not self.p then return end
            local lines = {}
            local b = self.p.set and self.p.set[self.class]
            if b then
                local have, total = B.Wanted(self.class, b)
                lines[#lines + 1] = L.BLESS_TIP_STATUS:format(have, total)
            end
            for _, s in ipairs(P.SinglesIn(self.p, self.class)) do
                lines[#lines + 1] = P.IconText(s.blessing, 14) .. " " .. L.BLESS_TIP_INSTEAD:format(s.member.name, B.Name(s.blessing))
            end
            -- (no blank line: short tooltips)
            lines[#lines + 1] = B.CanEdit(self.p) and L.BLESS_CELL_TIP or L.BLESS_CANT_EDIT
            -- above the cell: below it unfold his players of this class
            P.hover = self
            P.Tip(self, (b and B.Name(b) or L.BLESS_NONE) .. " · " .. className(self.class), lines, "ANCHOR_TOP")
            P.ShowFly(self)
        end)
        c:SetScript("OnLeave", P.Unhover)
        row.cells[i] = c
        return c
    end

    local function paladinRow(i)
        local r = rowsUI[i]
        if r then return r end
        r = CreateFrame("Frame", nil, body)
        r:SetHeight(ROW_H)
        r.bg = UI.Fill(r, (i % 2 == 0) and "rowAlt" or "row", "BACKGROUND"); r.bg:SetAllPoints()
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(28, 28)
        r.icon:SetPoint("TOPLEFT", 6, -9)
        r.name = UI.Text(r, 13, "text")
        r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
        r.name:SetWidth(NAME_W - 46)
        r.sub = UI.Text(r, 10, "muted")
        r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 1)
        r.cells = {}
        rowsUI[i] = r
        return r
    end

    -- one single blessing: paladin, player (spec icon), blessing, state, set by hand / smart
    local function singleRow(i)
        local r = singleUI[i]
        if r then return r end
        r = CreateFrame("Button", nil, body)
        r:SetHeight(24)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.bg = UI.Fill(r, (i % 2 == 0) and "rowAlt" or "row", "BACKGROUND"); r.bg:SetAllPoints()
        r.hl = UI.Fill(r, "hover", "HIGHLIGHT"); r.hl:SetAllPoints()
        r.pal = UI.Text(r, 12, "text")
        r.pal:SetPoint("LEFT", 8, 0)
        r.pal:SetWidth(NAME_W - 16)
        r.pal:SetWordWrap(false)
        r.spec = r:CreateTexture(nil, "ARTWORK")
        r.spec:SetSize(18, 18)
        r.spec:SetPoint("LEFT", NAME_W, 0)
        r.who = UI.Text(r, 12, "text")
        r.who:SetPoint("LEFT", r.spec, "RIGHT", 6, 0)
        r.who:SetWidth(170)
        r.who:SetWordWrap(false)
        r.bless = UI.Text(r, 12, "text")
        r.bless:SetPoint("LEFT", r.who, "RIGHT", 8, 0)
        r.bless:SetWidth(150)
        r.bless:SetWordWrap(false)
        r.state = UI.Text(r, 12, "text")
        r.state:SetPoint("LEFT", r.bless, "RIGHT", 8, 0)
        r.state:SetWidth(80)
        r.src = UI.Text(r, 11, "muted")
        r.src:SetPoint("LEFT", r.state, "RIGHT", 8, 0)
        r.src:SetPoint("RIGHT", -8, 0)
        r.src:SetWordWrap(false)
        r:SetScript("OnClick", function(self, button)
            if not self.p then return end
            if not B.CanEdit(self.p) then ns.Print(L.BLESS_CANT_EDIT); return end
            if button == "RightButton" then B.SetSingle(self.p, self.key, nil)
            else ns.BlessingsBar.SingleMenu(self, self.key, self.p) end
        end)
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", function(self, delta)
            if not self.p then return end
            if not B.CanEdit(self.p) then ns.Print(L.BLESS_CANT_EDIT); return end
            B.CycleSingle(self.p, self.key, delta)
            ns.Window.Refresh("blessings")
        end)
        r:SetScript("OnEnter", function(self)
            if not self.p then return end
            local m = B.members[self.key]
            local lines = {}
            if m then
                local kind, source = B.UnitType(m.unit, m.key, m.class)
                lines[#lines + 1] = L.BLESS_TIP_PLAYS:format(L["BLESS_TYPE_" .. kind:upper()] or kind, L["BLESS_SRC_" .. tostring(source):upper()] or "")
                local classB = self.p.set and self.p.set[m.class]
                if classB and classB ~= self.blessing then lines[#lines + 1] = L.BLESS_TIP_REPLACES:format(B.Name(classB)) end
            end
            lines[#lines + 1] = self.pinned and L.BLESS_TIP_PINNED or L.BLESS_TIP_SMART
            -- (no blank line: short tooltips)
            lines[#lines + 1] = B.CanEdit(self.p) and L.BLESS_CELL_TIP or L.BLESS_CANT_EDIT
            UI.Tooltip(self, (m and m.name or self.key) .. " · " .. (B.Name(self.blessing) or ""), lines)
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        singleUI[i] = r
        return r
    end

    local function draw()
        B.Rebuild()
        counters[1]:ClearAllPoints()
        counters[1]:SetPoint("TOPRIGHT", 0, 0)
        local classes = {}
        -- solo: every class, so you can plan your own blessings before a group
        local solo = not IsInGroup() and not B.test
        for _, class in ipairs(B.CLASSES) do if solo or B.classUnits[class] then classes[#classes + 1] = class end end
        if #classes == 0 then classes = B.CLASSES end
        local pals = B.PaladinList()
        -- page search: a paladin's name narrows the rows, a class name the columns
        -- page search: matching paladins and classes are marked (nothing is hidden)
        local q = page.query or ""
        page.hits = 0
        if q ~= "" then
            for _, p in ipairs(pals) do if ns.SearchAny(ns.Names.Display(p.name or p.key), q) then page.hits = page.hits + 1 end end
            for _, c in ipairs(classes) do if ns.SearchAny(className(c), q) then page.hits = page.hits + 1 end end
        end
        local W = math.max(400, (scroll:GetWidth() or 800) - 8)
        local colW = math.max(72, math.min(COL_W + 24, math.floor((W - NAME_W) / math.max(1, #classes))))

        -- title + counters
        local zone = ns.Call(GetInstanceInfo)
        title:SetText(B.test and (L.TEST_TAG .. " " .. L.BLESS_RAID)
            or (IsInGroup() and zone and zone ~= "") and zone or (IsInRaid() and L.BLESS_RAID or IsInGroup() and L.BLESS_GROUP or L.BLESS_SOLO_TITLE))
        local sum = B.Summary()
        counters.paladins.value:SetText(("%d/%d"):format(sum.synced, sum.paladins))
        counters.missing.value:SetText(tostring(sum.missing))
        counters.missing.value:SetTextColor(Theme.Color(sum.missing > 0 and "accent" or "good"))
        counters.duplicates.value:SetText(tostring(sum.duplicates))
        counters.duplicates.value:SetTextColor(Theme.Color(sum.duplicates > 0 and "bad" or "text"))
        local pp = 0
        for _, p in ipairs(pals) do if p.addon == "pp" then pp = pp + 1 end end
        info:SetText(L.BLESS_INFO:format(sum.synced, sum.paladins, pp))
        local lead = not IsInGroup() or ns.IsGroupLead("player")
        suggest:SetEnabled(#pals > 0 and (lead or B.Me() ~= nil))
        clear:SetEnabled(B.Me() ~= nil)

        if #pals == 0 then
            for _, r in ipairs(rowsUI) do r:Hide() end
            for _, h in ipairs(headCells) do h:Hide() end
            for _, col in pairs(playerUI) do for _, b in ipairs(col) do b:Hide() end end
            plHead:Hide(); plHint:Hide()
            for _, m in ipairs(missUI) do m:Hide() end
            gridHead:Hide(); gridLine:Hide(); legend:Hide(); missHead:Hide(); missLine:Hide()
            empty:ClearAllPoints()
            empty:SetPoint("TOP", body, "TOP", 0, -40)
            empty:SetTextWidth(math.min(420, W - 40))
            empty:Set("sparkles", IsInGroup() and L.BLESS_NO_PALADINS or L.BLESS_NO_GROUP)
            empty:Show()
            body:SetHeight(200)
            scroll.UpdateBar()
            return
        end
        empty:Hide()
        gridHead:Show(); gridLine:Show(); legend:Show()

        -- header: class names in class colour
        gridHead:ClearAllPoints()
        gridHead:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -4)
        for i, class in ipairs(classes) do
            local h = headCells[i]
            if not h then h = UI.Text(body, 10, "text", "LEFT"); headCells[i] = h end
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", body, "TOPLEFT", NAME_W + (i - 1) * colW + 4, -4)
            h:SetWidth(colW - 4)
            local r, g, b = ns.ClassColor(class)
            h:SetText(ns.Highlight(ns.Hex(r, g, b, className(class):upper()), q))
            h:Show()
        end
        for i = #classes + 1, #headCells do headCells[i]:Hide() end
        gridLine:ClearAllPoints()
        gridLine:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -20)
        gridLine:SetWidth(NAME_W + #classes * colW)

        local y = 24
        -- players under every class name (wheel: your single, click: pick, right click: none)
        local most = 0
        for i, class in ipairs(classes) do
            local list = P.ClassPlayers(class)
            playerUI[i] = playerUI[i] or {}
            for j, key in ipairs(list) do
                local b = playerUI[i][j]
                if not b then b = P.Button(body); playerUI[i][j] = b end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", body, "TOPLEFT", NAME_W + (i - 1) * colW, -(y + (j - 1) * P.LINE_H))
                b:SetWidth(colW - 4)
                b:Set(key, q)
            end
            for j = #list + 1, #playerUI[i] do playerUI[i][j]:Hide(); playerUI[i][j].key = nil end
            most = math.max(most, #list)
        end
        for i = #classes + 1, #playerUI do for _, b in ipairs(playerUI[i]) do b:Hide(); b.key = nil end end
        plHead:SetShown(most > 0); plHint:SetShown(most > 0)
        if most > 0 then
            plHead:ClearAllPoints(); plHead:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -(y + 1))
            plHint:ClearAllPoints(); plHint:SetPoint("TOPLEFT", plHead, "BOTTOMLEFT", 0, -3)
            y = y + math.max(most * P.LINE_H, 44) + 8
        end
        for i, p in ipairs(pals) do
            local r = paladinRow(i)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
            r:SetWidth(NAME_W + #classes * colW)
            local lines = 0
            for _, class in ipairs(classes) do lines = math.max(lines, #P.SinglesIn(p, class)) end
            local h = math.max(ROW_H, CELL_TOP + lines * P.LINE_H + 4)
            r:SetHeight(h)
            ns.SetClassIcon(r.icon, "PALADIN")
            r.name:SetText(ns.Highlight(ns.ColorName(p.name or p.key, "PALADIN"), q))
            r.sub:SetText(p.me and Theme.HexColor("accent", L.BLESS_YOU) or (p.addon == "lg" and L.BLESS_ADDON)
                or (p.addon == "pp" and L.BLESS_PP_GUEST) or Theme.HexColor("muted", L.BLESS_NO_ADDON))
            for c, class in ipairs(classes) do
                local cl = cell(r, c)
                cl:ClearAllPoints()
                cl:SetPoint("TOPLEFT", r, "TOPLEFT", NAME_W + (c - 1) * colW, -3)
                cl:SetWidth(colW - 4)
                cl:SetHeight(h - 6)
                cl.p, cl.class = p, class
                local b = p.set and p.set[class]
                local st = B.status[class]
                if b then
                    cl.icon:SetTexture(B.Icon(b)); cl.icon:Show(); cl.dash:Hide()
                    local have, total = B.Wanted(class, b)
                    if total > 0 then
                        cl.count:SetText(Theme.HexColor(have >= total and "good" or "bad", ("%d/%d"):format(have, total)))
                    else
                        cl.count:SetText(Theme.HexColor("muted", "—"))
                    end
                    local left = st and st.left[b]
                    cl.left:SetText(left and left ~= math.huge and ("%dm"):format(math.floor(left / 60)) or "")
                    cl.count:Show(); cl.left:Show()
                else
                    cl.icon:Hide(); cl.count:Hide(); cl.left:Hide(); cl.dash:Show()
                end
                P.CellLines(cl, p, class, CELL_TOP, q)
                cl:Show()
            end
            for c = #classes + 1, #r.cells do r.cells[c]:Hide() end
            r:Show()
            y = y + h + 2
        end
        for i = #pals + 1, #rowsUI do rowsUI[i]:Hide() end

        -- legend
        local parts = {}
        for _, b in ipairs(B.LIST) do parts[#parts + 1] = ("|T%s:14:14:0:0:64:64:5:59:5:59|t %s"):format(B.Icon(b.key), B.Name(b.key)) end
        legend:ClearAllPoints()
        legend:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -(y + 8))
        legend:SetWidth(W - 8)
        legend:SetText(table.concat(parts, "     ") .. Theme.HexColor("muted", "     " .. L.BLESS_LEGEND_HINT))
        y = y + 34 + math.max(0, math.ceil(((legend:GetStringHeight() or 14) - 16) / 14)) * 14

        -- single blessings of every paladin (players in the group)
        local all = {}
        for _, p in ipairs(pals) do
            for _, sg in ipairs(B.Singles(p)) do sg.p = p; all[#all + 1] = sg end
        end
        local showS = IsInGroup() or B.test
        singleHead:SetShown(showS); singleLine:SetShown(showS); singleNote:SetShown(showS)
        if showS then
            local done = 0
            for _, sg in ipairs(all) do if B.SingleState(sg.key, sg.blessing) then done = done + 1 end end
            singleHead:ClearAllPoints()
            singleHead:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -(y + 6))
            singleHead:SetText(L.BLESS_SINGLES_TITLE:upper() .. (#all > 0 and ("   " .. Theme.HexColor(done >= #all and "good" or "bad", ("%d/%d"):format(done, #all))) or ""))
            singleLine:ClearAllPoints()
            singleLine:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(y + 22))
            singleLine:SetWidth(W)
            y = y + 30
            singleNote:ClearAllPoints()
            singleNote:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
            singleNote:SetWidth(W - 8)
            singleNote:SetWordWrap(true)
            singleNote:SetJustifyH("LEFT")
            singleNote:SetText(#all == 0 and L.BLESS_SINGLES_EMPTY or L.BLESS_SINGLES_HINT)
            y = y + 20
        end
        for i, sg in ipairs(showS and all or {}) do
            local r = singleRow(i)
            r.p, r.key, r.blessing, r.pinned = sg.p, sg.key, sg.blessing, sg.pinned
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
            r:SetWidth(W)
            r.pal:SetText(ns.Highlight(ns.ColorName(sg.p.name or sg.p.key, "PALADIN"), q))
            local m = sg.member
            if not ns.SetSpecIcon(r.spec, m.class, ns.SpecPoints(ns.Database.Member(m.key))) then ns.SetClassIcon(r.spec, m.class) end
            r.who:SetText(ns.Highlight(ns.ColorName(m.name, m.class), q))
            r.bless:SetText(("|T%s:16:16:0:0:64:64:5:59:5:59|t  %s"):format(B.Icon(sg.blessing), B.Name(sg.blessing)))
            local has, left = B.SingleState(sg.key, sg.blessing)
            r.state:SetText(has and Theme.HexColor("good", left and left ~= math.huge and ("%dm"):format(math.floor(left / 60)) or L.BLESS_SINGLE_HAS)
                or Theme.HexColor("bad", L.BLESS_SINGLE_MISSING))
            r.src:SetText(sg.pinned and L.BLESS_SRC_PINNED or L.BLESS_SRC_SMART)
            r:Show()
            y = y + 26
        end
        for i = (showS and #all or 0) + 1, #singleUI do singleUI[i]:Hide() end
        if showS then y = y + 6 end

        -- missing players, four per line
        missHead:SetShown(#B.missing > 0)
        missLine:SetShown(#B.missing > 0)
        if #B.missing > 0 then
            missHead:ClearAllPoints()
            missHead:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -(y + 6))
            missLine:ClearAllPoints()
            missLine:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(y + 22))
            missLine:SetWidth(W)
            y = y + 30
        end
        local perLine = math.max(1, math.floor(W / 200))
        local mw = math.floor(W / perLine)
        for i, m in ipairs(B.missing) do
            local t = missUI[i]
            if not t then t = UI.Text(body, 12, "text"); missUI[i] = t end
            local icons = {}
            for _, b in ipairs(m.list) do icons[#icons + 1] = ("|T%s:14:14:0:0:64:64:5:59:5:59|t"):format(B.Icon(b)) end
            t:SetText(table.concat(icons, "") .. "  " .. ns.ColorName(m.name, m.class))
            t:ClearAllPoints()
            local col, line = (i - 1) % perLine, math.floor((i - 1) / perLine)
            t:SetPoint("TOPLEFT", body, "TOPLEFT", 4 + col * mw, -(y + line * 22))
            t:SetWidth(mw - 8)
            t:Show()
        end
        for i = #B.missing + 1, #missUI do missUI[i]:Hide() end
        y = y + math.ceil(#B.missing / perLine) * 22 + 10
        body:SetHeight(y)
        scroll.UpdateBar()
        P.UpdateFly()
        P.Retip()
    end

    page.searchHint = L.BLESS_SEARCH
    page.Search = function(text) page.query = text; draw(); return page.hits end
    page.OnShow = function()
        draw()
        if not B.test and (B.IsPaladin() or IsInGroup()) and GetTime() - (B.lastScan or -99) > 3 then B.Scan() end
    end
    B.PageDraw = draw
    content:HookScript("OnSizeChanged", function() if content:IsVisible() then ns.Debounce("bless-page", 0.05, draw) end end)
    tabs.Finish()
end, { section = "raid", icon = "sparkles", module = "blessings" })

ns.On("LG_BLESSINGS", function()
    if ns.Window.IsShown("blessings") and B.PageDraw then ns.Debounce("bless-page-draw", 0.2, B.PageDraw) end
end)
