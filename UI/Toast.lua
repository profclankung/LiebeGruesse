-- Notifications at the top of the screen: kicker, text, detail lines, an
-- optional row of class icons and a draining timer bar (right to left) that
-- shows how long the toast stays. Hover pauses it and shows the details.
local _, ns = ...
local UI, Theme = ns.UI, ns.Theme

local toasts, queue, pool = {}, {}, {}
local MAX, DURATION, WIDTH = 3, 7, 360
local BAR_H, GAP = 3, 6

local function layout()
    local holder = _G.LiebeGruesseAnchor_toasts
    local m = ns.Database.Settings().movers
    local y = 0
    for _, t in ipairs(toasts) do
        t:ClearAllPoints()
        t:SetScale(m and m.toastScale or 1)
        if holder then t:SetPoint("TOP", holder, "TOP", 0, -y)
        else t:SetPoint("TOP", UIParent, "TOP", 0, -120 - y) end
        y = y + t:GetHeight() + GAP
    end
end

-- horizontal colour gradient on a texture (modern and older clients)
local function gradient(tex, r1, g1, b1, a1, r2, g2, b2, a2)
    if CreateColor and pcall(tex.SetGradient, tex, "HORIZONTAL", CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2)) then return end
    if tex.SetGradientAlpha and pcall(tex.SetGradientAlpha, tex, "HORIZONTAL", r1, g1, b1, a1, r2, g2, b2, a2) then return end
    tex:SetVertexColor(r2, g2, b2, a2)
end

local function paintBar(t)
    local r, g, b = Theme.Color("accent")
    -- darker at the start, bright towards the (moving) end
    gradient(t.fill, r * 0.45, g * 0.45, b * 0.45, 0.9, math.min(1, r * 1.15 + 0.1), math.min(1, g * 1.15 + 0.08), math.min(1, b * 1.15 + 0.05), 1)
    gradient(t.glow, r, g, b, 0, 1, 0.95, 0.85, 0.55)
    gradient(t.shineL, 1, 1, 1, 0, 1, 1, 1, 0.35)
    gradient(t.shineR, 1, 1, 1, 0.35, 1, 1, 1, 0)
end

