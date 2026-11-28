# Changelog

All notable changes to Liebe Grüße – Guild Tools. Newest first.

## [1.0.90] – 2026-11-28

- feat(runs): new page Speedruns (Raid tools) – dungeon and raid runs from the first pull to the end boss, with splits, deaths and an optional death penalty
- feat(runs): run timer on screen with splits against your best run or the guild record (green ahead, red behind); movable, lock, scale, only the time in combat
- feat(runs): wings count on their own (Scarlet Monastery, Dire Maul, Maraudon, Stratholme, Blackrock Spire); end bosses learned by encounter ID
- feat(runs): guild records and personal bests shared with the guild – checked first (known instance, end boss killed, realistic time, group size, splits in order, sender in the group)
- feat(runs): share every record in guild or party chat, or copy it for Discord
- feat(runs): boss stats – pulls, wipes, kill rate, fastest kill and first-try kills per boss
- feat(community): raid night boards count only inside raid instances with a guild raid; boards grouped into Raid night and Around Azeroth, each with its counting rule
- feat(community): new raid night boards – first to die, last one standing, not ready, chatterbox, roll king, snake eyes, emote spammer, chugger; flask champion and forgot food are back
- feat(community): Tonight's awards after a raid night – toast, card on the page, one click posts them to the guild
- fix(community): jumps count only real jumps inside the raid (no presses in mid-air, swimming, in cities); AFK only inside the raid instance
- fix(community): pepega deaths only in boss kills and only for players alive at the pull – ghosts and feigning hunters no longer count
- fix(community): interrupts count only when the target was casting
- feat(achievements): new page Achievements (Personal) – dungeon, open world and raid with progress bars, counters, tier badges and unlock dates; guild overview of who has which tier
- feat(achievements): new achievements for speedruns, first-try and deathless kills, full clears, attunements, quests, zones, rares, professions and the new raid night boards
- feat(bugs): errors of this addon are caught and grouped; a small "Report bug" button opens the report (stack, count, what you were doing)
- feat(bugs): reports go to the guild master and officers; nobody online – they wait and go out when an officer logs in
- feat(bugs): bug inbox for officers in Guild admin – new / seen / solved, stack to copy, delete all
- feat(notify): notification history with a movable bell and unread count – mark all read, clear
- feat(versions): officers remind members with an older version – guild-wide (cooldown) or one player, at most once a day
- feat(ui): copy boxes open with the text selected – press Ctrl+C
- change(community): the badges tab moved to Achievements › Guild overview
- feat(runs): bosses of every dungeon from the client data of WoW Forever – instance IDs, encounter IDs, NPC IDs and German names, incl. the new Forever dungeons; no more guessed end bosses (Maraudon is one run)
- feat(runs): bosses without an encounter count when seen dead (target, boss frames, loot) – only during a run
- change(runs): records only accept bosses of their own wing; splits use the same boss names on every client
- change(runs): the run timer is off by default (Speedruns › Settings)
- feat(versions): CurseForge – "Copy download link" on the update card, /lg download; update texts point to the CurseForge app
- feat(ui): every window has a cross – also toasts, the blessing bar, the loot master bar, the run timer, the bell and the fail-pull square
- feat(tests): a small popup shows running tests with "Stop tests" – no /reload needed
- perf(community): raid night counting asks the group at most every 2 s; the death watch runs only in a raid night or a speedrun
- perf(achievements): checked at most every 30 s and never in combat; own stats cached
- perf(community): interrupts read only the target's casts (unit events)
- fix(raid): raids count only in real raid instances – ten-player dungeons in a raid group (Upper Blackrock Spire) are dungeons again for raid night boards, awards, achievements, boss stats, the fail-pull vote and boss notifications
- fix(achievements): raid data recorded in dungeons before this fix no longer counts; raid achievements start fresh
- feat(community): Pepega around Azeroth – own deaths in the open world (falls and drowning shown apart) next to the raid Pepega deaths
- change(community): spirit healer regulars, guard victims and auction house shark removed (boards, achievements and counting)
- feat(achievements): eight tiers – bronze, silver, gold, platinum, emerald, diamond, master and challenger
- feat(achievements): new Pepega around Azeroth and Gravity Tester; Master Crafter counts profession skill points
- change(achievements): guild overview reworked – member ranking by tier points with the selected member's badges, or every achievement with its holders and highest tier; category filter
- feat(notify): congratulations and welcomes can be sent once from the notification history – only when not answered on the toast and only for what happened while you were online

## [1.0.89] – 2026-11-27

- change(blessings): smart assign gives every class its own blessing first (Might or Wisdom) and Kings second – one paladin = Might / Wisdom only, two = plus Kings from the one who knows it
- change(blessings): hunters want Wisdom first, survival hunters (melee) Might; protection paladins and shaman tanks Kings, Wisdom, Might
- fix(blessings): smart assign never gives a class the same blessing from two paladins; singles only for players who want something else than their class (feral druid, retribution paladin), no more swapped singles; running it twice changes nothing
- feat(blessings): paladins without any addon – what they bless is read from the buffs on the players, smart assign plans them too (no Kings without 10 Protection points) and whispers them their part after combat (option "Whisper paladins without the addon")
- change(blessings): mouse wheel skips a blessing another paladin already gives that class; picking it in a menu swaps the two
- feat(blessings): compact view of the bar – half as wide, class and blessing icons with counts; toggle next to the lock or in Blessings › Settings
- change(blessings): aura, seal, Righteous Fury and Oath of Light are small icons in one row on the bar – green border while on, red while off; each one can be switched off, the row disappears without any
- fix(blessings): announce, whisper and test lines without arrows or dashes (other players saw odd characters); class names in class colors in your own chat
- feat(quickbar): wider by default (380 px, larger text) – saved positions stay where they were
- feat(quickbar): choose where lines open – toward the middle of the screen (default), down, up, left or right
- feat(quickbar): display style icon + text, text only or icons only; width, spacing, scale and max lines in Settings
- feat(quickbar): order newest/oldest first; time line, × button and "+n more" can be hidden
- feat(quickbar): choose whether guild and whispered "!lg" questions wait in the bar or are answered by the addon
- feat(quickbar): width slider in the Move elements editor; /lg test quicklayout
- fix(cooldowns): keep players' bars and cooldowns when the roster briefly shows "Unknown" or someone leaves and rejoins
- fix(cooldowns): don't drop cooldown lists from players who are not in the roster yet
- fix(cooldowns): spells seen cast stay known when another addon's list lacks them
- fix(cooldowns): re-ask new group members for their cooldowns instead of dropping throttled requests
- fix(cooldowns): throttle instead of debounce, so bars update during busy raids
- fix(cooldowns): track addon users' casts while the game holds back addon messages in boss fights
- fix(cooldowns): restore running cooldowns and seen spells after /reload, also for players who load in later
- fix(cooldowns): match party-frame icons by GUID and retry when frames appear late
- perf(cooldowns): casts of group members cost one table lookup – the spell of an unknown id is looked up once, not on every cast
- feat(tests): new Test suite page (Settings › Test suite, /lg tests) – every test grouped by module, with Run buttons, search and "Stop all tests"
- feat(tests): tests that keep running (blessings, cooldown bars, update notice, quick actions, loot history, council session, loot master bar, boards, trade timers, partner, move elements) get a switch that shows whether they are running and turns them off
- feat(tests): /lg test blesssmart, /lg test blesscompact
- change(help): test commands moved out of Help & commands into the Test suite; the support card opens it
- fix(help): stale texts (support hint, /lg test list, test bar/move descriptions) and unused locale keys removed
- fix(partner): /lg test partner sample members can be removed again (test suite switch)

