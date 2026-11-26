-- Notifications for guild milestones: level 10/20/…/60, epic loot, boss kills,
-- profession milestones, guild firsts, new members. Each type can be switched
-- off; milestones offer a one-click congratulation. The guild master and
-- officers can also pop an announcement for the whole guild (AN).
local _, ns = ...
local Notify = {}
ns.Notify = Notify
local UI, L, Names, Items, Theme, Comm = ns.UI, ns.L, ns.Names, ns.Items, ns.Theme, ns.Comm

local ICONS = { lvl = 136064, join = 136116, leave = 136116, boss = 135966, loot = 133784, prof = 136249, first = 236685, lc = 133785 }
local SOUND_MILESTONE, SOUND_EPIC = "milestone", "epic"  -- own files in Media/Sounds, volume via ns.Sound

function Notify.Settings()
    local s = ns.Database.Settings()
    s.notify = s.notify or {}
    local n = s.notify
    local defaults = { level = true, levelMin = 10, loot = true, lootQuality = 4, boss = true, dungeonBoss = false, prof = true, first = true,
        join = true, leave = false, lc = false, profcd = true, sound = true, chat = false, gratz = true,
        announce = true, annSound = true, update = true }
    for k, v in pairs(defaults) do if n[k] == nil then n[k] = v end end
    return n
end

local function display(key)
    local g = ns.Guild.Find(key)
    local m = ns.Database.Member(key)
    return Names.Display(g and g.name or (m and m.name) or key)
end

local function congratulate(text) ns.SendChat(text, "GUILD") end

local function whisperTarget(key)
    local g = ns.Guild.Find(key)
    return g and g.name or display(key)
end

-- Called by the feed for every new entry that should notify
function Notify.Feed(e, test)
    local s = Notify.Settings()
    if not test then
        if ns.Database.Settings().modules.feed == false then return end
        if Names.Same(e.a, Names.Me()) or ns.Now() - (e.t or 0) > 600 then return end
    end
    local d = e.d or {}
    local text = ns.Feed.Text(e)
    local title, opts, icon = L.FEED_TOAST_TITLE, {}, ICONS[e.k]
    if e.k == "lvl" then
        if not s.level or (d.l or 0) < s.levelMin then return end
        title = (d.l or 0) >= 60 and L.NOTIFY_MAX_LEVEL or L.NOTIFY_MILESTONE
        opts.big = true
        if s.sound then opts.sound = SOUND_MILESTONE end
        if s.gratz then
            local msg = ns.Messages.Format("gratzLevel", { player = display(e.a), level = d.l or 0 })
            opts.actionText = L.NOTIFY_CLICK_GRATZ
            opts.action = function() congratulate(msg) end
        end
    elseif e.k == "loot" then
        local info = Items.Info(d.i)
        if not s.loot or (info and (info.quality or 0) < s.lootQuality) then return end
        title = L.NOTIFY_EPIC
        icon = Items.Icon(d.i) or icon
        if info and info.quality and GetItemQualityColor then
            local ok, r, g, b = pcall(GetItemQualityColor, info.quality)
            if ok and type(r) == "number" then opts.iconColor = { r, g, b } end
        end
        if s.sound then opts.sound = SOUND_EPIC end
        if s.gratz then
            opts.actionText = L.NOTIFY_CLICK_WHISPER_GRATZ
            opts.action = function() ns.SendChat(ns.Messages.Format("gratzLoot", { player = display(e.a), item = Items.Link(d.i) or "?" }), "WHISPER", whisperTarget(e.a)) end
        end
    elseif e.k == "boss" then
        if not s.boss then return end
        -- dungeon bosses only when wanted: raid flag, or a group larger than five
        local raid = d.r or (tonumber(d.s) or 0) > 5
        if not raid and not s.dungeonBoss then return end
        title = L.NOTIFY_BOSS
        text = L.NOTIFY_BOSS_TEXT:format(Theme.HexColor("gold", d.b or "?"))
    elseif e.k == "prof" then
        if not s.prof then return end
        title = L.NOTIFY_MILESTONE
        if s.gratz then
            local msg = ns.Messages.Format("gratzProf", { player = display(e.a), profession = ns.Feed.ProfLabel(d.p), skill = d.s or 0 })
            opts.actionText = L.NOTIFY_CLICK_GRATZ
            opts.action = function() congratulate(msg) end
        end
    elseif e.k == "first" then
        if not s.first then return end
        title = L.NOTIFY_FIRST
        opts.big = true
        if s.sound then opts.sound = SOUND_MILESTONE end
    elseif e.k == "join" then
        if not s.join then return end
        title = L.NOTIFY_JOIN
        if s.gratz then
            local msg = ns.Messages.Format("welcome", { player = display(e.a) })
            opts.actionText = L.NOTIFY_CLICK_WELCOME
            opts.action = function() congratulate(msg) end
        end
    elseif e.k == "leave" then
        if not s.leave then return end
    elseif e.k == "lc" then
        if not s.lc then return end
    else
        return
    end
    if test then title = L.TEST_TAG .. " " .. title end
    -- details on the toast; everything else on hover
    opts.kicker = title
    opts.lines, opts.classes = ns.Feed.ToastInfo(e)
    if e.k == "lvl" then
        local class = ns.Guild.Find(e.a) and ns.Guild.Find(e.a).class or (ns.Database.Member(e.a) or {}).c
        if class then
            opts.iconColor = { ns.ClassColor(class) }
        end
    end
    opts.onEnter = function(owner) ns.Feed.ShowTooltip(owner, e, opts.actionText) end
    UI.Toast(title, text, icon, opts)
    if s.chat then ns.Print(text) end
