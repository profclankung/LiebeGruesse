-- Daily counters every player records about themselves: time as a ghost,
-- flights, hearthstone, junk sold, vendor shopping, mails, interrupts,
-- night owl / early bird and login days.
-- One running entry per player and day ("dy:<player>:<day>"); the guild keeps
-- the highest value of every counter (Community addEvent merges them).
local _, ns = ...
local Community, Names = ns.Community, ns.Names
local Daily = {}
ns.CommunityDaily = Daily

-- counter -> highest believable value for one day (also used to check others' data;
-- guard, spirit and ah are no longer recorded since 1.0.90, older entries stay valid)
Daily.LIMITS = {
    ghost = 86400, guard = 100, spirit = 100, taxi = 500, hearth = 200, junk = 1e8, shop = 1e9,
    ah = 5000, mail = 2000, kick = 5000, owl = 1, early = 1, login = 1,
}

local function on() return ns.Database.Settings().modules.community ~= false and IsInGuild() end
local function today() return date("%Y%m%d") end

local function record()
    local char = ns.Database.Char()
    local day = today()
    if not char.daily or char.daily.day ~= day then char.daily = { day = day, c = {} } end
    return char.daily
end

local lastShare = 0
function Daily.Share()
    lastShare = GetTime()
    local r = ns.Database.Char().daily
    if not on() or not r or not next(r.c) then return end
    local d = { day = r.day }
    for k, v in pairs(r.c) do d[k] = math.floor(v) end
    local me = Names.Me()
    Community.AddEvent({ id = ("dy:%s:%s"):format(me, r.day), t = ns.Now(), k = "daily", who = me, d = d }, true)
end

local function changed()
    -- shared half a minute after the last change, and at least every 10 minutes
    if GetTime() - lastShare > 600 then Daily.Share() end
    ns.Debounce("lg-daily", 30, Daily.Share)
end

function Daily.Add(key, n)
    if not on() or not Daily.LIMITS[key] then return end
    local r = record()
    r.c[key] = math.min(Daily.LIMITS[key], (r.c[key] or 0) + (n or 1))
    changed()
end

function Daily.Set(key, v)
    if not on() or not Daily.LIMITS[key] then return end
    local r = record()
    if (r.c[key] or 0) >= v then return end
    r.c[key] = math.min(Daily.LIMITS[key], v)
    changed()
end

-- is another player's daily entry believable?
function Daily.Valid(d)
    if type(d) ~= "table" or type(d.day) ~= "string" or not d.day:match("^%d%d%d%d%d%d%d%d$") then return false end
    for k, v in pairs(d) do
        if k ~= "day" then
            local limit = Daily.LIMITS[k]
            if not limit or type(v) ~= "number" or v < 0 or v > limit then return false end
        end
    end
    return true
end

---------------------------------------------------------------------------
-- Login days, night owl (2:00–5:59), early bird (6:00–6:59)
---------------------------------------------------------------------------
ns.On("LG_READY", function()
    ns.After(25, function()
        Daily.Set("login", 1)
        local h = tonumber(date("%H")) or 12
        if h >= 2 and h < 6 then Daily.Set("owl", 1) elseif h == 6 then Daily.Set("early", 1) end
        -- a count from the last session that was never shared
        Daily.Share()
    end)
end)

---------------------------------------------------------------------------
-- Ghost runner: dead time from death to being alive again (at most 30 min each)
---------------------------------------------------------------------------
local deadAt
ns.On("PLAYER_DEAD", function() deadAt = GetTime() end)
local function alive()
    if not deadAt or ns.Call(UnitIsDeadOrGhost, "player") == true then return end
    local t = GetTime() - deadAt
    deadAt = nil
    if t > 1 then Daily.Add("ghost", math.min(1800, t)) end
end
ns.On("PLAYER_ALIVE", alive)
ns.On("PLAYER_UNGHOST", alive)

---------------------------------------------------------------------------
-- Travel: flight master, hearthstone
---------------------------------------------------------------------------
if hooksecurefunc and TakeTaxiNode then hooksecurefunc("TakeTaxiNode", function() Daily.Add("taxi") end) end
local HEARTH = { [8690] = true }

---------------------------------------------------------------------------
-- Interrupts: our own interrupt spell, then the target's cast stops
---------------------------------------------------------------------------
-- the kick counts only when the target really was casting (start/stop events of the target)
-- (events of the target only: a frame with unit events, nothing for the rest of the raid)
local kickAt, targetCasting = nil, false
local castFrame = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED" }) do
    if castFrame.RegisterUnitEvent then pcall(castFrame.RegisterUnitEvent, castFrame, e, "target") end
