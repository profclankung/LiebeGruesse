-- Profession sync feedback: a chat line when the profession window opens
-- ("keep it open a moment") and one when the recipes are read and saved.
-- After login a small window (once per character and set of professions)
-- explains how to sync professions that were never read.
local _, ns = ...
local UI, Theme, L, Names = ns.UI, ns.Theme, ns.L, ns.Names
local PS = {}
ns.ProfSync = PS

local function settings()
    local s = ns.Database.Settings()
    if s.profSyncChat == nil then s.profSyncChat = true end
    return s
end
PS.Settings = settings

local function moduleOn() return ns.Database.Settings().modules.professions ~= false end
local function chatOn() return moduleOn() and settings().profSyncChat end

-- professions with a recipe window: crafting ones plus cooking and first aid.
-- Gathering skills (and fishing) have no recipes – only their skill is shared.
local SECONDARY = { cooking = true, firstaid = true, fishing = true }
PS.SECONDARY = SECONDARY
local function syncable(key)
    local info = key and ns.Crafts.ProfInfo(key)
    return info ~= nil and not info.gather
end
PS.Syncable = syncable

local function readKeys(m)
    local have = {}
    for name in pairs(m and m.rc or {}) do
        local key = ns.Crafts.ProfKey(name)
        if key then have[key] = true end
    end
    return have
end

