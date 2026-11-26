-- Players of a class and their single blessings, shared by the quick window and
-- the blessings page (the way paladins know it from the assignment grid):
--   player list under every class head: mouse wheel = your single blessing for
--   him (back to the class blessing is part of the cycle), click = picker with
--   every paladin and his blessings as icons (one click sets it), right click
--   removes his single blessings.
--   lines in a paladin's cell: "icon Name" for every single blessing that
--   paladin gives in this class (instead of his class blessing) – the same
--   wheel / click / right click.
--   hovering a paladin's cell unfolds every player of that class below it:
--   mouse wheel on a name = THAT paladin's single blessing for him.
--   Tooltips sit beside the list (never over the icons) and follow every change.
local _, ns = ...
local UI, Theme, L, Names = ns.UI, ns.Theme, ns.L, ns.Names
local B = ns.Blessings
local P = {}
ns.BlessPlayers = P

P.LINE_H = 20
P.FONT, P.ICON = 12, 16
P.buttons, P.lines = {}, {}   -- every player button / cell line made so far (reused, never many)

local function icon(b, size)
    return ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(B.Icon(b) or 135995, size or 12, size or 12)
end
P.IconText = icon
local function first(name) return (Names.Display(name or ""):match("^(%S+)")) or name or "?" end
P.First = first
-- full names everywhere (two "Salty"s in one raid must stay apart)
local function full(name) return Names.Display(name or "") or name or "?" end
P.Full = full

-- tooltips beside the owner, not at the cursor: the cursor tooltip covered
-- the blessing icons it explains. P.hover = owner, redrawn after each change.
local function tipAt(owner, anchor)
    ns.TipOwner(owner, anchor or "ANCHOR_RIGHT", true)
end
P.TipAt = tipAt
function P.Tip(owner, title, lines, anchor)
    tipAt(owner, anchor)
    local tr, tg, tb = Theme.Color("text")
    GameTooltip:SetText(title or "", tr, tg, tb)
    local r, g, b = Theme.Color("textDim")
    for _, line in ipairs(lines or {}) do GameTooltip:AddLine(line, r, g, b, true) end
    GameTooltip:Show()
end
function P.Hover(self) P.hover = self end
function P.Unhover(self) if P.hover == self then P.hover = nil end; GameTooltip:Hide() end
-- the tooltip of whatever is under the mouse again (after a wheel / click)
function P.Retip()
    local h = P.hover
    if h and h:IsShown() and h:IsVisible() and h:GetScript("OnEnter") then h:GetScript("OnEnter")(h) end
end

