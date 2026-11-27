-- Quick actions: a small bar of one-line prompts for "!lg" answers only
-- ("Salty Brown asked for [Lionheart Helm] – click to post"). A click is your
-- own action, so the game lets the chat line through – no automatic line needed.
-- Notifications (toasts), greetings and congratulations stay as they are.
-- Placed with "Move elements"; nothing runs while it is empty (one timer per
-- entry for its expiry, no OnUpdate).
local _, ns = ...
local UI, Theme, L = ns.UI, ns.Theme, ns.L

local QB = {}
ns.QuickBar = QB
-- one line is ROW_H high; its width is a setting (icons only: a square)
local ROW_H = 32
QB.MIN_W, QB.MAX_W, QB.WIDTH = 260, 640, 380
-- grow directions: where the next line goes (x, y in lines); "auto" = up or down toward the screen middle
local GROW = { down = { 0, -1 }, up = { 0, 1 }, right = { 1, 0 }, left = { -1, 0 } }
local STYLES = { full = true, text = true, icons = true }

QB.entries = {}   -- newest first: { key, icon, text, tip, send, onClick, group, timer, t }
local rows, holder = {}, nil
QB.rows = rows   -- for tests

local function clamp(v, lo, hi, def)
    v = tonumber(v) or def
    return math.max(lo, math.min(hi, v))
end

function QB.Settings()
    local s = ns.Database.Settings()
    s.quick = s.quick or {}
    local q = s.quick
    -- auto: "ask" = "!lg" answers for players without the addon wait here, "send" = sent by the addon
    -- guild/whisper: which "ask first" questions wait in the bar (off = the addon answers them itself)
    -- grow/style/order/width/gap/timer/close/more: the look of the bar (1.0.88)
    local defaults = { enabled = true, auto = "ask", craft = true, craftLink = true, ttl = 15, max = 4, scale = 1,
        guild = true, whisper = true, grow = "auto", style = "full", order = "newest", width = QB.WIDTH, gap = 4,
        timer = true, close = true, more = true }
    for k, v in pairs(defaults) do if q[k] == nil then q[k] = v end end
    -- 1.0.82: lines stay 15 s by default (first builds had 90 s)
    if not q.ttl15 then q.ttl15 = true; if q.ttl == 90 then q.ttl = 15 end end
    -- unknown or out-of-range values (older or hand-edited saves) fall back to something sane
    if q.grow ~= "auto" and not GROW[q.grow] then q.grow = "auto" end
    if not STYLES[q.style] then q.style = "full" end
    if q.order ~= "oldest" then q.order = "newest" end
    q.width = clamp(q.width, QB.MIN_W, QB.MAX_W, QB.WIDTH)
    q.gap = clamp(q.gap, 0, 16, 4)
    q.max = math.floor(clamp(q.max, 1, 8, 4))
    q.scale = clamp(q.scale, 0.6, 1.6, 1)
    return q
end

-- "!lg" answers for players without the addon: ask first (bar) instead of sending them;
-- channel "GUILD"/"WHISPER" also checks whether that kind of question is shown in the bar
function QB.AskFirst(channel)
    local q = QB.Settings()
    if not (q.enabled and q.auto == "ask") then return false end
    if channel == "GUILD" then return q.guild ~= false end
    if channel == "WHISPER" then return q.whisper ~= false end
    return true
end

-- the direction the lines grow in; "auto" = toward the middle of the screen (down when the bar sits high)
function QB.Grow()
    local g = QB.Settings().grow
    if GROW[g] then return g end
    if holder and holder.GetCenter and UIParent.GetCenter then
        local _, y = holder:GetCenter()
        local _, mid = UIParent:GetCenter()
        local s1, s2 = holder:GetEffectiveScale(), UIParent:GetEffectiveScale()
        if y and mid and s1 and s2 and s2 > 0 then return (y * s1 / s2 < mid) and "up" or "down" end
    end
    return "down"
end

