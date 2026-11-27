-- Cooldown displays: freely configurable bar or icon groups. Spells are
-- placed by column and row ; every display has its
-- own style (size, texture, font, colors, text, growth, sorting).
local _, ns = ...
local UI, Theme, L, Names = ns.UI, ns.Theme, ns.L, ns.Names
local Spells, Cooldowns = ns.CooldownSpells, ns.Cooldowns

local Bars = {}
ns.CooldownBars = Bars
local frames = {}

local function settings() return ns.Database.Settings().cd end

---------------------------------------------------------------------------
-- Display definitions
---------------------------------------------------------------------------
-- Default look of the bars:
-- Expressway with outline, white text, class-coloured bars that fill from the
-- right while on cooldown, icon left (zoom 30 %), 1 px black borders,
-- remaining time on the right (hidden when ready), ready bars fade in boss fights.
local STYLE_DEFAULTS = {
    enabled = true, mode = "bars", width = 110, height = 15, spacing = 1, colSpacing = 1, scale = 1,
    showIcon = true, iconSide = "LEFT", iconZoom = 0.3, texture = "Flat", font = "Expressway", fontSize = 10,
    outline = "OUTLINE", labelOffset = 2, textFormat = "name", showTime = true, readyText = "", hideReadyTime = true,
    colorMode = "wa", barColor = { 0.376, 0.376, 0.376, 1 },
    cdColorMode = "same", cdColor = { 0.3, 0.3, 0.3, 1 }, bgColor = { 0, 0, 0, 0.5 }, textColorMode = "white",
    textColor = { 1, 1, 1, 1 }, readyColor = { 1, 1, 1, 1 }, fill = "fill", reverse = true, grow = "DOWN", sort = "name",
    hideReady = false, excludeSelf = false, collapse = true, showTitle = true, nameAbove = false, iconSize = 32, iconsPerRow = 5,
    iconWidth = 30, iconHeight = 26, iconBorder = "none",
    showNames = true, border = true, fadeReady = true, fadeAlpha = 0.1, deadAlpha = 0.35,
    -- attached to the group's unit frames : side, offset, alignment
    attach = false, attachSide = "LEFT", attachX = 2, attachY = 0, attachAlign = "TOP",
    -- conditions: where the display is shown
    whenSolo = true, whenParty = true, whenRaid = true, where = "any", combat = "any",
}

-- Bar colours (slightly different from the default class colours)
local WA_CLASS = {
    DRUID = { 0.902, 0.494, 0.133 }, HUNTER = { 0.659, 0.788, 0.486 }, MAGE = { 0.314, 0.741, 0.855 },
    PALADIN = { 0.918, 0.588, 0.733 }, PRIEST = { 0.8, 0.8, 0.8 }, ROGUE = { 0.941, 0.906, 0.467 },
    SHAMAN = { 0.086, 0.439, 0.780 }, WARLOCK = { 0.569, 0.573, 0.894 }, WARRIOR = { 0.741, 0.608, 0.463 },
}
Bars.WA_CLASS = WA_CLASS

local BUILTIN_DISPLAYS = {
    raid = { name = "CD_GROUP_RAID", order = 1, enabled = false },
    kick = { name = "CD_GROUP_KICK", order = 2, enabled = false, width = 163, height = 24, fontSize = 17, texture = "Flat",
        bgColor = { 0, 0, 0, 0.75 }, labelOffset = 6 },
    party = { name = "CD_GROUP_PARTY", order = 3, mode = "icons", enabled = false, attach = true, showNames = false,
        whenSolo = false, whenRaid = false,
        iconWidth = 30, iconHeight = 26, iconBorder = "none", iconsPerRow = 4, spacing = 1 },
}

-- Style keys reset by "classic look" (layout, spells and position stay)
local LOOK_KEYS = { "width", "height", "colSpacing", "spacing", "showIcon", "iconSide", "iconZoom", "texture", "font",
    "fontSize", "outline", "labelOffset", "textFormat", "showTime", "readyText", "hideReadyTime", "colorMode", "barColor",
    "cdColorMode", "bgColor", "textColorMode", "textColor", "readyColor", "fill", "reverse", "border", "fadeReady",
    "fadeAlpha", "deadAlpha" }

local function copyValue(v) return type(v) == "table" and { v[1], v[2], v[3], v[4] } or v end

function Bars.ApplyWALook(key)
    local d = settings().displays[key]
    if not d then return end
    local builtin = BUILTIN_DISPLAYS[key] or {}
    for _, k in ipairs(LOOK_KEYS) do
        local v = builtin[k]
        if v == nil then v = STYLE_DEFAULTS[k] end
        d[k] = copyValue(v)
    end
end

Bars.STYLE_DEFAULTS = STYLE_DEFAULTS

function Bars.Display(key)
    local all = settings().displays
    local d = all[key]
    if not d then
        local builtin = BUILTIN_DISPLAYS[key]
        if not builtin then return nil end
        d = { name = L[builtin.name], order = builtin.order }
        for k, v in pairs(builtin) do if k ~= "name" then d[k] = v end end
        all[key] = d
    end
    for k, v in pairs(STYLE_DEFAULTS) do
        if d[k] == nil then d[k] = type(v) == "table" and { v[1], v[2], v[3], v[4] } or v end
    end
    return d
end

function Bars.Keys()
    local cd = settings()
    if (cd.styleVersion or 0) < 2 then
        -- v0.6.6: existing displays get the classic look once
        for key in pairs(cd.displays) do if cd.displays[key].mode ~= "icons" then Bars.ApplyWALook(key) end end
        cd.styleVersion = 2
    end
    for key in pairs(BUILTIN_DISPLAYS) do Bars.Display(key) end
    if not cd.partyOnlyMigrated then
        -- v1.0.44: the group icons only show in a 5-man party
        cd.partyOnlyMigrated = true
        local p = cd.displays.party
        if p then p.whenSolo, p.whenRaid = false, false end
    end
    if not cd.defaultsHidden then
        -- v1.0.41: the built-in raid cooldown and interrupt displays start hidden
        cd.defaultsHidden = true
        if cd.displays.raid then cd.displays.raid.enabled = false end
        if cd.displays.kick then cd.displays.kick.enabled = false end
    end
    for _, d in pairs(cd.displays) do
        -- v1.0.41: English texture names
        local tex = d.texture and ns.Theme.LEGACY_TEXTURE[d.texture]
        if tex and (tex == "Flat" or tex == "Gloss") then d.texture = tex end
    end
    if not cd.attachMigrated then
        -- v0.8.7: the party icons hang at the party frames
        cd.attachMigrated = true
        local p = cd.displays.party
        if p then p.attach, p.showNames = true, false end
    end
    local keys = {}
    for key in pairs(settings().displays) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local da, db = settings().displays[a], settings().displays[b]
        if (da.order or 99) ~= (db.order or 99) then return (da.order or 99) < (db.order or 99) end
        return a < b
    end)
    return keys
