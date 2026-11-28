-- Guild admin: guild-wide settings for the guild master, officers and the
-- loot council – officer ranks, the craft prefix and the loot council setup.
-- Everyone with the addon takes them over; nobody else can change them.
--
-- Messages:
--   GS  (GUILD) officer ranks + craft prefix, each with time and author
--   GSQ (GUILD) "what I have" at login (rt/pt/lt) – officers (and the council
--       for its setup) answer once, elected, only when the asker is behind
-- The loot council setup itself travels as "LCC" (Council.lua).
local _, ns = ...
local L, UI, Theme, Names, Comm = ns.L, ns.UI, ns.Theme, ns.Names, ns.Comm
local Admin = {}
ns.Admin = Admin

local DEFAULT_PREFIX = "!lg"
local MAX_RANK = 9

---------------------------------------------------------------------------
-- Stored rules (per guild)
---------------------------------------------------------------------------
function Admin.Rules()
    local gdb = ns.Database.Guild()
    if type(gdb.rules) ~= "table" then gdb.rules = {} end
    local r = gdb.rules
    r.ranksT = tonumber(r.ranksT) or 0
    r.prefixT = tonumber(r.prefixT) or 0
    return r
end

function Admin.CraftPrefix()
    local p = ns.db and Admin.Rules().prefix
    return (type(p) == "string" and p ~= "") and p or DEFAULT_PREFIX
end

-- a prefix starts with a sign (so normal words never trigger), 2–10 characters, no spaces
function Admin.ValidPrefix(v)
    if type(v) ~= "string" then return nil end
    v = v:gsub("^%s+", ""):gsub("%s+$", "")
    if #v < 2 or #v > 10 or v:find("[%s|]") or not v:find("^%p") then return nil end
    return v
end

---------------------------------------------------------------------------
-- Who may do what
---------------------------------------------------------------------------
local function me() return Names.Me() end
function Admin.CanEditRanks() return IsInGuild() and ns.Guild.IsGuildMaster(me()) == true end
function Admin.CanEditPrefix() return IsInGuild() and ns.Guild.IsOfficer(me()) == true end
function Admin.CanEditLC()
    local key = me()
    return ns.Guild.IsOfficer(key) == true or (ns.Council and ns.Council.IsCouncilMember(key) == true) or false
end
-- the admin page: guild master, officers, loot council
function Admin.IsStaff() return IsInGuild() and Admin.CanEditLC() end

