-- Notification history: every notification of the addon (toast) is kept with
-- time, type, title, text and read state (the last 50, setting). A small bell
-- with an unread badge (movable with "Move elements") opens a compact log of
-- missed notifications. Toasts that are switched off are still logged.
-- Reactions (congratulate, welcome): a notification that offered one can be
-- answered once from the log – only when it was not answered on the toast and
-- it happened while you were online (opts.react, see Modules/Notify.lua).
local _, ns = ...
local Log = {}
ns.NotifyLog = Log
local UI, Theme, L = ns.UI, ns.Theme, ns.L

function Log.Settings()
    local s = ns.Database.Settings()
    s.notifyLog = s.notifyLog or {}
    local o = s.notifyLog
    if o.enabled == nil then o.enabled = true end
    if o.bell == nil then o.bell = true end
    if o.badge == nil then o.badge = true end
    o.max = o.max or 50
    o.list = o.list or {}
    return o
end

local function strip(text)
    text = tostring(text or "")
    return text:gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

function Log.Unread()
    local n = 0
    for _, e in ipairs(Log.Settings().list) do if not e.read then n = n + 1 end end
    return n
end

-- adds an entry (newest last); kind: the toast's kicker
function Log.Add(kicker, title, text, opts)
    local o = Log.Settings()
    if not o.enabled then return end
    kicker = strip(kicker)
    if kicker:find(strip(L.TEST_TAG), 1, true) == 1 and not Log.keepTests then return end
    local list = o.list
    local e = { t = ns.Now(), k = kicker:sub(1, 40), h = strip(title):sub(1, 120), x = strip(text):sub(1, 200),
        p = opts and opts.page or nil, read = false }
    local re = opts and opts.react
    if type(re) == "table" and type(re.m) == "string" and (re.c == "GUILD" or (re.c == "WHISPER" and type(re.to) == "string")) then
        e.re = { m = re.m:sub(1, 250), c = re.c, to = re.to, b = re.b, t = re.t }
    end
    list[#list + 1] = e
    while #list > math.max(10, o.max) do table.remove(list, 1) end
    ns.Fire("LG_NOTIFYLOG")
    return e
end

-- can this entry still be answered from the log?
function Log.CanReact(e) return type(e) == "table" and e.re ~= nil and not e.rd end

-- answers once (the chat line the toast would have sent)
function Log.React(e)
    if not Log.CanReact(e) then return false end
    if e.re.t then
        -- test entry: nothing is sent
        ns.Print(L.TEST_TAG .. " " .. L.NLOG_REACT_TEST:format(e.re.m))
    else
        local ok = ns.SendChat(e.re.m, e.re.c, e.re.to)
        if ok == false then return false end
    end
    e.rd, e.read = true, true
    ns.Fire("LG_NOTIFYLOG")
    return true
end

function Log.MarkAllRead()
    for _, e in ipairs(Log.Settings().list) do e.read = true end
    ns.Fire("LG_NOTIFYLOG")
end
function Log.Clear()
    wipe(Log.Settings().list)
    ns.Fire("LG_NOTIFYLOG")
end

-- every toast goes through here once (queued toasts come back with the same opts)
local realToast = UI.Toast
function UI.Toast(title, text, icon, opts)
    opts = opts or {}
    if not opts._logged then
        opts._logged = true
        local ok, e = pcall(Log.Add, opts.kicker or title, (opts.kicker and title ~= opts.kicker) and title or text,
            (opts.kicker and title ~= opts.kicker) and text or ((opts.lines and opts.lines[1]) or ""), opts)
        -- answered on the toast: no second reaction from the log
        if ok and type(e) == "table" and e.re and opts.action then
            local action = opts.action
            opts.action = function(...)
                e.rd = true
                ns.Fire("LG_NOTIFYLOG")
                return action(...)
            end
        end
    end
    return realToast(title, text, icon, opts)
end

---------------------------------------------------------------------------
-- Bell (HUD) and the log window
---------------------------------------------------------------------------
local bell, win
local ICONS = {}

local function iconFor(kind)
    local k = (kind or ""):lower()
    if k:find("record") or k:find("best") then return "trophy" end
    if k:find("achiev") then return "star" end
    if k:find("update") then return "circle-arrow-up" end
    if k:find("announce") then return "megaphone" end
    if k:find("bug") or k:find("error") then return "bug" end
    if k:find("award") or k:find("raid") then return "crown" end
    if k:find("loot") or k:find("epic") then return "gem" end
    return ICONS[k] or "bell"
end

local function createWindow()
    win = UI.Panel(UIParent, "bg", "border")
    UI.Float(win)
    win:SetSize(360, 420)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win.head = UI.Fill(win, "header", "BACKGROUND")
    win.head:SetPoint("TOPLEFT", 1, -1); win.head:SetPoint("TOPRIGHT", -1, -1); win.head:SetHeight(32)
    win.icon = UI.Icon(win, "bell", 14, "accent"); win.icon:SetPoint("TOPLEFT", 12, -10)
    win.title = UI.Text(win, 14, "text", nil, nil, true); win.title:SetPoint("LEFT", win.icon, "RIGHT", 8, 0)
    win.title:SetText(L.NLOG_TITLE)
    win.close = UI.IconButton(win, "x", 18, function() win:Hide() end)
    win.close:SetPoint("TOPRIGHT", -7, -7)
    win.count = UI.Text(win, 11, "accent", "RIGHT"); win.count:SetPoint("RIGHT", win.close, "LEFT", -8, 0)
    win.readAll = UI.Button(win, L.NLOG_READ_ALL, 130, 22, function() Log.MarkAllRead() end, "check")
    win.readAll:SetPoint("TOPLEFT", 10, -40)
    win.clear = UI.Button(win, L.NLOG_CLEAR, 96, 22, function() Log.Clear() end, "trash-2")
    win.clear:SetPoint("LEFT", win.readAll, "RIGHT", 6, 0)
    win.onlyUnread = false
    win.filter = UI.Segmented(win, 100, { { value = false, text = L.NLOG_ALL }, { value = true, text = L.NLOG_UNREAD } },
        function() return win.onlyUnread end, function(v) win.onlyUnread = v; Log.Refresh() end)
    win.filter:SetPoint("TOPRIGHT", -10, -40)
    local scroll, body = UI.ScrollArea(win)
    scroll:SetPoint("TOPLEFT", 1, -70)
    scroll:SetPoint("BOTTOMRIGHT", -1, 26)
    win.scroll, win.body = scroll, body
    win.foot = UI.Text(win, 10, "muted"); win.foot:SetPoint("BOTTOMLEFT", 10, 8)
    win.empty = UI.Empty(win, 300)
    win.empty:SetPoint("CENTER", 0, -20)
    win.rows = {}
    win:SetScript("OnHide", function() Log.MarkAllRead() end)
    win:Hide()
end

local ROW_H = 54
local function row(i)
    local r = win.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, win.body)
    r:SetHeight(ROW_H)
    r.bg = UI.Fill(r, "accentDim", "BACKGROUND"); r.bg:SetAllPoints()
    r.bar = UI.Fill(r, "accent", "ARTWORK"); r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(2)
    r.line = UI.Fill(r, "borderDim", "ARTWORK"); r.line:SetHeight(1); r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT")
    r.tile = UI.Panel(r, "input", "borderDim"); r.tile:SetSize(28, 28); r.tile:SetPoint("TOPLEFT", 10, -10)
    r.icon = UI.Icon(r.tile, "bell", 14, "muted"); r.icon:SetPoint("CENTER")
    r.kind = UI.Text(r, 10, "accent", nil, nil, true); r.kind:SetPoint("TOPLEFT", 46, -7); r.kind:SetWordWrap(false)
    r.ago = UI.Text(r, 10, "muted", "RIGHT"); r.ago:SetPoint("TOPRIGHT", -10, -7)
    r.title = UI.Text(r, 12, "text"); r.title:SetPoint("TOPLEFT", 46, -21); r.title:SetWordWrap(false)
    -- reaction (once): congratulate / welcome from the log
    r.react = UI.Button(r, "", 74, 20, function(self)
        local e = self:GetParent().e
        if Log.React(e) then return end
        if e and not Log.CanReact(e) then ns.Print(L.NLOG_REACT_DONE) end
    end, "message-circle")
    r.react:SetPoint("BOTTOMRIGHT", -8, 7)
    r.react:HookScript("OnEnter", function(self)
        local e = self:GetParent().e
        if not e or not e.re then return end
        UI.Tooltip(self, L.NLOG_REACT, { L.NLOG_REACT_TIP, " ", Theme.HexColor("muted", e.re.m) })
    end)
    r.react:HookScript("OnLeave", function() GameTooltip:Hide() end)
    r.text = UI.Text(r, 11, "muted"); r.text:SetPoint("TOPLEFT", 46, -36); r.text:SetWordWrap(false)
    r:SetScript("OnClick", function(self)
        if not self.e then return end
        self.e.read = true
        if self.e.p and ns.Window and ns.Window.Show then ns.Window.Show(self.e.p) end
        ns.Fire("LG_NOTIFYLOG")
    end)
    r:SetScript("OnEnter", function(self)
        if not self.e then return end
        UI.Tooltip(self, self.e.h ~= "" and self.e.h or self.e.k, { self.e.x, " ", Theme.HexColor("muted", ns.Date(self.e.t)) })
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    win.rows[i] = r
    return r
end

function Log.Refresh()
    if bell then
        local n = Log.Unread()
        bell.badge:SetShown(n > 0 and Log.Settings().badge)
        bell.badgeText:SetText(n > 99 and "99+" or tostring(n))
        bell.badge:SetWidth(math.max(16, (bell.badgeText:GetStringWidth() or 8) + 8))
        bell.icon:SetVertexColor(Theme.Color(n > 0 and "accent" or "bronze"))
    end
    if not win or not win:IsShown() then return end
    local list = Log.Settings().list
    local unread = Log.Unread()
    win.count:SetText(unread > 0 and L.NLOG_NEW:format(unread) or "")
    win.filter:Refresh()
    local w = (win.scroll:GetWidth() or 358) - 4
    local n = 0
    for i = #list, 1, -1 do
        local e = list[i]
        if not win.onlyUnread or not e.read then
            n = n + 1
            local r = row(n)
            r.e = e
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -(n - 1) * ROW_H); r:SetWidth(w)
            r.bg:SetShown(not e.read); r.bar:SetShown(not e.read)
            Theme.SetIcon(r.icon, iconFor(e.k))
            r.icon:SetVertexColor(Theme.Color(e.read and "muted" or "accent"))
            r.kind:SetText(ns.Upper(e.k or "")); r.kind:SetWidth(w - 46 - 70)
            r.ago:SetText(ns.Ago(e.t))
            r.title:SetText(e.h or "")
            local canReact = Log.CanReact(e)
            r.react:SetShown(canReact)
            if canReact then r.react:SetText(e.re.b or L.NLOG_REACT) end
            r.text:SetText(e.rd and e.re and (Theme.HexColor("good", L.NLOG_REACTED) .. "  " .. (e.x or "")) or (e.x or ""))
            r.text:SetWidth(w - 56 - (canReact and 84 or 0))
            r.title:SetWidth(w - 56 - (canReact and 84 or 0))
            r:Show()
        end
    end
    for i = n + 1, #win.rows do win.rows[i]:Hide() end
    win.body:SetSize(w, math.max(1, n * ROW_H))
    if win.scroll.UpdateBar then win.scroll.UpdateBar() end
    win.empty:SetShown(n == 0)
    if n == 0 then win.empty:Set("bell", win.onlyUnread and L.NLOG_EMPTY_UNREAD or L.NLOG_EMPTY, L.NLOG_EMPTY_HINT) end
    win.foot:SetText(L.NLOG_FOOT:format(Log.Settings().max))