## [1.0.88] – 2026-11-26

- style(blessings): the lock button of the blessing bar sits in the top right corner

## [1.0.87] – 2026-11-26

- feat(blessings): players under every class in the quick window and on the page – mouse wheel on a name sets your single blessing for him (back to your class blessing is part of the cycle), a click opens every paladin's blessings as icons (one click sets it), right click removes his single blessings
- feat(blessings): every single blessing shows in its paladin's cell with icon and name (e.g. Kings · Salty instead of "+1") – mouse wheel changes it, right click removes it
- feat(blessings): mouse wheel on the aura and seal buttons of the bar picks the next one you know
- feat(blessings): pop-outs of the bar open toward the middle of the screen by default (to the right when the bar sits on the left), still selectable left / right in Blessings › Settings
- feat(blessings): someone of a class you do not bless yet joins – it gets a blessing from you right away (your main blessing if the class wants it, else what it wants most and nobody gives); option "Bless new classes automatically". /lg test blessjoin
- fix(blessings): a player who just joined is no longer missing on the bar until the next roster change – the roster is read again while the game does not know him yet
- change(blessings): the cell menu of the quick window only picks the class blessing; single blessings go through the players. /lg test blesspick
- change(blessings): the bar counts per class every player who gets something from you – class blessing or his single one – so a green row means everything is on; the separate "Single" button is gone (a class where you only give singles gets its own row)
- change(blessings): left click on the bar = greater blessing, right click = normal blessing (class rows and player buttons; on a player with a single blessing both cast it); mouse wheel on a player sets his single blessing
- change(blessings): short tooltips – name, blessing and state, missing players in one line, one line of hints
- fix(blessings): the Righteous Fury button shows for every spec as soon as it is switched on in Blessings › Settings, also when the game has no name for the old spell id
- feat(blessings): hovering a paladin's cell in the quick window or on the page unfolds every player of that class below it – mouse wheel on a name sets THAT paladin's single blessing (no more only your own), click picks, right click removes; a dot shows whether he has it
- fix(blessings): tooltips of the player lists sit beside the list instead of on top of the blessing icons and update right away after a mouse wheel or click
- change(blessings): full names in player lists, cell lines and the picker (two players with the same first name stay apart); bigger names and icons, wider columns in the quick window
- fix(blessings): the known-blessing icons of a paladin in the quick window no longer overlap "You"
- change(blessings): only Kings, Might and Wisdom as blessings – Sanctuary does not exist on Forever and Light is Oath of Light there (it showed the Kings icon); old assignments of both are dropped, PallyPower digits 5 and 6 are passed on unchanged
- feat(blessings): Oath of Light button on the bar (shown when you know it, option in Blessings › Settings) – casts it on the player you chose (mouse wheel or right click, tanks first; without a choice on your target), green while he has it. /lg test blessoath
- feat(blessings): Shift + mouse wheel on a cell of the quick window or page (or a class row of the bar) gives the whole row the same blessing – every class in the group. /lg test blessflyout
- change(blessings): full names in the pop-outs and tooltips of the bar too
- change(blessings): no blessing icon in the top right corner of the bar any more

## [1.0.86] – 2026-11-26

- change(general): new release with the version number raised – the addon itself is unchanged since 1.0.84 (blessing bar, quick assign window, single blessings, smart assign by spec, Light and Sanctuary)

## [1.0.85] – 2026-11-26

- change(general): version number raised only – no changes in the addon since 1.0.84

## [1.0.84] – 2026-11-26

- feat(blessings): new blessing bar – one button per class you bless (class, blessing, buffed/total, time left) in green / yellow / red; hovering it pops out the players of that class with what you give each of them and the time left – left click casts it on him, right click or mouse wheel sets a single blessing. Opens in combat too. On top: aura, seal and Righteous Fury buttons (optional), "Cast next" with the shortest time left
- feat(blessings): quick assign window – every paladin and class at a glance, click a cell for the blessing or a single blessing for one player, mouse wheel cycles, right click removes; free assignment, settings, announce, smart assign, clear and refresh at the bottom. /lg assign, grid button on the bar, "Quick…" on the page, /lg test blesswindow
- feat(blessings): single blessings – one player gets another blessing than his class gets from you (e.g. Might for a protection paladin while the other paladins get Wisdom); the "Single 2/2" button on the bar (green when all are on), "Single…" on the page, the quick window or right click on a player
- feat(blessings): smart assign by spec – talents (profile or inspect), group role, else class decide what a player wants: a feral druid gets Might among restoration druids, a resto druid Wisdom, tanks Sanctuary. Class blessings follow what most of the class wants, singles fill the rest; singles set by hand stay. /lg test blessspec shows what everyone plays and wants
- feat(blessings): single blessings go to PallyPower guests and come from them (NASSIGN, also as leader for them)
- feat(blessings): Light and Sanctuary – offered when the paladin knows them; no Salvation (not a blessing on WoW: Forever)
- feat(blessings): bar settings – player buttons, which side they open to, buff duration, counts, bar scale, aura / seal / Righteous Fury buttons with the one to track
- feat(blessings): Seal of Fury counts with both ranks on the seal button
- fix(blessings): greater blessings on WoW: Forever – also found by name in the spell book when the game uses other spell ids, and blessing ids seen on players are learned (counts, own casts, live strip); /lg test blessspells shows what you know
- change(community): the fail-pull vote after a wipe is off by default (switched off once for everyone); when on, only a small square shows up that opens the vote – movable with "Move elements". Notifications › Fail-pull vote after a wipe
- change(blessings): bar counts only players who should get the blessing (a single from you replaces your class blessing on him); "Cast next" casts class blessings first, then singles
- change(council): every member sees the loot council page again – the loot history and the council setup (who is on the council, rules, answer buttons) read-only; only the guild master, officers and the council can change it. Modules › Loot council can still hide the page for members

## [1.0.83] – 2026-11-26

