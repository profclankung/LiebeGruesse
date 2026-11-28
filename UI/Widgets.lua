-- Widget kit: dark cards, accent toggles, sliders, dropdowns and settings forms
local _, ns = ...
local UI = {}
ns.UI = UI
local Theme = ns.Theme
local WHITE = Theme.WHITE

local BACKDROP = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }

function UI.Skin(frame, bg, border)
    if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(Theme.Color(bg or "panel"))
    frame:SetBackdropBorderColor(Theme.Color(border or "borderDim"))
    Theme.RegisterSkin(frame, bg or "panel", border or "borderDim")
end

function UI.Panel(parent, bg, border)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    UI.Skin(f, bg, border)
    return f
end

-- head: titles/numbers font; big text (15+) uses it automatically
function UI.Text(parent, size, color, justify, flags, head)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    if head == nil then head = (size or 12) >= 15 end
    Theme.SetFont(fs, Theme.Font(head), Theme.FontSize(size or 12), flags or "")
    fs:SetTextColor(Theme.Color(color or "text"))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    Theme.RegisterText(fs, size or 12, color or "text", flags, head)
    fs.isHead = head
    return fs
end

function UI.Fill(parent, color, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture(WHITE)
    t:SetVertexColor(Theme.Color(color))
    Theme.RegisterFill(t, color)
    return t
end

-- Icon texture from Media\Icons, tinted with a color role
function UI.Icon(parent, name, size, color, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(Theme.Icon(name, size or 14))
    t:SetSize(size or 14, size or 14)
    t:SetVertexColor(Theme.Color(color or "textDim"))
    if color then Theme.RegisterFill(t, color) end
    return t
end

-- Separate windows/popups (council window, dialogs, votes): always above
-- the main window, raised when shown or clicked.
function UI.Float(frame, strata)
    frame:SetFrameStrata(strata or "DIALOG")
    frame:SetToplevel(true)
    -- separate windows carry the same bronze corner brackets as the main window
    if not frame.lgCorners then frame.lgCorners = UI.Corners(frame, 10) end
    frame:SetClampedToScreen(true)
    frame:HookScript("OnShow", function(self) self:Raise() end)
    return frame
end

-- Inline icon for font strings: UI.Glyph("star", "gold", 14) -> "|T...|t"
local GLYPH_PATH = "Interface\\AddOns\\LiebeGruesse\\Media\\Icons\\"
function UI.Glyph(name, role, size)
    local r, g, b = Theme.Color(role or "textDim")
    size = size or 14
    local path, dim = Theme.IconFile(name, size)
    return ("|T%s.tga:%d:%d:0:0:%d:%d:0:%d:0:%d:%d:%d:%d|t"):format(path, size, size, dim, dim, dim, dim,
        math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

-- Horizontal fade from a color role to transparent
function UI.Gradient(parent, role, alpha, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture(WHITE)
    local function apply()
        local r, g, b = Theme.Color(role)
        if t.SetGradient and CreateColor then
            t:SetGradient("HORIZONTAL", CreateColor(r, g, b, alpha or 0.35), CreateColor(r, g, b, 0))
        elseif t.SetGradientAlpha then
            t:SetGradientAlpha("HORIZONTAL", r, g, b, alpha or 0.35, r, g, b, 0)
        else
            t:SetVertexColor(r, g, b, (alpha or 0.35) / 2)
        end
    end
    apply()
    Theme.OnApply(apply)
    return t
end

-- Vertical fade between two colors {r,g,b,a} (top -> bottom)
function UI.VGradient(parent, top, bottom, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture(WHITE)
    if t.SetGradient and CreateColor then
        t:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1), CreateColor(top[1], top[2], top[3], top[4] or 1))
    elseif t.SetGradientAlpha then
        t:SetGradientAlpha("VERTICAL", bottom[1], bottom[2], bottom[3], bottom[4] or 1, top[1], top[2], top[3], top[4] or 1)
    else
        t:SetVertexColor(top[1], top[2], top[3], top[4] or 1)
    end
    return t
end

-- Bronze corner brackets: two 1px strokes per corner, drawn on top of a card
function UI.Corners(parent, size, role, layer)
    size, role = size or 7, role or "bronze"
    local corners = {}
    for _, spec in ipairs({ { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }) do
        local point, sx, sy = spec[1], spec[2], spec[3]
        local h = UI.Fill(parent, role, layer or "OVERLAY")
        h:SetSize(size, 1)
        h:SetPoint(point, parent, point, -sx, -sy)
        local v = UI.Fill(parent, role, layer or "OVERLAY")
        v:SetSize(1, size)
        v:SetPoint(point, parent, point, -sx, -sy)
        corners[#corners + 1] = h
        corners[#corners + 1] = v
    end
    return corners
end

-- Engraved card title: bronze diamond, upper-case text and a thin rule to the
-- right (up to rightAnchor when given). Returns the font string.
function UI.CardTitle(card, text, rightAnchor, y)
    y = y or -10
    local d = UI.Fill(card, "bronze", "ARTWORK")
    d:SetSize(5, 5)
    d:SetPoint("TOPLEFT", 14, y - 4)
    if d.SetRotation then d:SetRotation(math.rad(45)) end
    local fs = UI.Text(card, 13, "text", nil, nil, true)
    fs:SetPoint("TOPLEFT", 26, y)
    fs:SetText(ns.Upper(text or ""))
    local rule = UI.Fill(card, "borderDim", "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("LEFT", fs, "RIGHT", 10, 0)
    if rightAnchor then rule:SetPoint("RIGHT", rightAnchor, "LEFT", -8, 0) else rule:SetPoint("RIGHT", card, "TOPRIGHT", -12, y - 7) end
    fs.rule, fs.diamond = rule, d
    UI.Corners(card)
    return fs
end

function UI.Tooltip(owner, title, lines)
    ns.TipOwner(owner, "ANCHOR_RIGHT")
    local tr, tg, tb = Theme.Color("text")
    GameTooltip:SetText(title or "", tr, tg, tb)
    local r, g, b = Theme.Color("textDim")
    for _, line in ipairs(lines or {}) do GameTooltip:AddLine(line, r, g, b, true) end
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
function UI.Button(parent, text, width, height, onClick, icon)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 100, height or 24)
    UI.Skin(b, "button", "border")
    b.label = UI.Text(b, 12, "text", "CENTER")
    b.label:SetPoint("CENTER", icon and 8 or 0, 0)
    b.label:SetText(text or "")
    if icon then
        b.icon = UI.Icon(b, icon, 13, "textDim")
        b.icon:SetPoint("RIGHT", b.label, "LEFT", -6, 0)
    end
    b:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            self:SetBackdropColor(Theme.Color("buttonHot"))
            self:SetBackdropBorderColor(Theme.Color("accent"))
        end
        if self.tip then UI.Tooltip(self, self.tipTitle or self.label:GetText(), self.tip) end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(Theme.Color("button")); self:SetBackdropBorderColor(Theme.Color("border"))
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(self, ...) if onClick then ns.Safe(onClick, self, ...) end end)
    function b:SetText(t) self.label:SetText(t) end
    hooksecurefunc(b, "Disable", function(self) self.label:SetTextColor(Theme.Color("muted")) end)
    hooksecurefunc(b, "Enable", function(self) self.label:SetTextColor(Theme.Color("text")) end)
    hooksecurefunc(b, "SetEnabled", function(self, on) self.label:SetTextColor(Theme.Color(on and "text" or "muted")) end)
    return b
end

-- Small square icon button (header controls)
function UI.IconButton(parent, icon, size, onClick, danger)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(size or 26, size or 26)
    UI.Skin(b, "button", "border")
    b.icon = UI.Icon(b, icon, math.floor((size or 26) * 0.55), danger and "bad" or "textDim")
    b.icon:SetPoint("CENTER")
    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(Theme.Color(danger and "bad" or "accent"))
        if self.tip then UI.Tooltip(self, self.tip, self.tipLines) end
    end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(Theme.Color("border")); GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self, ...) if onClick then ns.Safe(onClick, self, ...) end end)
    return b
end

---------------------------------------------------------------------------
-- Flash: a frame (accent frame or fill) pulses and fades out – shows where a
-- search result is. Uses an animation group, no OnUpdate.
---------------------------------------------------------------------------
-- the mark lasts about 5 s in all (pulses, hold, fade)
UI.FLASH_TIME = 5
UI.FLASH_HOLD = 2.9
-- The cross at the top right of a window (every window of the addon can be closed).
-- onClose decides what closing means (default: hide the frame).
function UI.CloseX(frame, onClose, size, x, y)
    local b = UI.IconButton(frame, "x", size or 18, function()
        if onClose then ns.Safe(onClose) else frame:Hide() end
    end)
    b:SetPoint("TOPRIGHT", x or -8, y or -8)
    b.tip = ns.L.CLOSE
    b:SetFrameLevel((frame:GetFrameLevel() or 1) + 10)
    frame.closeX = b
    return b
end

function UI.Flash(f, restart)
    if not f then return end
    if f.flashAnim and f.flashAnim:IsPlaying() and not restart then return end
    if not f.flashAnim then
        local g = f:CreateAnimationGroup()
        local function step(from, to, dur, order)
            local a = g:CreateAnimation("Alpha")
            if a.SetFromAlpha then a:SetFromAlpha(from); a:SetToAlpha(to) elseif a.SetChange then a:SetChange(to - from) end
            a:SetDuration(dur)
            a:SetOrder(order)
        end
        -- two pulses, then it stays marked for a while and fades out slowly
        step(0, 1, 0.18, 1); step(1, 0.35, 0.35, 2); step(0.35, 1, 0.35, 3); step(1, 0.35, 0.35, 4); step(0.35, 1, 0.35, 5)
        step(1, 1, UI.FLASH_HOLD, 6); step(1, 0, 0.5, 7)
        g:SetScript("OnFinished", function() f:Hide(); f:SetAlpha(1) end)
        f.flashAnim = g
    end
    f:Show()
    f.flashAnim:Stop()
    f.flashAnim:Play()
end

---------------------------------------------------------------------------
-- Page search over sub tabs: every tab is searched, the tabs show their
-- number of hits, and when the open tab has none the first tab with hits opens.
--   tabs[key].SearchHits(q) -> n   tabs[key].SearchApply(q)   (both optional)
---------------------------------------------------------------------------
function UI.TabSearch(bar, tabs, query)
    local q = (query or ""):find("%S") and query or ""
    local hits, total = {}, 0
    for _, b in ipairs(bar.buttons) do
        local t = tabs[b.key]
        local n = (q ~= "" and t and t.SearchHits) and (ns.Try(t.SearchHits, q) or 0) or 0
        if type(n) ~= "number" then n = 0 end
        hits[b.key] = n
        total = total + n
        bar:SetHits(b.key, q ~= "" and n or nil)
    end
    if q ~= "" and (hits[bar.current] or 0) == 0 then
        for _, b in ipairs(bar.buttons) do
            if hits[b.key] > 0 then bar:Select(b.key); break end
        end
    end
    local t = tabs[bar.current]
    if t and t.SearchApply then ns.Safe(t.SearchApply, q) end
    return total
end

---------------------------------------------------------------------------
-- Empty state: icon in a small bronze-framed tile, a line of text and a hint
--   local e = UI.Empty(parent); e:Set(icon, text, hint); e:SetPoint(...)
---------------------------------------------------------------------------
function UI.Empty(parent, width)
    local e = CreateFrame("Frame", nil, parent)
    e:SetSize(width or 380, 110)
    e.tile = UI.Panel(e, "input", "bronzeDim")
    e.tile:SetSize(44, 44)
    e.tile:SetPoint("TOP", 0, 0)
    UI.Corners(e.tile, 6)
    e.icon = UI.Icon(e.tile, "dot", 20, "bronze")
    e.icon:SetPoint("CENTER")
    e.text = UI.Text(e, 13, "textDim", "CENTER")
    e.text:SetPoint("TOP", e.tile, "BOTTOM", 0, -12)
    e.text:SetWidth(width or 380)
    e.text:SetWordWrap(true)
    e.hint = UI.Text(e, 11, "muted", "CENTER")
    e.hint:SetPoint("TOP", e.text, "BOTTOM", 0, -6)
    e.hint:SetWidth(width or 380)
    e.hint:SetWordWrap(true)
    function e:Set(icon, text, hint)
        Theme.SetIcon(self.icon, icon or "dot")
        self.text:SetText(text or "")
        self.hint:SetText(hint or "")
        self.hint:SetShown((hint or "") ~= "")
    end
    function e:SetTextWidth(w)
        self:SetWidth(w)
        self.text:SetWidth(w)
        self.hint:SetWidth(w)
    end
    return e
end

-- small search mark in the top right corner of a frame (after the flash);
-- ns.Window.SetMark hides it again with the next click in the window
function UI.Pin(parent)
    if parent.searchPin then return parent.searchPin end
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(12, 12)
    p:SetPoint("TOPRIGHT", -3, -2)
    p:SetFrameLevel(parent:GetFrameLevel() + 8)
    -- engraved style: accent diamond with a light centre
    p.bg = UI.Fill(p, "accent", "ARTWORK")
    p.bg:SetSize(8, 8)
    p.bg:SetPoint("CENTER")
    if p.bg.SetRotation then p.bg:SetRotation(math.rad(45)) end
    p.dot = UI.Fill(p, "text", "OVERLAY")
    p.dot:SetSize(2, 2)
    p.dot:SetPoint("CENTER")
    p:Hide()
    parent.searchPin = p
    return p
end

-- the empty state for a search without a match
function UI.EmptySearch(e, query)
    e:Set("search", ns.L.SEARCH_NOTHING:format(query or ""), ns.L.SEARCH_NOTHING_HINT)
end

---------------------------------------------------------------------------
-- Inputs
---------------------------------------------------------------------------
function UI.EditBox(parent, width, height, placeholder)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetSize(width or 160, height or 24)
    UI.Skin(e, "input", "border")
    Theme.SetFont(e, Theme.Font(), Theme.FontSize(12), "")
    e:SetTextColor(Theme.Color("text"))
    Theme.RegisterText(e, 12, nil, "")
    e:SetTextInsets(8, 8, 0, 0)
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus(); if self.onEnter then ns.Safe(self.onEnter, self) end end)
    e:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(Theme.Color("accent")) end)
    e:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(Theme.Color("border"))
        if self.onCommit then ns.Safe(self.onCommit, self) end
    end)
    if placeholder then
        e.placeholder = UI.Text(e, 12, "muted")
        e.placeholder:SetPoint("LEFT", 8, 0)
        e.placeholder:SetPoint("RIGHT", -8, 0)
        e.placeholder:SetText(placeholder)
    end
    e:SetScript("OnTextChanged", function(self, user)
        if self.placeholder then self.placeholder:SetShown(self:GetText() == "") end
        if self.onChange then ns.Safe(self.onChange, self, self:GetText(), user) end
    end)
    return e