end

-- Templates for own bars: { picks = function(spell) -> bool, onlyMe, mySubgroup }
local TEMPLATES = {
    empty = {},
    mine = { onlyMe = true, pick = function(spell, class) return spell.class == class or spell.class == "ALL" end },
    healing = { ids = { 29166, 16190, 10060, 740, 20484, 633, 19752, 20707 } },
    tanks = { ids = { 871, 12975, 22812, 22842, 6940, 1022, 633 } },
    immunities = { ids = { 11958, 642, 1022, 1044 } },
    kicks = { mySubgroup = true, pick = function(spell) return spell.group == "kick" end },
}
Bars.TEMPLATE_ORDER = { "empty", "mine", "healing", "tanks", "immunities", "kicks" }

-- Creates a display. Own bars ("pick") show their own selection of spells,
-- independent of where the spells are placed in the main displays.
function Bars.AddDisplay(template)
    local n = 1
    while settings().displays["custom" .. n] do n = n + 1 end
    local key = "custom" .. n
    local t = TEMPLATES[template or "empty"] or TEMPLATES.empty
    local d = { name = template and template ~= "empty" and L["CD_TPL_" .. template] or L.CD_NEW_DISPLAY:format(n),
        order = 10 + n, pick = true, picks = {}, onlyMe = t.onlyMe or false, mySubgroup = t.mySubgroup or false,
        players = "", width = 150, height = 18, fontSize = 11 }
    local _, class = ns.Call(UnitClass, "player")
    for _, spell in ipairs(Spells.list) do
        local on = false
        if t.ids then for _, id in ipairs(t.ids) do if id == spell.id then on = true end end end
        if t.pick and t.pick(spell, class) then on = true end
        if on then d.picks[spell.id] = true end
    end
    settings().displays[key] = d
    Bars.Display(key)
    Bars.Layout()
    return key
end

function Bars.IsBuiltin(key) return BUILTIN_DISPLAYS[key] ~= nil end

function Bars.TogglePick(key, id, on)
    local d = settings().displays[key]
    if not d then return end
    d.picks = d.picks or {}
    d.picks[id] = on and true or nil
    Bars.Layout()
end

function Bars.RemoveDisplay(key)
    if BUILTIN_DISPLAYS[key] then return false end
    settings().displays[key] = nil
    settings().pos[key] = nil
    for id, o in pairs(settings().spells) do if o.display == key then o.display = "off" end end
    if frames[key] then frames[key]:Hide() end
    Bars.Layout()
    return true
end

function Bars.ResetDisplay(key)
    local d = settings().displays[key]
    if not d then return end
    local name, order = d.name, d.order
    settings().displays[key] = nil
    if BUILTIN_DISPLAYS[key] then
        Bars.Display(key)
    else
        settings().displays[key] = { name = name, order = order }
        Bars.Display(key)
    end
    settings().displays[key].name = name
    settings().pos[key] = nil
    if frames[key] then frames[key].positioned = false end
    Bars.Layout()
end

---------------------------------------------------------------------------
-- Entries: which bars a display shows, grouped by column
---------------------------------------------------------------------------
local ROLE_FIELD = { TANK = "tank", HEALER = "healer", DAMAGER = "damage" }

local function passesFilter(cfg, m)
    if cfg.filter and cfg.filter ~= "" then
        local ok = false
        for part in cfg.filter:gmatch("[^,;]+") do
            if Names.Same(Names.Key(part), m.key) then ok = true end
        end
        if not ok then return false end
    end
    local field = m.role and ROLE_FIELD[m.role]
    if field and cfg[field] == false then return false end
    return true
end

local function remaining(m, id, now)
    local cd = m.cds[id]
    if cd and cd.expires > now then return cd.expires - now, cd end
    return 0
end

local function subgroupOf(unit)
    if not unit or not GetRaidRosterInfo then return nil end
    local index = unit == "player" and UnitInRaid and ns.Call(UnitInRaid, "player") or tonumber(tostring(unit):match("^raid(%d+)$"))
    if not index then return nil end
    local _, _, sub = ns.Call(GetRaidRosterInfo, index)
    return sub
end

-- Player filters of a display (own bars): only me, only my raid group, names
local function memberAllowed(style, mkey, m, me)
    if style.onlyMe and not Names.Same(mkey, me) then return false end
    if style.players and style.players ~= "" then
        local ok = false
        for part in style.players:gmatch("[^,;]+") do
            part = part:gsub("^%s+", ""):gsub("%s+$", "")
            if Names.Same(Names.Key(part), mkey) or Names.Same(Names.First(part) or "", Names.First(mkey) or "") then ok = true end
        end
        if not ok then return false end
    end
    if style.mySubgroup and IsInRaid() and not m.fake then
        local mine = subgroupOf("player")
        local theirs = subgroupOf(m.unit)
        if mine and theirs and mine ~= theirs then return false end
    end
    return true
end
Bars.MemberAllowed = memberAllowed