-- roles of a player, strongest first: "gm", "officer", "council"
function Admin.Roles(key)
    local roles = {}
    if ns.Guild.IsGuildMaster(key) then roles[#roles + 1] = "gm" end
    if ns.Guild.IsOfficer(key) then roles[#roles + 1] = "officer" end
    if ns.Council and ns.Council.IsCouncilMember(key) then roles[#roles + 1] = "council" end
    return roles
end

---------------------------------------------------------------------------
-- Ranks of the guild (names from the game, else from the roster)
---------------------------------------------------------------------------
function Admin.RankName(i)
    local name = ns.Guild.ranks[i]
    if name then return name end
    for _, m in pairs(ns.Guild.members) do
        if m.rankIndex == i and m.rank then return m.rank end
    end
end

function Admin.RankCount(i)
    local n = 0
    for _, m in pairs(ns.Guild.members) do if m.rankIndex == i then n = n + 1 end end
    return n
end

local function rankList(set)
    local list = {}
    for i = 1, MAX_RANK do if set[i] then list[#list + 1] = i end end
    return list
end

local function rankSet(list)
    local set = { [0] = true }
    if type(list) ~= "table" then return nil end
    local n = 0
    for _, v in ipairs(list) do
        v = tonumber(v)
        if not v or v ~= math.floor(v) or v < 1 or v > MAX_RANK then return nil end
        set[v] = true
        n = n + 1
        if n > MAX_RANK then return nil end
    end
    return set
end
Admin.RankSet = rankSet

---------------------------------------------------------------------------
-- Changing and sending
---------------------------------------------------------------------------
local function packet()
    local r = Admin.Rules()
    return { r = rankList(ns.Guild.OfficerRanks()), rt = r.ranksT, rb = r.ranksBy,
        p = r.prefix, pt = r.prefixT, pb = r.prefixBy }
end

function Admin.Send()
    if not IsInGuild() then return false end
    Comm.Answered("gs")
    return Comm.Send("GS", packet(), "GUILD", { priority = "normal" })
end

local function changed()
    ns.Fire("LG_ADMIN")
    ns.Window.Refresh("admin")
end

function Admin.SetRank(i, on)
    if not Admin.CanEditRanks() then ns.Print(L.ADM_RANKS_ONLY_GM); return false end
    if type(i) ~= "number" or i < 1 or i > MAX_RANK then return false end
    local set = {}
    for k, v in pairs(ns.Guild.OfficerRanks()) do set[k] = v end
    set[0] = true
    set[i] = on and true or nil
    local r = Admin.Rules()
    r.ranks, r.ranksT, r.ranksBy = set, ns.Now(), me()
    Admin.Send()
    changed()
    return true
end

function Admin.SetPrefix(v)
    if not Admin.CanEditPrefix() then ns.Print(L.ADM_PREFIX_ONLY_OFFICERS); return false end
    local p = Admin.ValidPrefix(v)
    if not p then ns.Print(L.ADM_PREFIX_INVALID); return false end
    if p == Admin.CraftPrefix() then return true end
    local r = Admin.Rules()
    r.prefix, r.prefixT, r.prefixBy = p, ns.Now(), me()
    Admin.Send()
    ns.Print(L.ADM_PREFIX_SET:format(p))
    changed()
    return true
end

-- at login: tell the officers what we have; they answer when we are behind
local queried
function Admin.Query(force)
    if not IsInGuild() or not ns.Database.GuildKey() then return false end
    if queried and not force then return false end
    queried = true
    local r = Admin.Rules()
    local cfg = ns.Council and ns.Council.Config() or {}
    return Comm.Send("GSQ", { rt = r.ranksT, pt = r.prefixT, lt = cfg.t or 0 }, "GUILD", { priority = "bulk" })
end

ns.On("LG_READY", function()
    ns.After(12, function() if not Admin.Query() then ns.After(30, function() Admin.Query() end) end end)
end)

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
local function fresh(t, mine)
    t = tonumber(t)
    return t ~= nil and t > (mine or 0) and t <= ns.Now() + 120
end

Comm.Register("GS", function(data, sender, channel)
    if channel ~= "GUILD" or not ns.Guild.IsMember(sender) then return end
    local r = Admin.Rules()
    local got = {}
    local officer = ns.Guild.IsOfficer(sender)
    -- officer ranks: from the guild master – or relayed by an officer when the guild master set them
    if fresh(data.rt, r.ranksT) then
        local gm = ns.Guild.MasterKey()
        local author = type(data.rb) == "string" and Names.Key(data.rb)
        local ok = ns.Guild.IsGuildMaster(sender) or (officer and author and gm and Names.Same(author, gm))
        local set = ok and rankSet(data.r)
        if set then
            r.ranks, r.ranksT = set, tonumber(data.rt)
            r.ranksBy = ns.Guild.IsGuildMaster(sender) and sender or author
            got[#got + 1] = L.ADM_RANKS
        end
    end
    -- craft prefix: from officers
    if fresh(data.pt, r.prefixT) and officer then
        local p = Admin.ValidPrefix(data.p)
        if p then
            r.prefix, r.prefixT = p, tonumber(data.pt)
            r.prefixBy = type(data.pb) == "string" and ns.Clean(data.pb) or sender
            got[#got + 1] = L.ADM_PREFIX_NAMED:format(p)
        end
    end
    -- somebody else already sent what we would answer
    if (tonumber(data.rt) or 0) >= r.ranksT and (tonumber(data.pt) or 0) >= r.prefixT then Comm.Answered("gs") end
    if #got > 0 then
        ns.Print(L.ADM_RECEIVED:format(Names.Display(sender), table.concat(got, ", ")))
        changed()
    end
end)

Comm.Register("GSQ", function(data, sender, channel)
    if channel ~= "GUILD" or Names.Same(sender, me()) or not ns.Guild.IsMember(sender) then return end
    local r = Admin.Rules()
    if ns.Guild.IsOfficer(me()) and (r.ranksT > (tonumber(data.rt) or 0) or r.prefixT > (tonumber(data.pt) or 0)) then
        Comm.ReplyOnce("gs", 1, 5, function() Admin.Send() end)
    end
    local cfg = ns.Council and ns.Council.Config()
    if cfg and Admin.CanEditLC() and (cfg.t or 0) > (tonumber(data.lt) or 0) then
        Comm.ReplyOnce("lcc", 1, 5, function() ns.Council.ShareConfig(true) end)
    end
end)

---------------------------------------------------------------------------
-- Texts for the page
---------------------------------------------------------------------------
local function who(key)
    if not key or key == "" then return nil end
    local g = ns.Guild.Find(key)
    return g and ns.ColorName(g.name or key, g.class) or Names.Display(key)
end

local function changedBy(t, by, default)
    if not t or t <= 0 then return Theme.HexColor("muted", default) end
    local name = who(by)
    return name and L.ADM_CHANGED_BY:format(name, ns.Ago(t)) or ns.Ago(t)
end
Admin.ChangedBy = changedBy

function Admin.RoleText(key)
    local names = {}
    for _, role in ipairs(Admin.Roles(key)) do names[#names + 1] = L["ADM_ROLE_" .. role:upper()] end
    if #names == 0 then return Theme.HexColor("muted", L.ADM_ROLE_NONE) end
    return Theme.HexColor("accent", table.concat(names, "  ·  "))
end

function Admin.OfficerRanksText()
    local parts = {}
    for i = 0, MAX_RANK do
        if ns.Guild.IsOfficerRank(i) then
            local name = Admin.RankName(i)
            if name or i <= 1 then parts[#parts + 1] = name or L.ADM_RANK_N:format(i) end
        end
    end
    return table.concat(parts, ", ")
end

-- guild members of the council (rank, names, loot master), sorted
function Admin.CouncilMembers()
    local list = {}
    if not ns.Council then return list end
    local cfg = ns.Council.Config()
    for key, m in pairs(ns.Guild.members) do
        if ns.Council.IsCouncilMember(key, cfg) then list[#list + 1] = m end
    end
    table.sort(list, function(a, b)
        if (a.rankIndex or 99) ~= (b.rankIndex or 99) then return (a.rankIndex or 99) < (b.rankIndex or 99) end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

local function councilText()
    local cfg = ns.Council.Config()
    local base = (cfg.minRank or 1) < 0 and L.LC_ONLY_NAMES
        or L.LC_RANK_AND_ABOVE:format(Admin.RankName(cfg.minRank or 1) or L.ADM_RANK_N:format(cfg.minRank or 1))
    local n = #(cfg.names or {})
    if n > 0 then base = base .. Theme.HexColor("muted", "  +  " .. L.ADM_N_NAMES:format(n)) end
    return base
end

local function membersText(limit)
    local list = Admin.CouncilMembers()
    if #list == 0 then return Theme.HexColor("muted", L.ADM_NOBODY) end
    local out = {}
    for i, m in ipairs(list) do
        if limit and i > limit then out[#out + 1] = Theme.HexColor("muted", L.QB_MORE:format(#list - limit)); break end
        out[#out + 1] = ns.ColorName(m.name or m.key, m.class)
    end
    return table.concat(out, limit and ", " or "\n")
end

local function qualityText(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    return (c and c.hex or "") .. (_G["ITEM_QUALITY" .. tostring(q) .. "_DESC"] or tostring(q)) .. "|r"
end

local function votingText(cfg)
    local parts = { cfg.multiVote and L.ADM_VOTE_MULTI or L.ADM_VOTE_SINGLE }
    parts[#parts + 1] = cfg.selfVote and L.ADM_VOTE_SELF or L.ADM_VOTE_NO_SELF
    if cfg.rolls then parts[#parts + 1] = L.ADM_VOTE_ROLLS end
    return table.concat(parts, "  ·  ")
end

local function responsesText(cfg)
    local out = {}
    for _, r in ipairs(cfg.responses or {}) do
        local c = r.c or { 1, 1, 1 }
        out[#out + 1] = ns.Hex(c[1] or 1, c[2] or 1, c[3] or 1, r.t or "?")
    end
    return table.concat(out, ", ")
end

---------------------------------------------------------------------------
-- Permissions overview: what each role may do
---------------------------------------------------------------------------
-- values: true, false or a short text ("own awards")
Admin.RIGHTS = {
    { key = "ranks", text = "ADM_R_RANKS", gm = true, officer = false, council = false },
    { key = "prefix", text = "ADM_R_PREFIX", gm = true, officer = true, council = false },
    { key = "lc", text = "ADM_R_LC", gm = true, officer = true, council = true },
    { key = "lcpage", text = "ADM_R_LCPAGE", gm = true, officer = true, council = true },
    { key = "lchist", text = "ADM_R_LCHIST", gm = true, officer = true, council = "ADM_R_OWN" },
    { key = "announce", text = "ADM_R_ANNOUNCE", gm = true, officer = true, council = false },
    { key = "feed", text = "ADM_R_FEED", gm = true, officer = true, council = false },
    { key = "key", text = "ADM_R_KEY", gm = true, officer = true, council = false },
    { key = "bugs", text = "ADM_R_BUGS", gm = true, officer = true, council = false },
    { key = "nudge", text = "ADM_R_NUDGE", gm = true, officer = true, council = false },
}
local COLUMNS = { "gm", "officer", "council" }

local function rightsMatrix(parent)
    local f = CreateFrame("Frame", nil, parent)
    local ROW, HEAD, COL = 28, 30, 92
    f.heads, f.rows = {}, {}
    f.colBg = {}
    for c, role in ipairs(COLUMNS) do
        local bg = UI.Fill(f, "accent", "BACKGROUND")
        bg:SetAlpha(0.08)
        f.colBg[c] = bg
        local h = UI.Text(f, 11, "muted", "CENTER", nil, true)
        h:SetText(ns.Upper(L["ADM_COL_" .. role:upper()]))
        h:SetWidth(COL)
        f.heads[c] = h
    end
    for i, def in ipairs(Admin.RIGHTS) do
        local row = { cells = {} }
        row.label = UI.Text(f, 12, "text")
        row.label:SetText(L[def.text])
        row.line = UI.Fill(f, "borderDim", "ARTWORK")
        row.line:SetHeight(1)
        for c, role in ipairs(COLUMNS) do
            local v = def[role]
            local cell = UI.Text(f, 11, "textDim", "CENTER")
            cell:SetWidth(COL)
            if v == true then cell:SetText(UI.Glyph("badge-check", "good", 14))
            elseif v == false then cell:SetText(Theme.HexColor("muted", "–"))
            else cell:SetText(L[v] or tostring(v)) end
            row.cells[c] = cell
        end
        f.rows[i] = row
    end
    function f:Relayout()
        local w = self:GetWidth() or 600
        local col = (w < 520) and 70 or COL
        local right = 14
        for c = #COLUMNS, 1, -1 do
            local x = w - right - (#COLUMNS - c + 1) * col
            self.heads[c]:ClearAllPoints()
            self.heads[c]:SetPoint("TOPLEFT", x, -10)
            self.heads[c]:SetWidth(col)
            self.colBg[c]:ClearAllPoints()
            self.colBg[c]:SetPoint("TOPLEFT", x + 4, -4)
            self.colBg[c]:SetSize(col - 8, HEAD + #self.rows * ROW - 2)
            for _, row in ipairs(self.rows) do row.cells[c]:SetWidth(col) end
            self.colX = self.colX or {}
            self.colX[c] = x
        end
        for i, row in ipairs(self.rows) do
            local y = -(HEAD + (i - 1) * ROW)
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", self, "TOPLEFT", 16, y - ROW / 2)
            row.label:SetWidth(math.max(60, (self.colX[1] or w) - 24))
            for c in ipairs(COLUMNS) do
                row.cells[c]:ClearAllPoints()
                row.cells[c]:SetPoint("LEFT", self, "TOPLEFT", self.colX[c], y - ROW / 2)
            end
            row.line:ClearAllPoints()
            row.line:SetPoint("TOPLEFT", 12, y)
            row.line:SetPoint("TOPRIGHT", -12, y)
        end
    end
    -- your own columns are tinted
    function f:Refresh()
        local mine = {}
        for _, role in ipairs(Admin.Roles(me())) do mine[role] = true end
        for c, role in ipairs(COLUMNS) do
            self.colBg[c]:SetShown(mine[role] == true)
            self.heads[c]:SetTextColor(Theme.Color(mine[role] and "accent" or "muted"))
        end
    end
    f:SetScript("OnSizeChanged", function(self) self:Relayout() end)
    f.height = HEAD + #Admin.RIGHTS * ROW + 8
    return f
end
Admin.RightsMatrix = rightsMatrix

---------------------------------------------------------------------------
-- Page: Guild › Admin
---------------------------------------------------------------------------
UI.AddPage("admin", L.PAGE_ADMIN, 32, function(root, page)
    -- tabs: overview (rights and shared settings) and the bug inbox (officers)
    local holder = CreateFrame("Frame", nil, root)
    holder:SetPoint("TOPLEFT", 0, -38)
    holder:SetPoint("BOTTOMRIGHT")
    local content = CreateFrame("Frame", nil, holder)
    content:SetAllPoints()
    local form = UI.Form(content)
    page.SearchEnter = function() form:JumpFirst() end
    page.head = L.HEAD_ADMIN
    form.scroll:SetPoint("TOPLEFT")
    form.scroll:SetPoint("BOTTOMRIGHT", -8, 0)
    local function cfg() return ns.Council.Config() end
    local function rules() return Admin.Rules() end

    -- you: role, rank, what you may change
    local you = form:Section(L.ADM_YOU)
    you:Info(L.ADM_YOUR_ROLE, function() return Admin.RoleText(me()) end)
    you:Info(L.ADM_YOUR_RANK, function()
        local i = ns.Guild.MyRankIndex()
        return (i and Admin.RankName(i)) or Theme.HexColor("muted", "–")
    end)
    you:Info(L.ADM_YOU_CAN, function()
        local can = {}
        if Admin.CanEditRanks() then can[#can + 1] = L.ADM_RANKS end
        if Admin.CanEditPrefix() then can[#can + 1] = L.ADM_PREFIX end
        if Admin.CanEditLC() then can[#can + 1] = L.ADM_LC_SHORT end
        return #can > 0 and table.concat(can, ", ") or Theme.HexColor("muted", L.ADM_NOTHING)
    end)
    you:Note(L.ADM_YOU_HINT, { height = 30 })

    -- officer ranks (guild master)
    local ranks = form:Section(L.ADM_RANKS_SECTION, { locked = function() return not Admin.CanEditRanks() end,
        lockTip = L.ADM_RANKS_ONLY_GM })
    ranks:Note(L.ADM_RANKS_HINT, { height = 30, unlocked = true })
    for i = 0, MAX_RANK do
        local label = (i == 0) and L.ADM_RANK_GM or L.ADM_RANK_N:format(i)
        local _, row = ranks:Toggle(label, function() return ns.Guild.IsOfficerRank(i) end,
            function(v) Admin.SetRank(i, v) end, {
                show = function() return Admin.RankName(i) ~= nil end,
                locked = i == 0 and function() return true end or nil,
                lockTip = i == 0 and L.ADM_RANK_GM_TIP or nil,
            })
        -- label: rank name and how many members hold it
        local refresh = row.control.Refresh
        row.control.Refresh = function(self, ...)
            if refresh then refresh(self, ...) end
            local name = Admin.RankName(i)
            if name then
                row.label:SetText(name .. Theme.HexColor("muted", "  ·  " .. L.ADM_MEMBERS_N:format(Admin.RankCount(i))))
                row.labelText = name
            end
        end
    end
    ranks:Info(L.ADM_LAST_CHANGE, function()
        local r = rules()
        return changedBy(r.ranksT, r.ranksBy, L.ADM_RANKS_DEFAULT)
    end, { unlocked = true })

    -- loot council: summary of the shared setup
    local lc = form:Section(L.ADM_LC_SECTION)
    lc:Info(L.ADM_LC_COUNCIL, councilText)
    lc:Info(L.ADM_LC_MEMBERS, function() return membersText(6) end, { tipFn = function() return membersText() end })
    lc:Info(L.ADM_LC_LOOTMASTER, function()
        local m = cfg().lootMaster
        return (m and m ~= "") and (who(Names.Key(m)) or m) or Theme.HexColor("muted", L.ADM_LC_LOOTMASTER_AUTO)
    end)
    lc:Info(L.ADM_LC_ITEMS, function() return L.ADM_LC_ITEMS_FROM:format(qualityText(cfg().quality or 4)) end)
    lc:Info(L.ADM_LC_TIME, function() return L.ADM_SECONDS:format(cfg().timeout or 120) end)
    lc:Info(L.ADM_LC_VOTING, function() return votingText(cfg()) end)
    lc:Info(L.ADM_LC_BUTTONS, function() return responsesText(cfg()) end, { tipFn = function() return responsesText(cfg()) end })
    lc:Info(L.ADM_LAST_CHANGE, function() return changedBy(cfg().t, cfg().by, L.ADM_LC_NEVER) end)
    lc:Buttons({
        { L.ADM_LC_EDIT, function() ns.Window.ShowSettings("council") end, width = 170, icon = "gem", tip = L.ADM_LC_EDIT_TIP },
        { L.ADM_LC_RESEND, function() ns.Council.ShareConfig() end, width = 170, icon = "users", tip = L.ADM_LC_RESEND_TIP },
    }, { locked = function() return not Admin.CanEditLC() end, lockTip = L.ADM_LC_ONLY })

    -- craft prefix (officers)
    local craft = form:Section(L.ADM_CRAFT_SECTION, { locked = function() return not Admin.CanEditPrefix() end,
        lockTip = L.ADM_PREFIX_ONLY_OFFICERS })
    craft:Note(L.ADM_CRAFT_HINT, { height = 44, unlocked = true })
    craft:Edit(L.SET_CRAFT_PREFIX, function() return Admin.CraftPrefix() end, function(v)
        if v ~= Admin.CraftPrefix() then Admin.SetPrefix(v); form:Refresh() end
    end, { width = 120, placeholder = DEFAULT_PREFIX, tip = L.ADM_PREFIX_TIP })
    craft:Info(L.ADM_CRAFT_EXAMPLE, function() return Admin.CraftPrefix() .. " Lionheart Helm" end, { unlocked = true })
    craft:Info(L.ADM_LAST_CHANGE, function()
        local r = rules()
        return changedBy(r.prefixT, r.prefixBy, L.ADM_PREFIX_DEFAULT)
    end, { unlocked = true })

    -- who may do what
    local rights = form:Section(L.ADM_RIGHTS_SECTION, { wide = true })
    local matrix = rightsMatrix(form.body)
    rights:Custom(matrix, matrix.height, { col = 0 })
    matrix.control = matrix
    rights:Note(L.ADM_RIGHTS_HINT, { height = 30 })

    local inbox = ns.BugInbox.Build(holder)
    inbox:SetAllPoints()
    local tabs = { overview = content, bugs = inbox }
    content.Refresh = function() form:Refresh() end
    content.SearchHits = function(q) return form:Filter(q) end
    content.SearchApply = function(q) form:Filter(q) end
    inbox.SearchHits = function(q) inbox.Refresh(); return inbox.list:SearchHits(q) end
    inbox.SearchApply = function(q) inbox.list:ShowFirstHit(q) end
    local function bugTitle()
        local n = ns.BugInbox.Count("new")
        return n > 0 and L.BUG_TAB_N:format(n) or L.BUG_TAB
    end
    local bar = UI.SubTabs(root, { { key = "overview", title = L.ADM_TAB_OVERVIEW }, { key = "bugs", title = L.BUG_TAB_N:format(99) } }, function(key)
        if key == "bugs" and not ns.Bugs.IsReceiver() then key = "overview" end
        content:SetShown(key == "overview")
        inbox:SetShown(key == "bugs")
        tabs[key].Refresh()
    end)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -ns.Window.SearchReserve(), 0)
    local function titles()
        for _, b in ipairs(bar.buttons) do
            if b.key == "bugs" then
                b.text:SetText(bugTitle())
                b:SetShown(ns.Bugs.IsReceiver())
            end
        end
    end
    titles()
    bar:Select("overview")
    ns.BugInbox.ShowTab = function() if ns.Bugs.IsReceiver() then bar:Select("bugs") end end
    page.Search = function(text)
        page.query = text
        return UI.TabSearch(bar, tabs, text)
    end
    page.OnShow = function()
        titles()
        if bar.current == "bugs" and not ns.Bugs.IsReceiver() then bar:Select("overview"); return end
        tabs[bar.current].Refresh()
    end
end, { section = "guild", icon = "shield", visible = function() return Admin.IsStaff() end, badge = function()
    local n = ns.BugInbox and ns.Bugs.IsReceiver() and ns.BugInbox.Count("new") or 0
    return n > 0 and tostring(n) or nil
end })

-- the roster, ranks or council can change who sees the page: rebuild the sidebar only then
local lastAllowed
local function recheck()
    local now = Admin.IsStaff()
    if lastAllowed ~= nil and now ~= lastAllowed and ns.Window.BuildNav then ns.Window.BuildNav() end
    lastAllowed = now
    if ns.Window.IsShown("admin") then ns.Window.Refresh("admin") end
end
ns.On("LG_ROSTER", recheck)
ns.On("LG_COUNCIL", recheck)
ns.On("LG_ADMIN", recheck)
ns.On("LG_READY", recheck)

---------------------------------------------------------------------------
-- /lg test admin: what this client knows (nothing is sent or changed)
---------------------------------------------------------------------------
function Admin.Test()
    local r = Admin.Rules()
    local cfg = ns.Council and ns.Council.Config() or {}
    ns.Print(L.TEST_TAG .. " " .. L.ADM_TEST_TITLE)
    ns.Print("  " .. L.ADM_YOUR_ROLE .. ": " .. Admin.RoleText(me()))
    ns.Print("  " .. L.ADM_RANKS_SECTION .. ": " .. Admin.OfficerRanksText() .. "  (" .. changedBy(r.ranksT, r.ranksBy, L.ADM_RANKS_DEFAULT) .. ")")
    ns.Print("  " .. L.SET_CRAFT_PREFIX .. ": " .. Admin.CraftPrefix() .. "  (" .. changedBy(r.prefixT, r.prefixBy, L.ADM_PREFIX_DEFAULT) .. ")")
    ns.Print("  " .. L.ADM_LC_SECTION .. ": " .. changedBy(cfg.t, cfg.by, L.ADM_LC_NEVER) .. " · " .. L.ADM_LC_MEMBERS .. " " .. #Admin.CouncilMembers())
    local can = {}
    for _, def in ipairs(Admin.RIGHTS) do
        local any = false
        for _, role in ipairs(Admin.Roles(me())) do if def[role] then any = true end end
        if any then can[#can + 1] = L[def.text] end
    end
    ns.Print("  " .. L.ADM_YOU_CAN .. ": " .. (#can > 0 and table.concat(can, ", ") or L.ADM_NOTHING))
    if Admin.IsStaff() then ns.Window.Show("admin") end
end