end

-- Switch: accent track with a light knob when on
function UI.Toggle(parent, get, set)
    local t = CreateFrame("Button", nil, parent, "BackdropTemplate")
    t:SetSize(28, 14)
    UI.Skin(t, "sidebar", "border")
    t.knob = t:CreateTexture(nil, "ARTWORK")
    t.knob:SetTexture(WHITE)
    t.knob:SetSize(10, 10)
    function t:Refresh()
        local on = get() and true or false
        self.on = on
        self.knob:ClearAllPoints()
        if on then
            self:SetBackdropColor(Theme.Color("accent"))
            self:SetBackdropBorderColor(Theme.Color("accent"))
            self.knob:SetPoint("RIGHT", -2, 0)
            self.knob:SetVertexColor(1, 1, 1, 1)
        else
            self:SetBackdropColor(Theme.Color("sidebar"))
            self:SetBackdropBorderColor(Theme.Color("border"))
            self.knob:SetPoint("LEFT", 2, 0)
            self.knob:SetVertexColor(0.65, 0.68, 0.74, 1)
        end
    end
    t:SetScript("OnClick", function(self)
        ns.Safe(set, not get())
        self:Refresh()
    end)
    Theme.OnApply(function() t:Refresh() end)
    t:Refresh()
    return t
end

-- Toggle with label to the right (filters, small option rows)
function UI.Check(parent, label, get, set, tip)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(200, 20)
    c.toggle = UI.Toggle(c, get, set)
    c.toggle:SetPoint("LEFT")
    c.label = UI.Text(c, 12, "textDim")
    c.label:SetPoint("LEFT", c.toggle, "RIGHT", 8, 0)
    c.label:SetText(label)
    c:SetWidth(36 + math.max(20, c.label:GetStringWidth() or 60))
    function c:Refresh() self.toggle:Refresh() end
    c:SetScript("OnClick", function() c.toggle:Click() end)
    c:SetScript("OnEnter", function(self)
        self.label:SetTextColor(Theme.Color("text"))
        if tip then UI.Tooltip(self, label, { tip }) end
    end)
    c:SetScript("OnLeave", function(self) self.label:SetTextColor(Theme.Color("textDim")); GameTooltip:Hide() end)
    return c
end

---------------------------------------------------------------------------
-- Dropdown: items() returns { {value=, text=}, ... }
---------------------------------------------------------------------------
local menu
local function getMenu()
    if menu then return menu end
    menu = UI.Panel(UIParent, "input", "border")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu.buttons = {}
    menu:Hide()
    menu.catcher = CreateFrame("Button", nil, UIParent)
    menu.catcher:SetAllPoints(UIParent)
    menu.catcher:SetFrameStrata("FULLSCREEN")
    menu.catcher:SetScript("OnClick", function() menu:Hide() end)
    menu.catcher:Hide()
    menu:SetScript("OnHide", function() menu.catcher:Hide() end)
    return menu
end

---------------------------------------------------------------------------
-- Search menu: dropdown with a search field, group headings and rows with
-- an icon, a tag and a value on the right. Arrow keys + Enter, Esc closes.
--   UI.SearchMenu(anchor, { width, placeholder, text, point = { point, relPoint, x, y }, twoLine,
--                           build = fn(query) -> entries, onPick = fn(value) })
--   entry: { head = "TITLE" } or { value, text, sub, prefix, right, tag, setIcon = fn(tex), border = { r, g, b },
--            children = { entry, … } }
--   twoLine: rows with a second line (sub: breadcrumb "Page › Card"); prefix in
--   accent before the text ("Section:"); children: the same label in several
--   places – the row opens / closes (+ / −), the children are picked.
---------------------------------------------------------------------------
local search
local SEARCH_ROWS, SEARCH_ROW_H, SEARCH_ROW_H2, SEARCH_HEAD_H, SEARCH_MAX_H = 12, 26, 38, 24, 456
local function getSearch()
    if search then return search end
    local s = UI.Panel(UIParent, "panel", "border")
    s:SetFrameStrata("FULLSCREEN_DIALOG")
    s:SetClampedToScreen(true)
    s:EnableMouse(true)
    UI.Corners(s)
    s:Hide()
    s.catcher = CreateFrame("Button", nil, UIParent)
    s.catcher:SetAllPoints(UIParent)
    s.catcher:SetFrameStrata("FULLSCREEN")
    s.catcher:SetScript("OnClick", function() s:Hide() end)
    s.catcher:Hide()
    s:SetScript("OnHide", function() s.catcher:Hide(); s.edit:ClearFocus() end)
    s.edit = UI.EditBox(s, 200, 26, "")
    s.edit:SetPoint("TOPLEFT", 8, -8)
    s.edit:SetPoint("TOPRIGHT", -8, -8)
    s.edit:SetTextInsets(26, 8, 0, 0)
    s.edit.icon = UI.Icon(s.edit, "search", 12, "textDim")
    s.edit.icon:SetPoint("LEFT", 8, 0)
    if s.edit.placeholder then s.edit.placeholder:ClearAllPoints(); s.edit.placeholder:SetPoint("LEFT", 26, 0) end
    s.edit:SetScript("OnEscapePressed", function() s:Hide() end)
    s.rows = {}
    s.hint = UI.Text(s, 10, "muted")
    s.hint:SetPoint("BOTTOMLEFT", 10, 7)
    s:EnableMouseWheel(true)
    search = s
    return s
end