end

function Log.Toggle()
    if not win then createWindow() end
    if win:IsShown() then win:Hide(); return end
    win:ClearAllPoints()
    if bell and bell:IsShown() then
        local x = bell:GetCenter() or 0
        local w = UIParent:GetWidth() or 1920
        if x > w / 2 then win:SetPoint("TOPRIGHT", bell, "BOTTOMRIGHT", 0, -6) else win:SetPoint("TOPLEFT", bell, "BOTTOMLEFT", 0, -6) end
    else
        win:SetPoint("CENTER")
    end
    win:Show()
    Log.Refresh()
end
function Log.Show() if not win or not win:IsShown() then Log.Toggle() end end

local function createBell()
    bell = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    bell:SetSize(32, 32)
    bell:SetFrameStrata("MEDIUM")
    bell:SetClampedToScreen(true)
    UI.Skin(bell, "bg", "bronzeDim")
    bell.icon = UI.Icon(bell, "bell", 16, "bronze"); bell.icon:SetPoint("CENTER")
    bell.badge = UI.Panel(bell, "bad", "bg")
    bell.badge:SetSize(16, 16)
    bell.badge:SetPoint("TOPRIGHT", 7, 7)
    bell.badge:SetFrameLevel(bell:GetFrameLevel() + 5)
    bell.badgeText = UI.Text(bell.badge, 10, "text", "CENTER", nil, true); bell.badgeText:SetPoint("CENTER", 0, 0)
    bell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bell:SetScript("OnClick", function(_, button)
        if button == "RightButton" then Log.MarkAllRead() else Log.Toggle() end
    end)
    -- small cross while the mouse is over the bell: hides it (Settings › Notifications brings it back)
    bell.closeX = UI.IconButton(bell, "x", 12, function()
        Log.Settings().bell = false
        Log.Layout()
        ns.Print(L.NLOG_BELL_HIDDEN)
    end)
    bell.closeX:SetPoint("TOPLEFT", -7, 7)
    bell.closeX:SetFrameLevel(bell:GetFrameLevel() + 6)
    bell.closeX.tip = L.NLOG_BELL_HIDE
    bell.closeX:SetAlpha(0)
    bell.closeX:HookScript("OnEnter", function(self) self:SetAlpha(1) end)
    bell.closeX:HookScript("OnLeave", function(self) if not bell:IsMouseOver() then self:SetAlpha(0) end end)
    bell:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(Theme.Color("accent"))
        self.closeX:SetAlpha(1)
        UI.Tooltip(self, L.NLOG_TITLE, { L.NLOG_BELL_TIP:format(Log.Unread()) })
    end)
    bell:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(Theme.Color("bronzeDim")); GameTooltip:Hide()
        if not self.closeX:IsMouseOver() then self.closeX:SetAlpha(0) end
    end)
    ns.Movers.Attach("notifyBell", bell)