-- profession keys of this character that have never been read: { key, ... }
function PS.Missing()
    local m = ns.Database.Member(Names.Me())
    if not m then return {} end
    local have = readKeys(m)
    local list, seen = {}, {}
    for _, p in ipairs(m.pr or {}) do
        local key = ns.Crafts.ProfKey(p.n)
        if syncable(key) and not have[key] and not seen[key] then
            seen[key] = true
            list[#list + 1] = key
        end
    end
    table.sort(list)
    return list
end

-- all professions of this character for the window: main ones first, then the
-- secondary ones (cooking, first aid, fishing); gathering main professions are left out
function PS.All()
    local m = ns.Database.Member(Names.Me())
    local main, second, seen = {}, {}, {}
    for _, p in ipairs(m and m.pr or {}) do
        local key = ns.Crafts.ProfKey(p.n)
        local info = key and ns.Crafts.ProfInfo(key)
        if info and not seen[key] and (SECONDARY[key] or not info.gather) then
            seen[key] = true
            local list = SECONDARY[key] and second or main
            list[#list + 1] = key
        end
    end
    local order = function(a, b) return ns.Crafts.ProfInfo(a).order < ns.Crafts.ProfInfo(b).order end
    table.sort(main, order); table.sort(second, order)
    for _, key in ipairs(second) do main[#main + 1] = key end
    return main
end

-- skill of one of our professions: rank, max
local function skill(key)
    local m = ns.Database.Member(Names.Me())
    for _, p in ipairs(m and m.pr or {}) do
        if ns.Crafts.ProfKey(p.n) == key then return p.s, p.m end
    end
end

-- the profession's name in this client (= the spell that opens its window)
function PS.SpellName(key)
    local m = ns.Database.Member(Names.Me())
    for _, p in ipairs(m and m.pr or {}) do
        if ns.Crafts.ProfKey(p.n) == key then return p.n end
    end
    return ns.Crafts.ProfName(key)
end

local function knowsSpell(name)
    if not name then return false end
    local info = C_Spell and C_Spell.GetSpellInfo and ns.Call(C_Spell.GetSpellInfo, name)
    if type(info) == "table" then return true end
    return GetSpellInfo ~= nil and ns.Call(GetSpellInfo, name) ~= nil
end

---------------------------------------------------------------------------
-- Chat feedback while the profession window is open
---------------------------------------------------------------------------
local session        -- { reported = { [key] = true }, changed = { [key] = bool }, any = bool, open = bool, said = bool }

local function linked()
    local T = C_TradeSkillUI
    if T and (ns.Call(T.IsTradeSkillLinked) == true or ns.Call(T.IsTradeSkillGuild) == true) then return true end
    if IsTradeSkillLinked and ns.Call(IsTradeSkillLinked) == true then return true end
    return false
end

-- what the chat already said per profession (per character): { [key] = recipe count }
local function said()
    local char = ns.Database.Char()
    if type(char.profSyncSaid) ~= "table" then char.profSyncSaid = {} end
    return char.profSyncSaid
end
PS.Said = said

-- the "keep it open" line only while a profession of ours was never reported
local function needsStartLine()
    local done = said()
    local any = false
    for _, key in ipairs(PS.All()) do
        any = true
        if syncable(key) and not done[key] then return true end
    end
    return not any
end

local function started()
    if not chatOn() or linked() then session = nil; return end
    -- several show events for one window (trade skill + craft): one session
    if session and session.open then return end
    session = { reported = {}, changed = {}, any = false, open = true, said = needsStartLine() }
    if not session.said then return end
    ns.Print(L.PSYNC_START)
    local mine = session
    -- nothing could be read: say so instead of leaving the player waiting
    ns.After(10, function()
        if session == mine and not mine.any then ns.Print(L.PSYNC_NOTHING) end
    end)
end

local function closed()
    if session then session.open = false end
end

-- one line per profession: the first sync, later only when recipes were added
local function report(prof, count, key)
    local s = session
    if not s or s.reported[key] then return end
    s.reported[key] = true
    local done = said()
    local first = done[key] == nil
    local grew = s.changed[key] and count ~= done[key]
    done[key] = count
    if PS.frame and PS.frame:IsShown() then PS.Update() end
    if not first and not grew then return end
    local name = Theme.HexColor("accent", ns.Crafts.ProfName(key) or prof)
    if s.changed[key] then
        ns.Print(L.PSYNC_DONE:format(name, count))
    else
        ns.Print(L.PSYNC_UPTODATE:format(name, count))
    end
end

ns.On("LG_PROF_SCANNED", function(_, prof, count, changed)
    local key = ns.Crafts.ProfKey(prof)
    if not key then return end
    if PS.frame and PS.frame:IsShown() then PS.Update() end
    local s = session
    if not s then return end
    s.any = true
    s.changed[key] = s.changed[key] or changed
    -- the list keeps updating for a moment after opening: report once it settles
    ns.Debounce("psync-done-" .. key, 2.5, function() report(prof, count, key) end)
end)

ns.On("TRADE_SKILL_SHOW", started)
ns.On("CRAFT_SHOW", started)
ns.On("TRADE_SKILL_CLOSE", closed)
ns.On("CRAFT_CLOSE", closed)

---------------------------------------------------------------------------
-- "Sync your professions" window
---------------------------------------------------------------------------
local W = 460
local frame

local function create()
    frame = UI.Panel(UIParent, "panel", "border")
    frame:SetSize(W, 300)
    frame:SetPoint("CENTER", 0, 80)
    UI.Float(frame)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    _G.LiebeGruesseProfSync = frame
    tinsert(UISpecialFrames, "LiebeGruesseProfSync")
    PS.frame = frame
    UI.CloseX(frame)

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
    frame.title:SetWidth(W - 100)
    frame.rule = UI.Fill(frame, "bronzeDim", "ARTWORK")
    frame.rule:SetHeight(1)
    frame.rule:SetPoint("TOPLEFT", 16, -80); frame.rule:SetPoint("TOPRIGHT", -16, -80)

    frame.intro = UI.Text(frame, 13, "textDim")
    frame.intro:SetPoint("TOPLEFT", 16, -94)
    frame.intro:SetWidth(W - 32)
    frame.intro:SetWordWrap(true)
    frame.intro:SetJustifyH("LEFT")

    frame.profs = {}
    frame.second = UI.Text(frame, 11, "bronze", nil, nil, true)
    frame.second:SetText(ns.Upper(L.PSYNC_SECONDARY))
    frame.second:Hide()
    frame.steps = {}
    for i = 1, 3 do
        local r = CreateFrame("Frame", nil, frame)
        r.num = UI.Panel(r, "accentDim", "accent")
        r.num:SetSize(20, 20)
        r.num:SetPoint("TOPLEFT", 0, 0)
        r.num.text = UI.Text(r.num, 12, "accent", "CENTER", nil, true)
        r.num.text:SetPoint("CENTER", 0, 0)
        r.num.text:SetText(tostring(i))
        r.text = UI.Text(r, 13, "text")
        r.text:SetPoint("TOPLEFT", 30, -2)
        r.text:SetWidth(W - 32 - 30)
        r.text:SetWordWrap(true)
        r.text:SetJustifyH("LEFT")
        frame.steps[i] = r
    end

    frame.status = UI.Text(frame, 12, "muted")
    frame.status:SetPoint("BOTTOMLEFT", 16, 26)
    frame.status:SetWidth(W - 32 - 150)
    frame.status:SetJustifyH("LEFT")
    frame.ok = UI.Button(frame, L.PSYNC_OK, 130, 32, function() frame:Hide() end)
    frame.ok:SetPoint("BOTTOMRIGHT", -16, 16)
    UI.Skin(frame.ok, "accentDim", "accent")
    frame.ok:SetScript("OnLeave", function(self)
        self:SetBackdropColor(Theme.Color("accentDim")); self:SetBackdropBorderColor(Theme.Color("accent")); GameTooltip:Hide()
    end)
end

local function profRow(i)
    local r = frame.profs[i]
    if r then return r end
    r = CreateFrame("Frame", nil, frame)
    r:SetSize(W - 32, 24)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT", 0, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = UI.Text(r, 13, "text")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 10, 0)
    -- one click opens the profession window (secure spell button, set up out of combat only)
    r.open = CreateFrame("Button", "LiebeGruesseProfSyncOpen" .. i, r, "SecureActionButtonTemplate, BackdropTemplate")
    r.open:SetSize(84, 22)
    r.open:SetPoint("RIGHT", 0, 0)
    r.open:RegisterForClicks("AnyUp", "AnyDown")
    UI.Skin(r.open, "button", "border")
    r.open.label = UI.Text(r.open, 12, "text", "CENTER")
    r.open.label:SetPoint("CENTER", 0, 0)
    r.open.label:SetText(L.PSYNC_OPEN)
    r.open:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(Theme.Color("accent"))
        local lines = { self.known and L.PSYNC_OPEN_TIP or L.PSYNC_OPEN_UNKNOWN }
        if frame.test then lines[#lines + 1] = Theme.HexColor("muted", L.PSYNC_TEST_TIP) end
        UI.Tooltip(self, self.profName or "", lines)
    end)
    r.open:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(Theme.Color(self.next and "accent" or "border")); GameTooltip:Hide()
    end)
    r.state = UI.Text(r, 12, "muted", "RIGHT")
    r.state:SetPoint("RIGHT", r.open, "LEFT", -10, 0)
    frame.profs[i] = r
    return r
end

-- lays the window out; rows turn green once their profession was read
function PS.Update()
    if not frame then return end
    local list = frame.list or {}
    local missing = {}
    if frame.test then
        for k, v in pairs(frame.testDone or {}) do missing[k] = not v end
    else
        for _, key in ipairs(PS.Missing()) do missing[key] = true end
    end
    local y = 94
    frame.intro:SetText(L.PSYNC_INTRO)
    y = y + math.max(18, frame.intro:GetStringHeight() or 18) + 12
    local open = 0
    local nextSet = false
    local secureOk = not InCombatLockdown()
    local headShown = false
    for i, key in ipairs(list) do
        -- secondary professions under their own small heading
        if SECONDARY[key] and not headShown and i > 1 then
            headShown = true
            frame.second:ClearAllPoints()
            frame.second:SetPoint("TOPLEFT", 16, -(y + 6))
            frame.second:Show()
            y = y + 24
        end
        local r = profRow(i)
        local info = ns.Crafts.ProfInfo(key)
        r.icon:SetTexture(info and info.icon or 134400)
        r.name:SetText(ns.Crafts.ProfName(key))
        local b = r.open
        -- no recipe window (fishing): nothing to sync, the skill is shared with the profile
        local skillOnly = not syncable(key)
        local done = skillOnly or not missing[key]
        if not done then open = open + 1 end
        b.profName = PS.SpellName(key)
        b.known = knowsSpell(b.profName)
        if secureOk then
            -- test: the button shows, but casts nothing
            local cast = b.known and not frame.test and not skillOnly
            b:SetAttribute("type", cast and "spell" or nil)
            b:SetAttribute("spell", cast and b.profName or nil)
            b:SetShown(not skillOnly)
        end
        b.next = not done and not nextSet
        if b.next then nextSet = true end
        b.label:SetText(done and L.PSYNC_REOPEN or L.PSYNC_OPEN)
        b.label:SetTextColor(Theme.Color((b.known or frame.test) and (b.next and "accent" or "text") or "muted"))
        b:SetBackdropBorderColor(Theme.Color(b.next and "accent" or "border"))
        if skillOnly then
            local rank, max = skill(key)
            r.state:SetText(Theme.HexColor("muted", rank and L.PSYNC_STATE_SKILL:format(rank, max or "?") or L.PSYNC_STATE_NORECIPES))
        else
            r.state:SetText(done and Theme.HexColor("good", L.PSYNC_STATE_DONE) or Theme.HexColor("warn", L.PSYNC_STATE_OPEN))
        end
        r.state:ClearAllPoints()
        if b:IsShown() then r.state:SetPoint("RIGHT", b, "LEFT", -10, 0) else r.state:SetPoint("RIGHT", r, "RIGHT", 0, 0) end
        r.icon:SetDesaturated(done and not skillOnly)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 16, -y)
        r:Show()
        y = y + 26
    end
    if not headShown then frame.second:Hide() end
    for i = #list + 1, #frame.profs do frame.profs[i]:Hide() end
    y = y + 12
    local texts = { L.PSYNC_STEP1, L.PSYNC_STEP2, L.PSYNC_STEP3 }
    for i, r in ipairs(frame.steps) do
        r.text:SetText(texts[i])
        local h = math.max(20, (r.text:GetStringHeight() or 16) + 4)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 16, -y)
        r:SetSize(W - 32, h)
        y = y + h + 8
    end
    if open == 0 then
        frame.status:SetText(Theme.HexColor("good", L.PSYNC_ALL_DONE))
    else
        frame.status:SetText(L.PSYNC_OPEN_COUNT:format(open))
    end
    frame:SetHeight(y + 70)