function UI.SearchMenu(anchor, opts)
    local s = getSearch()
    local width = opts.width or 330
    local twoLine = opts.twoLine
    s.opts, s.offset, s.sel, s.open = opts, 0, nil, {}
    s:SetWidth(width)
    if s.edit.placeholder then s.edit.placeholder:SetText(opts.placeholder or "") end
    s.hint:SetText(opts.hint or "")

    local function pickable(i) local e = s.entries[i]; return e and not e.head end
    local function rowH(e)
        if not e or e.head then return SEARCH_HEAD_H end
        return (twoLine and e.sub) and SEARCH_ROW_H2 or SEARCH_ROW_H
    end
    -- entries from the offset on that fit into the list height
    local function fitting(from)
        local h, n = 0, 0
        local maxH = twoLine and SEARCH_MAX_H or SEARCH_ROWS * SEARCH_ROW_H
        for i = from, #s.entries do
            local eh = rowH(s.entries[i])
            if h + eh > maxH and n > 0 then break end
            h, n = h + eh, n + 1
        end
        return n, h
    end
    -- groups that are open show their children right below
    local function flatten()
        local out = {}
        for _, e in ipairs(s.raw or {}) do
            out[#out + 1] = e
            if e.children and s.open[e] then
                for _, c in ipairs(e.children) do c.child = true; out[#out + 1] = c end
            end
        end
        s.entries = out
    end
    local draw
    local function choose(e)
        if not e or e.head then return end
        if e.children then
            s.open[e] = not s.open[e]
            flatten()
            for i, x in ipairs(s.entries) do if x == e then s.sel = i end end
            draw()
            return
        end
        s:Hide()
        ns.Safe(opts.onPick, e.value)
    end
    draw = function()
        local visible, listH = fitting(s.offset + 1)
        local y = -42
        for i = 1, visible do
            local e = s.entries[i + s.offset]
            local r = s.rows[i]
            if not r then
                r = CreateFrame("Button", nil, s)
                r.hl = UI.Fill(r, "hover", "HIGHLIGHT"); r.hl:SetAllPoints()
                r.sel = UI.Fill(r, "selected", "BORDER"); r.sel:SetAllPoints()
                r.bar = UI.Fill(r, "accent", "ARTWORK"); r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(2)
                r.guide = UI.Fill(r, "borderDim", "ARTWORK"); r.guide:SetWidth(1)
                r.guide:SetPoint("TOPLEFT", 19, 0); r.guide:SetPoint("BOTTOMLEFT", 19, 0)
                r.border = r:CreateTexture(nil, "ARTWORK"); r.border:SetTexture(Theme.WHITE); r.border:SetSize(18, 18)
                r.icon = r:CreateTexture(nil, "OVERLAY"); r.icon:SetSize(16, 16); r.icon:SetPoint("CENTER", r.border, "CENTER")
                r.text = UI.Text(r, 13, "text")
                r.sub = UI.Text(r, 11, "muted")
                r.right = UI.Text(r, 13, "text", "RIGHT", nil, true)
                r.right:SetPoint("RIGHT", -10, 0)
                r.tag = UI.Text(r, 10, "bronze", "RIGHT", nil, true)
                r.tag:SetPoint("RIGHT", r.right, "LEFT", -8, 0)
                r.head = UI.Text(r, 11, "bronze", "LEFT", nil, true)
                r.head:SetPoint("BOTTOMLEFT", 10, 3)
                s.rows[i] = r
            end
            local h = rowH(e)
            r:SetHeight(h)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 1, y)
            r:SetPoint("TOPRIGHT", -1, y)
            y = y - h
            local isHead = e and e.head
            r.head:SetShown(isHead and true or false)
            r.head:SetText(isHead and ns.Upper(e.head) or "")
            for _, part in ipairs({ r.text, r.right, r.tag, r.icon, r.border }) do part:SetShown(e ~= nil and not isHead) end
            r.hl:SetShown(e ~= nil and not isHead)
            local selected = (i + s.offset) == s.sel
            r.sel:SetShown(selected); r.bar:SetShown(selected)
            local child = e and e.child and true or false
            r.guide:SetShown(child)
            if e and not isHead then
                local indent = child and 18 or 0
                local hasSub = twoLine and e.sub ~= nil
                r.border:ClearAllPoints()
                r.border:SetPoint("LEFT", 10 + indent, 0)
                local x = (e.setIcon or e.border) and (10 + indent + 18 + 8) or (10 + indent)
                r.text:ClearAllPoints(); r.sub:ClearAllPoints()
                if hasSub then
                    r.text:SetPoint("TOPLEFT", x, -5)
                    r.sub:SetPoint("TOPLEFT", x, -21)
                else
                    r.text:SetPoint("LEFT", x, 0)
                end
                local title = ns.Highlight(e.text or "", s.query or "", e.hlRole)
                if e.prefix then title = Theme.HexColor("accent", e.prefix) .. " " .. title end
                if e.children then title = title .. "  " .. Theme.HexColor("accent", s.open[e] and "−" or "+") end
                r.text:SetText(title)
                r.sub:SetShown(hasSub)
                r.sub:SetText(hasSub and e.sub or "")
                r.right:SetText(e.right or "")
                r.tag:SetText(e.tag and ns.Upper(e.tag) or "")
                local free = width - x - 10 - (r.right:GetStringWidth() or 0) - (e.tag and (r.tag:GetStringWidth() or 0) + 8 or 0) - 16
                r.text:SetWidth(math.max(40, free))
                r.sub:SetWidth(math.max(40, width - x - 16))
                if e.setIcon then e.setIcon(r.icon) else r.icon:SetTexture(nil) end
                local b = e.border
                r.border:SetShown(b ~= nil)
                if b then r.border:SetVertexColor(b[1], b[2], b[3], 1) end
            else
                r.sub:Hide()
            end
            r:SetScript("OnClick", function() choose(e) end)
            r:Show()
        end
        for i = visible + 1, #s.rows do s.rows[i]:Hide() end
        local hintH = (opts.hint and opts.hint ~= "") and 22 or 6
        s:SetHeight(42 + math.max(SEARCH_ROW_H, listH) + hintH)
    end
    local function rebuild(text)
        s.query = text or ""
        local ok, res = pcall(opts.build, (text or ""):lower())
        if not ok then ns.Safe(error, res) end
        s.raw = (ok and type(res) == "table") and res or {}
        s.open = {}
        flatten()
        s.offset, s.sel = 0, nil
        for i = 1, #s.entries do if pickable(i) then s.sel = i; break end end
        draw()
    end
    local function move(delta)
        if not s.sel then return end
        local i = s.sel
        repeat i = i + delta until i < 1 or i > #s.entries or pickable(i)
        if i < 1 or i > #s.entries then return end
        s.sel = i
        if s.sel <= s.offset then s.offset = math.max(0, s.sel - 2) end
        while s.sel > s.offset + fitting(s.offset + 1) do s.offset = s.offset + 1 end
        draw()
    end
    s.edit.onChange = function(_, text) rebuild(text) end
    s.edit:SetScript("OnArrowPressed", function(_, key) if key == "UP" then move(-1) elseif key == "DOWN" then move(1) end end)
    s.edit:SetScript("OnEnterPressed", function()
        local e = s.sel and s.entries[s.sel]
        if e and e.children then choose(e); return end
        s:Hide()
        if e and not e.head then ns.Safe(opts.onPick, e.value) end
    end)
    s:SetScript("OnMouseWheel", function(_, delta)
        s.offset = math.max(0, math.min(math.max(0, #s.entries - 3), s.offset - delta * 3))
        draw()
    end)
    s.edit:SetText(opts.text or "")
    rebuild(opts.text or "")
    s:ClearAllPoints()
    if opts.point then
        local p = opts.point
        s:SetPoint(p[1], anchor, p[2], p[3] or 0, p[4] or 0)
    else
        s:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    end
    s.catcher:Show()
    s:Show()
    s.edit:SetFocus()
end

local MAX_VISIBLE = 18
function UI.OpenMenu(anchor, items, onPick, width, current)
    local m = getMenu()
    width = width or anchor:GetWidth()
    m.items, m.onPick, m.offset = items, onPick, 0
    local visible = math.min(#items, MAX_VISIBLE)
    local function draw()
        for i = 1, visible do
            local item = m.items[i + m.offset]
            local b = m.buttons[i]
            if not b then
                b = CreateFrame("Button", nil, m)
                b:SetHeight(22)
                b.hl = UI.Fill(b, "selected", "HIGHLIGHT")
                b.hl:SetAllPoints()
                b.bar = UI.Fill(b, "accent", "ARTWORK")
                b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(2)
                b.text = UI.Text(b, 12, "textDim")
                b.text:SetPoint("LEFT", 10, 0)
                b.text:SetPoint("RIGHT", -8, 0)
                m.buttons[i] = b
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 1, -1 - (i - 1) * 22)
            b:SetPoint("TOPRIGHT", -1, -1 - (i - 1) * 22)
            b.text:SetText(item and item.text or "")
            local isCurrent = item and current ~= nil and item.value == current
            b.bar:SetShown(isCurrent or false)
            b.text:SetTextColor(Theme.Color(isCurrent and "text" or "textDim"))
            -- font lists preview the font itself
            if item and item.path and tostring(item.path):lower():find("%.[ot]tf$") then
                Theme.SetFont(b.text, item.path, Theme.FontSize(12), "")
            else
                Theme.SetFont(b.text, Theme.Font(), Theme.FontSize(12), "")
            end
            b:SetScript("OnClick", function() m:Hide(); if item then ns.Safe(m.onPick, item.value, item) end end)
            b:Show()
        end
        for i = visible + 1, #m.buttons do m.buttons[i]:Hide() end
    end
    m:EnableMouseWheel(true)
    m:SetScript("OnMouseWheel", function(_, delta)
        m.offset = math.max(0, math.min(#m.items - visible, m.offset - delta * 3))
        draw()
    end)
    draw()
    m:SetSize(width, visible * 22 + 2)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    m.catcher:Show()
    m:Show()
end

function UI.Dropdown(parent, width, items, get, set)
    local d = CreateFrame("Button", nil, parent, "BackdropTemplate")
    d:SetSize(width or 180, 24)
    UI.Skin(d, "input", "border")
    d.label = UI.Text(d, 12, "text")
    d.label:SetPoint("LEFT", 9, 0)
    d.label:SetPoint("RIGHT", -24, 0)
    d.arrow = UI.Icon(d, "chevron-down", 12, "textDim")
    d.arrow:SetPoint("RIGHT", -8, 0)
    function d:Refresh()
        local current = get()
        for _, item in ipairs(items()) do
            if item.value == current then self.label:SetText(item.text); return end
        end
        self.label:SetText(current and tostring(current) or "–")
    end
    d:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(Theme.Color("accent")) end)
    d:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(Theme.Color("border")) end)
    d:SetScript("OnClick", function(self)
        UI.OpenMenu(self, items(), function(value) ns.Safe(set, value); self:Refresh() end, self.menuWidth, get())
    end)
    d:Refresh()
    return d
end

-- Segmented choice: options = { {value=, text=}, ... }
function UI.Segmented(parent, width, options, get, set)
    local f = UI.Panel(parent, "input", "border")
    f:SetSize(width or 240, 24)
    f.buttons = {}
    local w = (width or 240) / #options
    for i, opt in ipairs(options) do
        local b = CreateFrame("Button", nil, f)
        b:SetPoint("TOPLEFT", (i - 1) * w, 0)
        b:SetSize(w, 24)
        b.bg = UI.Fill(b, "accentDim", "BACKGROUND")
        b.bg:SetPoint("TOPLEFT", 1, -1)
        b.bg:SetPoint("BOTTOMRIGHT", -1, 1)
        b.text = UI.Text(b, 11, "muted", "CENTER")
        b.text:SetPoint("CENTER")
        b.text:SetText(opt.text)
        b:SetScript("OnClick", function() ns.Safe(set, opt.value); f:Refresh() end)
        b.value = opt.value
        f.buttons[i] = b
    end
    -- buttons share the width; follows SetWidth (responsive toolbars)
    function f:Layout()
        local bw = (self:GetWidth() or width or 240) / #self.buttons
        for i, b in ipairs(self.buttons) do
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", (i - 1) * bw, 0); b:SetSize(bw, 24)
        end
    end
    f:SetScript("OnSizeChanged", function(self) self:Layout() end)
    function f:Refresh()
        local current = get()
        for _, b in ipairs(self.buttons) do
            local on = b.value == current
            b.bg:SetShown(on)
            b.text:SetTextColor(Theme.Color(on and "text" or "muted"))
        end
    end
    f:Refresh()
    return f
end

---------------------------------------------------------------------------
-- Filter chips: a row of small toggle buttons (icon, label, count), one active.
--   UI.FilterChips(parent, items { {value, text, icon = name or texture id, tip} }, get, set)
-- Too narrow: chips shrink to the icon (label + count move into the tooltip).
---------------------------------------------------------------------------
function UI.FilterChips(parent, items, get, set)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(24)
    bar.chips = {}
    local GAP = 6
    local function paint(c)
        local on = c.value == get()
        c:SetBackdropColor(Theme.Color(on and "accentDim" or "button"))
        c:SetBackdropBorderColor(Theme.Color(on and "accent" or (c.hot and "border" or "borderDim")))
        c.label:SetTextColor(Theme.Color(on and "text" or (c.hot and "textDim" or "muted")))
        if c.iconRole then c.icon:SetVertexColor(Theme.Color(on and "accent" or (c.hot and "textDim" or "muted"))) end
        c.icon:SetDesaturated(not on and not c.hot and not c.iconRole)
        c.icon:SetAlpha((on or c.hot) and 1 or 0.75)
    end
    for i, item in ipairs(items) do
        local c = CreateFrame("Button", nil, bar, "BackdropTemplate")
        UI.Skin(c, "button", "borderDim")
        c:SetHeight(24)
        c.value, c.text = item.value, item.text
        if type(item.icon) == "string" then
            c.icon = UI.Icon(c, item.icon, 13, "muted")
            c.iconRole = true
        else
            c.icon = c:CreateTexture(nil, "ARTWORK")
            c.icon:SetSize(14, 14)
            c.icon:SetTexture(item.icon or 134400)
            c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        c.label = UI.Text(c, 11, "muted", "LEFT")
        c.label:SetText(item.text)
        c.count = UI.Text(c, 10, "muted", "LEFT", nil, true)
        c:SetScript("OnClick", function(self)
            if get() == self.value then return end
            ns.Safe(set, self.value)
            bar:Refresh()
        end)
        c:SetScript("OnEnter", function(self)
            self.hot = true; paint(self)
            local lines = {}
            if item.tip then lines[#lines + 1] = item.tip end
            if self.n then lines[#lines + 1] = ns.L.CHIP_COUNT:format(self.n) end
            -- always a tooltip: the full name and the number of entries
            UI.Tooltip(self, self.text, lines)
        end)
        c:SetScript("OnLeave", function(self) self.hot = nil; paint(self); GameTooltip:Hide() end)
        bar.chips[i] = c
    end
    -- n = entries behind a chip (nil hides the number)
    function bar:SetCount(value, n)
        for _, c in ipairs(self.chips) do
            if c.value == value then c.n = n; c.count:SetText(n and tostring(n) or "") end
        end
        self:Fit()
    end
    -- the number shows only when there is something behind the chip
    local function hasCount(c) return c.n ~= nil and c.n > 0 end
    local function fullWidth(c, withCount)
        local tw = c.label:GetStringWidth() or 0
        if tw <= 0 then tw = #c.text * 6 end
        local show = withCount and hasCount(c)
        local cw = show and ((c.count:GetStringWidth() or 0) > 0 and c.count:GetStringWidth() or #tostring(c.n) * 6) or 0
        return math.ceil(8 + 14 + 5 + tw + (show and (5 + cw) or 0) + 9)
    end
    -- wide: icon, label and count; narrower: without counts; narrow: icons only
    function bar:Fit()
        local avail = self:GetWidth() or 0
        if avail <= 0 then avail = 1e9 end
        local function total(withCount)
            local sum = 0
            for _, c in ipairs(self.chips) do sum = sum + fullWidth(c, withCount) + GAP end
            return sum - GAP
        end
        local withCount = total(true) <= avail
        local small = not withCount and total(false) > avail
        local x = 0
        for _, c in ipairs(self.chips) do
            c.small = small
            c.label:SetShown(not small); c.count:SetShown(not small and withCount and hasCount(c))
            c.icon:ClearAllPoints()
            local w
            if small then
                c.icon:SetPoint("CENTER")
                w = 28
            else
                c.icon:SetPoint("LEFT", 8, 0)
                c.label:ClearAllPoints(); c.label:SetPoint("LEFT", c.icon, "RIGHT", 5, 0)
                c.count:ClearAllPoints(); c.count:SetPoint("LEFT", c.label, "RIGHT", 5, 0)
                w = fullWidth(c, withCount)
            end
            c:SetWidth(w)
            c:ClearAllPoints(); c:SetPoint("LEFT", x, 0)
            x = x + w + GAP
        end
        self.usedWidth = x - GAP
    end
    function bar:Refresh()
        for _, c in ipairs(self.chips) do paint(c) end
    end
    bar:SetScript("OnSizeChanged", function(self) self:Fit() end)
    Theme.OnApply(function() bar:Refresh() end)
    bar:Fit(); bar:Refresh()
    return bar
end

function UI.Divider(parent, role)
    local t = UI.Fill(parent, role or "borderDim", "ARTWORK")
    t:SetHeight(1)
    return t
end

function UI.Header(parent, text)
    local fs = UI.Text(parent, 13, "gold", "LEFT")
    fs:SetText(text)
    return fs
end

-- Square item icon with tooltip
function UI.ItemIcon(parent, size)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetSize(size or 20, size or 20)
    UI.Skin(f, "input", "border")
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetPoint("TOPLEFT", 1, -1)
    f.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    function f:SetItem(item)
        self.item = item
        if item then
            self.tex:SetTexture(ns.Items.Icon(item))
            local info = ns.Items.Info(item)
            local q = info and info.quality
            local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
            if c then self:SetBackdropBorderColor(c.r, c.g, c.b, 1) else self:SetBackdropBorderColor(Theme.Color("border")) end
            self:Show()
        else
            self:Hide()
        end
    end
    f:SetScript("OnEnter", function(self) if self.item then ns.Items.ShowTooltip(self, self.item) end end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnClick", function(self)
        if self.item and IsModifiedClick and IsModifiedClick("CHATLINK") then
            local link = ns.Items.Link(self.item)
            if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
        end
    end)
    return f
end

-- Scrollable content frame with a thin accent scrollbar
function UI.ScrollArea(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    local bar = UI.Fill(scroll, "borderDim", "OVERLAY")
    bar:SetWidth(3)
    local function updateBar()
        local h, ch = scroll:GetHeight() or 1, child:GetHeight() or 1
        if ch <= h + 1 then bar:Hide(); return end
        local size = math.max(20, h * h / ch)
        local pos = (scroll:GetVerticalScroll() or 0) / (ch - h) * (h - size)
        bar:ClearAllPoints()
        bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 6, -pos)
        bar:SetHeight(size)
        bar:Show()
    end
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, child:GetHeight() - self:GetHeight())
        local v = math.min(max, math.max(0, self:GetVerticalScroll() - delta * 40))
        self:SetVerticalScroll(v)
        updateBar()
    end)
    scroll:SetScript("OnSizeChanged", function(self, w) child:SetWidth(w); updateBar() end)
    scroll.child = child
    scroll.UpdateBar = updateBar
    return scroll, child
end

---------------------------------------------------------------------------
-- Slider: UI.Slider(parent, label, min, max, step, get, set, fmt)
-- With a label the slider stacks label/value above the track; without one it
-- is a compact track with the value on the right (for form rows).
---------------------------------------------------------------------------
function UI.Slider(parent, label, minV, maxV, step, get, set, fmt)
    local f = CreateFrame("Frame", nil, parent)
    local compact = label == nil
    f:SetSize(compact and 200 or 300, compact and 20 or 36)
    f.value = UI.Text(f, 11, "text", "RIGHT")
    if compact then
        f.value:SetPoint("RIGHT")
        f.value:SetWidth(42)
    else
        f.label = UI.Text(f, 11, "textDim")
        f.label:SetPoint("TOPLEFT")
        f.label:SetText(label)
        f.value:SetPoint("TOPRIGHT")
    end
    local s = CreateFrame("Slider", nil, f)
    if compact then
        s:SetPoint("LEFT")
        s:SetPoint("RIGHT", f.value, "LEFT", -10, 0)
    else
        s:SetPoint("TOPLEFT", 0, -18)
        s:SetPoint("TOPRIGHT", 0, -18)
    end
    -- dark 4 px track, accent fill, white rectangular knob
    s:SetHeight(16)
    s.track = UI.Fill(s, "sidebar", "BACKGROUND")
    s.track:SetHeight(4)
    s.track:SetPoint("LEFT"); s.track:SetPoint("RIGHT")
    s.fill = UI.Fill(s, "accent", "BORDER")
    s.fill:SetHeight(4)
    s.fill:SetPoint("LEFT")
    s:SetOrientation("HORIZONTAL")
    s:SetThumbTexture(WHITE)
    local thumb = s:GetThumbTexture()
    thumb:SetSize(7, 16)
    thumb:SetVertexColor(0.95, 0.95, 0.95, 1)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step or 1)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)
    local function show(v)
        f.value:SetText(fmt and fmt(v) or (step and step < 1 and ("%.2f"):format(v) or tostring(math.floor(v + 0.5))))
        local w = s:GetWidth() or 0
        s.fill:SetWidth(math.max(1, w * (v - minV) / math.max(0.0001, maxV - minV)))
    end
    local updating = false
    s:SetScript("OnValueChanged", function(_, v)
        if step then v = math.floor(v / step + 0.5) * step end
        show(v)
        if not updating then ns.Safe(set, v) end
    end)
    s:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(math.min(maxV, math.max(minV, self:GetValue() + delta * (step or 1))))
    end)
    s:SetScript("OnSizeChanged", function() show(s:GetValue() or minV) end)
    function f:Refresh()
        updating = true
        local v = get() or minV
        s:SetValue(v)
        show(v)
        updating = false
    end
    f.slider = s
    f:Refresh()
    return f
end

---------------------------------------------------------------------------
-- Color picker (works with the old and the new ColorPickerFrame API)
---------------------------------------------------------------------------
function UI.PickColor(r, g, b, a, hasAlpha, callback)
    local function current()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = a
        if hasAlpha then
            if ColorPickerFrame.GetColorAlpha then na = ColorPickerFrame:GetColorAlpha()
            elseif OpacitySliderFrame then na = 1 - OpacitySliderFrame:GetValue() end
        end
        return nr, ng, nb, na
    end
    local function changed() ns.Safe(callback, current()) end
    local function cancel() ns.Safe(callback, r, g, b, a) end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, opacity = a, hasOpacity = hasAlpha,
            swatchFunc = changed, opacityFunc = changed, cancelFunc = cancel,
        })
    else
        ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = changed, changed, cancel
        ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = hasAlpha, hasAlpha and (1 - (a or 1)) or nil
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