- feat(admin): new page Guild › Guild admin for the guild master, officers and the loot council – your role, officer ranks, the loot council setup, the craft prefix and who may do what, at a glance. /lg admin, /lg test admin
- feat(admin): the guild master picks which guild ranks count as officers in the addon (announcements, deleting feed and loot entries, partner key, craft prefix, council setup) – the same for everyone
- feat(admin): officers set the craft question prefix (default "!lg") for the whole guild – also in Professions › Settings; members on older versions keep "!lg"
- change(council): the loot council setup (council, rules, answer buttons, announce channel) is the same for the whole guild – every change by the guild master, an officer or the council goes out by itself, members who were offline get it at their next login; for everyone else it is read-only
- fix(council): a shared setup is now taken by new installs too (from officers) and is no longer blocked by an older local change; received setups are checked field by field
- style(settings): read-only settings are dimmed with a lock on the card – hover them to see who may change them
- change(qol): change your group role by hand and auto role pauses for the session – one line in chat, role checks are left to you; back after a talent swap (one line in chat), login, /reload or picking it again in General › Group role
- fix(feed): profession milestones always show the English profession name, also from German clients
- fix(comm): no more "No player named … is currently playing" lines – addon data for a player who just went offline is dropped instead of being sent piece by piece; he is skipped for 10 minutes or until he is back online. /lg test offline
- fix(partner): asking /who for the partner guild no longer opens the who window or the LFG who list – also when the answer comes late or the game opens it another way (a window that was already open stays). /lg test who shows what happened

## [1.0.82] – 2026-11-26

- feat(window): third slider in the header – font size of every addon text, next to opacity and scale; all three slimmer, they give way one by one in narrow windows
- style(window): new sidebar – group titles in the theme's accent colour, thin lines between the groups, taller rows, the open page with an accent bar and a soft accent fade
- feat(theme): new colourways with a short line in the theme menu – Ember, Liebe Grüße, Emerald, Radiance, Love Letter (new), Arcane, Moonwell, Crimson; existing choices keep their key
- change(council): the loot council page shows only for the guild master, officers and the council by default (switch in Modules › Loot council); raiders keep the answer popup, their auto-pass switch is on Modules then
- feat(notify): editable message texts with placeholders – congratulations (level, loot, profession), welcome ({player}, {first}, {level}, {item} …) – a click on a placeholder below a field puts it in at the cursor; award announcement and roll request in Loot Council › Settings, the whisper to paladins in Blessings › Settings. /lg test messages
- feat(quick): quick actions bar for "!lg" – one-line prompts like "Salty Brown asked for [Lionheart Helm] – click to post"; a click writes the answer in your name, right-click dismisses, lines go away after 15 s (10–120 s). Movable with "Move elements". Settings in Professions › Settings, /lg test quick
- feat(quick): "!lg" answers between addon users show in the bar with who asked; gone as soon as someone posts the answer. The [Post] link in the chat line stays (switchable)
- change(quick): "!lg" answers for players without the addon ask first by default – they wait in the bar until you click (the game limits automatic lines); "Send" restores the old behaviour. Notifications, the login greeting and congratulations are unchanged
- change(theme): default font size 95 % (was 105 %; a size you chose yourself stays)
- docs(release): CurseForge and GitHub show this version's changes instead of the commit list
- change(search): settings that are hidden for you are no longer offered by the global search

## [1.0.81] – 2026-11-26

- feat(blessings): live status in combat – a thin strip under each bar row, one segment per player, green while your blessing is on him and red when it is missing; drawn by the game itself, so it stays right in combat (Protection, death, a replaced blessing). Option "Live status in combat" on the Blessings page, /lg test blesslive
- fix(blessings): right-click on a bar row in combat steps through the class (players missing the blessing first) and skips dead players – before, every right-click in combat went to the same player
- fix(blessings): left-click in combat skips a dead target
- fix(blessings): your own Blessing of Protection, Freedom or Sacrifice in combat removes your blessing from that player on the bar, your own recasts count again right away
- change(blessings): in combat the counts show "~" – the game hides buffs there, the numbers are the last known state
- change(settings): every module keeps its settings in its own page, tab "Settings" – Guild Feed (pop-ups), Professions ("!lg" answers, profession sync; gear tab), Loot Council (auto-pass, together with the council setup), Blessings (bar and sync, no more switches under the grid), Roster (enchant check, moved from General); Cooldowns keep theirs under Displays
- change(modules): the page Modules only switches modules on and off; a gear next to a module opens its settings. "Loot council page only for council" stays there
- change(general): only interface, characters, group role and import / export
- feat(blessings): /lg test blesslive also says why nothing is shown (not a paladin, bar hidden, no row with players yet)
- feat(council): loot history by raid evening – pick one evening above the list (until 6 in the morning it still counts as the evening before), and within it one council session; export and share can take just the shown evening
- feat(council): click on a history entry: delete it, its session or its whole raid evening – for the whole guild; officers delete everything, a loot master the items he gave out; deleted entries do not come back with the sync. /lg test lchistory adds sample evenings (only for you)
- change(council): the council may vote for themselves by default ("Allow voting for yourself", switched on once for existing setups)
- feat(setup): the setup assistant opens once at login when something is open (per character; again only when something new is open; after the "what's new" window). It covers the profession sync hint. Option in General › Interface
- fix(changelog): "what's new" also shows when a newer build keeps the same version number (its changelog grew) – before, it only showed when the version number went up
- feat(setup): /lg setup – setup assistant: addon version, professions synced, main character, group role, your blessings, cooldown displays; each row with its state and a button that leads there (also General › Interface). /lg test setup
- fix(professions): narrow window – the tabs get narrower and then show only their icons, so the settings tab is never hidden behind the search
- fix(professions): narrow window – "Expand all" no longer covers the "Show" switches (becomes a small icon button, the "Show:" label goes first)

## [1.0.80] – 2026-11-25

- change(craft): "!lg" from an addon user (1.0.80+) is answered through the addon channel instead of guild chat – every addon user of the guild sees the answer in the chat window (guild colour, links clickable); no automatic chat line, so the game's limit does not apply; players without the addon still get the guild chat answer
- feat(craft): "[Post]" behind every answer in the chat window – one click posts it to guild chat (also /lg post for the last answer), each answer once
- change(craft): whispered "!lg" from an addon user is answered by addon whisper

## [1.0.79] – 2026-11-25

- fix(craft): Forever limits how many automatic chat lines an addon may send in a short time – every automatic line (answers, greetings) is counted, and a client that sent one in the last minute leaves the next "!lg" answer to another client
- feat(test): /lg test chat shows how many automatic lines were sent in the last 1 and 5 minutes

## [1.0.78] – 2026-11-25

- change(dungeons): page Dungeons removed again with everything that belongs to it (marks, group posts, guild chat reading, dungeon browser, /lg lfg, /lg lfm, tests, settings); its saved data is deleted at login

## [1.0.77] – 2026-11-25

- change(community): leaderboard "Gravity's favourites" and the badge "Gravity Tester" removed; deaths by falling or drowning are no longer recorded
- change(craft): after a blocked chat line the client sits out "!lg" answers for 2 minutes at most (was 24 h)

## [1.0.76] – 2026-11-25

