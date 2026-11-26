-- Live blessing status on the bar, also in combat.
-- In combat the game hides aura data from addons, so the bar's counts can only
-- show the last known state. The game can still draw auras itself: per group
-- member a native aura container ("Blizzard_AuraContainer") with one slot that
-- only accepts the row's blessing (every rank, single and greater). A thin
-- strip at the bottom of each row has one segment per player: red underneath,
-- the game draws green on top while the blessing is on that player.
-- Display only: nothing here reads back what the game draws (that would be a
-- hidden value). Containers, units and filters change only outside of combat.
-- Without the native container (or after any error) nothing is shown and the
-- bar works exactly as before.
local _, ns = ...
local L = ns.L
local B = ns.Blessings
local Native = {}
ns.BlessNative = Native

local STRIP_H = 3
local MAX_SEGMENTS = 15
local WHITE = "Interface\\Buttons\\WHITE8X8"

local state          -- nil = not tried yet, true = ready, false = unavailable
local reason         -- why it is unavailable
local segs = {}      -- [row][i] = segment
local active = 0     -- segments currently enabled
local suspended = false
local filters = {}   -- [blessing] = { filter, signature }

local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function enabledSetting() return B.Settings().live ~= false end

local function fail(why)
    state, reason = false, tostring(why or "unknown")
    for _, list in pairs(segs) do
        for _, seg in pairs(list) do
            pcall(function()
                if seg.enabled then seg.container:SetAuraSlotEnabled(seg.key, false) end
                seg.container:SetEnabled(false)
                seg.base:Hide()
            end)
            seg.enabled = false
        end
    end
    active = 0
end

-- loads the game's aura container once (outside of combat)
function Native.Ready()
    if state ~= nil then return state end
    if inCombat() then return false end
    if not (C_AddOns and C_AddOns.LoadAddOn and C_XMLUtil and C_XMLUtil.GetTemplateInfo) then
        state, reason = false, "no aura container in this client"
        return false
    end
    local ok, loaded, why = pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    if not ok or not loaded then
        state, reason = false, "Blizzard_AuraContainer: " .. tostring(ok and why or loaded)
        return false
    end
    local okT, info = pcall(C_XMLUtil.GetTemplateInfo, "CustomAuraContainerTemplate")
    if not okT or not info then
        state, reason = false, "missing CustomAuraContainerTemplate"
        return false
    end
    if not (AuraContainerSortMethod and Enum and Enum.CustomAuraButtonDispelTypeTextureStyle) then
        state, reason = false, "missing aura container enums"
        return false
    end
    state = true
    return true
end

-- learned ids (Blessings.Learn): build the filters again, segments follow at the next layout
function Native.ResetFilters() wipe(filters) end

