-- Quick assignment window (/lg assign, grid button on the blessing bar):
-- every paladin × every class at a glance. Click a cell for the blessing
-- (or a single blessing for one player), mouse wheel cycles, right click
-- removes. Footer: free assignment, settings, announce, smart assign, clear,
-- refresh. Nothing runs while it is closed.
local _, ns = ...
local UI, Theme, L, Names = ns.UI, ns.Theme, ns.L, ns.Names
local B = ns.Blessings
local A = {}
ns.BlessAssign = A

local NAME_W, COL_W, ROW_H, HEAD_H = 176, 62, 48, 92
local frame
local cells, rowsUI, heads = {}, {}, {}

local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function blessIcon(b, size)
    return ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(B.Icon(b) or 135995, size or 16, size or 16)
end

-- blessing menu of one cell: the blessings this paladin knows, none, a single for a player
local function cellMenu(anchor, p, class)
    local items = {}
    for _, b in ipairs(B.LIST) do
        local can = p.can and p.can[b.key]
        local note = (p.addon and can == 0) and Theme.HexColor("muted", "  " .. L.BLESS_NOT_KNOWN) or ""
        items[#items + 1] = { value = b.key, text = blessIcon(b.key) .. "  " .. B.Name(b.key) .. note }
    end
    items[#items + 1] = { value = "none", text = Theme.HexColor("muted", L.BLESS_NONE) }
    if B.classUnits[class] and #B.classUnits[class] > 0 then
        items[#items + 1] = { value = "single", text = Theme.HexColor("accent", "+ " .. L.BLESS_SINGLE_FOR_PLAYER) }
    end
    UI.OpenMenu(anchor, items, function(v)
        if v == "single" then
            ns.BlessingsBar.AddSingle(anchor, anchor, p, class)
        else
            B.Set(p, class, v ~= "none" and v or nil)
        end
    end, 210, p.set and p.set[class] or "none")
end

local function cell(r, i)
    local c = r.cells[i]
    if c then return c end
    c = CreateFrame("Button", nil, r)
    c:SetSize(COL_W - 4, ROW_H - 6)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c.bg = UI.Fill(c, "input", "BACKGROUND"); c.bg:SetAllPoints()
    c.hl = UI.Fill(c, "hover", "HIGHLIGHT"); c.hl:SetAllPoints()
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(26, 26)
    c.icon:SetPoint("TOP", 0, -3)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.count = UI.Text(c, 10, "text", "CENTER")
    c.count:SetPoint("BOTTOM", 0, 2)
    c.extra = UI.Text(c, 10, "accent", "RIGHT")
    c.extra:SetPoint("TOPRIGHT", -2, -2)
    c.dash = UI.Text(c, 12, "borderDim", "CENTER")
    c.dash:SetPoint("CENTER")
    c.dash:SetText("—")
    c:SetScript("OnClick", function(self, button)
        if not self.p then return end
        if not B.CanEdit(self.p) then ns.Print(L.BLESS_CANT_EDIT); return end
        if button == "RightButton" then B.Set(self.p, self.class, nil) else cellMenu(self, self.p, self.class) end
    end)
    c:EnableMouseWheel(true)
    c:SetScript("OnMouseWheel", function(self, delta)
        if not self.p then return end
        if not B.CanEdit(self.p) then ns.Print(L.BLESS_CANT_EDIT); return end
        B.Cycle(self.p, self.class, delta)
        A.Draw()
        if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
    end)
    c:SetScript("OnEnter", function(self)
        if not self.p then return end
        local lines = {}
        local b = self.p.set and self.p.set[self.class]
        if b then
            local have, total = B.Wanted(self.class, b)
            lines[#lines + 1] = L.BLESS_TIP_STATUS:format(have, total)
        end
        for _, s in ipairs(B.Singles(self.p)) do
            if s.member.class == self.class then
                lines[#lines + 1] = L.BLESS_TIP_INSTEAD:format(s.member.name, B.Name(s.blessing))
            end
        end
        lines[#lines + 1] = " "
        lines[#lines + 1] = B.CanEdit(self.p) and L.BLESS_QUICK_CELL_TIP or L.BLESS_CANT_EDIT
        UI.Tooltip(self, (b and B.Name(b) or L.BLESS_NONE) .. " · " .. ns.ClassName(self.class), lines)
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.cells[i] = c
    return c
end

local function paladinRow(i)
    local r = rowsUI[i]
    if r then return r end
    r = CreateFrame("Frame", nil, frame)
    r:SetHeight(ROW_H)
    r.bg = UI.Fill(r, (i % 2 == 0) and "rowAlt" or "row", "BACKGROUND"); r.bg:SetAllPoints()
    r.name = UI.Text(r, 13, "text")
    r.name:SetPoint("TOPLEFT", 10, -7)
    r.name:SetWidth(NAME_W - 16)
    r.name:SetWordWrap(false)
    r.sub = UI.Text(r, 10, "muted")
    r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.skills = UI.Text(r, 10, "text")
    r.skills:SetPoint("BOTTOMLEFT", 10, 6)
    r.cells = {}
    rowsUI[i] = r
    return r
end

-- known blessings as small icons ("?" for paladins without data)
local function skills(p)
    if not p.addon then return Theme.HexColor("muted", L.BLESS_SKILLS_UNKNOWN) end
    local out = {}
    for _, b in ipairs(B.LIST) do
        local can = p.can and p.can[b.key]
        if can == nil or can > 0 then out[#out + 1] = blessIcon(b.key, 14) end
    end
    return #out > 0 and table.concat(out, " ") or Theme.HexColor("muted", "–")
end

local function create()
    frame = UI.Panel(UIParent, "panel", "border")
    frame:SetSize(NAME_W + #B.CLASSES * COL_W + 24, 300)
    UI.Float(frame)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    UI.RememberPosition(frame, "blessAssign", { "CENTER", "CENTER", 0, 60 })
    _G.LiebeGruesseBlessAssign = frame
    tinsert(UISpecialFrames, "LiebeGruesseBlessAssign")

    frame.kicker = UI.Text(frame, 10, "accent")
    frame.kicker:SetPoint("TOPLEFT", 14, -12)
    frame.kicker:SetText(L.BLESS_QUICK:upper())
    frame.title = UI.Text(frame, 20, "text", nil, nil, true)
    frame.title:SetPoint("TOPLEFT", frame.kicker, "BOTTOMLEFT", 0, -4)
    frame.info = UI.Text(frame, 11, "muted")
    frame.info:SetPoint("LEFT", frame.title, "RIGHT", 12, -2)
    frame.close = UI.IconButton(frame, "x", 22, function() frame:Hide() end)
    frame.close:SetPoint("TOPRIGHT", -10, -10)
    frame.rule = UI.Fill(frame, "bronzeDim", "ARTWORK")
    frame.rule:SetHeight(1)
    frame.rule:SetPoint("TOPLEFT", 12, -50); frame.rule:SetPoint("TOPRIGHT", -12, -50)
    frame.palHead = UI.Text(frame, 10, "muted")
    frame.palHead:SetPoint("TOPLEFT", 22, -70)
    frame.palHead:SetText(L.BLESS_PALADIN:upper())
    -- class heads: icon and number of players
    for i, class in ipairs(B.CLASSES) do
        local h = CreateFrame("Frame", nil, frame)
        h:SetSize(COL_W - 4, 36)
        h:SetPoint("TOPLEFT", 12 + NAME_W + (i - 1) * COL_W, -54)
        h.icon = h:CreateTexture(nil, "ARTWORK")
        h.icon:SetSize(24, 24)
        h.icon:SetPoint("TOP", 0, -2)
        ns.SetClassIcon(h.icon, class)
        h.count = UI.Text(h, 10, "muted", "CENTER")
        h.count:SetPoint("TOP", h.icon, "BOTTOM", 0, -1)
        h:EnableMouse(true)
        h:SetScript("OnEnter", function(self)
            local names = {}
            for _, unit in ipairs(B.classUnits[class] or {}) do
                local m = B.members[B.unitKey[unit] or ""]
                if m then
                    local kind = B.UnitType(unit, m.key, class)
                    names[#names + 1] = m.name .. Theme.HexColor("muted", "  " .. (L["BLESS_TYPE_" .. kind:upper()] or kind))
                end
            end
            UI.Tooltip(self, ns.ClassName(class), #names > 0 and names or { L.BLESS_ROW_ABSENT })
        end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        heads[i] = h
    end

    -- footer
    local free = UI.Check(frame, L.BLESS_FREE, function() return B.Settings().freeAssign end,
        function(v) B.Settings().freeAssign = v; B.Share(B.Me()) end, L.BLESS_FREE_TIP)
    free:SetPoint("BOTTOMLEFT", 14, 16)
    frame.free = free
    local refresh = UI.Button(frame, L.BLESS_REFRESH, 96, 26, function()
        B.Rebuild(); B.Request(); B.Scan(); A.Draw()
    end, "rotate-ccw")
    refresh:SetPoint("BOTTOMRIGHT", -12, 12)
    refresh.tip = { L.BLESS_REFRESH_TIP }
    local clear = UI.Button(frame, L.BLESS_CLEAR, 86, 26, function()
        local n = 0
        for _, p in ipairs(B.PaladinList()) do if B.CanEdit(p) and B.Clear(p) then n = n + 1 end end
        if n == 0 then ns.Print(L.BLESS_CANT_EDIT) end
    end, "x")
    clear:SetPoint("RIGHT", refresh, "LEFT", -6, 0)
    clear.tip = { L.BLESS_CLEAR_TIP }
    local smart = UI.Button(frame, L.BLESS_SMART, 120, 26, function()
        if B.Suggest() then ns.Print(L.BLESS_SUGGESTED) else ns.Print(L.BLESS_CANT_EDIT) end
    end, "sparkles")
    smart:SetPoint("RIGHT", clear, "LEFT", -6, 0)
    smart.tip = { L.BLESS_SMART_TIP }
    local report = UI.Button(frame, L.BLESS_ANNOUNCE, 100, 26, function() B.Announce() end, "megaphone")
    report:SetPoint("RIGHT", smart, "LEFT", -6, 0)
    local settings = UI.Button(frame, L.SETTINGS_TAB, 96, 26, function()
        ns.Window.ShowSettings("blessings")
    end, "settings")
    settings:SetPoint("RIGHT", report, "LEFT", -6, 0)
    frame.empty = UI.Text(frame, 12, "muted", "CENTER")
    frame.empty:SetPoint("TOP", 0, -HEAD_H - 20)
    frame:HookScript("OnShow", function() A.Draw() end)
    frame:Hide()
end

function A.Draw()
    if not frame or not frame:IsShown() then return end
    if not B.test then B.Rebuild() end
    local zone = ns.Call(GetInstanceInfo)
    frame.title:SetText(B.test and (L.TEST_TAG .. " " .. L.BLESS_RAID)
        or (IsInGroup() and zone and zone ~= "") and zone or (IsInRaid() and L.BLESS_RAID or IsInGroup() and L.BLESS_GROUP or L.BLESS_SOLO_TITLE))
    local sum = B.Summary()
    frame.info:SetText(L.BLESS_INFO_SHORT:format(sum.synced, sum.paladins, sum.missing))
    frame.free.toggle:Refresh()
    local solo = not IsInGroup() and not B.test
    for i, class in ipairs(B.CLASSES) do
        local n = #(B.classUnits[class] or {})
        heads[i].count:SetText(n > 0 and tostring(n) or "–")
        heads[i]:SetAlpha((n > 0 or solo) and 1 or 0.4)
    end
    local pals = B.PaladinList()
    local y = HEAD_H
    for i, p in ipairs(pals) do
        local r = paladinRow(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 12, -y)
        r:SetPoint("TOPRIGHT", -12, -y)
        r.name:SetText(ns.ColorName(p.name or p.key, "PALADIN"))
        r.sub:SetText(p.me and Theme.HexColor("accent", L.BLESS_YOU) or (p.addon == "lg" and L.BLESS_ADDON)
            or (p.addon == "pp" and L.BLESS_PP_GUEST) or Theme.HexColor("muted", L.BLESS_NO_ADDON))
        r.skills:SetText(skills(p))
        for c, class in ipairs(B.CLASSES) do
            local cl = cell(r, c)
            cl:ClearAllPoints()
            cl:SetPoint("LEFT", r, "LEFT", NAME_W + (c - 1) * COL_W, 0)
            cl.p, cl.class = p, class
            local b = p.set and p.set[class]
            local present = (B.classUnits[class] and #B.classUnits[class] > 0) or solo
            if b then
                cl.icon:SetTexture(B.Icon(b)); cl.icon:Show(); cl.dash:Hide()
                local have, total = B.Wanted(class, b)
                cl.count:SetText(total > 0 and Theme.HexColor(have >= total and "good" or (have == 0 and "bad" or "warn"), ("%d/%d"):format(have, total)) or "")
                cl.count:Show()
            else
                cl.icon:Hide(); cl.count:Hide(); cl.dash:Show()
            end
            local extra = 0
            for _, s in ipairs(B.Singles(p)) do if s.member.class == class then extra = extra + 1 end end
            cl.extra:SetText(extra > 0 and ("+" .. extra) or "")
            cl:SetAlpha(present and 1 or 0.45)
            cl:Show()
        end
        r:Show()
        y = y + ROW_H + 2
    end
    for i = #pals + 1, #rowsUI do rowsUI[i]:Hide() end
    frame.empty:SetShown(#pals == 0)
    frame.empty:SetText(IsInGroup() and L.BLESS_NO_PALADINS or L.BLESS_NO_GROUP)
    if #pals == 0 then y = y + 50 end
    frame:SetHeight(y + 56)
end

function A.Show()
    if not frame then create() end
    frame:Show()
    A.Draw()
end
function A.Toggle()
    if frame and frame:IsShown() then frame:Hide() else A.Show() end
end
function A.Shown() return frame ~= nil and frame:IsShown() end

ns.On("LG_BLESSINGS", function()
    if frame and frame:IsShown() then ns.Debounce("bless-assign-draw", 0.2, A.Draw) end
end)
