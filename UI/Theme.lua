-- Color themes, fonts and textures. Everything created through the widget kit
-- is registered, so a theme or font change applies live.
local _, ns = ...
local Theme = {}
ns.Theme = Theme

Theme.WHITE = "Interface\\Buttons\\WHITE8X8"
Theme.ICONS = "Interface\\AddOns\\LiebeGruesse\\Media\\Icons\\"

-- Color roles. "gold" is the accent used for headings and highlights.
Theme.ROLES = { "bg", "sidebar", "header", "panel", "row", "rowAlt", "input", "hover", "selected", "border", "borderDim",
    "gold", "accent", "accentDim", "text", "textDim", "muted", "good", "warn", "bad", "button", "buttonHot",
    "bronze", "bronzeDim", "lapis", "tier1", "tier2", "tier3", "tier4", "tier5", "tier6", "tier7", "tier8" }

local function hex(h, a)
    h = h:gsub("#", "")
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, a or 1 }
end

local function mix(c1, c2, t)
    return { c1[1] + (c2[1] - c1[1]) * t, c1[2] + (c2[2] - c1[2]) * t, c1[3] + (c2[3] - c1[3]) * t, 1 }
end

-- Graphite bases (neutral, not too dark); the accent colors headings, toggles, sliders and selection
local BASES = {
    charcoal = {
        bg = "#17191d", sidebar = "#121417", header = "#1d2025", panel = "#20242a", row = "#20242a", rowAlt = "#1b1e23",
        input = "#141619", border = "#3d424b", borderDim = "#2d3138", text = "#f0f1f3", textDim = "#b0b5bd",
        muted = "#868b94", button = "#2c3037", buttonHot = "#363b43",
    },
    navy = {
        bg = "#161a21", sidebar = "#11141a", header = "#1c2129", panel = "#20252e", row = "#20252e", rowAlt = "#1b1f27",
        input = "#13161c", border = "#3a414e", borderDim = "#2b313b", text = "#f0f2f6", textDim = "#aeb4c0",
        muted = "#848b99", button = "#2a303a", buttonHot = "#343b47",
    },
}

local function build(baseKey, accentHex)
    local base, accent = BASES[baseKey], hex(accentHex)
    local c = {}
    for role, value in pairs(base) do c[role] = hex(value) end
    c.gold, c.accent = accent, accent
    c.accentDim = mix(c.panel, accent, 0.22)
    c.selected = { accent[1], accent[2], accent[3], 0.16 }
    c.hover = { 1, 1, 1, 0.05 }
    c.good, c.warn, c.bad = hex("#5fd068"), hex("#ffb03a"), hex("#ed6c63")
    -- ornament colors taken from the logo (bronze frame, lapis center); same in every theme
    c.bronze, c.bronzeDim, c.lapis = hex("#b98a52"), hex("#6e5233"), hex("#4c86c9")
    -- achievement tiers: bronze, silver, gold, platinum, emerald, diamond, master, challenger
    c.tier1, c.tier2, c.tier3, c.tier4 = hex("#c08a52"), hex("#c6ced8"), hex("#f2c64e"), hex("#86e0d4")
    c.tier5, c.tier6, c.tier7, c.tier8 = hex("#3fd27a"), hex("#8fd3ff"), hex("#b97dff"), hex("#ff5c8a")
    return c
end

-- colourways: name + one short line (shown in the theme menu)
Theme.PRESETS = {
    { key = "ember", name = "Ember", desc = "Glowing coals", colors = build("charcoal", "#ff8f32") },
    { key = "lg", name = "Liebe Grüße", desc = "The guild's own gold", colors = build("navy", "#e8c27a") },
    { key = "fel", name = "Emerald", desc = "Dreaming green", colors = build("charcoal", "#95fe32") },
    { key = "gold", name = "Radiance", desc = "Warm holy light", colors = build("charcoal", "#ffcc48") },
    { key = "rose", name = "Love Letter", desc = "Rose-pink greetings", colors = build("charcoal", "#ff6fab") },
    { key = "void", name = "Arcane", desc = "Violet spellfire", colors = build("charcoal", "#8474ff") },
    { key = "frost", name = "Moonwell", desc = "Cool moonlight", colors = build("charcoal", "#8dabff") },
    { key = "blood", name = "Crimson", desc = "Deep battle red", colors = build("charcoal", "#fb2132") },
}
local presetByKey = {}
for _, p in ipairs(Theme.PRESETS) do presetByKey[p.key] = p end
Theme.DEFAULT = "ember"