- change(dungeons): the dungeon browser only fills your own group – "Dungeon browser" works after "Post group", shows the players listed there (right-click: invite); a second click shows the guild only again; foreign groups from the browser are no longer listed
- feat(dungeons): role filter tank / healer / dps next to it (main role or off spec, several at once); after a browser search it is set to your open spots
- fix(dungeons): comments from the browser are protected text ("Kt75k") – now shown the way the game shows them; no dangling "·" after a play style without note
- fix(craft): /lg test chat reset – answer "!lg" again right away after a block

## [1.0.75] – 2026-11-25

- change(dungeons): guild chat is always read again (no "Guild chat" button) – it is the guild's own chat
- feat(dungeons): "Dungeon browser" button – searches the game's dungeon browser for the selected dungeon; listed players show in the list (tag "browser", right-click: invite), listed groups at the top
- feat(dungeons): right-click a listed group: "Request to join" – the game's request where the client has one, otherwise a whisper to the leader with role, level and class
- style(dungeons): groups listed in the browser show "public"

## [1.0.74] – 2026-11-25

- fix(craft): a client whose chat line the game blocked takes no part in "!lg" answers for 30 min – the other members' addons answer; one chat note explains it
- fix(chat): every addon restriction the client reports counts before an automatic chat line (not only a fixed list); lines go out through C_ChatInfo.SendChatMessage when the client has it
- feat(test): /lg test chat – combat, encounter, chat lockdown, every addon restriction and the last block (time, function, combat state)
- fix(dungeons): the group finder search looks at every category the client offers (Ragefire Chasm and The Stockade were not found under dungeons)

## [1.0.73] – 2026-11-25

- fix(craft): a "!lg" question got no answer when the chosen client could not send (the game blocked its chat line, combat): after 5 s without an answer a second round picks another client; late answers are dropped when someone answered meanwhile
- fix(chat): when the game blocks an action of the addon, automatic chat lines pause for two minutes instead of failing again; the combat restriction counts as blocked, too
- change(dungeons): "Public" opens the game's group finder on its listing tab and names the entry to pick – the game lists groups only from its own window; the post shows "public" as soon as the listing is active, closing the post removes it
- fix(dungeons): dungeon names of the game's group finder (Stratholme Main/Service Gate, Scarlet Graveyard/Library/Armory/Cathedral) are recognised, also in guild chat

## [1.0.72] – 2026-11-25

- feat(dungeons): "Public (group finder)" when posting a group – for players outside the guild to fill the last spots
- feat(dungeons): play style (Learning, Relaxed, Competitive, Carry offered) for group posts and marks – shown in the chat line, the group rows and the player list; toasts and "fits a spot" only for matching styles
- change(dungeons): a group gets into the tool only with "Post group" – your own typed "LF2M …" no longer makes one
- feat(test): /lg test lfgtool [reset] – which group finder functions the client offers and which dungeons it knows

## [1.0.71] – 2026-11-25

- change(dungeons): reading guild chat is off until switched on with the new "Guild chat" button on Who wants to go (accent colour while on); entries from guild chat are hidden while it is off
- style(dungeons): open groups, LFM tag, "Your group" and players who fit a spot use the accent colour

## [1.0.70] – 2026-11-25