end

-- Test: one of each, nothing is saved
function Notify.Test(kind)
    local me = Names.Me()
    local item = "item:19019"
    -- a mixed test group from the roster (the own character when alone)
    local group = {}
    for _, key in ipairs(ns.Guild.order or {}) do if #group < 18 then group[#group + 1] = key end end
    if #group == 0 then for i = 1, 12 do group[i] = me end end
    local samples = {
        lvl = { k = "lvl", a = me, d = { l = 60, z = L.TEST_ZONE } },
        loot = { k = "loot", a = me, d = { i = item, m = L.TEST_BOSS, ins = L.TEST_INSTANCE } },
        boss = { k = "boss", a = me, d = { b = L.TEST_BOSS, n = 12, s = 40, dur = 154, ins = L.TEST_INSTANCE, r = true,
            g = group } },
        prof = { k = "prof", a = me, d = { p = L.PROFESSION, s = 300 } },
        first = { k = "first", a = me, d = { w = "lvl", l = 60 } },
        join = { k = "join", a = me },
    }
    local list = kind and { kind } or { "lvl", "loot", "boss", "join" }
    for i, k in ipairs(list) do
        local e = samples[k]
        if e then
            e.t, e.id = ns.Now(), "test:" .. k
            ns.After((i - 1) * 0.8, function() Notify.Feed(e, true) end)
        end
    end
end


---------------------------------------------------------------------------
-- Announcements: the guild master and officers (rank 0/1) pop a notification
-- for everyone in the guild who has the addon. Guild channel only, checked
-- against the sender's rank; shown as a toast and printed to chat.
---------------------------------------------------------------------------
local ANNOUNCE_MAX, ANNOUNCE_TITLE_MAX, ANNOUNCE_GAP = 200, 40, 10
local lastAnnounce, announceSeen = -ANNOUNCE_GAP, {}
Notify.ANNOUNCE_MAX = ANNOUNCE_MAX

function Notify.CanAnnounce()
    return IsInGuild() and ns.Guild.IsOfficer(Names.Me()) == true
end

