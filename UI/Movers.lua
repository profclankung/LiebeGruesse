-- "Move elements" mode: screen grid, snapping and a small control bar.
-- Movable elements call Movers.Snap(frame) after dragging; the position is
-- returned as { point, relPoint, x, y } relative to UIParent.
local _, ns = ...
local UI, Theme, L = ns.UI, ns.Theme, ns.L
local Movers = {}
ns.Movers = Movers

local function settings()
    local s = ns.Database.Settings()
    s.movers = s.movers or {}
    local m = s.movers
    if m.grid == nil then m.grid = true end
    if m.snap == nil then m.snap = true end
    m.size = m.size or 16
    return m
end
Movers.Settings = settings

---------------------------------------------------------------------------
-- Grid overlay
---------------------------------------------------------------------------
local grid
local function drawGrid()
    if not grid then
        grid = CreateFrame("Frame", nil, UIParent)
        grid:SetAllPoints(UIParent)
        grid:SetFrameStrata("BACKGROUND")
        grid:EnableMouse(false)
        grid.lines = {}
    end
    for _, l in ipairs(grid.lines) do l:Hide() end
    local size = settings().size
    local w, h = UIParent:GetWidth() or 1920, UIParent:GetHeight() or 1080
    local n = 0
    local function line(vertical, offset, center)
        n = n + 1
        local t = grid.lines[n]
        if not t then t = grid:CreateTexture(nil, "BACKGROUND"); grid.lines[n] = t end
        t:ClearAllPoints()
        if center then
            local r, g, b = Theme.Color("accent")
            t:SetColorTexture(r, g, b, 0.55)
        else
            t:SetColorTexture(1, 1, 1, 0.07)
        end
        if vertical then
            t:SetPoint("TOP", grid, "TOP", offset, 0)
            t:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
            t:SetWidth(1)
        else
            t:SetPoint("LEFT", grid, "LEFT", 0, offset)
            t:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
            t:SetHeight(1)
        end
        t:Show()
    end
    -- lines start at the screen centre so the middle is always on the grid
    for x = 0, w / 2, size do
        line(true, x, x == 0)
        if x > 0 then line(true, -x) end
    end
    for y = 0, h / 2, size do
        line(false, y, y == 0)
        if y > 0 then line(false, -y) end
    end
end

---------------------------------------------------------------------------
-- Control bar (grid on/off, size, snap, done)
---------------------------------------------------------------------------
local bar
local function buildBar()
    bar = UI.Panel(UIParent, "bg", "border")
    UI.Float(bar)
    bar:SetSize(860, 60)
    bar:SetPoint("TOP", UIParent, "TOP", 0, -40)
    bar:EnableMouse(true)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", bar.StartMoving)
    bar:SetScript("OnDragStop", bar.StopMovingOrSizing)
    local icon = UI.Icon(bar, "move", 16, "accent")
    icon:SetPoint("TOPLEFT", 14, -10)
    local title = UI.Text(bar, 14, "text")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    title:SetText(L.MOVE_ELEMENTS)
    bar.hint = UI.Text(bar, 11, "muted")
    bar.hint:SetPoint("BOTTOMLEFT", 14, 9)
    bar.hint:SetPoint("RIGHT", bar, "RIGHT", -270, 0)
    bar.hint:SetJustifyH("LEFT")
    bar.hint:SetWordWrap(false)
    local lock = UI.Button(bar, L.MOVE_LOCK, 96, 28, function() ns.Window.ToggleMovers() end, "x")
    lock:SetPoint("RIGHT", -8, 0)
    if lock.SetBackdropColor then
        local r, g, b = Theme.Color("accent")
        lock:SetBackdropColor(r * 0.55, g * 0.55, b * 0.55, 1)
        lock:SetBackdropBorderColor(r, g, b, 1)
    end
    local reset = UI.Button(bar, L.MOVE_RESET_ALL, 120, 28, function()
        Movers.ResetAll()
        if ns.CooldownBars then for _, key in ipairs(ns.CooldownBars.Keys()) do ns.CooldownBars.ResetPosition(key) end end
    end, "rotate-ccw")
    reset:SetPoint("RIGHT", lock, "LEFT", -6, 0)
    local sizes = UI.Segmented(bar, 96, { { value = 8, text = "8" }, { value = 16, text = "16" }, { value = 32, text = "32" } },
        function() return settings().size end, function(v) settings().size = v; Movers.Refresh() end)
    sizes:SetPoint("TOPRIGHT", reset, "TOPLEFT", -10, 8)
    local snapCheck = UI.Check(bar, L.MOVE_SNAP, function() return settings().snap end,
        function(v) settings().snap = v end, L.MOVE_SNAP_TIP)
    snapCheck:SetPoint("RIGHT", sizes, "LEFT", -14, 0)
    local gridCheck = UI.Check(bar, L.MOVE_GRID, function() return settings().grid end,
        function(v) settings().grid = v; Movers.Refresh() end)
    gridCheck:SetPoint("RIGHT", snapCheck, "LEFT", -14, 0)
    bar.checks = { gridCheck, snapCheck, sizes }

    -- arrow keys move the picked element (Shift: one grid step)
    bar:EnableKeyboard(true)
    bar:SetScript("OnKeyDown", function(self, key)
        local o = Movers.selected
        local dx = (key == "LEFT" and -1) or (key == "RIGHT" and 1) or 0
        local dy = (key == "DOWN" and -1) or (key == "UP" and 1) or 0
        local handled = o and o:IsShown() and (dx ~= 0 or dy ~= 0)
        if key == "ESCAPE" and o then Movers.Select(nil); handled = true end
        if not InCombatLockdown() and self.SetPropagateKeyboardInput then pcall(self.SetPropagateKeyboardInput, self, not handled) end
        if handled and o.nudge then
            local step = IsShiftKeyDown() and settings().size or 1
            o.nudge(dx * step, dy * step)
        end
    end)