-- Color swatch; with a label the label sits to the right
function UI.ColorSwatch(parent, label, get, set, hasAlpha)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(label and 150 or 34, 20)
    f.box = UI.Panel(f, "input", "border")
    f.box:SetSize(34, 18)
    f.box:SetPoint(label and "LEFT" or "RIGHT")
    f.color = f.box:CreateTexture(nil, "ARTWORK")
    f.color:SetTexture(WHITE)
    f.color:SetPoint("TOPLEFT", 3, -3)
    f.color:SetPoint("BOTTOMRIGHT", -3, 3)
    if label then
        f.label = UI.Text(f, 12, "textDim")
        f.label:SetPoint("LEFT", f.box, "RIGHT", 8, 0)
        f.label:SetText(label)
    end
    function f:Refresh()
        local r, g, b, a = get()
        self.color:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    end
    f:SetScript("OnEnter", function(self) self.box:SetBackdropBorderColor(Theme.Color("accent")) end)
    f:SetScript("OnLeave", function(self) self.box:SetBackdropBorderColor(Theme.Color("border")) end)
    f:SetScript("OnClick", function(self)
        local r, g, b, a = get()
        UI.PickColor(r or 1, g or 1, b or 1, a or 1, hasAlpha, function(nr, ng, nb, na)
            ns.Safe(set, nr, ng, nb, na)
            self:Refresh()
        end)
    end)
    f:Refresh()
    return f