local function tidy(text, max)
    text = tostring(text or ""):gsub("|", ""):gsub("[\r\n]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #text > max then text = text:sub(1, max) end
    return text
end

local function senderName(key)
    local g = ns.Guild.Find(key)
    local class = (g and g.class) or (ns.Database.Member(key) or {}).c
    return class and ns.ColorName(g and g.name or key, class) or display(key)
end

local function showAnnouncement(title, text, from, sound, test)
    local s = Notify.Settings()
    if not test and not s.announce then return end
    local kicker = title ~= "" and title or L.ANNOUNCE_KICKER
    if test then kicker = L.TEST_TAG .. " " .. kicker end
    local who = senderName(from)
    UI.Toast(kicker, text, nil, {
        kicker = kicker, big = true, duration = 20, wrap = 6,
        lines = { L.ANNOUNCE_FROM:format(who) },
        sound = (sound and s.sound and s.annSound) and SOUND_MILESTONE or nil,
    })
    -- also in chat: a toast is easy to miss (and waits during combat)
    ns.Print(L.ANNOUNCE_CHAT:format((test and (L.TEST_TAG .. " ") or "") .. who, text))
end

-- sends an announcement to the guild; returns true when it went out
function Notify.Announce(text, title, sound)
    if not Notify.CanAnnounce() then ns.Print(L.ANNOUNCE_ONLY_OFFICERS); return false end
    text, title = tidy(text, ANNOUNCE_MAX), tidy(title, ANNOUNCE_TITLE_MAX)
    if text == "" then ns.Print(L.ANNOUNCE_EMPTY); return false end
    local wait = ANNOUNCE_GAP - (GetTime() - lastAnnounce)
    if wait > 0 then ns.Print(L.ANNOUNCE_WAIT:format(math.ceil(wait))); return false end
    lastAnnounce = GetTime()
    local id = ("%d%04d"):format(ns.Now(), math.random(0, 9999))
    announceSeen[id] = true
    Comm.Send("AN", { x = text, h = title ~= "" and title or nil, s = sound and 1 or nil, t = ns.Now(), id = id },
        "GUILD", { priority = "alert" })
    -- our own guild messages are not echoed back: show it here as well
    showAnnouncement(title, text, Names.Me(), sound)
    return true
end

Comm.Register("AN", function(data, sender, channel)
    if channel ~= "GUILD" or not ns.Guild.IsOfficer(sender) then return end
    if type(data.x) ~= "string" or (data.h ~= nil and type(data.h) ~= "string") then return end
    local t = tonumber(data.t)
    -- live only: not from the future, not older than 10 minutes
    if not t or t > ns.Now() + 120 or ns.Now() - t > 600 then return end
    local id = tostring(data.id or (sender .. t))
    if announceSeen[id] then return end
    announceSeen[id] = true
    local text, title = tidy(data.x, ANNOUNCE_MAX), tidy(data.h, ANNOUNCE_TITLE_MAX)
    if text == "" then return end
    showAnnouncement(title, text, sender, data.s == 1)
end)

-- /lg test announce: how an announcement looks (nothing sent)
function Notify.TestAnnounce(text)
    showAnnouncement(L.ANNOUNCE_TEST_TITLE, (text and text ~= "") and tidy(text, ANNOUNCE_MAX) or L.ANNOUNCE_TEST_TEXT,
        Names.Me(), true, true)
end

---------------------------------------------------------------------------
-- Settings page
---------------------------------------------------------------------------
UI.AddPage("notifications", L.PAGE_NOTIFY, 91, function(content, page)
    local form = UI.Form(content)
    page.Search = function(text) return form:Filter(text) end
    page.SearchEnter = function() form:JumpFirst() end
    page.head = L.HEAD_NOTIFY
    form.scroll:SetPoint("TOPLEFT")
    form.scroll:SetPoint("BOTTOMRIGHT", -8, 0)
    local function get(k) return function() return Notify.Settings()[k] end end
    local function set(k) return function(v) Notify.Settings()[k] = v end end

    local general = form:Section(L.NOTIFY_GENERAL)
    general:Note(L.NOTIFY_HINT, { col = 0, height = 30 })
    general:Toggle(L.NOTIFY_ENABLED, function() return ns.Database.Settings().toasts end,
        function(v) ns.Database.Settings().toasts = v end, { tip = L.SET_TOASTS_TIP })
    general:Toggle(L.NOTIFY_SOUND, get("sound"), set("sound"), { col = 2 })
    general:Slider(L.SOUND_VOLUME, 0, 100, 5, function() return ns.SoundVolume() end,
        function(v) ns.Database.Settings().soundVolume = v end,
        { tip = L.SOUND_VOLUME_TIP, fmt = function(v) return v == 0 and L.SOUND_OFF or (v .. " %") end })
    general:Buttons({ { L.SOUND_TEST, function() ns.Sound("milestone") end } }, { col = 2 })
    general:Toggle(L.NOTIFY_GRATZ, get("gratz"), set("gratz"), { tip = L.NOTIFY_GRATZ_TIP })
    general:Toggle(L.NOTIFY_CHAT, get("chat"), set("chat"), { col = 2, tip = L.NOTIFY_CHAT_TIP })

    local what = form:Section(L.NOTIFY_WHAT)
    what:Toggle(L.NOTIFY_LEVEL, get("level"), set("level"))
    what:Segment(L.NOTIFY_LEVEL_FROM, { { value = 10, text = "10+" }, { value = 40, text = "40+" }, { value = 60, text = "60" } },
        get("levelMin"), set("levelMin"), { col = 2, width = 180, show = function() return Notify.Settings().level end })
    what:Toggle(L.NOTIFY_LOOT, get("loot"), set("loot"), { tip = L.NOTIFY_LOOT_TIP })
    what:Segment(L.NOTIFY_LOOT_FROM, { { value = 3, text = L.QUALITY_RARE }, { value = 4, text = L.QUALITY_EPIC }, { value = 5, text = L.QUALITY_LEGENDARY } },
        get("lootQuality"), set("lootQuality"), { col = 2, width = 240, show = function() return Notify.Settings().loot end })
    what:Toggle(L.NOTIFY_BOSSES, get("boss"), set("boss"))
    what:Toggle(L.NOTIFY_DUNGEON_BOSS, get("dungeonBoss"), set("dungeonBoss"), { tip = L.NOTIFY_DUNGEON_BOSS_TIP, show = function() return Notify.Settings().boss end })
    what:Toggle(L.NOTIFY_PROF, get("prof"), set("prof"), { col = 2 })
    what:Toggle(L.NOTIFY_FIRSTS, get("first"), set("first"))
    what:Toggle(L.NOTIFY_JOINS, get("join"), set("join"), { col = 2 })
    what:Toggle(L.NOTIFY_LEAVES, get("leave"), set("leave"))
    what:Toggle(L.NOTIFY_LC, get("lc"), set("lc"), { col = 2 })
    what:Toggle(L.NOTIFY_PROFCD, get("profcd"), set("profcd"), { tip = L.NOTIFY_PROFCD_TIP })
    what:Toggle(L.NOTIFY_ANNOUNCE, get("announce"), set("announce"), { col = 2, tip = L.NOTIFY_ANNOUNCE_TIP })
    what:Toggle(L.NOTIFY_ANNOUNCE_SOUND, get("annSound"), set("annSound"),
        { tip = L.NOTIFY_ANNOUNCE_SOUND_TIP, show = function() return Notify.Settings().announce end })

    what:Toggle(L.NOTIFY_UPDATE, get("update"), set("update"), { col = 2, tip = L.NOTIFY_UPDATE_TIP })
    what:Toggle(L.NOTIFY_FAILVOTE, function() return ns.Database.Settings().community.failVote == true end,
        function(v) ns.Database.Settings().community.failVote = v end, { tip = L.NOTIFY_FAILVOTE_TIP })

    -- what the congratulation clicks write (placeholders)
    local msgs = form:Section(L.MSG_SECTION, { wide = true })
    msgs:Note(L.MSG_HINT, { col = 0, height = 30 })
    ns.Messages.Rows(msgs, { "gratzLevel", "gratzLoot", "gratzProf", "welcome" })

    local test = form:Section(L.NOTIFY_TEST)
    test:Buttons({
        { L.NOTIFY_TEST_LEVEL, function() Notify.Test("lvl") end, width = 170 },
        { L.NOTIFY_TEST_LOOT, function() Notify.Test("loot") end, width = 170 },
        { L.NOTIFY_TEST_JOIN, function() Notify.Test("join") end, width = 170 },
        { L.NOTIFY_TEST_ANNOUNCE, function() Notify.TestAnnounce() end, width = 170 },
        { L.MOVE_ELEMENTS, function() ns.Window.ToggleMovers() end, width = 170, icon = "move" },
    }, { col = 0 })
    -- announcement composer (guild master and officers)
    local ann = form:Section(L.ANNOUNCE_SECTION, { wide = true })
    local officer = function() return Notify.CanAnnounce() end
    local draft = function()
        local st = ns.Database.Settings()
        st.announceDraft = st.announceDraft or { sound = true }
        return st.announceDraft
    end
    ann:Note(L.ANNOUNCE_HINT, { col = 0, height = 30, show = officer })
    ann:Note(L.ANNOUNCE_NOT_OFFICER, { col = 0, height = 30, show = function() return not officer() end })
    local titleEdit = ann:Edit(L.ANNOUNCE_TITLE, function() return draft().title end,
        function(v) draft().title = v end, { width = 260, placeholder = L.ANNOUNCE_KICKER, show = officer })
    local textEdit, textRow = ann:Edit(L.ANNOUNCE_TEXT, function() return draft().text end,
        function(v) draft().text = v end, { width = 420, placeholder = L.ANNOUNCE_TEXT_PH, show = officer,
            tip = L.ANNOUNCE_TEXT_TIP:format(ANNOUNCE_MAX) })
    if textEdit.SetMaxLetters then textEdit:SetMaxLetters(ANNOUNCE_MAX) end
    -- the message box grows with the card, but leaves room for its label
    textRow:HookScript("OnSizeChanged", function(row)
        local w = math.floor(math.max(160, math.min(420, (row:GetWidth() or 0) - 140)))
        textEdit:SetWidth(w)
        if row.label then row.label:SetPoint("RIGHT", row, "RIGHT", -(w + 24), 0) end
    end)
    if titleEdit.SetMaxLetters then titleEdit:SetMaxLetters(ANNOUNCE_TITLE_MAX) end
    ann:Toggle(L.ANNOUNCE_SOUND, function() return draft().sound ~= false end, function(v) draft().sound = v end,
        { show = officer, tip = L.ANNOUNCE_SOUND_TIP })
    -- the edit boxes may still have focus: read them directly
    local function current()
        local d = draft()
        d.title, d.text = titleEdit:GetText() or "", textEdit:GetText() or ""
        return d
    end
    ann:Buttons({
        { L.ANNOUNCE_PREVIEW, function()
            local d = current()
            showAnnouncement(tidy(d.title, ANNOUNCE_TITLE_MAX), tidy(d.text, ANNOUNCE_MAX) ~= "" and tidy(d.text, ANNOUNCE_MAX)
                or L.ANNOUNCE_TEST_TEXT, Names.Me(), d.sound ~= false, true)
        end, width = 150, icon = "sparkles", tip = L.ANNOUNCE_PREVIEW_TIP },
        { L.ANNOUNCE_SEND, function()
            local d = current()
            if Notify.Announce(d.text, d.title, d.sound ~= false) then
                d.text = ""
                textEdit:SetText("")
                textEdit:ClearFocus()
            end
        end, width = 170, icon = "megaphone", tip = L.ANNOUNCE_SEND_TIP },
    }, { col = 0, show = officer })

    page.OnShow = function() form:Refresh() end
end, { section = "settings", icon = "newspaper" })