end

function Movers.UpdateHint()
    if not bar then return end
    local o = Movers.selected
    if o and o:IsShown() then
        bar.hint:SetText(Theme.HexColor("accent", o.labelText or "") .. "  " .. L.MOVE_HINT_PICKED)
    else
        bar.hint:SetText(L.MOVE_HINT_BAR)
    end
end

function Movers.Refresh()
    local active = Movers.active
    if active and not bar then buildBar() end
    if bar then
        bar:SetShown(active)
        if active then for _, c in ipairs(bar.checks) do c:Refresh() end end
        if not active then Movers.selected = nil end
        Movers.UpdateHint()
    end
    if active and settings().grid then drawGrid(); grid:Show() elseif grid then grid:Hide() end
end

function Movers.SetActive(on)
    Movers.active = on and true or false
    Movers.Refresh()
    ns.Fire("LG_MOVERS", Movers.active)
end

---------------------------------------------------------------------------
-- Snapping: re-anchors the frame TOPLEFT to UIParent BOTTOMLEFT on the grid
---------------------------------------------------------------------------
function Movers.Snap(f, noSnap)
    local left, top = f:GetLeft(), f:GetTop()
    if not left or not top then
        local point, _, rel, x, y = f:GetPoint()
        return { point, rel, x, y }
    end
    local ratio = (f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    local x, y = left * ratio, top * ratio
    local s = settings()
    if s.snap and not noSnap then
        -- snap relative to the screen centre (the grid's origin)
        local cx, cy = (UIParent:GetWidth() or 0) / 2, (UIParent:GetHeight() or 0) / 2
        x = cx + math.floor((x - cx) / s.size + 0.5) * s.size
        y = cy + math.floor((y - cy) / s.size + 0.5) * s.size
    end
    x, y = x / ratio, y / ratio
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    return { "TOPLEFT", "BOTTOMLEFT", x, y }
end

---------------------------------------------------------------------------
-- Anchors for everything else on screen (popups, toasts, windows).
--   local holder = Movers.Anchor(key, label, { point, relPoint, x, y }, w, h)
--   Movers.Attach(key, frame)   frame follows the holder (TOPLEFT to TOPLEFT);
--                               dragging the frame itself also saves the spot.
-- In unlock mode every anchor shows a labelled placeholder that can be dragged
-- even when the real element is hidden; right-click resets it.
---------------------------------------------------------------------------
local anchors, order = {}, {}
Movers.anchors = anchors

local function positions()
    local m = settings()
    m.pos = m.pos or {}
    return m.pos
end

local function placeHolder(a)
    a.holder:ClearAllPoints()
    local p = positions()[a.key] or a.default
    a.holder:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

-- placeholder look: dark panel with accent edge, name on top, icon in the middle;
-- the picked one (and the one under the mouse) is filled with the accent colour
local function paint(o)
    local r, g, b = Theme.Color("accent")
    if o.picked or o.hovered then
        o:SetBackdropColor(r, g, b, o.picked and 0.95 or 0.75)
        o:SetBackdropBorderColor(r, g, b, 1)
        o.label:SetTextColor(1, 1, 1)
        if o.icon then o.icon:SetVertexColor(0.08, 0.06, 0.04) end
    else
        o:SetBackdropColor(0.10, 0.07, 0.05, o.fillAlpha or 0.85)
        o:SetBackdropBorderColor(r, g, b, 0.9)
        o.label:SetTextColor(1, 1, 1)
        if o.icon then o.icon:SetVertexColor(r, g, b) end
    end
end

local function styleOverlay(o, label, hint, icon)
    o:SetBackdrop({ bgFile = Theme.WHITE, edgeFile = Theme.WHITE, edgeSize = 1 })
    Theme.SetFont(o.label, Theme.Font(), Theme.FontSize(11), "OUTLINE")
    o.label:SetText(label)
    o.labelText = label
    Theme.SetFont(o.hint, Theme.Font(), Theme.FontSize(10), "")
    o.hint:SetText("")
    icon = icon or o.iconName
    if icon then
        o.iconName = icon
        if not o.icon then
            o.icon = o:CreateTexture(nil, "OVERLAY")
            o.icon:SetPoint("CENTER", 0, -6)
        end
        Theme.SetIcon(o.icon, icon)
        local size = math.max(10, math.min(22, (o:GetHeight() or 40) - 22))
        o.icon:SetSize(size, size)
        o.icon:SetShown((o:GetHeight() or 0) >= 34)
    end
    -- the name sits at the top of tall placeholders, centred in flat ones
    o.label:ClearAllPoints()
    if (o:GetHeight() or 0) >= 34 then o.label:SetPoint("TOP", 0, -6) else o.label:SetPoint("CENTER") end
    paint(o)
end
Movers.StyleOverlay = styleOverlay

function Movers.Select(o)
    if Movers.selected and Movers.selected ~= o then
        Movers.selected.picked = false
        paint(Movers.selected)
    end
    Movers.selected = o
    if o then o.picked = true; paint(o) end
    Movers.UpdateHint()
end

function Movers.NewOverlay(parent)
    local o = CreateFrame("Button", nil, parent, "BackdropTemplate")
    o.label = o:CreateFontString(nil, "OVERLAY")
    Theme.SetFont(o.label, Theme.Font(), Theme.FontSize(11), "OUTLINE")
    o.label:SetPoint("TOP", 0, -6)
    o.hint = o:CreateFontString(nil, "OVERLAY")
    Theme.SetFont(o.hint, Theme.Font(), Theme.FontSize(10), "")
    o.hint:SetPoint("TOP", o.label, "BOTTOM", 0, -3)
    o.hint:SetTextColor(0.7, 0.7, 0.7)
    o:RegisterForDrag("LeftButton")
    o:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- left click picks it (arrow keys), right click opens its menu
    o:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if self.menu then self.menu(self) end
        else
            Movers.Select(self)
        end
    end)
    o:HookScript("OnEnter", function(self) self.hovered = true; paint(self) end)
    o:HookScript("OnLeave", function(self) self.hovered = false; paint(self) end)
    o:HookScript("OnHide", function(self)
        self.hovered = false
        if Movers.selected == self then Movers.selected = nil; self.picked = false; Movers.UpdateHint() end
    end)
    return o
end

-- opts: { settings = fn (opens the element's options), sizes = { { label, min, max, step, get, set, pct } },
--         scalable = true (adds a scale slider for the attached frames) }
function Movers.Anchor(key, label, default, w, h, level, opts)
    local a = anchors[key]
    if a then return a.holder end
    a = { key = key, label = label, default = default, opts = opts or {} }
    a.opts.key = key
    a.holder = CreateFrame("Frame", "LiebeGruesseAnchor_" .. key, UIParent)
    a.holder:SetSize(w or 200, h or 60)
    a.holder:SetMovable(true)
    a.holder:SetClampedToScreen(true)
    placeHolder(a)
    local o = Movers.NewOverlay(a.holder)
    o:SetAllPoints()
    o:SetFrameStrata("DIALOG")
    o:SetFrameLevel(level or 200)
    o:SetScript("OnDragStart", function(self) Movers.Select(self); a.holder:StartMoving() end)
    o:SetScript("OnDragStop", function()
        a.holder:StopMovingOrSizing()
        positions()[key] = Movers.Snap(a.holder)
        Movers.Follow(key)
    end)
    o.menu = function(self) Movers.Menu(a.label, a.opts, function() Movers.Reset(key) end, self) end
    o.nudge = function(dx, dy)
        local left, top = a.holder:GetLeft(), a.holder:GetTop()
        if not left or not top then return end
        a.holder:ClearAllPoints()
        a.holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + dx, top + dy)
        positions()[key] = Movers.Snap(a.holder, true)
        Movers.Follow(key)
    end
    o:Hide()
    a.overlay = o
    anchors[key] = a
    order[#order + 1] = key
    if Movers.active then Movers.Refresh() end
    return a.holder
end

local function scales()
    local m = settings()
    m.scale = m.scale or {}
    return m.scale
end

function Movers.Scale(key) return scales()[key] or 1 end
function Movers.SetScale(key, v)
    scales()[key] = (v and v ~= 1) and v or nil
    Movers.Follow(key)
end

function Movers.Follow(key)
    local a = anchors[key]
    if not a then return end
    for _, f in ipairs(a.frames or {}) do
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", a.holder, "TOPLEFT")
        if a.opts.scalable then f:SetScale(scales()[key] or 1) end
    end
    if a.opts.onFollow then ns.Safe(a.opts.onFollow) end
end

---------------------------------------------------------------------------
-- Right-click menu of a placeholder and the small size editor
---------------------------------------------------------------------------
local editor
local function openEditor(title, sizes, anchor)
    if not editor then
        editor = UI.Panel(UIParent, "bg", "accent")
        editor:SetFrameStrata("FULLSCREEN_DIALOG")
        editor:SetClampedToScreen(true)
        editor:EnableMouse(true)
        editor.title = UI.Text(editor, 13, "gold")
        editor.title:SetPoint("TOPLEFT", 12, -10)
        local close = UI.IconButton(editor, "x", 20, function() editor:Hide() end)
        close:SetPoint("TOPRIGHT", -6, -6)
        editor.sliders = {}
    end
    for _, sl in ipairs(editor.sliders) do sl:Hide() end
    editor.title:SetText(title)
    for i, def in ipairs(sizes) do
        local fmt = def.pct and function(v) return ("%d%%"):format(v * 100 + 0.5) end or nil
        local sl = UI.Slider(editor, def.label, def.min, def.max, def.step, def.get, def.set, fmt)
        sl:SetPoint("TOPLEFT", 12, -34 - (i - 1) * 44)
        sl:SetPoint("TOPRIGHT", -12, -34 - (i - 1) * 44)
        editor.sliders[#editor.sliders + 1] = sl
        sl:Show()
    end
    editor:SetSize(260, 44 + #sizes * 44)
    editor:ClearAllPoints()
    editor:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
    editor:Show()
end
Movers.OpenEditor = openEditor

function Movers.Menu(title, opts, reset, anchor)
    local entries = { { title = title } }
    local sizes = {}
    for _, s in ipairs(opts.sizes or {}) do sizes[#sizes + 1] = s end
    if opts.scalable and opts.key then
        sizes[#sizes + 1] = { label = L.MOVE_SCALE, min = 0.5, max = 1.6, step = 0.05, pct = true,
            get = function() return scales()[opts.key] or 1 end,
            set = function(v) scales()[opts.key] = v; Movers.Follow(opts.key) end }
    end
    if #sizes > 0 then entries[#entries + 1] = { text = L.MOVE_SIZE, func = function() openEditor(title, sizes, anchor) end } end
    if opts.settings then entries[#entries + 1] = { text = L.MOVE_OPTIONS, func = opts.settings } end
    if opts.extra then for _, e in ipairs(opts.extra) do entries[#entries + 1] = e end end
    entries[#entries + 1] = { divider = true }
    entries[#entries + 1] = { text = L.MOVE_RESET, func = reset }
    UI.ContextMenu(entries)
end

function Movers.Attach(key, frame)
    local a = anchors[key]
    if not a then
        if not frame:GetPoint() then frame:SetPoint("CENTER") end
        return
    end
    a.frames = a.frames or {}
    table.insert(a.frames, frame)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", a.holder, "TOPLEFT")
    if frame.IsMovable and frame:IsMovable() then
        frame:HookScript("OnDragStop", function(self)
            -- the frame was dragged itself: move the anchor there
            local left, top = self:GetLeft(), self:GetTop()
            if not left or not top then return end
            a.holder:ClearAllPoints()
            a.holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            positions()[key] = Movers.Snap(a.holder)
            Movers.Follow(key)
        end)
    end
end

function Movers.Reset(key)
    local a = anchors[key]
    if not a then return end
    positions()[key] = nil
    placeHolder(a)
    Movers.Follow(key)
end

function Movers.ResetAll()
    for _, key in ipairs(order) do Movers.Reset(key) end
end

local baseRefresh = Movers.Refresh
function Movers.Refresh()
    baseRefresh()
    for _, key in ipairs(order) do
        local a = anchors[key]
        if Movers.active then styleOverlay(a.overlay, a.label, nil, a.opts.icon or "move") end
        a.overlay:SetShown(Movers.active == true and not a.disabled)
    end
end

-- an element that follows another one (docked) has no placeholder of its own
function Movers.SetDisabled(key, on)
    local a = anchors[key]
    if not a or a.disabled == (on and true or false) then return end
    a.disabled = on and true or false
    if Movers.active then Movers.Refresh() end
end

function Movers.HasPosition(key) return positions()[key] ~= nil end

---------------------------------------------------------------------------
-- Lock button on a single element: unlocks just this element so it can be
-- dragged where it sits, without the "Move elements" mode.
--   Movers.LockButton(key, frame, parent, size) -> icon button
-- While unlocked a tinted cover lies over the element (its own clicks pause),
-- right-click on the cover opens the element's menu. Combat and the
-- "Move elements" mode lock it again.
---------------------------------------------------------------------------
local locks = {}   -- [key] = { button, cover, unlocked }

local function paintLock(l)
    local r, g, b = Theme.Color("accent")
    Theme.SetIcon(l.button.icon, l.unlocked and "lock-open" or "lock")
    if l.unlocked then
        l.button.icon:SetVertexColor(r, g, b)
        l.cover:SetBackdropColor(r, g, b, 0.22)
        l.cover:SetBackdropBorderColor(r, g, b, 1)
        l.button.tip, l.button.tipLines = L.MOVE_LOCK_ONE, { L.MOVE_LOCK_ONE_TIP }
    else
        l.button.icon:SetVertexColor(Theme.Color("textDim"))
        l.button.tip, l.button.tipLines = L.MOVE_UNLOCK_ONE, { L.MOVE_UNLOCK_ONE_TIP }
    end
    l.cover:SetShown(l.unlocked)
end

function Movers.SetUnlocked(key, on)
    local l = locks[key]
    if not l then return end
    on = on and true or false
    if on and InCombatLockdown and InCombatLockdown() then ns.Print(L.MOVE_COMBAT); return end
    if l.unlocked == on then return end
    l.unlocked = on
    paintLock(l)
    if l.button:IsMouseOver() and l.button:GetScript("OnEnter") then l.button:GetScript("OnEnter")(l.button) end
end

function Movers.IsUnlocked(key) return locks[key] and locks[key].unlocked or false end

function Movers.LockButton(key, frame, parent, size)
    local l = { unlocked = false }
    l.button = UI.IconButton(parent or frame, "lock", size or 16, function() Movers.SetUnlocked(key, not l.unlocked) end)
    local cover = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    cover:SetAllPoints()
    cover:SetFrameLevel(frame:GetFrameLevel() + 20)
    cover:SetBackdrop({ bgFile = Theme.WHITE, edgeFile = Theme.WHITE, edgeSize = 1 })
    cover:EnableMouse(true)
    cover:RegisterForDrag("LeftButton")
    -- no text on the cover (it would sit on the element's own texts): the hint is a tooltip
    cover:SetScript("OnEnter", function(self) UI.Tooltip(self, L.MOVE_DRAG_HINT, { L.CD_MOVER_HINT }) end)
    cover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cover:SetScript("OnDragStart", function()
        local a = anchors[key]
        if not a or (InCombatLockdown and InCombatLockdown()) then return end
        a.holder:StartMoving()
    end)
    cover:SetScript("OnDragStop", function()
        local a = anchors[key]
        if not a then return end
        a.holder:StopMovingOrSizing()
        positions()[key] = Movers.Snap(a.holder)
        Movers.Follow(key)
    end)
    cover:SetScript("OnMouseUp", function(self, button)
        local a = anchors[key]
        if button == "RightButton" and a then Movers.Menu(a.label, a.opts, function() Movers.Reset(key) end, self) end
    end)
    cover:Hide()
    l.cover = cover
    -- the button stays clickable above the cover
    l.button:SetFrameLevel(cover:GetFrameLevel() + 5)
    locks[key] = l
    paintLock(l)
    return l.button
end

local function lockAll() for key in pairs(locks) do Movers.SetUnlocked(key, false) end end
ns.On("PLAYER_REGEN_DISABLED", lockAll)
ns.On("LG_MOVERS", lockAll)
