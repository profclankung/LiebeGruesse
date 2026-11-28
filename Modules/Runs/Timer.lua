-- Speedrun timer on screen: instance, time, delta to the reference run, deaths
-- (+ penalty) and the splits – killed bosses with their delta, the next ones
-- of the reference run in grey. Movable ("Move elements" or its lock).
-- No secure frames: it may update in combat. The 0.1 s ticker runs only while
-- a run is going on; outside instances the frame is hidden.
local _, ns = ...
local Timer = {}
ns.RunsTimer = Timer
local UI, Theme, L = ns.UI, ns.Theme, ns.L
local Runs, Data = ns.Runs, ns.RunsData

local W, ROW = 250, 17
local frame, ticker

local function create()
    frame = UI.Panel(UIParent, "bg", "border")
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetWidth(W)
    frame.head = UI.Fill(frame, "header", "BACKGROUND")
    frame.head:SetPoint("TOPLEFT", 1, -1); frame.head:SetPoint("TOPRIGHT", -1, -1); frame.head:SetHeight(24)
    frame.icon = UI.Icon(frame, "flag", 13, "bronze"); frame.icon:SetPoint("TOPLEFT", 8, -6)
    frame.title = UI.Text(frame, 11, "bronze", nil, nil, true)
    frame.title:SetPoint("LEFT", frame.icon, "RIGHT", 6, 0)
    frame.title:SetWordWrap(false)
    frame.gear = UI.IconButton(frame, "settings", 16, function() ns.Window.Show("runs"); if ns.RunsPage then ns.RunsPage.ShowTab("settings") end end)
    -- cross: hides the timer for this run (tests: ends the test)
    frame.closeX = UI.IconButton(frame, "x", 16, function()
        if Timer.test then Timer.Test(true); return end
        local run = Runs.Active()
        if run then run.hideTimer = true end
        Timer.Update()
        ns.Print(L.RUN_TIMER_CLOSED)
    end)
    frame.closeX:SetPoint("TOPRIGHT", -4, -4)
    frame.closeX.tip = L.CLOSE
    frame.gear:SetPoint("RIGHT", frame.closeX, "LEFT", -4, 0)
    frame.gear.tip = L.MOVE_OPTIONS
    frame.lock = ns.Movers.LockButton("runTimer", frame, frame, 16)
    frame.lock:SetPoint("RIGHT", frame.gear, "LEFT", -4, 0)
    frame.time = UI.Text(frame, 28, "text", "LEFT", nil, true)
    frame.time:SetPoint("TOPLEFT", 10, -30)
    frame.delta = UI.Text(frame, 14, "good", "LEFT", nil, true)
    frame.delta:SetPoint("BOTTOMLEFT", frame.time, "BOTTOMRIGHT", 8, 3)
    frame.sub = UI.Text(frame, 11, "muted")
    frame.sub:SetPoint("TOPLEFT", 10, -64)
    frame.sub:SetWidth(W - 20)
    frame.sub:SetWordWrap(false)
    frame.bar = UI.Fill(frame, "borderDim", "ARTWORK"); frame.bar:SetHeight(2)
    frame.bar:SetPoint("TOPLEFT", 1, -82); frame.bar:SetPoint("TOPRIGHT", -1, -82)
    frame.fill = UI.Fill(frame, "accent", "OVERLAY"); frame.fill:SetHeight(2)
    frame.fill:SetPoint("TOPLEFT", frame.bar, "TOPLEFT")
    frame.rows = {}
    frame:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then ns.Window.Show("runs") end end)
    frame:Hide()
    ns.Movers.Attach("runTimer", frame)
end

local function row(i)
    local r = frame.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, frame)
    r:SetSize(W - 2, ROW)
    r.bg = UI.Fill(r, "accentDim", "BACKGROUND"); r.bg:SetAllPoints(); r.bg:Hide()
    r.name = UI.Text(r, 11, "text"); r.name:SetPoint("LEFT", 9, 0); r.name:SetWordWrap(false); r.name:SetWidth(W - 120)
    r.delta = UI.Text(r, 11, "good", "RIGHT", nil, true); r.delta:SetPoint("RIGHT", -8, 0); r.delta:SetWidth(46)
    r.time = UI.Text(r, 11, "text", "RIGHT", nil, true); r.time:SetPoint("RIGHT", r.delta, "LEFT", -4, 0); r.time:SetWidth(50)
    frame.rows[i] = r
    return r
end

local function colorDelta(fs, d)
    if not d then fs:SetText(""); return end
    fs:SetText(Runs.Delta(d))
    fs:SetTextColor(Theme.Color(d <= 0 and "good" or "bad"))
end

-- the sample shown in "Move elements" and by /lg test runtimer
local function sample()
    local base = Timer.test or {}
    return base.run or { n = Data.Name("stratlive"), i = 329, start = 1, s = {
        { e = 472, b = "The Unforgiven", s = 252 }, { e = 2798, b = "Postmaster Malown", s = 590 }, { e = 474, b = "Timmy the Cruel", s = 958 } },
        d = 1 }, base.ref or { s = { { b = "The Unforgiven", s = 266 }, { b = "Postmaster Malown", s = 571 }, { b = "Timmy the Cruel", s = 950 },
        { b = "Archivist Galford", s = 1210 }, { b = "Balnazzar", s = 1450 } } }, base.elapsed or 984
end