local function make()
    local t = UI.Panel(UIParent, "bg", "border")
    t:SetSize(WIDTH, 60)
    UI.Float(t)
    if t.SetClipsChildren then t:SetClipsChildren(true) end
    t.accent = UI.Fill(t, "accent", "ARTWORK")
    t.accent:SetPoint("TOPLEFT"); t.accent:SetPoint("BOTTOMLEFT"); t.accent:SetWidth(3)

    t.iconBorder = UI.Fill(t, "borderDim", "BORDER")
    t.iconBorder:SetSize(42, 42)
    t.iconBorder:SetPoint("TOPLEFT", 10, -10)
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetPoint("TOPLEFT", t.iconBorder, "TOPLEFT", 1, -1)
    t.icon:SetPoint("BOTTOMRIGHT", t.iconBorder, "BOTTOMRIGHT", -1, 1)
    t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    t.kicker = UI.Text(t, 10, "accent")
    t.kicker:SetPoint("TOPLEFT", t.iconBorder, "TOPRIGHT", 10, -1)
    t.when = UI.Text(t, 10, "muted", "RIGHT")
    t.when:SetPoint("TOPRIGHT", -26, -10)
    -- cross: dismiss (the same as a click without action)
    t.closeX = UI.IconButton(t, "x", 14, function() t.ends, t.hover = 0, nil; GameTooltip:Hide() end)
    t.closeX:SetPoint("TOPRIGHT", -6, -6)
    t.closeX.tip = ns.L.CLOSE
    t.kicker:SetWidth(WIDTH - 72 - 60)
    t.text = UI.Text(t, 13, "text")
    t.text:SetPoint("TOPLEFT", t.kicker, "BOTTOMLEFT", 0, -4)
    t.text:SetWidth(WIDTH - 72)
    t.text:SetWordWrap(false)
    t.lines = {}
    t.classes = {}
    t.hint = UI.Text(t, 10, "muted", "RIGHT")

    -- timer bar: track, gradient fill (clips the shimmer), soft glow at the end
    t.track = UI.Fill(t, "borderDim", "BORDER")
    t.track:SetPoint("BOTTOMLEFT", 1, 1); t.track:SetPoint("BOTTOMRIGHT", -1, 1)
    t.track:SetHeight(BAR_H)
    t.bar = CreateFrame("Frame", nil, t)
    t.bar:SetPoint("BOTTOMLEFT", 1, 1)
    t.bar:SetHeight(BAR_H)
    if t.bar.SetClipsChildren then t.bar:SetClipsChildren(true) end
    t.fill = t.bar:CreateTexture(nil, "ARTWORK")
    t.fill:SetTexture(Theme.WHITE)
    t.fill:SetAllPoints()
    t.shineL = t.bar:CreateTexture(nil, "OVERLAY")
    t.shineL:SetTexture(Theme.WHITE)
    t.shineL:SetSize(22, BAR_H)
    t.shineR = t.bar:CreateTexture(nil, "OVERLAY")
    t.shineR:SetTexture(Theme.WHITE)
    t.shineR:SetSize(22, BAR_H)
    t.shineR:SetPoint("LEFT", t.shineL, "RIGHT")
    t.glow = t:CreateTexture(nil, "OVERLAY")
    t.glow:SetTexture(Theme.WHITE)
    t.glow:SetSize(28, BAR_H + 2)
    t.glow:SetPoint("BOTTOMRIGHT", t.bar, "BOTTOMRIGHT", 0, -1)

    t:EnableMouse(true)
    -- hover: details tooltip; the toast (and its bar) pause while the mouse is on it
    t:SetScript("OnEnter", function(self)
        self.hover = GetTime()
        self:SetAlpha(1)
        if self.onEnter then ns.Safe(self.onEnter, self) end
    end)
    t:SetScript("OnLeave", function(self)
        -- resume exactly where it stopped: bar and shine move on from the same point
        if self.hover then
            local paused = GetTime() - self.hover
            self.ends = self.ends + paused
            self.started = self.started + paused
        end
        self.hover = nil
        GameTooltip:Hide()
    end)
    t:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.action then ns.Safe(self.action) end
        self.ends, self.hover = 0, nil
        GameTooltip:Hide()
    end)
    -- runs only while the toast is shown
    t:SetScript("OnUpdate", function(self)
        local now = GetTime()
        if self.hover then return end
        local left = self.ends - now
        if left <= 0 then
            self:Hide()
            for i, other in ipairs(toasts) do if other == self then table.remove(toasts, i) break end end
            layout()
            if #queue > 0 then UI.Toast(unpack(table.remove(queue, 1))) end
            return
        end
        local full = (self:GetWidth() or WIDTH) - 2
        local w = math.max(0.5, full * math.min(1, left / self.total))
        self.bar:SetWidth(w)
        self.glow:SetShown(w > 6)
        -- a soft shine runs along the bar
        local x = ((now - self.started) * 140) % (full + 44) - 44
        self.shineL:ClearAllPoints()
        self.shineL:SetPoint("BOTTOMLEFT", self.bar, "BOTTOMLEFT", x, 0)
        if left < 0.5 then self:SetAlpha(left / 0.5) end
    end)
    t:SetScript("OnHide", function(self) pool[#pool + 1] = self end)
    return t
end

-- bigger groups: one thin bar split by class (largest first) plus the count;
-- the names stay in the hover tooltip
local GROUP_ICONS = 5
local function classBar(t, list, anchor)
    if not t.comp then
        t.comp = CreateFrame("Frame", nil, t)
        t.comp:SetSize(WIDTH - 72, 14)
        t.comp.icon = UI.Icon(t.comp, "users", 11, "good")
        t.comp.icon:SetPoint("LEFT", 0, 0)
        t.comp.count = UI.Text(t.comp, 11, "textDim")
        t.comp.count:SetPoint("LEFT", t.comp.icon, "RIGHT", 4, 0)
        t.comp.segs = {}
    end
    local counts, order = {}, {}
    for _, class in ipairs(list) do
        if not counts[class] then counts[class] = 0; order[#order + 1] = class end
        counts[class] = counts[class] + 1
    end
    table.sort(order, function(a, b) if counts[a] ~= counts[b] then return counts[a] > counts[b] end return a < b end)
    t.comp.count:SetText(Theme.HexColor("text", tostring(#list)) .. " " .. ns.L.TOAST_FROM_GUILD)
    local x0 = 4 + 11 + 4 + 96
    local width = (WIDTH - 72) - x0
    local x = x0
    for i, class in ipairs(order) do
        local seg = t.comp.segs[i]
        if not seg then seg = t.comp:CreateTexture(nil, "ARTWORK"); seg:SetTexture(Theme.WHITE); t.comp.segs[i] = seg end
        local w = math.max(2, width * counts[class] / #list - 1)
        seg:ClearAllPoints()
        seg:SetPoint("LEFT", t.comp, "LEFT", x, 0)
        seg:SetSize(w, 5)
        seg:SetVertexColor(ns.ClassColor(class))
        seg:Show()
        x = x + w + 1
    end
    for i = #order + 1, #t.comp.segs do t.comp.segs[i]:Hide() end
    t.comp:ClearAllPoints()
    t.comp:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -5)
    t.comp:Show()
end

local function classRow(t, list)
    if list and #list > GROUP_ICONS then
        for _, tex in ipairs(t.classes) do tex:Hide() end
        return 0
    end
    local n = 0
    for i, class in ipairs(list or {}) do
        if i > 18 then break end
        n = i
        local tex = t.classes[i]
        if not tex then
            tex = t:CreateTexture(nil, "ARTWORK")
            tex:SetSize(14, 14)
            t.classes[i] = tex
        end
        if not ns.SetClassIcon(tex, class) then tex:SetTexture(134400) end
        tex:Show()
    end
    for i = n + 1, #t.classes do t.classes[i]:Hide() end
    if not t.more then t.more = UI.Text(t, 10, "muted") end
    local extra = #(list or {}) - n
    t.more:SetText(extra > 0 and ("+" .. extra) or "")
    return n
end

-- opts: { kicker = "LEVEL UP", lines = { "detail", … }, classes = { "WARRIOR", … },
--         action = fn, actionText = "Click: …", big = true, sound = "milestone"|"epic",
--         sub = "single detail line" (old), onEnter = fn(toast), duration = seconds,
--         wrap = max. lines for the main text (default: one line, clipped),
--         iconColor = { r, g, b } (icon border, e.g. item quality) }
function UI.Toast(title, text, icon, opts)
    if not ns.Database.Settings().toasts then return end
    if ns.InCombat() then
        if #queue < 5 then queue[#queue + 1] = { title, text, icon, opts } end
        return
    end
    if #toasts >= MAX then
        if #queue < 10 then queue[#queue + 1] = { title, text, icon, opts } end
        return
    end
    opts = opts or {}
    local t = table.remove(pool) or make()
    t:SetWidth(WIDTH)
    t.kicker:SetText(ns.Upper(opts.kicker or title or ns.title))
    t.when:SetText(opts.when or "")
    -- long texts (announcements): wrap up to opts.wrap lines, the toast grows
    local wrap = tonumber(opts.wrap)
    t.text:SetWordWrap(wrap ~= nil)
    if t.text.SetMaxLines then t.text:SetMaxLines(wrap or 0) end
    t.text:SetText(text or "")
    local textH = 16
    if wrap then
        local h = ns.Call(t.text.GetStringHeight, t.text)
        if ns.Num(h) and h > 0 then textH = math.min(math.max(16, math.ceil(h)), wrap * 16) end
    end
    t.icon:SetTexture(icon or (ns.media .. "icon"))
    if opts.iconColor then t.iconBorder:SetVertexColor(opts.iconColor[1], opts.iconColor[2], opts.iconColor[3])
    else t.iconBorder:SetVertexColor(Theme.Color("borderDim")) end
    t.action = opts.action
    t.onEnter, t.hover = opts.onEnter, nil
    t.accent:SetShown(opts.big == true)

    -- detail lines under the text
    local lines = opts.lines or (opts.sub and opts.sub ~= "" and { opts.sub }) or {}
    local y = -10 - 12 - 4 - textH   -- kicker + text
    local prev = t.text
    for i, l in ipairs(lines) do
        local fs = t.lines[i]
        if not fs then fs = UI.Text(t, 11, "textDim"); t.lines[i] = fs end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -5 or -3)
        fs:SetWidth(WIDTH - 72)
        fs:SetWordWrap(false)
        fs:SetText(l)
        fs:Show()
        prev = fs
        y = y - 15
    end
    for i = #lines + 1, #t.lines do t.lines[i]:Hide() end
    -- class icons (e.g. the guild members at a boss kill); big groups as a class bar
    local n = classRow(t, opts.classes)
    if t.comp then t.comp:Hide() end
    if opts.classes and #opts.classes > GROUP_ICONS then
        classBar(t, opts.classes, prev)
        if t.more then t.more:SetText("") end
        y = y - 18
    elseif n > 0 then
        for i = 1, n do
            t.classes[i]:ClearAllPoints()
            t.classes[i]:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", (i - 1) * 16, -5)
        end
        t.more:ClearAllPoints()
        t.more:SetPoint("LEFT", t.classes[n], "RIGHT", 4, 0)
        y = y - 18
    elseif t.more then
        t.more:SetText("")
    end
    t.hint:SetText(opts.actionText or "")
    t.hint:ClearAllPoints()
    local h = math.max(62, -y + 14)
    if opts.actionText then
        t.hint:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -10, BAR_H + 6)
        h = h + 14
    end
    t:SetHeight(h)

    if opts.sound then ns.Sound(opts.sound) end
    t.total = opts.duration or (opts.big and DURATION + 4 or DURATION)
    t.started = GetTime()
    t.ends = t.started + t.total
    paintBar(t)
    t.bar:SetWidth(WIDTH - 2)
    t:SetAlpha(1)
    t:Show()
    toasts[#toasts + 1] = t
    layout()
end

ns.On("PLAYER_REGEN_ENABLED", function()
    ns.After(2, function()
        while #queue > 0 and #toasts < MAX do UI.Toast(unpack(table.remove(queue, 1))) end
    end)
end)

ns.On("LG_READY", function()
    ns.Movers.Anchor("toasts", ns.L.MOVER_TOASTS, { "TOP", "TOP", 0, -110 }, WIDTH, 200, nil, { icon = "newspaper",
        settings = function() ns.Window.Show("notifications") end,
        sizes = { { label = ns.L.MOVE_SCALE, min = 0.6, max = 1.6, step = 0.05, pct = true,
            get = function() local m = ns.Database.Settings().movers; return m and m.toastScale or 1 end,
            set = function(v) ns.Database.Settings().movers.toastScale = v; layout() end } },
    })
end)
