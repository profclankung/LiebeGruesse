-- "Test suite" page: every "/lg test …" command as a row, grouped by module
-- (the guide's topics), with a Run button – or a switch for tests that keep
-- running (registry fields toggle/active/stop/duration in Core/Slash.lua).
-- Built from the registry, so new tests show up here without changes.
local _, ns = ...
local UI, Theme, L = ns.UI, ns.Theme, ns.L

local Suite = {}
ns.TestSuite = Suite

local ROW_MIN, CONTROL_W = 44, 96

-- area of a test without a guide entry of its own: the word after "test"
local AREA_RULES = {
    { "^bless", "blessings" }, { "^lc", "council" }, { "^bar$", "council" }, { "^trade", "trade" },
    { "^cd$", "cooldowns" }, { "^feed", "feed" }, { "^toast$", "feed" },
    { "^craft", "professions" }, { "^price", "professions" }, { "^shop", "professions" }, { "^prof", "professions" },
    { "^quick", "professions" },
    { "^failpull", "raidnight" }, { "^mispull", "raidnight" }, { "^death", "raidnight" }, { "^consum", "raidnight" },
    { "^notify", "notify" }, { "^announce", "notify" }, { "^messages", "notify" },
    { "^who$", "coguild" }, { "^partner", "coguild" },
    { "^armory", "roster" }, { "^model", "roster" }, { "^compare", "roster" },
    { "^changelog", "versions" }, { "^update", "versions" },
    { "^font", "look" }, { "^move", "look" }, { "^board", "community" }, { "^badge", "community" },
}

-- the test group of the command registry
local function testGroup()
    for _, g in ipairs(ns.Commands or {}) do if g.key == "test" then return g end end
end

-- guide topic of a test: own field, the guide's test/commands, the rules, else "start"
local function areaOf(c, guide)
    if c.area and guide[c.area] then return c.area end
    local cmd = "/lg " .. c.cmd
    for _, e in ipairs(ns.Guide and ns.Guide.LIST or {}) do
        if e.test == c.cmd then return e.key end
        for _, x in ipairs(e.cmds or {}) do
            if x == cmd or x:sub(1, #cmd + 1) == cmd .. " " then return e.key end
        end
    end
    local word = c.cmd:match("^test%s+(%S+)") or ""
    for _, r in ipairs(AREA_RULES) do
        if word:find(r[1]) and guide[r[2]] then return r[2] end
    end
    return "start"
end

-- running state of a switch test (errors count as "not running")
function Suite.IsActive(c)
    return c.toggle and c.active and ns.Try(c.active) and true or false
end

-- every switch test that is running is stopped; returns how many
function Suite.StopAll()
    local g, n = testGroup(), 0
    for _, c in ipairs(g and g.commands or {}) do
        if Suite.IsActive(c) and c.stop then ns.Safe(c.stop); n = n + 1 end
    end
    if Suite.Refresh then Suite.Refresh() end
    return n
end

UI.AddPage("tests", L.PAGE_TESTS, 97.5, function(content, page)
    page.head = L.HEAD_TESTS
    page.searchHint = L.TESTS_SEARCH
    local group = testGroup() or { commands = {} }

    -- top row: how many tests (and running ones), "Stop all tests"
    local top = CreateFrame("Frame", nil, content)
    top:SetPoint("TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", -8, 0)
    top:SetHeight(28)
    top.icon = UI.Icon(top, "badge-check", 14, "bronze")
    top.icon:SetPoint("LEFT", 2, 0)
    top.text = UI.Text(top, 12, "textDim", "LEFT")
    top.text:SetPoint("LEFT", top.icon, "RIGHT", 8, 0)
    top.stop = UI.Button(top, L.TESTS_STOP_ALL, 140, 26, function()
        local n = Suite.StopAll()
        ns.Print(L.TEST_TAG .. " " .. (n > 0 and L.TESTS_STOPPED:format(n) or L.TESTS_NONE_RUNNING))
    end, "x")
    top.stop:SetPoint("RIGHT", 0, 0)
    top.stop.tip = { L.TESTS_STOP_ALL_TIP }
    top.text:SetPoint("RIGHT", top.stop, "LEFT", -12, 0)
    top.text:SetWordWrap(false)

    local form = UI.Form(content)
    form.noIndex = true   -- the global search finds the tests as commands
    form.scroll:SetPoint("TOPLEFT", 0, -38)
    form.scroll:SetPoint("BOTTOMRIGHT", -8, 0)
    page.Search = function(text) return form:Filter(text) end
    page.SearchEnter = function() form:JumpFirst() end

    -- sections in guide order ("start" = general & diagnostics first)
    local guide, order, byArea = {}, {}, {}
    for _, e in ipairs(ns.Guide and ns.Guide.LIST or {}) do guide[e.key] = e end
    for _, c in ipairs(group.commands) do
        if c.suite ~= false then
            local key = areaOf(c, guide)
            if not byArea[key] then byArea[key] = {} end
            table.insert(byArea[key], c)
        end
    end
    for _, e in ipairs(ns.Guide and ns.Guide.LIST or {}) do
        if byArea[e.key] then order[#order + 1] = e.key end
    end

    local switches, total = {}, 0
    local function refreshTop()
        local running = 0
        for _, c in ipairs(switches) do if Suite.IsActive(c) then running = running + 1 end end
        top.text:SetText(L.TESTS_COUNT:format(total) .. "  ·  "
            .. (running > 0 and Theme.HexColor("accent", L.TESTS_RUNNING_N:format(running)) or L.TESTS_NONE_RUNNING))
    end
    function Suite.Refresh()
        if not ns.Window.IsShown("tests") then return end
        form:Refresh()
        refreshTop()
    end
    -- timed tests end by themselves: look again once they are over
    local function later(c)
        if c.duration then ns.After(c.duration + 1, Suite.Refresh) end
        ns.After(0.3, Suite.Refresh)
    end

    local function row(section, c)
        local f = CreateFrame("Frame")
        local text = ns.CommandText(c, group)
        local needsInput = c.args and c.args:sub(1, 1) == "<"
        f.hover = UI.Fill(f, "hover", "BACKGROUND")
        f.hover:SetPoint("TOPLEFT", 1, 0); f.hover:SetPoint("BOTTOMRIGHT", -1, 0)
        f.hover:Hide()
        f.name = UI.Text(f, 12, "accent", "LEFT")
        f.name:SetPoint("TOPLEFT", 16, -8)
        f.name:SetWordWrap(false)
        f.desc = UI.Text(f, 11, "textDim", "LEFT")
        f.desc:SetPoint("TOPLEFT", 16, -25)
        f.desc:SetWordWrap(true)
        f.desc:SetJustifyV("TOP")
        f.desc:SetText(c.desc or "")
        f.name:SetText(text)
        local control
        if c.toggle then
            control = UI.Toggle(f, function() return Suite.IsActive(c) end, function(v)
                if v then ns.Safe(c.run, "") elseif c.stop then ns.Safe(c.stop) end
                later(c)
            end)
            control:SetPoint("RIGHT", -16, 0)
            f.state = UI.Text(f, 10, "accent", "RIGHT")
            f.state:SetPoint("RIGHT", control, "LEFT", -8, 0)
            f.state:SetText(L.TESTS_RUNNING)
            local refresh = control.Refresh
            function control:Refresh() refresh(self); f.state:SetShown(self.on) end
            control:Refresh()
            switches[#switches + 1] = c
            -- like a settings switch: a click on the row flips it
            f:SetScript("OnMouseUp", function() control:Click() end)
        else
            control = UI.Button(f, L.TESTS_RUN, 70, 24, function()
                if needsInput then
                    if ChatFrame_OpenChat then ChatFrame_OpenChat(text:gsub("%s*[<%[].*$", "") .. " ") end
                else
                    ns.Safe(c.run, "")
                    later(c)
                end
            end, "chevron-right")
            control:SetPoint("RIGHT", -14, 0)
            control.tip = { needsInput and L.TESTS_TIP_INPUT or L.TESTS_TIP_RUN }
        end
        -- options ("[recipe]", "[raw]"): into the chat box to type them ("[off]" is the switch)
        if c.args and not (c.toggle and c.args == "[off]") then
            f.chat = UI.IconButton(f, "message-circle", 22, function()
                if ChatFrame_OpenChat then ChatFrame_OpenChat(text:gsub("%s*[<%[].*$", "") .. " ") end
            end)
            f.chat:SetPoint("RIGHT", f, "RIGHT", -(14 + CONTROL_W - 4), 0)
            f.chat.tip = L.TESTS_CHAT
            f.chat.tipLines = { text }
        end
        f:EnableMouse(true)
        f:SetScript("OnEnter", function(self)
            self.hover:Show()
            local lines = { c.desc or "", " " }
            if c.toggle then lines[#lines + 1] = Suite.IsActive(c) and L.TESTS_TIP_STOP or L.TESTS_TIP_START
            else lines[#lines + 1] = needsInput and L.TESTS_TIP_INPUT or L.TESTS_TIP_RUN end
            UI.Tooltip(self, text, lines)
        end)
        f:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip:Hide() end)
        -- name and description wrap to the card width (called by the form layout)
        function f:Flow(width)
            local w = math.max(60, width - 16 - CONTROL_W - 14 - (self.chat and 30 or 0))
            self.name:SetWidth(w)
            self.desc:SetWidth(w)
            self:SetHeight(math.max(ROW_MIN, 25 + (self.desc:GetStringHeight() or 12) + 9))
        end
        function f:Highlight(q)
            self.name:SetText(q and ns.Highlight(text, q, "text") or text)
            self.desc:SetText(q and ns.Highlight(c.desc or "", q) or (c.desc or ""))
        end
        local _, r = section:Custom(f, ROW_MIN)
        r.searchTitle = text
        r.searchText = text .. " " .. (c.desc or "")
        r.control = control
        total = total + 1
    end

    for _, key in ipairs(order) do
        local e = guide[key]
        local section = form:Section(key == "start" and L.TESTS_AREA_GENERAL or e.name)
        for _, c in ipairs(byArea[key]) do row(section, c) end
        -- cards may sit in two columns when the window is wide
        section.wide = nil
    end

    -- switches follow tests started elsewhere (chat, other pages)
    for _, event in ipairs({ "LG_BLESSINGS", "LG_COOLDOWNS", "LG_MOVERS", "LG_COUNCIL", "LG_COGUILD" }) do
        ns.On(event, function()
            if ns.Window.IsShown("tests") then ns.Debounce("test-suite", 0.3, Suite.Refresh) end
        end)
    end

    form:Layout()
    refreshTop()
    page.OnShow = function() form:Refresh(); refreshTop() end
end, { section = "settings", icon = "badge-check" })

---------------------------------------------------------------------------
-- Small popup while a test keeps running: which tests, "Stop tests" (no
-- /reload needed). The cross hides it until every test has ended. It looks
-- once a second only while a test runs (nothing at all otherwise).
---------------------------------------------------------------------------
local Popup = {}
ns.TestPopup = Popup
local frame, ticker

function Popup.Running()
    local list = {}
    for _, g in ipairs(ns.Commands or {}) do
        if g.key == "test" then
            for _, c in ipairs(g.commands) do if Suite.IsActive(c) then list[#list + 1] = c end end
        end
    end
    return list
end

local function create()
    frame = UI.Panel(UIParent, "bg", "accent")
    UI.Float(frame, "DIALOG")
    frame:SetSize(300, 64)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame.stripe = UI.Fill(frame, "accent", "ARTWORK")
    frame.stripe:SetPoint("TOPLEFT"); frame.stripe:SetPoint("BOTTOMLEFT"); frame.stripe:SetWidth(3)
    frame.icon = UI.Icon(frame, "zap", 14, "accent"); frame.icon:SetPoint("TOPLEFT", 12, -10)
    frame.kicker = UI.Text(frame, 11, "accent", nil, nil, true); frame.kicker:SetPoint("LEFT", frame.icon, "RIGHT", 8, 0)
    frame.names = UI.Text(frame, 12, "text"); frame.names:SetPoint("TOPLEFT", 12, -30)
    frame.names:SetWidth(170); frame.names:SetWordWrap(false)
    frame.stop = UI.Button(frame, L.TESTPOP_STOP, 104, 24, function()
        local n = Suite.StopAll()
        ns.Print(L.TESTS_STOPPED:format(n))
        Popup.Check()
    end, "x")
    frame.stop:SetPoint("BOTTOMRIGHT", -10, 10)
    frame.stop.tip = { L.TESTPOP_STOP_TIP }
    UI.CloseX(frame, function() Popup.dismissed = true; frame:Hide() end, 16, -6, -6)
    frame.closeX.tip = L.TESTPOP_HIDE
    ns.Movers.Attach("testPopup", frame)
end

function Popup.Check()
    local list = Popup.Running()
    if #list == 0 then
        Popup.dismissed = nil
        if frame then frame:Hide() end
        if ticker then ticker:Cancel(); ticker = nil end
        return
    end
    if not ticker then ticker = C_Timer.NewTicker(1, function() ns.Safe(Popup.Check) end) end
    if Popup.dismissed then if frame then frame:Hide() end return end
    if not frame then create() end
    local names = {}
    for _, c in ipairs(list) do names[#names + 1] = (c.cmd:gsub("^test%s*", "")) end
    frame.kicker:SetText(ns.Upper(#list == 1 and L.TESTPOP_ONE or L.TESTPOP_N:format(#list)))
    frame.names:SetText("/lg test " .. table.concat(names, ", "))
    frame:Show()
end

ns.On("LG_READY", function()
    ns.Movers.Anchor("testPopup", L.TESTPOP_MOVER, { "TOP", "TOP", 0, -64 }, 300, 64, nil, { icon = "zap" })
end)