-- spell ids of a blessing: every rank, single and greater
local function filterFor(blessing)
    local f = filters[blessing]
    if f then return f[1], f[2] end
    local b = B.BY_KEY[blessing]
    local ids, sorted = {}, {}
    for _, kind in ipairs({ "single", "greater" }) do
        for _, id in ipairs(b and b[kind] or {}) do
            if not ids[id] then ids[id] = true; sorted[#sorted + 1] = id end
        end
    end
    table.sort(sorted)
    f = { { includeSpellIDs = ids }, table.concat(sorted, ",") }
    filters[blessing] = f
    return f[1], f[2]
end

local function color(key)
    local r, g, b = ns.Theme.Color(key)
    return r or 1, g or 1, b or 1
end

-- one segment: anchor frame (ours), container with a red base and one slot
local function newSegment(row, i)
    local anchor = CreateFrame("Frame", nil, UIParent)
    anchor:EnableMouse(false)
    local container = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    container:EnableMouse(false)
    if container.EnableMouseWheel then container:EnableMouseWheel(false) end
    container:SetSize(1, 1)
    container:SetPoint("TOPLEFT", anchor, "TOPLEFT")
    container:SetEnabled(false)
    local seg = { anchor = anchor, container = container, key = (row:GetName() or "LGBlessRow") .. "Seg" .. i, enabled = false }
    local base = container:CreateTexture(nil, "BACKGROUND")
    base:SetAllPoints(anchor)
    base:SetColorTexture(color("bad"))
    base:Hide()
    seg.base = base
    local gr, gg, gb = color("good")
    container:AddAuraSlot(seg.key, "HELPFUL", {
        candidateFilters = { includeSpellIDs = {} },
        sortMethod = AuraContainerSortMethod.ExpirationOnly,
        initializeFrame = function(frame)
            frame:EnableMouse(false)
            if frame.EnableMouseWheel then frame:EnableMouseWheel(false) end
            frame:SetAllPoints(anchor)
            -- only the colour tile: no icon, count or border on a 3 px strip
            for _, k in ipairs({ "Icon", "Count", "Border", "Cooldown", "Duration" }) do
                local region = rawget(frame, k)
                if type(region) == "table" and region.SetAlpha then pcall(region.SetAlpha, region, 0) end
            end
            local tile = frame:CreateTexture(nil, "BACKGROUND")
            tile:SetAllPoints(frame)
            local asset = { asset = WHITE, texCoords = { left = 0, right = 1, top = 0, bottom = 1 } }
            local assets, colors = {}, {}
            local c = CreateColor(gr, gg, gb, 1)
            for _, kind in ipairs({ "None", "Magic", "Curse", "Disease", "Poison", "Enrage", "Bleed" }) do
                assets[kind], colors[kind] = asset, c
            end
            frame:AddDispelTypeTexture(tile, {
                showAlways = true,
                style = Enum.CustomAuraButtonDispelTypeTextureStyle.CustomAsset,
                customDispelAssetMap = assets, customDispelColorMap = colors,
            })
            seg.frame = frame
        end,
    })
    -- the game reports errors in initializeFrame without passing them on
    if not seg.frame then error("aura slot could not be created") end
    return seg
end

local function disable(seg)
    if seg.enabled then
        seg.container:SetAuraSlotEnabled(seg.key, false)
        seg.container:SetEnabled(false)
        seg.enabled = false
        active = active - 1
    end
    seg.base:Hide()
end

local function place(seg, row, i, n, unit, blessing)
    local width = row:GetWidth()
    if not width or width <= 0 then width = 168 end
    local inner = width - 2
    local w = (inner - (n - 1)) / n
    local strata, level = row:GetFrameStrata(), (row:GetFrameLevel() or 1) + 2
    -- the anchor sits on UIParent: give it the bar's scale (the bar can be scaled)
    local scale = (row:GetEffectiveScale() or 1) / ((UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1)
    local geo = table.concat({ i, n, width, strata, level, ("%.3f"):format(scale) }, ":")
    if seg.geo ~= geo then
        seg.anchor:SetScale(scale)
        seg.anchor:ClearAllPoints()
        seg.anchor:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2 + (i - 1) * (w + 1), 0)
        seg.anchor:SetSize(math.max(1, w), STRIP_H)
        seg.anchor:SetFrameStrata(strata)
        seg.anchor:SetFrameLevel(level)
        seg.container:SetFrameStrata(strata)
        seg.container:SetFrameLevel(level)
        seg.geo = geo
    end
    if seg.unit ~= unit then seg.container:SetUnit(unit); seg.unit = unit end
    local filter, signature = filterFor(blessing)
    if seg.signature ~= signature then
        seg.container:SetAuraSlotCandidateFilters(seg.key, filter)
        seg.signature = signature
    end
    if not seg.enabled then
        seg.container:SetEnabled(true)
        seg.container:SetAuraSlotEnabled(seg.key, true)
        seg.enabled = true
        active = active + 1
    end
    seg.base:Show()
end

local function layout(list)
    local used = {}
    if enabledSetting() and #list > 0 and Native.Ready() then
        for _, entry in ipairs(list) do
            local row, units = entry.row, entry.units
            local n = math.min(#units, MAX_SEGMENTS)
            segs[row] = segs[row] or {}
            used[row] = n
            for i = 1, n do
                local seg = segs[row][i]
                if not seg then
                    seg = newSegment(row, i)
                    segs[row][i] = seg
                end
                place(seg, row, i, n, units[i], entry.blessing)
            end
        end
    end
    for row, list2 in pairs(segs) do
        for i, seg in pairs(list2) do
            if i > (used[row] or 0) then disable(seg) end
        end
    end
    suspended = false
end

-- called by the bar outside of combat: list = { { row, units, blessing }, ... }
function Native.Layout(list)
    if inCombat() or state == false then return end
    local ok, err = pcall(layout, list or {})
    if not ok then
        fail(err)
        ns.Print(L.BLESS_LIVE_FAILED:format(tostring(err)))
    end
end

-- unit ids can point to other players after a roster change in combat
local function suspend()
    if active == 0 then return end
    suspended = true
    for _, list in pairs(segs) do
        for _, seg in pairs(list) do pcall(disable, seg) end
    end
end
ns.On("GROUP_ROSTER_UPDATE", function() if inCombat() then suspend() end end)

function Native.Active() return state == true and active > 0 and not suspended end

function Native.Report()
    -- answer "available?" even before the bar asked for it (e.g. solo, no rows yet)
    if state == nil and not inCombat() then Native.Ready() end
    local rows, total = 0, 0
    for _, list in pairs(segs) do
        rows = rows + 1
        for _ in pairs(list) do total = total + 1 end
    end
    local st = state == true and "ready" or (state == false and ("unavailable – " .. tostring(reason)) or "not tried yet")
    local text = L.BLESS_LIVE_REPORT:format(st, enabledSetting() and "on" or "off", active, total, rows, suspended and "yes" or "no")
    -- why there is nothing to show
    local why
    if not B.IsPaladin() then why = L.BLESS_LIVE_WHY_CLASS
    elseif not (ns.BlessingsBar and ns.BlessingsBar.Shown and ns.BlessingsBar.Shown()) then why = L.BLESS_LIVE_WHY_BAR
    elseif total == 0 or active == 0 then why = L.BLESS_LIVE_WHY_ROWS end
    if why and state ~= false then text = text .. " – " .. why end
    return text
end
