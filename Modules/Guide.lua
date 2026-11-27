-- "Guide" page: how every module works. Index on the left (search, grouped
-- like the sidebar, on/off dot), one module on the right: what it is, who it
-- is for, how it works in 3–4 steps, where to find it, good to know, what is
-- shared, commands. Help & commands stays the command reference.
local _, ns = ...
local UI, Theme, L = ns.UI, ns.Theme, ns.L

local Guide = {}
ns.Guide = Guide
local state = { key = "start", query = "" }

local SECTIONS = {
    { key = "start", title = "GUIDE_SEC_START" }, { key = "guild", title = "SECTION_GUILD" },
    { key = "raid", title = "SECTION_RAID" }, { key = "forever", title = "SECTION_FOREVER" },
    { key = "me", title = "SECTION_ME" }, { key = "every", title = "GUIDE_SEC_EVERY" },
}

-- where-rows: icon per kind
local WHERE_ICON = { page = "book-open", hud = "move", chat = "message-circle", tip = "message-circle", window = "book-open",
    link = "link", toast = "megaphone", users = "users", timer = "timer", crown = "crown" }

-- the content (English like the rest of the addon). page = window page key,
-- module = settings.modules key (switchable), test = /lg test command
Guide.LIST = {
    { key = "start", section = "start", icon = "compass", name = "Start here", map = "dalaran",
      who = { "Everyone" }, test = "test list",
      sum = "What the addon does, how it talks to other members and how to find your way around.",
      steps = {
          { "Log in", "Your addon reads your own character – gear, talents, professions, attunements – and shares it with guild members who use the addon." },
          { "Open /lg", "Pages are grouped in the sidebar. Search above the pages finds any page, setting, command, member or recipe." },
          { "Hover, then click", "Almost everything explains itself on mouseover. A left click does the action right where you are." },
          { "Try it alone", "Every feature has a test – Settings › Test suite (/lg tests) runs them and switches running ones off. Test data is never sent or saved. /lg setup shows what is still open." },
      },
      where = { { "window", "Window", "/lg or the minimap button" }, { "link", "Search", "Sidebar: everything · page header: only this page" },
          { "hud", "HUD", "Move elements (top bar) – arrow keys move pixel by pixel" },
          { "page", "Modules", "Settings › Modules – switch off what you do not need" } },
      tips = { "Modules are on by default; switching one off only affects you.", "A module's own settings are in its page, tab “Settings” (gear on the Modules page).", "Data of other members is as fresh as their last login with the addon.",
          "Lua error? Copy it completely and send it to the guild lead." },
      shared = "Only data about your own character. Everything from others is checked (sender, time, content) before it is stored.",
      cmds = { "/lg", "/lg find [text]", "/lg setup", "/lg modules", "/lg tests", "/lg test list" } },

    { key = "roster", section = "guild", icon = "users", name = "Roster & Armory", page = "roster",
      who = { "Everyone" }, test = "test compare",
      sum = "Every member with spec, item level, enchants and professions. Click a name to open their Armory.",
      steps = {
          { "Profiles sync", "Each addon user shares their profile on login and whenever something changes." },
          { "Browse the roster", "Sort by any column. Switch between your guild and the partner guild at the top." },
          { "Open the Armory", "Gear around the model, stats, talents with a mini tree on hover, professions, badges and twinks." },
          { "Compare", "Two characters side by side, slot by slot. “Only differences” hides the rest." },
      },
      where = { { "page", "Page", "Guild › Roster" }, { "tip", "Tooltip", "Player tooltips show iLvl, enchants, professions" },
          { "link", "Armory", "‹ › steps through the roster list" } },
      tips = { "The three dots under DATA show whether gear, talents and professions are known.",
          "The real 3D model only works while the member is in sight (group, target, mouseover) – otherwise race, gender and gear.",
          "Missing enchants are marked in red.", "Your own characters are tinted blue; “Filter” narrows by class, rank, profession or your characters." },
      shared = "Your profile (gear, talents, stats, professions, attunements) – to guild members with the addon, only when it changed.",
      cmds = { "/lg roster", "/lg test compare", "/lg test model" } },

    { key = "feed", section = "guild", icon = "newspaper", name = "Guild Feed", page = "feed", module = "feed",
      who = { "Everyone" }, test = "test feed",
      sum = "A live log of what the guild achieves – epic loot, boss kills, level-ups and firsts – with toasts.",
      steps = {
          { "Something happens", "Your addon notices your own loot, kills and level-ups." },
          { "It is shared", "The entry reaches every addon user in the guild. Missed entries are synced at login." },
          { "A toast pops up", "With zone, boss, fight time and the guild members involved. Hover pauses it." },
          { "Look back", "The Guild Feed page lists everything – the buttons above the list show one kind (loot, bosses, levels …); hover an entry for all details." },
      },
      where = { { "page", "Page", "Guild › Guild Feed" }, { "toast", "Toasts", "Top of the screen – movable" },
          { "link", "Sidebar", "Chip “new” when you were away" } },
      tips = { "Boss toasts only for raids – dungeons can be switched on under Notifications.",
          "Officers can delete wrong entries: click an entry › Delete entry.", "Hovering a toast pauses the timer exactly where it was." },
      shared = "Only your own events. Entries of others are checked before they are stored.",
      cmds = { "/lg feed", "/lg test feed", "/lg test toast" } },

    { key = "community", section = "guild", icon = "crown", name = "Community", page = "community", module = "community",
      who = { "Everyone" }, test = "test boards",
      sum = "Pin board, leaderboards, quote of the week and badges – the fun side of the guild.",
      steps = {
          { "Post & like", "Write on the pin board, like the posts of others." },
          { "Counters run by themselves", "Deaths, jumps, repair bills, taxi rides … each addon counts only its own player." },
          { "Leaderboards", "A grid of boards. The “?” on each board explains what is counted." },
          { "Badges", "Bronze, silver and gold. Shown in the Armory; a toast when you earn one." },
      },
      where = { { "page", "Page", "Guild › Community" }, { "users", "Armory", "Badges card" }, { "toast", "Toasts", "Quote of the week, new badges" } },
      tips = { "Quote of the week = most liked post from Monday to Sunday.", "No combat log on Forever – deaths are recognised another way.",
          "After a wipe you can vote for the fail-pull (off by default)." },
      shared = "Your own counters (one entry per day), your posts and likes.",
      cmds = { "/lg community", "/lg test boards", "/lg test badge" } },

    { key = "coguild", section = "guild", icon = "link", name = "Partner guild", page = "coguild",
      who = { "Everyone", "Officers: key" }, test = "test partner",
      sum = "See who in the partner guild is online and which twinks belong to whom.",
      steps = {
          { "A secret key", "The guild master creates a key; officers hand it out automatically." },
          { "Hidden channel", "With the key your addon joins a hidden channel – no chat, only presence." },
          { "Who is online", "The “Partner” chip in the sidebar and the page show who is online." },
          { "Twinks", "Members with characters in both guilds are linked in the Armory." },
      },
      where = { { "page", "Page", "Guild › Partner guild" }, { "link", "Sidebar", "Chip “Partner”" }, { "users", "Roster", "Switch own / partner guild" } },
      tips = { "The partner guild pastes the key once (lock button next to “Sync with addon users”).", "/who only runs when you click.",
          "A new key from the guild master replaces the old one everywhere." },
      shared = "Your online presence in the hidden channel. Nothing else.",
      cmds = { "/lg partner", "/lg bund", "/lg test partner" } },

    { key = "versions", section = "guild", icon = "badge-check", name = "Versions", page = "versions",
      who = { "Everyone" }, test = "test update",
      sum = "Who runs which version of the addon – and a small notice when yours is outdated.",
      steps = {
          { "Versions travel along", "Every addon sends its version with the profile and answers version checks." },
          { "Newer one confirmed", "It counts once an officer or at least two members run it." },
          { "Notice once per login", "A toast and a chat line – then only the chip next to your version and “UPDATE” at Versions." },
          { "Update", "Close the game, replace the folder, start again. What's new shows once afterwards." },
      },
      where = { { "page", "Page", "Guild › Versions" }, { "link", "Sidebar", "Chip next to your version number" },
          { "toast", "Toast", "Once per login when outdated" } },
      tips = { "One row per player: alts are grouped under their main – hover the name to see each character's version.",
          "“Don't remind me” mutes the login notice for that version – the chip stays.", "Outdated versions can miss data from newer ones.",
          "Switch the notice off under Notifications." },
      shared = "Your version number – with your profile and on request.",
      cmds = { "/lg version", "/lg ver", "/lg changelog", "/lg test update" } },

    { key = "admin", section = "guild", icon = "shield", name = "Guild admin", page = "admin",
      who = { "Guild master", "Officers", "Loot council" }, test = "test admin",
      sum = "Guild-wide settings in one place: officer ranks, the loot council setup, the craft prefix – and who may do what.",
      steps = {
          { "Officer ranks", "The guild master switches on which ranks count as officers in the addon." },
          { "Loot council", "Officers and the council change the setup in Loot Council › Settings – it goes to the whole guild by itself." },
          { "Craft prefix", "Officers pick the prefix for craft questions (default “!lg”) – the same for everyone." },
          { "Everyone follows", "Members take it over right away; who was offline gets it at the next login. For everyone else it is read-only." },
      },
      where = { { "page", "Page", "Guild › Guild admin – guild master, officers and loot council only" },
          { "page", "Page", "Loot Council › Settings – shared setup on top" }, { "page", "Page", "Professions › Settings – craft prefix" } },
      tips = { "Read-only settings show a lock – hover them to see who may change them.",
          "The overview at the bottom shows what the guild master, officers and the council may do; your columns are tinted.",
          "Members on older versions keep answering “!lg” until they update." },
      shared = "Officer ranks, craft prefix and the loot council setup – each with who changed it and when.",
      cmds = { "/lg admin", "/lg test admin" } },

    { key = "blessings", section = "raid", icon = "sparkles", name = "Blessings", page = "blessings", module = "blessings",
      who = { "Paladins", "Raid lead" }, test = "test bless",
      sum = "Plan paladin blessings per class, see missing buffs live and cast with one click.",
      steps = {
          { "Plan", "Grid of paladins × classes. “Smart assign” fills everything from what each player plays (talents, group role, class); the mouse wheel changes a blessing." },
          { "Single", "Players who want something else than their class get a single blessing: a feral druid Might among restoration druids. Set by hand on bar, quick window or page – smart assign keeps it." },
          { "Sync", "Assignments sync with other addon users and with PallyPower guests – both ways, as leader also for them." },
          { "Cast", "The bar: a button per class (green / yellow / red), hover pops out its players; “Cast next” = next missing blessing. Quick assign window: /lg assign." },
      },
      where = { { "page", "Page", "Raid tools › Blessings" }, { "hud", "HUD", "Blessing bar (lock button to move it)" },
          { "chat", "Chat", "Announce or whisper the assignments" } },
      tips = { "On first start your own blessings are filled in for you.", "Works solo too – all classes are shown for planning.", "In combat the bar layout freezes so a click always matches its text.",
          "In combat the game hides buffs: counts show the last known state (~), the strip under each row stays live.",
          "Right-click in combat steps through the class and skips dead players.",
          "Mouse wheel on bar or grid cycles the blessing.", "Bar and sync options: tab “Settings” on the Blessings page." },
      shared = "Your assignments – in the raid, PallyPower-compatible.",
      cmds = { "/lg bless", "/lg test bless", "/lg test bless off", "/lg test blesslive", "/lg test blessspec", "/lg test blessspells", "/lg assign", "/lg test blesswindow", "/lg test blesspick", "/lg test blessjoin" } },

    { key = "council", section = "raid", icon = "gem", name = "Loot Council", page = "council", module = "council",
      who = { "Raiders", "Loot master", "Council" }, test = "lc test",
      sum = "Fair loot: raiders answer in a popup, the council votes, the loot master hands out – everything is logged.",
      steps = {
          { "Queue items", "Alt-click items in your bags or drag them into the queue. /lg lc add all takes every tradeable item." },
          { "Start a session", "The loot master starts it; every raider with the addon gets the popup." },
          { "Answer & vote", "Raiders choose their reason; the council sees answers, equipped gear and votes." },
          { "Award", "The item is awarded and written to the history – exportable for the loot page." },
      },
      where = { { "page", "Page", "Raid tools › Loot Council – everyone; members see the history and the council setup read-only" }, { "hud", "HUD", "Loot master bar – only for the actual loot master" },
          { "chat", "Chat", "Raiders without addon: whisper “!lc 1 bis” to the loot master" } },
      tips = { "Normal loot rolls are never touched.", "The trade timer display shows how long items can still be traded.",
          "History: pick one raid evening (or one session) above the list; officers delete entries for the whole guild with a click on an entry.",
          "/lg lc test runs a full session with sample items – nothing is handed out." },
      shared = "Session, answers and votes – in the raid. History to the guild (checked on arrival).",
      cmds = { "/lg lc", "/lg lc add all", "/lg lc start", "/lg lc history", "/lg lc export [rclc|gargul|nota|csv]", "/lg lc test", "/lg test lchistory" } },

    { key = "attune", section = "raid", icon = "shield", name = "Attunements", page = "attune",
      who = { "Everyone", "Raid lead" }, test = "test attune",
      sum = "Who is attuned for Molten Core, Onyxia, Blackwing Lair and Naxxramas – and who carries which dungeon keys.",
      steps = {
          { "Read automatically", "From your quest log and bags, including the bank." },
          { "Shared with your profile", "No extra step – it travels with the roster data." },
          { "Filter", "Search a name, show only level 60, or only members who have both." },
      },
      where = { { "page", "Page", "Raid tools › Attunements" }, { "users", "Armory", "Attunements card" } },
      tips = { "Open your bank once so keys stored there count.", "Members without the addon show no attunements." },
      shared = "Your attunements and keys, as part of your profile.",
      cmds = { "/lg attune", "/lg test attune" } },

    { key = "cooldowns", section = "raid", icon = "timer", name = "Cooldowns", page = "cooldowns", module = "cooldowns",
      who = { "Everyone", "Raid lead" }, test = "test cd",
      sum = "Cooldown bars for your group – raid cooldowns, interrupts or displays you build yourself.",
      steps = {
          { "Create a display", "Bars or icons, your choice of style." },
          { "Pick spells", "Drag & drop between the columns. Conditions decide when it shows (solo, party, raid)." },
          { "Place it", "Move elements, then nudge it with the arrow keys." },
          { "Ask for the real time", "Click a running cooldown – the player's addon answers with the exact time left." },
      },
      where = { { "page", "Page", "Raid tools › Cooldowns" }, { "hud", "HUD", "Your cooldown displays" },
          { "users", "Party frames", "Icons at the party frames – 5-player groups only" } },
      tips = { "“Raid cooldowns” and “Interrupts” are off by default – switch them on under Cooldowns › Displays.",
          "Your addon always sends your own cooldowns to the group, even with the module off – so others can track you.",
          "/lg cd preview shows every display with sample data." },
      shared = "Your own cooldowns when you use them, and which ones you know – to your group.",
      cmds = { "/lg cd", "/lg cd preview", "/lg test cd" } },

    { key = "raidnight", section = "raid", icon = "crown", name = "Fail-pulls & ready checks", page = "community", module = "community",
      who = { "Raiders" }, test = "test failpull",
      sum = "The fun side of a raid night: vote who pulled after a wipe, report mispulls, flasks and food at ready checks.",
      steps = {
          { "Wipe", "Off by default (Notifications). When on, a small square shows up after a wipe – click it to vote who pulled." },
          { "Mispull", "Report a mispull on the Community page – it counts on the board." },
          { "Ready check", "Your addon quietly reads flasks, elixirs and food of the group (outside combat)." },
          { "Boards", "Fail-pulls, mispulls, pepega deaths and flask kings show up on the Community boards." },
      },
      where = { { "toast", "Square", "Fail-pull vote after a wipe – movable with Move elements" }, { "page", "Page", "Guild › Community" },
          { "crown", "Boards", "Fail-pulls, Mispulls, Flask kings" }, { "page", "Settings", "Settings › Notifications › Fail-pull vote" } },
      tips = { "The vote can be switched off under Notifications.", "Nothing is posted in chat – it all stays in the addon." },
      shared = "Your vote, your mispull reports and the ready check result – to the guild.",
      cmds = { "/lg community", "/lg test failpull", "/lg test mispull", "/lg test consum" } },

    { key = "trade", section = "raid", icon = "timer", name = "Trade timers", page = "council",
      who = { "Loot master" }, test = "test trade",
      sum = "Items in your bags that can still be traded, with the time left as a draining bar.",
      steps = {
          { "Loot drops", "Group loot you can still trade shows up in the small list." },
          { "Watch the time", "The bar runs down; 10 minutes before the end you get a warning." },
          { "Act on it", "Click queues the item for the loot council, Shift-click links it, right-click for more." },
      },
      where = { { "hud", "HUD", "Trade timer list – docked to the loot master bar, movable" },
          { "page", "Settings", "Raid tools › Loot Council › Setup" } },
      tips = { "By default only shown while you are the master looter.", "/lg test trade raw prints the tooltip lines of your bags." },
      shared = "Nothing – it only reads your own bags.",
      cmds = { "/lg test trade", "/lg test trade raw", "/lg lc config" } },

    { key = "professions", section = "forever", icon = "hammer", name = "Professions", page = "professions", module = "professions",
      who = { "Everyone" }, test = "test profsync",
      sum = "Who in the guild can craft what, what the materials cost and what you can make yourself.",
      steps = {
          { "Open each profession once", "The sync window guides you – keep the profession window open until it says “synced”." },
          { "Guild crafting", "Search a recipe: crafters, materials and prices. Hover a crafter for details." },
          { "Ask in chat", "“!lg <item>” in guild chat – exactly one addon answers who can craft it. Every answer ends with the material cost; “!lg price <item>” lists the materials too." },
          { "Buy the materials", "Each click on a recipe's cart adds its materials for one craft to your shopping list – Auctionator gets it right away, TradeSkillMaster as a search (cart button at the top)." },
      },
      where = { { "page", "Page", "Professions & world › Professions" }, { "chat", "Chat", "!lg <item or link> – guild chat or whisper" },
          { "shopping-cart", "Shopping list", "Professions › Shopping list – or the cart button at the top" },
          { "timer", "Cooldowns", "Profession cooldowns (transmutes …)" },
          { "zap", "HUD", "Quick actions bar: \"X asked for [Item] – click to post\" (Move elements)" } },
      tips = { "!lg answers only from English clients – that keeps the answer short and single.",
          "Asked by an addon user? The answer shows in the chat window of every addon user (not in guild chat) – “[Post]” behind it or /lg post puts it into guild chat.",
          "Quick actions bar: the same answer as a line – one click posts it. Players without the addon: with \"Ask first\" their answer waits there for a click (the game limits automatic lines).",
          "Shopping list: click the cart twice = materials for two crafts; right-click removes one. Nothing you own is subtracted.",
          "New recipes are synced the next time you open the profession.", "Poisons do not count as a profession." },
      shared = "Your recipes and skill levels.",
      cmds = { "/lg professions", "/lg craft <item>", "/lg shop", "/lg price <item>", "!lg <item>", "!lg price <item>", "/lg post", "/lg test quick", "/lg test shopping", "/lg test price <item>", "/lg test profsync" } },

    { key = "stats", section = "me", icon = "badge-check", name = "Statistics", page = "stats", module = "stats",
      who = { "Everyone" }, test = "test stats",
      sum = "Your life in numbers – combat, dungeons & raids, wealth, professions – and the sheets of others.",
      steps = {
          { "Read after login", "Your statistics are read automatically (not in combat or instances) and shared with the guild." },
          { "Open the window", "/lg life shows your sheet, grouped by topic." },
          { "Compare", "Target someone or open the Guild tab – “Compare with me” puts both side by side." },
      },
      where = { { "page", "Page", "Personal › Statistics" }, { "window", "Window", "Life statistics – also beside Inspect" } },
      tips = { "“Refresh” reads your numbers right now.", "Addon records lists the guild's best values." },
      shared = "Your statistics sheet – to guild members with the addon.",
      cmds = { "/lg life", "/lg life target", "/lg test stats" } },

    { key = "notify", section = "every", icon = "megaphone", name = "Notifications", page = "notifications",
      who = { "Everyone", "Officers: announce" }, test = "test announce",
      sum = "Toasts for guild events – and announcements from officers that reach everyone.",
      steps = {
          { "Choose what matters", "Settings › Notifications: which events, sound and volume." },
          { "Toasts appear", "Hover pauses them, a click opens the details." },
          { "Announcements", "Officers write one message – everyone gets a big toast for 20 s plus a chat line." },
          { "Place them", "Move elements › drag the toast anchor where you like." },
      },
      where = { { "page", "Page", "Settings › Notifications" }, { "toast", "HUD", "Toasts – movable" },
          { "chat", "Chat", "Announcements also as a chat line" } },
      tips = { "Sounds start at 5 % volume.", "/lg announce without text opens the composer.",
          "The texts of congratulations, award announcements and blessing whispers are editable with placeholders like {player}." },
      shared = "Announcements: only from officers, only in the guild.",
      cmds = { "/lg notify", "/lg announce <text>", "/lg test announce", "/lg test messages" } },

    { key = "tooltips", section = "every", icon = "message-circle", name = "Tooltips", page = "tooltips",
      who = { "Everyone" }, test = "test tooltip",
      sum = "Guild info right in the player tooltip: item level, enchants, professions.",
      steps = {
          { "Hover a member", "The tooltip gets extra lines from the roster data." },
          { "Pick the lines", "Settings › Tooltips, with a live preview." },
          { "Keep it clean", "“Only with Shift” shows the lines only while Shift is held." },
      },
      where = { { "page", "Page", "Settings › Tooltips" }, { "tip", "Game", "Every player tooltip" } },
      tips = { "Works for partner guild members too." },
      shared = "Nothing extra – it uses the roster data.",
      cmds = { "/lg tooltips", "/lg test tooltip" } },

    { key = "greet", section = "every", icon = "message-circle", name = "Login greeting", page = "general", module = "greet",
      who = { "Everyone" }, test = "test greet",
      sum = "“glaun hs” when Salty logs in, “marcha hs” for Mar Cha – once a day, from whoever is fastest.",
      steps = {
          { "A member logs in", "The addon sees the online message for the members on the list." },
          { "It greets", "1–4 seconds later in guild chat – once a day, never in combat." },
          { "Fastest greeter", "Counts on its own leaderboard in Community." },
      },
      where = { { "chat", "Chat", "Guild chat" }, { "crown", "Community", "Board “Fastest greeter”" } },
      tips = { "Nobody greets themselves.", "A greeting you type yourself counts too." },
      shared = "Nothing – it is a normal chat line.",
      cmds = { "/lg test greet" } },

    { key = "role", section = "every", icon = "shield", name = "Auto role", page = "general",
      who = { "Everyone" }, test = "test role",
      sum = "Sets your group role (tank, healer, damage) from your talents when you join a group or a role check starts.",
      steps = {
          { "Join a group", "The addon picks the role of the talent tree with the most points." },
          { "Role check", "It answers the role poll for you and closes the popup." },
          { "Your choice", "Settings › General: automatic, a fixed role or off." },
      },
      where = { { "page", "Settings", "Settings › General › Group role" }, { "chat", "Chat", "One line when the role is set" } },
      tips = { "Battlegrounds and arenas are skipped – roles do not count there.", "Changed the role yourself? Auto role pauses (one line in chat) – back after a talent swap, login or /reload, or pick it again in Settings." },
      shared = "Nothing – only your own role in the group.",
      cmds = { "/lg config", "/lg test role" } },

    { key = "look", section = "every", icon = "palette", name = "Appearance & layout", page = "appearance",
      who = { "Everyone" }, test = "test move",
      sum = "Theme, accent colour, font weight, window scale and where every element sits on your screen.",
      steps = {
          { "Pick a look", "Settings › Appearance: theme, accent, font, header maps." },
          { "Place elements", "Move elements (top bar) – drag, arrow keys for single pixels, right-click for options." },
          { "Take it along", "Export your settings as text and import them on another character." },
      },
      where = { { "page", "Settings", "Settings › Appearance" }, { "hud", "HUD", "Move elements – top bar of the window" },
          { "page", "Export", "Settings › General › Import / export" } },
      tips = { "Window opacity and scale also sit in the top bar.", "New fonts or textures need a full game restart, not only /reload." },
      shared = "Nothing – unless you export your settings yourself.",
      cmds = { "/lg look", "/lg move", "/lg export", "/lg import", "/lg minimap" } },
}

