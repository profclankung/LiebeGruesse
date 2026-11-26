-- Dungeon interest: members mark the dungeons they would like to run – main
-- role, off spec, a short note and the items they hope for. Everyone sees who
-- wants which dungeon and can whisper or invite them right away, so nobody has
-- to ask "anyone for Strat?" in guild chat. Wanted items show overlaps, so two
-- players who need the same drop know it before the run.
--
-- Messages (own kinds, older addon versions simply ignore them):
--   DI  one member's interest { o = owner, t = time, e = entries } – sent to the
--       guild by the owner on every change, whispered as a sync answer
--   DQ  sync request after login; exactly one member answers (Comm.ReplyOnce)
--   DA  "I answer DQ of <to>" – the other members stay quiet
local _, ns = ...
local UI, Theme, L, Names, Comm = ns.UI, ns.Theme, ns.L, ns.Names, ns.Comm
local Dungeons = ns.NewModule("dungeons")
ns.Dungeons = Dungeons

-- Classic dungeons and the new Forever dungeons (forever = true), sorted by level.
-- Level range: the recommended levels (Forever ones as listed by AtlasLoot Forever).
Dungeons.LIST = {
    { key = "rfc", short = "RFC", name = "Ragefire Chasm", min = 13, max = 18 },
    { key = "thanes", short = "Thanes", name = "Hall of Thanes", min = 13, max = 18, forever = true },
    { key = "lordaeron", short = "Lordaeron", name = "Ruins of Lordaeron", min = 13, max = 18, forever = true },
    { key = "wc", short = "WC", name = "Wailing Caverns", min = 17, max = 24 },
    { key = "vc", short = "VC", name = "The Deadmines", min = 17, max = 26 },
    { key = "sfk", short = "SFK", name = "Shadowfang Keep", min = 22, max = 30 },
    { key = "bfd", short = "BFD", name = "Blackfathom Deeps", min = 24, max = 32 },
    { key = "stocks", short = "Stocks", name = "The Stockade", min = 24, max = 32 },
    { key = "excavation", short = "Excavation", name = "Excavation Site: Wetlands", min = 24, max = 29, forever = true },
    { key = "smgy", short = "SM GY", name = "Scarlet Monastery: Graveyard", min = 26, max = 36 },
    { key = "dalaran", short = "Dalaran", name = "City of Dalaran", min = 28, max = 33, forever = true },
    { key = "gnomer", short = "Gnomer", name = "Gnomeregan", min = 29, max = 38 },
    { key = "rfk", short = "RFK", name = "Razorfen Kraul", min = 29, max = 38 },
    { key = "smlib", short = "SM Lib", name = "Scarlet Monastery: Library", min = 29, max = 39 },
    { key = "smarm", short = "SM Arm", name = "Scarlet Monastery: Armory", min = 32, max = 42 },
    { key = "drowned", short = "Drowned", name = "The Drowned City", min = 35, max = 40, forever = true },
    { key = "smcath", short = "SM Cath", name = "Scarlet Monastery: Cathedral", min = 35, max = 45 },
    { key = "rfd", short = "RFD", name = "Razorfen Downs", min = 37, max = 46 },
    { key = "kroldok", short = "Krol'dok", name = "Krol'dok Stronghold", min = 40, max = 45, forever = true },
    { key = "ulda", short = "Ulda", name = "Uldaman", min = 41, max = 51 },
    { key = "zf", short = "ZF", name = "Zul'Farrak", min = 44, max = 54 },
    { key = "mara", short = "Mara", name = "Maraudon", min = 46, max = 55 },
    { key = "alcaz", short = "Alcaz", name = "Alcaz Prison", min = 48, max = 53, forever = true },
    { key = "st", short = "ST", name = "Sunken Temple", min = 50, max = 60 },
    { key = "brd", short = "BRD", name = "Blackrock Depths", min = 52, max = 60 },
    { key = "blackmaw", short = "Blackmaw", name = "Blackmaw Hold", min = 55, max = 60, forever = true },
    { key = "lbrs", short = "LBRS", name = "Lower Blackrock Spire", min = 55, max = 60 },
    { key = "dme", short = "DM E", name = "Dire Maul East", min = 55, max = 60 },
    { key = "dmw", short = "DM W", name = "Dire Maul West", min = 57, max = 60 },
    { key = "dmn", short = "DM N", name = "Dire Maul North", min = 57, max = 60 },
    { key = "ubrs", short = "UBRS", name = "Upper Blackrock Spire", min = 58, max = 60 },
    { key = "shaper", short = "Shaper", name = "Shaper's Terrace", min = 58, max = 60, forever = true },
    { key = "stratl", short = "Strat Live", name = "Stratholme Live", min = 58, max = 60 },
    { key = "stratud", short = "Strat UD", name = "Stratholme Undead", min = 58, max = 60 },
    { key = "scholo", short = "Scholo", name = "Scholomance", min = 58, max = 60 },
}
Dungeons.BY_KEY = {}
for i, d in ipairs(Dungeons.LIST) do d.order = i; Dungeons.BY_KEY[d.key] = d end

local ROLES = { "T", "H", "D" }
local ROLE_ICON = { T = "shield", H = "sparkles", D = "swords" }
local ROLE_COLOR = { T = "lapis", H = "good", D = "bad" }
local function roleName(r) return (r == "T" and L.DG_TANK) or (r == "H" and L.DG_HEAL) or L.DG_DPS end
-- roles a class can fill in a 5-player dungeon
local CLASS_ROLES = { WARRIOR = "TD", PALADIN = "THD", DRUID = "THD", PRIEST = "HD", SHAMAN = "THD",
    HUNTER = "D", ROGUE = "D", MAGE = "D", WARLOCK = "D" }

