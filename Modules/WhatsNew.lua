-- "What's new": after an update the changelog lines of every version since the
-- last one you saw, once (out of combat). /lg changelog shows it any time.
local _, ns = ...
local UI, Theme, L = ns.UI, ns.Theme, ns.L
local WN = {}
ns.WhatsNew = WN

-- tag of a commit line -> label and colour
local TAGS = {
    feat = { "WN_NEW", "good" }, fix = { "WN_FIXED", "warn" }, change = { "WN_CHANGED", "accent" },
    perf = { "WN_PERF", "textDim" }, style = { "WN_STYLE", "textDim" }, docs = { "WN_DOCS", "muted" },
}

local function parse(line)
    local tag, scope, rest = line:match("^(%a+)%(([^)]*)%):%s*(.*)$")
    if not tag then tag, rest = line:match("^(%a+):%s*(.*)$") end
    if not tag or not TAGS[tag] then return nil, nil, line end
    return tag, scope, rest
end
WN.Parse = parse

-- versions newer than `since` (all when nil), newest first
function WN.Since(since, limit)
    local list = {}
    for _, e in ipairs(ns.CHANGELOG or {}) do
        if since and ns.CompareVersions(e.v, since) <= 0 then break end
        list[#list + 1] = e
        if limit and #list >= limit then break end
    end
    return list
end

-- readable area names for the commit scopes ("fix(ui): …" -> "Interface: …")
local AREAS = {
    ui = "Interface", admin = "Guild admin", roster = "Roster", armory = "Armory", compare = "Compare", partner = "Partner guild",
    feed = "Guild feed", toast = "Notifications", notify = "Notifications", quick = "Quick actions", help = "Help", credits = "Credits",
    lc = "Loot Council", council = "Loot Council", cd = "Cooldowns", cooldowns = "Cooldowns", bless = "Blessings",
    blessings = "Blessings", crafts = "Professions", prof = "Professions", professions = "Professions", profsync = "Profession sync", trade = "Trade timer", test = "Test commands",
    attune = "Attunements", stats = "Statistics", life = "Statistics", tooltip = "Tooltips", tooltips = "Tooltips",
    settings = "Settings", greet = "Login greeting", badges = "Badges", community = "Community", versions = "Versions", inspect = "Inspect", profile = "Profile sync",
    runs = "Speedruns", achievements = "Achievements", bugs = "Bug reports",
}
function WN.Area(scope)
    if not scope or scope == "" then return nil end
    return AREAS[scope:lower()] or (scope:sub(1, 1):upper() .. scope:sub(2))
end

local W, MAX_H = 560, 560
local frame
local function create()
    frame = UI.Panel(UIParent, "panel", "border")
    frame:SetSize(W, 300)
    frame:SetPoint("CENTER", 0, 80)
    UI.Float(frame)
    if frame.SetClipsChildren then frame:SetClipsChildren(true) end
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    _G.LiebeGruesseWhatsNew = frame
    tinsert(UISpecialFrames, "LiebeGruesseWhatsNew")
    -- header: logo, kicker, title with version badge
    frame.glow = UI.VGradient(frame, { 0.090, 0.129, 0.192, 0.9 }, { 0.090, 0.129, 0.192, 0 }, "BORDER")
    frame.glow:SetPoint("TOPLEFT", 1, -1); frame.glow:SetPoint("TOPRIGHT", -1, -1); frame.glow:SetHeight(90)
    frame.logo = frame:CreateTexture(nil, "ARTWORK")
    frame.logo:SetTexture(ns.media .. "logo")
    frame.logo:SetSize(52, 52)
    frame.logo:SetPoint("TOPLEFT", 16, -14)
    frame.kicker = UI.Text(frame, 11, "accent", nil, nil, true)
    frame.kicker:SetPoint("TOPLEFT", frame.logo, "TOPRIGHT", 12, -6)
    frame.title = UI.Text(frame, 22, "text", nil, nil, true)
    frame.title:SetPoint("TOPLEFT", frame.kicker, "BOTTOMLEFT", 0, -4)
    frame.badge = UI.Panel(frame, "accentDim", "accent")
    frame.badge:SetHeight(22)
    frame.badge:SetPoint("LEFT", frame.title, "RIGHT", 14, 0)
    frame.badge.text = UI.Text(frame.badge, 13, "accent", "CENTER", nil, true)
    frame.badge.text:SetPoint("CENTER", 0, 0)
    frame.rule = UI.Fill(frame, "bronzeDim", "ARTWORK")
    frame.rule:SetHeight(1)
    frame.rule:SetPoint("TOPLEFT", 16, -80); frame.rule:SetPoint("TOPRIGHT", -16, -80)
    local scroll, body = UI.ScrollArea(frame)
    scroll:SetPoint("TOPLEFT", 16, -94)
    scroll:SetPoint("BOTTOMRIGHT", -12, 62)
    frame.scroll, frame.body = scroll, body
    frame.rows = {}
    -- footer: all changes (quiet) · close (accent)
    frame.all = UI.Button(frame, L.WN_ALL, 140, 32, function() WN.Show(nil, true) end)
    frame.all:SetPoint("BOTTOMLEFT", 16, 16)
    UI.CloseX(frame)
    _G.LiebeGruesseWhatsNew = frame
    tinsert(UISpecialFrames, "LiebeGruesseWhatsNew")
    frame.ok = UI.Button(frame, L.WN_CLOSE, 130, 32, function() frame:Hide() end)
    frame.ok:SetPoint("BOTTOMRIGHT", -16, 16)
    UI.Skin(frame.ok, "accentDim", "accent")
    frame.ok:SetScript("OnLeave", function(self)
        self:SetBackdropColor(Theme.Color("accentDim")); self:SetBackdropBorderColor(Theme.Color("accent")); GameTooltip:Hide()
    end)
end

local function row(i)
    local r = frame.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, frame.body)
    r.dot = UI.Fill(r, "accent", "ARTWORK")
    r.dot:SetSize(6, 6)
    r.dot:SetPoint("TOPLEFT", 2, -6)
    if r.dot.SetRotation then r.dot:SetRotation(math.rad(45)) end
    r.text = UI.Text(r, 14, "text")
    r.text:SetWordWrap(true)
    r.text:SetJustifyH("LEFT")
    frame.rows[i] = r
    return r
