-- Loot master companion bar: the most used council actions in one small,
-- movable bar. Which buttons, layout, size and when it shows are configurable.
local _, ns = ...
local UI, Theme, L, Council = ns.UI, ns.Theme, ns.L, ns.Council
local Bar = {}
ns.CouncilBar = Bar

local function running() local s = Council.session; return s and not s.ended and s end
local function testing()
    local s = Council.session
    return (s and s.test and not s.ended) or (Bar.testUntil and GetTime() < Bar.testUntil) or not IsInGroup()
end
Bar.Testing = testing

-- every button stays clickable; when an action is not possible it says why
Bar.BUTTONS = {
    { key = "queue", icon = "scroll-text", text = function() return L.LCB_QUEUE:format(#Council.pending) end,
      tip = function() return L.LCB_TIP_QUEUE end,
      run = function() ns.CouncilWindow.ShowQueue() end },
    { key = "addAll", icon = "search", text = function() return L.LCB_ADD_ALL end,
      tip = function() return L.LCB_TIP_ADD_ALL end,
      run = function() ns.CouncilQueue.AddAll() end },
    { key = "start", icon = "chevron-right", text = function() return L.LCB_START end,
      tip = function()
          if running() then return L.LC_ALREADY_RUNNING end
          if #Council.pending == 0 then return L.LCB_TIP_START_EMPTY end
          return L.LCB_TIP_START:format(#Council.pending) .. (testing() and ("\n" .. L.LCB_TIP_TEST) or "")
      end,
      run = function()
          if running() then ns.Print(L.LC_ALREADY_RUNNING); ns.CouncilWindow.Toggle(); return end
          if #Council.pending == 0 then ns.CouncilQueue.AddAll() end
          if #Council.pending == 0 then ns.Print(L.LCB_NOTHING_QUEUED); ns.CouncilWindow.ShowQueue(); return end
          if testing() then Council.Start(Council.pending, true)
          elseif not Council.IAmLootMaster() then ns.Print(L.LC_START_NEED_ML)
          else Council.Start(Council.pending, false) end
      end },
    { key = "stop", icon = "x", text = function() return L.LCB_END end,
      tip = function() return running() and L.LCB_TIP_END or L.LCB_NO_SESSION end,
      run = function() if running() then Council.End() else ns.Print(L.LCB_NO_SESSION) end end },
    { key = "window", icon = "users", text = function() return L.LCB_WINDOW end,
      tip = function() return L.LCB_TIP_WINDOW end,
      run = function() ns.CouncilWindow.Toggle() end },
    { key = "reannounce", icon = "rotate-ccw", text = function() return L.LC_REANNOUNCE end,
      tip = function() return running() and L.LCB_TIP_REANNOUNCE or L.LCB_NO_SESSION end,
      run = function() if running() then Council.Reannounce() else ns.Print(L.LCB_NO_SESSION) end end },
    { key = "test", icon = "sparkles", text = function() return L.LC_TEST end,
      tip = function() return L.LCB_TIP_TEST_BUTTON end,
      run = function() Council.Test() end },
}

function Bar.Settings()
    local st = ns.Database.Settings()
    st.lcBar = st.lcBar or {}
    local o = st.lcBar
    local d = { enabled = true, onlyML = true, onlyRaid = false, vertical = false, labels = false, width = 96, height = 22, spacing = 2,
        scale = 1, alpha = 1 }
    for k, v in pairs(d) do if o[k] == nil then o[k] = v end end
    if o.dock == nil then o.dock = true end
    -- 0.7.5: slim by default (icons only, 22 px)
    if not o.slim then
        o.slim = true
        o.labels, o.width, o.height, o.spacing = false, 96, 22, 2
    end
    o.buttons = o.buttons or { queue = true, addAll = true, start = true, stop = true, window = true, reannounce = false, test = false }
    return o
end

local frame
local function create()
    frame = UI.Panel(UIParent, "bg", "border")
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame.items = {}
    ns.Movers.Attach("lcBar", frame)
    frame.grip = UI.Fill(frame, "accent", "ARTWORK")
    frame.grip:SetPoint("TOPLEFT"); frame.grip:SetPoint("BOTTOMLEFT"); frame.grip:SetWidth(3)
    frame.closeX = UI.IconButton(frame, "x", 14, function()
        Bar.closed = true
        frame:Hide()
        ns.Print(L.LCB_CLOSED)
    end)
    frame.closeX:SetPoint("LEFT", frame, "RIGHT", 2, 0)
    frame.closeX.tip = L.CLOSE
end

local function shouldShow(o)
    if not o.enabled or ns.Database.Settings().modules.council == false then return false end
    if ns.Movers.active then return true end
    if Bar.closed then return false end
    -- tests show the bar for a few minutes, so it can be tried without being loot master
    -- (a test session left open does not keep it on screen)
    if Bar.testUntil and GetTime() < Bar.testUntil then return true end
    -- only for the master looter of a group or raid (master loot must be on)
    if o.onlyRaid and not IsInRaid() then return false end
    return Council.IsMasterLooter()
end

function Bar.Layout()
    local o = Bar.Settings()
    if not frame then
        if not shouldShow(o) then return end
        create()
    end
    if not shouldShow(o) then frame:Hide(); return end
    -- docked: sits on top of the trade expiration timers and takes their width
    local tt = ns.TradeTimers and ns.TradeTimers.Settings()
    local ttAnchor = ns.Movers.anchors and ns.Movers.anchors.tradeTimers
    local docked = o.dock and tt and tt.enabled and ttAnchor ~= nil
    local count = 0
    for _, def in ipairs(Bar.BUTTONS) do if o.buttons[def.key] then count = count + 1 end end
    local w = o.labels and o.width or o.height
    if docked and not o.vertical and count > 0 then
        w = math.max(o.height, math.floor((tt.width * (tt.scale or 1) / (o.scale or 1) - 7 - (count - 1) * o.spacing) / count))
    end
    local n = 0
    for _, def in ipairs(Bar.BUTTONS) do
        if o.buttons[def.key] then
            n = n + 1
            local b = frame.items[n]
            if not b then
                b = UI.Button(frame, "", w, o.height, nil, def.icon)
                frame.items[n] = b
            end
            b:SetSize(w, o.height)
            b:SetScript("OnClick", function() ns.Safe(def.run); ns.After(0.2, Bar.Layout) end)
            b:SetText(o.labels and def.text() or "")
            if b.icon then
                Theme.SetIcon(b.icon, def.icon)
                b.icon:ClearAllPoints()
                if o.labels then b.icon:SetPoint("RIGHT", b.label, "LEFT", -6, 0) else b.icon:SetPoint("CENTER") end
            end
            b.def = def
            b.tipTitle = def.text()
            b.tip = nil
            b:SetEnabled(true)
            if not b.barHooked then
                b.barHooked = true
                -- refresh the tooltip text every time (counts and state change)
                b:HookScript("OnEnter", function(self)
                    if not self.def then return end
                    ns.TipOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText(self.def.text(), 1, 1, 1)
                    local line = self.def.tip and self.def.tip()
                    if line then GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
                    GameTooltip:Show()
                end)
            end
            b:ClearAllPoints()
                    if o.vertical then b:SetPoint("TOPLEFT", 5, -2 - (n - 1) * (o.height + o.spacing))
            else b:SetPoint("TOPLEFT", 5 + (n - 1) * (w + o.spacing), -2) end
            b:Show()
        end
    end
    for i = n + 1, #frame.items do frame.items[i]:Hide() end
    if o.vertical then frame:SetSize(w + 7, 4 + n * o.height + (n - 1) * o.spacing)
    else frame:SetSize(7 + n * w + (n - 1) * o.spacing, o.height + 4) end
    frame:SetScale(o.scale)
    frame:SetAlpha(o.alpha)
    frame:ClearAllPoints()
    if docked then
        frame:SetPoint("BOTTOMLEFT", ttAnchor.holder, "TOPLEFT", 0, 2)
    else
        frame:SetPoint("TOPLEFT", ns.Movers.anchors.lcBar and ns.Movers.anchors.lcBar.holder or UIParent, "TOPLEFT")
    end
    if ns.Movers.SetDisabled then ns.Movers.SetDisabled("lcBar", docked) end
    frame:SetShown(n > 0)
end

-- closed with the cross: back with the next loot method change or zone
ns.On("PARTY_LOOT_METHOD_CHANGED", function() Bar.closed = nil end)
ns.On("PLAYER_ENTERING_WORLD", function() Bar.closed = nil end)
for _, e in ipairs({ "LG_COUNCIL", "GROUP_ROSTER_UPDATE", "PARTY_LOOT_METHOD_CHANGED", "LG_MODULES", "PLAYER_ENTERING_WORLD", "LG_MOVERS" }) do
    ns.On(e, function() ns.Debounce("lc-bar", 0.3, Bar.Layout) end)
end
ns.On("LG_READY", function()
    ns.Movers.Anchor("lcBar", L.LCB_TITLE, { "BOTTOM", "BOTTOM", 0, 200 }, 130, 26, nil, { icon = "gem",
        onFollow = function() Bar.Layout() end,
        settings = function() ns.Window.Show("council"); if ns.CouncilPage then ns.CouncilPage.ShowSetup() end end,
        sizes = {
            { label = L.CD_SCALE, min = 0.5, max = 2, step = 0.05, get = function() return Bar.Settings().scale end,
              set = function(v) Bar.Settings().scale = v; Bar.Layout() end, pct = true },
            { label = L.LCB_BUTTON_WIDTH, min = 40, max = 220, step = 2, get = function() return Bar.Settings().width end,
              set = function(v) Bar.Settings().width = v; Bar.Layout() end },
            { label = L.LCB_BUTTON_HEIGHT, min = 14, max = 48, step = 1, get = function() return Bar.Settings().height end,
              set = function(v) Bar.Settings().height = v; Bar.Layout() end },
        },
    })
    ns.After(2, Bar.Layout)
end)