end

---------------------------------------------------------------------------
-- Sub tabs inside a page: white active tab with accent underline
---------------------------------------------------------------------------
function UI.SubTabs(parent, tabs, onSelect)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(28)
    bar.buttons = {}
    local x = 0
    for i, tab in ipairs(tabs) do
        local b = CreateFrame("Button", nil, bar)
        b:SetHeight(28)
        b.text = UI.Text(b, 12, "muted", "CENTER")
        b.text:SetPoint("CENTER", 0, 1)
        b.text:SetText(tab.iconOnly and "" or tab.title)
        local w = math.max(60, (b.text:GetStringWidth() or 0) + 28, #tab.title * 6.5 + 28)
        -- icon-only tab (little room): the title shows in the tooltip
        if tab.iconOnly and tab.icon then
            b.icon = UI.Icon(b, tab.icon, 14, "muted")
            b.icon:SetPoint("CENTER", 0, 1)
            b.tipTitle = tab.title
            w = 40
        end
        b:SetWidth(w)
        b:SetPoint("LEFT", x, 0)
        x = x + w + 6
        b.def, b.natural = tab, w
        b.compact = tab.iconOnly and w or math.max(48, math.min(w, (b.text:GetStringWidth() or (#tab.title * 6)) + 14))
        b.line = UI.Fill(b, "accent", "ARTWORK")
        b.line:SetPoint("BOTTOMLEFT", 6, 0); b.line:SetPoint("BOTTOMRIGHT", -6, 0); b.line:SetHeight(2)
        b:SetScript("OnClick", function() bar:Select(tab.key) end)
        local function tint(self, role)
            self.text:SetTextColor(Theme.Color(role))
            if self.icon then self.icon:SetVertexColor(Theme.Color(role)) end
        end
        b.tint = tint
        b:SetScript("OnEnter", function(self)
            if bar.current ~= self.key then tint(self, "textDim") end
            if self.tipTitle then UI.Tooltip(self, self.tipTitle) end
        end)
        b:SetScript("OnLeave", function(self)
            if bar.current ~= self.key then tint(self, "muted") end
            if self.tipTitle then GameTooltip:Hide() end
        end)
        b.key = tab.key
        -- search hits in this tab (small accent number, top right)
        b.hits = UI.Text(b, 10, "accent", "LEFT", nil, true)
        b.hits:SetPoint("LEFT", b.text, "RIGHT", 4, 4)
        b.hits:Hide()
        bar.buttons[i] = b
    end
    -- n = number of search hits in that tab (nil hides it)
    function bar:SetHits(key, n)
        for _, b in ipairs(self.buttons) do
            if b.key == key then
                b.hits:SetShown(n ~= nil and n > 0)
                b.hits:SetText(n and n > 0 and tostring(n) or "")
            end
        end
    end
    local divider = UI.Divider(bar)
    divider:SetPoint("BOTTOMLEFT"); divider:SetPoint("BOTTOMRIGHT")
    -- little room: narrower tabs first, then tabs with an icon show only the icon
    -- (title in the tooltip). Returns the width the tabs take.
    function bar:Fit(maxW)
        local function apply(mode)
            local x = 0
            for _, b in ipairs(self.buttons) do
                local def = b.def
                local iconOnly = def.iconOnly or (mode == "icons" and def.icon ~= nil)
                local w
                if iconOnly then
                    if not b.icon then b.icon = UI.Icon(b, def.icon, 14, "muted"); b.icon:SetPoint("CENTER", 0, 1) end
                    b.icon:Show()
                    b.text:SetText("")
                    b.tipTitle = def.title
                    w = 40
                else
                    if b.icon then b.icon:Hide() end
                    b.text:SetText(def.title)
                    b.tipTitle = nil
                    w = (mode == "natural") and b.natural or b.compact
                end
                b:SetWidth(w)
                b:ClearAllPoints()
                b:SetPoint("LEFT", x, 0)
                x = x + w + 6
            end
            return x - 6
        end
        local used
        for _, mode in ipairs({ "natural", "compact", "icons" }) do
            used = apply(mode)
            self.mode = mode
            if used <= maxW then break end
        end
        for _, b in ipairs(self.buttons) do b.tint(b, b.key == self.current and "text" or "muted") end
        return used
    end
    function bar:Select(key)
        self.current = key
        for _, b in ipairs(self.buttons) do
            local on = b.key == key
            b.line:SetShown(on)
            b.tint(b, on and "text" or "muted")
        end
        ns.Safe(onSelect, key)
    end
    Theme.OnApply(function() if bar.current then
        for _, b in ipairs(bar.buttons) do b.tint(b, b.key == bar.current and "text" or "muted") end
    end end)
    return bar
end

---------------------------------------------------------------------------
-- Toolbar: a row of buttons at the top of a page
---------------------------------------------------------------------------
function UI.Toolbar(parent, buttons)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(26)
    bar.buttons = {}
    for i, def in ipairs(buttons) do
        local b = UI.Button(bar, def.text, def.width or 110, 26, def.onClick, def.icon)
        if def.text == "" and b.icon then b.icon:ClearAllPoints(); b.icon:SetPoint("CENTER") end
        if def.tip then b.tip = { def.tip } end
        b.fullW = def.width or 110
        bar.buttons[i] = b
    end
    -- too narrow: buttons with an icon shrink to the icon (last ones first), the name moves into the tooltip
    function bar:Fit()
        local avail = self:GetWidth() or 0
        if avail <= 0 then avail = 1e9 end
        local total = 0
        for _, b in ipairs(self.buttons) do total = total + b.fullW + 8 end
        local small = {}
        for i = #self.buttons, 1, -1 do
            if total - 8 <= avail then break end
            local b = self.buttons[i]
            if b.icon then small[i] = true; total = total - b.fullW + 34 end
        end
        local x = 0
        for i, b in ipairs(self.buttons) do
            if b.label and not b.fullText then b.fullText = b.label:GetText() end
            local s = small[i]
            b:SetWidth(s and 34 or b.fullW)
            b.label:SetShown(not s)
            if b.icon then
                b.icon:ClearAllPoints()
                if s or (b.fullText or "") == "" then b.icon:SetPoint("CENTER") else b.icon:SetPoint("RIGHT", b.label, "LEFT", -6, 0) end
            end
            b.tipTitle = s and b.fullText or nil
            if s and not b.tip then b.tip = {} end
            b:ClearAllPoints()
            b:SetPoint("LEFT", x, 0)
            x = x + (s and 34 or b.fullW) + 8
        end
    end
    bar:SetScript("OnSizeChanged", function(self) self:Fit() end)
    bar:Fit()
    return bar
end

---------------------------------------------------------------------------
-- Windows remember where they were dragged (moved by their own title area,
-- not in the global "move elements" mode).
--   UI.RememberPosition(frame, key, default { point, relPoint, x, y })
---------------------------------------------------------------------------
local function windowPositions()
    local st = ns.Database.Settings()
    st.windowPos = st.windowPos or {}
    return st.windowPos
end
function UI.HasWindowPosition(key) return windowPositions()[key] ~= nil end
function UI.RememberPosition(frame, key, default)
    local pos = windowPositions()[key]
    -- older versions kept these windows in the move-elements mode
    local m = ns.Database.Settings().movers
    if not pos and m and m.pos and m.pos[key] then pos = m.pos[key]; windowPositions()[key] = pos end
    local p = pos or default or { "CENTER", "CENTER", 0, 0 }
    frame:ClearAllPoints()
    frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    frame:HookScript("OnDragStop", function(self)
        local left, top = self:GetLeft(), self:GetTop()
        if not left or not top then return end
        windowPositions()[key] = { "TOPLEFT", "BOTTOMLEFT", left, top }
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end)
end
function UI.ResetWindowPosition(frame, key, default)
    windowPositions()[key] = nil
    local p = default or { "CENTER", "CENTER", 0, 0 }
    frame:ClearAllPoints()
    frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

---------------------------------------------------------------------------
-- Resizable windows: corner grip, size bounds, size saved per key.
--   UI.Resizable(frame, "council", minW, minH, maxW, maxH, onResize)
---------------------------------------------------------------------------
function UI.Resizable(frame, key, minW, minH, maxW, maxH, onResize)
    local st = ns.Database.Settings()
    st.sizes = st.sizes or {}
    local saved = st.sizes[key]
    if saved and saved[1] and saved[2] then
        frame:SetSize(math.max(minW, math.min(maxW, saved[1])), math.max(minH, math.min(maxH, saved[2])))
    end
    frame:SetResizable(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(minW, minH, maxW, maxH)
    elseif frame.SetMinResize then frame:SetMinResize(minW, minH); if frame.SetMaxResize then frame:SetMaxResize(maxW, maxH) end end
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        st.sizes[key] = { math.floor(frame:GetWidth() + 0.5), math.floor(frame:GetHeight() + 0.5) }
        if onResize then ns.Safe(onResize, frame) end
    end)
    grip:SetScript("OnEnter", function(self) UI.Tooltip(self, ns.L.RESIZE_TIP) end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- double-click the grip: back to the default size
    grip:SetScript("OnDoubleClick", function()
        st.sizes[key] = nil
        if frame.defaultSize then frame:SetSize(frame.defaultSize[1], frame.defaultSize[2]) end
        if onResize then ns.Safe(onResize, frame) end
    end)
    if onResize then
        frame:HookScript("OnSizeChanged", function() ns.Debounce("resize-" .. key, 0.05, function() ns.Safe(onResize, frame) end) end)
    end
    frame.grip = grip
    return grip
end

---------------------------------------------------------------------------
-- Settings forms: collapsible accent sections with two columns of row cards.
--   local form = UI.Form(parent)
--   local s = form:Section("Title")
--   s:Toggle(label, get, set, { col = 1|2|0, tip = , show = fn })
--   s:Slider(label, min, max, step, get, set, { fmt = fn, ... })
--   s:Dropdown(label, items, get, set, opts)    s:Segment(label, options, get, set, opts)
--   s:Color(label, get, set, opts)              s:Edit(label, get, set, opts)
--   s:Buttons({ {text, fn}, ... }, opts)          s:Note(text, opts)
--   form:Refresh()  form:Layout()
---------------------------------------------------------------------------
-- Layout: every section is a card – accent title with a chevron on
-- the right, rows separated by thin lines, label left, control right. Cards flow
-- into two columns when there is room; sections with custom content span both.
local ROW_H, ROW_GAP, CONTROL_W, HEAD_H, CARD_GAP = 36, 4, 180, 40, 12

-- every form, with the page it was built on (settings search)
UI.forms = {}

function UI.Form(parent)
    local scroll, body = UI.ScrollArea(parent)
    local form = { scroll = scroll, body = body, sections = {}, page = ns.Window and ns.Window.building }
    UI.forms[#UI.forms + 1] = form

    local function newRow(label, opts)
        local row = CreateFrame("Frame", nil, body)
        row:SetHeight(opts.height or ROW_H)
        row:SetFrameLevel(body:GetFrameLevel() + 3)
        row.opts = opts
        row.labelText = label
        row.hover = UI.Fill(row, "hover", "BACKGROUND")
        row.hover:SetPoint("TOPLEFT", 1, 0); row.hover:SetPoint("BOTTOMRIGHT", -1, 0)
        row.hover:Hide()
        row:SetScript("OnEnter", function(self) self.hover:Show() end)
        row:SetScript("OnLeave", function(self) self.hover:Hide() end)
        if label then
            row.label = UI.Text(row, 12, "text")
            row.label:SetPoint("LEFT", 16, 0)
            row.label:SetPoint("RIGHT", row, "RIGHT", -(opts.labelRight or (CONTROL_W + 24)), 0)
            row.label:SetText(label)
        end
        row:EnableMouse(true)
        if opts.tip then
            row:SetScript("OnEnter", function(self) self.hover:Show(); UI.Tooltip(self, label, { opts.tip }) end)
            row:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip:Hide() end)
        end
        return row
    end

    function form:Section(title, opts)
        opts = opts or {}
        local section = { rows = {}, collapsed = opts.collapsed or false, wide = opts.wide, grid = opts.grid,
            show = opts.show, title = title or "", locked = opts.locked, lockTip = opts.lockTip }
        section.card = UI.Panel(body, "panel", "borderDim")
        section.card:SetFrameLevel(body:GetFrameLevel() + 1)
        local head = CreateFrame("Button", nil, body)
        head:SetFrameLevel(body:GetFrameLevel() + 3)
        head:SetHeight(HEAD_H)
        -- heading: title in the accent color, chevron on the right, line below
        head.text = UI.Text(head, 13, "accent", nil, nil, true)
        head.text:SetPoint("LEFT", 16, 0)
        head.text:SetText(title or "")
        head.chevron = UI.Icon(head, "chevron-down", 12, "muted")
        head.chevron:SetPoint("RIGHT", -14, 0)
        -- read-only card (opts.locked): a small lock left of the chevron
        head.lock = UI.Icon(head, "lock", 12, "muted")
        head.lock:SetPoint("RIGHT", head.chevron, "LEFT", -8, 0)
        head.lock:Hide()
        head.hover = UI.Fill(head, "hover", "BACKGROUND")
        head.hover:SetPoint("TOPLEFT", 1, -1); head.hover:SetPoint("BOTTOMRIGHT", -1, 0)
        head.hover:Hide()
        head:SetScript("OnEnter", function(self) self.hover:Show() end)
        head:SetScript("OnLeave", function(self) self.hover:Hide() end)
        head.line = UI.Fill(head, "borderDim", "ARTWORK")
        head.line:SetHeight(1)
        head.line:SetPoint("BOTTOMLEFT", 12, 0); head.line:SetPoint("BOTTOMRIGHT", -12, 0)
        head:SetScript("OnClick", function()
            section.collapsed = not section.collapsed
            Theme.SetIcon(head.chevron, section.collapsed and "chevron-right" or "chevron-down")
            form:Layout()
        end)
        section.head = head
        self.sections[#self.sections + 1] = section

        local function add(row, control, opts2)
            row.control = control
            row.col = opts2.col or 1
            if not row.divider then
                row.divider = UI.Fill(row, "borderDim", "ARTWORK")
                row.divider:SetHeight(1)
                row.divider:SetPoint("BOTTOMLEFT", 12, 0); row.divider:SetPoint("BOTTOMRIGHT", -12, 0)
            end
            section.rows[#section.rows + 1] = row
            return control, row
        end

        function section:Toggle(label, get, set, o)
            o = o or {}
            local row = newRow(label, o)
            local t = UI.Toggle(row, get, function(v) ns.Safe(set, v); form:Refresh() end)
            t:SetPoint("RIGHT", -14, 0)
            row:EnableMouse(true)
            row:SetScript("OnMouseUp", function() t:Click() end)
            return add(row, t, o)
        end
        function section:Slider(label, minV, maxV, step, get, set, o)
            o = o or {}
            local row = newRow(label, o)
            local s = UI.Slider(row, nil, minV, maxV, step, get, set, o.fmt)
            s:SetWidth(CONTROL_W)
            s:SetPoint("RIGHT", -14, 0)
            return add(row, s, o)
        end
        function section:Dropdown(label, items, get, set, o)
            o = o or {}
            local row = newRow(label, o)
            local d = UI.Dropdown(row, o.width or CONTROL_W, items, get, function(v) ns.Safe(set, v); form:Refresh() end)
            d:SetPoint("RIGHT", -14, 0)
            return add(row, d, o)
        end
        function section:Segment(label, options, get, set, o)
            o = o or {}
            o.labelRight = (o.width or 280) + 24
            local row = newRow(label, o)
            local sgm = UI.Segmented(row, o.width or 280, options, get, function(v) ns.Safe(set, v); form:Refresh() end)
            sgm:SetPoint("RIGHT", -14, 0)
            return add(row, sgm, o)
        end
        function section:Color(label, get, set, o)
            o = o or {}
            o.labelRight = 70
            local row = newRow(label, o)
            local c = UI.ColorSwatch(row, nil, get, set, o.alpha)
            c:SetPoint("RIGHT", -14, 0)
            return add(row, c, o)
        end
        function section:Edit(label, get, set, o)
            o = o or {}
            local row = newRow(label, o)
            local e = UI.EditBox(row, o.width or CONTROL_W, 24, o.placeholder)
            e:SetPoint("RIGHT", -14, 0)
            local function commit(self)
                local text = (self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
                ns.Safe(set, text)
            end
            e.onEnter, e.onCommit = commit, commit
            e.Refresh = function(self) if not self:HasFocus() then self:SetText(get() or "") end end
            return add(row, e, o)
        end
        -- read-only value: label left, text right (clipped); o.tipFn = dynamic tooltip lines
        function section:Info(label, valueFn, o)
            o = o or {}
            local row = newRow(label, o)
            local lw = o.labelWidth or 130
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", 16, 0)
            row.label:SetWidth(lw)
            row.label:SetTextColor(Theme.Color("textDim"))
            local value = UI.Text(row, 12, "text", "RIGHT")
            value:SetPoint("LEFT", row, "LEFT", 16 + lw + 10, 0)
            value:SetPoint("RIGHT", -14, 0)
            row.value = value
            if o.tipFn then
                row:SetScript("OnEnter", function(self)
                    self.hover:Show()
                    local lines = {}
                    for line in tostring(o.tipFn() or ""):gmatch("[^\n]+") do lines[#lines + 1] = line end
                    UI.Tooltip(self, label, lines)
                end)
                row:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip:Hide() end)
            end
            local control = { Refresh = function() value:SetText(ns.Try(valueFn) or "") end }
            add(row, control, o)
            control.Refresh()
            return value, row
        end
        function section:Buttons(list, o)
            o = o or {}
            o.col = o.col or 0
            local row = CreateFrame("Frame", nil, body)
            row:SetFrameLevel(body:GetFrameLevel() + 3)
            row:SetHeight(44)
            row.opts = o
            row.buttons = {}
            for _, def in ipairs(list) do
                local b = UI.Button(row, def[1], def.width or 140, 28, def[2], def.icon)
                b.searchLabel = def[1]
                if def.tip then b.tip = { def.tip } end
                row.buttons[#row.buttons + 1] = b
            end
            -- buttons wrap into more lines when the card is narrow
            function row:Flow(width)
                local x, y = 14, 8
                for _, b in ipairs(self.buttons) do
                    local w = b:GetWidth()
                    if x > 14 and x + w > width - 14 then x, y = 14, y + 34 end
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", x, -y)
                    x = x + w + 8
                end
                self:SetHeight(y + 36)
            end
            return add(row, nil, o)
        end
        function section:Note(text, o)
            o = o or {}
            o.col = o.col or 0
            local row = CreateFrame("Frame", nil, body)
            row:SetFrameLevel(body:GetFrameLevel() + 3)
            row.opts = o
            row.text = UI.Text(row, 11, "muted")
            row.text:SetPoint("TOPLEFT", 14, -8)
            row.text:SetPoint("TOPRIGHT", -14, -8)
            row.text:SetWordWrap(true)
            row.text:SetJustifyV("TOP")
            row.text:SetText(text)
            row.noteText = text
            row:SetHeight((o.height or 20) + 12)
            return add(row, nil, o)
        end
        -- any frame; it is sized to the column width
        function section:Custom(frame, height, o)
            o = o or {}
            frame:SetParent(body)
            frame:SetFrameLevel(body:GetFrameLevel() + 3)
            local row = frame
            row.opts = o
            row:SetHeight(height)
            row.custom = true
            section.wide = true
            return add(row, nil, o)
        end
        return section
    end

    -- Read-only rows: Section(title, { locked = fn, lockTip = text }) or a row's
    -- opts.locked / opts.lockTip. A locked row is dimmed and covered by a shield
    -- that explains who may change it (never a silent, dead control).
    local function applyLocks(section, rows)
        local sectionLocked = section.locked and section.locked() or false
        if section.head.lock then section.head.lock:SetShown(sectionLocked) end
        for _, row in ipairs(rows) do
            local o = row.opts or {}
            local locked = sectionLocked and not o.unlocked or (o.locked and o.locked()) or false
            if locked and not row.shield then
                local shield = CreateFrame("Button", nil, row)
                shield:SetAllPoints()
                shield:SetFrameLevel(row:GetFrameLevel() + 20)
                shield:SetScript("OnEnter", function(self)
                    if row.hover then row.hover:Show() end
                    UI.Tooltip(self, row.labelText or row.searchTitle or section.title, { self.tipText })
                end)
                shield:SetScript("OnLeave", function() if row.hover then row.hover:Hide() end; GameTooltip:Hide() end)
                row.shield = shield
            end
            if row.shield then
                row.shield.tipText = o.lockTip or section.lockTip or ns.L.LOCKED_TIP
                row.shield:SetShown(locked)
            end
            local target = (row.control and row.control ~= row) and row.control or nil
            if target and target.SetAlpha then target:SetAlpha(locked and 0.4 or 1)
            elseif row.custom or row.buttons then
                for _, b in ipairs(row.buttons or {}) do b:SetAlpha(locked and 0.4 or 1) end
                if row.custom then row:SetAlpha(locked and 0.55 or 1) end
            end
        end
    end

    function form:Layout()
        local width = body:GetWidth() or 1000
        local two = width >= 700
        local colW = two and math.floor((width - CARD_GAP) / 2) or width
        local colY = { 0, 0 }
        for _, section in ipairs(self.sections) do
            -- rows that are shown, stacked inside the card
            local visibleRows = {}
            local filtering = self.query ~= nil
            for _, row in ipairs(section.rows) do
                local visible = (filtering or not section.collapsed) and (not row.opts.show or row.opts.show()) and not row.filteredOut
                row:SetShown(visible)
                if visible then visibleRows[#visibleRows + 1] = row end
            end
            applyLocks(section, visibleRows)
            -- a search hides cards without a match; opts.show hides a whole card
            local skip = (filtering and #visibleRows == 0) or (section.show and not section.show())
            if skip then for _, row in ipairs(section.rows) do row:Hide() end end
            section.card:SetShown(not skip)
            section.head:SetShown(not skip)
            if skip then section.skipped = true else section.skipped = nil end
            if not skip then
                local wide = section.wide or not two
                local w = wide and width or colW
                local x, top
                if wide then
                    top = math.max(colY[1], colY[2])
                    x = 0
                else
                    local c = colY[1] <= colY[2] and 1 or 2
                    top, x = colY[c], (c - 1) * (colW + CARD_GAP)
                    section.col = c
                end
                local inner = HEAD_H
                -- grid cards: rows with col 1/2 side by side when the card is wide enough
                local gridded = section.grid and w >= 640
                local half = math.floor((w - 2) / 2)
                local i = 1
                while i <= #visibleRows do
                    local row = visibleRows[i]
                    local nextRow = visibleRows[i + 1]
                    if gridded and (row.opts.col or 1) ~= 0 and nextRow and (nextRow.opts.col or 1) ~= 0 then
                        local h = math.max(row:GetHeight(), nextRow:GetHeight())
                        for k, r in ipairs({ row, nextRow }) do
                            r:ClearAllPoints()
                            r:SetPoint("TOPLEFT", body, "TOPLEFT", x + 1 + (k - 1) * half, -(top + inner))
                            r.layoutY = top + inner
                            r:SetWidth(half)
                            if r.divider then r.divider:SetShown(i + 1 < #visibleRows) end
                        end
                        inner = inner + h
                        i = i + 2
                    else
                        if row.Flow then row:Flow(w - 2) end
                        row:ClearAllPoints()
                        row:SetPoint("TOPLEFT", body, "TOPLEFT", x + 1, -(top + inner))
                        row.layoutY = top + inner
                        row:SetWidth(w - 2)
                        if row.divider then row.divider:SetShown(i < #visibleRows) end
                        inner = inner + row:GetHeight()
                        i = i + 1
                    end
                end
                local h = inner + (#visibleRows > 0 and 4 or 0)
                section.card:ClearAllPoints()
                section.card:SetPoint("TOPLEFT", body, "TOPLEFT", x, -top)
                section.layoutY = top
                section.card:SetSize(w, h)
                section.head:ClearAllPoints()
                section.head:SetPoint("TOPLEFT", body, "TOPLEFT", x, -top)
                section.head:SetWidth(w)
                -- very long titles are clipped before the chevron
                local ht = section.head.text
                local tw = (ht.GetUnboundedStringWidth and ht:GetUnboundedStringWidth()) or ht:GetStringWidth() or 0
                if tw > w - 80 then ht:SetWidth(math.max(40, w - 80)); ht.clipped = true
                elseif ht.clipped then ht:SetWidth(tw + 2) end
                section.head.line:SetShown(#visibleRows > 0)
                if wide then
                    colY[1], colY[2] = top + h + CARD_GAP, top + h + CARD_GAP
                else
                    colY[section.col] = top + h + CARD_GAP
                end
            end
        end
        local shown = false
        for _, section in ipairs(self.sections) do if not section.skipped then shown = true end end
        if self.query and not shown then
            if not self.empty then
                self.empty = UI.Empty(body, 420)
                self.empty:SetPoint("TOP", 0, -40)
            end
            UI.EmptySearch(self.empty, self.queryText)
            self.empty:Show()
        elseif self.empty then
            self.empty:Hide()
        end
        body:SetHeight(math.max(colY[1], colY[2]) + 8)
        scroll.UpdateBar()
    end

    -- text a row is found by: its label, tooltip, note text or button texts
    function form.RowText(row)
        local parts = { row.searchText or "" }
        if row.label then parts[#parts + 1] = row.label:GetText() or "" end
        if row.text and row.text.GetText then parts[#parts + 1] = row.text:GetText() or "" end
        if row.opts and type(row.opts.tip) == "string" then parts[#parts + 1] = row.opts.tip end
        for _, b in ipairs(row.buttons or {}) do parts[#parts + 1] = b.searchLabel or "" end
        return table.concat(parts, " ")
    end

    -- "jump to": the row (or card) with this label – card opened, scrolled into view, flashed
    function form:JumpTo(label)
        if not label then return false end
        local hit, hitSection
        for _, section in ipairs(self.sections) do
            if section.title == label then hit, hitSection = section.card, section end
            for _, row in ipairs(section.rows) do
                local match = row.labelText == label or row.searchTitle == label
                for _, b in ipairs(row.buttons or {}) do if b.searchLabel == label then match = true end end
                if match and not hit then hit, hitSection = row, section end
            end
            if hit then break end
        end
        if not hit then return false end
        if hitSection.collapsed then
            hitSection.collapsed = false
            Theme.SetIcon(hitSection.head.chevron, "chevron-down")
        end
        self:Layout()
        local y = (hit == hitSection.card) and (hitSection.layoutY or 0) or (hit.layoutY or 0)
        local max = math.max(0, (body:GetHeight() or 0) - (scroll:GetHeight() or 0))
        scroll:SetVerticalScroll(math.max(0, math.min(max, y - 60)))
        scroll.UpdateBar()
        if not hit.flash then
            hit.flash = CreateFrame("Frame", nil, hit, "BackdropTemplate")
            hit.flash:SetPoint("TOPLEFT", 2, 0); hit.flash:SetPoint("BOTTOMRIGHT", -2, 0)
            hit.flash:SetFrameLevel(hit:GetFrameLevel() + 6)
            UI.Skin(hit.flash, "selected", "accent")
            hit.flash:SetBackdropColor(Theme.Color("accent"))
            local r, g, b = Theme.Color("accent")
            hit.flash:SetBackdropColor(r, g, b, 0.14)
            hit.flash:Hide()
        end
        UI.Flash(hit.flash, true)
        local pin = UI.Pin(hit)
        pin:Hide()
        local token = {}
        self.markToken = token
        ns.After(UI.FLASH_TIME, function()
            if self.markToken ~= token then return end
            pin:Show()
        end)
        if ns.Window.SetMark then
            ns.Window.SetMark(function()
                self.markToken = nil
                pin:Hide()
                if hit.flash.flashAnim then hit.flash.flashAnim:Stop() end
                hit.flash:Hide()
            end)
        end
        return true
    end

    -- Enter in the page search: the first visible match flashes
    function form:JumpFirst()
        local f = self.firstHit
        if not f then return false end
        if f.card then return self:JumpTo(f.title) end
        return self:JumpTo(f.labelText or f.searchTitle or (f.buttons and f.buttons[1] and f.buttons[1].searchLabel))
    end

    -- page search: nothing is hidden – matching rows (and card titles) are marked,
    -- cards with a match open, the view scrolls to the first match. Returns the number of hits.
    function form:Filter(query)
        local q = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        local hq = q ~= "" and query or nil
        self.query = nil
        self.queryText = query
        local hits, first = 0, nil
        for _, section in ipairs(self.sections) do
            local title = section.title
            local whole = hq and ns.SearchMatch(section.title, q)
            section.head.text:SetText(hq and ns.Highlight(title, hq) or title)
            local any = whole
            for _, row in ipairs(section.rows) do
                row.filteredOut = nil
                local own = hq and ns.SearchMatch(form.RowText(row), q) or false
                local visible = not (row.opts.show and not row.opts.show())
                if own and visible then
                    hits = hits + 1
                    any = true
                    first = first or row
                end
                if row.label and row.labelText then row.label:SetText(hq and ns.Highlight(row.labelText, hq) or row.labelText) end
                if row.noteText then row.text:SetText(hq and ns.Highlight(row.noteText, hq) or row.noteText) end
                for _, b in ipairs(row.buttons or {}) do
                    if b.searchLabel then b:SetText(hq and ns.Highlight(b.searchLabel, hq) or b.searchLabel) end
                end
                if row.Highlight then ns.Safe(row.Highlight, row, hq) end
                if own and not row.hitBg then
                    row.hitBg = UI.Fill(row, "accent", "BACKGROUND")
                    row.hitBg:SetPoint("TOPLEFT", 4, -2); row.hitBg:SetPoint("BOTTOMRIGHT", -4, 2)
                    row.hitBg:SetAlpha(0.14)
                    row.hitBar = UI.Fill(row, "accent", "ARTWORK")
                    row.hitBar:SetPoint("TOPLEFT", 4, -2); row.hitBar:SetPoint("BOTTOMLEFT", 4, 2); row.hitBar:SetWidth(2)
                end
                if row.hitBg then row.hitBg:SetShown(own); row.hitBar:SetShown(own) end
            end
            if whole and not first then hits = hits + 1; first = section end
            -- a closed card with a match opens
            if hq and any and section.collapsed then
                section.collapsed = false
                Theme.SetIcon(section.head.chevron, "chevron-down")
            end
        end
        self.hits, self.firstHit = hits, first
        self:Layout()
        if first then
            local y = first.card and (first.layoutY or 0) or (first.layoutY or 0)
            local max = math.max(0, (body:GetHeight() or 0) - (scroll:GetHeight() or 0))
            scroll:SetVerticalScroll(math.max(0, math.min(max, y - 60)))
            scroll.UpdateBar()
        elseif not hq then
            scroll:SetVerticalScroll(0)
            scroll.UpdateBar()
        end
        return hits
    end

    scroll:HookScript("OnSizeChanged", function()
        local w = math.floor(body:GetWidth() or 0)
        if w ~= form.lastWidth then
            form.lastWidth = w
            ns.Debounce(tostring(form) .. "-layout", 0.05, function() form:Layout() end)
        end
    end)

    function form:Refresh()
        for _, section in ipairs(self.sections) do
            for _, row in ipairs(section.rows) do
                if row.control and row.control.Refresh then row.control:Refresh() end
            end
        end
        self:Layout()
    end

    return form
end

---------------------------------------------------------------------------
-- Context menu (right-click), opened at the cursor. Two levels.
--   UI.ContextMenu({
--     { title = "Name" },                                  -- header line
--     { text = "Award", func = fn, disabled = bool, checked = bool, color = role },
--     { divider = true },
--     { text = "Award for ...", submenu = { ... } },
--   })
---------------------------------------------------------------------------
local ctx = {}
local CTX_ROW = 22

local function ctxLevel(level)
    if ctx[level] then return ctx[level] end
    local m = UI.Panel(UIParent, "input", "border")
    m:SetFrameStrata("FULLSCREEN_DIALOG")
    m:SetFrameLevel(10 + level * 10)
    m:SetClampedToScreen(true)
    m:EnableMouse(true)
    m.rows = {}
    m:Hide()
    ctx[level] = m
    if level == 1 then
        m.catcher = CreateFrame("Button", nil, UIParent)
        m.catcher:SetAllPoints(UIParent)
        m.catcher:SetFrameStrata("FULLSCREEN")
        m.catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        m.catcher:SetScript("OnClick", function() UI.CloseContextMenu() end)
        m.catcher:Hide()
    end
    return m
end

function UI.CloseContextMenu()
    for _, m in pairs(ctx) do m:Hide() end
    if ctx[1] and ctx[1].catcher then ctx[1].catcher:Hide() end
end

local function ctxRow(m, i)
    local b = m.rows[i]
    if b then return b end
    b = CreateFrame("Button", nil, m)
    b:SetHeight(CTX_ROW)
    b.hl = UI.Fill(b, "selected", "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.check = UI.Icon(b, "badge-check", 12, "accent")
    b.check:SetPoint("LEFT", 8, 0)
    b.text = UI.Text(b, 12, "textDim")
    b.text:SetPoint("LEFT", 26, 0)
    b.text:SetPoint("RIGHT", -22, 0)
    b.arrow = UI.Icon(b, "chevron-right", 10, "muted")
    b.arrow:SetPoint("RIGHT", -8, 0)
    b.line = UI.Fill(b, "borderDim", "ARTWORK")
    b.line:SetHeight(1)
    b.line:SetPoint("LEFT", 6, 0)
    b.line:SetPoint("RIGHT", -6, 0)
    m.rows[i] = b
    return b
end

local function openLevel(level, entries, anchor)
    local m = ctxLevel(level)
    for l = level + 1, #ctx do ctx[l]:Hide() end
    local y, width = -4, 160
    local i = 0
    for _, e in ipairs(entries) do
        i = i + 1
        local b = ctxRow(m, i)
        local h = e.divider and 7 or CTX_ROW
        b:SetHeight(h)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 1, y)
        b:SetPoint("TOPRIGHT", -1, y)
        y = y - h
        b.line:SetShown(e.divider == true)
        b.text:SetShown(not e.divider)
        b.check:SetShown(e.checked == true)
        b.arrow:SetShown(e.submenu ~= nil)
        b.hl:SetShown(not e.divider and not e.title and not e.disabled)
        if not e.divider then
            b.text:SetText(e.title or e.text or "")
            local role = e.title and "gold" or (e.disabled and "muted" or (e.color or "textDim"))
            b.text:SetTextColor(Theme.Color(role))
            b.text:SetPoint("LEFT", e.title and 10 or 26, 0)
            width = math.max(width, (b.text:GetStringWidth() or 0) + (e.title and 30 or 60))
        end
        b:SetScript("OnEnter", function(self)
            if e.submenu and not e.disabled then openLevel(level + 1, e.submenu, self)
            elseif ctx[level + 1] then for l = level + 1, #ctx do ctx[l]:Hide() end end
            if e.tip then UI.Tooltip(self, e.text, { e.tip }) end
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self)
            if e.divider or e.title or e.disabled then return end
            if e.submenu then openLevel(level + 1, e.submenu, self); return end
            UI.CloseContextMenu()
            if e.func then ns.Safe(e.func) end
        end)
        b:Show()
    end
    for j = i + 1, #m.rows do m.rows[j]:Hide() end
    m:SetSize(math.min(320, width), -y + 4)
    m:ClearAllPoints()
    if anchor then
        m:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 2, 4)
    else
        local x, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 2, cy / scale - 2)
    end
    m:Show()
    return m
end

function UI.ContextMenu(entries)
    UI.CloseContextMenu()
    ctxLevel(1).catcher:Show()
    return openLevel(1, entries)
end
