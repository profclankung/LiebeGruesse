-- Slash commands: /lg and /liebegruesse
-- All commands live in one registry (ns.Commands). The chat help
-- ("/lg help", "/lg help lc", "/lg lc help") and the "Help & commands" page
-- are generated from it, so they always match what really exists.
local _, ns = ...
local L = ns.L

local function arg1(rest) return (rest or ""):match("^(%S*)%s*(.-)$") end

local function showCraftSearch(text)
    ns.Window.Show("professions")
    if ns.Professions.ShowTab then ns.Professions.ShowTab("guild") end
    if ns.CraftsPage.Search then ns.CraftsPage.Search(text or "") end
end

local function lcAdd(arg)
    local word = (arg or ""):match("^(%S+)")
    if word and (word:lower() == "all" or word:lower() == "bags" or word:lower() == "alle") then
        ns.CouncilQueue.AddAll()
        ns.CouncilWindow.ShowQueue()
        return
    end
    if (arg or "") == "" then ns.CouncilWindow.ShowQueue(); return end
    local added = 0
    for link in arg:gmatch("|H(item:[^|]+)|h") do
        table.insert(ns.Council.pending, link)
        added = added + 1
    end
    ns.Print(L.LC_ADDED:format(added, #ns.Council.pending))
    ns.Fire("LG_COUNCIL")
    ns.CouncilWindow.ShowQueue()
end

local function cdSettings() return ns.Database.Settings().cd end

-- groups: key, title, module (settings.modules key, optional), commands
-- command: { cmd = "lc test", args = "[...]", desc = "...", run = fn(rest), aliases = { ... } }
local GROUPS = {
    { key = "general", title = "General", commands = {
        { cmd = "", desc = "Open / close the window", run = function() ns.Window.Toggle() end },
        { cmd = "help", args = "[area]", desc = "This help – or one area, e.g. /lg help lc", aliases = { "?" } },
        { cmd = "find", args = "[text]", desc = "Search everything: pages, settings, guide, commands, members, recipes",
          run = function(rest) ns.Window.OpenSearch(rest) end, aliases = { "f" } },
        { cmd = "commands", desc = "Help & commands page in the window",
          run = function() ns.Window.Show("help") end },
        { cmd = "guide", args = "[module]", desc = "Guide: how every module works",
          run = function(rest) ns.Guide.Open(rest) end },
        { cmd = "setup", desc = "Setup assistant: what is still open for this character (professions, main, role …)",
          run = function() ns.Setup.Show() end, aliases = { "assistant" } },
        { cmd = "modules", desc = "Switch modules and cooldown displays on/off",
          run = function() ns.Window.Show("modules") end, aliases = { "module" } },
        { cmd = "notify", desc = "Notification settings",
          run = function() ns.Window.Show("notifications") end },
        { cmd = "config", desc = "Settings", run = function() ns.Window.Show("general") end,
          aliases = { "settings" } },
        { cmd = "look", desc = "Appearance: theme, font, scale",
          run = function() ns.Window.Show("appearance") end },
        { cmd = "tooltips", desc = "Player tooltip lines and their preview",
          run = function() ns.Window.Show("tooltips") end },
        { cmd = "move", desc = "Move elements (cooldown bars, popups) on / off",
          run = function() ns.Window.ToggleMovers() end },
        { cmd = "minimap", desc = "Show / hide the minimap button",
          run = function()
              local m = ns.Database.Settings().minimap
              m.hide = not m.hide
              ns.UI.UpdateMinimap()
          end },
        { cmd = "export", desc = "Export your settings as text",
          run = function() ns.Share.ShowExport() end },
        { cmd = "import", desc = "Import settings from text",
          run = function() ns.Share.ShowImport() end },
        { cmd = "version", desc = "Versions page (who has which version)",
          run = function() ns.Window.Show("versions") end },
        { cmd = "ver", desc = "Version check in your group (chat output)",
          run = function() ns.Versions.CheckGroup() end },
        { cmd = "changelog", desc = "All changes of the addon",
          run = function() ns.WhatsNew.Show(nil, true) end, aliases = { "news" } },
        { cmd = "credits", desc = "Credits: maps, font, licenses",
          run = function() ns.Window.Show("credits") end },
    } },
    { key = "roster", title = "Roster & guild", commands = {
        { cmd = "roster", desc = "Guild roster with gear, enchants and professions",
          run = function() ns.Window.Show("roster") end },
        { cmd = "announce", args = "<text>", desc = "Guild master/officers: pops a notification for everyone in the guild (no text: opens the composer)",
          run = function(rest)
              if (rest or "") == "" then ns.Window.Show("notifications") else ns.Notify.Announce(rest, nil, true) end
          end },
        { cmd = "admin", desc = "Guild admin: officer ranks, loot council setup, craft prefix, who may do what (guild master, officers, council)",
          run = function() ns.Window.Show("admin") end },
        { cmd = "feed", desc = "Guild feed (loot, kills, level-ups …)",
          run = function() ns.Window.Show("feed") end },
        { cmd = "life", desc = "Life statistics window (yours)",
          run = function() ns.LifeStats.Inspect("player") end, aliases = { "irs" } },
        { cmd = "life target", desc = "Life statistics of your target",
          run = function() ns.LifeStats.Inspect("target") end },
        { cmd = "stats", desc = "Statistics: life statistics, guild, addon records",
          run = function() ns.Window.Show("stats") end },
        { cmd = "lfg", args = "[dungeon]", desc = "Dungeon interest: who wants which dungeon (e.g. /lg lfg strat ud)",
          run = function(rest) ns.Dungeons.Open(rest) end, aliases = { "dungeons", "dungeon" } },
    } },
    { key = "lc", title = "Loot Council", module = "council", commands = {
        { cmd = "lc", desc = "Open / close the council window",
          run = function() ns.CouncilWindow.Toggle() end },
        { cmd = "lc add all", desc = "Queue every tradeable loot item from your bags",
          run = function() ns.CouncilQueue.AddAll(); ns.CouncilWindow.ShowQueue() end, aliases = { "bags" } },
        { cmd = "lc queue", desc = "Open the queue (drag items in, Alt-click items)",
          run = function() ns.CouncilWindow.ShowQueue() end, aliases = { "items" } },
        { cmd = "lc add", args = "[item links]",
          desc = "Queue items for the next session (shift-click items into the command)",
          run = lcAdd },
        { cmd = "lc list", desc = "Show queued items",
          run = function()
              ns.Print(("Queued items: %d"):format(#ns.Council.pending))
              for i, s in ipairs(ns.Council.pending) do
                  local info = ns.Items.Info(s)
                  print(("  %d. %s"):format(i, info and info.link or s))
              end
          end },
        { cmd = "lc clear", desc = "Remove all queued items",
          run = function() wipe(ns.Council.pending); ns.Print("Queue cleared.") end },
        { cmd = "lc start", desc = "Start a session with the queued items (loot master)",
          run = function() ns.Council.Start(ns.Council.pending, false) end },
        { cmd = "lc end", desc = "End the running session", run = function() ns.Council.End() end },
        { cmd = "lc test", desc = "Test session with sample items – nothing is really handed out",
          run = function() ns.Council.Test() end },
        { cmd = "lc config", desc = "Council settings: roles, buttons, reasons",
          run = function() ns.Window.Show("council"); if ns.CouncilPage then ns.CouncilPage.ShowSetup() end end },
        { cmd = "lc history", desc = "Loot history",
          run = function() ns.Window.Show("council"); if ns.CouncilPage then ns.CouncilPage.ShowHistory() end end },
        { cmd = "lc export", args = "[rclc|gargul|nota|csv|tsv|discord|bbcode|json]", desc = "Export the loot history (last 30 days, default rclc)",
          run = function(rest)
              local fmt = (rest or ""):lower():match("%a+")
              local known = false
              for _, f in ipairs(ns.Council.EXPORT_FORMATS or {}) do if f == fmt then known = true end end
              if not known then fmt = "rclc" end
              local text, n = ns.Council.HistoryExport(fmt, 30)
              ns.Share.ShowText(L.LC_EXPORT_TITLE:format(n or 0), L.LC_EXPORT_HINT, text)
          end },
        { cmd = "lc share", desc = "Send your loot history to the guild",
          run = function() ns.Council.ShareHistory(30) end },
        { cmd = "lc bar", desc = "Loot master bar on / off",
          run = function() local b = ns.CouncilBar.Settings(); b.enabled = not b.enabled; ns.CouncilBar.Layout() end },
    } },
    { key = "raid", title = "Raid tools", commands = {
        { cmd = "bless", desc = "Blessings: paladin assignments and the blessing bar",
          run = function() ns.Window.Show("blessings") end, aliases = { "blessings" } },
        { cmd = "attune", desc = "Attunements and dungeon keys of the guild",
          run = function() ns.Window.Show("attune") end, aliases = { "keys" } },
    } },
    { key = "cd", title = "Cooldowns", module = "cooldowns", commands = {
        { cmd = "cd", desc = "Cooldown setup", run = function() ns.Window.Show("cooldowns") end,
          aliases = { "cooldowns" } },
        { cmd = "cd preview", desc = "Preview bars on / off (to style them)",
          run = function() ns.Cooldowns.SetPreview(not ns.Cooldowns.IsPreview()) end },
        { cmd = "cd test", desc = "Test bars for 2 minutes", run = function() ns.Cooldowns.Test() end },
        { cmd = "cd lock", desc = "Lock / unlock the bars",
          run = function()
              local s = cdSettings()
              s.locked = not s.locked
              ns.CooldownBars.Layout()
              ns.Print(s.locked and L.CD_NOW_LOCKED or L.CD_NOW_UNLOCKED)
          end },
        { cmd = "cd toggle", desc = "Cooldown bars on / off",
          run = function()
              local s = cdSettings()
              s.enabled = not s.enabled
              ns.CooldownBars.Layout()
          end },
    } },
    { key = "crafts", title = "Professions & crafting", module = "professions", commands = {
        { cmd = "professions", desc = "Professions page (guild crafting, my professions, shopping list, cooldowns)",
          run = function() ns.Window.Show("professions") end, aliases = { "prof", "crafts" } },
        { cmd = "craft", args = "<recipe or item>",
          desc = "Search the guild crafting list",
          run = function(rest) showCraftSearch(rest) end, aliases = { "search" } },
        { cmd = "post", desc = "Posts the last \"!lg\" answer from your chat window to guild chat (also: [Post] in the line)",
          run = function() ns.CraftQuery.PostAnswer() end },
        { cmd = "who", args = "<recipe or item>",
          desc = "Who can craft it? Answer only for you in chat",
          run = function(rest)
              if (rest or "") == "" then ns.Print("Usage: /lg who <recipe>"); return end
              ns.Print(ns.CraftQuery.Reply(rest))
          end },
        { cmd = "price", args = "<recipe or item>",
          desc = "Material cost of a recipe – answer only for you in chat (like !lg price)",
          run = function(rest)
              if (rest or "") == "" then ns.Print("Usage: /lg price <recipe>"); return end
              ns.Print(ns.CraftQuery.Reply("price " .. rest))
          end, aliases = { "cost" } },
        { cmd = "shop", desc = "Your shopping list (Professions › Shopping list)",
          run = function() ns.Window.Show("professions"); ns.Professions.ShowTab("shop") end, aliases = { "shopping", "cart" } },
        { cmd = "shop clear", desc = "Empties your shopping list (and the Auctionator list)",
          run = function() ns.Shopping.Clear() end },
        { cmd = "profcd", desc = "Guild profession cooldowns (Mooncloth, transmutes, salt …)",
          run = function() ns.Window.Show("professions"); ns.Professions.ShowTab("cds") end },
    } },
    { key = "partner", title = "Partner guild", commands = {
        { cmd = "partner", desc = "Who of the partner guild is online (asks /who)",
          run = function() ns.Window.Show("coguild"); ns.CoGuild.Query(true) end, aliases = { "coguild" } },
        { cmd = "bund", args = "[key|newkey]", desc = "Bund channel status; key: show or paste the key; newkey: new key (officers)",
          run = function(rest)
              rest = (rest or ""):lower()
              if rest:find("new") then ns.CoGuild.NewKey()
              elseif rest:find("key") then ns.CoGuild.ShowKey()
              else ns.Print(ns.CoGuild.BundStatus()) end
          end },
    } },
    { key = "community", title = "Community", module = "community", commands = {
        { cmd = "community", desc = "Boards, pin wall and history",
          run = function() ns.Window.Show("community") end },
    } },
    { key = "test", title = "Test everything (alone, nothing is sent)", runnable = true, commands = {
        { cmd = "test", desc = "Notification, feed, pepega death and fail-pull vote one after another",
          run = function() ns.Test.All() end },
        { cmd = "test list", desc = "Lists every test command in the chat (also: Help & commands → Tests)",
          run = function() ns.PrintTests() end },
        { cmd = "test failpull", desc = "Fail-pull vote with made-up raiders (20 s)",
          run = function() ns.Test.FailVote() end },
        { cmd = "test mispull", desc = "How a mispull report looks", run = function() ns.Test.Mispull() end },
        { cmd = "test death", desc = "How a pepega death looks", run = function() ns.Test.Death() end },
        { cmd = "test consum", desc = "Scans your own flask, elixirs and food like at a ready check",
          run = function() ns.Test.Consumables() end },
        { cmd = "test lc", desc = "Loot council session with test raiders", run = function() ns.Test.Council() end },
        { cmd = "test cd", desc = "Cooldown bars with test players (2 min)", run = function() ns.Test.Cooldowns() end },
        { cmd = "test craft", args = "[recipe]", desc = "The answer to a guild chat craft question, only for you",
          run = function(rest) ns.Test.Craft(rest) end },
        { cmd = "test stats", desc = "Reads your life statistics now and opens them", run = function() ns.Test.Life() end },
        { cmd = "test blesslive", desc = "Blessing bar: shows whether the live status strip (drawn by the game, also in combat) is available and active",
          run = function() if ns.BlessNative then ns.Print(ns.BlessNative.Report()) end end },
        { cmd = "test bless", args = "[off]", desc = "Blessings page and bar with made-up paladins and raiders (3 min, nothing is sent or cast)",
          run = function(rest) if (rest or ""):lower():find("off") then ns.Blessings.StopTest() else ns.Blessings.Test() end end },
        { cmd = "test changelog", desc = "The \"what's new\" window with the last versions",
          run = function() ns.WhatsNew.Test() end },
        { cmd = "test tooltip", desc = "Your player tooltip lines at the mouse cursor (8 s)",
          run = function() ns.Tooltips.Test() end },
        { cmd = "test armory", desc = "Prints the raw talent and stat values of your character (armory check)",
          run = function() ns.Test.Armory() end },
        { cmd = "test update", args = "[off]", desc = "How the update notice looks: toast, sidebar chip, Versions card (2 min, nothing sent)",
          run = function(rest) ns.Versions.Test((rest or ""):lower():find("off") ~= nil) end },
        { cmd = "test guide", desc = "Checks every guide entry (page, test, commands) and opens the guide",
          run = function() ns.Guide.Test() end },
        { cmd = "test model", desc = "Race, gender and model mode of the member open in the armory",
          run = function() ns.Armory.ModelReport() end },
        { cmd = "test compare", desc = "Opens the armory compare: first guild member with gear vs. you",
          run = function() ns.Test.Compare() end },
        { cmd = "test attune", desc = "Prints which attunements and keys your addon reads for you and opens the page",
          run = function() ns.Attune.Test() end },
        { cmd = "test lfg", desc = "Dungeon interest with made-up members, roles and overlapping items (3 min, nothing sent or stored)",
          run = function() ns.Dungeons.Test() end },
        { cmd = "test lfgchat", args = "[text]", desc = "Which dungeons the addon reads from a guild chat message – samples or your own text (nothing stored)",
          run = function(rest) ns.Dungeons.TestChat(rest) end },
        { cmd = "test lfgask", args = "[dungeon]", desc = "The \"!lfg\" answer (who wants to go), only for you, and whether your client would answer (nothing sent)",
          run = function(rest) ns.Dungeons.TestAsk(rest) end },
        { cmd = "test lfgdebug", desc = "On/off: every step of a \"!lfg\" question in your chat window – who claims, who answers, why not (only for you)",
          run = function() ns.Dungeons.ToggleDebug() end },
        { cmd = "test search", args = "[text]", desc = "Opens the search with a sample text (default: \"blessing\")",
          run = function(rest) ns.Window.OpenSearch((rest or "") ~= "" and rest or "blessing") end },
        { cmd = "test chat", args = "[reset]", desc = "Why automatic chat lines (craft answers, greetings) may be blocked – combat, restrictions, last block (nothing is sent); reset: answer \"!lg\" again",
          run = function(rest)
              if (rest or ""):find("reset") then ns.blockedAt = nil end
              ns.ChatReport()
          end },
        { cmd = "test offline", desc = "Players skipped for addon whispers because they are offline (no \"No player named\" lines)",
          run = function() ns.Comm.OfflineReport() end },
        { cmd = "test role", desc = "Why your group role is (not) set automatically (nothing is changed)",
          run = function() ns.QoL.Test() end },
        { cmd = "test font", desc = "Shows which font files load (font weight check)",
          run = function() ns.Theme.FontReport() end },
        { cmd = "test toast", desc = "A notification", run = function() ns.Test.Toast() end },
        { cmd = "test notify", args = "[lvl|loot|boss|prof|first|join]",
          desc = "Milestone notifications (level, epic loot, new member)",
          run = function(rest) ns.Notify.Test(rest ~= "" and rest or nil) end },
        { cmd = "test admin", desc = "Guild admin: your role, officer ranks, craft prefix and council setup this client knows (nothing sent)",
          run = function() ns.Admin.Test() end },
        { cmd = "test announce", args = "[text]", desc = "How an officer announcement looks (only for you, nothing sent)",
          run = function(rest) ns.Notify.TestAnnounce(rest) end },
        { cmd = "test quick", args = "[off]", desc = "Sample lines in the quick actions bar (a click only prints, nothing is sent)",
          run = function(rest) if (rest or ""):lower():find("off") then ns.QuickBar.Clear() else ns.QuickBar.Test() end end },
        { cmd = "test messages", desc = "Every message text with sample values (only for you)",
          run = function() ns.Messages.Test() end },
        { cmd = "test feed", desc = "A guild feed notification", run = function() ns.Test.Feed() end },
        { cmd = "test feeddel", desc = "Adds a sample feed entry (only for you) to try deleting it (officers)",
          run = function() ns.Test.FeedDelete() end },
        { cmd = "test shopping", args = "[recipe]", desc = "Shopping list for a known recipe as text (nothing goes to Auctionator or TSM)",
          run = function(rest) ns.Shopping.Test(rest) end },
        { cmd = "test price", args = "<item>", desc = "The \"!lg price\" answer, only for you (nothing sent)",
          run = function(rest) ns.CraftQuery.TestPrice(rest) end },
        { cmd = "test setup", desc = "The setup assistant with every row open (buttons do nothing)",
          run = function() ns.Setup.Show(true) end },
        { cmd = "test lchistory", args = "[off]", desc = "Sample loot history of two raid evenings (only for you, not stored) – try the evening filter and deleting",
          run = function(rest) ns.Council.TestHistory((rest or ""):lower():find("off") ~= nil) end },
        { cmd = "test profsync", desc = "The profession sync hint window and chat lines with sample professions (nothing stored)",
          run = function() ns.ProfSync.Test() end },
        { cmd = "test boards", desc = "Sample entries on all community leaderboards and the quote of the week (2 min, nothing stored or sent)",
          run = function() ns.CommunityFun.Test() end },
        { cmd = "test badge", desc = "The notification for a new badge (nothing stored)", run = function() ns.Badges.Test() end },
        { cmd = "test greet", desc = "Shows the login greeting that would be written to guild chat (nothing sent)",
          run = function() ns.Greet.Test() end },
        { cmd = "test profcd", desc = "Profession cooldowns with sample entries", run = function() ns.Test.ProfCooldowns() end },
        { cmd = "test trade", args = "[raw]", desc = "Trade expiration timers with sample items (1 min); raw: prints the tooltip lines of your bags",
          run = function(rest) if (rest or ""):lower():find("raw") then ns.TradeTimers.Debug() else ns.Test.Trade() end end },
        { cmd = "test who", desc = "Partner /who: which windows listen and what was closed (after the who window popped up)",
          run = function() ns.CoGuild.WhoReport() end },
        { cmd = "test partner", desc = "Partner guild page with sample members",
          run = function() ns.CoGuild.Test(); ns.Window.Show("coguild") end },
        { cmd = "test security", desc = "Runs forged feed, loot history and Bund messages through the checks (nothing stored or sent)",
          run = function() ns.Test.Security() end },
        { cmd = "test bar", desc = "Shows the loot master bar", run = function() ns.Test.Bar() end },
        { cmd = "test move", desc = "Unlock mode for all elements", run = function() ns.Test.Unlock() end },
    } },
    { key = "chat", title = "Chat commands (also without addon)", chat = true, commands = {
        { cmd = "!lg", args = "<recipe or item link>",
          desc = "In guild chat or as a whisper: exactly one addon user answers who can craft it" },
        { cmd = "!lg price", args = "<recipe or item link>",
          desc = "The same with the material cost (also \"cost\" or \"mats\", in front or at the end)" },
        { cmd = "!lfg", args = "[dungeon]",
          desc = "In guild chat or as a whisper: exactly one addon user answers who wants to run it, e.g. \"!lfg ubrs\" – \"!lfg\" alone lists the most wanted dungeons" },
        { cmd = "!lc", desc = "Whisper to the loot master: shows the answer buttons" },
        { cmd = "!lc", args = "<item no.> <button>",
          desc = "Answer for raiders without addon, e.g. \"!lc 1 need\" or \"!lc 2 2\"" },
    } },
}
ns.Commands = GROUPS

local byCommand = {}
local function register(c)
    if c.run then
        byCommand[c.cmd] = c
        for _, a in ipairs(c.aliases or {}) do
            local prefix = c.cmd:match("^(%S+)%s") -- aliases of sub commands keep their group word
            byCommand[prefix and (prefix .. " " .. a) or a] = c
        end
    end
end
for _, g in ipairs(GROUPS) do for _, c in ipairs(g.commands) do register(c) end end
byCommand["irs target"] = byCommand["life target"]

function ns.CommandText(c, group)
    if group and group.chat then return c.cmd .. (c.args and (" " .. c.args) or "") end
    return "/lg" .. (c.cmd ~= "" and (" " .. c.cmd) or "") .. (c.args and (" " .. c.args) or "")
end

local function moduleOff(g)
    return g.module and ns.Database.Settings().modules[g.module] == false
end

local printGroup
function ns.PrintTests()
    for _, g in ipairs(GROUPS) do if g.key == "test" then printGroup(g) end end
end

function printGroup(g)
    local accent = ns.Theme.HexColor("accent", g.title)
    if moduleOff(g) then accent = accent .. ns.Theme.HexColor("muted", "  (module off)") end
    print(accent)
    for _, c in ipairs(g.commands) do
        print(("  %s – %s"):format(ns.Theme.HexColor("text", ns.CommandText(c, g)), c.desc))
    end
end

local function findGroup(name)
    name = (name or ""):lower()
    local alias = { loot = "lc", council = "lc", cooldown = "cd", cooldowns = "cd", prof = "crafts", professions = "crafts",
        craft = "crafts", guild = "roster", bless = "raid", blessings = "raid", attune = "raid", coguild = "partner" }
    name = alias[name] or name
    for _, g in ipairs(GROUPS) do if g.key == name then return g end end
end

local function help(rest)
    local g = findGroup(arg1(rest))
    if g then
        ns.Print("Commands – " .. g.title)
        printGroup(g)
        return
    end
    ns.Print(L.HELP_HEADER)
    for _, c in ipairs(GROUPS[1].commands) do
        print(("  %s – %s"):format(ns.Theme.HexColor("text", ns.CommandText(c)), c.desc))
    end
    local keys = {}
    for i = 2, #GROUPS do keys[#keys + 1] = ns.Theme.HexColor("text", "/lg help " .. GROUPS[i].key) .. " (" .. GROUPS[i].title .. ")" end
    print("  " .. "More: " .. table.concat(keys, ", "))
end
for _, c in ipairs(GROUPS[1].commands) do if c.cmd == "help" then c.run = help; register(c) end end
ns.ShowHelp = help

local function handle(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local first, rest = arg1(msg)
    first = first:lower()
    -- two-word commands ("lc add", "cd test")
    local second, rest2 = arg1(rest)
    local c = byCommand[first .. " " .. second:lower()]
    if c and second ~= "" then ns.Safe(c.run, rest2 or ""); return end
    -- "/lg lc help", "/lg cd ?"
    if (second:lower() == "help" or second == "?") and findGroup(first) then
        help(first); return
    end
    c = byCommand[first]
    if c then ns.Safe(c.run, rest or ""); return end
    ns.Print("Unknown command: " .. msg)
    help()
end
ns.HandleSlash = handle

SLASH_LIEBEGRUESSE1 = "/lg"
SLASH_LIEBEGRUESSE2 = "/liebegruesse"
SlashCmdList.LIEBEGRUESSE = handle