end

-- one bullet per change; with several versions a quiet version line separates them
function WN.Layout()
    if not frame then return end
    local Wb = math.max(200, (frame.scroll:GetWidth() or (W - 28)) - 12)
    local y, n = 0, 0
    local several = #(frame.list or {}) > 1
    for vi, e in ipairs(frame.list or {}) do
        if several then
            n = n + 1
            local h = row(n)
            h.dot:Hide()
            h.text:ClearAllPoints(); h.text:SetPoint("TOPLEFT", 0, 0); h.text:SetWidth(Wb)
            h.text:SetText(Theme.HexColor("bronze", "v" .. e.v) .. (e.d ~= "" and Theme.HexColor("muted", "   " .. e.d) or ""))
            h:ClearAllPoints(); h:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, -y); h:SetSize(Wb, 20); h:Show()
            y = y + 24
        end
        for _, line in ipairs(e) do
            local _, scope, rest = parse(line)
            n = n + 1
            local r = row(n)
            r.dot:Show()
            r.text:ClearAllPoints()
            r.text:SetPoint("TOPLEFT", 18, 0)
            r.text:SetWidth(Wb - 18)
            local area = WN.Area(scope)
            r.text:SetText((area and (area .. ": ") or "") .. rest:gsub("^%l", string.upper))
            local th = math.max(16, r.text:GetStringHeight() or 16)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, -y)
            r:SetSize(Wb, th)
            r:Show()
            y = y + th + 10
        end
        if several and vi < #frame.list then y = y + 8 end
    end
    for i = n + 1, #frame.rows do frame.rows[i]:Hide() end
    frame.body:SetHeight(math.max(1, y))
    -- the window grows with its content up to MAX_H, then scrolls
    frame:SetHeight(math.min(MAX_H, math.max(200, 94 + y + 66)))
    frame.scroll.UpdateBar()
end

-- since: last version seen (nil = everything); all: full history
function WN.Show(since, all)
    if not frame then create() end
    local list = WN.Since(not all and since or nil, all and nil or 8)
    if #list == 0 then list = WN.Since(nil, 1) end
    frame.list = list
    frame.kicker:SetText(ns.Upper(L.WN_KICKER))
    frame.title:SetText(all and L.WN_TITLE_ALL or L.WN_HEAD)
    frame.badge.text:SetText(ns.version)
    frame.badge:SetWidth((frame.badge.text:GetStringWidth() or 40) + 20)
    frame.badge:SetShown(not all)
    frame.all:SetShown(not all)
    frame:Show()
    frame.scroll:SetVerticalScroll(0)
    WN.Layout()
    ns.After(0, WN.Layout)   -- string heights are final one frame later
    -- right after login a font may still be loading: draw all texts again
    ns.After(0.3, function() if frame:IsShown() then Theme.Refont(frame); WN.Layout() end end)
end

function WN.Settings()
    local s = ns.Database.Settings()
    if s.whatsNew == nil then s.whatsNew = true end
    return s
end

-- fingerprint of the current version's changelog lines: the version number stays
-- the same until a release is committed, but its lines grow with every build
function WN.Signature()
    local e = ns.CHANGELOG and ns.CHANGELOG[1]
    if not e or e.v ~= ns.version then return ns.version end
    local h = 5381
    for _, line in ipairs(e) do
        for i = 1, #line do h = (h * 33 + line:byte(i)) % 4294967296 end
    end
    return ns.version .. "#" .. #e .. "#" .. h
end

-- after login: once per new version, and again when the changelog of the same
-- version grew (a newer build of it); not on the very first install
ns.On("LG_READY", function()
    local s = WN.Settings()
    local seen, seenSig = s.lastSeenVersion, s.lastSeenSig
    if ns.version == "dev" then return end
    local sig = WN.Signature()
    s.lastSeenVersion, s.lastSeenSig = ns.version, sig
    if not seen or not s.whatsNew then return end
    local since
    if ns.CompareVersions(ns.version, seen) > 0 then
        since = seen
    elseif ns.CompareVersions(ns.version, seen) == 0 and seenSig ~= sig then
        -- same version, new build: its own lines (the previous version as the start)
        local prev = ns.CHANGELOG and ns.CHANGELOG[2]
        since = prev and prev.v or nil
    else
        return
    end
    WN.pending = true
    ns.After(6, function() ns.AfterCombat("whatsnew", function() WN.pending = nil; WN.Show(since) end) end)
end)

function WN.Test() WN.Show(ns.CHANGELOG and ns.CHANGELOG[4] and ns.CHANGELOG[4].v or nil) end