local function remove(key)
    for i, e in ipairs(QB.entries) do
        if e.key == key then
            if e.timer then e.timer:Cancel() end
            table.remove(QB.entries, i)
            return true
        end
    end
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------
local function shrink(row, ttl)
    -- thin line at the bottom that runs empty until the prompt goes away
    row.drain:SetWidth((row:GetWidth() or QB.WIDTH) - 2)
    if row.anim then row.anim:Stop() end
    if not (row.drainAnim and ttl and ttl > 0) then return end
    row.drainAnim:SetDuration(ttl)
    row.anim:Play()
end

local function makeRow(i)
    local r = CreateFrame("Button", nil, holder, "BackdropTemplate")
    UI.Skin(r, "bg", "borderDim")
    r:SetSize(QB.WIDTH, ROW_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.accent = UI.Fill(r, "accent", "ARTWORK")
    r.accent:SetPoint("TOPLEFT", 1, -1); r.accent:SetPoint("BOTTOMLEFT", 1, 1); r.accent:SetWidth(2)
    r.hl = UI.Fill(r, "hover", "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16)
    r.icon:SetPoint("LEFT", 10, 0)
    r.close = UI.IconButton(r, "x", 18, function() QB.Remove(r.key) end)
    r.close:SetPoint("RIGHT", -5, 0)
    r.close.tip = L.QB_DISMISS
    r.text = UI.Text(r, 13, "text")
    r.text:SetWordWrap(false)
    r.drain = UI.Fill(r, "accent", "OVERLAY")
    r.drain:SetPoint("BOTTOMLEFT", 1, 1)
    r.drain:SetHeight(1)
    r.drain:SetAlpha(0.7)
    r.anim = r.drain:CreateAnimationGroup()
    local a = r.anim:CreateAnimation("Scale")
    if a.SetScaleFrom then a:SetScaleFrom(1, 1); a:SetScaleTo(0.001, 1); r.drainAnim = a
    elseif a.SetFromScale then a:SetFromScale(1, 1); a:SetToScale(0.001, 1); r.drainAnim = a end
    if a.SetOrigin then a:SetOrigin("LEFT", 0, 0) end
    r:SetScript("OnClick", function(self, button)
        if button == "RightButton" then QB.Remove(self.key) else QB.Run(self.key) end
    end)
    r:SetScript("OnEnter", function(self)
        local e = self.entry
        if not e then return end
        local lines = {}
        for _, l in ipairs(e.tip or {}) do lines[#lines + 1] = l end
        if e.send then lines[#lines + 1] = Theme.HexColor("muted", L.QB_WILL_SEND) .. " " .. e.send[1] end
        lines[#lines + 1] = Theme.HexColor("muted", e.hint or (e.send and L.QB_CLICK_SEND or L.QB_CLICK_OPEN))
        UI.Tooltip(self, e.title or e.text, lines)
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = r
    return r
end

local function sample()
    return { key = "sample", icon = "message-circle", text = L.QB_SAMPLE, tip = { L.QB_SAMPLE_TIP } }
end

-- one line in the chosen look: icon + text, text only, or a square icon (text in the tooltip)
local function restyle(r, q, w)
    local icons, textOnly = q.style == "icons", q.style == "text"
    local close = q.close and not icons
    r:SetSize(w, ROW_H)
    r.icon:ClearAllPoints()
    r.icon:SetShown(not textOnly)
    r.close:SetShown(close)
    r.text:ClearAllPoints()
    if icons then
        r.icon:SetSize(20, 20)
        r.icon:SetPoint("CENTER", 1, 0)
        r.text:SetPoint("BOTTOMRIGHT", -3, 3)   -- only "+n" when more lines wait
        r.text:SetJustifyH("RIGHT")
    else
        r.icon:SetSize(16, 16)
        r.icon:SetPoint("LEFT", 10, 0)
        if textOnly then r.text:SetPoint("LEFT", 12, 0) else r.text:SetPoint("LEFT", r.icon, "RIGHT", 8, 0) end
        if close then r.text:SetPoint("RIGHT", r.close, "LEFT", -6, 0) else r.text:SetPoint("RIGHT", -10, 0) end
        r.text:SetJustifyH("LEFT")
    end
    r.drain:SetShown(q.timer ~= false)
    r.drain:SetWidth(w - 2)
end

function QB.Layout()
    if not holder then return end
    local q = QB.Settings()
    local icons = q.style == "icons"
    local w = icons and ROW_H or q.width
    holder:SetScale(q.scale)
    -- the anchor is the first line: a saved spot (top left) keeps where the bar starts
    holder:SetSize(w, ROW_H)
    local list = QB.entries
    -- while placing the elements: one sample line shows where the bar is
    if (#list == 0) and ns.Movers.active then list = { sample() } end
    if q.order == "oldest" and #list > 1 then
        local old = {}
        for i = #list, 1, -1 do old[#old + 1] = list[i] end
        list = old
    end
    local shown = q.enabled and math.min(#list, q.max) or 0
    local step = GROW[QB.Grow()]
    for i = 1, shown do
        local e = list[i]
        local r = rows[i] or makeRow(i)
        restyle(r, q, w)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", holder, "TOPLEFT", step[1] * (i - 1) * (w + q.gap), step[2] * (i - 1) * (ROW_H + q.gap))
        r.key, r.entry = e.key, e
        if type(e.icon) == "number" then r.icon:SetTexture(e.icon); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); r.icon:SetVertexColor(1, 1, 1)
        else Theme.SetIcon(r.icon, e.icon or "message-circle"); r.icon:SetVertexColor(Theme.Color("accent")) end
        r.text:SetText(icons and "" or (e.text or ""))
        if r.shownFor ~= e then
            r.shownFor = e
            shrink(r, e.expires and (e.expires - GetTime()) or nil)
        end
        r:Show()
    end
    for i = shown + 1, #rows do rows[i]:Hide(); rows[i].shownFor = nil end
    -- more than fit: the last line says so (icons only: a small "+n")
    if q.enabled and q.more and #list > shown and shown > 0 then
        local r = rows[shown]
        if icons then r.text:SetText(("+%d"):format(#list - shown))
        else r.text:SetText((r.entry.text or "") .. "  " .. Theme.HexColor("muted", L.QB_MORE:format(#list - shown))) end
    end
    holder:SetShown(shown > 0)
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------
-- e = { key, icon (Lucide name or texture id), text, title, tip = { lines },
--       send = { text, chatType, target }, check = fn() -> ok, reason,
--       onClick = fn() (return false to keep the line), group, ttl }
-- Same key replaces the older line. Returns true when it is shown.
function QB.Add(e)
    local q = QB.Settings()
    if not q.enabled or not e or not e.key then return false end
    remove(e.key)
    local ttl = e.ttl or q.ttl or 15
    e.expires = GetTime() + ttl
    e.timer = C_Timer.NewTimer(ttl, function() if remove(e.key) then QB.Layout() end end)
    table.insert(QB.entries, 1, e)
    -- keep the list short (the oldest go)
    while #QB.entries > 20 do
        local old = table.remove(QB.entries)
        if old.timer then old.timer:Cancel() end
    end
    QB.Layout()
    return true
end

function QB.Remove(key)
    if remove(key) then QB.Layout() end
end

function QB.RemoveGroup(group)
    local any = false
    for i = #QB.entries, 1, -1 do
        local e = QB.entries[i]
        if e.group == group then
            if e.timer then e.timer:Cancel() end
            table.remove(QB.entries, i)
            any = true
        end
    end
    if any then QB.Layout() end
end

function QB.Clear()
    for _, e in ipairs(QB.entries) do if e.timer then e.timer:Cancel() end end
    wipe(QB.entries)
    QB.Layout()
end

function QB.Get(key)
    for _, e in ipairs(QB.entries) do if e.key == key then return e end end
end

-- a click: send the line (or run the action) and remove it
function QB.Run(key)
    local e = QB.Get(key)
    if not e then return end
    if e.check then
        local ok, reason = e.check()
        if not ok then
            if reason then ns.Print(reason) end
            QB.Remove(key)
            return
        end
    end
    local done = true
    if e.send then
        if e.test then ns.Print("%s %s", L.TEST_TAG, e.send[1])
        else done = ns.SendChat(e.send[1], e.send[2], e.send[3]) == true end
    end
    if e.onClick then
        local r = ns.Try(e.onClick, e, done)
        if r == false then done = false end
    end
    if done then QB.Remove(key) end
end

-- /lg test quick: sample "!lg" lines (a click only prints, nothing is sent)
function QB.Test()
    local me = ns.Names.Display(ns.Names.Me())
    local answer = "[LG] [Lionheart Helm]: " .. me .. " (online) · mats ~64g"
    QB.Add({ key = "test-craft", icon = "hammer", test = true, text = L.QB_CRAFT_ASKED:format("Salty Brown", "[Lionheart Helm]"),
        tip = { answer, L.QB_CRAFT_POST_TIP }, send = { answer, "GUILD" }, ttl = 120 })
    QB.Add({ key = "test-whisper", icon = "hammer", test = true, text = L.QB_CRAFT_WHISPERED:format("Mar Cha", "[Arcanite Rod]"),
        send = { "[LG] [Arcanite Rod]: " .. me .. " (online)", "WHISPER", "Mar Cha" }, ttl = 120 })
    ns.Print(L.QB_TEST_DONE)
end

-- /lg test quicklayout: four sample lines in the current look and what the settings say
function QB.TestLayout()
    local q = QB.Settings()
    for i = 4, 1, -1 do
        QB.Add({ key = "test-layout-" .. i, icon = i % 2 == 0 and "message-circle" or "hammer", test = true,
            text = L.QB_LAYOUT_SAMPLE:format(i), send = { L.QB_LAYOUT_SAMPLE:format(i), "GUILD" }, ttl = 60 })
    end
    local grow = QB.Grow()
    ns.Print(L.QB_LAYOUT_REPORT:format(L["QB_GROW_" .. grow] .. (q.grow == "auto" and " (" .. L.QB_GROW_auto .. ")" or ""),
        L["QB_STYLE_" .. q.style], q.style == "icons" and ROW_H or q.width, q.gap, q.max,
        q.order == "oldest" and L.QB_ORDER_OLDEST or L.QB_ORDER_NEWEST))
    ns.Print(L.QB_LAYOUT_KINDS:format(q.guild and L.YES or L.NO, q.whisper and L.YES or L.NO, q.craft and L.YES or L.NO))
end

---------------------------------------------------------------------------
-- Anchor and settings
---------------------------------------------------------------------------
ns.On("LG_READY", function()
    holder = ns.Movers.Anchor("quickBar", L.QB_TITLE, { "TOP", "TOP", 0, -330 }, QB.Settings().width, ROW_H, nil, {
        icon = "zap",
        settings = function() ns.Window.ShowSettings("professions") end,
        sizes = { { label = L.CD_SCALE, min = 0.6, max = 1.6, step = 0.05, pct = true,
            get = function() return QB.Settings().scale end, set = function(v) QB.Settings().scale = v; QB.Layout() end },
            { label = L.QB_WIDTH, min = QB.MIN_W, max = QB.MAX_W, step = 10,
            get = function() return QB.Settings().width end, set = function(v) QB.Settings().width = v; QB.Layout() end } },
        -- moved: "auto" may now grow the other way
        onFollow = function() QB.Layout() end,
    })
    holder:SetFrameStrata("MEDIUM")
    holder:Hide()
end)
ns.On("LG_MOVERS", function() QB.Layout() end)
ns.On("LG_THEME", function() QB.Layout() end)

-- cards in Professions › Settings: what goes into the bar, and how it looks
function QB.SettingsCard(form)
    local q = QB.Settings
    local function on() return q().enabled end
    local s = form:Section(L.QB_TITLE)
    s:Note(L.QB_HINT, { col = 0, height = 44 })
    s:Toggle(L.QB_ENABLED, function() return q().enabled end, function(v) q().enabled = v; QB.Layout() end)
    s:Segment(L.QB_AUTO, { { value = "ask", text = L.QB_AUTO_ASK }, { value = "send", text = L.QB_AUTO_SEND } },
        function() return q().auto end, function(v) q().auto = v end,
        { width = 220, tip = L.QB_AUTO_TIP, show = on })
    -- which questions wait in the bar (off = answered by the addon as before)
    local function ask() return q().enabled and q().auto == "ask" end
    s:Toggle(L.QB_SHOW_GUILD, function() return q().guild end, function(v) q().guild = v end, { tip = L.QB_SHOW_GUILD_TIP, show = ask })
    s:Toggle(L.QB_SHOW_WHISPER, function() return q().whisper end, function(v) q().whisper = v end, { tip = L.QB_SHOW_WHISPER_TIP, show = ask })
    s:Toggle(L.QB_CRAFT, function() return q().craft end, function(v) q().craft = v end,
        { tip = L.QB_CRAFT_TIP, show = on })
    s:Toggle(L.QB_CRAFT_LINK, function() return q().craftLink end, function(v) q().craftLink = v end, { col = 2, tip = L.QB_CRAFT_LINK_TIP })
    s:Slider(L.QB_TTL, 10, 120, 5, function() return q().ttl end, function(v) q().ttl = v end,
        { col = 2, fmt = function(v) return ("%d s"):format(v) end, show = on })
    s:Buttons({ { L.NOTIFY_TEST, function() QB.Test() end, width = 140, icon = "sparkles" },
        { L.MOVE_ELEMENTS, function() ns.Window.ToggleMovers() end, width = 170, icon = "move" } }, { col = 0 })

    local function set(key) return function(v) q()[key] = v; QB.Layout() end end
    local look = form:Section(L.QB_LOOK, { grid = true, show = on })
    look:Dropdown(L.QB_GROW, function()
        local list = {}
        for _, g in ipairs({ "auto", "down", "up", "right", "left" }) do list[#list + 1] = { value = g, text = L["QB_GROW_" .. g] } end
        return list
    end, function() return q().grow end, set("grow"), { tip = L.QB_GROW_TIP })
    look:Segment(L.QB_STYLE, { { value = "full", text = L.QB_STYLE_full }, { value = "text", text = L.QB_STYLE_text },
        { value = "icons", text = L.QB_STYLE_icons } }, function() return q().style end, set("style"), { width = 240, tip = L.QB_STYLE_TIP })
    look:Segment(L.QB_ORDER, { { value = "newest", text = L.QB_ORDER_NEWEST }, { value = "oldest", text = L.QB_ORDER_OLDEST } },
        function() return q().order end, set("order"), { width = 220, tip = L.QB_ORDER_TIP })
    look:Slider(L.QB_MAX, 1, 8, 1, function() return q().max end, set("max"), { fmt = function(v) return ("%d"):format(v) end })
    look:Slider(L.QB_WIDTH, QB.MIN_W, QB.MAX_W, 10, function() return q().width end, set("width"),
        { fmt = function(v) return ("%d px"):format(v) end, show = function() return q().style ~= "icons" end })
    look:Slider(L.CD_SPACING, 0, 16, 1, function() return q().gap end, set("gap"), { fmt = function(v) return ("%d px"):format(v) end })
    look:Slider(L.CD_SCALE, 0.6, 1.6, 0.05, function() return q().scale end, set("scale"),
        { fmt = function(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end })
    look:Toggle(L.QB_SHOW_TIMER, function() return q().timer end, set("timer"), { tip = L.QB_SHOW_TIMER_TIP })
    look:Toggle(L.QB_SHOW_CLOSE, function() return q().close end, set("close"),
        { tip = L.QB_SHOW_CLOSE_TIP, show = function() return q().style ~= "icons" end })
    look:Toggle(L.QB_SHOW_MORE, function() return q().more end, set("more"), { tip = L.QB_SHOW_MORE_TIP })
    look:Buttons({ { L.NOTIFY_TEST, function() QB.TestLayout() end, width = 140, icon = "sparkles" } }, { col = 0 })
    return s
end
