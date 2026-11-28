-- Bug reports: Lua errors of this addon (only Liebe Grüße – other addons are
-- ignored) are caught, grouped by signature (same message and stack = one bug
-- with a counter) and offered as a small, non-blocking "Report bug" button.
-- The report (error, stack, count, version, character, zone, group, optional
-- note) goes to the guild master and officers as addon whisper. Nobody of them
-- online: it waits in a queue (SavedVariables) and goes out when one logs in.
-- Every officer gets it ("officer" = the officer ranks set in Guild admin, and
-- the guild master): a report stays queued until all of them confirmed it, and
-- officers who got it hand it on to the others (relay) – every officer's inbox
-- ends up with every report.
--   BR   report → officer (WHISPER, split into pieces by Comm); r.from on relays
--   BRA  "got it" → sender (WHISPER): out of the queue once every officer has it
-- The officers' inbox: Modules/BugInbox.lua (Guild admin › Bug reports).
local _, ns = ...
local Bugs = ns.NewModule("bugs")
ns.Bugs = Bugs
local UI, Theme, L, Names, Comm = ns.UI, ns.Theme, ns.L, ns.Names, ns.Comm

local MAX_STACK, MAX_MSG, MAX_QUEUE, MAX_SEEN = 2000, 300, 50, 40
local RESEND = 180

function Bugs.Settings()
    local s = ns.Database.Settings()
    s.bugs = s.bugs or {}
    local b = s.bugs
    if b.enabled == nil then b.enabled = true end
    if b.button == nil then b.button = true end
    if b.inboxToast == nil then b.inboxToast = true end
    b.send = b.send or "ask"
    b.seen = b.seen or {}
    b.queue = b.queue or {}
    return b
end

local function on() return ns.Database.Settings().modules.bugs ~= false end

-- test bugs (/lg test bug) live only in memory and are never sent
Bugs.testSeen = {}
local function seenStore(sig)
    if sig and Bugs.testSeen[sig] then return Bugs.testSeen end
    if Bugs.testing then return Bugs.testSeen end
    return Bugs.Settings().seen
end

---------------------------------------------------------------------------
-- Signature: the message without addresses/numbers that change every time,
-- plus the first lines of the stack (file and line)
---------------------------------------------------------------------------
local function hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return ("%08x"):format(h)
end

local function normalize(text)
    text = tostring(text or "")
    text = text:gsub("0x%x+", "0x"):gsub("table: [%x]+", "table"):gsub("function: [%x]+", "function"):gsub("Interface[\\/]AddOns[\\/]", "")
    return text
end

