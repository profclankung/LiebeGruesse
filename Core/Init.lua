-- Liebe Grüße Guild Tools: namespace, events, modules, safety helpers
local ADDON, ns = ...
LiebeGruesse = ns

ns.name = ADDON
local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (getMeta and getMeta(ADDON, "Version")) or "dev"
ns.media = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"

-- Addon sounds: own quiet files in fixed volume steps (WoW cannot set the volume of a
-- single sound). settings.soundVolume: 0 = off … 100, default 5 %.
local SOUND_STEPS = { 5, 10, 15, 20, 25, 30, 40, 50, 60, 70, 80, 90, 100 }
function ns.SoundVolume()
    local s = ns.Database and ns.Database.Settings and ns.Database.Settings()
    local v = s and tonumber(s.soundVolume)
    return v or 5
end
function ns.Sound(name, volume)
    volume = volume or ns.SoundVolume()
    if not name or volume <= 0 or not PlaySoundFile then return end
    local best = SOUND_STEPS[1]
    for _, step in ipairs(SOUND_STEPS) do
        if math.abs(step - volume) < math.abs(best - volume) then best = step end
    end
    pcall(PlaySoundFile, ns.media .. "Sounds\\" .. name .. "_" .. best .. ".ogg", "Master")
end
ns.title = "Liebe Grüße"
-- CurseForge page (not public): install once from the website, then the CurseForge app updates it
ns.DOWNLOAD_URL = "https://www.curseforge.com/wow/addons/lgguild"
-- copy box with the link (the game cannot open web pages or the clipboard)
function ns.ShowDownloadLink()
    if ns.Share and ns.Share.ShowText then ns.Share.ShowText(ns.L.DL_TITLE, ns.L.DL_HINT, ns.DOWNLOAD_URL) end
end

---------------------------------------------------------------------------
-- Secret values / safe calls
---------------------------------------------------------------------------
function ns.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Removes secret values from a returned table (and the tables inside it), so
-- that later comparisons or arithmetic never touch a secret value.
local function scrub(t, depth)
    if depth > 4 then return end
    local secretKeys
    for k, v in pairs(t) do
        if ns.IsSecret(v) or ns.IsSecret(k) then
            secretKeys = secretKeys or {}
            secretKeys[#secretKeys + 1] = k
        elseif type(v) == "table" then
            scrub(v, depth + 1)
        end
    end
    if secretKeys then
        for _, k in ipairs(secretKeys) do pcall(function() t[k] = nil end) end
    end
end
ns.Scrub = function(t) if type(t) == "table" then pcall(scrub, t, 0) end return t end

-- Calls fn safely. Returns nil for missing functions, errors and secret values;
-- secret fields of returned tables are removed.
function ns.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local result = { pcall(fn, ...) }
    if not result[1] then return nil end
    for i = 2, table.maxn(result) do
        local v = result[i]
        if ns.IsSecret(v) then result[i] = nil
        elseif type(v) == "table" then pcall(scrub, v, 0) end
    end
    return unpack(result, 2, table.maxn(result))
end

-- true for a normal (non-secret) number
function ns.Num(v)
    return type(v) == "number" and not ns.IsSecret(v)
end

-- errors of our own wrappers also go to the bug reporter (Modules/Bugs), even
-- when another addon owns the global error handler
local function report(err)
    if ns.OnOwnError then pcall(ns.OnOwnError, err, debugstack and debugstack(3) or nil) end
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) else print(err) end
end

function ns.Safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then report(err) end
    return ok
end

-- like ns.Safe, but returns the function's results (nil after an error)
function ns.Try(fn, ...)
    local r = { pcall(fn, ...) }
    if not r[1] then report(r[2]); return nil end
    return unpack(r, 2, table.maxn(r))
end

function ns.Guard(fn)
    return function(...) return ns.Safe(fn, ...) end
end

function ns.Print(text, ...)
    if select("#", ...) > 0 then text = text:format(...) end
    print("|cffe8c27aLiebe Grüße|r: " .. tostring(text))
end

---------------------------------------------------------------------------
-- Events and internal messages
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
ns.eventFrame = frame
local listeners = {}