Theme.colors = presetByKey[Theme.DEFAULT].colors

---------------------------------------------------------------------------
-- Media: client fonts/textures plus LibSharedMedia when another addon has it
---------------------------------------------------------------------------
-- Expressway is not shipped with this addon (its license does not allow it).
-- It is the default when another installed addon provides it (or your own
-- copy at Media\Fonts\Expressway.ttf); otherwise the shipped Barlow is used.
local EXPRESSWAY = {
    "Interface\\AddOns\\LiebeGruesse\\Media\\Fonts\\Expressway.ttf",
    "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF",
    "Interface\\AddOns\\ElvUI\\Core\\Media\\Fonts\\Expressway.ttf",
    "Interface\\AddOns\\ElvUI\\Media\\Fonts\\Expressway.ttf",
    "Interface\\AddOns\\FojjiCore\\font\\Expressway.ttf",
}
local FALLBACK_FONT = "Fonts\\ARIALN.TTF"
-- Barlow ships with the addon (SIL Open Font License, see Licenses): text in
-- Barlow Semi Condensed, titles, numbers and small caps in Barlow Condensed
local FONT_DIR = ns.media .. "Fonts\\"   -- follows the real addon folder name
local BARLOW = FONT_DIR .. "BarlowSemiCondensed-Medium.ttf"
local BARLOW_HEAD = FONT_DIR .. "BarlowCondensed-SemiBold.ttf"
-- weight "strong" (default): one step heavier – the game renders thinner than a browser
local WEIGHTS = {
    normal = { FONT_DIR .. "BarlowSemiCondensed-Medium.ttf", FONT_DIR .. "BarlowCondensed-SemiBold.ttf" },
    strong = { FONT_DIR .. "BarlowSemiCondensed-SemiBold.ttf", FONT_DIR .. "BarlowCondensed-Bold.ttf" },
    bold = { FONT_DIR .. "BarlowSemiCondensed-Bold.ttf", FONT_DIR .. "BarlowCondensed-ExtraBold.ttf" },
}
-- Preload every shipped cut during the loading screen: a font file the client
-- sees for the first time later can leave new text blank until it is set again
do
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(1, 1); holder:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 10, -10)
    for _, w in pairs(WEIGHTS) do
        for _, path in ipairs(w) do
            local fs = holder:CreateFontString(nil, "OVERLAY")
            pcall(fs.SetFont, fs, path, 12, "")
            fs:SetPoint("TOPLEFT")
            pcall(fs.SetText, fs, "Aa")
        end
    end
