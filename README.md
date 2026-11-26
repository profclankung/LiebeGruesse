# Liebe Grüße – Guild Tools

Addon for World of Warcraft: Forever (Interface 16001). English only.

## Installation

Copy the folder `LiebeGruesse` into `World of Warcraft\_forever_\Interface\AddOns\` (or the AddOns folder of your client) and restart the game.

## Features

- **Search** – the field above the pages finds any page, setting, guide topic, command, guild member or recipe (`/lg find <text>`). Every page also has its own search in its top right corner (roster names, feed entries, boards and posts, settings, spells …): matches are marked, nothing is hidden, and every tab of a page is searched.
- **Roster** – every guild member with level, rank, item level, spec, professions and "last online". Click opens the armory with gear, right-click whispers. Alts are linked to their main (set the main in the settings). Your own characters are marked; the Filter menu narrows the list (my characters, level 60, class, rank, profession).
- **Inspect** – members without the addon are inspected automatically on mouseover/target (out of combat); there is also an "Inspect" button.
- **Professions** – own page in the addon design with two tabs: "Guild crafting" (professions on the left with counts, recipes or members on the right; recipes expand with reagents and every crafter, quality colours, star favourites, whisper with recipe link or a choice of crafters, post to guild chat, shift-click links, search across all professions, "Online only", specialisations) and "My professions" (cost, sell value, profit, shopping list). A third tab "Shopping list" shows the recipes in your list (−/+), all materials with price and total, and sends them on (`/lg shop`). Every click on a recipe's cart adds its materials for one craft to your shopping list (several recipes, right-click removes one); Auctionator gets the list "Liebe Grüße" right away, TradeSkillMaster a search to paste, otherwise a list to copy (vendor materials left out). Item tooltips show who in the guild can craft an item or already knows a recipe. Prices come from your auction house scans and – if installed – from price addons.
- **Dungeons** (`/lg lfg [dungeon]`) – mark the dungeons you want to run with main role, off spec, a note and up to six wanted items. "Who wants to go" shows everyone per dungeon (online only, fits my level); click whispers with a prepared text, right-click invites. Overlapping wanted items are marked; marks expire after 14 days (7/30 selectable) and can be renewed.
- **Guild feed** – level milestones, joins/leaves, boss kills, epic loot, maxed professions, "guild firsts" and loot council awards. With short popups.
- **Tooltips** – item level, spec, professions, main and more for guild members; every line can be switched under Settings → Tooltips (with live preview).
- **Loot council** – roles set in game (guild rank and above, extra names, loot master), renamable answer buttons, voting, awards with a raid chat announcement, loot history for the whole guild. The setup can be sent to the guild.
- **Cooldowns** (own page, `/lg cd`) – "Arrangement" tab: drag spells between columns, drag them in from the list on the right (search, class and category filters, grouped by class) or drag them back to remove; double-click shows/hides or adds. Click actions are free to set (left / shift-left / right click: whisper "{spell} please!" or announce in group chat, texts editable). Freely designed displays: raid cooldowns (5 columns), interrupts, group icons and any number of own displays – the built-in raid cooldown and interrupt displays start hidden. Per display: bars or icons, width, height, spacing, scale, texture, font, outline, text, colours (class/own), fill and growth direction, sorting, "only running". Per spell: display, column, row, cooldown, roles and player filter; own spells by ID. Preview with test players. Uses the common message format `FA_SPELL_CD`.
- **Window** – dark layout with a grouped sidebar (Guild, Raid tools, Forever, Settings), opacity and scale sliders in the header, "Move elements", minimise, "Reload UI".
- **Appearance** – 7 colour themes (default "Ember"), every colour can be changed, font, font and window size. Fonts and textures of other addons are offered when they provide them.
- **Enchant check** – including the neck; roster column with tick/cross, filter "Missing enchants", marker per item in the armory and a tooltip line. Which slots count is configurable.
- **Versions** – who has which addon version (guild or current group).

## Changes

All changes are in [`CHANGELOG.md`](CHANGELOG.md) in the addon folder (newest first).

## Commands

`/lg help` shows the general commands, `/lg help <area>` (or `/lg lc help`) those of one area: `roster`, `lc`, `raid`, `cd`, `crafts`, `partner`, `community`, `test`, `chat`. All commands are also listed in the window under **Settings → Help & commands** (`/lg commands`); a click writes the command into the chat line.

Main loot council commands: `/lg lc`, `/lg lc add all`, `/lg lc queue`, `/lg lc add [items]`, `/lg lc list`, `/lg lc clear`, `/lg lc start`, `/lg lc end`, `/lg lc test`, `/lg lc config`, `/lg lc history`. Raiders without the addon whisper `!lc` or `!lc 1 bis` to the loot master.

More: `/lg find <text>` (search everything), `/lg bless`, `/lg attune`, `/lg tooltips`, `/lg craft <recipe>` (search guild crafting), `/lg who <recipe>` (answer only for you), `/lg move`, `/lg minimap`, `/lg export`, `/lg import`, `/lg stats`, `/lg community`.

`!lg <recipe or item link>` in guild chat or a whisper: one addon user answers who can craft it. Answers are English only, so only English game clients answer. Answers end with the material cost; `!lg price <recipe or item link>` (also `cost`/`mats`) lists the materials and the auction value too.

## How to test

1. Alone: `/lg`, click through every page, `/lg lc test` (answer the popup, vote and award in the council window), `/lg cd` → tick "Preview with test players", design the displays and move them by their title bars, then lock them.
2. Two players in a group: `/lg ver`, one becomes group leader and opens loot or uses `/lg lc add [item]` + `/lg lc start`.
3. Please copy Lua errors completely and send them along.

## Known limits

- Members without the addon only have data from inspect (gear/item level), not professions.
- During boss fights the client blocks addon messages; the addon waits and sends afterwards.
- The loot council only assigns items. Hand them over by master loot or trade as before.

## Credits

- Map strips in the page headers: Santiago Reyes – Atlas de Azeroth: Forever (sreyesmaps.com), used with permission. In game: Settings → Credits.