local byKey = {}
for i, e in ipairs(Guide.LIST) do e.index = i; byKey[e.key] = e end
Guide.byKey = byKey

local function settings() return ns.Database.Settings() end

-- "on" / "off" (switchable module) or "always"
function Guide.State(e)
    if e.key == "start" then return "info" end
    if not e.module then return "always" end
    return settings().modules[e.module] == false and "off" or "on"
end

local function pageOf(e) return e.page and ns.Window.Page and ns.Window.Page(e.page) end

local function slash(rest)
    if SlashCmdList and SlashCmdList.LIEBEGRUESSE then SlashCmdList.LIEBEGRUESSE(rest) end
end

-- "/lg lc add all" -> runnable without input; "/lg announce <text>" -> chat only
local function runnable(cmd) return cmd:sub(1, 4) == "/lg " and not cmd:find("[<%[]") end
local function toChat(cmd)
    local text = cmd:gsub("%s*[<%[].*$", "")
    if ChatFrame_OpenChat then ChatFrame_OpenChat(text .. ((text ~= cmd) and " " or "")) end
end

local function matches(e, q)
    if q == "" then return true end
    local parts = { e.name, e.sum, e.shared, table.concat(e.cmds, " "), table.concat(e.tips, " ") }
    for _, s in ipairs(e.steps) do parts[#parts + 1] = s[1] .. " " .. s[2] end
    return table.concat(parts, " "):lower():find(q, 1, true) ~= nil
end

function Guide.Open(key)
    key = key and key:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
    if key ~= "" then
        local found = byKey[key]
        if not found then
            for _, e in ipairs(Guide.LIST) do if e.name:lower():find(key, 1, true) or (e.page == key) then found = e; break end end
        end
        if found then state.key = found.key end
    end
    ns.Window.Show("guide")
    if Guide.Fill then Guide.Fill() end
end

function Guide.Select(key)
    if not byKey[key] then return end
    state.key = key
    if Guide.Fill then Guide.Fill(true) end
end

-- the header map follows the module
local function setMap(e)
    local page = ns.Window.Page and ns.Window.Page("guide")
    if not page then return end
    page.map = e.map or (e.page and ns.Window.PAGE_MAPS[e.page]) or "dalaran"
    if ns.Window.UpdateMap then ns.Window.UpdateMap() end
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local function card(parent, title)
    local c = UI.Panel(parent, "panel", "borderDim")
    c.right = UI.Text(c, 10, "muted", "RIGHT")
    c.right:SetPoint("TOPRIGHT", -12, -11)
    c.title = UI.CardTitle(c, title, c.right)
    return c
end

local function diamond(parent, size, color)
    local d = UI.Fill(parent, color or "bronze", "ARTWORK")
    d:SetSize(size, size)
    if d.SetRotation then d:SetRotation(math.rad(45)) end
    return d
end

-- a command as accent chip with run / into-chat buttons
local function cmdChip(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetHeight(24)
    UI.Skin(f, "input", "borderDim")
    f.text = UI.Text(f, 12, "accent", "LEFT")
    f.text:SetPoint("LEFT", 8, 0)
    f.chat = UI.IconButton(f, "message-circle", 22, function() toChat(f.cmd) end)
    f.chat:SetPoint("RIGHT", -1, 0)
    f.chat.tip = L.GUIDE_TO_CHAT
    f.run = UI.IconButton(f, "chevron-right", 22, function() slash(f.cmd:sub(5)) end)
    f.run:SetPoint("RIGHT", f.chat, "LEFT", 0, 0)
    f.run.tip = L.GUIDE_RUN
    function f:Set(cmd)
        self.cmd = cmd
        self.text:SetWidth(0)
        self.text:SetText(cmd)
        local tw = (self.text.GetUnboundedStringWidth and self.text:GetUnboundedStringWidth()) or self.text:GetStringWidth() or 40
        tw = math.max(tw, #cmd * 6.4)
        local canRun = runnable(cmd)
        self.run:SetShown(canRun)
        self.text:SetWidth(tw + 2)
        self:SetWidth(8 + tw + 8 + (canRun and 44 or 22) + 1)
    end
    return f
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
UI.AddPage("guide", L.PAGE_GUIDE, 96, function(content, page)
    -- index (left)
    local index = CreateFrame("Frame", nil, content)
    index:SetPoint("TOPLEFT")
    index:SetPoint("BOTTOMLEFT")
    -- the search sits in the page header
    page.searchHint = L.GUIDE_SEARCH
    page.searchRow = true
    page.Search = function(text)
        state.query = (text or ""):lower()
        Guide.FillIndex()
        -- jump to the first match, so the right side follows the search
        if state.query ~= "" then
            local cur = byKey[state.key]
            if not (cur and matches(cur, state.query)) then
                for _, sec in ipairs(SECTIONS) do
                    for _, e in ipairs(Guide.LIST) do
                        if e.section == sec.key and matches(e, state.query) then Guide.Select(e.key); return Guide.hits end
                    end
                end
            end
        end
        return Guide.hits
    end
    local legend = UI.Text(index, 10, "muted", "LEFT")
    legend:SetPoint("BOTTOMLEFT", 2, 0)
    legend:SetPoint("BOTTOMRIGHT", -2, 0)
    legend:SetText(UI.Glyph("dot", "good", 8) .. " " .. L.GUIDE_ON .. "   " .. UI.Glyph("dot", "borderDim", 8) .. " " .. L.GUIDE_OFF
        .. "   " .. UI.Glyph("ring", "muted", 8) .. " " .. L.GUIDE_ALWAYS)
    local box = UI.Panel(index, "bg", "borderDim")
    box:SetPoint("TOPLEFT", index, "TOPLEFT", 0, 0)
    box:SetPoint("BOTTOMRIGHT", index, "BOTTOMRIGHT", 0, 18)
    local iscroll, ibody = UI.ScrollArea(box)
    iscroll:SetPoint("TOPLEFT", 0, -4)
    iscroll:SetPoint("BOTTOMRIGHT", 0, 4)
    local heads, rows = {}, {}
    local function head(i)
        if heads[i] then return heads[i] end
        local h = CreateFrame("Frame", nil, ibody)
        h:SetHeight(24)
        h.d = diamond(h, 5)
        h.d:SetPoint("LEFT", 13, -3)
        h.text = UI.Text(h, 11, "bronze", "LEFT", nil, true)
        h.text:SetPoint("LEFT", 24, -3)
        h.rule = UI.Fill(h, "bronzeDim", "ARTWORK")
        h.rule:SetHeight(1)
        h.rule:SetPoint("LEFT", h.text, "RIGHT", 8, 0)
        h.rule:SetPoint("RIGHT", h, "RIGHT", -10, -3)
        heads[i] = h
        return h
    end
    local function row(i)
        if rows[i] then return rows[i] end
        local r = CreateFrame("Button", nil, ibody)
        r:SetHeight(27)
        r.sel = UI.Fill(r, "selected")
        r.sel:SetAllPoints()
        r.bar = UI.Fill(r, "accent", "ARTWORK")
        r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(2)
        r.hl = UI.Fill(r, "hover", "HIGHLIGHT")
        r.hl:SetAllPoints()
        r.icon = UI.Icon(r, "dot", 14, "muted")
        r.icon:SetPoint("LEFT", 14, 0)
        r.dot = UI.Icon(r, "dot", 8, "good")
        r.dot:SetPoint("RIGHT", -10, 0)
        r.text = UI.Text(r, 13, "textDim", "LEFT")
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 9, 0)
        r:SetScript("OnClick", function(self) Guide.Select(self.key) end)
        r:SetScript("OnEnter", function(self)
            local e = byKey[self.key]
            if e then UI.Tooltip(self, e.name, { e.sum }) end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = r
        return r
    end

    function Guide.FillIndex()
        local W = (iscroll:GetWidth() or 200)
        local q = state.query
        local y, nh, nr = 0, 0, 0
        Guide.hits = 0
        for _, sec in ipairs(SECTIONS) do
            local list = {}
            for _, e in ipairs(Guide.LIST) do if e.section == sec.key then list[#list + 1] = e end end
            if #list > 0 then
                nh = nh + 1
                local h = head(nh)
                h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y); h:SetWidth(W)
                h.text:SetText(ns.Upper(L[sec.title]))
                h:Show()
                y = y + 24
                for _, e in ipairs(list) do
                    nr = nr + 1
                    local r = row(nr)
                    r.key = e.key
                    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetWidth(W)
                    local on = e.key == state.key
                    r.sel:SetShown(on); r.bar:SetShown(on)
                    Theme.SetIcon(r.icon, e.icon)
                    r.icon:SetVertexColor(Theme.Color(on and "accent" or "muted"))
                    r.text:SetTextColor(Theme.Color(on and "text" or "textDim"))
                    r.text:SetWidth(math.max(40, W - 14 - 14 - 9 - 24))
                    r.text:SetText(ns.Highlight(e.name, q))
                    -- search hit: accent bar and tint (all topics stay listed)
                    local hit = q ~= "" and matches(e, q)
                    if not r.hitBg then
                        r.hitBg = UI.Fill(r, "accent", "BORDER"); r.hitBg:SetAllPoints(); r.hitBg:SetAlpha(0.12)
                        r.hitBar = UI.Fill(r, "accent", "OVERLAY"); r.hitBar:SetPoint("TOPRIGHT"); r.hitBar:SetPoint("BOTTOMRIGHT"); r.hitBar:SetWidth(3)
                    end
                    r.hitBg:SetShown(hit and not on); r.hitBar:SetShown(hit and true or false)
                    if hit then Guide.hits = Guide.hits + 1 end
                    local st = Guide.State(e)
                    r.dot:SetShown(st ~= "info")
                    Theme.SetIcon(r.dot, st == "always" and "ring" or "dot")
                    r.dot:SetVertexColor(Theme.Color(st == "on" and "good" or st == "off" and "borderDim" or "muted"))
                    r:Show()
                    y = y + 27
                end
                y = y + 2
            end
        end
        for i = nh + 1, #heads do heads[i]:Hide() end
        for i = nr + 1, #rows do rows[i]:Hide() end
        if not ibody.empty then
            ibody.empty = UI.Empty(ibody, 180)
            ibody.empty:SetPoint("TOP", 0, -16)
        end
        ibody.empty:SetTextWidth(math.max(80, W - 24))
        ibody.empty:SetShown(nr == 0)
        if nr == 0 then ibody.empty:Set("search", L.GUIDE_NOTHING) end
        ibody:SetHeight(math.max(nr == 0 and 140 or 40, y + 4))
        iscroll.UpdateBar()
    end

    -- detail (right)
    local scroll, body = UI.ScrollArea(content)
    scroll:SetPoint("TOPLEFT", index, "TOPRIGHT", 14, 0)
    scroll:SetPoint("BOTTOMRIGHT", -8, 0)

    -- hero card
    local hero = UI.Panel(body, "panel", "borderDim")
    UI.Corners(hero)
    hero.badge = UI.Panel(hero, "input", "bronzeDim")
    hero.badge:SetSize(56, 56)
    hero.badge:SetPoint("TOPLEFT", 16, -16)
    hero.icon = UI.Icon(hero.badge, "dot", 28, "bronze")
    hero.icon:SetPoint("CENTER")
    hero.kicker = UI.Text(hero, 11, "accent", "LEFT", nil, true)
    hero.title = UI.Text(hero, 24, "text", "LEFT", nil, true)
    hero.sum = UI.Text(hero, 13, "textDim", "LEFT")
    hero.sum:SetWordWrap(true)
    hero.sum:SetJustifyV("TOP")
    hero.who = UI.Text(hero, 11, "textDim", "LEFT")
    hero.open = UI.Button(hero, "", 150, 26, function()
        local e = byKey[state.key]
        if e and e.page then ns.Window.Show(e.page) end
    end, "chevron-right")
    hero.try = UI.Button(hero, L.GUIDE_TRY, 150, 26, function()
        local e = byKey[state.key]
        if e and e.test then slash(e.test) end
    end, "sparkles")
    hero.module = UI.Check(hero, L.GUIDE_MODULE, function()
        local e = byKey[state.key]
        return e and e.module and settings().modules[e.module] ~= false
    end, function(v)
        local e = byKey[state.key]
        if not e or not e.module then return end
        settings().modules[e.module] = v
        ns.Window.BuildNav()
        ns.Fire("LG_COOLDOWNS")
        ns.Fire("LG_MODULES")
        Guide.Fill()
    end, L.GUIDE_MODULE_TIP)

    -- steps
    local stepsCard = card(body, L.GUIDE_HOW)
    stepsCard.steps = {}
    for i = 1, 4 do
        local s = {}
        s.d = diamond(stepsCard, 15)
        s.num = UI.Text(stepsCard, 12, "bg", "CENTER", nil, true)
        s.num:SetPoint("CENTER", s.d, "CENTER", 0, 0)
        s.num:SetText(tostring(i))
        s.title = UI.Text(stepsCard, 15, "text", "LEFT", nil, true)
        s.title:SetWordWrap(true)
        s.text = UI.Text(stepsCard, 12, "textDim", "LEFT")
        s.text:SetWordWrap(true)
        s.text:SetJustifyV("TOP")
        s.sep = UI.Fill(stepsCard, "borderDim", "ARTWORK")
        s.sep:SetWidth(1)
        stepsCard.steps[i] = s
    end

    -- where / shared / tips / commands
    local whereCard = card(body, L.GUIDE_WHERE)
    whereCard.rows = {}
    for i = 1, 4 do
        local r = {}
        r.icon = UI.Icon(whereCard, "dot", 14, "bronze")
        r.k = UI.Text(whereCard, 12, "muted", "LEFT")
        r.v = UI.Text(whereCard, 13, "text", "LEFT")
        r.v:SetWordWrap(true)
        r.v:SetJustifyV("TOP")
        r.line = UI.Fill(whereCard, "borderDim", "ARTWORK")
        r.line:SetHeight(1)
        whereCard.rows[i] = r
    end
    local sharedCard = card(body, L.GUIDE_SHARED)
    sharedCard.lock = UI.Panel(sharedCard, "input", "borderDim")
    sharedCard.lock:SetSize(26, 26)
    sharedCard.lockIcon = UI.Icon(sharedCard.lock, "link", 13, "lapis")
    sharedCard.lockIcon:SetPoint("CENTER")
    sharedCard.text = UI.Text(sharedCard, 12, "textDim", "LEFT")
    sharedCard.text:SetWordWrap(true)
    sharedCard.text:SetJustifyV("TOP")
    local tipsCard = card(body, L.GUIDE_TIPS)
    tipsCard.lines = {}
    for i = 1, 4 do
        local d = diamond(tipsCard, 4)
        local t = UI.Text(tipsCard, 12, "textDim", "LEFT")
        t:SetWordWrap(true)
        t:SetJustifyV("TOP")
        tipsCard.lines[i] = { dot = d, text = t }
    end
    local cmdCard = card(body, L.GUIDE_CMDS)
    cmdCard.right:SetText(L.GUIDE_CMDS_HINT)
    cmdCard.chips = {}

    -- prev / next
    local prev = UI.Button(body, "", 160, 26, function()
        local e = byKey[state.key]; local n = #Guide.LIST
        Guide.Select(Guide.LIST[((e.index - 2) % n) + 1].key)
    end, "chevron-right")
    if prev.icon then prev.icon:SetTexCoord(1, 0, 0, 1) end   -- mirrored: points left
    local nextB = UI.Button(body, "", 160, 26, function()
        local e = byKey[state.key]; local n = #Guide.LIST
        Guide.Select(Guide.LIST[(e.index % n) + 1].key)
    end, "chevron-right")
    local pos = UI.Text(body, 11, "muted", "LEFT")

    local function textAt(fs, parent, x, y, w)
        fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y); fs:SetWidth(math.max(20, w))
        return math.max(13, fs:GetStringHeight() or 14)
    end

    function Guide.Fill(top)
        local e = byKey[state.key] or Guide.LIST[1]
        state.key = e.key
        -- index width: narrower in small windows
        local CW = content:GetWidth() or 1000
        index:SetWidth(CW < 900 and 180 or 212)
        Guide.FillIndex()
        setMap(e)
        local W = math.max(360, (scroll:GetWidth() or 760) - 4)
        local st = Guide.State(e)

        -- hero
        local actW = W < 560 and 0 or 150
        local tx = 16 + 56 + 16
        local tw = W - tx - 16 - (actW > 0 and (actW + 16) or 0)
        Theme.SetIcon(hero.icon, e.icon)
        local sec
        for _, s in ipairs(SECTIONS) do if s.key == e.section then sec = s end end
        hero.kicker:SetText(ns.Upper(L[sec.title]) .. (e.key ~= "start" and (" · " .. L.GUIDE_KICKER_MODULE) or ""))
        local hy = 16
        hy = hy + textAt(hero.kicker, hero, tx, hy, tw) + 2
        hy = hy + textAt(hero.title, hero, tx, hy, tw) + 4
        hero.title:SetText(e.name)
        hero.sum:SetText(e.sum)
        hy = hy + textAt(hero.sum, hero, tx, hy, tw) + 8
        local who = {}
        for _, w in ipairs(e.who or {}) do who[#who + 1] = UI.Glyph("users", "muted", 11) .. " " .. w end
        if st == "on" then who[#who + 1] = Theme.HexColor("good", L.GUIDE_MOD_ON)
        elseif st == "off" then who[#who + 1] = Theme.HexColor("muted", L.GUIDE_MOD_OFF)
        elseif st == "always" then who[#who + 1] = Theme.HexColor("lapis", L.GUIDE_MOD_ALWAYS) end
        hero.who:SetText(table.concat(who, Theme.HexColor("borderDim", "   |   ")))
        hy = hy + textAt(hero.who, hero, tx, hy, tw) + 14
        -- actions: right column, or below the text when narrow
        local p = e.page and ns.Window.Page and ns.Window.Page(e.page)
        hero.open:SetShown(e.page ~= nil)
        hero.open:SetText(L.GUIDE_OPEN:format(p and p.title or e.name))
        local visible = p and ns.Window.PageVisible(p)
        hero.open:SetEnabled(visible and true or false)
        hero.open.tip = (not visible) and { L.GUIDE_OPEN_OFF } or nil
        hero.try:SetShown(e.test ~= nil)
        hero.try.tip = e.test and { L.GUIDE_TRY_TIP:format("/lg " .. e.test) } or nil
        hero.module:SetShown(e.module ~= nil)
        hero.module:Refresh()
        local buttons = {}
        if e.page then buttons[#buttons + 1] = hero.open end
        if e.test then buttons[#buttons + 1] = hero.try end
        if actW > 0 then
            local by = 16
            for _, b in ipairs(buttons) do
                b:ClearAllPoints(); b:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -16, -by); b:SetWidth(actW); by = by + 32
            end
            hero.module:ClearAllPoints(); hero.module:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -16 - (actW - hero.module:GetWidth()), -by - 3)
            if e.module then by = by + 26 end
            hy = math.max(hy, by + 10, 16 + 56 + 16)
        else
            local bx = tx
            for _, b in ipairs(buttons) do
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", hero, "TOPLEFT", bx, -hy); b:SetWidth(140); bx = bx + 146
            end
            hero.module:ClearAllPoints(); hero.module:SetPoint("TOPLEFT", hero, "TOPLEFT", tx, -(hy + ((#buttons > 0) and 32 or 0)) - 3)
            hy = hy + ((#buttons > 0) and 32 or 0) + (e.module and 26 or 0) + 8
            hy = math.max(hy, 16 + 56 + 16)
        end
        hero:ClearAllPoints(); hero:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
        hero:SetSize(W, hy)
        local y = hy + 12

        -- steps: one row, 2×2 when narrow
        local n = #e.steps
        stepsCard.right:SetText(L.GUIDE_STEPS:format(n))
        local perRow = (W >= 700) and n or 2
        local inner = W - 28
        local colW = math.floor((inner - (perRow - 1) * 28) / perRow)
        local sy, rowH, rowTop = 40, 0, 40
        for i = 1, 4 do
            local s = stepsCard.steps[i]
            local data = e.steps[i]
            local show = data ~= nil
            s.d:SetShown(show); s.num:SetShown(show); s.title:SetShown(show); s.text:SetShown(show); s.sep:Hide()
            if show then
                local col = (i - 1) % perRow
                if col == 0 and i > 1 then rowTop = rowTop + rowH + 14; rowH = 0 end
                local x = 14 + col * (colW + 28)
                s.d:ClearAllPoints(); s.d:SetPoint("TOPLEFT", stepsCard, "TOPLEFT", x + 3, -(rowTop + 3))
                s.title:SetText(data[1])
                local th = textAt(s.title, stepsCard, x + 28, rowTop, colW - 28)
                s.text:SetText(data[2])
                local bh = textAt(s.text, stepsCard, x, rowTop + math.max(th, 20) + 6, colW)
                rowH = math.max(rowH, math.max(th, 20) + 6 + bh)
                if col > 0 then
                    s.sep:ClearAllPoints()
                    s.sep:SetPoint("TOPLEFT", stepsCard, "TOPLEFT", x - 14, -rowTop)
                    s.sep.row = rowTop
                    s.sep:Show()
                end
            end
        end
        for i = 1, n do
            local s = stepsCard.steps[i]
            if s.sep:IsShown() then s.sep:SetHeight(rowH) end
        end
        sy = rowTop + rowH + 14
        stepsCard:ClearAllPoints(); stepsCard:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        stepsCard:SetSize(W, sy)
        y = y + sy + 12

        -- two columns (one when narrow)
        local two = W >= 640
        local lw = two and math.floor((W - 12) * 0.52) or W
        local rw = two and (W - 12 - lw) or W
        local ly, ry = y, two and y or 0
        local function place(c, x, cy, w, h) c:ClearAllPoints(); c:SetPoint("TOPLEFT", body, "TOPLEFT", x, -cy); c:SetSize(w, h) end

        -- where
        local wy = 40
        for i = 1, 4 do
            local r, d = whereCard.rows[i], e.where[i]
            local show = d ~= nil
            r.icon:SetShown(show); r.k:SetShown(show); r.v:SetShown(show); r.line:SetShown(show and i > 1)
            if show then
                if i > 1 then
                    r.line:ClearAllPoints(); r.line:SetPoint("TOPLEFT", whereCard, "TOPLEFT", 14, -(wy - 4))
                    r.line:SetWidth(lw - 28)
                    wy = wy + 4
                end
                Theme.SetIcon(r.icon, WHERE_ICON[d[1]] or "dot")
                r.icon:ClearAllPoints(); r.icon:SetPoint("TOPLEFT", whereCard, "TOPLEFT", 14, -(wy + 1))
                r.k:SetText(d[2]); textAt(r.k, whereCard, 36, wy + 1, 76)
                r.v:SetText(d[3])
                wy = wy + textAt(r.v, whereCard, 118, wy, lw - 118 - 14) + 8
            end
        end
        place(whereCard, 0, ly, lw, wy + 4)
        ly = ly + wy + 4 + 12

        -- shared
        sharedCard.text:SetText(e.shared)
        sharedCard.lock:ClearAllPoints(); sharedCard.lock:SetPoint("TOPLEFT", 14, -40)
        local shh = textAt(sharedCard.text, sharedCard, 50, 42, lw - 50 - 14)
        place(sharedCard, 0, ly, lw, 40 + math.max(26, shh + 2) + 14)
        ly = ly + 40 + math.max(26, shh + 2) + 14 + 12

        -- tips
        local rx = two and (lw + 12) or 0
        if not two then ry = ly end
        local ty = 40
        for i = 1, 4 do
            local l, t = tipsCard.lines[i], e.tips[i]
            l.dot:SetShown(t ~= nil); l.text:SetShown(t ~= nil)
            if t then
                l.dot:ClearAllPoints(); l.dot:SetPoint("TOPLEFT", tipsCard, "TOPLEFT", 16, -(ty + 6))
                l.text:SetText(t)
                ty = ty + textAt(l.text, tipsCard, 28, ty, rw - 28 - 14) + 7
            end
        end
        place(tipsCard, rx, ry, rw, ty + 7)
        ry = ry + ty + 7 + 12

        -- commands: chips wrap
        local cx, cy = 14, 40
        for i, cmd in ipairs(e.cmds) do
            local chip = cmdCard.chips[i]
            if not chip then chip = cmdChip(cmdCard); cmdCard.chips[i] = chip end
            chip:Set(cmd)
            local w = chip:GetWidth()
            if cx > 14 and cx + w > rw - 14 then cx = 14; cy = cy + 30 end
            chip:ClearAllPoints(); chip:SetPoint("TOPLEFT", cmdCard, "TOPLEFT", cx, -cy)
            chip:Show()
            cx = cx + w + 6
        end
        for i = #e.cmds + 1, #cmdCard.chips do cmdCard.chips[i]:Hide() end
        place(cmdCard, rx, ry, rw, cy + 24 + 14)
        ry = ry + cy + 24 + 14 + 12

        -- prev / next
        y = math.max(ly, ry) + 2
        local n2 = #Guide.LIST
        local pe, ne = Guide.LIST[((e.index - 2) % n2) + 1], Guide.LIST[(e.index % n2) + 1]
        prev:SetText(pe.name); nextB:SetText(ne.name)
        nextB:ClearAllPoints(); nextB:SetPoint("TOPRIGHT", body, "TOPLEFT", W, -y)
        prev:ClearAllPoints(); prev:SetPoint("RIGHT", nextB, "LEFT", -8, 0)
        pos:ClearAllPoints(); pos:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -(y + 7))
        pos:SetWidth(math.max(40, W - 340))
        pos:SetText(L.GUIDE_POS:format(e.index, n2))
        body:SetHeight(y + 26 + 8)
        if top then scroll:SetVerticalScroll(0) end
        scroll.UpdateBar()
    end

    scroll:HookScript("OnSizeChanged", function() ns.Debounce("guide-layout", 0.05, Guide.Fill) end)
    page.OnShow = function()
        -- the NEW badge in the sidebar goes away once the page was opened
        if not settings().guideSeen then
            settings().guideSeen = true
            ns.Window.BuildNav()
        end
        Guide.Fill(true)
    end
end, { section = "settings", icon = "compass", badge = function()
    return not ns.Database.Settings().guideSeen and L.GUIDE_NEW or nil
end })

ns.On("LG_MODULES", function()
    if Guide.Fill and ns.Window.IsShown and ns.Window.IsShown("guide") then Guide.Fill() end
end)

-- /lg test guide: every entry points to an existing page, test and command
function Guide.Test()
    local known = {}
    for _, g in ipairs(ns.Commands or {}) do
        for _, c in ipairs(g.commands) do known[c.cmd] = true end
    end
    local bad = 0
    for _, e in ipairs(Guide.LIST) do
        local problems = {}
        if e.page and not (ns.Window.Page and ns.Window.Page(e.page)) then problems[#problems + 1] = "page " .. e.page end
        if e.test and not known[e.test] then problems[#problems + 1] = "test " .. e.test end
        for _, c in ipairs(e.cmds) do
            if c:sub(1, 3) == "/lg" then
                -- a known command, maybe with arguments ("test bless off")
                local rest, ok = c:sub(5):gsub("%s*[<%[].*$", ""), false
                while true do
                    if known[rest] then ok = true; break end
                    local shorter = rest:match("^(.*)%s+%S+$")
                    if not shorter then break end
                    rest = shorter
                end
                if not ok then problems[#problems + 1] = c end
            end
        end
        if #e.steps < 3 or #e.steps > 4 then problems[#problems + 1] = "steps" end
        if #problems > 0 then
            bad = bad + 1
            ns.Print(L.TEST_TAG .. " " .. e.name .. ": " .. table.concat(problems, ", "))
        end
    end
    ns.Print(L.TEST_TAG .. " " .. L.GUIDE_TEST_RESULT:format(#Guide.LIST, bad))
    Guide.Open()
    return bad
end