-- players of a class in group order: { key, ... }
function P.ClassPlayers(class)
    local out = {}
    for _, unit in ipairs(B.classUnits[class] or {}) do
        local key = B.unitKey[unit]
        if key and B.members[key] then out[#out + 1] = key end
    end
    return out
end

-- singles of paladin p in one class: { { key, blessing, member, pinned } }
function P.SinglesIn(p, class)
    local out = {}
    for _, s in ipairs(B.Singles(p)) do if s.member.class == class then out[#out + 1] = s end end
    return out
end

local function refresh()
    if ns.BlessAssign and ns.BlessAssign.Shown() then ns.BlessAssign.Draw() end
    if ns.Window.IsShown("blessings") and B.PageDraw then B.PageDraw() end
    if P.picker and P.picker:IsShown() then P.picker.Draw() end
    P.UpdateFly()
    P.Retip()
end
P.Refresh = refresh

-- mouse wheel on a player: your own single blessing for him
function P.Cycle(key, delta, p)
    p = p or B.Me()
    if not p then ns.Print(L.BLESS_PICK_NOT_PALADIN); return false end
    if not B.CanEdit(p) then ns.Print(L.BLESS_CANT_EDIT); return false end
    local ok = B.CycleSingle(p, key, delta)
    if ok then refresh() end
    return ok
end

-- what everyone gives this player, for tooltips
function P.TipLines(key, class)
    local lines = {}
    for _, g in ipairs(B.GivenTo(key, class)) do
        local text = Theme.HexColor("muted", full(g.p.name or g.p.key) .. ": ") .. icon(g.blessing, 14) .. " " .. (B.Name(g.blessing) or "")
        if g.single then
            text = text .. Theme.HexColor("accent", "  " .. (g.classB and L.BLESS_TIP_INSTEAD_OF:format(B.Name(g.classB)) or L.BLESS_TIP_SINGLE_SHORT))
        end
        lines[#lines + 1] = text
    end
    if #lines == 0 then lines[1] = Theme.HexColor("muted", L.BLESS_PICK_NOTHING) end
    return lines
end

local function tooltip(owner, key, extra, anchorTo, anchor)
    local m = B.members[key]
    if not m then return end
    tipAt(anchorTo or owner, anchor)
    local cr, cg, cb = ns.ClassColor(m.class)
    GameTooltip:SetText(m.name, cr, cg, cb)
    for _, line in ipairs(P.TipLines(key, m.class)) do GameTooltip:AddLine(line, 1, 1, 1) end
    GameTooltip:AddLine(extra or L.BLESS_PLAYER_LIST_TIP, 0.5, 0.5, 0.5, true)
    GameTooltip:Show()
end
P.Tooltip = tooltip

---------------------------------------------------------------------------
-- Picker: "<name> – single blessing from:" one row per paladin with his
-- blessings as icons. Click sets it at once (the class blessing = no single),
-- mouse wheel on a row cycles, × removes. Stays open for the next paladin;
-- a click outside or Esc closes it.
---------------------------------------------------------------------------
local PICK_ICON, PICK_NAME_W = 24, 136
local function pickIcon(row, i)
    local b = row.icons[i]
    if b then return b end
    b = CreateFrame("Button", nil, row)
    b:SetSize(PICK_ICON, PICK_ICON)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.ring = UI.Fill(b, "accent", "BACKGROUND"); b.ring:SetAllPoints()
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 2, -2); b.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.hl = UI.Fill(b, "hover", "HIGHLIGHT"); b.hl:SetAllPoints()
    b.dot = UI.Fill(b, "text", "OVERLAY"); b.dot:SetSize(6, 2); b.dot:SetPoint("BOTTOM", 0, -3)
    b:SetScript("OnClick", function(self, mouse)
        local f = P.picker
        if not f or not self.p then return end
        if not B.CanEdit(self.p) then ns.Print(L.BLESS_CANT_EDIT); return end
        if mouse == "RightButton" or self.value == "none" or self.value == self.classB then
            B.SetSingle(self.p, f.key, nil)
        else
            B.SetSingle(self.p, f.key, self.value)
        end
        refresh()
    end)
    b:SetScript("OnEnter", function(self)
        if not self.p then return end
        local title, lines
        if self.value == "none" then
            title, lines = L.BLESS_PICK_REMOVE, { self.classB and L.BLESS_SINGLE_CLASS:format(B.Name(self.classB)) or L.BLESS_SINGLE_REMOVE }
        elseif self.value == self.classB then
            title, lines = B.Name(self.value), { L.BLESS_PICK_CLASS_TIP:format(full(self.p.name or self.p.key)) }
        else
            title, lines = B.Name(self.value), { self.classB and L.BLESS_TIP_INSTEAD_OF:format(B.Name(self.classB)) or L.BLESS_TIP_SINGLE_SHORT }
        end
        if not B.CanEdit(self.p) then lines[#lines + 1] = L.BLESS_CANT_EDIT end
        P.hover = self
        P.Tip(self, title, lines, "ANCHOR_TOP")
    end)
    b:SetScript("OnLeave", P.Unhover)
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel", function(self, delta) local r = self:GetParent(); r:GetScript("OnMouseWheel")(r, delta) end)
    row.icons[i] = b
    return b
end

local function pickRow(f, i)
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, f)
    r:SetHeight(PICK_ICON + 8)
    r.bg = UI.Fill(r, (i % 2 == 0) and "rowAlt" or "row", "BACKGROUND"); r.bg:SetAllPoints()
    r.name = UI.Text(r, 12, "text")
    r.name:SetPoint("LEFT", 8, 0)
    r.name:SetWidth(PICK_NAME_W - 10)
    r.name:SetWordWrap(false)
    r.icons = {}
    r:EnableMouse(true)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(self, delta)
        if not self.p or not P.picker then return end
        if not B.CanEdit(self.p) then ns.Print(L.BLESS_CANT_EDIT); return end
        if B.CycleSingle(self.p, P.picker.key, delta) then refresh() end
    end)
    f.rows[i] = r
    return r
end

local function makePicker()
    local f = UI.Panel(UIParent, "panel", "border")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    UI.Float(f, "FULLSCREEN_DIALOG")
    _G.LiebeGruesseBlessPicker = f
    tinsert(UISpecialFrames, "LiebeGruesseBlessPicker")
    f.spec = f:CreateTexture(nil, "ARTWORK"); f.spec:SetSize(18, 18); f.spec:SetPoint("TOPLEFT", 10, -10)
    f.title = UI.Text(f, 14, "text", nil, nil, true)
    f.title:SetPoint("LEFT", f.spec, "RIGHT", 7, 0)
    f.title:SetWordWrap(false)
    f.close = UI.IconButton(f, "x", 20, function() f:Hide() end)
    f.close:SetPoint("TOPRIGHT", -6, -7)
    f.sub = UI.Text(f, 11, "muted")
    f.sub:SetPoint("TOPLEFT", 10, -34)
    f.sub:SetWordWrap(false)
    f.hint = UI.Text(f, 10, "muted")
    f.hint:SetPoint("BOTTOMLEFT", 10, 8)
    f.hint:SetWordWrap(true)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetText(L.BLESS_PICK_HINT)
    f.rows = {}
    f.catcher = CreateFrame("Button", nil, UIParent)
    f.catcher:SetAllPoints(UIParent)
    f.catcher:SetFrameStrata("FULLSCREEN")
    f.catcher:RegisterForClicks("AnyUp")
    f.catcher:SetScript("OnClick", function() f:Hide() end)
    f.catcher:Hide()
    f:SetScript("OnHide", function() f.catcher:Hide() end)

    function f.Draw()
        local m = B.members[f.key]
        if not m then f:Hide(); return end
        if not ns.SetSpecIcon(f.spec, m.class, ns.SpecPoints(ns.Database.Member(m.key))) then ns.SetClassIcon(f.spec, m.class) end
        f.title:SetText(ns.ColorName(m.name, m.class))
        local kind = B.UnitType(m.unit, m.key, m.class)
        f.sub:SetText(L.BLESS_PICK_TITLE:format(L["BLESS_TYPE_" .. kind:upper()] or kind))
        local pals = B.PaladinList()
        local width = 220
        local y = 52
        for i, p in ipairs(pals) do
            local r = pickRow(f, i)
            r.p = p
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 6, -y)
            r:SetPoint("TOPRIGHT", -6, -y)
            local edit = B.CanEdit(p)
            local pname = Names.Display(p.name or p.key)
            r.name:SetText(edit and ns.ColorName(pname, "PALADIN") or Theme.HexColor("muted", pname))
            local classB = p.set and p.set[m.class]
            local current = (p.single and p.single[f.key]) or classB
            local n = 0
            local function add(value, tex)
                n = n + 1
                local b = pickIcon(r, n)
                b.p, b.value, b.classB = p, value, classB
                b:ClearAllPoints()
                b:SetPoint("LEFT", PICK_NAME_W + (n - 1) * (PICK_ICON + 4), 0)
                if value == "none" then
                    b.tex:SetTexture(Theme.Icon("x", 32)); b.tex:SetTexCoord(0, 1, 0, 1)
                    b.tex:SetVertexColor(Theme.Color("muted"))
                else
                    b.tex:SetTexture(tex); b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92); b.tex:SetVertexColor(1, 1, 1)
                end
                b.ring:SetShown(value ~= "none" and value == current)
                b.dot:SetShown(value ~= "none" and value == classB)
                b.tex:SetDesaturated(not edit)
                b:SetAlpha(edit and 1 or 0.5)
                b:Show()
            end
            for _, info in ipairs(B.LIST) do
                if B.CanCast(p, info.key) or info.key == current then add(info.key, B.Icon(info.key)) end
            end
            if p.single and p.single[f.key] then add("none") end
            for j = n + 1, #r.icons do r.icons[j]:Hide() end
            width = math.max(width, PICK_NAME_W + n * (PICK_ICON + 4) + 18)
            r:Show()
            y = y + PICK_ICON + 10
        end
        for i = #pals + 1, #f.rows do f.rows[i]:Hide() end
        f.empty = f.empty or UI.Text(f, 11, "muted")
        f.empty:ClearAllPoints(); f.empty:SetPoint("TOPLEFT", 10, -y)
        f.empty:SetText(L.BLESS_NO_PALADINS)
        f.empty:SetShown(#pals == 0)
        if #pals == 0 then y = y + 20 end
        f.title:SetWidth(width - 70)
        f.sub:SetWidth(width - 20)
        f.hint:SetWidth(width - 20)
        local hintH = (f.hint:GetStringHeight() or 12) + 4
        f:SetSize(width, y + 10 + math.max(16, hintH))
    end
    f:Hide()
    return f
end

function P.Picker(anchor, key)
    if not B.members[key] then return end
    if #B.PaladinList() == 0 then ns.Print(L.BLESS_NO_PALADINS); return end
    P.picker = P.picker or makePicker()
    local f = P.picker
    f.key = key
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    if P.fly then P.fly:Hide() end
    f.catcher:Show()
    f:Show()
    f.Draw()
end

---------------------------------------------------------------------------
-- Player button (list under a class head)
---------------------------------------------------------------------------
local function playerClick(self, mouse)
    if not self.key then return end
    if mouse == "RightButton" then
        if B.ClearSingles(self.key) > 0 then refresh() end
    else
        P.Picker(self, self.key)
    end
end
local function playerWheel(self, delta)
    if not self.key then return end
    P.Cycle(self.key, delta, self.p)
end

function P.Button(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(P.LINE_H)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.hl = UI.Fill(b, "hover", "HIGHLIGHT"); b.hl:SetAllPoints()
    b.mark = UI.Fill(b, "accent", "ARTWORK")
    b.mark:SetPoint("TOPLEFT"); b.mark:SetPoint("BOTTOMLEFT"); b.mark:SetWidth(2)
    b.spec = b:CreateTexture(nil, "ARTWORK"); b.spec:SetSize(P.ICON, P.ICON); b.spec:SetPoint("LEFT", 4, 0)
    b.icons = UI.Text(b, P.FONT, "text", "RIGHT")
    b.icons:SetPoint("RIGHT", -2, 0)
    b.name = UI.Text(b, P.FONT, "text")
    b.name:SetPoint("LEFT", b.spec, "RIGHT", 4, 0)
    b.name:SetPoint("RIGHT", b.icons, "LEFT", -2, 0)
    b.name:SetWordWrap(false)
    b:SetScript("OnClick", playerClick)
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel", playerWheel)
    b:SetScript("OnEnter", function(self) if self.key then P.hover = self; tooltip(self, self.key) end end)
    b:SetScript("OnLeave", P.Unhover)
    P.buttons[#P.buttons + 1] = b
    -- key: player; returns whether he has a single blessing from anyone
    function b:Set(key, query)
        self.key, self.p = key, nil
        local m = B.members[key]
        if not m then self:Hide(); return false end
        self.class = m.class
        if not ns.SetSpecIcon(self.spec, m.class, ns.SpecPoints(ns.Database.Member(key))) then ns.SetClassIcon(self.spec, m.class) end
        local cr, cg, cb = ns.ClassColor(m.class)
        local text = ns.Hex(cr, cg, cb, full(m.name))
        self.name:SetText(query and ns.Highlight(text, query) or text)
        local icons = {}
        for _, g in ipairs(B.GivenTo(key, m.class)) do
            if g.single and #icons < 2 then icons[#icons + 1] = icon(g.blessing, P.ICON) end
        end
        -- no single: the name gets the whole width (no empty icon slot)
        self.icons:SetText(table.concat(icons, ""))
        self.icons:SetShown(#icons > 0)
        self.name:ClearAllPoints()
        self.name:SetPoint("LEFT", self.spec, "RIGHT", 4, 0)
        if #icons > 0 then self.name:SetPoint("RIGHT", self.icons, "LEFT", -2, 0) else self.name:SetPoint("RIGHT", self, "RIGHT", -2, 0) end
        self.mark:SetShown(#icons > 0)
        self:Show()
        return #icons > 0
    end
    return b
end

---------------------------------------------------------------------------
-- Single lines in a paladin's cell: "icon Name" per single blessing
---------------------------------------------------------------------------
local function lineButton(cell, i)
    cell.lines = cell.lines or {}
    local l = cell.lines[i]
    if l then return l end
    l = CreateFrame("Button", nil, cell)
    l:SetHeight(P.LINE_H - 1)
    l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    l.hl = UI.Fill(l, "hover", "HIGHLIGHT"); l.hl:SetAllPoints()
    l.text = UI.Text(l, P.FONT, "text")
    l.text:SetPoint("LEFT", 2, 0)
    l.text:SetPoint("RIGHT", -1, 0)
    l.text:SetWordWrap(false)
    l:SetScript("OnClick", function(self, mouse)
        if not self.p or not self.key then return end
        if not B.CanEdit(self.p) then ns.Print(L.BLESS_CANT_EDIT); return end
        if mouse == "RightButton" then B.SetSingle(self.p, self.key, nil); refresh()
        else P.Picker(self, self.key) end
    end)
    l:EnableMouseWheel(true)
    l:SetScript("OnMouseWheel", function(self, delta)
        if not self.p or not self.key then return end
        P.Cycle(self.key, delta, self.p)
    end)
    l:SetScript("OnEnter", function(self)
        if not self.key then return end
        P.hover = self
        tooltip(self, self.key, L.BLESS_SINGLE_LINE_TIP)
        if self:GetParent().p then P.ShowFly(self:GetParent()) end
    end)
    l:SetScript("OnLeave", P.Unhover)
    cell.lines[i] = l
    P.lines[#P.lines + 1] = l
    return l
end

-- draws the singles of paladin p in this class below y (from the top of the
-- cell); returns the number of lines
function P.CellLines(cell, p, class, y, query)
    local list = p and P.SinglesIn(p, class) or {}
    for i, s in ipairs(list) do
        local l = lineButton(cell, i)
        l.p, l.key = p, s.key
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", cell, "TOPLEFT", 1, -(y + (i - 1) * P.LINE_H))
        l:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -1, -(y + (i - 1) * P.LINE_H))
        local cr, cg, cb = ns.ClassColor(s.member.class)
        local has = B.SingleState(s.key, s.blessing)
        local name = ns.Hex(cr, cg, cb, full(s.member.name))
        l.text:SetText(icon(s.blessing, P.ICON) .. " " .. (query and ns.Highlight(name, query) or name))
        l:SetAlpha(has and 1 or 0.8)
        l:Show()
    end
    for i = #list + 1, #(cell.lines or {}) do cell.lines[i]:Hide(); cell.lines[i].key = nil end
    return #list
end

---------------------------------------------------------------------------
-- Cell flyout: hovering a paladin's cell unfolds every player of that class
-- below it. Mouse wheel on a name = this paladin's single blessing for him
-- (back to his class blessing is part of the cycle), click = picker,
-- right click = remove this paladin's single. Hides once the mouse leaves
-- cell and list; checks only while it is shown.
---------------------------------------------------------------------------
local FLY_W, FLY_HEAD = 200, 24
local function flyLine(f, i)
    local l = f.lines[i]
    if l then return l end
    l = CreateFrame("Button", nil, f)
    l:SetHeight(P.LINE_H)
    l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    l.hl = UI.Fill(l, "hover", "HIGHLIGHT"); l.hl:SetAllPoints()
    l.mark = UI.Fill(l, "accent", "ARTWORK")
    l.mark:SetPoint("TOPLEFT"); l.mark:SetPoint("BOTTOMLEFT"); l.mark:SetWidth(2)
    l.icon = l:CreateTexture(nil, "ARTWORK")
    l.icon:SetSize(P.ICON, P.ICON)
    l.icon:SetPoint("LEFT", 6, 0)
    l.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    l.dash = UI.Text(l, P.FONT, "borderDim", "CENTER")
    l.dash:SetPoint("CENTER", l.icon, "CENTER", 0, 0)
    l.dash:SetText("—")
    l.dot = UI.Fill(l, "good", "ARTWORK")
    l.dot:SetSize(6, 6)
    l.dot:SetPoint("RIGHT", -6, 0)
    l.name = UI.Text(l, P.FONT, "text")
    l.name:SetPoint("LEFT", l.icon, "RIGHT", 6, 0)
    l.name:SetPoint("RIGHT", l.dot, "LEFT", -4, 0)
    l.name:SetWordWrap(false)
    l:SetScript("OnClick", function(self, mouse)
        local p = P.fly and P.fly.p
        if not p or not self.key then return end
        if mouse == "RightButton" then
            if not B.CanEdit(p) then ns.Print(L.BLESS_CANT_EDIT); return end
            if p.single and p.single[self.key] then B.SetSingle(p, self.key, nil); refresh() end
        else
            P.Picker(self, self.key)
        end
    end)
    l:EnableMouseWheel(true)
    l:SetScript("OnMouseWheel", function(self, delta)
        local p = P.fly and P.fly.p
        if not p or not self.key then return end
        P.Cycle(self.key, delta, p)
    end)
    l:SetScript("OnEnter", function(self)
        local p = P.fly and P.fly.p
        if not self.key or not p then return end
        P.hover = self
        -- beside the list, so neither icons nor names are covered
        tooltip(self, self.key, L.BLESS_FLY_LINE_TIP:format(full(p.name or p.key)), P.fly, "ANCHOR_RIGHT")
    end)
    l:SetScript("OnLeave", P.Unhover)
    f.lines[i] = l
    return l
end

local function makeFly()
    local f = UI.Panel(UIParent, "panel", "border")
    f:SetFrameStrata("FULLSCREEN")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetWidth(FLY_W)
    _G.LiebeGruesseBlessCellFly = f
    f.title = UI.Text(f, 11, "muted")
    f.title:SetPoint("TOPLEFT", 8, -7)
    f.title:SetPoint("TOPRIGHT", -8, -7)
    f.title:SetWordWrap(false)
    f.lines = {}
    f.elapsed = 0
    f:SetScript("OnUpdate", function(self, el)
        self.elapsed = self.elapsed + el
        if self.elapsed < 0.1 then return end
        self.elapsed = 0
        local c = self.cell
        if not c or not c:IsVisible() then self:Hide(); return end
        if not (self:IsMouseOver() or c:IsMouseOver()) then self:Hide() end
    end)
    f:SetScript("OnHide", function(self) self.cell, self.p = nil, nil end)

    function f.Draw()
        local c, p = f.cell, f.p
        if not c or not p or not c.class then f:Hide(); return end
        local class = c.class
        local list = P.ClassPlayers(class)
        if #list == 0 then f:Hide(); return end
        local classB = p.set and p.set[class]
        local cr, cg, cb = ns.ClassColor(class)
        f.title:SetText(ns.ColorName(full(p.name or p.key), "PALADIN") .. Theme.HexColor("muted", "  ›  ") .. ns.Hex(cr, cg, cb, ns.ClassName(class)))
        local y = FLY_HEAD
        for i, key in ipairs(list) do
            local m = B.members[key]
            local l = flyLine(f, i)
            l.key = key
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", 2, -y)
            l:SetPoint("TOPRIGHT", -2, -y)
            local single = p.single and p.single[key]
            local b = single or classB
            if b then
                l.icon:SetTexture(B.Icon(b)); l.icon:Show(); l.dash:Hide()
                l.icon:SetDesaturated(false)
                local has = B.SingleState(key, b)
                l.dot:SetColorTexture(Theme.Color(has and "good" or "bad"))
                l.dot:Show()
            else
                l.icon:Hide(); l.dash:Show(); l.dot:Hide()
            end
            l.mark:SetShown(single ~= nil)
            local mr, mg, mb = ns.ClassColor(m and m.class or class)
            l.name:SetText(ns.Hex(mr, mg, mb, full(m and m.name or key)))
            l:SetAlpha(B.CanEdit(p) and 1 or 0.6)
            l:Show()
            y = y + P.LINE_H
        end
        for i = #list + 1, #f.lines do f.lines[i]:Hide(); f.lines[i].key = nil end
        f:SetWidth(math.max(FLY_W, (c:GetWidth() or 0)))
        f:SetHeight(y + 6)
    end
    f:Hide()
    return f
end

-- cell: needs .p (paladin) and .class
function P.ShowFly(cell)
    if not cell or not cell.p or not cell.class then return end
    if P.picker and P.picker:IsShown() then return end
    if #P.ClassPlayers(cell.class) == 0 then if P.fly then P.fly:Hide() end; return end
    P.fly = P.fly or makeFly()
    local f = P.fly
    if f.cell ~= cell or f.p ~= cell.p or not f:IsShown() then
        f.cell, f.p = cell, cell.p
        f:ClearAllPoints()
        -- overlaps the cell by 2 px: the mouse never crosses a gap
        f:SetPoint("TOPLEFT", cell, "BOTTOMLEFT", 0, 2)
        f.elapsed = 0
        f:Show()
    end
    f.Draw()
end

-- after a redraw of a window: the cell may now show another paladin
function P.UpdateFly()
    local f = P.fly
    if not f or not f:IsShown() then return end
    local c = f.cell
    if not c or not c:IsVisible() or not c.p then f:Hide(); return end
    f.p = c.p
    f.Draw()
end