function Bugs.Signature(msg, stack)
    local lines, n = {}, 0
    for line in tostring(stack or ""):gmatch("[^\n]+") do
        if line:lower():find("liebegruesse") then
            n = n + 1
            lines[#lines + 1] = normalize(line):match("([%w_/\\%.]+%.lua%]?:%d+)") or ""
            if n >= 3 then break end
        end
    end
    return hash(normalize(msg) .. "|" .. table.concat(lines, "|"))
end

-- only errors that come from this addon's files
function Bugs.IsOwn(msg, stack)
    local hay = (tostring(msg or "") .. "\n" .. tostring(stack or "")):lower():gsub("\\", "/")
    return hay:find("addons/liebegruesse/", 1, true) ~= nil or hay:find("liebegruesse/", 1, true) ~= nil
end

-- short "file:line" of the error for lists
function Bugs.Where(msg, stack)
    local s = tostring(msg or "") .. "\n" .. tostring(stack or "")
    local file, line = s:gsub("\\", "/"):match("LiebeGruesse/([%w_/]+%.lua)%]?:(%d+)")
    return file and (file .. ":" .. line) or "?"
end

---------------------------------------------------------------------------
-- Capture
---------------------------------------------------------------------------
Bugs.session = {}       -- [sig] = count this session
local busy, last = false, { msg = nil, t = 0 }

function Bugs.Capture(msg, stack)
    if busy or not ns.db then return end
    busy = true
    local ok, err = pcall(function()
        if not on() or not Bugs.Settings().enabled then return end
        msg = tostring(msg or "?")
        -- the same error reported twice (our wrapper + the global handler) counts once
        if last.msg == msg and GetTime() - last.t < 0.2 then return end
        last.msg, last.t = msg, GetTime()
        if not Bugs.IsOwn(msg, stack) then return end
        local sig = Bugs.Signature(msg, stack)
        local seen = seenStore()
        local e = seen[sig]
        if not e then
            e = { sig = sig, m = msg:sub(1, MAX_MSG), st = tostring(stack or ""):sub(1, MAX_STACK), n = 0, first = ns.Now(), v = ns.version }
            seen[sig] = e
            -- only the newest bugs are kept
            local list = {}
            for k, x in pairs(seen) do list[#list + 1] = { k = k, t = x.last or x.first or 0 } end
            if #list > MAX_SEEN then
                table.sort(list, function(a, b) return a.t < b.t end)
                for i = 1, #list - MAX_SEEN do seen[list[i].k] = nil end
            end
        end
        e.n = e.n + 1
        e.last = ns.Now()
        e.v = ns.version
        if e.st == "" and stack then e.st = tostring(stack):sub(1, MAX_STACK) end
        Bugs.session[sig] = (Bugs.session[sig] or 0) + 1
        -- a new bug (or a known one after a new version) offers the button
        if not e.reported or e.reportedV ~= ns.version then
            if Bugs.Settings().send == "auto" then
                ns.After(1, function() Bugs.Submit(sig, nil) end)
            elseif Bugs.Settings().button then
                Bugs.pending = sig
                ns.AfterCombat("bug-button", Bugs.ShowButton)
            end
        elseif Bugs.button and Bugs.button:IsShown() then
            Bugs.ShowButton()
        end
    end)
    busy = false
    if not ok and print then print("LiebeGruesse bug capture: " .. tostring(err)) end
end

-- our own wrappers (ns.Safe / ns.Try) always report here
ns.OnOwnError = function(err, stack) Bugs.Capture(err, stack) end

-- the global error handler (chained: other error displays keep working)
do
    local get, set = geterrorhandler, seterrorhandler
    if type(get) == "function" and type(set) == "function" then
        local prev = get()
        local ok = pcall(set, function(msg, ...)
            local stack = debugstack and debugstack(2) or nil
            Bugs.Capture(msg, stack)
            if prev then return prev(msg, ...) end
        end)
        Bugs.hooked = ok and true or false
    end
end

---------------------------------------------------------------------------
-- The "Report bug" button (non-blocking, never during combat)
---------------------------------------------------------------------------
function Bugs.ShowButton()
    local sig = Bugs.pending
    local e = sig and seenStore(sig)[sig]
    if not e or not Bugs.Settings().button then return end
    if ns.InCombat() then ns.AfterCombat("bug-button", Bugs.ShowButton); return end
    if not Bugs.button then
        local b = UI.Panel(UIParent, "bg", "border")
        b:SetFrameStrata("DIALOG")
        b:SetHeight(32)
        b:SetClampedToScreen(true)
        b:EnableMouse(true)
        b:SetBackdropBorderColor(Theme.Color("bad"))
        b.icon = UI.Icon(b, "bug", 14, "bad"); b.icon:SetPoint("LEFT", 10, 0)
        b.text = UI.Text(b, 12, "text"); b.text:SetPoint("LEFT", b.icon, "RIGHT", 8, 0); b.text:SetWordWrap(false)
        b.report = UI.Button(b, L.BUG_REPORT_BTN, 110, 22, function() b:Hide(); Bugs.ShowDialog(Bugs.pending) end, "bug")
        b.report:SetPoint("LEFT", b.text, "RIGHT", 10, 0)
        b.close = UI.IconButton(b, "x", 16, function() b:Hide(); Bugs.dismissed = Bugs.pending end)
        b.close:SetPoint("LEFT", b.report, "RIGHT", 6, 0)
        b.close.tip = L.BUG_DISMISS_TIP
        Bugs.button = b
        ns.Movers.Attach("bugButton", b)
    end
    if Bugs.dismissed == sig then return end
    local b = Bugs.button
    b.text:SetText(L.BUG_BUTTON_TEXT .. Theme.HexColor("muted", ("  (×%d)"):format(e.n)))
    b:SetWidth(10 + 14 + 8 + (b.text:GetStringWidth() or 160) + 10 + 110 + 6 + 16 + 10)
    b:Show()
end

---------------------------------------------------------------------------
-- Report dialog: error, count, stack, "what were you doing?"
---------------------------------------------------------------------------
local dialog
local function createDialog()
    dialog = UI.Panel(UIParent, "bg", "border")
    UI.Float(dialog, "DIALOG")
    dialog:SetSize(620, 470)
    dialog:SetPoint("CENTER")
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog.tile = UI.Panel(dialog, "input", "bad"); dialog.tile:SetSize(34, 34); dialog.tile:SetPoint("TOPLEFT", 16, -16)
    dialog.icon = UI.Icon(dialog.tile, "bug", 18, "bad"); dialog.icon:SetPoint("CENTER")
    dialog.kicker = UI.Text(dialog, 11, "bad", nil, nil, true); dialog.kicker:SetPoint("TOPLEFT", 60, -16)
    dialog.kicker:SetText(ns.Upper(L.BUG_KICKER))
    dialog.title = UI.Text(dialog, 18, "text", nil, nil, true); dialog.title:SetPoint("TOPLEFT", 60, -30)
    dialog.title:SetText(L.BUG_TITLE)
    dialog.close = UI.IconButton(dialog, "x", 18, function() dialog:Hide() end); dialog.close:SetPoint("TOPRIGHT", -10, -10)
    dialog.msg = UI.Text(dialog, 13, "text"); dialog.msg:SetPoint("TOPLEFT", 16, -64); dialog.msg:SetWidth(588)
    dialog.msg:SetWordWrap(true); dialog.msg:SetJustifyV("TOP")
    dialog.meta = UI.Text(dialog, 11, "muted"); dialog.meta:SetPoint("TOPLEFT", 16, -100); dialog.meta:SetWidth(588); dialog.meta:SetWordWrap(false)
    -- the stack in a read-only box (selectable)
    local box = UI.Panel(dialog, "input", "borderDim")
    box:SetPoint("TOPLEFT", 16, -120); box:SetPoint("TOPRIGHT", -16, -120); box:SetHeight(150)
    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 8, -6); scroll:SetPoint("BOTTOMRIGHT", -8, 6)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetWidth(570)
    Theme.SetFont(edit, Theme.Font(), 11, "")
    edit:SetTextColor(Theme.Color("textDim"))
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnTextChanged", function(self, user) if user and dialog.stack then self:SetText(dialog.stack) end end)
    scroll:SetScrollChild(edit)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta) self:SetVerticalScroll(math.max(0, self:GetVerticalScroll() - delta * 30)) end)
    dialog.stackEdit = edit
    dialog.noteLabel = UI.Text(dialog, 12, "text"); dialog.noteLabel:SetPoint("TOPLEFT", 16, -282)
    dialog.noteLabel:SetText(L.BUG_NOTE .. Theme.HexColor("muted", "  " .. L.BUG_OPTIONAL))
    dialog.note = UI.EditBox(dialog, 588, 28, L.BUG_NOTE_PH)
    dialog.note:SetPoint("TOPLEFT", 16, -300)
    if dialog.note.SetMaxLetters then dialog.note:SetMaxLetters(200) end
    dialog.status = UI.Panel(dialog, "input", "borderDim")
    dialog.status:SetPoint("TOPLEFT", 16, -340); dialog.status:SetPoint("TOPRIGHT", -16, -340); dialog.status:SetHeight(44)
    dialog.statusIcon = UI.Icon(dialog.status, "users", 14, "lapis"); dialog.statusIcon:SetPoint("TOPLEFT", 10, -8)
    dialog.statusText = UI.Text(dialog.status, 12, "textDim"); dialog.statusText:SetPoint("TOPLEFT", 32, -7)
    dialog.statusText:SetWidth(548); dialog.statusText:SetWordWrap(true); dialog.statusText:SetJustifyV("TOP")
    dialog.copy = UI.Button(dialog, L.BUG_COPY, 120, 26, function()
        ns.Share.ShowText(L.BUG_COPY_TITLE, L.COPY_HINT, Bugs.CopyText(dialog.sig))
    end, "copy")
    dialog.copy:SetPoint("BOTTOMLEFT", 16, 16)
    dialog.sends = UI.Text(dialog, 11, "muted"); dialog.sends:SetPoint("LEFT", dialog.copy, "RIGHT", 10, 0)
    dialog.sends:SetText(L.BUG_SENDS); dialog.sends:SetWidth(200); dialog.sends:SetWordWrap(false)
    dialog.send = UI.Button(dialog, L.BUG_SEND, 140, 26, function()
        if Bugs.Submit(dialog.sig, dialog.note:GetText()) then dialog:Hide() end
    end, "bug")
    dialog.send:SetPoint("BOTTOMRIGHT", -16, 16)
    dialog.later = UI.Button(dialog, L.BUG_LATER, 100, 26, function() dialog:Hide() end)
    dialog.later:SetPoint("RIGHT", dialog.send, "LEFT", -8, 0)
    dialog:Hide()