function ns.On(event, fn)
    local list = listeners[event]
    if not list then
        list = {}
        listeners[event] = list
        if not event:match("^LG_") then
            pcall(frame.RegisterEvent, frame, event)
        end
    end
    list[#list + 1] = fn
end

function ns.Fire(event, ...)
    local list = listeners[event]
    if not list then return end
    for i = 1, #list do ns.Safe(list[i], event, ...) end
end

frame:SetScript("OnEvent", function(_, event, ...) ns.Fire(event, ...) end)

---------------------------------------------------------------------------
-- Timers
---------------------------------------------------------------------------
function ns.After(seconds, fn)
    C_Timer.After(seconds, ns.Guard(fn))
end

local debounced = {}
-- Runs fn once, `seconds` after the last call with the same key.
function ns.Debounce(key, seconds, fn)
    local old = debounced[key]
    if old then old:Cancel() end
    debounced[key] = C_Timer.NewTimer(seconds, function()
        debounced[key] = nil
        ns.Safe(fn)
    end)
end

function ns.CancelDebounce(key)
    local old = debounced[key]
    if old then old:Cancel(); debounced[key] = nil end
end

---------------------------------------------------------------------------
-- A real raid instance. Ten-player dungeons run as a raid group (e.g. Upper
-- Blackrock Spire) do not count: known dungeons and raids for 10 or fewer.
---------------------------------------------------------------------------
function ns.RaidInstance()
    local inside, kind = ns.Call(IsInInstance)
    if inside ~= true or kind ~= "raid" then return false end
    local _, _, _, _, maxPlayers, _, _, inst = ns.Call(GetInstanceInfo)
    local wings = ns.RunsData and ns.Num(inst) and ns.RunsData.BY_INST[inst]
    if wings and wings[1] then return wings[1].kind == "raid" end
    if ns.Num(maxPlayers) and maxPlayers > 0 and maxPlayers <= 10 then return false end
    return true
end

---------------------------------------------------------------------------
-- Restrictions (combat, encounters, chat lockdown)
---------------------------------------------------------------------------
function ns.EncounterInProgress()
    local api = C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress
    if api then
        local running = ns.Call(api)
        if running ~= nil then return running == true end
    end
    return ns.Call(IsEncounterInProgress) == true
end

-- every restriction the client knows counts (new ones too), not only a fixed list
function ns.Restrictions()
    local out = {}
    local api, types = C_RestrictedActions, Enum and Enum.AddOnRestrictionType
    if api and api.IsAddOnRestrictionActive and type(types) == "table" then
        for name, kind in pairs(types) do
            if type(kind) == "number" then
                out[#out + 1] = { name = tostring(name), on = ns.Call(api.IsAddOnRestrictionActive, kind) == true }
            end
        end
        table.sort(out, function(a, b) return a.name < b.name end)
    end
    return out
end
function ns.CommsRestricted()
    for _, r in ipairs(ns.Restrictions()) do
        if r.on then return true, r.name:lower() end
    end
    if ns.EncounterInProgress() then return true, "encounter" end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and ns.Call(C_ChatInfo.InChatMessagingLockdown) == true then
        return true, "chat"
    end
    return false
end

-- Sends a chat message safely: only boss
-- encounters block it. Returns true when the message was handed to the game.
function ns.SendChat(text, chatType, target)
    if ns.EncounterInProgress() then
        ns.Print(ns.L.CD_CHAT_LOCKED)
        return false
    end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if not send then return false end
    local ok, err = pcall(send, text, chatType, nil, target)
    if not ok then ns.Print("%s (%s)", ns.L.CHAT_FAILED, tostring(err)) end
    return ok
end

function ns.InCombat()
    return InCombatLockdown() or ns.EncounterInProgress()
end

local afterCombat = {}
function ns.AfterCombat(key, fn)
    if not ns.InCombat() then return ns.Safe(fn) end
    afterCombat[key] = fn
end
local function flushAfterCombat()
    if ns.InCombat() then return end
    local list = afterCombat
    afterCombat = {}
    for _, fn in pairs(list) do ns.Safe(fn) end
end
ns.On("PLAYER_REGEN_ENABLED", function() ns.After(0.5, flushAfterCombat) end)
ns.On("ENCOUNTER_END", function() ns.After(1, flushAfterCombat) end)

-- Automatic chat messages (craft answers, greetings) must never be sent while the
-- game could block them: in combat (also the plain "in combat" flag, which the
-- lockdown check misses), during encounters or a chat lockdown.
-- the game blocked an action of this addon (e.g. a chat line it did not allow):
-- automatic chat pauses for two minutes instead of failing again
local function onBlocked(event, addon, fn)
    if addon ~= "LiebeGruesse" then return end
    if not ns.blockedAt then ns.Print(ns.L.CHAT_BLOCKED_ONCE) end
    ns.blockedAt = GetTime()
    ns.blockCount = (ns.blockCount or 0) + 1
    ns.lastBlock = { t = time and time() or 0, fn = tostring(fn or "?"), event = event,
        combat = UnitAffectingCombat and ns.Call(UnitAffectingCombat, "player") == true, lockdown = InCombatLockdown() }
end
ns.On("ADDON_ACTION_BLOCKED", onBlocked)
ns.On("ADDON_ACTION_FORBIDDEN", onBlocked)

-- /lg test chat: why automatic chat lines may (not) go out (nothing is sent)
function ns.ChatReport()
    local L = ns.L
    local function yes(v) return v and "|cffff6060yes|r" or "|cff60d060no|r" end
    ns.Print(L.TEST_TAG .. " " .. L.CHAT_REPORT)
    print("  in combat (lockdown / flag): " .. yes(InCombatLockdown()) .. " / " .. yes(UnitAffectingCombat and ns.Call(UnitAffectingCombat, "player") == true))
    print("  encounter: " .. yes(ns.EncounterInProgress()) .. "   chat lockdown: "
        .. yes(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and ns.Call(C_ChatInfo.InChatMessagingLockdown) == true))
    local r = ns.Restrictions()
    if #r == 0 then print("  addon restrictions: (client has none)") end
    for _, x in ipairs(r) do print(("  restriction %s: %s"):format(x.name, yes(x.on))) end
    print("  sends with: " .. ((C_ChatInfo and C_ChatInfo.SendChatMessage) and "C_ChatInfo.SendChatMessage" or "SendChatMessage"))
    local b = ns.lastBlock
    if b then
        print(("  blocked %d× this session, last %s: %s (%s) – combat flag %s, lockdown %s"):format(ns.blockCount or 1,
            date and date("%H:%M:%S", b.t) or "?", b.fn, b.event, yes(b.combat), yes(b.lockdown)))
    else
        print("  blocked this session: " .. yes(false))
    end
    print(("  automatic lines sent: %d in the last minute, %d in 5 minutes"):format(ns.AutoSentSince(60), ns.AutoSentSince(300)))
    local blocked, why = ns.ChatBlocked()
    print("  automatic chat now: " .. (blocked and ("|cffff6060waits|r (" .. tostring(why) .. ")") or "|cff60d060allowed|r"))
end
function ns.ChatBlocked()
    if ns.blockedAt and GetTime() - ns.blockedAt < 120 then return true, "blocked" end
    if InCombatLockdown() then return true, "combat" end
    if UnitAffectingCombat and ns.Call(UnitAffectingCombat, "player") == true then return true, "combat" end
    return ns.CommsRestricted()
end

local autoChat, autoTimer = {}, nil
local AUTO_MAX_WAIT = 600
local function flushAutoChat()
    autoTimer = nil
    if ns.ChatBlocked() then
        -- a chat lockdown ends without a combat event: look again, only while something waits
        if next(autoChat) then autoTimer = C_Timer.NewTimer(5, flushAutoChat) end
        return
    end
    local list = autoChat
    autoChat = {}
    local now = GetTime()
    for _, item in pairs(list) do
        if now - item.t <= AUTO_MAX_WAIT then ns.Safe(item.fn) end
    end
end
-- Runs fn now when chat is allowed, otherwise once it is again (same key = latest wins).
-- Stale entries (older than 10 min) are dropped.
function ns.AutoChat(key, fn)
    if not ns.ChatBlocked() then return ns.Safe(fn) end
    autoChat[key] = { fn = fn, t = GetTime() }
    if not autoTimer then autoTimer = C_Timer.NewTimer(5, flushAutoChat) end
end
-- Sends an automatic chat message through ns.AutoChat.
function ns.SendChatAuto(key, text, chatType, target)
    ns.AutoChat(key, function() if ns.SendChat(text, chatType, target) then ns.MarkAutoSent() end end)
end

-- Forever allows an addon only a few automatic chat lines in a short time (more
-- are blocked): every automatic line is counted, so busy clients leave the next
-- "!lg" answer to the others
local autoSent = {}
function ns.MarkAutoSent()
    autoSent[#autoSent + 1] = GetTime()
    while #autoSent > 20 do table.remove(autoSent, 1) end
end
function ns.AutoSentSince(seconds)
    local n, now = 0, GetTime()
    for _, t in ipairs(autoSent) do if now - t <= seconds then n = n + 1 end end
    return n
end
ns.On("PLAYER_REGEN_ENABLED", function() ns.After(0.6, function() if next(autoChat) then flushAutoChat() end end) end)

---------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------
ns.modules = {}
local byKey = {}

function ns.NewModule(key, def)
    def = def or {}
    def.key = key
    byKey[key] = def
    ns.modules[#ns.modules + 1] = def
    return def
end

function ns.GetModule(key) return byKey[key] end

ns.On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    ns.Database.Init()
    for _, mod in ipairs(ns.modules) do
        if mod.OnInit then ns.Safe(mod.OnInit, mod) end
    end
end)

ns.On("PLAYER_LOGIN", function()
    for _, mod in ipairs(ns.modules) do
        if mod.OnLogin then ns.Safe(mod.OnLogin, mod) end
    end
    ns.Fire("LG_READY")
end)