- feat(dungeons): post your group – "Post group" (or /lg lfm [dungeon]) picks the open spots per role and a note, writes one line in guild chat ("LF2M Stratholme Undead - need Healer, DPS") and shows the group to addon users
- feat(dungeons): open groups at the top of a dungeon (yours first) with "Join" (whisper prepared) and an "LFM" tag in the dungeon list
- feat(dungeons): spots fill by themselves when players join your group and open again when they leave; the post closes when the group is full or after 30 min
- feat(dungeons): toast when a group for a dungeon you marked needs your main role or off spec (switch under Modules and Notifications)
- feat(dungeons): players who fit an open spot of your group are marked green
- feat(dungeons): the nine new Forever dungeons are in the list (Hall of Thanes, Ruins of Lordaeron, Excavation Site: Wetlands, City of Dalaran, The Drowned City, Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold, Shaper's Terrace), sorted by level and tagged "Forever"
- feat(dungeons): guild chat is read – "LFG Strat UD" puts the player on the list for 2 hours (also without the addon, role from "as heal"), "LF2M Scholo need tank" shows as an open group; trade messages are ignored
- feat(dungeons): your own chat message makes a short mark of yours (or your open group) that is synced
- feat(search): results in two lines – name and where it is ("Notifications › General"), card titles as "Section:", the same setting in several places as one entry ("2 places: …") that opens with +
- feat(test): /lg test lfgpost (open groups + toast), /lg test lfgchat [text] (what is read from a chat message)

## [1.0.69] – 2026-11-25

- feat(dungeons): new page Dungeons – mark the dungeons you want to run with main role, off spec, a note and up to six wanted items (/lg lfg)
- feat(dungeons): "Who wants to go" lists everyone per dungeon with role, items and note; online only, fits my level; click whispers (text prepared, not sent), right-click invites
- feat(dungeons): wanted items show overlaps with other players of the same dungeon; items you get leave your list by themselves
- feat(dungeons): marks run out after 14 days (7/30 selectable), "Renew" keeps them; synced to the guild on change and at login
- feat(test): /lg test lfg with made-up members

## [1.0.68] – 2026-11-25

- feat(professions): new tab "Shopping list" – recipes with −/+ and remove, all materials with need, owned, price and total, vendor materials marked; buttons for Auctionator, TSM search, copy and empty
- change(professions): the cart button at the top opens the tab (right-click: quick menu)
- feat(slash): /lg shop, /lg shop clear, /lg price <item>
- docs(guide): shopping list and price commands in the Professions guide and the command list

## [1.0.67] – 2026-11-25

- fix(professions): error when opening the shopping menu (menu title)
- change(professions): the shopping list is a cart – every click on a recipe's cart adds one craft (right-click removes one), several recipes in one list, cart button at the top with the recipes, TSM search, copy and empty
- change(professions): nothing you already own is subtracted any more; the Auctionator list follows every click
- feat(crafts): every "!lg" answer ends with the short material cost ("mats ~64g")

## [1.0.66] – 2026-11-25

- feat(professions): shopping list for the Auction House – cart button at every recipe in Guild crafting and "Shopping list" in My professions; materials for 1, 5, 10 or 20 crafts go to Auctionator as the list "Liebe Grüße", or as a TradeSkillMaster search, or as text to copy (bags and bank counted, vendor materials left out)
- feat(crafts): "!lg price <item>" (also "cost" or "mats") answers with the material cost, the main materials and the auction value
- feat(test): /lg test shopping and /lg test price <item>

## [1.0.65] – 2026-11-25

- fix(crafts): "!lg" answers and the login greeting wait until combat ends – the game blocked them while you were in combat
- change(roster): the row tooltip shows only main professions (icon, name, skill) – shorter
- change(versions): one row per player – alts are grouped under their main (versions of every character in the tooltip), all guild members are listed, newest version first
- feat(feed): filter buttons above the list (all, levels, bosses, loot, professions, firsts, joins, council) with the number of entries

## [1.0.64] – 2026-11-25

- style(settings): every settings page gets a head with icon, title, a line on what it is for and the search on the right
- style(settings): cards with the title in the accent color and a chevron, rows with hover, two columns that become one in narrow windows
- change(modules): the Modules page lists every module in two columns, below it one card per module with its features (feed, professions, loot council, blessings, greeting, cooldown displays)
- change(general): sorted into Interface, Your characters, Group, Enchant check and Import / export
- style(icons): every icon comes in 16, 32 and 64 px and the size that fits the screen is used – sharp instead of blurry
- change(font): Expressway is the default font when an installed addon provides it, otherwise Barlow
- change(armory): the picture in the model box is the same icon as the portrait in the header, same size and frame

## [1.0.63] – 2026-11-25

- change(armory): without a model from the game the box shows the spec picture in a bronze ring with race and class – the 3D model replaces it once the member is known (in sight or remembered from the group)
- change(armory): the statue preview is gone
- feat(roster): row tooltip with level, class, spec, rank, the known data (gear, talents, professions) with source and age, and where the member is
- style(professions): guild crafting with the guild title, professions grouped into crafting, gathering and secondary, a header with icon and recipe count and the tabs Characters / Recipes
- feat(professions): recipe rows show how many crafters are online and how many characters can craft it
- feat(blessings): PallyPower guests – free assign (FREEASSIGN), real spell ranks, blessings this addon does not know stay untouched, a check request after assigning a guest
- feat(blessings): options "Read PallyPower of guests" and "Sync with PallyPower"; nothing is sent while PallyPower runs on your own client

## [1.0.62] – 2026-11-25

- feat(armory): group members out of sight show the look the game remembers from earlier, before any preview
- feat(armory): a member who leaves your sight keeps the real model while their armory stays open
- style(armory): the race body preview is lit as a bronze statue (the client has no skin colours for it)
- feat(test): /lg test model shows the group unit, the statue light and light, texture and item methods of the model

## [1.0.61] – 2026-11-25

- fix(armory): clients without SetCustomRace show the member's race body model instead of an empty box
- fix(armory): the empty model box says when the game client can't show other members' models (no longer "race unknown")
- feat(test): /lg test model lists the race setter, the loaded body source and the model and scene methods of the client

## [1.0.60] – 2026-11-25

- fix(crafts): the recipe search lists the hits of all professions again, grouped by profession (as before 1.0.58)
- fix(professions): in small windows the price source shrinks (no label, then only an icon) so the tabs stay readable
- fix(help): in small windows the area tabs get their own row below the page search
- fix(attunements): in small windows the switches shrink and then move into a second row
- fix(versions): the summary line ends before the page search
- change(search): the page search always has the same width

## [1.0.59] – 2026-11-25

- change(search): a jumped-to setting or member is marked for 5 seconds, then only a small diamond stays in its top right corner until your next click in the window

## [1.0.58] – 2026-11-25

- change(search): the page search only marks matches – nothing is hidden any more; the view scrolls to the first match
- feat(search): pages with tabs are searched completely – each tab shows its number of hits, the tab with hits opens by itself (Loot Council, Community, Cooldowns, Professions, Statistics, Help)
- feat(search): professions with hits show their count and open by themselves in Guild crafting
- feat(search): number of hits inside the search field
- change(search): a jumped-to setting or member stays marked much longer
- fix(roster): the Filter menu closes after picking an entry; the Filter button is no longer cut off

## [1.0.57] – 2026-11-25

- change(search): "Search everything" sits below the online bar again, above the pages
- feat(search): picking a setting or a member jumps there – the page stays complete, the row scrolls into view and flashes
- feat(search): matches get a soft accent background in lists and settings; Enter in the page search jumps to the first match
- feat(roster): your own characters are marked (tint, "you" / "yours")
- feat(roster): Filter menu – my characters, level 60, class, rank, profession
- fix(search): the page search no longer covers the guild switch (roster), armory and compare controls or the update card on wide windows

## [1.0.56] – 2026-11-25

- change(search): "Search everything" sits at the very top of the sidebar
- change(search): the page search moved out of the header into the top right corner of every page – Credits included
- feat(search): matches are marked in lists, settings, guide, help, boards, blessings and statistics
- feat(ui): empty lists show an icon with a short hint; a search without result says so and how to fix it
- change(ui): toolbars too long for the window shrink to their icons (name in the tooltip)
- change(partner): the switches move to their own row in narrow windows

## [1.0.55] – 2026-11-25

- feat(search): search everything from the sidebar – pages, settings, guide, commands, members and recipes (/lg find)
- feat(search): every page has its own search in the header; picking a setting opens its page filtered to it
- change(search): the searches of Roster, Attunements, Loot Council, Professions, Guide and Help moved into the header
- feat(search): new searches for Guild Feed, Community, Partner guild, Versions, Blessings, Cooldowns, Statistics and all settings pages
- fix(lootcouncil): the answer popup no longer errors while more than a minute is left
- fix(lootcouncil): /lg lc config and /lg lc history open the right tab; /lg lc export knows rclc, gargul and nota (default rclc)
- feat(help): new commands /lg bless, /lg tooltips, /lg credits; new area "Raid tools"
- feat(guide): new topics – fail-pulls & ready checks, trade timers, auto role, appearance & layout
- feat(notify): option "Fail-pull vote after a wipe"
- perf(cooldowns): the preview timer only runs while a preview is shown
- feat(test): /lg test attune and /lg test search

## [1.0.54] – 2026-11-25

- fix(qol): auto role no longer sets itself every few seconds in battlegrounds (roles are skipped in battlegrounds and arenas)
- fix(qol): a role that does not stick is not sent again, so the chat is no longer spammed with role changes
- feat(test): /lg test role shows why your role is (not) set automatically

## [1.0.53] – 2026-11-25

- feat(versions): update notice once per login when an officer or two members already run a newer version (toast + chat line)
- feat(versions): small update chip next to the version in the sidebar and an UPDATE badge at Versions until you updated
- feat(versions): update card on the Versions page with the three steps and "Don't remind me for this version"
- feat(notify): option "Addon update available" under Notifications
- fix(versions): implausible version numbers no longer count as the newest version
- feat(test): /lg test update shows the notice with a made-up version

## [1.0.52] – 2026-11-25

- feat(guide): new page Guide – how every module works: steps, where to find it, what is shared, commands (/lg guide)
- fix(notify): long announcements wrap over several lines instead of being cut off
- fix(armory): never shows your own character for other members – race, gender and their gear instead, empty when the race is unknown
- feat(window): sidebar badge NEW for pages not opened yet

## [1.0.51] – 2026-11-24

- feat(notify): guild master and officers can pop an announcement for the whole guild (Notifications → Announcement, /lg announce)
- fix(professions): rogue poisons are no longer treated as a profession (old entries are removed)
- feat(profsync): the sync window lists all your professions, including cooking, first aid and fishing
- change(profsync): sync messages in chat only the first time and when new recipes were learned, not on every open

## [1.0.50] – 2026-11-24

- fix(community): no more "ADDON FORBIDDEN" error at login – the combat log is no longer used (the client blocks it for addons)
- change(community): falls count deaths out of combat, drowning and fatigue come from the breath timer, guard deaths from your target

## [1.0.49] – 2026-11-24

- feat(greet): "glaun hs" in guild chat when Salty Brown or Salty Yellow logs in, "marcha hs" for Mar Cha – everyone once a day
- feat(prof): chat lines while a profession syncs – "keep the window open" and "synced (N recipes)"
- feat(prof): hint window after login for professions that were never synced (once per character)
- feat(prof): sync window opens each profession with one click ("Open") and guides to the next one
- feat(community): "?" on every board explains how it is counted
- feat(community): new boards – gravity's favourites (falls, drowning), repair bill, lucky dog / unlucky (epics per raid night), marathon (longest session), fastest greeter
- feat(community): quote of the week – most liked pin board post, last week's winner as a notification
- feat(community): AFK king and jumper (jumps per raid night) boards
- feat(community): tracked on their own – bad luck streak, ghost runner, guard victims, spirit healer, flights, hearthstone, junk dealer, shopaholic, auctions, mails, interrupts, night owl, early bird, login streak (with badges)
- feat(community): badges in bronze, silver and gold for guild moments – in the armory, a "Badges" tab and a notification for your own new ones
- style(community): leaderboards in as many columns as fit, compact cards, scrolling
- fix(crafts): recipes of other professions no longer land under enchanting (craft window answered for every profession); old data is repaired
- feat(help): "Tests" tab with the whole test suite, /lg test list
- feat(test): /lg test greet, /lg test profsync, /lg test boards and /lg test badge (marked as test, sample data only)

## [1.0.48] – 2026-11-24

- change(trade): trade expiration timers only show for the master looter (option "Only when I am loot master", on by default)

## [1.0.47] – 2026-11-24

- fix(lootcouncil): loot master bar only shows for the real master looter – an unknown loot method no longer counts as master loot
- fix(lootcouncil): master looter read from the raid roster when available
- fix(lootcouncil): a test session left open no longer keeps the bar on screen (tests show it for 5 minutes)

## [1.0.46] – 2026-11-24

- feat(feed): officers delete feed entries for the whole guild – click an entry: delete it or all entries of that player
- feat(feed): deletions sync to members who were offline and keep deleted entries from coming back
- fix(blessings): bar keeps its rows in combat – only the numbers update, layout follows after combat
- fix(blessings): counts no longer drop to 0 in combat when the game hides aura data; the last reading is kept
- feat(test): /lg test feeddel adds a sample entry to try deleting

## [1.0.45] – 2026-11-24

- fix(feed): entries from others are checked – level/profession only from that player, loot only from someone in the same zone, awards only with the loot master's record
- fix(feed): guild firsts can no longer be stolen with a backdated entry; history batches never overwrite entries
- fix(feed): feed and loot history syncs only from guild members, only when we asked, only from the member who answered
- fix(lootcouncil): loot history only from the loot master who gave the item (officers may share everything)
- fix(sync): history requests by whisper are not answered (no data for players outside the guild)
- fix(sync): links, textures and colors from other players' data are removed; at most 6 notifications per player and minute
- fix(partner): Bund channel uses a secret key from the officers instead of a fixed name and password; the old channel is left
- fix(partner): presence is only taken under the sender's real name
- feat(partner): Key button – show or paste the key, officers send it or make a new one (/lg bund)
- feat(test): /lg test security runs forged messages through the checks
- fix(partner): last switch moves into the status line when the window is narrow

## [1.0.44] – 2026-11-24

- fix(cooldowns): icons on the group frames only show in a 5-man party – never in a raid, never solo
- change(cooldowns): group icons default to party only (also for existing settings, once)

## [1.0.43] – 2026-11-24

- fix(crafts): !lg answers are short – best match with at most two crafters plus "+N more matches", no more long lists
- fix(crafts): "Did you mean" and "too many" answers name only two recipes
- fix(crafts): the client that knows the asked recipe answers – clients without a match only answer when nobody else can

## [1.0.42] – 2026-11-24

- fix(crafts): !lg with a recipe link from the profession window ([Enchanting: Enchant Cloak - Agility]) finds the recipe
- fix(crafts): !lg ignores a "Profession:" or "Formula:"/"Pattern:" prefix in the question
- fix(crafts): exact recipe names always answer directly instead of "Did you mean"
- fix(crafts): every claim goes out within 1 s, so this version answers instead of older ones
- fix(crafts): question keys stay the same as in older versions (no double answers across versions)

## [1.0.41] – 2026-11-24

- change(ui): all German texts removed – the addon is English only
- fix(crafts): !lg answers only from English game clients, never with German recipe names
- fix(crafts): !lg answers from this version always win over older versions
- change(crafts): recipe search uses the names of your own client only
- change(cooldowns): raid cooldown and interrupt displays hidden by default (also for existing settings, once)
- change(slash): German command aliases removed (/lg berufe is now /lg professions)
- change(ui): theme and texture names in English (Ember, Void, Blood, Fel green, Flat, Gloss)
- docs: README in English

## [1.0.40] – 2026-11-24

- fix(armory): other members' model shows their race and gender – your own character no longer replaces it once it has loaded
- feat(test): /lg test model shows the race data and model mode of the member open in the armory

## [1.0.39] – 2026-11-24

- feat(crafts): !lg answers for a single recipe link the recipe as well – its tooltip shows the reagents
- fix(crafts): long crafter lists in !lg answers get shorter instead of cutting a link

## [1.0.38] – 2026-11-24

- fix(blessings): blessing bar fills in your blessings on first use – no right-click on Auto Assign needed
- fix(blessings): right-click on Auto Assign assigns once ("Blessings assigned" was shown twice)
- feat(blessings): lock button on the blessing bar – unlock and drag it where it is
- feat(trade): lock button on the trade expiration timers – unlock and drag them where they are
- fix(help): "/lg lc add all" description without a comparison

## [1.0.37] – 2026-11-24

- feat(blessings): blessing bar can show when solo (option "Show when solo", on by default)
- feat(blessings): plan blessings for every class when solo, on the page and the bar
- fix(blessings): changing one of your blessings no longer clears all your other assignments
- fix(armory): model uses the member's race and gender instead of your own character
- feat(armory): real model when the member is your target, mouseover or focus
- fix(profile): sync race id, gender, shirt and tabard for the armory model

## [1.0.36] – 2026-11-24

- fix(life): /lg irs opens your own life statistics again (/lg irs target for your target)
- change(ui): header map strip spans the full header and fades out slowly under the sliders

## [1.0.35] – 2026-11-24

- change(ui): English texts only, on German clients too
- fix(roster): spec, tree and class names in English ("Protection" instead of "Schutz"), also for data from German clients

## [1.0.34] – 2026-11-24

- fix(ui): sidebar pages tighten their rows in short windows and scroll as a last resort – no entries below the window edge

## [1.0.33] – 2026-11-24

- fix(feed): item names instead of raw item strings when the item is not cached yet; feed redraws once names arrive
- change(cd): attached group icons show a compact two-row sample while moving ("players without a group frame")

## [1.0.32] – 2026-11-24

- fix(ui): all shipped font cuts are preloaded during the loading screen – no blank texts in windows shown right after login
- fix(ui): "What's new" draws its texts again shortly after opening

## [1.0.31] – 2026-11-24

- fix(ui): shipped Barlow fonts are used directly (no pre-check); each text falls back to Arial Narrow only if the client refuses the file
- fix(ui): font folder follows the real addon folder name
- feat(ui): Barlow weights registered with LibSharedMedia for other addons
- change(test): /lg test font lists SetFont result per file, the font of the window title and refused files

## [1.0.30] – 2026-11-24

- fix(ui): font check accepts the path the client reports (slashes/case) – Barlow and all weights load instead of Arial Narrow
- change(ui): new "What's new" window – logo, version badge, one bullet per change with readable area names, window grows with its content

## [1.0.29] – 2026-11-24

- fix(ui): heavier Barlow cuts replaced with the original font files (the converted subsets did not load in game)
- feat(test): /lg test font shows which font files load and which are in use
- fix(ui): choosing a font weight switches the font to Barlow (weights only exist for Barlow)

## [1.0.28] – 2026-11-24

- feat(ui): third font weight "Bold"; hint that new font files need a full game restart
- change(ui): "Liebe Grüße" theme uses the lighter graphite base as well (no more dark navy)

## [1.0.27] – 2026-11-24

- change(ui): lighter, neutral graphite colors instead of dark slate blue
- feat(ui): font weight setting (Normal/Strong); Strong is the new default with heavier Barlow cuts
- change(roster): class/spec icons without colored border (roster, armory, compare, search)
- change(compare): better side tinted with a green edge, middle shows "+n iLvl" or "equal" with a tooltip
- fix(partner): online count only includes players from other guilds (Bund channel also carries our own guild)

## [1.0.26] – 2026-11-24

- fix(ui): list rows re-layout with the header – no text outside the table in narrow windows
- fix(roster): summary strip drops labels from the right when narrow (tooltip keeps all details)

## [1.0.25] – 2026-11-24

- fix(ui): header controls (opacity, scale, buttons) sit on solid header color – no map behind the sliders
- fix(help): area tabs move into their own row in narrow windows; quick start tiles grow with their text
- fix(roster): narrow window – guild switch moves into the summary row, filters keep their room
- fix(ui): segmented controls follow their width

## [1.0.24] – 2026-11-24

- feat(help): new help page – search, area tabs, quick start tiles, one grouped command table with run / put into chat
- feat(help): side cards for chat commands, tips and support; test commands behind a switch
- feat(ui): credits page – addon, all map strips with their author, font, licenses, thanks
- change(ui): map credit no longer shown in the page header (it is on the credits page)

## [1.0.23] – 2026-11-24

- feat(armory): compare – button in the armory opens a searchable member list (suggestions: you, same spec)
- feat(armory): compare view – gear slot by slot with item level difference, stats, talents, professions and attunements
- feat(armory): compare has "Back to armory", swap sides and "only differences"
- feat(ui): search menu widget (type to filter, arrow keys, Enter, Esc)
- feat(test): /lg test compare

## [1.0.22] – 2026-11-24

- change(notify): groups of 6+ show one class bar with the count instead of a row of icons; names stay in the hover tooltip
- fix(notify): hover pauses the timer bar and it resumes exactly where it stopped
- change(notify): boss test toast uses a mixed group from the roster

## [1.0.21] – 2026-11-24

- style(ui): addon tooltips in the window look – flat dark card, thin border, bronze corners
- style(armory): more room in the side cards; attunements and keys on separate lines; labelled character lines

## [1.0.20] – 2026-11-24

- feat(ui): Barlow ships with the addon and is the new default font (text: Semi Condensed, titles and numbers: Condensed)
- change(ui): Expressway and the other fonts stay selectable under Appearance

## [1.0.19] – 2026-11-24

- fix(ui): header map strips fade out to the right (fade baked into the textures)
- style(ui): logo block like the design – lapis light, larger stacked name, centered crest
- style(ui): status buttons on the dark base, footer in the header color

## [1.0.18] – 2026-11-24

- style(ui): every table gets its own dark frame with padding; larger row and header text
- style(ui): community, statistics and life-stats cards with bronze corners and engraved titles
- style(ui): separate windows (council, dialogs, what's new) carry bronze corner brackets

## [1.0.17] – 2026-11-24

- change(ui): light flash on the logo line and shine on the online bar loop while the window is open

## [1.0.16] – 2026-11-24

- style(ui): cooler slate base colors from the logo for all dark themes
- style(ui): sidebar like the design – stacked name, bronze group titles, compact items, solid selection
- feat(roster): summary strip with icons and big numbers above a framed table
- style(armory): larger stat values and card titles

## [1.0.15] – 2026-11-24

- style(ui): new look – bronze window frame and corner brackets on cards, engraved section titles
- feat(ui): sidebar status buttons – guild online, partner guild online, new feed entries
- feat(ui): online share bar under the status buttons; light flash along the logo line when the window opens
- feat(ui): map strips in the page header per page (option in Appearance), map credits in Help
- feat(roster): spec icons framed in the class color instead of class icons
- feat(armory): square spec portrait with class-colored frame

## [1.0.14] – 2026-11-24

- feat(notify): richer toasts – kicker, details per event, class icons of the group, item quality border
- feat(notify): draining timer bar with shine; hover pauses it
- feat(notify): level-ups show class and zone; epics show item level, slot, source and instance
- feat(notify): boss kills show instance, fight time, group size and the guild members
- change(notify): dungeon bosses no longer notify by default (option "Dungeon bosses too")
- feat(ui): "what's new" window after updates; `/lg changelog`
- fix(ui): toast text no longer overlaps its detail lines

## [1.0.13] – 2026-11-24

- change: remove credits and mentions of other addons from code, UI, README and changelog
- change: license texts moved to `Licenses/`
- change(cooldowns): default bar texture "Flach"; "classic look" preset
- change(slash): new alias `/lg life` for life stats

## [1.0.12] – 2026-11-23

- docs: rewrite changelog as short English commit messages

## [1.0.11] – 2026-11-23

- fix(trade): read trade time from the rendered bag tooltip instead of stale `C_TooltipInfo` data
- feat(trade): `/lg test trade raw` shows both sources side by side

## [1.0.10] – 2026-11-23

- feat(cooldowns): ask the player's addon for the real remaining time when clicking a running cooldown
- feat(cooldowns): fall back to the tracker's estimate when there is no answer
- feat(trade): close button; list stays hidden until a new tradeable item appears
- feat(trade): re-read times every minute while visible; hover shows the parsed tooltip text

## [1.0.9] – 2026-11-23

- docs: add `CHANGELOG.md`; README links to it

## [1.0.8] – 2026-11-23

- feat(tooltips): new settings page with live preview
- feat(tooltips): toggle each line (ilvl, enchants, spec, talents, professions, alts, attunements, note, version)
- feat(tooltips): compact or one-per-line layout, shift-only mode, partner guild support
- feat(tooltips): `/lg test tooltip`

## [1.0.7] – 2026-11-23

- feat(tooltips): show main professions only

## [1.0.6] – 2026-11-23

- feat(ui): all tooltips anchor at the mouse cursor (optional; talent tree excluded)

## [1.0.5] – 2026-11-23

- fix(feed): invalid `SetText` argument in feed tooltips
- fix(profile): secret number values when reading character stats

## [1.0.4] – 2026-11-23

- feat(armory): gear slots spread over the full height; icons and model scale with it

## [1.0.3] – 2026-11-23

- fix(trade): re-read trade times after login and on hover

## [1.0.2] – 2026-11-23

- fix(armory): read talents via `C_Traits` on Forever
- feat(armory): talent icons per tree and mini talent tree on hover; dual spec points
- feat(armory): responsive layout; slots like the character sheet
- fix(armory): model no longer reloads on every refresh
- fix(armory): hit includes hit rating; own stats shown live
- fix(profile): stats-only updates are accepted from other members
- feat(blessings): mouse wheel cycles blessings on bar and grid
- feat(blessings): test mode `/lg test bless`
- feat(notify): toasts and feed with details on hover (source, zone, duration, guild members)
- feat(inspect): read talents when inspecting
- feat: `/lg test armory` prints raw talent and stat values

## [1.0.1] – 2026-11-23

- fix(armory): talents no longer "unknown" when data is missing; clearer hint
- fix(armory): stats sync
- feat(armory): talents read from inspect

## [1.0.0] – 2026-11-23

- feat(armory): character view from the roster (gear, model, stats, talents, professions, attunements, alts)
- feat(roster): class icons, profession icons, data column, crown for the guild master
- feat(blessings): paladin assignments with live status, PallyPower sync and blessing bar
- feat(ui): refresh button in the window header
- feat(professions): crafters on hover and click

## [0.9.2]

- feat(sound): own quiet sounds with adjustable volume (default 5 %)

## [0.9.1]

- feat(loot): export formats rclc, gargul and nota
- feat(cooldowns): universal unit frame support with optional frame hint

## [0.9.0]

- feat(attune): raid attunements and dungeon keys (`/lg attune`)
- perf: no idle timers or periodic scans
- fix(ui): text overflow; narrow windows hide optional columns
- style: settings as two-column cards, new slider and list headers

## [0.8.9]

- feat(cooldowns): separate icon width/height, icon border options

## [0.8.8]

- feat(cooldowns): toggle displays directly in the list

## [0.8.7]

- feat(cooldowns): icons attached to group unit frames

## [0.8.6]

- feat(roster): switch between own and partner guild
- feat(partner): online presence via hidden channel
- fix(partner): `/who` no longer opens the who window

## [0.8.5]

- feat(profile): automatic alts per account, also across guilds
- fix(profile): loading profiles of offline members (duplicate message kind)

## [0.8.4]

- fix(crafts): duplicate enchanting entry

## [0.8.3]

- fix(crafts): Lua error when hovering a crafter
- feat(roster): larger detail panel with two-column gear

## [0.8.2]

- feat(professions): all transmutes and engineering cooldowns
- feat(loot): master looter bar only for the actual loot master

## [0.8.1]

- feat(cooldowns): no title bar while moving bars
- feat(partner): partner guild page via `/who`

## [0.8.0]

- feat(loot): master looter bar docks to the trade timers
- change(ui): council window and life stats move by their title bar
- change(loot): "send setup" only for council members

## [0.7.9]

- feat(roster): weighted columns
- change(ui): main window above HUD elements; dialogs above it

## [0.7.8]

- feat(roster): profession abbreviations
- feat(ui): all windows resizable and responsive

## [0.7.7]

- feat(loot): master looter bar tooltips and icons
- feat(cooldowns): visible column settings
- feat(loot): readable export format names

## [0.7.6]

- fix(ui): "Font not set" when unlocking elements
- feat(loot): master looter bar in test mode

## [0.7.5]

- fix(crafts): Lua error in item tooltips
- feat(loot): compact master looter bar
- feat(trade): trade expiration timers
- feat(ui): redesigned unlock mode with arrow-key nudging
- feat(stats): dungeons & raids tab

## [0.7.4]

- feat(roster): profession abbreviations; crafting price in tooltips
- feat(loot): master looter bar and options
- feat(ui): right-click menu in unlock mode
- feat(stats): resizable life stats window
- feat(cooldowns): up to 12 columns and display conditions
- feat(professions): profession cooldowns (`/lg profcd`)

## [0.7.3]

- feat(stats): life stats for targets in their own window

## [0.7.2]

- feat(notify): notifications page (levels, epic loot, boss kills, firsts, joins)
- fix(feed): loot detection with missing client strings

## [0.7.1]

- feat(crafts): fuzzy `!lg` recipe search
- fix(crafts): never auto-post in combat

## [0.7.0]

- feat(stats): life statistics tab
- feat: `/lg test` commands for every module

## [0.6.9]

- feat(ui): unlock mode for all elements (`/lg move`)

## [0.6.8]

- feat(ui): drag displays with grid and snapping
- feat: modules page (`/lg modules`)

## [0.6.7]

- feat(cooldowns): custom bars with templates

## [0.6.6]

- style(cooldowns): classic bar look by default
- feat(cooldowns): track players without addon

## [0.6.5]

- fix(community): post text visible again
- feat(community): officers can remove posts

## [0.6.4]

- change(community): removed flask and food leaderboards; rebuilt board
- feat(loot): item actions button
- feat(crafts): material costs and price sources

## [0.6.3]

- feat(loot): right-click menus for players and items

## [0.6.2]

- feat(loot): queue from bags without chat commands

## [0.6.1]

- change: removed gold planner
- feat: command help per module
- fix(ui): own windows above the main window

## [0.6]

- feat(crafts): guild crafting tab with crafter tooltips
- feat(crafts): shared recipe catalog and specializations
- change: removed external codex integration

## [0.5]

- feat(community): leaderboards, board and fail-pull vote
- feat(stats): dungeon runs, raid nights, kills, deaths
- feat(crafts): `!lg` recipe answers in guild chat
- feat: automatic group role, import/export, toggleable modules
- feat(loot): configurable buttons, reasons, rolls, auto-pass
- feat(cooldowns): custom names and colors
- feat(professions): own professions page