function Dungeons.ClassRoles(class)
    local s = CLASS_ROLES[class or ""] or "THD"
    local out = {}
    for _, r in ipairs(ROLES) do if s:find(r, 1, true) then out[#out + 1] = r end end
    return out
end

local MAX_ITEMS, MAX_NOTE = 6, 60
local DAY = 86400
Dungeons.DURATIONS = { 7, 14, 30 }

---------------------------------------------------------------------------
-- Data
--   guild.dungeons[memberKey] = { t = changed, e = { [dungeonKey] = entry } }
--   entry = { r = main role, o = off spec roles ("HD"), n = note,
--             i = "itemId,itemId", a = added/renewed, x = expires }
---------------------------------------------------------------------------
local function settings()
    local s = ns.Database.Settings()
    if type(s.dungeons) ~= "table" then s.dungeons = {} end
    if not s.dungeons.days then s.dungeons.days = 14 end
    return s.dungeons
end
Dungeons.Settings = settings

local function store()
    local g = ns.Database.Guild()
    if type(g.dungeons) ~= "table" then g.dungeons = {} end
    return g.dungeons
end

-- players seen asking for a dungeon in guild chat (local only, never sent):
--   guild.dungeonChat[memberKey][dungeonKey] = { a = seen, x = expires, n = message }
local function chatStore()
    local g = ns.Database.Guild()
    if type(g.dungeonChat) ~= "table" then g.dungeonChat = {} end
    return g.dungeonChat
end

local function fire() ns.Debounce("dungeons-fire", 0.5, function() ns.Fire("LG_DUNGEONS") end) end

-- "123,456" -> { 123, 456 }
function Dungeons.ItemIds(text)
    local ids, seen = {}, {}
    for id in tostring(text or ""):gmatch("%d+") do
        id = tonumber(id)
        if id and id > 0 and not seen[id] and #ids < MAX_ITEMS then seen[id] = true; ids[#ids + 1] = id end
    end
    return ids
end

local function cutNote(text)
    text = tostring(text or ""):gsub("[%c|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #text > MAX_NOTE then
        text = text:sub(1, MAX_NOTE):gsub("[\192-\255][\128-\191]*$", "")
    end
    return text
end

-- A checked copy of an entry (nil when it is broken or expired)
local function validEntry(v, now)
    if type(v) ~= "table" then return nil end
    local r = type(v.r) == "string" and v.r:match("^[THD]$")
    local x, a = tonumber(v.x), tonumber(v.a)
    if not r or not x or x <= now or x > now + 61 * DAY then return nil end
    if not a or a > now + 600 then a = now end
    local off = {}
    for c in tostring(v.o or ""):gmatch("[THD]") do if c ~= r then off[c] = true end end
    local o = ""
    for _, c in ipairs(ROLES) do if off[c] then o = o .. c end end
    local note = cutNote(v.n)
    local ids = Dungeons.ItemIds(v.i)
    -- c: picked up from the owner's own guild chat message (short mark)
    return { r = r, o = o ~= "" and o or nil, n = note ~= "" and note or nil,
        i = #ids > 0 and table.concat(ids, ",") or nil, a = a, x = x, c = v.c and true or nil }
end

-- drops expired entries; true when something was removed
local function prune(rec, now)
    if type(rec) ~= "table" or type(rec.e) ~= "table" then return false end
    local removed = false
    for dk, v in pairs(rec.e) do
        if not Dungeons.BY_KEY[dk] or type(v) ~= "table" or (tonumber(v.x) or 0) <= now then rec.e[dk] = nil; removed = true end
    end
    return removed
end

local function cleanStore()
    local now, s, me = ns.Now(), store(), Names.Me()
    for key, rec in pairs(s) do
        if type(rec) ~= "table" then s[key] = nil
        else
            prune(rec, now)
            -- old empty records of others are not needed any more
            if not next(rec.e or {}) and not Names.Same(key, me) and (rec.t or 0) < now - 30 * DAY then s[key] = nil end
        end
    end
    local seen = chatStore()
    for key, list in pairs(seen) do
        if type(list) == "table" then
            for dk, c in pairs(list) do
                if type(c) ~= "table" or (tonumber(c.x) or 0) <= now then list[dk] = nil end
            end
        end
        if type(list) ~= "table" or not next(list) then seen[key] = nil end
    end
end

-- Takes a record from another member if it is newer than ours
local function accept(owner, t, e)
    if not owner or type(t) ~= "number" or type(e) ~= "table" then return false end
    local now = ns.Now()
    if t > now + 600 then return false end
    if Names.Same(owner, Names.Me()) then return false end
    -- only guild members (as soon as the roster is known)
    if next(ns.Guild.members) and not ns.Guild.IsMember(owner) then return false end
    local s = store()
    local old = s[owner]
    if old and (old.t or 0) >= t then return false end
    local entries = {}
    for dk, v in pairs(e) do
        if Dungeons.BY_KEY[dk] then entries[dk] = validEntry(v, now) end
    end
    s[owner] = { t = t, e = entries }
    fire()
    return true
end
Dungeons.Accept = accept

---------------------------------------------------------------------------
-- Own interest
---------------------------------------------------------------------------
local function mine(create)
    local me = Names.Me()
    if not me then return nil end
    local s = store()
    if not s[me] and create then s[me] = { t = 0, e = {} } end
    local rec = s[me]
    if rec and type(rec.e) ~= "table" then rec.e = {} end
    return rec
end

function Dungeons.MyEntry(dk)
    local rec = mine(false)
    local e = rec and rec.e[dk]
    if e and (tonumber(e.x) or 0) <= ns.Now() then return nil end
    return e
end

function Dungeons.Broadcast()
    if not IsInGuild() then return end
    local rec = mine(false)
    if not rec or (rec.t or 0) == 0 then return end
    prune(rec, ns.Now())
    Comm.Send("DI", { o = Names.Me(), t = rec.t, e = rec.e }, "GUILD", { priority = "normal" })
end

local function changed()
    local rec = mine(true)
    if not rec then return end
    rec.t = math.max(ns.Now(), (rec.t or 0) + 1)
    fire()
    ns.Debounce("dungeons-send", 3, Dungeons.Broadcast)
end
Dungeons.Changed = changed

-- main role from the talent tree with the most points
local SPEC_ROLE = {
    WARRIOR = { "D", "D", "T" }, PALADIN = { "H", "T", "D" }, DRUID = { "D", "T", "H" },
    PRIEST = { "H", "H", "D" }, SHAMAN = { "D", "D", "H" },
}
function Dungeons.GuessRole()
    local _, class = ns.Call(UnitClass, "player")
    local m = ns.Database.Member(Names.Me())
    local tree = ns.SpecTree(m and m.tp)
    local list = SPEC_ROLE[class or ""]
    if tree and list and list[tree] then return list[tree] end
    return Dungeons.ClassRoles(class)[1] or "D"
end

local function expiry() return ns.Now() + (settings().days or 14) * DAY end

-- creates the entry when needed; returns it. A short mark from guild chat
-- becomes a normal one (normal duration) as soon as you mark or edit it here.
function Dungeons.Mark(dk)
    if not Dungeons.BY_KEY[dk] then return nil end
    local rec = mine(true)
    if not rec then return nil end
    local e = rec.e[dk]
    if e and (tonumber(e.x) or 0) <= ns.Now() then e = nil end   -- expired, not pruned yet
    if not e then
        e = { r = Dungeons.GuessRole(), a = ns.Now(), x = expiry() }
        rec.e[dk] = e
        changed()
    elseif e.c then
        e.c = nil
        e.x = math.max(tonumber(e.x) or 0, expiry())
        changed()
    end
    return e
end

function Dungeons.Unmark(dk)
    local rec = mine(false)
    if rec and rec.e[dk] then rec.e[dk] = nil; changed() end
end

-- f(entry) changes the entry (it is created when missing)
function Dungeons.Edit(dk, f)
    local e = Dungeons.Mark(dk)
    if not e then return end
    ns.Safe(f, e)
    -- off spec never repeats the main role
    if e.o then
        local o = ""
        for _, c in ipairs(ROLES) do if c ~= e.r and e.o:find(c, 1, true) then o = o .. c end end
        e.o = o ~= "" and o or nil
    end
    changed()
end

function Dungeons.Renew(dk)
    Dungeons.Edit(dk, function(e) e.a = ns.Now(); e.x = expiry() end)
end

function Dungeons.RenewAll()
    local rec = mine(false)
    if not rec or not next(rec.e) then return end
    for _, e in pairs(rec.e) do e.a = ns.Now(); e.x = expiry() end
    changed()
end

function Dungeons.AddItem(dk, item)
    local id = ns.Items.ID(ns.Items.String(item) or item) or tonumber(item)
    if not id then return false end
    local ok = false
    Dungeons.Edit(dk, function(e)
        local ids = Dungeons.ItemIds(e.i)
        for _, x in ipairs(ids) do if x == id then return end end
        if #ids >= MAX_ITEMS then ns.Print(L.DG_ITEMS_FULL:format(MAX_ITEMS)); return end
        ids[#ids + 1] = id
        e.i = table.concat(ids, ",")
        ok = true
    end)
    return ok
end

function Dungeons.RemoveItem(dk, id)
    Dungeons.Edit(dk, function(e)
        local keep = {}
        for _, x in ipairs(Dungeons.ItemIds(e.i)) do if x ~= id then keep[#keep + 1] = x end end
        e.i = #keep > 0 and table.concat(keep, ",") or nil
    end)
end

-- Items the addon can find by name. WoW has no item search by name, so this
-- is what is known anyway: items seen this session, the guild's gear, the loot
-- history, your bags and everyone's wanted items.
local function knownItemIds()
    local ids = {}
    local function add(x)
        local id = ns.Items.ID(ns.Items.String(x) or x) or tonumber(x)
        if id then ids[id] = true end
    end
    for id in pairs(ns.Items.names) do ids[id] = true end
    local g = ns.Database.Guild()
    for _, m in pairs(g.members or {}) do
        if type(m) == "table" and type(m.g) == "table" then for _, s in pairs(m.g) do add(s) end end
    end
    for _, r in ipairs(g.lootHistory or {}) do if type(r) == "table" then add(r.i) end end
    local numSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    local getLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
    if numSlots and getLink then
        for bag = 0, 4 do
            for slot = 1, (ns.Call(numSlots, bag) or 0) do add(ns.Call(getLink, bag, slot)) end
        end
    end
    for _, rec in pairs(store()) do
        for _, e in pairs(type(rec) == "table" and type(rec.e) == "table" and rec.e or {}) do
            for _, id in ipairs(Dungeons.ItemIds(type(e) == "table" and e.i)) do ids[id] = true end
        end
    end
    return ids
end

-- item ids for what was typed: an id, a link or (part of) a name.
-- Second result true: a number that is no item.
function Dungeons.FindItems(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return {} end
    local id = tonumber(text) or ns.Items.ID(ns.Items.String(text))
    if id then
        local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        if instant and not ns.Call(instant, id) then return {}, true end
        return { id }
    end
    local q = ns.PlainText(text):lower():gsub("^%[", ""):gsub("%]$", "")
    local exact, partial, names = {}, {}, {}
    -- the client knows an exact name directly when the item is in its cache
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local _, link = ns.Call(getInfo, text)
    local direct = link and ns.Items.ID(ns.Items.String(link))
    if direct then exact[1] = direct end
    for kid in pairs(knownItemIds()) do
        if kid ~= direct then
            local info = ns.Items.Info(kid)
            local name = info and info.name
            if name then
                names[kid] = name
                local n = name:lower()
                if n == q then exact[#exact + 1] = kid
                elseif #q >= 3 and n:find(q, 1, true) then partial[#partial + 1] = kid end
            end
        end
    end
    if #exact > 0 then return exact end
    table.sort(partial, function(a, b) return names[a] < names[b] end)
    return partial
end

-- a wanted item that landed in your bags (or is worn) is taken off the list
local function haveItem(id)
    local count = (C_Item and C_Item.GetItemCount) or GetItemCount
    local n = count and ns.Call(count, id, true)
    if ns.Num(n) and n > 0 then return true end
    return IsEquippedItem and ns.Call(IsEquippedItem, id) == true or false
end

function Dungeons.CheckWishes()
    local rec = mine(false)
    if not rec then return end
    local got = {}
    for dk, e in pairs(rec.e) do
        local keep = {}
        for _, id in ipairs(Dungeons.ItemIds(e.i)) do
            if haveItem(id) then got[#got + 1] = { dk = dk, id = id } else keep[#keep + 1] = id end
        end
        if #keep ~= #Dungeons.ItemIds(e.i) then e.i = #keep > 0 and table.concat(keep, ",") or nil end
    end
    if #got == 0 then return end
    for _, g in ipairs(got) do
        ns.Print(L.DG_GOT_ITEM:format(ns.Items.Link(g.id), Dungeons.BY_KEY[g.dk].name))
    end
    changed()
end

---------------------------------------------------------------------------
-- Guild chat: "LFG Strat UD", "wer kommt mit scholo?", "LF1M heal BRD" …
-- Every client reads the guild chat itself, so players without the addon show
-- up as well – stored only locally for a short time, nothing is sent. Your own
-- message also makes a short real mark (synced), so members who log in later
-- see it too. A normal mark of yours is never touched.
---------------------------------------------------------------------------
Dungeons.CHAT_HOURS = 2

-- per dungeon: what players write. Lower case; punctuation counts as a space
-- ("Zul'Farrak" is matched as "zul farrak"). Whole words only.
local ALIASES = {
    rfc = { "rfc", "ragefire", "ragefire chasm", "flammenschlund" },
    thanes = { "thanes", "hall of thanes", "halls of thanes" },
    lordaeron = { "lordaeron", "ruins of lordaeron", "lorda" },
    wc = { "wc", "wailing caverns", "hdw", "höhlen des wehklagens", "wehklagen" },
    vc = { "deadmines", "dead mines", "todesminen" },   -- not "vc": that is voice chat
    sfk = { "sfk", "shadowfang", "shadowfang keep", "burg schattenfang", "schattenfang", "bsf" },
    bfd = { "bfd", "blackfathom", "blackfathom deeps", "tiefschwarze grotte", "tsg" },
    stocks = { "stocks", "stockade", "verlies" },
    excavation = { "excavation", "excavation site", "ausgrabung", "ausgrabungsstätte" },
    smgy = { "sm gy", "smgy", "sm graveyard", "graveyard", "sm friedhof", "friedhof" },
    dalaran = { "dalaran", "city of dalaran" },
    gnomer = { "gnomer", "gnomeregan" },
    rfk = { "rfk", "razorfen kraul", "kral" },
    smlib = { "sm lib", "smlib", "sm library", "library", "sm bib", "bibliothek" },
    smarm = { "sm arm", "smarm", "sm armory", "armory", "sm wk", "waffenkammer" },
    drowned = { "drowned", "drowned city" },
    smcath = { "sm cath", "smcath", "sm kath", "cathedral", "kathedrale", "cath", "kath" },
    rfd = { "rfd", "razorfen downs", "hügel von razorfen" },
    kroldok = { "kroldok", "krol dok", "kroldok stronghold" },
    ulda = { "ulda", "uldaman" },
    zf = { "zf", "zul farrak", "zulfarrak" },
    mara = { "mara", "maraudon" },
    alcaz = { "alcaz", "alcaz prison" },
    st = { "st", "sunken temple", "versunkener tempel", "atal hakkar" },
    brd = { "brd", "blackrock depths", "schwarzfelstiefen" },
    blackmaw = { "blackmaw", "blackmaw hold" },
    lbrs = { "lbrs", "lower blackrock", "lower blackrock spire", "untere schwarzfelsspitze" },
    dme = { "dm e", "dme", "dm east", "dm ost", "dire maul east", "düsterbruch ost", "db ost" },
    dmw = { "dm w", "dmw", "dm west", "dire maul west", "düsterbruch west", "db west" },
    dmn = { "dm n", "dmn", "dm north", "dm nord", "dire maul north", "düsterbruch nord", "db nord", "tribute run", "tribut" },
    ubrs = { "ubrs", "upper blackrock", "upper blackrock spire", "obere schwarzfelsspitze" },
    shaper = { "shaper", "shapers terrace", "shaper s terrace" },
    stratl = { "strat live", "stratlive", "strat l", "live strat", "strat lebend",
        "strath live", "strathlive", "strath l", "live strath", "strath lebend" },
    stratud = { "strat ud", "stratud", "strat undead", "ud strat", "strat tot", "strat untot", "baron run",
        "strath ud", "strathud", "strath undead", "ud strath", "strath tot", "strath untot" },
    scholo = { "scholo", "scholomance" },
}
-- names for several dungeons, only used when no single one was named:
-- keys = all of them count, pick = the one that suits the player's level
local GROUP_ALIASES = {
    { words = { "strat", "strath", "stratholme" }, keys = { "stratl", "stratud" } },
    { words = { "sm", "kloster", "scarlet monastery", "scharlachrotes kloster" }, pick = { "smgy", "smlib", "smarm", "smcath" } },
    { words = { "dire maul", "düsterbruch" }, pick = { "dme", "dmw", "dmn" } },
    { words = { "brs", "blackrock spire", "schwarzfelsspitze" }, keys = { "lbrs", "ubrs" } },
}
-- the message has to ask for a group …
local INTENT = { "lfg", "lfm", "lf", "looking for", "suche", "suchen", "sucht", "such", "wer kommt", "wer will", "wer hat lust",
    "wer mag", "wer ist dabei", "wer noch", "jemand", "anyone", "someone", "need", "brauche", "brauchen", "mitkommen",
    "mit nach", "lust auf", "gruppe für", "group for", "noch platz" }
-- … and must not be about trading
local SKIP = { "wts", "wtb", "verkaufe", "kaufe", "verkauf", "ankauf" }

local function normalize(text)
    text = ns.PlainText(text):lower():gsub("[%p]", " "):gsub("%s+", " ")
    return " " .. text .. " "
end

local function bestFit(keys, level)
    if not level then return keys[1] end
    local best, dist
    for _, k in ipairs(keys) do
        local d = Dungeons.BY_KEY[k]
        local x = math.abs((d.min + d.max) / 2 - level)
        if not dist or x < dist then best, dist = k, x end
    end
    return best
end

-- dungeon keys a guild chat message asks for (nil: none / not a group search)
function Dungeons.ParseChat(text, level)
    if type(text) ~= "string" or text:find("^%s*[!%[]") then return nil end   -- commands, "[LG] …" answers
    local s = normalize(text)
    for _, w in ipairs(SKIP) do if s:find(" " .. w .. " ", 1, true) then return nil end end
    local intent = false
    for tok in s:gmatch("%S+") do
        if tok:match("^lf%d?[mg]?$") then intent = true; break end
    end
    if not intent then
        for _, w in ipairs(INTENT) do if s:find(" " .. w .. " ", 1, true) then intent = true; break end end
    end
    -- short questions like "strat ud?" or "jemand scholo?"
    if not intent and text:find("?", 1, true) and #s <= 42 then intent = true end
    if not intent then return nil end
    local found, seen = {}, {}
    local function add(k) if k and not seen[k] then seen[k] = true; found[#found + 1] = k end end
    for _, d in ipairs(Dungeons.LIST) do
        for _, a in ipairs(ALIASES[d.key] or {}) do
            if s:find(" " .. a .. " ", 1, true) then add(d.key); break end
        end
    end
    for _, g in ipairs(GROUP_ALIASES) do
        local list, named = g.keys or g.pick, false
        for _, k in ipairs(list) do if seen[k] then named = true end end
        if not named then
            for _, w in ipairs(g.words) do
                if s:find(" " .. w .. " ", 1, true) then
                    if g.keys then for _, k in ipairs(g.keys) do add(k) end else add(bestFit(g.pick, level)) end
                    break
                end
            end
        end
    end
    return #found > 0 and found or nil
end

local function chatOn()
    return settings().chat ~= false and ns.Database.Settings().modules.dungeons ~= false
end

function Dungeons.HeardChat(text, sender)
    if not chatOn() then return end
    local key = Names.Key(sender)
    if not key then return end
    local isMe = Names.Same(key, Names.Me())
    local g = ns.Guild.Find(key)
    local level = (g and g.level) or (isMe and ns.Call(UnitLevel, "player")) or nil
    local keys
    -- "!lfg scholo": whoever asks who wants to go is looking for a group as well
    local asked = text:match("^%s*!lfg%s+(.-)%s*$")
    if asked then
        local pick
        keys, pick = Dungeons.ChatQuery(asked)
        if keys and pick then keys = { bestFit(keys, level) } end
    else
        keys = Dungeons.ParseChat(text, level)
    end
    if not keys then return end
    local now = ns.Now()
    local x = now + Dungeons.CHAT_HOURS * 3600
    local note = cutNote(ns.PlainText(text))
    note = note ~= "" and note or nil
    if isMe then
        -- own message: a short real mark that is synced; a normal mark stays as it is
        local rec = mine(true)
        if not rec then return end
        local any = false
        for _, dk in ipairs(keys) do
            local e = rec.e[dk]
            if not e or (tonumber(e.x) or 0) <= now then
                rec.e[dk] = { r = Dungeons.GuessRole(), a = now, x = x, c = true, n = note }
                any = true
            elseif e.c then
                e.a, e.x, e.n = now, x, note
                any = true
            end
        end
        if any then changed() end
    else
        local seen = chatStore()
        seen[key] = seen[key] or {}
        for _, dk in ipairs(keys) do seen[key][dk] = { a = now, x = x, n = note } end
        fire()
    end
end

ns.On("CHAT_MSG_GUILD", function(_, text, sender)
    if ns.IsSecret(text) or ns.IsSecret(sender) or type(text) ~= "string" or type(sender) ~= "string" then return end
    Dungeons.HeardChat(text, sender)
end)

-- /lg test lfgchat [text]: what the addon reads from a message (nothing stored)
local CHAT_SAMPLES = { "LFG Strat UD", "wer kommt mit scholo?", "LF1M heal BRD", "suche gruppe für sm cath", "LFM Zul'Farrak need tank",
    "jemand DM Nord tribute?", "wts [Righteous Orb] 5g", "bin kurz afk", "strat?", "LFM strath", "LFG Hall of Thanes" }
function Dungeons.TestChat(text)
    local list = (text and text:find("%S")) and { text } or CHAT_SAMPLES
    local level = ns.Call(UnitLevel, "player")
    ns.Print(L.TEST_TAG .. " " .. L.DG_CHAT_TEST:format(Dungeons.CHAT_HOURS))
    for _, t in ipairs(list) do
        local keys = Dungeons.ParseChat(t, level)
        local names = {}
        for _, k in ipairs(keys or {}) do names[#names + 1] = Dungeons.BY_KEY[k].name end
        print(("  %s  →  %s"):format(Theme.HexColor("text", t),
            #names > 0 and Theme.HexColor("good", table.concat(names, ", ")) or Theme.HexColor("muted", L.DG_CHAT_NONE)))
    end
end

---------------------------------------------------------------------------
-- "!lfg <dungeon>" in guild chat (or as a whisper): exactly one addon user
-- answers who wants to run it; "!lfg" alone lists the dungeons with the most
-- interest. Own election (message kind "DE"), the same way as the crafting
-- answers: every client draws a claim, the lowest one answers.
-- A client whose chat lines the game blocks (ADDON_ACTION_BLOCKED) stays out
-- for a few days, and the asker's own addon shows the answer locally when no
-- answer showed up in guild chat.
---------------------------------------------------------------------------
local QUERY_FILLER = { lfg = true, lfm = true, lf = true, dungeon = true, dungeons = true, run = true, who = true, wer = true }

-- dungeon keys when the whole question names a dungeon ("ubrs", "strat ud",
-- "Scholomance", "lfg brd"); nil otherwise, so crafting questions stay crafting
function Dungeons.ChatQuery(text)
    if type(text) ~= "string" or ns.Database.Settings().modules.dungeons == false then return nil end
    local words = {}
    for w in normalize(text):gmatch("%S+") do if not QUERY_FILLER[w] then words[#words + 1] = w end end
    local q = table.concat(words, " ")
    if q == "" then return nil end
    for _, d in ipairs(Dungeons.LIST) do
        if q == d.key or q == normalize(d.short):match("^%s*(.-)%s*$") or q == normalize(d.name):match("^%s*(.-)%s*$") then return { d.key } end
        for _, a in ipairs(ALIASES[d.key] or {}) do if q == a then return { d.key } end end
    end
    for _, g in ipairs(GROUP_ALIASES) do
        for _, w in ipairs(g.words) do
            -- second result: a "pick" group (one of them is meant, e.g. "sm")
            if q == w then return g.keys or g.pick, g.pick ~= nil end
        end
    end
    return nil
end

local CHAT_MAX = 240   -- "[LG] " is added in front; guild chat takes 255
local function answerFor(dk, maxNames)
    local d = Dungeons.BY_KEY[dk]
    local rows = Dungeons.Interested(dk, false, true)
    if #rows == 0 then return L.DG_ANSWER_NONE:format(d.name) end
    table.sort(rows, function(a, b)
        if a.online ~= b.online then return a.online end
        return (a.e.a or 0) > (b.e.a or 0)
    end)
    local parts = {}
    for i, r in ipairs(rows) do
        if i > maxNames then parts[#parts + 1] = L.CRAFT_MORE:format(#rows - maxNames); break end
        local info = {}
        info[#info + 1] = r.e.r and roleName(r.e.r) or L.DG_ANSWER_CHAT
        if r.online then info[#info + 1] = "online" end
        parts[#parts + 1] = ("%s (%s)"):format(Names.Display(r.name), table.concat(info, ", "))
    end
    return L.DG_ANSWER:format(d.name, #rows, table.concat(parts, ", "))
end

-- the chat answer for a dungeon question (nil: not a dungeon question)
function Dungeons.ChatAnswer(text)
    local keys = Dungeons.ChatQuery(text)
    if not keys then return nil end
    -- one dungeon: up to 6 names; several (e.g. "strat"): fewer each
    for maxNames = (#keys == 1 and 6 or 3), 0, -1 do
        local parts = {}
        for _, dk in ipairs(keys) do parts[#parts + 1] = answerFor(dk, maxNames) end
        local text2 = table.concat(parts, " / ")
        if #text2 <= CHAT_MAX or maxNames == 0 then return text2:sub(1, CHAT_MAX) end
    end
end

-- "!lfg" alone: the dungeons with the most interest
function Dungeons.TopAnswer()
    local counts = Dungeons.Counts(true)
    local list = {}
    for _, d in ipairs(Dungeons.LIST) do
        local c = counts[d.key]
        if c and c.total > 0 then list[#list + 1] = { d = d, c = c } end
    end
    if #list == 0 then return L.DG_TOP_NONE end
    table.sort(list, function(a, b)
        if a.c.total ~= b.c.total then return a.c.total > b.c.total end
        if a.c.online ~= b.c.online then return a.c.online > b.c.online end
        return a.d.order < b.d.order
    end)
    local parts = {}
    for i, x in ipairs(list) do
        if i > 6 then parts[#parts + 1] = L.CRAFT_MORE:format(#list - 6); break end
        parts[#parts + 1] = ("%s %d%s"):format(x.d.short, x.c.total, x.c.online > 0 and (" (" .. x.c.online .. " online)") or "")
    end
    return (L.DG_TOP:format(table.concat(parts, ", "))):sub(1, CHAT_MAX)
end

-- the answer to "!lfg <text>" ("" = the top list)
local function replyFor(q)
    if q == "" then return Dungeons.TopAnswer() end
    return Dungeons.ChatAnswer(q) or L.DG_ASK_UNKNOWN:format(q:sub(1, 40))
end

-- "!lfg", "!lfg scholo" -> "" / "scholo"; nil when it is no !lfg question
local function parseAsk(text)
    if text:match("^%s*!lfg%s*$") then return "" end
    return text:match("^%s*!lfg%s+(.-)%s*$")
end

Dungeons.debug = false
local function dbg(fmt, ...)
    if Dungeons.debug then ns.Print("|cff88ccff[!lfg debug]|r " .. fmt, ...) end
end
function Dungeons.ToggleDebug()
    Dungeons.debug = not Dungeons.debug
    ns.Print("!lfg debug: %s", Dungeons.debug and "ON – ask something with !lfg in guild chat" or "off")
end

local function answersOn() return settings().answer ~= false and ns.Database.Settings().modules.dungeons ~= false end

-- Delivery like "!lg" since 1.0.80 (CraftQuery.Deliver): an asker with the addon
-- gets the answer through the addon channel – every addon user sees it in the
-- chat window (guild colour, "[Post]" link, /lg post) and no automatic chat line
-- is needed; players without the addon get a guild chat line.
local function deliver(text, asked, asker)
    local Craft = ns.CraftQuery
    dbg("answering: %s", text)
    if Craft and Craft.Deliver then Craft.Deliver(text, asked, asker)
    else ns.SendChatAuto("lfg-answer-GUILD", "[LG] " .. text, "GUILD") end
end

-- the election
local ASK_REPEAT = 30
local BACKUP_WAIT = 5     -- no answer this long after a question: one more round
local askRecent, askPending, askClaims = {}, {}, {}
local lastAnswer = -1     -- GetTime() of the last answer seen (guild chat line or addon answer)

local function elect(key, q, asked, asker)
    if askPending[key] then return end
    -- the game blocked a line of this client lately: the others answer
    if ns.blockedAt and GetTime() - ns.blockedAt < 120 then dbg("not taking part: the game blocked this client lately"); return end
    local token = math.random(1, 100000)
    if ns.ChatBlocked and ns.ChatBlocked() then token = token + 1000000 end
    -- sent automatic lines lately: the game may block the next one – another client first
    local sent = ns.AutoSentSince and ns.AutoSentSince(60) or 0
    if sent > 0 then token = token + math.min(sent, 3) * 300000 end
    local delay = 0.05 + (token % 100000) / 100000 * 0.5 + math.floor(token / 1000000) * 0.15
    dbg("question \"%s\" – my claim %d in %.2f s", key, token, delay)
    local p = { token = token }
    askPending[key] = p
    p.timer = C_Timer.NewTimer(delay, function()
        if askPending[key] ~= p then return end
        if askClaims[key] and askClaims[key] < p.token then askPending[key] = nil; dbg("lost: claim %d is lower", askClaims[key]); return end
        Comm.Send("DE", { q = key, n = p.token }, "GUILD", { priority = "alert" })
        C_Timer.After(1.2, function()
            if askPending[key] ~= p then return end
            askPending[key] = nil
            if askClaims[key] and askClaims[key] < p.token then dbg("lost after claiming"); return end
            askRecent[key] = GetTime()
            deliver(replyFor(q), asked, asker)
        end)
    end)
end

local function onAsk(text, sender)
    local q = parseAsk(text)
    if not q then return end
    if not answersOn() then dbg("answers are switched off here"); return end
    local key = normalize(q):match("^%s*(.-)%s*$")
    if key == "" then key = "*" end
    if askRecent[key] and GetTime() - askRecent[key] < ASK_REPEAT then
        dbg("not again: \"%s\" was answered %d s ago", key, GetTime() - askRecent[key]); return
    end
    if askPending[key] then return end
    local asked, asker = GetTime(), Names.Key(sender)
    elect(key, q, asked, asker)
    -- the winner did not answer (the game blocked it, combat, offline): one more round without it
    C_Timer.After(BACKUP_WAIT, function()
        if lastAnswer >= asked then return end
        dbg("no answer after %d s – second round", BACKUP_WAIT)
        elect(key .. "#2", q, asked, asker)
    end)
end

-- every answer shown in the chat window (addon answers of !lg and !lfg) counts as answered
ns.On("LG_READY", function()
    local Craft = ns.CraftQuery
    if Craft and Craft.ShowAnswer and hooksecurefunc then
        hooksecurefunc(Craft, "ShowAnswer", function() lastAnswer = GetTime() end)
    end
end)

Comm.Register("DE", function(data, sender)
    if type(data.q) ~= "string" or type(data.n) ~= "number" then return end
    dbg("claim %d for \"%s\" from %s", data.n, data.q, tostring(sender))
    if not askClaims[data.q] or data.n < askClaims[data.q] then askClaims[data.q] = data.n end
    askRecent[data.q] = GetTime()
    local p = askPending[data.q]
    if p and data.n < p.token then
        if p.timer then p.timer:Cancel() end
        askPending[data.q] = nil
    end
    C_Timer.After(ASK_REPEAT, function() askClaims[data.q] = nil end)
end)

ns.On("CHAT_MSG_GUILD", function(_, text, sender)
    if ns.IsSecret(text) or ns.IsSecret(sender) or type(text) ~= "string" or type(sender) ~= "string" then return end
    if text:find("^%[LG%] ") then lastAnswer = GetTime(); return end
    onAsk(text, sender)
end)

-- whispered "!lfg …": an addon user gets an addon whisper (no chat line), others a whisper
ns.On("CHAT_MSG_WHISPER", function(_, text, sender)
    if ns.IsSecret(text) or ns.IsSecret(sender) or type(text) ~= "string" or type(sender) ~= "string" then return end
    local q = parseAsk(text)
    if not q or not answersOn() then return end
    local answer, key, Craft = replyFor(q), Names.Key(sender), ns.CraftQuery
    if key and Craft and Craft.HasAddonAnswers and Craft.HasAddonAnswers(key) and not Names.Same(key, Names.Me()) then
        Comm.Send("QA", { t = answer }, "WHISPER", { target = sender, priority = "alert" })
        return
    end
    ns.SendChatAuto("lfg-answer-" .. sender, "[LG] " .. answer, "WHISPER", sender)
end)

-- /lg test lfgask [dungeon]: the "!lfg" answer, only for you, and whether this client would answer
function Dungeons.TestAsk(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    ns.Print(L.TEST_TAG .. " [LG] " .. replyFor(text))
    local yes, no = Theme.HexColor("good", L.YES), Theme.HexColor("bad", L.NO)
    local blocked, why = false, nil
    if ns.ChatBlocked then blocked, why = ns.ChatBlocked() end
    print("  " .. L.DG_ASK_STATUS:format(answersOn() and yes or no, blocked and (no .. " (" .. tostring(why or "") .. ")") or yes))
end

---------------------------------------------------------------------------
-- Reading: who wants a dungeon
---------------------------------------------------------------------------
local testRecords, testUntil = nil, 0

local function memberInfo(key)
    local g = ns.Guild.Find(key)
    local m = ns.Database.Member(key) or {}
    return g, m
end

-- rows for one dungeon: { key, name, class, level, online, me, test, e, ids }
-- noTest: without the made-up members of /lg test lfg (chat answers)
function Dungeons.Interested(dk, onlyOnline, noTest)
    local rows, now = {}, ns.Now()
    local rosterKnown = next(ns.Guild.members) ~= nil
    local me = Names.Me()
    local function add(key, rec, test)
        local e = rec and rec.e and rec.e[dk]
        if type(e) ~= "table" or (tonumber(e.x) or 0) <= now then return end
        local g, m = memberInfo(key)
        local isMe = Names.Same(key, me)
        if not test and not isMe and rosterKnown and not g then return end   -- left the guild
        local online = test and rec.online or isMe or (g and g.online) or false
        if onlyOnline and not online then return end
        rows[#rows + 1] = {
            key = key, name = (g and g.name) or rec.name or Names.Display(key), class = (g and g.class) or m.c or rec.class,
            level = (g and g.level) or m.l or rec.level, online = online, me = isMe, test = test,
            e = e, ids = Dungeons.ItemIds(e.i), spec = ns.SpecPoints(m),
        }
    end
    for key, rec in pairs(store()) do add(key, rec, false) end
    if testRecords and GetTime() < testUntil and not noTest then
        for key, rec in pairs(testRecords) do add(key, rec, true) end
    end
    -- seen in guild chat (local, no role): only when the player has no mark of their own for it
    local have = {}
    for _, r in ipairs(rows) do have[r.key] = true end
    for key, list in pairs(chatStore()) do
        local c = type(list) == "table" and list[dk]
        if type(c) == "table" and (tonumber(c.x) or 0) > now and not have[key] then
            local g, m = memberInfo(key)
            local online = (g and g.online) or false
            if (g or not rosterKnown) and (online or not onlyOnline) then
                rows[#rows + 1] = {
                    key = key, name = (g and g.name) or Names.Display(key), class = (g and g.class) or m.c,
                    level = (g and g.level) or m.l, online = online, chat = true,
                    e = { n = c.n, a = c.a, x = c.x, c = true }, ids = {}, spec = ns.SpecPoints(m),
                }
            end
        end
    end
    -- items wanted by more than one player
    local wanted = {}
    for _, r in ipairs(rows) do
        for _, id in ipairs(r.ids) do
            wanted[id] = wanted[id] or {}
            table.insert(wanted[id], r)
        end
    end
    for _, r in ipairs(rows) do
        r.clash = {}
        for _, id in ipairs(r.ids) do
            if #wanted[id] > 1 then
                local others = {}
                for _, o in ipairs(wanted[id]) do if o ~= r then others[#others + 1] = o end end
                r.clash[id] = others
            end
        end
    end
    return rows
end

-- per dungeon: total, online, main roles (real: without test members)
function Dungeons.Counts(real)
    local out = {}
    for _, d in ipairs(Dungeons.LIST) do
        local c = { total = 0, online = 0, T = 0, H = 0, D = 0, names = {} }
        for _, r in ipairs(Dungeons.Interested(d.key, false, real)) do
            c.total = c.total + 1
            if r.online then c.online = c.online + 1 end
            if r.e.r then c[r.e.r] = (c[r.e.r] or 0) + 1 end
            c.names[#c.names + 1] = Names.Display(r.name)
        end
        out[d.key] = c
    end
    return out
end

---------------------------------------------------------------------------
-- Sync
---------------------------------------------------------------------------
local function sendRecord(key, rec, channel, target)
    Comm.Send("DI", { o = key, t = rec.t, e = rec.e }, channel, { target = target, priority = "bulk" })
end

Comm.Register("DI", function(data, sender, channel)
    local d = ns.Clean(data, 3)
    if type(d) ~= "table" then return end
    local owner = Names.Key(d.o)
    if channel == "WHISPER" then
        -- sync answer: only while we wait for it, only from the member who answers
        if not Comm.Expected("dungeons", sender) then return end
    elseif channel == "GUILD" then
        -- live change: only the owner speaks for themselves (stored under the sender's own key)
        if not owner or not Names.Same(owner, sender) then return end
        owner = sender
    else
        return
    end
    accept(owner, tonumber(d.t), d.e)
end)

Comm.Register("DQ", function(_, sender, _, raw)
    if not IsInGuild() then return end
    if next(ns.Guild.members) and not ns.Guild.IsMember(sender) then return end
    Comm.ReplyOnce("dungeons:" .. sender, 2, 10, function()
        Comm.Send("DA", { to = sender }, "GUILD", { priority = "alert" })
        cleanStore()
        local now, n = ns.Now(), 0
        for key, rec in pairs(store()) do
            -- empty records too (recent ones), so removals reach the asker
            if type(rec) == "table" and (rec.t or 0) > 0 and (next(rec.e or {}) or (rec.t or 0) > now - 30 * DAY)
                and not Names.Same(key, sender) then
                n = n + 1
                if n > 200 then break end
                sendRecord(key, rec, "WHISPER", raw)
            end
        end
    end)
end)

Comm.Register("DA", function(data)
    local to = type(data.to) == "string" and Names.Key(data.to)
    if to then Comm.Answered("dungeons:" .. to) end
end)

function Dungeons:OnLogin()
    ns.After(5, cleanStore)
    -- own interest to everyone online, then ask for what we missed
    ns.After(25, function()
        local rec = mine(false)
        if rec and next(rec.e) then Dungeons.Broadcast() end
    end)
    ns.After(45, function()
        if not IsInGuild() then return end
        Comm.Expect("dungeons", 120)
        Comm.Send("DQ", {}, "GUILD", { priority = "bulk" })
    end)
    ns.After(20, Dungeons.CheckWishes)
end

ns.On("BAG_UPDATE_DELAYED", function() ns.Debounce("dungeons-wishes", 10, Dungeons.CheckWishes) end)
ns.On("PLAYER_EQUIPMENT_CHANGED", function() ns.Debounce("dungeons-wishes", 10, Dungeons.CheckWishes) end)

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
function Dungeons.Whisper(row, dk)
    if row.test then ns.Print(L.DG_TEST_ROW); return end
    if not ChatFrame_SendTell then return end
    ChatFrame_SendTell(row.name)
    local d = dk and Dungeons.BY_KEY[dk]
    if d and ChatEdit_GetActiveWindow then
        local box = ChatEdit_GetActiveWindow()
        if box and box.Insert then box:Insert(L.DG_WHISPER_TEXT:format(d.name)) end
    end
end

function Dungeons.Invite(row)
    if row.test then ns.Print(L.DG_TEST_ROW); return end
    local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    if invite then ns.Call(invite, row.name) end
end

---------------------------------------------------------------------------
-- Test: made-up members (only for you, nothing is sent or stored)
---------------------------------------------------------------------------
function Dungeons.Test()
    local now = ns.Now()
    local function e(r, o, items, note, age)
        return { r = r, o = o, i = items, n = note, a = now - (age or 0), x = now + 10 * DAY }
    end
    testRecords = {
        ["test thorgar"] = { name = "Thorgar", class = "WARRIOR", level = 60, online = true,
            e = { stratud = e("T", "D", "13335", nil, 2 * DAY), scholo = e("T", nil, nil, "only full clears", DAY) } },
        ["test lysanne"] = { name = "Lysanne", class = "PRIEST", level = 60, online = true,
            e = { stratud = e("H", "D", "13335,13505", nil, 3 * 3600), brd = e("H", nil, "11815") } },
        ["test kaelin"] = { name = "Kaelin", class = "MAGE", level = 59, online = false,
            e = { stratud = e("D", nil, nil, "need the Baron quest", 5 * DAY), scholo = e("D", nil, "13937") } },
        ["test mirabel"] = { name = "Mirabel", class = "DRUID", level = 58, online = false,
            e = { brd = e("D", "TH", "11815", nil, 6 * 3600), ubrs = e("H", "D", "13965") } },
        -- seen in guild chat: no role, short time
        ["test borin"] = { name = "Borin", class = "HUNTER", level = 60, online = true,
            e = { stratud = { c = true, n = "LF2M Strat UD, need heal + dps", a = now - 900, x = now + Dungeons.CHAT_HOURS * 3600 - 900 } } },
    }
    testUntil = GetTime() + 180
    ns.After(181, function() if GetTime() >= testUntil then testRecords = nil; fire() end end)
    ns.Print(L.TEST_TAG .. " " .. L.DG_TEST_START)
    ns.Window.Show("dungeons")
    if Dungeons.Select then Dungeons.Select("stratud", "find") end
    fire()
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local state = { tab = "find", dungeon = nil, mine = nil, online = false, fits = false }
Dungeons.state = state

local function myLevel() return ns.Call(UnitLevel, "player") or 60 end
local function fits(d, level) return level >= d.min - 2 and level <= d.max + 2 end
local function levelText(d) return ("%d–%d"):format(d.min, d.max) end
-- small tag behind the name of the new Forever dungeons
local function foreverTag(d) return d.forever and ("  " .. Theme.HexColor("bronze", L.DG_FOREVER)) or "" end

local function roleGlyph(r, size, dim)
    return UI.Glyph(ROLE_ICON[r] or "dot", dim and "muted" or ROLE_COLOR[r], size or 12)
end

local function rolesText(e)
    -- only seen in guild chat: the role is not known
    if not e.r then return UI.Glyph("message-circle", "muted", 12) .. " " .. Theme.HexColor("muted", L.DG_ROLE_UNKNOWN) end
    local out = roleGlyph(e.r, 12) .. " " .. Theme.HexColor("text", roleName(e.r))
    if e.o then
        local off = {}
        for c in e.o:gmatch("[THD]") do off[#off + 1] = roleGlyph(c, 11, true) end
        out = out .. "  " .. Theme.HexColor("muted", "/ ") .. table.concat(off, " ")
    end
    return out
end

local function itemIcons(r, size)
    local parts = {}
    for _, id in ipairs(r.ids) do
        local icon = ns.Items.Icon(id)
        parts[#parts + 1] = ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(tostring(icon), size or 16, size or 16)
        if r.clash and r.clash[id] then parts[#parts] = parts[#parts] .. UI.Glyph("dot", "warn", 9) end
    end
    return table.concat(parts, " ")
end

local function expiresText(e)
    local left = (tonumber(e.x) or 0) - ns.Now()
    if left <= 0 then return Theme.HexColor("muted", "–") end
    local days = math.floor(left / DAY)
    local role = days < 2 and "warn" or "textDim"
    if days >= 1 then return Theme.HexColor(role, L.DG_IN_DAYS:format(days)) end
    return Theme.HexColor("warn", L.DG_IN_HOURS:format(math.max(1, math.floor(left / 3600))))
end

UI.AddPage("dungeons", L.PAGE_DUNGEONS, 22, function(content, page)
    local tabs, tabSearch = {}, {}
    local bar = UI.SubTabs(content, { { key = "find", title = L.DG_TAB_FIND }, { key = "mine", title = L.DG_TAB_MINE } },
        function(key)
            state.tab = key
            for k, f in pairs(tabs) do f:SetShown(k == key) end
            if tabs[key] and tabs[key].Refresh then tabs[key].Refresh() end
        end)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("RIGHT", content, "RIGHT", -ns.Window.SearchReserve(), 0)
    local holder = CreateFrame("Frame", nil, content)
    holder:SetPoint("TOPLEFT", 0, -40)
    holder:SetPoint("BOTTOMRIGHT")

    -------------------------------------------------------------------
    -- Tab "Who wants to go": dungeons on the left, players on the right
    -------------------------------------------------------------------
    local find = CreateFrame("Frame", nil, holder)
    find:SetAllPoints()
    tabs.find = find
    local counts = {}

    local onlineCheck = UI.Check(find, L.ONLY_ONLINE, function() return state.online end,
        function(v) state.online = v; find.Refresh() end, L.DG_ONLINE_TIP)
    onlineCheck:SetPoint("TOPLEFT", 0, 0)
    local fitsCheck = UI.Check(find, L.DG_FITS, function() return state.fits end,
        function(v) state.fits = v; find.Refresh() end, L.DG_FITS_TIP)
    fitsCheck:SetPoint("LEFT", onlineCheck, "RIGHT", 18, 0)

    local LEFT_W = 330
    local dList = UI.List(find, {
        rowHeight = 26, sortKey = "order",
        columns = {
            { key = "order", title = L.DG_COL_DUNGEON, flex = 1, minWidth = 120,
              text = function(r)
                  local c = counts[r.d.key]
                  return Theme.HexColor((c and c.total > 0) and "text" or "textDim", r.d.name) .. foreverTag(r.d)
              end,
              sort = function(r) return r.d.order end },
            { key = "level", title = L.COL_LEVEL, width = 54, align = "CENTER",
              text = function(r) return Theme.HexColor(fits(r.d, myLevel()) and "textDim" or "muted", levelText(r.d)) end,
              sort = function(r) return r.d.min end },
            { key = "count", title = L.DG_COL_WANT, width = 62, align = "CENTER",
              text = function(r)
                  local c = counts[r.d.key]
                  if not c or c.total == 0 then return Theme.HexColor("muted", "–") end
                  local online = c.online > 0 and ("  " .. UI.Glyph("dot", "good", 8) .. Theme.HexColor("good", c.online)) or ""
                  return Theme.HexColor("accent", c.total) .. online
              end,
              sort = function(r) local c = counts[r.d.key]; return c and (c.total * 100 + c.online) or 0 end, defaultDesc = true },
        },
        onClick = function(r) state.dungeon = r.d.key; find.Refresh() end,
        isSelected = function(r) return r.d.key == state.dungeon end,
        -- the page search also finds players: their dungeons are marked
        searchText = function(r)
            local c = counts[r.d.key]
            return r.d.name .. " " .. r.d.short .. (r.d.forever and " forever" or "") .. " " .. (c and table.concat(c.names, " ") or "")
        end,
        onEnter = function(frame, r)
            local c = counts[r.d.key] or { total = 0, online = 0, T = 0, H = 0, D = 0 }
            ns.TipOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:AddLine(r.d.name)
            if r.d.forever then GameTooltip:AddLine(L.DG_FOREVER_TIP, 0.75, 0.6, 0.4) end
            GameTooltip:AddLine(L.DG_TIP_LEVEL:format(levelText(r.d)), 0.7, 0.7, 0.7)
            GameTooltip:AddLine(L.DG_TIP_COUNT:format(c.total, c.online), 0.7, 0.7, 0.7)
            if c.total > 0 then
                GameTooltip:AddLine(("%s %d   %s %d   %s %d"):format(roleGlyph("T"), c.T, roleGlyph("H"), c.H, roleGlyph("D"), c.D))
            end
            GameTooltip:Show()
        end,
    })
    dList:SetPoint("TOPLEFT", 0, -32)
    dList:SetPoint("BOTTOMLEFT", 0, 0)
    dList:SetWidth(LEFT_W)

    local right = CreateFrame("Frame", nil, find)
    right:SetPoint("TOPLEFT", dList, "TOPRIGHT", 14, 0)
    right:SetPoint("BOTTOMRIGHT")
    local title = UI.Text(right, 15, "text", nil, nil, true)
    title:SetPoint("TOPLEFT", 2, -2)
    local sub = UI.Text(right, 11, "muted")
    sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
    local markBtn = UI.Button(right, L.DG_MARK, 150, 24, function()
        if not state.dungeon then return end
        -- a short mark from guild chat becomes a normal one; a normal one is removed
        local e = Dungeons.MyEntry(state.dungeon)
        if e and not e.c then Dungeons.Unmark(state.dungeon) else Dungeons.Mark(state.dungeon) end
    end, "star")
    markBtn:SetPoint("TOPRIGHT", 0, 0)
    local editBtn = UI.Button(right, L.DG_EDIT, 90, 24, function()
        if state.dungeon then Dungeons.Select(state.dungeon, "mine") end
    end)
    editBtn:SetPoint("RIGHT", markBtn, "LEFT", -6, 0)

    -- left click: whisper (shift: link the first wanted item) · right click: menu
    local function rowClick(r, button)
        if button == "RightButton" then
            UI.ContextMenu({
                { title = Names.Display(r.name) },
                { text = L.DG_WHISPER, func = function() Dungeons.Whisper(r, state.dungeon) end, disabled = r.me },
                { text = L.DG_INVITE, func = function() Dungeons.Invite(r) end, disabled = r.me or not r.online },
                { text = L.DG_ARMORY, disabled = r.test, func = function()
                    ns.Window.Show("roster")
                    if ns.Roster and ns.Roster.OpenMember then ns.Roster.OpenMember(r.key) end
                end },
            })
            return
        end
        if IsModifiedClick and IsModifiedClick("CHATLINK") and r.ids[1] and ChatEdit_InsertLink then
            ChatEdit_InsertLink(ns.Items.Link(r.ids[1]))
            return
        end
        if not r.me then Dungeons.Whisper(r, state.dungeon) end
    end

    local pList = UI.List(right, {
        rowHeight = 28, sortKey = "seen",
        columns = {
            { key = "name", title = L.COL_CHARACTER, flex = 1, minWidth = 130, iconSize = 18,
              iconSet = function(tex, r) return ns.SetSpecIcon(tex, r.class, r.spec) end,
              text = function(r)
                  local dot = r.online and (UI.Glyph("dot", "good", 9) .. " ") or ""
                  local tag = (r.me and ("  " .. Theme.HexColor("lapis", L.ROSTER_YOU))) or (r.test and ("  " .. Theme.HexColor("muted", L.DG_TEST))) or ""
                  local chat = r.e.c and ("  " .. UI.Glyph("message-circle", "bronze", 11) .. Theme.HexColor("bronze", " " .. L.DG_CHAT_TAG)) or ""
                  return dot .. ns.ColorName(r.name, r.class) .. tag .. chat
              end,
              sort = function(r) return r.key end },
            { key = "level", title = L.COL_LEVEL, width = 44, align = "CENTER",
              text = function(r) return tostring(r.level or "") end, sort = function(r) return r.level or 0 end, defaultDesc = true },
            { key = "role", title = L.DG_COL_ROLE, width = 120, text = function(r) return rolesText(r.e) end,
              sort = function(r) return r.e.r or "Z" end, noHighlight = true },
            { key = "items", title = L.DG_COL_ITEMS, width = 130, optional = 2, noHighlight = true,
              text = function(r) return #r.ids > 0 and itemIcons(r, 18) or Theme.HexColor("muted", "–") end,
              sort = function(r) return #r.ids end, defaultDesc = true,
              onClick = function(r, button) rowClick(r, button) end,
              tip = function(r)
                  if #r.ids == 0 then return nil end
                  local lines = {}
                  for _, id in ipairs(r.ids) do
                      local line = ns.Items.Link(id)
                      local others = r.clash[id]
                      if others then
                          local names = {}
                          for _, o in ipairs(others) do names[#names + 1] = Names.Display(o.name) end
                          line = line .. "  " .. Theme.HexColor("warn", L.DG_ALSO_WANTS:format(table.concat(names, ", ")))
                      end
                      lines[#lines + 1] = line
                  end
                  return L.DG_COL_ITEMS, lines
              end },
            { key = "note", title = L.DG_COL_NOTE, flex = 1, minWidth = 80, optional = 1,
              text = function(r) return r.e.n and Theme.HexColor("textDim", r.e.n) or "" end },
            { key = "seen", title = L.DG_COL_SINCE, width = 74, optional = 3,
              text = function(r) return Theme.HexColor("muted", ns.Ago(r.e.a)) end,
              sort = function(r) return (r.online and 1e10 or 0) + (r.e.a or 0) end, defaultDesc = true },
        },
        sortDesc = true,
        onClick = rowClick,
        onEnter = function(frame, r)
            ns.TipOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:AddLine(ns.ColorName(r.name, r.class))
            if r.e.r then GameTooltip:AddLine(L.DG_TIP_MAIN:format(roleName(r.e.r)), 0.8, 0.8, 0.8) end
            if r.e.c then GameTooltip:AddLine(L.DG_TIP_CHAT:format(expiresText(r.e)), 0.75, 0.6, 0.4, true) end
            if r.e.o then
                local off = {}
                for c in r.e.o:gmatch("[THD]") do off[#off + 1] = roleName(c) end
                GameTooltip:AddLine(L.DG_TIP_OFF:format(table.concat(off, ", ")), 0.8, 0.8, 0.8)
            end
            if r.e.n then GameTooltip:AddLine(r.e.n, 1, 1, 1, true) end
            for _, id in ipairs(r.ids) do
                local others = r.clash[id]
                GameTooltip:AddLine(ns.Items.Link(id) .. (others and ("  " .. Theme.HexColor("warn", L.DG_CLASH)) or ""))
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(r.me and L.DG_ROW_TIP_ME or L.DG_ROW_TIP, 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end,
        rowMark = function(r) return r.me and "lapis" or nil end,
        searchText = function(r)
            local parts = { Names.Display(r.name), roleName(r.e.r), r.e.n or "" }
            for _, id in ipairs(r.ids) do
                local known = ns.Items.names[id]
                parts[#parts + 1] = known and known[1] or ""
            end
            return table.concat(parts, " ")
        end,
    })
    pList:SetPoint("TOPLEFT", 0, -32)
    pList:SetPoint("BOTTOMRIGHT", 0, 26)
    local roleLine = UI.Text(right, 11, "textDim")
    roleLine:SetPoint("BOTTOMLEFT", 2, 4)
    roleLine:SetPoint("BOTTOMRIGHT", 0, 4)
    roleLine:SetWordWrap(false)

    function find.Refresh()
        counts = Dungeons.Counts()
        onlineCheck:Refresh(); fitsCheck:Refresh()
        local level = myLevel()
        local rows = {}
        for _, d in ipairs(Dungeons.LIST) do
            if not state.fits or fits(d, level) then rows[#rows + 1] = { key = d.key, d = d } end
        end
        dList:SetRows(rows)
        -- first look: the dungeon with the most interest
        if not state.dungeon then
            local best, n = nil, 0
            for _, r in ipairs(rows) do
                local c = counts[r.d.key]
                if c and c.total > n then best, n = r.d.key, c.total end
            end
            state.dungeon = best or (rows[1] and rows[1].d.key)
            dList:Draw()
        end
        local d = state.dungeon and Dungeons.BY_KEY[state.dungeon]
        if not d then pList:SetRows({}); return end
        title:SetText(d.name)
        sub:SetText(L.DG_LEVEL_RANGE:format(levelText(d)))
        local mineE = Dungeons.MyEntry(d.key)
        local marked = mineE ~= nil and not mineE.c
        markBtn:SetText(marked and L.DG_UNMARK or L.DG_MARK)
        editBtn:SetShown(marked)
        local players = Dungeons.Interested(d.key, state.online)
        pList:SetRows(players)
        pList:SetEmptyText(state.online and L.DG_EMPTY_ONLINE or L.DG_EMPTY, L.DG_EMPTY_HINT)
        -- role cover: main roles count, off specs as reserve
        local main, off = { T = 0, H = 0, D = 0 }, { T = 0, H = 0, D = 0 }
        local clashes = 0
        for _, r in ipairs(players) do
            if r.e.r then main[r.e.r] = main[r.e.r] + 1 end
            for c in (r.e.o or ""):gmatch("[THD]") do off[c] = off[c] + 1 end
            for _ in pairs(r.clash) do clashes = clashes + 1 end
        end
        local parts = {}
        for _, c in ipairs(ROLES) do
            local text = roleGlyph(c, 11) .. " " .. Theme.HexColor(main[c] > 0 and "text" or "muted", roleName(c) .. " " .. main[c])
            if off[c] > 0 then text = text .. Theme.HexColor("muted", " (+" .. off[c] .. ")") end
            parts[#parts + 1] = text
        end
        local line = table.concat(parts, "    ")
        if clashes > 0 then line = line .. "    " .. UI.Glyph("dot", "warn", 9) .. " " .. Theme.HexColor("warn", L.DG_CLASHES:format(clashes)) end
        roleLine:SetText(#players > 0 and line or "")
    end
    tabSearch.find = {
        SearchHits = function(q) return dList:SearchHits(q) end,
        SearchApply = function(q)
            dList:ShowFirstHit(q)
            -- jump to the first dungeon with a hit
            if q ~= "" and dList.firstHit and dList.firstHit ~= state.dungeon then state.dungeon = dList.firstHit; find.Refresh() end
            pList:ShowFirstHit(q)
        end,
    }

    -------------------------------------------------------------------
    -- Tab "My interest": all dungeons with a switch, editor on the right
    -------------------------------------------------------------------
    local my = CreateFrame("Frame", nil, holder)
    my:SetAllPoints()
    my:Hide()
    tabs.mine = my

    local EDIT_W = 330
    local mList = UI.List(my, {
        rowHeight = 26, sortKey = "order",
        columns = {
            { key = "on", title = "", width = 44, align = "CENTER",
              toggle = { get = function(r) return Dungeons.MyEntry(r.d.key) ~= nil end,
                  set = function(r, v) state.mine = r.d.key; if v then Dungeons.Mark(r.d.key) else Dungeons.Unmark(r.d.key) end end,
                  tip = L.DG_TOGGLE_TIP } },
            { key = "order", title = L.DG_COL_DUNGEON, flex = 1, minWidth = 120,
              text = function(r)
                  local e = Dungeons.MyEntry(r.d.key)
                  local chat = (e and e.c) and ("  " .. Theme.HexColor("bronze", L.DG_CHAT_TAG)) or ""
                  return Theme.HexColor(e and "text" or "textDim", r.d.name) .. foreverTag(r.d) .. chat
              end,
              sort = function(r) return r.d.order end },
            { key = "level", title = L.COL_LEVEL, width = 54, align = "CENTER",
              text = function(r) return Theme.HexColor(fits(r.d, myLevel()) and "textDim" or "muted", levelText(r.d)) end,
              sort = function(r) return r.d.min end },
            { key = "role", title = L.DG_COL_ROLE, width = 110, optional = 2, noHighlight = true,
              text = function(r) local e = Dungeons.MyEntry(r.d.key); return e and rolesText(e) or "" end },
            { key = "items", title = L.DG_COL_ITEMS, width = 90, optional = 1, noHighlight = true,
              text = function(r)
                  local e = Dungeons.MyEntry(r.d.key)
                  return e and itemIcons({ ids = Dungeons.ItemIds(e.i) }, 16) or ""
              end },
            { key = "exp", title = L.DG_COL_EXPIRES, width = 70, optional = 3,
              text = function(r) local e = Dungeons.MyEntry(r.d.key); return e and expiresText(e) or "" end },
        },
        onClick = function(r) if my.note then my.note:ClearFocus() end; state.mine = r.d.key; my.Refresh() end,
        isSelected = function(r) return r.d.key == state.mine end,
        searchText = function(r) return r.d.name .. " " .. r.d.short .. (r.d.forever and " forever" or "") end,
    })
    mList:SetPoint("TOPLEFT", 0, 0)
    mList:SetPoint("BOTTOMRIGHT", -(EDIT_W + 14), 62)

    local renewAll = UI.Button(my, L.DG_RENEW_ALL, 120, 24, function() Dungeons.RenewAll() end, "rotate-ccw")
    renewAll:SetPoint("BOTTOMLEFT", 0, 0)
    renewAll.tip = { L.DG_RENEW_ALL_TIP }
    local daysLabel = UI.Text(my, 11, "muted")
    daysLabel:SetPoint("LEFT", renewAll, "RIGHT", 14, 0)
    daysLabel:SetText(L.DG_KEEP_FOR)
    local days = UI.Dropdown(my, 90, function()
        local items = {}
        for _, n in ipairs(Dungeons.DURATIONS) do items[#items + 1] = { value = n, text = L.DG_DAYS:format(n) } end
        return items
    end, function() return settings().days end, function(v) settings().days = v end)
    days:SetPoint("LEFT", daysLabel, "RIGHT", 8, 0)
    -- guild chat pick-up on/off (own row above, the list ends there)
    local chatCheck = UI.Check(my, L.DG_CHAT_PICKUP:format(Dungeons.CHAT_HOURS), function() return settings().chat ~= false end,
        function(v) settings().chat = v; fire() end, L.DG_CHAT_PICKUP_TIP)
    chatCheck:SetPoint("BOTTOMLEFT", 0, 32)
    local answerCheck = UI.Check(my, L.DG_ANSWER_ON, function() return settings().answer ~= false end,
        function(v) settings().answer = v end, L.DG_ANSWER_ON_TIP)
    answerCheck:SetPoint("LEFT", chatCheck, "RIGHT", 16, 0)

    -- editor card
    local card = UI.Panel(my, "panel", "borderDim")
    card:SetPoint("TOPRIGHT", 0, 0)
    card:SetPoint("BOTTOMRIGHT", 0, 0)
    card:SetWidth(EDIT_W)
    local cTitle = UI.CardTitle(card, "")
    local cLevel = UI.Text(card, 11, "muted")
    cLevel:SetPoint("TOPLEFT", 26, -32)
    local hint = UI.Text(card, 12, "textDim")
    hint:SetPoint("TOPLEFT", 16, -60)
    hint:SetPoint("RIGHT", card, "RIGHT", -16, 0)
    hint:SetWordWrap(true)
    hint:SetText(L.DG_EDIT_HINT)
    local markHere = UI.Button(card, L.DG_MARK, 150, 26, function() if state.mine then Dungeons.Mark(state.mine) end end, "star")
    markHere:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)

    local edit = CreateFrame("Frame", nil, card)
    edit:SetPoint("TOPLEFT", 16, -56)
    edit:SetPoint("BOTTOMRIGHT", -16, 12)

    local _, myClass = ns.Call(UnitClass, "player")
    local classRoles = Dungeons.ClassRoles(myClass)

    local function label(text, y)
        local fs = UI.Text(edit, 11, "muted", nil, nil, true)
        fs:SetPoint("TOPLEFT", 0, y)
        fs:SetText(ns.Upper(text))
        return fs
    end
    local function entry() return state.mine and Dungeons.MyEntry(state.mine) end

    label(L.DG_MAIN_ROLE, 0)
    local roleOpts = {}
    for _, r in ipairs(classRoles) do roleOpts[#roleOpts + 1] = { value = r, text = roleName(r) } end
    local mainRole = UI.Segmented(edit, math.min(EDIT_W - 32, 90 * #roleOpts), roleOpts,
        function() local e = entry(); return e and e.r end,
        function(v) Dungeons.Edit(state.mine, function(e) e.r = v end) end)
    mainRole:SetPoint("TOPLEFT", 0, -16)

    label(L.DG_OFF_SPEC, -52)
    local offChecks = {}
    for _, r in ipairs(classRoles) do
        local c = UI.Check(edit, roleName(r), function()
            local e = entry()
            return e and e.o and e.o:find(r, 1, true) ~= nil or false
        end, function(v)
            Dungeons.Edit(state.mine, function(e)
                local o = (e.o or ""):gsub(r, "")
                if v then o = o .. r end
                e.o = o
            end)
        end)
        c.role = r
        offChecks[#offChecks + 1] = c
    end
    local offNone = UI.Text(edit, 11, "muted")
    offNone:SetText(L.DG_OFF_NONE)

    label(L.DG_COL_NOTE, -100)
    local note = UI.EditBox(edit, EDIT_W - 32, 24, L.DG_NOTE_HINT)
    note:SetPoint("TOPLEFT", 0, -116)
    note:SetMaxLetters(MAX_NOTE)
    my.note = note
    -- saved for the dungeon the text was loaded for (the selection may have changed meanwhile)
    local function saveNote(self)
        local dk = self.dk
        local e = dk and Dungeons.MyEntry(dk)
        if not e then return end
        local text = cutNote(self:GetText())
        if text == (e.n or "") then return end
        Dungeons.Edit(dk, function(x) x.n = text ~= "" and text or nil end)
    end
    note.onCommit = saveNote
    note.onEnter = saveNote

    label(L.DG_COL_ITEMS, -152)
    local icons = {}
    for i = 1, MAX_ITEMS do
        local b = UI.ItemIcon(edit, 30)
        b:SetPoint("TOPLEFT", (i - 1) * 36, -168)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnEnter", function(self)
            if not self.item then return end
            ns.Items.ShowTooltip(self, self.item)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.DG_ITEM_REMOVE_TIP, 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        b:SetScript("OnClick", function(self, button)
            if not self.item then return end
            if button == "RightButton" then Dungeons.RemoveItem(state.mine, self.item); return end
            if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(ns.Items.Link(self.item)) end
        end)
        b:Hide()
        icons[i] = b
    end
    -- adding items: drop one here, or click and then shift-click an item anywhere
    local capture = { untilT = 0 }
    local addBtn = UI.Button(edit, L.DG_ADD_ITEM, 120, 26, nil, "star")
    local addHint = UI.Text(edit, 10, "muted")
    addHint:SetPoint("TOPLEFT", 0, -236)
    addHint:SetPoint("RIGHT", edit, "RIGHT")
    addHint:SetWordWrap(true)
    addHint:SetText(L.DG_ADD_HINT)
    -- type an item id or (part of) a name; several matches: pick one from a menu
    local findBox = UI.EditBox(edit, EDIT_W - 32, 24, L.DG_FIND_HINT)
    findBox:SetPoint("TOPLEFT", 0, -206)
    local function addFound(id)
        if state.mine and Dungeons.AddItem(state.mine, id) then findBox:SetText("") end
    end
    findBox.onEnter = function(self)
        local text = self:GetText()
        if not state.mine or not text:find("%S") then return end
        local ids, badId = Dungeons.FindItems(text)
        if #ids == 0 then
            ns.Print(badId and L.DG_FIND_BAD_ID:format(text) or L.DG_FIND_NONE:format(text))
            return
        end
        if #ids == 1 then addFound(ids[1]); return end
        local items = {}
        for i, id in ipairs(ids) do
            if i > 30 then break end
            items[#items + 1] = { value = id, text = ("|T%s:14:14|t %s"):format(tostring(ns.Items.Icon(id)), ns.Items.Link(id)) }
        end
        UI.OpenMenu(self, items, function(id) addFound(id) end, self:GetWidth())
    end
    my.findBox = findBox
    local function dropCursor()
        local kind, _, link = ns.Call(GetCursorInfo)
        if kind ~= "item" or type(link) ~= "string" or not state.mine then return false end
        ClearCursor()
        Dungeons.AddItem(state.mine, link)
        return true
    end
    local function setCapture(on)
        capture.untilT = on and (GetTime() + 30) or 0
        addBtn:SetText(on and L.DG_ADD_WAIT or L.DG_ADD_ITEM)
        if on then ns.After(30.2, function() if GetTime() >= capture.untilT then setCapture(false) end end) end
    end
    addBtn:SetScript("OnClick", function()
        if dropCursor() then return end
        setCapture(GetTime() >= capture.untilT)
    end)
    addBtn:SetScript("OnReceiveDrag", dropCursor)
    Dungeons.CaptureItem = function(link)
        -- shift-click while the ID/name field has the focus adds the item right away
        if findBox:HasFocus() and state.mine and my:IsVisible() then
            Dungeons.AddItem(state.mine, link)
            findBox:SetText("")
            return true
        end
        if GetTime() >= capture.untilT or not state.mine or not my:IsVisible() then return false end
        Dungeons.AddItem(state.mine, link)
        setCapture(false)
        return true
    end

    label(L.DG_COL_EXPIRES, -290)
    local expText = UI.Text(edit, 12, "textDim")
    expText:SetPoint("TOPLEFT", 0, -308)
    local renew = UI.Button(edit, L.DG_RENEW, 100, 24, function() if state.mine then Dungeons.Renew(state.mine) end end, "rotate-ccw")
    renew:SetPoint("TOPLEFT", 0, -328)
    local remove = UI.Button(edit, L.DG_REMOVE, 120, 24, function() if state.mine then Dungeons.Unmark(state.mine) end end, "x")
    remove:SetPoint("LEFT", renew, "RIGHT", 8, 0)

    function my.Refresh()
        if not state.mine then state.mine = state.dungeon or "stratud" end
        local rows = {}
        for _, d in ipairs(Dungeons.LIST) do rows[#rows + 1] = { key = d.key, d = d } end
        mList:SetRows(rows)
        days:Refresh()
        chatCheck:Refresh()
        answerCheck:Refresh()
        local d = Dungeons.BY_KEY[state.mine]
        local e = entry()
        cTitle:SetText(ns.Upper(d and d.name or ""))
        cLevel:SetText(d and L.DG_LEVEL_RANGE:format(levelText(d)) or "")
        hint:SetShown(e == nil)
        markHere:SetShown(e == nil)
        edit:SetShown(e ~= nil)
        if not e then return end
        mainRole:Refresh()
        local x, shown = 0, 0
        for _, c in ipairs(offChecks) do
            local show = c.role ~= e.r
            c:SetShown(show)
            if show then
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", x, -68)
                c:Refresh()
                x = x + c:GetWidth() + 16
                shown = shown + 1
            end
        end
        offNone:ClearAllPoints()
        offNone:SetPoint("TOPLEFT", 0, -72)
        offNone:SetShown(shown == 0)
        if not note:HasFocus() then note:SetText(e.n or ""); note.dk = state.mine end
        local ids = Dungeons.ItemIds(e.i)
        for i, b in ipairs(icons) do b:SetItem(ids[i]) end
        addBtn:ClearAllPoints()
        if #ids < MAX_ITEMS then
            addBtn:SetPoint("TOPLEFT", #ids * 36, -170)
            addBtn:Show()
        else
            addBtn:Hide()
        end
        findBox:SetShown(#ids < MAX_ITEMS)
        expText:SetText(expiresText(e) .. Theme.HexColor("muted", "  ·  " .. L.DG_SINCE:format(ns.Ago(e.a))))
    end
    tabSearch.mine = {
        SearchHits = function(q) return mList:SearchHits(q) end,
        SearchApply = function(q) mList:ShowFirstHit(q) end,
    }

    -- selects a dungeon on a tab (from /lg lfg <name>, the test or "Edit")
    function Dungeons.Select(dk, tab)
        if dk and Dungeons.BY_KEY[dk] then
            if (tab or state.tab) == "mine" then state.mine = dk else state.dungeon = dk end
        end
        bar:Select(tab or state.tab or "find")
    end

    page.searchHint = L.DG_SEARCH
    page.Search = function(text) return UI.TabSearch(bar, tabSearch, text) end

    page.OnShow = function()
        if tabs[state.tab] and tabs[state.tab].Refresh then tabs[state.tab].Refresh() end
    end
    bar:Select(state.tab)
end, { section = "guild", icon = "compass", module = "dungeons" })

-- shift-click on an item while "Add item" waits
ns.On("LG_READY", function()
    if not hooksecurefunc or not HandleModifiedItemClick then return end
    hooksecurefunc("HandleModifiedItemClick", function(link)
        if ns.IsSecret(link) or type(link) ~= "string" or not link:find("|Hitem:") then return end
        if Dungeons.CaptureItem then Dungeons.CaptureItem(link) end
    end)
end)

ns.On("LG_DUNGEONS", function() ns.Window.Refresh("dungeons") end)
ns.On("LG_ROSTER", function() ns.Debounce("dungeons-redraw", 1, function() ns.Window.Refresh("dungeons") end) end)
ns.On("GET_ITEM_INFO_RECEIVED", function() ns.Debounce("dungeons-items", 0.5, function() ns.Window.Refresh("dungeons") end) end)

-- /lg lfg [dungeon]: finds a dungeon by key, short or (part of the) name
function Dungeons.Open(text)
    text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    ns.Window.Show("dungeons")
    if text == "" then return end
    local found
    for _, d in ipairs(Dungeons.LIST) do
        if d.key == text or d.short:lower() == text then found = d; break end
    end
    if not found then
        for _, d in ipairs(Dungeons.LIST) do
            if d.name:lower():find(text, 1, true) or d.short:lower():find(text, 1, true) then found = d; break end
        end
    end
    if found and Dungeons.Select then Dungeons.Select(found.key, "find")
    elseif not found then ns.Print(L.DG_UNKNOWN:format(text)) end
end