end

function Bugs.ShowDialog(sig)
    local e = sig and seenStore(sig)[sig]
    if not e then return end
    if not dialog then createDialog() end
    dialog.sig = sig
    dialog.msg:SetText(e.m)
    local zone = ns.Call(GetRealZoneText)
    dialog.meta:SetText(L.BUG_META:format(e.n, date("%H:%M", e.first or 0), date("%H:%M", e.last or 0), e.v or ns.version,
        type(zone) == "string" and zone or "?"))
    dialog.stack = e.st ~= "" and e.st or L.BUG_NO_STACK
    dialog.stackEdit:SetText(dialog.stack)
    dialog.note:SetText("")
    local targets = Bugs.Targets()
    if Bugs.IsReceiver() then
        dialog.statusText:SetText(L.BUG_STATUS_SELF)
    elseif #targets > 0 then
        dialog.statusText:SetText(L.BUG_STATUS_ONLINE:format(#targets))
    else
        dialog.statusText:SetText(L.BUG_STATUS_QUEUE:format(#Bugs.Settings().queue + 1))
    end
    dialog:Show()
end

function Bugs.CopyText(sig)
    local e = sig and seenStore(sig)[sig]
    if not e then return "" end
    return ("%s %s · %s\n%s\n\n%s"):format(ns.title, e.v or ns.version, L.BUG_COUNT:format(e.n), e.m, e.st or "")
end

---------------------------------------------------------------------------
-- Sending and the queue
---------------------------------------------------------------------------
-- guild master and officers receive reports
function Bugs.IsReceiver(key)
    return IsInGuild() and ns.Guild.IsOfficer(key or Names.Me()) == true
end

-- online officers (not us), names to whisper, and a parallel list of keys.
-- "Officer" = every rank set as officer rank in Guild admin (and the guild master).
function Bugs.Targets()
    local list = {}
    for key, g in pairs(ns.Guild.members or {}) do
        if g.online and not Names.Same(key, Names.Me()) and ns.Guild.IsOfficer(key) then
            list[#list + 1] = { key = key, name = g.name or Names.Display(key) }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    local names, keys = {}, {}
    for i, x in ipairs(list) do names[i], keys[i] = x.name, x.key end
    return names, keys
end

-- every officer of the roster (online or not), without us and without `skip`
local function allOfficers(skip)
    local out = {}
    for key in pairs(ns.Guild.members or {}) do
        if not Names.Same(key, Names.Me()) and not (skip and Names.Same(key, skip)) and ns.Guild.IsOfficer(key) then
            out[#out + 1] = key
        end
    end
    return out
end

local function hasAck(r, key)
    if type(r.acked) ~= "table" then return false end
    for k in pairs(r.acked) do if Names.Same(k, key) then return true end end
    return false
end

-- done when every officer of the roster confirmed it (unknown roster: never)
local function delivered(r)
    if not next(ns.Guild.members or {}) then return false end
    for _, key in ipairs(allOfficers(r.from)) do
        if not hasAck(r, key) then return false end
    end
    return true
end
Bugs.Delivered = delivered

local function groupInfo()
    if IsInRaid() then return "raid " .. (GetNumGroupMembers() or 0) end
    if IsInGroup() then return "party " .. ((GetNumSubgroupMembers() or 0) + 1) end
    return "solo"
end

function Bugs.Build(sig, note)
    local e = Bugs.Settings().seen[sig]
    if not e then return nil end
    local zone = ns.Call(GetRealZoneText)
    local _, class = ns.Call(UnitClass, "player")
    note = tostring(note or ""):gsub("|", ""):gsub("[\r\n]+", " "):sub(1, 200)
    return { id = sig .. ":" .. (Names.Me() or "?") .. ":" .. ns.Now(), m = e.m, st = e.st, n = e.n, v = ns.version,
        c = class, lv = ns.Call(UnitLevel, "player"), z = type(zone) == "string" and zone:sub(1, 60) or nil, gr = groupInfo(),
        cb = ns.InCombat() and 1 or nil, note = note ~= "" and note or nil, t = ns.Now() }
end

-- a report waits in the queue until every officer has confirmed it (or 30 days)
local MAX_AGE = 30 * 86400
local function enqueue(r)
    local q = Bugs.Settings().queue
    for _, x in ipairs(q) do if x.id == r.id then return x end end
    q[#q + 1] = r
    while #q > MAX_QUEUE do table.remove(q, 1) end
    return r
end

-- an officer who got a report (or filed his own) hands it on to the other
-- officers: same id, so it counts once in every inbox; `from` is the reporter.
-- `got` = the officer we received it from (has it already).
function Bugs.Relay(r, fromKey, got)
    if type(r) ~= "table" or type(r.id) ~= "string" then return end
    local copy = {}
    for k, v in pairs(r) do if k ~= "sentAt" and k ~= "acked" and k ~= "k" then copy[k] = v end end
    copy.from = fromKey
    copy.relay = true
    copy.queuedAt = ns.Now()
    copy.acked = {}
    if got then copy.acked[got] = true end
    if delivered(copy) then return end
    enqueue(copy)
    Bugs.Flush(true)
end

function Bugs.Submit(sig, note)
    if sig and Bugs.testSeen[sig] then
        ns.Print(L.TEST_TAG .. " " .. L.BUG_TEST_NOT_SENT)
        if Bugs.button then Bugs.button:Hide() end
        return true
    end
    local r = Bugs.Build(sig, note)
    if not r then return false end
    local e = Bugs.Settings().seen[sig]
    e.reported, e.reportedV = ns.Now(), ns.version
    if Bugs.button then Bugs.button:Hide() end
    -- officers file their own reports directly – and hand them on to the other officers
    if Bugs.IsReceiver() and ns.BugInbox then
        ns.BugInbox.Receive(r, Names.Me())
        ns.Print(L.BUG_FILED_SELF)
        Bugs.Relay(r, Names.Me())
        return true
    end
    r.queuedAt = ns.Now()
    enqueue(r)
    Bugs.Flush(true)
    if #Bugs.Targets() == 0 then ns.Print(L.BUG_QUEUED) end
    return true
end

-- sends what waits in the queue to every online officer without receipt
function Bugs.Flush(force)
    local q = Bugs.Settings().queue
    if #q == 0 or not IsInGuild() then return 0 end
    for i = #q, 1, -1 do
        local t = q[i].queuedAt or q[i].t
        if (type(t) == "number" and ns.Now() - t > MAX_AGE) or delivered(q[i]) then table.remove(q, i) end
    end
    local names, keys = Bugs.Targets()
    if #names == 0 then return 0 end
    local sent = 0
    for _, r in ipairs(q) do
        if force or not r.sentAt or ns.Now() - r.sentAt > RESEND then
            local any = false
            for i, name in ipairs(names) do
                local key = keys[i]
                if not hasAck(r, key) and not (r.from and Names.Same(key, r.from)) then
                    local out = {}
                    for k, v in pairs(r) do if k ~= "sentAt" and k ~= "acked" and k ~= "queuedAt" then out[k] = v end end
                    Comm.Send("BR", { r = out }, "WHISPER", { target = name, priority = "bulk" })
                    any = true
                end
            end
            if any then r.sentAt = ns.Now(); sent = sent + 1 end
        end
    end
    return sent
end

-- receipt of an officer: he is not whispered again; out of the queue once
-- every officer has it
Comm.Register("BRA", function(data, sender, channel)
    if channel ~= "WHISPER" or type(data.id) ~= "string" or not ns.Guild.IsOfficer(sender) then return end
    local q = Bugs.Settings().queue
    for i = #q, 1, -1 do
        local r = q[i]
        if r.id == data.id then
            r.acked = type(r.acked) == "table" and r.acked or {}
            local first = next(r.acked) == nil
            r.acked[sender] = true
            if first and not r.relay then ns.Print(L.BUG_DELIVERED:format(Names.Display(sender))) end
            if delivered(r) then table.remove(q, i) end
        end
    end
end)

-- an officer comes online (roster update): try again, at most once a minute
local lastRoster = 0
ns.On("LG_ROSTER", function()
    if #Bugs.Settings().queue == 0 or GetTime() - lastRoster < 60 then return end
    lastRoster = GetTime()
    ns.After(5, function() Bugs.Flush() end)
end)
ns.On("LG_READY", function()
    ns.Movers.Anchor("bugButton", L.BUG_BUTTON_MOVER, { "BOTTOM", "BOTTOM", 0, 220 }, 360, 32, nil, { icon = "bug",
        settings = function() ns.Window.Show("notifications") end })
    ns.After(60, function() Bugs.Flush() end)
end)

-- /lg test bug: a sample error of this addon (caught like a real one, nothing sent)
function Bugs.Test()
    local stack = "[string \"@Interface/AddOns/LiebeGruesse/Modules/Runs/Sync.lua\"]:212: in function 'Validate'\n"
        .. "[string \"@Interface/AddOns/LiebeGruesse/Core/Init.lua\"]:80: in function 'Safe'"
    local msg = "Interface/AddOns/LiebeGruesse/Modules/Runs/Sync.lua:212: attempt to index field 'd' (a nil value) [test]"
    Bugs.testing = true
    Bugs.Capture(msg, stack)
    Bugs.testing = false
    local sig = Bugs.Signature(msg, stack)
    Bugs.pending = sig
    Bugs.dismissed = nil
    Bugs.ShowButton()
    Bugs.ShowDialog(sig)
end

-- /lg test bugs: what this client knows (nothing sent)
function Bugs.Report()
    local s = Bugs.Settings()
    local n = 0
    for _ in pairs(s.seen) do n = n + 1 end
    ns.Print(L.TEST_TAG .. " " .. L.BUG_REPORT_DIAG:format(n, #s.queue, #Bugs.Targets(), tostring(Bugs.hooked), tostring(Bugs.IsReceiver())))
end