function Timer.Update()
    local o = Runs.Settings()
    local run = Runs.Active()
    local live = run and run.start and not run.fin and not run.hideTimer and Runs.Here() == run.i
    local show = (o.timer and ns.Database.Settings().modules.runs ~= false and live) or ns.Movers.active or Timer.test
    if not show then
        if frame then frame:Hide() end
        if ticker then ticker:Cancel(); ticker = nil end
        return
    end
    if not frame then create() end
    local ref, elapsed
    if live and not Timer.test then
        ref, elapsed = Runs.Reference(run), Runs.Elapsed(run)
    else
        run, ref, elapsed = sample()
    end
    local pen = Runs.Penalty()
    frame.title:SetText(ns.Upper(run.n or "?"))
    frame.title:SetWidth(W - 90)
    frame.time:SetText(Runs.Format(elapsed + (run.d or 0) * pen))
    -- headline delta: the last split against the reference
    local lastDelta
    for _, sp in ipairs(run.s or {}) do
        local rs = Runs.SplitOf(ref, sp.b)
        if rs then lastDelta = sp.s - rs end
    end
    colorDelta(frame.delta, lastDelta)
    local sub = {}
    sub[#sub + 1] = L.RUN_TIMER_DEATHS:format(run.d or 0) .. (pen > 0 and ((run.d or 0) > 0) and (" · +" .. Runs.Format((run.d or 0) * pen)) or "")
    if ref then sub[#sub + 1] = L.RUN_TIMER_REF:format(Runs.Format(Runs.Final(ref))) end
    frame.sub:SetText(table.concat(sub, "  ·  "))
    local refEnd = ref and ref.s and ref.s[#ref.s] and ref.s[#ref.s].s
    local progress = refEnd and refEnd > 0 and math.min(1, elapsed / refEnd) or 0
    frame.fill:SetWidth(math.max(1, (W - 2) * progress))
    local n = 0
    local hideRows = o.hideCombat and ns.InCombat() and not Timer.test and not ns.Movers.active
    if o.splits and not hideRows then
        local killed = {}
        for _, sp in ipairs(run.s or {}) do
            n = n + 1
            local r = row(n)
            killed[sp.b] = true
            r.name:SetText(Data.BossName(sp.b or "?")); r.name:SetTextColor(Theme.Color("text"))
            r.time:SetText(Runs.Format(sp.s)); r.time:SetTextColor(Theme.Color("text"))
            local rs = Runs.SplitOf(ref, sp.b)
            colorDelta(r.delta, rs and (sp.s - rs) or nil)
            r.bg:Hide()
        end
        local first = true
        for _, sp in ipairs(ref and ref.s or {}) do
            if not killed[sp.b] and n < (o.rows or 6) + #run.s then
                n = n + 1
                local r = row(n)
                r.name:SetText(Data.BossName(sp.b or "?")); r.name:SetTextColor(Theme.Color(first and "text" or "muted"))
                r.time:SetText(Runs.Format(sp.s)); r.time:SetTextColor(Theme.Color("muted"))
                r.delta:SetText("")
                r.bg:SetShown(first)
                first = false
            end
        end
        -- only the last rows when the list is long
        local maxRows = math.max(3, o.rows or 6)
        local skip = math.max(0, n - maxRows)
        local shownRows = 0
        for i = 1, n do
            local r = frame.rows[i]
            if i > skip then
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 1, -86 - shownRows * ROW)
                r:Show()
                shownRows = shownRows + 1
            else
                r:Hide()
            end
        end
        n = shownRows
        for i = #frame.rows, 1, -1 do if i > skip + shownRows then frame.rows[i]:Hide() end end
    else
        for _, r in ipairs(frame.rows) do r:Hide() end
    end
    frame:SetHeight(88 + n * ROW + 4)
    frame:SetScale(o.scale or 1)
    frame:Show()
    if live and not ticker then
        ticker = C_Timer.NewTicker(0.5, function() ns.Safe(Timer.Tick) end)
    elseif not live and ticker then
        ticker:Cancel(); ticker = nil
    end
end

-- cheap update of the running time only
function Timer.Tick()
    local run = Runs.Active()
    if not frame or not run or not run.start or run.fin then return Timer.Update() end
    frame.time:SetText(Runs.Format(Runs.Elapsed(run) + (run.d or 0) * Runs.Penalty()))
end

-- /lg test runtimer: the timer with sample data for 30 s
function Timer.Test(off)
    if off then Timer.test = nil else Timer.test = {} end
    Timer.Update()
    if not off then ns.After(30, function() Timer.test = nil; Timer.Update() end) end
end

ns.On("LG_RUNS", function() ns.Debounce("runs-timer", 0.05, Timer.Update) end)
ns.On("LG_MOVERS", Timer.Update)
ns.On("PLAYER_REGEN_DISABLED", function() if Runs.Settings().hideCombat then Timer.Update() end end)
ns.On("PLAYER_REGEN_ENABLED", function() if Runs.Settings().hideCombat then Timer.Update() end end)
ns.On("LG_READY", function()
    ns.Movers.Anchor("runTimer", L.RUN_TIMER, { "TOPLEFT", "TOPLEFT", 40, -220 }, W, 150, nil, { icon = "flag", scalable = true,
        settings = function() ns.Window.Show("runs"); if ns.RunsPage then ns.RunsPage.ShowTab("settings") end end })
    ns.After(3, Timer.Update)
end)