end
castFrame:SetScript("OnEvent", function(_, event)
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then targetCasting = true
    else ns.After(0.7, function() targetCasting = false end) end
end)
Daily.castFrame = castFrame
ns.On("PLAYER_TARGET_CHANGED", function()
    targetCasting = (ns.Call(UnitCastingInfo, "target") or ns.Call(UnitChannelInfo, "target")) ~= nil
end)
Daily.TargetCasting = function() return targetCasting end
ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
    if unit ~= "player" or ns.IsSecret(spellID) then return end
    if HEARTH[spellID] then Daily.Add("hearth"); return end
    local S = ns.CooldownSpells
    local id = S and S.Resolve(spellID)
    local spell = id and S.byId[id]
    if spell and spell.cat == "interrupt" and targetCasting then kickAt = GetTime() end
end)
local function interrupted(_, unit)
    if not kickAt or GetTime() - kickAt > 0.6 then return end
    if unit == "target" or unit == "focus" or unit == "mouseover" then
        kickAt = nil
        Daily.Add("kick")
    end
end
ns.On("UNIT_SPELLCAST_INTERRUPTED", interrupted)
ns.On("UNIT_SPELLCAST_CHANNEL_STOP", function(e, unit)
    -- a stopped channel right after our kick counts as interrupted
    interrupted(e, unit)
end)

---------------------------------------------------------------------------
-- Vendor: junk sold (grey items that leave the bags while a merchant is open)
-- and money spent there (minus repairs)
---------------------------------------------------------------------------
local shop      -- { money, spent, repairStart, junk = { ["bag:slot"] = { id, value } } }
local function money() return ns.Call(GetMoney) or 0 end
local function snapshotJunk()
    local junk = {}
    local C = C_Container
    for bag = 0, 4 do
        local slots = (C and C.GetContainerNumSlots and ns.Call(C.GetContainerNumSlots, bag)) or 0
        for slot = 1, slots do
            local info = C.GetContainerItemInfo and ns.Call(C.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and info.quality == 0 and info.itemID and not info.hasNoValue then
                local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
                local price = select(11, ns.Call(getInfo, info.itemID))
                if type(price) == "number" and price > 0 then
                    junk[bag .. ":" .. slot] = { id = info.itemID, value = price * (info.stackCount or 1) }
                end
            end
        end
    end
    return junk
end
Daily.SnapshotJunk = snapshotJunk

ns.On("MERCHANT_SHOW", function()
    shop = { money = money(), spent = 0, earned = 0, repair = ns.Call(GetRepairAllCost) or 0, repaired = 0,
        junk = snapshotJunk(), junkSold = 0 }
end)
ns.On("UPDATE_INVENTORY_DURABILITY", function()
    if not shop then return end
    local now = ns.Call(GetRepairAllCost) or 0
    if type(now) == "number" and now < shop.repair then shop.repaired = shop.repaired + (shop.repair - now) end
    shop.repair = now
end)
ns.On("PLAYER_MONEY", function()
    if not shop then return end
    local m = money()
    if m < shop.money then shop.spent = shop.spent + (shop.money - m)
    else shop.earned = shop.earned + (m - shop.money) end
    shop.money = m
end)
ns.On("BAG_UPDATE_DELAYED", function()
    if not shop then return end
    local C = C_Container
    local sold = 0
    for slotKey, j in pairs(shop.junk) do
        local bag, slot = slotKey:match("^(%-?%d+):(%d+)$")
        local info = C and C.GetContainerItemInfo and ns.Call(C.GetContainerItemInfo, tonumber(bag), tonumber(slot))
        if not (type(info) == "table" and info.itemID == j.id) then
            sold = sold + j.value
            shop.junk[slotKey] = nil
        end
    end
    shop.junkSold = shop.junkSold + sold
end)
ns.On("MERCHANT_CLOSED", function()
    local s = shop
    shop = nil
    if not s then return end
    local bought = s.spent - s.repaired
    if bought > 0 then Daily.Add("shop", bought) end
    -- grey items that left the bags count only as far as money came in (not moved or deleted ones)
    local junk = math.min(s.junkSold, s.earned)
    if junk > 0 then Daily.Add("junk", junk) end
end)

---------------------------------------------------------------------------
-- Mail
---------------------------------------------------------------------------
ns.On("MAIL_SEND_SUCCESS", function() Daily.Add("mail") end)