end

function Log.Layout()
    local o = Log.Settings()
    local show = (o.enabled and o.bell) or ns.Movers.active
    if not show then if bell then bell:Hide() end; if win then win:Hide() end; return end
    -- frames are only created outside of combat (nothing secure, but no work during fights)
    if not bell then
        if ns.InCombat() then ns.AfterCombat("notify-bell", Log.Layout); return end
        createBell()
    end
    bell:Show()
    Log.Refresh()
end

ns.On("LG_NOTIFYLOG", function() ns.Debounce("notify-log", 0.1, Log.Refresh) end)
ns.On("LG_MOVERS", function() Log.Layout() end)
ns.On("LG_READY", function()
    ns.Movers.Anchor("notifyBell", L.NLOG_TITLE, { "TOPRIGHT", "TOPRIGHT", -240, -20 }, 32, 32, nil, { icon = "bell", scalable = true,
        settings = function() ns.Window.Show("notifications") end })
    ns.After(2, Log.Layout)
end)

-- /lg test notifylog: three sample entries (marked as test) and the log
function Log.Test()
    Log.keepTests = true
    UI.Toast(L.TEST_TAG .. " " .. L.RUN_NEW_GUILD, L.RUN_TOAST_TEXT:format("Stratholme – Live", "31:47"), nil, { kicker = L.TEST_TAG .. " " .. L.RUN_NEW_GUILD, page = "runs" })
    UI.Toast(L.TEST_TAG .. " " .. L.ACH_NEW, "Speed Demon  Silver", nil, { kicker = L.TEST_TAG .. " " .. L.ACH_NEW, page = "achievements" })
    UI.Toast(L.TEST_TAG .. " " .. L.ANNOUNCE_KICKER, L.ANNOUNCE_TEST_TEXT, nil, { kicker = L.TEST_TAG .. " " .. L.ANNOUNCE_KICKER })
    -- with a reaction: answer it from the log (nothing is sent in the test)
    local msg = ns.Messages and ns.Messages.Format("gratzLevel", { player = ns.Names.Display(ns.Names.Me()), level = 60 }) or "Gz!"
    UI.Toast(L.TEST_TAG .. " " .. L.NOTIFY_MILESTONE, L.NLOG_TEST_REACT, nil, { kicker = L.TEST_TAG .. " " .. L.NOTIFY_MILESTONE,
        react = { m = msg, c = "GUILD", b = L.NLOG_GRATZ, t = true }, actionText = L.NOTIFY_CLICK_GRATZ,
        action = function() ns.Print(L.TEST_TAG .. " " .. L.NLOG_REACT_TEST:format(msg)) end })
    Log.keepTests = false
    Log.Layout()
    Log.Show()
end