local function entriesFor(key, style)
    local columns = {}
    local me, now = Names.Me(), GetTime()
    local spells = {}
    for _, spell in ipairs(Spells.list) do
        local cfg = Spells.Config(spell)
        if style.pick then
            if style.picks and style.picks[spell.id] then
                local own = {}
                for k, v in pairs(cfg) do own[k] = v end
                own.col, own.row = 1, spell.order
                spells[#spells + 1] = { spell = spell, cfg = own }
            end
        elseif cfg.enabled and cfg.display == key then
            spells[#spells + 1] = { spell = spell, cfg = cfg }
        end
    end
    table.sort(spells, function(a, b)
        if a.cfg.col ~= b.cfg.col then return a.cfg.col < b.cfg.col end
        if a.cfg.row ~= b.cfg.row then return a.cfg.row < b.cfg.row end
        return a.spell.order < b.spell.order
    end)
    for _, s in ipairs(spells) do
        local list = {}
        for mkey, m in pairs(Cooldowns.members) do
            local skip = (style.excludeSelf and Names.Same(mkey, me)) or not memberAllowed(style, mkey, m, me)
            if not skip and m.known[s.spell.id] and (s.spell.class == "ALL" or not m.class or m.class == s.spell.class)
                and passesFilter(s.cfg, m) then
                local left = remaining(m, s.spell.id, now)
                if not (style.hideReady and left <= 0) then
                    list[#list + 1] = { member = m, spell = s.spell, left = left, cfg = s.cfg }
                end
            end
        end
        table.sort(list, function(a, b)
            if style.sort == "ready" and (a.left > 0) ~= (b.left > 0) then return a.left <= 0 end
            if style.sort == "remaining" and a.left ~= b.left then return a.left < b.left end
            return a.member.key < b.member.key
        end)
        local col = columns[s.cfg.col] or {}
        columns[s.cfg.col] = col
        for _, e in ipairs(list) do col[#col + 1] = e end
    end
    -- "Columns" setting: spread all entries evenly over n columns
    -- (own bars default 1; built-in displays default 0 = columns from the arrangement)
    local n = math.floor(style.pickColumns or (style.pick and 1 or 0))
    if n >= 1 then
        local all, spread = {}, {}
        local keys = {}
        for c in pairs(columns) do keys[#keys + 1] = c end
        table.sort(keys)
        for _, c in ipairs(keys) do for _, e in ipairs(columns[c]) do all[#all + 1] = e end end
        if #all == 0 then return columns end
        local per = math.ceil(#all / n)
        for i, e in ipairs(all) do
            local c = math.floor((i - 1) / per) + 1
            spread[c] = spread[c] or {}
            table.insert(spread[c], e)
        end
        return spread
    end
    return columns
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
local function savePosition(f)
    if ns.Movers then
        settings().pos[f.key] = ns.Movers.Snap(f)
        return
    end
    local point, _, rel, x, y = f:GetPoint()
    settings().pos[f.key] = { point, rel, x, y }
end

local function placeAnchor(f, index)
    if f.positioned then return end
    f:ClearAllPoints()
    local pos = settings().pos[f.key]
    if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -180 - (index - 1) * 220) end
    f.positioned = true
end

local function createDisplay(key)
    local f = CreateFrame("Frame", "LiebeGruesseCD_" .. key, UIParent)
    f.key = key
    f:SetSize(150, 18)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(20)
    f.title = UI.Panel(f, "bg", "border")
    f.title:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2)
    f.title:SetHeight(18)
    f.title.text = UI.Text(f.title, 11, "gold")
    f.title.text:SetPoint("LEFT", 6, 0)
    f.title:EnableMouse(true)
    f.title:RegisterForDrag("LeftButton")
    f.title:SetScript("OnDragStart", function() f:StartMoving() end)
    f.title:SetScript("OnDragStop", function() f:StopMovingOrSizing(); savePosition(f) end)
    -- mover: covers title and bars while "move elements" is on, so the whole
    -- display can be dragged (also at the screen edge); right-click = menu
    f.mover = ns.Movers.NewOverlay(f)
    f.mover:SetFrameLevel(f:GetFrameLevel() + 40)
    f.mover:SetScript("OnDragStart", function(self) ns.Movers.Select(self); f:StartMoving() end)
    f.mover:SetScript("OnDragStop", function() f:StopMovingOrSizing(); savePosition(f) end)
    f.mover.nudge = function(dx, dy)
        local left, top = f:GetLeft(), f:GetTop()
        if not left or not top then return end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + dx, top + dy)
        settings().pos[f.key] = ns.Movers.Snap(f, true)
    end
    f.mover.menu = function(self)
        local d = Bars.Display(key)
        local function set(field) return function(v) d[field] = v; Bars.Layout() end end
        local sizes = { { label = L.CD_SCALE, min = 0.5, max = 2, step = 0.05, pct = true, get = function() return d.scale or 1 end, set = set("scale") } }
        if d.mode == "icons" then
            sizes[#sizes + 1] = { label = L.CD_ICON_WIDTH, min = 12, max = 80, step = 1, get = function() return d.iconWidth end, set = set("iconWidth") }
            sizes[#sizes + 1] = { label = L.CD_ICON_HEIGHT, min = 12, max = 80, step = 1, get = function() return d.iconHeight end, set = set("iconHeight") }
        else
            sizes[#sizes + 1] = { label = L.CD_BAR_WIDTH, min = 40, max = 400, step = 1, get = function() return d.width end, set = set("width") }
            sizes[#sizes + 1] = { label = L.CD_BAR_HEIGHT, min = 8, max = 48, step = 1, get = function() return d.height end, set = set("height") }
            sizes[#sizes + 1] = { label = L.FONT_SIZE, min = 6, max = 24, step = 1, get = function() return d.fontSize end, set = set("fontSize") }
        end
        ns.Movers.Menu(d.name, { sizes = sizes,
            settings = function() if ns.CooldownsPage then ns.CooldownsPage.Open(key) else ns.Window.Show("cooldowns") end end,
            extra = { { text = L.CD_HIDE_DISPLAY, func = function() d.enabled = false; Bars.Layout(); ns.Window.Refresh("cooldowns") end } },
        }, function() Bars.ResetPosition(key) end, self)
    end
    f.mover:HookScript("OnEnter", function(self) UI.Tooltip(self, Bars.Display(key).name, { L.CD_MOVER_TIP }) end)
    f.mover:HookScript("OnLeave", function() GameTooltip:Hide() end)
    f.mover:Hide()
    f.items = {}
    frames[key] = f
    return f
end

-- Click actions: ask the player to use the cooldown (whisper) or call it in
-- group chat. Templates use {spell}, {name} and {target}.
local lastCall = {}
local ACTIONS = { LeftButton = "clickLeft", RightButton = "clickRight" }

local function fill(template, e)
    local target = ns.Names.Unit("target")
    local values = {
        spell = Spells.Name(e.spell),
        name = Names.Display(e.member.name):match("^(%S+)") or "",
        target = target and (Names.Display(target):match("^(%S+)") or target) or "",
    }
    return (tostring(template):gsub("{(%a+)}", function(k) return values[k] or ("{" .. k .. "}") end))
end

function Bars.RunAction(e, action)
    local s = settings()
    if not e or action == "none" or not action then return end
    local now = GetTime()
    local key = e.member.key .. ":" .. e.spell.id .. ":" .. action
    if lastCall[key] and now - lastCall[key] < 3 then return end
    lastCall[key] = now
    local cd = e.member.cds[e.spell.id]
    if s.onlyReady and cd and cd.expires > now then
        ns.Print(L.CD_NOT_READY:format(Names.Display(e.member.name), Spells.Name(e.spell)))
        return
    end
    if e.member.fake then
        UI.Toast(L.CD_PREVIEW_SHORT, L.CD_ACTION_TEST:format(fill(action == "whisper" and (s.whisperText or L.CD_WHISPER_DEFAULT) or (s.callText or L.CD_CALL_DEFAULT), e)))
        ns.Print(L.CD_ACTION_TEST:format(fill(action == "whisper" and (s.whisperText or L.CD_WHISPER_DEFAULT) or (s.callText or L.CD_CALL_DEFAULT), e)))
        return
    end
    if action == "whisper" then
        if Names.Same(e.member.key, Names.Me()) then ns.Print(L.CD_SELF_CLICK); return end
        local target = e.member.name
        if e.member.unit and UnitExists(e.member.unit) then target = Names.Unit(e.member.unit) or target end
        ns.SendChat(fill(s.whisperText or L.CD_WHISPER_DEFAULT, e), "WHISPER", target)
        -- their addon answers with the real cooldown; shown only when it is not ready
        if ns.Cooldowns and ns.Cooldowns.AskReady then ns.Cooldowns.AskReady(e.member, e.spell) end
    elseif action == "call" then
        local channel = ns.GroupChannel()
        if channel then ns.SendChat(fill(s.callText or L.CD_CALL_DEFAULT, e), channel) else ns.Print(L.NOT_IN_GROUP) end
    end
end

local function onClick(self, button)
    local s = settings()
    local action = s[ACTIONS[button] or "clickLeft"]
    if button == "LeftButton" and IsShiftKeyDown() then action = s.clickShift end
    Bars.RunAction(self.entry, action)
    if action and action ~= "none" then
        self.flash = GetTime()
    end
end

local function onEnter(self)
    local e = self.entry
    if not e then return end
    ns.TipOwner(self, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetSpellByID, GameTooltip, e.spell.id)
    GameTooltip:AddLine(ns.ColorName(e.member.name, e.member.class))
    local s = settings()
    local names = { whisper = L.CD_ACTION_WHISPER, call = L.CD_ACTION_CALL }
    for _, pair in ipairs({ { "clickLeft", L.CD_KEY_LEFT }, { "clickShift", L.CD_KEY_SHIFT }, { "clickRight", L.CD_KEY_RIGHT } }) do
        local action = s[pair[1]]
        if names[action] then GameTooltip:AddDoubleLine(pair[2], names[action], 0.6, 0.6, 0.6, 1, 0.56, 0.2) end
    end
    GameTooltip:Show()
end

local function createBar(parent)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:EnableMouse(true)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.sep = b:CreateTexture(nil, "OVERLAY")
    b.sep:SetColorTexture(0, 0, 0, 1)
    b.sep:SetWidth(1)
    b.bar = CreateFrame("StatusBar", nil, b)
    b.bar:EnableMouse(false)
    b.bar:SetMinMaxValues(0, 1)
    b.bar.bg = b.bar:CreateTexture(nil, "BACKGROUND")
    b.bar.bg:SetAllPoints()
    b.left = b.bar:CreateFontString(nil, "OVERLAY")
    b.right = b.bar:CreateFontString(nil, "OVERLAY")
    b.left:SetWordWrap(false)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", onEnter)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function createIcon(parent)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetBackdrop({ edgeFile = Theme.WHITE, edgeSize = 1 })
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:EnableMouse(false)
    b.cooldown:SetAllPoints(b.icon)
    if b.cooldown.SetHideCountdownNumbers then b.cooldown:SetHideCountdownNumbers(true) end
    b:EnableMouse(true)
    b.overlay = CreateFrame("Frame", nil, b)
    b.overlay:EnableMouse(false)
    b.overlay:SetAllPoints()
    b.overlay:SetFrameLevel(b.cooldown:GetFrameLevel() + 2)
    b.right = b.overlay:CreateFontString(nil, "OVERLAY")
    b.right:SetPoint("CENTER")
    b.left = b.overlay:CreateFontString(nil, "OVERLAY")
    b.left:SetPoint("TOP", b, "BOTTOM", 0, -1)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", onEnter)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function labelText(style, e)
    local first = Names.Display(e.member.name):match("^(%S+)") or "?"
    local spell = (e.cfg and e.cfg.label and e.cfg.label ~= "") and e.cfg.label or Spells.Name(e.spell)
    local fmt = style.textFormat
    if fmt == "spell" then return spell
    elseif fmt == "name_spell" then return first .. " - " .. spell
    elseif fmt == "spell_name" then return spell .. " - " .. first
    elseif fmt == "fullname" then return Names.Display(e.member.name)
    elseif fmt == "none" then return ""
    end
    return first
end

local function stateOf(m)
    if m.fake or not m.unit or not UnitExists(m.unit) then return nil end
    if ns.Call(UnitIsConnected, m.unit) == false then return "offline" end
    if ns.Call(UnitIsDeadOrGhost, m.unit) == true then return "dead" end
end

local function readyLabel(style, st)
    if st == "dead" then return L.CD_DEAD end
    if st == "offline" then return L.OFFLINE end
    if style.readyText and style.readyText ~= "" then return style.readyText end
    return L.CD_READY
end

-- Applies size/font/texture to one bar
local function styleBar(b, style)
    local h, w = style.height, style.width
    local icon = style.showIcon and h or 0
    b:SetSize(w + icon, h)
    b.icon:SetShown(style.showIcon)
    b.icon:ClearAllPoints()
    b.bar:ClearAllPoints()
    b.icon:SetSize(h, h)
    local z = math.max(0, math.min(0.9, style.iconZoom or 0.3)) * 0.25 + 0.04
    b.icon:SetTexCoord(z, 1 - z, z, 1 - z)
    b.sep:ClearAllPoints()
    b.sep:SetShown(style.showIcon and style.border)
    if style.iconSide == "RIGHT" then
        b.icon:SetPoint("RIGHT")
        b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMRIGHT", -icon, 0)
        b.sep:SetPoint("TOPRIGHT", b.icon, "TOPLEFT"); b.sep:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMLEFT")
    else
        b.icon:SetPoint("LEFT")
        b.bar:SetPoint("TOPLEFT", icon, 0); b.bar:SetPoint("BOTTOMRIGHT")
        b.sep:SetPoint("TOPLEFT", b.icon, "TOPRIGHT"); b.sep:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT")
    end
    b.bar:SetStatusBarTexture(Theme.TexturePath(style.texture))
    if b.bar.SetReverseFill then b.bar:SetReverseFill(style.reverse == true) end
    b.bar.bg:SetTexture(Theme.TexturePath(style.texture))
    local bg = style.bgColor
    b.bar.bg:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
    local font, size, flags = Theme.FontPath(style.font), style.fontSize, style.outline == "NONE" and "" or style.outline
    Theme.SetFont(b.left, font, size, flags)
    Theme.SetFont(b.right, font, size, flags)
    for _, fs in ipairs({ b.left, b.right }) do
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(0, 0)
    end
    b.left:ClearAllPoints(); b.right:ClearAllPoints()
    b.left:SetPoint("LEFT", style.labelOffset or 4, 0)
    b.right:SetPoint("RIGHT", -2, 0)
    b.left:SetPoint("RIGHT", b.right, "LEFT", -2, 0)
    b.left:SetJustifyH("LEFT")
    if style.border then
        b:SetBackdrop({ edgeFile = Theme.WHITE, edgeSize = 1 })
        b:SetBackdropBorderColor(0, 0, 0, 1)
    else
        b:SetBackdrop(nil)
    end
end

-- icon width/height (non-square icons are cropped, not squashed) and border: none / black / class colour
local function styleIcon(b, style)
    local w, h = style.iconWidth or style.iconSize, style.iconHeight or style.iconSize
    b:SetSize(w, h)
    local inset = style.iconBorder == "none" and 0 or 1
    b.icon:ClearAllPoints()
    b.icon:SetPoint("TOPLEFT", inset, -inset)
    b.icon:SetPoint("BOTTOMRIGHT", -inset, inset)
    local l, r, t, bt = 0.08, 0.92, 0.08, 0.92
    if w > h then
        local span = 0.84 * h / w
        t, bt = 0.5 - span / 2, 0.5 + span / 2
    elseif h > w then
        local span = 0.84 * w / h
        l, r = 0.5 - span / 2, 0.5 + span / 2
    end
    b.icon:SetTexCoord(l, r, t, bt)
    if style.iconBorder == "none" then b:SetBackdropBorderColor(0, 0, 0, 0)
    elseif style.iconBorder == "black" then b:SetBackdropBorderColor(0, 0, 0, 1) end
    local size = math.min(w, h)
    local font, flags = Theme.FontPath(style.font), style.outline == "NONE" and "" or style.outline
    Theme.SetFont(b.right, font, math.max(8, math.floor(size * 0.42)), flags)
    Theme.SetFont(b.left, font, math.max(7, style.fontSize - 2), flags)
    b.left:SetShown(style.showNames)
end

local function classColor(style, e)
    local own = e.cfg and e.cfg.color
    if own then return own[1], own[2], own[3], own[4] or 1 end
    if style.colorMode == "custom" then
        local c = style.barColor
        return c[1], c[2], c[3], c[4] or 1
    end
    if style.colorMode == "wa" then
        local c = WA_CLASS[e.member.class or ""]
        if c then return c[1], c[2], c[3], 1 end
        return 0.753, 0.753, 0.753, 1
    end
    local r, g, b = ns.ClassColor(e.member.class)
    return r, g, b, 1
end

local function update(b, style)
    local e = b.entry
    local now = GetTime()
    local cd = e.member.cds[e.spell.id]
    local left = (cd and cd.expires > now) and (cd.expires - now) or 0
    local st = stateOf(e.member)
    local r, g, bl, a = classColor(style, e)
    if style.mode == "icons" then
        if style.iconBorder == "class" or style.iconBorder == nil then b:SetBackdropBorderColor(r, g, bl, 1) end
        if left > 0 then
            if b.cdStart ~= cd.expires then
                b.cdStart = cd.expires
                b.cooldown:SetCooldown(cd.expires - (cd.dur or left), cd.dur or left)
            end
            b.right:SetText(ns.Duration(left))
            b.icon:SetDesaturated(false)
        else
            if b.cdStart then b.cooldown:SetCooldown(0, 0); b.cdStart = nil end
            b.right:SetText("")
        end
        b.icon:SetDesaturated(st ~= nil)
        b:SetAlpha(st and 0.5 or 1)
        return left
    end
    local dur = cd and cd.dur or 1
    local value
    if left > 0 then
        local frac = math.min(1, math.max(0, left / math.max(dur, 1)))
        value = style.fill == "drain" and frac or (1 - frac)
        if style.cdColorMode == "custom" then
            local c = style.cdColor
            b.bar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
        elseif style.cdColorMode == "grey" then
            b.bar:SetStatusBarColor(0.35, 0.35, 0.35, 1)
        elseif style.cdColorMode == "same" then
            b.bar:SetStatusBarColor(r, g, bl, a)
        else
            b.bar:SetStatusBarColor(r * 0.5, g * 0.5, bl * 0.5, a)
        end
        b.right:SetText(style.showTime and ns.Duration(left) or "")
        local tc = style.textColor
        b.right:SetTextColor(tc[1], tc[2], tc[3], tc[4] or 1)
    else
        value = 1
        b.bar:SetStatusBarColor(r, g, bl, a)
        local showReady = style.showTime and (not style.hideReadyTime or st ~= nil or (style.readyText or "") ~= "")
        b.right:SetText(showReady and readyLabel(style, st) or "")
        local rc = st and Theme.colors.bad or style.readyColor
        b.right:SetTextColor(rc[1], rc[2], rc[3], rc[4] or 1)
    end
    b.bar:SetValue(value)
    if style.textColorMode == "class" then
        local cr, cg, cb = ns.ClassColor(e.member.class)
        b.left:SetTextColor(cr, cg, cb, 1)
    else
        local tc = style.textColor
        b.left:SetTextColor(tc[1], tc[2], tc[3], tc[4] or 1)
    end
    local alpha = 1
    if st then alpha = style.deadAlpha or 0.35
    elseif left <= 0 and style.fadeReady and ns.EncounterInProgress() then alpha = style.fadeAlpha or 0.1 end
    b:SetAlpha(alpha)
    if b.flash and GetTime() - b.flash < 0.6 then
        b:SetAlpha(0.4 + 0.6 * ((GetTime() - b.flash) / 0.6))
    end
    return left
end

local function visible()
    local s = settings()
    if not s.enabled or ns.Database.Settings().modules.cooldowns == false then return false end
    if Cooldowns.IsPreview() then return true end
    return IsInGroup() or s.showSolo
end

---------------------------------------------------------------------------
-- Unit frames of the group (any frame with a unit)
---------------------------------------------------------------------------
local frameCache, frameCacheTime = {}, 0
-- works with any unit frame addon: every visible frame
-- whose "unit" attribute is a group unit counts; group/party/raid frames win over the player frame.
-- An optional name hint (settings) lets one addon's frames win when several show the same player.
local function frameScore(f, hint)
    local name = f.GetName and f:GetName() or ""
    if name:find("NamePlate") or name:find("Target") or name:find("Focus") or name:find("Pet") then return nil end
    if f.GetEffectiveAlpha and (f:GetEffectiveAlpha() or 1) < 0.05 then return nil end
    local score = 1
    local lower = name:lower()
    if lower:find("party") or lower:find("group") or lower:find("raid") or lower:find("compact") then score = 3 end
    if hint and hint ~= "" and lower:find(hint, 1, true) then score = score + 10 end
    return score
end
local function scanUnitFrames()
    frameCache = {}
    frameCacheTime = GetTime()
    if not EnumerateFrames then return end
    local hint = (settings().frameHint or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local f = EnumerateFrames()
    local count = 0
    while f and count < 20000 do
        count = count + 1
        local ok, unit = pcall(function()
            if f.IsForbidden and f:IsForbidden() then return nil end
            if not f:IsVisible() then return nil end
            local u = f.GetAttribute and f:GetAttribute("unit") or f.unit
            return type(u) == "string" and u or nil
        end)
        if ok and unit and (unit == "player" or unit:find("^party%d") or unit:find("^raid%d")) then
            local score = frameScore(f, hint)
            if score then
                local guid = ns.Call(UnitGUID, unit)
                if guid then
                    local best = frameCache[guid]
                    local area = (f:GetWidth() or 0) * (f:GetHeight() or 0)
                    if not best or score > best.score or (score == best.score and area > best.area) then
                        frameCache[guid] = { frame = f, score = score, area = area }
                    end
                end
            end
        end
        f = EnumerateFrames(f)
    end
end
-- cached; the expensive scan over all frames runs only after a roster change,
-- a loading screen, or when a cached frame no longer shows that player.
-- Frames are matched by GUID (unit tokens shift when the roster changes).
local function stillValid(e, guid)
    local f = e.frame
    if not f:IsVisible() then return false end
    local u = (f.GetAttribute and f:GetAttribute("unit")) or f.unit
    return type(u) == "string" and ns.Call(UnitGUID, u) == guid
end
local frameRetries, frameRetryPending = 0, false
local FRAME_RESCAN, FRAME_RETRIES = 10, 3
function Bars.UnitFrame(unit, guid)
    guid = guid or (unit and ns.Call(UnitGUID, unit))
    if not guid then return nil end
    if frameCacheTime == 0 then scanUnitFrames() end
    local e = frameCache[guid]
    if e and stillValid(e, guid) then return e.frame end
    -- missing or moved: rescan, but at most every 10 s
    if GetTime() - frameCacheTime > FRAME_RESCAN then
        scanUnitFrames()
        e = frameCache[guid]
        if e and stillValid(e, guid) then return e.frame end
    end
    -- unit frames are often built a moment after a roster change or loading
    -- screen: look again once the rescan is allowed (a few times, then stop)
    if not frameRetryPending and frameRetries < FRAME_RETRIES then
        frameRetries = frameRetries + 1
        frameRetryPending = true
        ns.After(math.max(0.5, frameCacheTime + FRAME_RESCAN + 0.1 - GetTime()), function()
            frameRetryPending = false
            Bars.RequestLayout(0)
        end)
    end
    return nil
end
function Bars.RescanFrames() frameCacheTime = 0; frameRetries = 0 end
-- which frame was found for each group member (for the settings check)
function Bars.FoundFrames()
    scanUnitFrames()
    local out = {}
    local units = { "player" }
    local raid = IsInRaid and IsInRaid()
    for i = 1, raid and 40 or 4 do units[#units + 1] = (raid and "raid" or "party") .. i end
    for _, unit in ipairs(units) do
        local guid = ns.Call(UnitGUID, unit)
        if guid and not out[guid] then
            local e = frameCache[guid]
            out[guid] = true
            out[#out + 1] = { name = ns.Call(UnitName, unit), frame = e and (e.frame:GetName() or "?") or nil }
        end
    end
    return out
end

local ATTACH_POINTS = {
    -- side = { holder point, frame point, x sign, y sign }
    LEFT = { "RIGHT", "LEFT", -1, 0 }, RIGHT = { "LEFT", "RIGHT", 1, 0 },
    TOP = { "BOTTOM", "TOP", 0, 1 }, BOTTOM = { "TOP", "BOTTOM", 0, -1 },
}

-- Icons of one member next to that member's unit frame
local function layoutHolder(f, holder, uf, style, list)
    local side = ATTACH_POINTS[style.attachSide] and style.attachSide or "LEFT"
    local iw, ih, gap = style.iconWidth or style.iconSize, style.iconHeight or style.iconSize, style.spacing
    local perRow = math.max(1, style.iconsPerRow)
    local horizontal = side == "LEFT" or side == "RIGHT"
    local align = style.attachAlign or "TOP"
    holder:ClearAllPoints()
    holder:SetFrameStrata(uf:GetFrameStrata() or "MEDIUM")
    holder:SetFrameLevel((uf:GetFrameLevel() or 1) + 5)
    holder:SetScale(style.scale or 1)
    local hp, fp = ATTACH_POINTS[side][1], ATTACH_POINTS[side][2]
    if horizontal then
        local v = align == "BOTTOM" and "BOTTOM" or (align == "CENTER" and "" or "TOP")
        hp, fp = v .. hp, v .. fp
    else
        local h = align == "BOTTOM" and "RIGHT" or (align == "CENTER" and "" or "LEFT")
        hp, fp = hp .. h, fp .. h
    end
    -- attachX = gap to the frame, attachY = shift along the frame
    local gapX, shift = style.attachX or 0, style.attachY or 0
    if horizontal then holder:SetPoint(hp, uf, fp, gapX * ATTACH_POINTS[side][3], shift)
    else holder:SetPoint(hp, uf, fp, shift, gapX * ATTACH_POINTS[side][4]) end
    local rows = math.ceil(#list / perRow)
    local cols = math.min(perRow, #list)
    holder:SetSize(math.max(1, cols * (iw + gap) - gap), math.max(1, rows * (ih + gap) - gap))
    holder.items = holder.items or {}
    for i, e in ipairs(list) do
        local item = holder.items[i]
        if not item then item = createIcon(holder); item.mode = "icons"; holder.items[i] = item end
        styleIcon(item, style)
        item.left:SetShown(false)
        local slot = i - 1
        local c, r = slot % perRow, math.floor(slot / perRow)
        item:ClearAllPoints()
        -- the first icon sits next to the frame, the rest grow away from it
        if side == "LEFT" then item:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -c * (iw + gap), -r * (ih + gap))
        elseif side == "RIGHT" then item:SetPoint("TOPLEFT", holder, "TOPLEFT", c * (iw + gap), -r * (ih + gap))
        elseif side == "TOP" then item:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", c * (iw + gap), r * (ih + gap))
        else item:SetPoint("TOPLEFT", holder, "TOPLEFT", c * (iw + gap), -r * (ih + gap)) end
        item.entry = e
        item.icon:SetTexture(Spells.Icon(e.spell))
        item.left:SetText("")
        update(item, style)
        item:Show()
        f.attachedItems[#f.attachedItems + 1] = item
    end
    for i = #list + 1, #holder.items do holder.items[i]:Hide(); holder.items[i].entry = nil end
    holder:Show()
end

-- Splits entries: members with a unit frame get their icons there, the rest stay in the display
local function attachEntries(f, style, columns)
    f.holders = f.holders or {}
    f.attachedItems = {}
    local perMember, rest, used = {}, {}, {}
    local keys = {}
    for c in pairs(columns) do keys[#keys + 1] = c end
    table.sort(keys)
    for _, c in ipairs(keys) do
        for _, e in ipairs(columns[c]) do
            local uf = e.member.unit and Bars.UnitFrame(e.member.unit, e.member.guid)
            if uf then
                local k = e.member.key
                perMember[k] = perMember[k] or { frame = uf, list = {} }
                table.insert(perMember[k].list, e)
            else
                rest[c] = rest[c] or {}
                table.insert(rest[c], e)
            end
        end
    end
    for k, data in pairs(perMember) do
        local holder = f.holders[k]
        if not holder then holder = CreateFrame("Frame", nil, UIParent); f.holders[k] = holder end
        layoutHolder(f, holder, data.frame, style, data.list)
        used[k] = true
    end
    for k, holder in pairs(f.holders) do if not used[k] then holder:Hide() end end
    return rest
end

local function hideHolders(f)
    for _, holder in pairs(f.holders or {}) do holder:Hide() end
    f.attachedItems = {}
end

-- Display conditions (group type, instance type, combat). Preview ignores them.
function Bars.ConditionsMet(style)
    if Cooldowns.IsPreview() then return true end
    local raid, party = IsInRaid(), IsInGroup()
    -- icons on the group frames: only in a 5-man party – never in a raid, never solo
    if style.attach and (raid or not party) then return false end
    if raid then
        if not style.whenRaid then return false end
    elseif party then
        if not style.whenParty then return false end
    elseif not style.whenSolo then
        return false
    end
    if style.where and style.where ~= "any" then
        local inside, kind = IsInInstance()
        if style.where == "instance" and not inside then return false end
        if style.where == "dungeon" and kind ~= "party" then return false end
        if style.where == "raid" and kind ~= "raid" then return false end
        if style.where == "world" and inside then return false end
    end
    local fighting = InCombatLockdown() or UnitAffectingCombat("player")
    if style.combat == "combat" and not fighting then return false end
    if style.combat == "nocombat" and fighting then return false end
    return true
end

function Bars.Layout()
    local show = visible()
    local s = settings()
    local seen = {}
    for index, key in ipairs(Bars.Keys()) do
        seen[key] = true
        local style = Bars.Display(key)
        local f = frames[key] or createDisplay(key)
        placeAnchor(f, index)
        f:SetScale(style.scale or 1)
        f.mode = style.mode
        f.title.text:SetText(style.name)
        local active = show and style.enabled and Bars.ConditionsMet(style)
        local columns = active and entriesFor(key, style) or {}
        if active and style.mode == "icons" and style.attach then
            columns = attachEntries(f, style, columns)
            -- while moving, the box only stands for players without a visible frame:
            -- a compact sample (two rows) instead of everyone's icons in a long strip
            if not s.locked then
                local sample, limit = {}, math.max(1, style.iconsPerRow or 4) * 2
                local keys = {}
                for c in pairs(columns) do keys[#keys + 1] = c end
                table.sort(keys)
                for _, c in ipairs(keys) do
                    for _, e in ipairs(columns[c]) do
                        if #sample < limit then sample[#sample + 1] = e end
                    end
                end
                columns = #sample > 0 and { sample } or {}
            end
        else
            hideHolders(f)
        end
        local itemW = style.mode == "icons" and (style.iconWidth or style.iconSize) or (style.width + (style.showIcon and style.height or 0))
        local itemH = style.mode == "icons" and ((style.iconHeight or style.iconSize) + (style.showNames and style.fontSize + 2 or 0)) or style.height
        local perRow = style.mode == "icons" and math.max(1, style.iconsPerRow) or 1
        local colWidth = style.mode == "icons" and (perRow * (itemW + style.spacing) - style.spacing) or itemW
        local maxCol = 0
        for c in pairs(columns) do maxCol = math.max(maxCol, c) end
        local used, x, n, maxHeight = 0, 0, 0, 0
        for c = 1, maxCol do
            local list = columns[c]
            if list and #list > 0 or not style.collapse then
                for i, e in ipairs(list or {}) do
                    n = n + 1
                    local item = f.items[n]
                    if item and item.mode ~= style.mode then item:Hide(); item = nil end
                    if not item then
                        item = style.mode == "icons" and createIcon(f) or createBar(f)
                        item.mode = style.mode
                        f.items[n] = item
                    end
                    if style.mode == "icons" then styleIcon(item, style) else styleBar(item, style) end
                    local slot = i - 1
                    local cx = x + (slot % perRow) * (itemW + style.spacing)
                    local cy = math.floor(slot / perRow) * (itemH + style.spacing)
                    item:ClearAllPoints()
                    if style.grow == "UP" then item:SetPoint("BOTTOMLEFT", f, "TOPLEFT", cx, cy)
                    else item:SetPoint("TOPLEFT", f, "TOPLEFT", cx, -cy) end
                    maxHeight = math.max(maxHeight, cy + itemH)
                    item.entry = e
                    item.icon:SetTexture(Spells.Icon(e.spell))
                    item.left:SetText(style.mode == "icons" and (Names.Display(e.member.name):match("^(%S+)") or "") or labelText(style, e))
                    update(item, style)
                    item:Show()
                end
                used = used + 1
                x = x + colWidth + style.colSpacing
            end
        end
        for i = n + 1, #f.items do f.items[i]:Hide(); f.items[i].entry = nil end
        f:SetSize(math.max(colWidth, x - style.colSpacing), math.max(1, maxHeight))
        f.style = style
        f.title:SetWidth(math.max(120, x - style.colSpacing))
        -- the name sits inside the placeholder while moving (so the frame's real
        -- edge is what snaps); above the bars only if wanted, and click-through
        f.title:SetShown(s.locked and style.nameAbove and active and n > 0 or false)
        f.title:EnableMouse(false)
        f:SetShown(active and (n > 0 or not s.locked))
        local moving = not s.locked and active
        f.mover:SetShown(moving)
        if moving and n == 0 then f:SetSize(math.max(150, f:GetWidth() or 0), 24) end
        if moving then
            f.mover:ClearAllPoints()
            f.mover:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
            f.mover:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
            f.mover.fillAlpha = 0.55
            ns.Movers.StyleOverlay(f.mover, style.attach and style.mode == "icons" and (style.name .. " · " .. L.CD_ATTACH_MOVER) or style.name, nil, "timer")
        end
    end
    for key, f in pairs(frames) do if not seen[key] then f:Hide() end end
    -- the 0.1 s timer only runs while bars or icons are on screen
    local busy = false
    for _, f in pairs(frames) do
        if (f:IsShown() and #f.items > 0) or (f.attachedItems and #f.attachedItems > 0) then busy = true; break end
    end
    if Bars.ticker then Bars.ticker:SetShown(busy) end
end

local ticker = CreateFrame("Frame")
ticker:Hide()
Bars.ticker = ticker
local acc = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.1 then return end
    acc = 0
    local relayout = false
    for _, f in pairs(frames) do
        for _, item in ipairs(f.attachedItems or {}) do
            if item:IsShown() and item.entry and f.style then update(item, f.style) end
        end
        if f:IsShown() and f.style then
            for _, item in ipairs(f.items) do
                if item:IsShown() and item.entry then
                    local left = update(item, f.style)
                    -- an expiring bar changes the order or disappears
                    if left <= 0 and item.entry.left > 0 and (f.style.hideReady or f.style.sort ~= "name") then relayout = true end
                end
            end
        end
    end
    if relayout then Bars.RequestLayout(0.2) end
end)

function Bars.ResetPosition(key)
    settings().pos[key] = nil
    if frames[key] then frames[key].positioned = false end
    Bars.Layout()
end

-- Throttled, not debounced: casts, roster and combat events can come in
-- faster than any debounce delay in a raid, which used to hold the layout back
-- until things calmed down (bars appeared late or all at once). A request
-- runs at most `delay` seconds later; an earlier pending run covers it.
local layoutTimer, layoutAt = nil, nil
function Bars.RequestLayout(delay)
    local at = GetTime() + (delay or 0.15)
    if layoutTimer and layoutAt <= at then return end
    if layoutTimer then layoutTimer:Cancel() end
    layoutAt = at
    layoutTimer = C_Timer.NewTimer(math.max(0, at - GetTime()), function()
        layoutTimer, layoutAt = nil, nil
        ns.Safe(Bars.Layout)
    end)
end

ns.On("LG_COOLDOWNS", function() Bars.RequestLayout(0.25) end)
ns.On("LG_THEME", function() Bars.RequestLayout(0.15) end)
ns.On("LG_READY", function() ns.After(4, Bars.Layout) end)
-- conditions depend on combat and group changes
ns.On("PLAYER_REGEN_DISABLED", function() Bars.RequestLayout(0.05) end)
ns.On("PLAYER_REGEN_ENABLED", function() Bars.RequestLayout(0.3) end)
-- the roster itself is rebuilt by the tracker, which then fires LG_COOLDOWNS
ns.On("GROUP_ROSTER_UPDATE", function() Bars.RescanFrames(); Bars.RequestLayout(1) end)
-- unit frames are rebuilt after loading screens and roster changes
ns.On("PLAYER_ENTERING_WORLD", function() Bars.RescanFrames(); Bars.RequestLayout(1) end)
ns.On("ZONE_CHANGED_NEW_AREA", function() Bars.RequestLayout(1) end)