end
local FONTS = {
    { key = "Expressway", path = EXPRESSWAY[1] },
    { key = "Barlow", path = BARLOW },
    { key = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { key = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { key = "Skurri", path = "Fonts\\SKURRI.TTF" },
    { key = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
}
local TEXTURES = {
    { key = "Flat", path = "Interface\\Buttons\\WHITE8X8" },
    { key = "Blizzard", path = "Interface\\TargetingFrame\\UI-StatusBar" },
    { key = "Raid", path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { key = "Gloss", path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
}

local function lsm()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

local function mediaList(builtIn, kind)
    local list, seen = {}, {}
    for _, m in ipairs(builtIn) do
        local path = m.path
        local text = m.key
        if kind == "font" then
            path = Theme.FontPath(m.key)
            if m.key == "Expressway" and not Theme.HasExpressway() then text = m.key .. " (" .. (ns.L.FONT_EXPRESSWAY_MISSING or "?") .. ")" end
        end
        list[#list + 1] = { value = m.key, text = text, path = path }
        seen[m.key] = true
    end
    local media = lsm()
    if media and media.HashTable then
        local hash = media:HashTable(kind) or {}
        local names = {}
        for name in pairs(hash) do if not seen[name] then names[#names + 1] = name end end
        table.sort(names)
        for _, name in ipairs(names) do list[#list + 1] = { value = name, text = name, path = hash[name] } end
    end
    return list
end

function Theme.Fonts() return mediaList(FONTS, "font") end
function Theme.Textures() return mediaList(TEXTURES, "statusbar") end

local function resolve(builtIn, kind, key, fallback)
    for _, m in ipairs(builtIn) do if m.key == key then return m.path end end
    local media = lsm()
    if media and key and media.IsValid and media:IsValid(kind, key) then return media:Fetch(kind, key) end
    return fallback
end

-- Checks whether a font file exists by loading it into a hidden font string
local probe, valid = nil, {}
local function fontWorks(path)
    if valid[path] ~= nil then return valid[path] end
    if not probe then
        local holder = CreateFrame("Frame")
        holder:Hide()
        probe = holder:CreateFontString()
    end
    probe:SetFont(FALLBACK_FONT, 12, "")
    local ok, set = pcall(probe.SetFont, probe, path, 12, "")
    local current = ok and probe:GetFont()
    Theme.lastProbe = { path = path, ok = ok, set = set, current = current }
    if not ok or set == false then valid[path] = false; return false end
    if set == true then valid[path] = true; return true end
    -- older clients return nothing: compare the path (the client may switch slashes or case)
    local function norm(p) return type(p) == "string" and p:gsub("/", "\\"):lower() or nil end
    local cur = norm(current)
    valid[path] = cur ~= nil and (cur == norm(path) or cur ~= norm(FALLBACK_FONT)) or false
    return valid[path]
end

local function expressway()
    local media = lsm()
    if media and media.IsValid and media:IsValid("font", "Expressway") then
        local path = media:Fetch("font", "Expressway")
        if path and fontWorks(path) then return path end
    end
    for _, path in ipairs(EXPRESSWAY) do
        if fontWorks(path) then return path end
    end
end

function Theme.HasExpressway() return expressway() ~= nil end

function Theme.FontPath(key)
    if key == "Expressway" then return expressway() or FALLBACK_FONT end
    local path = resolve(FONTS, "font", key, FALLBACK_FONT)
    if path ~= FALLBACK_FONT and not path:find("^Fonts") and path:sub(1, #FONT_DIR) ~= FONT_DIR and not fontWorks(path) then return FALLBACK_FONT end
    return path
end

local LEGACY_TEXTURE = { fojjiBlank = "Flat", fojjiFlat = "Flat", Flach = "Flat", Glanz = "Gloss" }   -- old keys
Theme.LEGACY_TEXTURE = LEGACY_TEXTURE
function Theme.TexturePath(key)
    local media = lsm()
    if LEGACY_TEXTURE[key] and not (media and media:IsValid("statusbar", key)) then key = LEGACY_TEXTURE[key] end
    return resolve(TEXTURES, "statusbar", key, Theme.WHITE)
end

-- icons come in 16, 32 and 64 px (rendered at that size, not scaled down);
-- the smallest file that is at least as big as the icon on screen is used
local NO_SMALL = { ["portrait-ring"] = true }
local function pixelsPerUnit()
    local _, h = ns.Call(GetPhysicalScreenSize)
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local t = ns.db and ns.db.settings and ns.db.settings.theme
    return ((tonumber(h) or 1080) / 768) * (tonumber(scale) or 1) * ((t and t.windowScale) or 1)
end
function Theme.IconSize(size)
    if not size then return 32 end
    local px = size * pixelsPerUnit()
    return px <= 16 and 16 or (px <= 32 and 32 or 64)
end
-- path (without extension) and file size in px
function Theme.IconFile(name, size)
    local dim = NO_SMALL[name] and 64 or Theme.IconSize(size)
    if dim == 64 then return Theme.ICONS .. name, 64 end
    return Theme.ICONS .. dim .. "\\" .. name, dim
end
function Theme.Icon(name, size) return (Theme.IconFile(name, size)) end
-- sets an icon on a texture in the file size that fits the texture's size
function Theme.SetIcon(tex, name)
    local w = tex.GetWidth and tex:GetWidth() or 0
    tex:SetTexture(Theme.Icon(name, (w and w > 0) and w or nil))
end

---------------------------------------------------------------------------
-- Settings access
---------------------------------------------------------------------------
local function settings()
    return ns.db and ns.db.settings.theme
end

-- head = true for titles, numbers and small upper-case labels
function Theme.Font(head)
    local s = settings()
    local key = s and s.font or FONTS[1].key
    -- Expressway is the default; without a copy on this client: Barlow
    if key == "Expressway" and not Theme.HasExpressway() then key = "Barlow" end
    if key == "Barlow" then
        -- shipped with the addon: used directly; Theme.SetFont falls back per font string
        -- if the client refuses the file (new files need a full game restart, not /reload)
        local w = WEIGHTS[s and s.weight or "strong"] or WEIGHTS.strong
        return w[head and 2 or 1]
    end
    return Theme.FontPath(key)
end

-- Sets a font and falls back to Arial Narrow only when the client refuses the file
Theme.refused = {}
function Theme.SetFont(fs, path, size, flags)
    local ok, set = pcall(fs.SetFont, fs, path, size, flags or "")
    if not ok or set == false then
        Theme.refused[path] = true
        fs:SetFont(FALLBACK_FONT, size, flags or "")
        return false
    end
    return true
end

-- offer the shipped fonts to other addons through LibSharedMedia (when one loads it)
local function registerMedia()
    local media = lsm()
    if not media or Theme.mediaRegistered then return end
    Theme.mediaRegistered = true
    local names = {
        { "Barlow", WEIGHTS.normal[1] }, { "Barlow SemiBold", WEIGHTS.strong[1] }, { "Barlow Bold", WEIGHTS.bold[1] },
        { "Barlow Condensed SemiBold", WEIGHTS.normal[2] }, { "Barlow Condensed Bold", WEIGHTS.strong[2] },
        { "Barlow Condensed ExtraBold", WEIGHTS.bold[2] },
    }
    local all = (media.LOCALE_BIT_western or 0) + (media.LOCALE_BIT_ruRU or 0)
    for _, n in ipairs(names) do pcall(media.Register, media, "font", n[1], n[2], all > 0 and all or nil) end
end
Theme.RegisterMedia = registerMedia
if ns.On then ns.On("PLAYER_LOGIN", registerMedia) end

-- /lg test font: which files load, which ones are in use
function Theme.FontReport()
    local s = settings()
    ns.Print(("font = %s, weight = %s"):format(tostring(s and s.font), tostring(s and s.weight or "strong")))
    for _, key in ipairs({ "normal", "strong", "bold" }) do
        for i, path in ipairs(WEIGHTS[key]) do
            valid[path] = nil
            local ok = fontWorks(path)
            ns.Print(("  %s %s: %s %s"):format(key, i == 1 and "text" or "head", ok and "|cff5fd068ok|r" or "|cffed6c63missing|r", path:match("[^\\]+$")))
            local p = Theme.lastProbe
            if p then ns.Print(("    SetFont=%s GetFont=%s"):format(tostring(p.set), tostring(p.current))) end
        end
    end
    ns.Print("  in use: " .. tostring(Theme.Font():match("[^\\]+$")) .. " / " .. tostring(Theme.Font(true):match("[^\\]+$")))
    local window = _G.LiebeGruesseMainWindow
    local sample = window and window.title or nil
    if sample and sample.GetFont then ns.Print("  window title: " .. tostring((sample:GetFont()))) end
    local refused = {}
    for path in pairs(Theme.refused) do refused[#refused + 1] = path:match("[^\\]+$") end
    ns.Print("  refused by the client: " .. (#refused > 0 and table.concat(refused, ", ") or "none"))
    ns.Print("  folder: " .. FONT_DIR)
    ns.Print(ns.L.SET_WEIGHT_TIP)
end

function Theme.FontSize(size)
    local s = settings()
    return math.max(6, math.floor((size or 12) * (s and s.fontScale or 1) + 0.5))
end

-- "Name  short line" with the name in the theme's accent (theme menu)
function Theme.PresetLabel(p)
    local a = p.colors.accent
    local m = p.colors.muted
    return ns.Hex(a[1], a[2], a[3], p.name) .. "   " .. ns.Hex(m[1], m[2], m[3], p.desc or "")
end

function Theme.Color(name)
    local c = Theme.colors[name] or Theme.colors.text
    return c[1], c[2], c[3], c[4]
end

-- opening colour code for search highlights
function ns.HighlightCode(role)
    local r, g, b = Theme.Color(role or "accent")
    return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

function Theme.HexColor(name, text)
    local r, g, b = Theme.Color(name)
    return ns.Hex(r, g, b, text)
end

-- One-time move of v0.1/v0.2 settings to the new look
function Theme.Migrate()
    local s = settings()
    if not s or s.v3 then return end
    s.v3 = true
    if s.preset == "lg" or s.preset == nil or not presetByKey[s.preset] then s.preset = Theme.DEFAULT end
    s.colors = {}
    if s.font == "Friz Quadrata" or not s.font then s.font = "Expressway" end
    s.fontScale = s.fontScale or 0.95
    s.windowAlpha = s.windowAlpha or 1
    s.windowScale = s.windowScale or 1
end

-- v1.0.64: Expressway is the default again (Barlow when the client has no copy)
function Theme.Migrate6()
    local s = settings()
    if not s or s.v6 then return end
    s.v6 = true
    if s.font == "Barlow" or not s.font then s.font = "Expressway" end
end

-- v1.0.20: the shipped Barlow becomes the default font (Appearance can switch back)
function Theme.Migrate5()
    local s = settings()
    if not s or s.v5 then return end
    s.v5 = true
    if s.font == "Expressway" or s.font == "Arial Narrow" or not s.font then s.font = "Barlow" end
end

-- v0.4: Expressway becomes the default font
function Theme.Migrate4()
    local s = settings()
    if not s or s.v4 then return end
    s.v4 = true
    if s.font == "Arial Narrow" or not s.font then s.font = "Expressway" end
end

function Theme.Load()
    local s = settings()
    local base = presetByKey[s and s.preset or Theme.DEFAULT] or presetByKey[Theme.DEFAULT]
    local colors = {}
    for _, role in ipairs(Theme.ROLES) do
        local c = (s and s.colors and s.colors[role]) or base.colors[role]
        colors[role] = { c[1], c[2], c[3], c[4] or 1 }
    end
    -- the accent override also drives the derived accent roles
    local accent = s and s.colors and (s.colors.accent or s.colors.gold)
    if accent then
        colors.gold, colors.accent = { accent[1], accent[2], accent[3], 1 }, { accent[1], accent[2], accent[3], 1 }
        if not s.colors.selected then colors.selected = { accent[1], accent[2], accent[3], 0.16 } end
        if not s.colors.accentDim then colors.accentDim = mix(colors.panel, accent, 0.22) end
    end
    Theme.colors = colors
end

---------------------------------------------------------------------------
-- Registry: widgets remember their color role and font size
---------------------------------------------------------------------------
local skins = setmetatable({}, { __mode = "k" })
local fills = setmetatable({}, { __mode = "k" })
local texts = setmetatable({}, { __mode = "k" })
local hooks = {}

function Theme.RegisterSkin(frame, bg, border) skins[frame] = { bg, border } end
function Theme.RegisterFill(tex, role) fills[tex] = role end
-- sets font and text of every theme text below `root` again (forces a redraw)
function Theme.Refont(root)
    local font, headFont = Theme.Font(), Theme.Font(true)
    for fs, info in pairs(texts) do
        local p = fs:GetParent()
        while p and p ~= root do p = p:GetParent() end
        if p == root then
            Theme.SetFont(fs, info[4] and headFont or font, Theme.FontSize(info[1]), info[3] or "")
            local t = fs:GetText()
            if t then fs:SetText(""); fs:SetText(t) end
        end
    end
end

function Theme.RegisterText(fs, size, role, flags, head) texts[fs] = { size, role, flags, head } end
-- fn() is called after every theme change (for widgets with own color logic)
function Theme.OnApply(fn) hooks[#hooks + 1] = fn end

function Theme.Apply()
    Theme.Load()
    local font, headFont = Theme.Font(), Theme.Font(true)
    for frame, roles in pairs(skins) do
        if frame.SetBackdropColor then
            frame:SetBackdropColor(Theme.Color(roles[1]))
            frame:SetBackdropBorderColor(Theme.Color(roles[2]))
        end
    end
    for tex, role in pairs(fills) do tex:SetVertexColor(Theme.Color(role)) end
    for fs, info in pairs(texts) do
        Theme.SetFont(fs, info[4] and headFont or font, Theme.FontSize(info[1]), info[3] or "")
        if info[2] then fs:SetTextColor(Theme.Color(info[2])) end
    end
    for _, fn in ipairs(hooks) do ns.Safe(fn) end
    ns.Fire("LG_THEME")
end

function Theme.SetPreset(key)
    local s = settings()
    s.preset = key
    s.colors = {}
    Theme.Apply()
end

function Theme.SetColor(role, r, g, b, a)
    local s = settings()
    s.colors = s.colors or {}
    s.colors[role] = { r, g, b, a or 1 }
    Theme.Apply()
end
