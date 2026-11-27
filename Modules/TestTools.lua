-- Test tools: try every visible feature alone, without a group or a raid.
-- Nothing here is sent to the guild or saved (except the life-statistics
-- refresh, which reads your real numbers).
local _, ns = ...
local L, Names, UI = ns.L, ns.Names, ns.UI
local Test = {}
ns.Test = Test

function Test.FailVote() ns.Community.TestVote() end
function Test.Mispull() ns.Community.TestEvent("mispull") end
function Test.Death() ns.Community.TestEvent("death") end

function Test.Consumables()
    local scan = ns.RaidCheck.ScanUnit("player")
    local parts = {}
    parts[#parts + 1] = scan.flask and (L.TEST_FLASK .. ": " .. scan.flask) or L.TEST_NO_FLASK
    parts[#parts + 1] = #scan.elixirs > 0 and (L.TEST_ELIXIRS .. ": " .. table.concat(scan.elixirs, ", ")) or L.TEST_NO_ELIXIRS
    parts[#parts + 1] = scan.food and L.TEST_FOOD or L.TEST_NO_FOOD
    ns.Print(L.TEST_TAG .. " " .. table.concat(parts, "  ·  "))
    ns.Community.TestEvent("consum")
end

function Test.Toast()
    UI.Toast(L.TEST_TAG .. " " .. ns.title, L.TEST_TOAST_TEXT)
end

function Test.Feed()
    local e = { k = "boss", t = ns.Now(), a = Names.Me(), d = { b = L.TEST_BOSS, n = 12 } }
    UI.Toast(L.TEST_TAG .. " " .. L.PAGE_FEED, ns.Feed.Text(e))
end

-- a local sample entry to try deleting (never sent; deleting it sends nothing)
function Test.FeedDelete()
    local now = ns.Now()
    ns.Feed.Add({ id = "lvl:test entry:" .. now, t = now, k = "lvl", a = "test entry", d = { l = 60 }, test = true })
    ns.Window.Show("feed")
    ns.Print(ns.Feed.CanDelete() and ns.L.FEED_TEST_HINT or ns.L.FEED_DELETE_OFFICERS)
end

function Test.Craft(query)
    query = query and query ~= "" and query or nil
    if not query then
        local idx = ns.Crafts.Index()
        local id = next(idx.recipes)
        query = id and ns.Crafts.Name(id) or "Netherweave"
    end
    ns.Print(L.TEST_TAG .. " " .. ns.Admin.CraftPrefix() .. " " .. query .. "  >  " .. ns.CraftQuery.Answer(query))
end

function Test.Life()
    if ns.LifeStats.Capture(true) then ns.Print(L.TEST_TAG .. " " .. L.LIFE_READ_OK) else ns.Print(L.LIFE_CANNOT_READ) end
    ns.Window.Show("stats")
end

function Test.Compare()
    ns.Window.Show("roster")
    local me = Names.Me()
    local pick
    for _, key in ipairs(ns.Guild.order or {}) do
        local m = ns.Database.Member(key)
        if not Names.Same(key, me) and m and ns.Inspect.Gear(m) then pick = key; break end
    end
    pick = pick or me
    if ns.Roster and ns.Roster.OpenMember then ns.Roster.OpenMember(pick) end
    ns.ArmoryCompare.Open(pick)
end

function Test.Council() ns.Council.Test() end
function Test.Cooldowns() ns.Cooldowns.Test() end
function Test.Unlock() ns.Window.ToggleMovers() end
function Test.ProfCooldowns() ns.ProfCD.Test(); ns.Window.Show("professions"); if ns.Professions and ns.Professions.ShowTab then ns.Professions.ShowTab("cds") end end
function Test.Trade() ns.TradeTimers.Test() end
function Test.Bar() ns.CouncilBar.testUntil = GetTime() + 120; ns.CouncilBar.Layout(); ns.After(121, ns.CouncilBar.Layout) end

-- running state and "off" of the tests that keep running (test suite switches)
function Test.BarActive() return ns.CouncilBar.testUntil ~= nil and GetTime() < ns.CouncilBar.testUntil end
function Test.StopBar() ns.CouncilBar.testUntil = nil; ns.CouncilBar.Layout() end
function Test.CouncilActive() local s = ns.Council.session; return s ~= nil and s.test and not s.ended end
function Test.TradeActive() return ns.TradeTimers.test ~= nil end
function Test.StopTrade() ns.TradeTimers.test = nil; ns.TradeTimers.Layout() end
function Test.BoardsActive() return ns.Community.testEvents ~= nil end
function Test.StopBoards()
    ns.Community.testEvents, ns.Community.testPosts = nil, nil
    ns.Window.Refresh("community")
end
function Test.QuickActive()
    for _, e in ipairs(ns.QuickBar.entries or {}) do if e.test then return true end end
    return false
end
-- "Move elements" off: like the second click on the button
function Test.Lock()
    local cd = ns.Database.Settings().cd
    cd.locked = true
    ns.Cooldowns.SetPreview(false)
    ns.Movers.SetActive(false)
    ns.Fire("LG_COOLDOWNS")
end

-- Raw talent and stat API values of the own character (to check the armory)
function Test.Armory()
    local function raw(...)
        local out = {}
        for i = 1, select("#", ...) do out[#out + 1] = tostring((select(i, ...))) end
        return table.concat(out, ", ")
    end
    ns.Print(L.TEST_TAG .. " " .. L.TEST_ARMORY_HEAD)
    local tabs = ns.Call(GetNumTalentTabs)
    ns.Print("GetNumTalentTabs: " .. tostring(tabs))
    for i = 1, (type(tabs) == "number" and tabs or 0) do
        ns.Print(("GetTalentTabInfo(%d): %s"):format(i, raw(ns.Call(GetTalentTabInfo, i))))
        ns.Print(("GetTalentInfo(%d,1): %s"):format(i, raw(ns.Call(GetTalentInfo, i, 1))))
    end
    local cfg = ns.Profile.TraitConfig(false)
    local info = cfg and C_Traits and ns.Call(C_Traits.GetConfigInfo, cfg)
    local tree = type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs[1]
    local groups = tree and C_Traits.GetGroupDisplayInfoByTreeID and ns.Call(C_Traits.GetGroupDisplayInfoByTreeID, tree)
    ns.Print(("C_Traits: config %s · tree %s · groups %s"):format(tostring(cfg), tostring(tree), type(groups) == "table" and #groups or "nil"))
    local _, tp, tn = ns.Profile.ReadTalents(false)
    ns.Print("ReadTalents: " .. tostring(tp) .. " | " .. tostring(tn))
    ns.Print("UnitAttackPower: " .. raw(ns.Call(UnitAttackPower, "player")))
    ns.Print("UnitRangedAttackPower: " .. raw(ns.Call(UnitRangedAttackPower, "player")))
    ns.Print("GetCombatRatingBonus hit melee/ranged/spell: " .. raw(ns.Call(GetCombatRatingBonus, CR_HIT_MELEE or 6))
        .. " / " .. raw(ns.Call(GetCombatRatingBonus, CR_HIT_RANGED or 7)) .. " / " .. raw(ns.Call(GetCombatRatingBonus, CR_HIT_SPELL or 8)))
    ns.Print("GetHitModifier: " .. raw(ns.Call(GetHitModifier)) .. "  GetCritChance: " .. raw(ns.Call(GetCritChance))
        .. "  GetRangedCritChance: " .. raw(ns.Call(GetRangedCritChance)))
    ns.Print("GetSpellHitModifier: " .. raw(ns.Call(GetSpellHitModifier)) .. "  GetSpellCritChance(2): " .. raw(ns.Call(GetSpellCritChance, 2))
        .. "  GetSpellBonusDamage(2): " .. raw(ns.Call(GetSpellBonusDamage, 2)) .. "  GetSpellBonusHealing: " .. raw(ns.Call(GetSpellBonusHealing)))
    ns.Print("ReadStats: " .. tostring(ns.Profile.ReadStats()))
end

-- Everything that pops up, one after another
function Test.All()
    Test.Toast()
    ns.After(1, Test.Feed)
    ns.After(2, Test.Death)
    ns.After(3, Test.FailVote)
end

-- Feeds forged messages through the checks (nothing is stored or sent)
function Test.Security()
    local L, Names = ns.L, ns.Names
    local me = Names.Me() or "me"
    local now = ns.Now()
    local fake = "fake person"
    local cases = {
        { "level entry for another player", not ns.Feed.LiveOk({ id = "lvl:" .. me .. ":60", t = now, k = "lvl", a = me, d = { l = 60 } }, fake) },
        { "own level entry", ns.Feed.LiveOk({ id = "lvl:" .. me .. ":10", t = now, k = "lvl", a = me, d = { l = 10 } }, me) },
        { "backdated guild first", not ns.Feed.LiveOk({ id = "first:lvl60", t = now - 86400, k = "first", a = me, d = { w = "lvl", l = 60 } }, me) },
        { "loot council award without the loot master's record",
          not ns.Feed.LiveOk({ id = "lc:" .. fake .. ":1:1", t = now, k = "lc", a = me, d = {} }, fake) },
        { "loot history record from someone else",
          (function()
              local r = ns.Council.CleanRecord({ id = me .. ":1:1", t = now, i = "item:19019", by = me, to = fake })
              return r ~= nil and not Names.Same(r.by, fake)
          end)() },
        { "links and textures stripped", (ns.Clean({ x = "|TInterface\\Icons\\x:64|t" }).x or ""):find("|", 1, true) == nil },
        { "presence under another name", not ns.CoGuild.PresenceOk({ n = "Ben Lienert" }, "Fake-Person") },
    }
    ns.Print(L.SEC_TITLE)
    for _, c in ipairs(cases) do
        ns.Print(("  %s: %s"):format(c[2] and L.SEC_OK or ("|cffff5555" .. L.SEC_FAIL .. "|r"), c[1]))
    end
    ns.Print("  " .. ns.CoGuild.BundStatus())
    return cases
end
