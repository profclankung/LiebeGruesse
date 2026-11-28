-- Bug inbox for the guild master and officers (Guild admin › Bug reports):
-- reports from guild members, grouped by signature (same error from several
-- players = one entry with a counter, the players and their notes), with
-- status New / Seen / Solved. A solved bug that comes back in a newer version
-- is new again. Stack copy: a box with the text selected (Ctrl+C).
-- Entries are kept (SavedVariables, per guild) until an officer deletes them –
-- nothing is removed automatically.
local _, ns = ...
local Inbox = {}
ns.BugInbox = Inbox
local UI, Theme, L, Names, Comm = ns.UI, ns.Theme, ns.L, ns.Names, ns.Comm

local MAX_NOTES, MAX_IDS = 10, 60
-- "all": a bug that was opened (seen) must not vanish from the default view
local state = { filter = "all", selected = nil }
Inbox.state = state

local function store()
    local g = ns.Database.Guild()
    g.bugs = g.bugs or {}
    return g.bugs
end
Inbox.Store = store

function Inbox.Count(status)
    local n = 0
    for _, b in pairs(store()) do if not status or b.status == status then n = n + 1 end end
    return n
end

local function clip(v, n) return type(v) == "string" and v:gsub("|", ""):sub(1, n) or nil end

-- a report from `sender` (key); returns the bug entry
function Inbox.Receive(r, sender)
    if type(r) ~= "table" or type(r.m) ~= "string" then return nil end
    local m, st = clip(r.m, 300), clip(r.st, 2000) or ""
    local sig = ns.Bugs.Signature(m, st)
    local bugs = store()
    local b = bugs[sig]
    local v = clip(r.v, 12) or "?"
    -- the same report (direct and relayed by an officer, or sent twice) counts once – also after a reload
    local id = type(r.id) == "string" and r.id:sub(1, 80) or nil
    if b and id and type(b.ids) == "table" and b.ids[id] then return b, true end
    if not b then
        b = { sig = sig, m = m, st = st, n = 0, players = {}, notes = {}, first = ns.Now(), status = "new",
            where = ns.Bugs.Where(m, st), ids = {} }
        bugs[sig] = b
        if ns.Bugs.Settings().inboxToast then
            UI.Toast(L.BUG_INBOX_KICKER, m, nil, { kicker = L.BUG_INBOX_KICKER, lines = { L.BUG_INBOX_FROM:format(Names.Display(sender)) },
                page = "admin", action = function() Inbox.Open() end, actionText = L.BUG_INBOX_CLICK })
        end
    elseif b.status == "solved" and b.solvedV and ns.CompareVersions(v, b.solvedV) > 0 then
        b.status = "new"
    end
    if id then
        b.ids = type(b.ids) == "table" and b.ids or {}
        b.idOrder = type(b.idOrder) == "table" and b.idOrder or {}
        b.ids[id] = true
        b.idOrder[#b.idOrder + 1] = id
        while #b.idOrder > MAX_IDS do b.ids[table.remove(b.idOrder, 1)] = nil end
    end
    local n = math.max(1, math.min(10000, tonumber(r.n) or 1))
    b.n = b.n + n
    b.players[sender] = (b.players[sender] or 0) + n
    b.last = ns.Now()
    if not b.v or ns.CompareVersions(v, b.v) > 0 then b.v = v end
    b.z, b.gr, b.lv, b.c, b.cb = clip(r.z, 60), clip(r.gr, 20), tonumber(r.lv), clip(r.c, 12), r.cb and 1 or nil
    b.by = sender
    if r.test then b.test = true end
    local note = clip(r.note, 200)
    if note and note ~= "" then
        b.notes[#b.notes + 1] = { k = sender, x = note, t = ns.Now() }
        while #b.notes > MAX_NOTES do table.remove(b.notes, 1) end
    end
    ns.Fire("LG_BUGS")
    return b
end

function Inbox.SetStatus(sig, status)
    local b = store()[sig]
    if not b then return end
    b.status = status
    if status == "solved" then b.solvedV = b.v end
    ns.Fire("LG_BUGS")
end

function Inbox.Delete(sig) store()[sig] = nil; ns.Fire("LG_BUGS") end
function Inbox.DeleteAll() wipe(store()); state.selected = nil; ns.Fire("LG_BUGS") end

-- reports: only to officers, only from guild members, at most 10 per player
-- in 10 minutes (officers handing reports on are not limited). No receipt
-- while guild or roster are not known yet (right after login): the sender
-- tries again and nothing gets lost.
local recent = {}
Comm.Register("BR", function(data, sender, channel, raw)
    if channel ~= "WHISPER" or not ns.Database.GuildKey() or not ns.Bugs.IsReceiver() or not ns.Guild.IsMember(sender) then return end
    local r = type(data.r) == "table" and data.r
    if not r or type(r.id) ~= "string" or #r.id > 80 then return end
    local officer = ns.Guild.IsOfficer(sender)
    -- relayed by an officer: counts for the player who reported it
    local from = sender
    if officer and type(r.from) == "string" and r.from ~= "" then
        local key = Names.Key(r.from)
        if key and (ns.Guild.IsMember(key) or Names.Same(key, Names.Me())) then from = key end
    end
    if not officer then
        local now = GetTime()
        local list = recent[sender] or {}
        for i = #list, 1, -1 do if now - list[i] > 600 then table.remove(list, i) end end
        if #list >= 10 then return end
        list[#list + 1] = now
        recent[sender] = list
    end
    local b, dup = Inbox.Receive(r, from)
    if not b then return end
    Comm.Send("BRA", { id = r.id }, "WHISPER", { target = raw, priority = "normal" })
    -- a new report goes on to the other officers (who have it already confirm and skip it)
    if not dup then ns.Bugs.Relay(r, from, sender) end
end)

function Inbox.Open()
    ns.Window.Show("admin")
    if Inbox.ShowTab then Inbox.ShowTab() end
end

---------------------------------------------------------------------------
-- The tab (built by Modules/Admin.lua)
---------------------------------------------------------------------------
local STATUS_COLOR = { new = "accent", seen = "lapis", solved = "good" }

function Inbox.Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    local chips = UI.FilterChips(f, {
        { value = "all", text = L.BUG_FILTER_ALL, icon = "bug" },
        { value = "new", text = L.BUG_STATUS_NEW, icon = "bug" },
        { value = "seen", text = L.BUG_STATUS_SEEN, icon = "eye" },
        { value = "solved", text = L.BUG_STATUS_SOLVED, icon = "check" },
    }, function() return state.filter end, function(v) state.filter = v; f.Refresh() end)
    chips:SetPoint("TOPLEFT")
    local delAll = UI.Button(f, L.BUG_DELETE_ALL, 120, 24, function()
        StaticPopupDialogs.LIEBEGRUESSE_BUGS_CLEAR = {
            text = L.BUG_DELETE_ALL_CONFIRM, button1 = YES or "Yes", button2 = NO or "No",
            OnAccept = function() Inbox.DeleteAll() end, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
        StaticPopup_Show("LIEBEGRUESSE_BUGS_CLEAR")
    end, "trash-2")
    delAll:SetPoint("TOPRIGHT")
    delAll.tip = { L.BUG_DELETE_ALL_TIP }

    -- detail on the right
    local DETAIL_W = 360
    local d = UI.Panel(f, "panel", "borderDim")
    d:SetPoint("TOPRIGHT", 0, -32)
    d:SetPoint("BOTTOMRIGHT")
    d:SetWidth(DETAIL_W)
    d.empty = UI.Empty(d, 300); d.empty:SetPoint("CENTER")
    d.status = UI.Segmented(d, 210, { { value = "new", text = L.BUG_STATUS_NEW }, { value = "seen", text = L.BUG_STATUS_SEEN },
        { value = "solved", text = L.BUG_STATUS_SOLVED } }, function() return d.b and d.b.status end,
        function(v) if d.b then Inbox.SetStatus(d.b.sig, v) end end)
    d.status:SetPoint("TOPRIGHT", -12, -12)
    d.tag = UI.Text(d, 11, "accent", nil, nil, true); d.tag:SetPoint("TOPLEFT", 12, -17)
    d.msg = UI.Text(d, 13, "text"); d.msg:SetPoint("TOPLEFT", 12, -46); d.msg:SetWordWrap(true); d.msg:SetJustifyV("TOP")
    d.where = UI.Text(d, 11, "muted"); d.where:SetPoint("TOPLEFT", d.msg, "BOTTOMLEFT", 0, -4); d.where:SetWordWrap(false)
    d.meta = UI.Text(d, 11, "textDim"); d.meta:SetPoint("TOPLEFT", d.where, "BOTTOMLEFT", 0, -10)
    d.meta:SetWordWrap(true); d.meta:SetJustifyV("TOP"); d.meta:SetSpacing(4)
    d.stackTitle = UI.Text(d, 12, "bronze", nil, nil, true); d.stackTitle:SetPoint("TOPLEFT", d.meta, "BOTTOMLEFT", 0, -14)
    d.stackTitle:SetText(ns.Upper(L.BUG_STACK))
    d.copy = UI.Button(d, L.BUG_COPY, 90, 22, function()
        if d.b then ns.Share.ShowText(L.BUG_COPY_TITLE, L.COPY_HINT, Inbox.CopyText(d.b)) end
    end, "copy")
    d.stack = UI.Panel(d, "input", "borderDim")
    d.stack:SetPoint("TOPLEFT", d.stackTitle, "BOTTOMLEFT", 0, -8)
    d.stack:SetHeight(120)
    d.stackText = UI.Text(d.stack, 10, "textDim"); d.stackText:SetPoint("TOPLEFT", 8, -6)
    d.stackText:SetWordWrap(true); d.stackText:SetJustifyV("TOP")
    if d.stack.SetClipsChildren then d.stack:SetClipsChildren(true) end
    d.notesTitle = UI.Text(d, 12, "bronze", nil, nil, true); d.notesTitle:SetPoint("TOPLEFT", d.stack, "BOTTOMLEFT", 0, -14)
    d.notesTitle:SetText(ns.Upper(L.BUG_NOTES))
    d.notes = UI.Text(d, 12, "textDim"); d.notes:SetPoint("TOPLEFT", d.notesTitle, "BOTTOMLEFT", 0, -6)
    d.notes:SetWordWrap(true); d.notes:SetJustifyV("TOP"); d.notes:SetSpacing(4)
    d.delete = UI.Button(d, L.BUG_DELETE, 100, 22, function() if d.b then Inbox.Delete(d.b.sig) end end, "trash-2")
    d.delete:SetPoint("BOTTOMRIGHT", -12, 12)
    function d.Show_(b)
        d.b = b
        local has = b ~= nil
        for _, x in ipairs({ d.status, d.tag, d.msg, d.where, d.meta, d.stackTitle, d.copy, d.stack, d.notesTitle, d.notes, d.delete }) do x:SetShown(has) end
        d.empty:SetShown(not has)
        if not has then d.empty:Set("bug", L.BUG_PICK, L.BUG_PICK_HINT); return end
        local w = (d:GetWidth() or DETAIL_W) - 24
        d.status:Refresh()
        d.tag:SetText(Theme.HexColor(STATUS_COLOR[b.status] or "accent", ns.Upper(L["BUG_STATUS_" .. b.status:upper()])))
        d.msg:SetText(Inbox.Short(b.m)); d.msg:SetWidth(w)
        d.where:SetText(b.where or "?"); d.where:SetWidth(w)
        local players = {}
        local np = 0
        for key in pairs(b.players) do np = np + 1; if #players < 6 then players[#players + 1] = Names.Display(key) end end
        table.sort(players)
        d.meta:SetWidth(w)
        d.meta:SetText(table.concat({
            Theme.HexColor("muted", L.BUG_META_PLAYERS) .. "  " .. table.concat(players, ", ") .. (np > #players and (" +" .. (np - #players)) or ""),
            Theme.HexColor("muted", L.BUG_META_COUNT) .. "  " .. L.BUG_COUNT_PLAYERS:format(b.n, np),
            Theme.HexColor("muted", L.BUG_META_VERSION) .. "  " .. tostring(b.v or "?"),
            Theme.HexColor("muted", L.BUG_META_WHERE) .. "  " .. table.concat({ b.z or "?", b.gr or "?", b.cb and L.BUG_IN_COMBAT or nil }, " · "),
            Theme.HexColor("muted", L.BUG_META_TIMES) .. "  " .. ns.Date(b.first) .. " / " .. ns.Date(b.last),
        }, "\n"))
        d.stack:SetWidth(w)
        d.copy:ClearAllPoints()
        d.copy:SetPoint("LEFT", d.stackTitle, "LEFT", w - 90, 0)
        d.stackText:SetWidth(w - 16)
        d.stackText:SetText(b.st ~= "" and b.st or L.BUG_NO_STACK)
        local notes = {}
        for i = #b.notes, 1, -1 do
            local n = b.notes[i]
            notes[#notes + 1] = Theme.HexColor("text", Names.Display(n.k)) .. ": “" .. n.x .. "”"
            if #notes >= 4 then break end
        end
        d.notes:SetWidth(w)
        d.notes:SetText(#notes > 0 and table.concat(notes, "\n") or Theme.HexColor("muted", L.BUG_NO_NOTES))
        -- seen once opened
        if b.status == "new" and f:IsVisible() then b.status = "seen"; d.status:Refresh(); ns.Fire("LG_BUGS") end
    end

    local list = UI.List(f, {
        sortKey = "last", sortDesc = true,
        columns = {
            { key = "status", title = "", width = 18, align = "CENTER", noHighlight = true,
              text = function(r) return UI.Glyph("dot", STATUS_COLOR[r.b.status] or "muted", 8) end, sort = function(r) return r.b.status end },
            { key = "msg", title = L.BUG_COL_ERROR, flex = true, minWidth = 160,
              text = function(r) return Theme.HexColor(r.b.status == "new" and "text" or "textDim", Inbox.Short(r.b.m)) end },
            { key = "where", title = L.BUG_COL_WHERE, width = 170, optional = 2,
              text = function(r) return Theme.HexColor("muted", r.b.where or "?") end },
            { key = "n", title = L.BUG_COL_COUNT, width = 56, align = "RIGHT", defaultDesc = true,
              text = function(r) return tostring(r.b.n) end, sort = function(r) return r.b.n end },
            { key = "players", title = L.BUG_COL_PLAYERS, width = 60, align = "RIGHT", optional = 3, defaultDesc = true,
              text = function(r) return tostring(r.np) end, sort = function(r) return r.np end },
            { key = "v", title = L.COL_VERSION, width = 70, optional = 4, text = function(r) return tostring(r.b.v or "?") end },
            { key = "last", title = L.BUG_COL_LAST, width = 90, optional = 1, defaultDesc = true,
              text = function(r) return Theme.HexColor("muted", ns.Ago(r.b.last)) end, sort = function(r) return r.b.last or 0 end },
        },
        onClick = function(r) state.selected = r.b.sig; d.Show_(r.b); f.list:Draw() end,
        isSelected = function(r) return state.selected == r.b.sig end,
        searchText = function(r)
            local parts = { r.b.m, r.b.where or "" }
            for key in pairs(r.b.players) do parts[#parts + 1] = Names.Display(key) end
            return table.concat(parts, " ")
        end,
    })
    list:SetPoint("TOPLEFT", 0, -32)
    list:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", -12, 0)
    list:SetEmptyText(L.BUG_EMPTY, L.BUG_EMPTY_HINT, "bug")
    f.list = list
    f:SetScript("OnSizeChanged", function(_, w) d:SetWidth((w or 900) < 760 and 280 or DETAIL_W); if d.b then d.Show_(d.b) end end)
    function f.Refresh()
        chips:Refresh()
        local rows, counts = {}, { all = 0, new = 0, seen = 0, solved = 0 }
        local sel
        for sig, b in pairs(store()) do
            counts.all = counts.all + 1
            counts[b.status] = (counts[b.status] or 0) + 1
            if state.filter == "all" or b.status == state.filter then
                local np = 0
                for _ in pairs(b.players) do np = np + 1 end
                rows[#rows + 1] = { key = sig, b = b, np = np }
                if sig == state.selected then sel = b end
            end
        end
        for k, n in pairs(counts) do chips:SetCount(k, n) end
        list:SetRows(rows)
        d.Show_(sel)
    end
    return f
end

-- the message without the file path in front (the "where" column has it)
function Inbox.Short(m)
    local short = tostring(m or ""):gsub("^[^\n]-%.lua%]?:%d+:%s*", "")
    return short ~= "" and short or tostring(m or "")
end

function Inbox.CopyText(b)
    local players = {}
    for key in pairs(b.players) do players[#players + 1] = Names.Display(key) end
    table.sort(players)
    return ("%s %s · %s · %s\n%s\n%s\n\n%s"):format(ns.title, b.v or "?", L.BUG_COUNT_PLAYERS:format(b.n, #players),
        table.concat(players, ", "), b.m, b.where or "", b.st or "")
end

-- the guild admin page shows the number of new reports in the sidebar
ns.On("LG_BUGS", function()
    ns.Debounce("bug-inbox", 0.2, function()
        if ns.Window.BuildNav then ns.Window.BuildNav() end
        ns.Window.Refresh("admin")
    end)
end)

-- /lg test buginbox: two sample reports in the inbox (only here, removed after 2 min)
function Inbox.Test()
    if not ns.Bugs.IsReceiver() then ns.Print(L.BUG_INBOX_ONLY_OFFICERS); return end
    local samples = {
        { m = "Interface/AddOns/LiebeGruesse/Modules/Feed.lua:388: bad argument #1 to 'format' (number expected, got nil) [test]",
          st = "[string \"@Interface/AddOns/LiebeGruesse/Modules/Feed.lua\"]:388: in function 'Text'", n = 2, v = ns.version, note = "Clicked a feed entry", test = true },
        { m = "Interface/AddOns/LiebeGruesse/UI/Toast.lua:241: Usage: SetPoint(point [, relativeTo]) [test]",
          st = "[string \"@Interface/AddOns/LiebeGruesse/UI/Toast.lua\"]:241: in function 'Toast'", n = 5, v = ns.version, test = true },
    }
    local sigs = {}
    for _, r in ipairs(samples) do
        local b = Inbox.Receive(r, Names.Me())
        if b then sigs[#sigs + 1] = b.sig end
    end
    Inbox.Open()
    ns.After(120, function() for _, sig in ipairs(sigs) do store()[sig] = nil end; ns.Fire("LG_BUGS") end)
end

function Inbox.HasTest()
    for _, b in pairs(store()) do if type(b) == "table" and b.test then return true end end
    return false
end
function Inbox.ClearTest()
    for sig, b in pairs(store()) do if type(b) == "table" and b.test then store()[sig] = nil end end
    ns.Fire("LG_BUGS")
end

-- test entries never survive a login
ns.On("LG_READY", function()
    for sig, b in pairs(store()) do if type(b) ~= "table" or b.test then store()[sig] = nil end end
end)