end

-- list: profession keys to show (default: all of ours, main ones first)
function PS.Show(list, test)
    -- the window holds secure buttons: only shown out of combat
    if InCombatLockdown() then
        ns.Print(L.PSYNC_AFTER_COMBAT)
        ns.AfterCombat("profsync-show", function() PS.Show(list, test) end)
        return
    end
    if not frame then create() end
    frame.list = list or PS.All()
    frame.test = test
    if test then
        frame.testDone = {}
        for _, key in ipairs(frame.list) do frame.testDone[key] = false end
    end
    frame.kicker:SetText(ns.Upper(L.PSYNC_KICKER) .. (test and ("  ·  " .. ns.Upper(L.PSYNC_TEST)) or ""))
    frame.title:SetText(L.PSYNC_TITLE)
    frame:Show()
    PS.Update()
    ns.After(0, PS.Update)   -- string heights are final one frame later
    ns.After(0.3, function() if frame:IsShown() then Theme.Refont(frame); PS.Update() end end)
end

-- after login: once per character and set of unread professions
local function check()
    if not moduleOn() or not settings().profSyncHint then return end
    -- the setup assistant shows open professions at login itself
    if ns.Setup and ns.Setup.AutoEnabled() then return end
    local list = PS.Missing()
    if #list == 0 then return end
    local char = ns.Database.Char()
    local sig = table.concat(list, ",")
    if char.profSyncHinted == sig then return end
    -- the "what's new" window goes first
    local wn = _G.LiebeGruesseWhatsNew
    if wn and wn:IsShown() then
        if not PS.waiting then
            PS.waiting = true
            wn:HookScript("OnHide", function()
                if PS.waiting then PS.waiting = false; ns.After(1, function() ns.AfterCombat("profsync", check) end) end
            end)
        end
        return
    end
    char.profSyncHinted = sig
    PS.Show()
end

-- fires right before combat lockdown: the secure buttons may still be hidden
ns.On("PLAYER_REGEN_DISABLED", function() if frame and frame:IsShown() then frame:Hide() end end)

ns.On("LG_READY", function()
    if settings().profSyncHint == nil then settings().profSyncHint = true end
    -- professions are read a few seconds after login
    ns.After(12, function() ns.AfterCombat("profsync", check) end)
end)

-- /lg test profsync: window with sample professions and the chat lines (nothing is stored)
function PS.Test()
    PS.Show({ "alchemy", "tailoring", "cooking", "firstaid", "fishing" }, true)
    ns.Print(L.TEST_TAG .. " " .. L.PSYNC_START)
    ns.After(2, function()
        ns.Print(L.TEST_TAG .. " " .. L.PSYNC_DONE:format(Theme.HexColor("accent", ns.Crafts.ProfName("tailoring")), 87))
        if frame and frame.test then frame.testDone.tailoring = true; PS.Update() end
    end)
end
