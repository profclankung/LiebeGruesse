-- Blessing bar for paladins, one button per class you bless:
--   class icon, blessing, buffed/total and time left, tinted green / yellow /
--   red (all / some / nobody buffed). Left click: (greater) blessing on that
--   class, right click: single blessing on someone missing it.
-- Hovering a class button pops out its players: what you give each of them,
-- time left, left click casts it, right click / mouse wheel sets a single
-- blessing. Your single blessings have their own button ("Single 2/2").
-- On top: aura, seal and Righteous Fury buttons (optional), "Cast next" (the
-- next missing blessing) and the header with page, quick window, smart assign
-- and lock. Every cast is one click (secure buttons); the pop-outs open in
-- combat too (secure snippets), their content is set outside of combat.
local _, ns = ...
local UI, Theme, L = ns.UI, ns.Theme, ns.L
local B = ns.Blessings
local Bar = {}
ns.BlessingsBar = Bar

local WIDTH, ROW_H, HEAD_H = 168, 30, 24
local FLY_W, PROW_H, MAX_PLAYERS = 170, 26, 15
local SINGLE_ROW = #B.CLASSES + 1          -- index of the "Single" button among the rows
local frame, auto, rows = nil, nil, {}
local selfButtons = {}                     -- aura / seal / fury
local flies = {}                           -- [row index] = pop-out frame with player buttons

local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function opt() return B.Settings() end

local function inRange(spellName, unit)
    if C_Spell and C_Spell.IsSpellInRange then
        local r = ns.Call(C_Spell.IsSpellInRange, spellName, unit)
        if r ~= nil then return r == true or r == 1 end
    end
    if IsSpellInRange then
        local r = ns.Call(IsSpellInRange, spellName, unit)
        if r ~= nil then return r == 1 end
    end
    return true
end
local function usable(unit)
    return ns.Call(UnitExists, unit) and not ns.Call(UnitIsDeadOrGhost, unit) and ns.Call(UnitIsConnected, unit) ~= false
end

-- a unit of that class to cast on: someone who misses it and is in range first
-- (pool: who may get it at all, default the whole class)
local function pickUnit(class, spellName, needList, pool)
    pool = pool or B.classUnits[class] or {}
    for _, unit in ipairs(needList or {}) do
        if usable(unit) and inRange(spellName, unit) then return unit end
    end
    for _, unit in ipairs(pool) do
        if usable(unit) and inRange(spellName, unit) then return unit end
    end
    return pool[1]
end

local function setSecure(button, attrs)
    if inCombat() then return false end
    if B.test then attrs = { type1 = false, type2 = false } end   -- test raiders: clicks cast nothing
    button.lgAttrs = button.lgAttrs or {}
    for k, v in pairs(attrs) do
        button:SetAttribute(k, v or nil)
        button.lgAttrs[k] = v or nil
    end
    return true
end
-- current value of a secure attribute (the combat snippet below can change unit1/unit2)
local function attr(button, key)
    local v = button:GetAttribute(key)
    if v == nil and button.lgAttrs then v = button.lgAttrs[key] end
    return v
end

-- after a click: remember whom the blessing went to (auras are hidden in combat)
local function noteClick(button, mouse)
    local which = (mouse == "RightButton") and "2" or "1"
    if attr(button, "type" .. which) ~= "spell" then return end
    local unit, spell = attr(button, "unit" .. which), attr(button, "spell" .. which)
    if unit and spell then B.NoteCastTarget(unit, spell) end
end

-- In combat the attributes are frozen, so a right-click would always hit the
-- same player (and nothing at all once he is dead). This secure snippet runs
-- before each click in combat: right-click steps through the class (players
-- missing the blessing first), left-click only skips a dead target. Outside
-- of combat it does nothing – the bar picks the target itself.
local ROTATE = [[
    if button ~= "LeftButton" and button ~= "RightButton" then return end
    if not SecureCmdOptionParse("[combat] 1") then return end
    local n = self:GetAttribute("lg-n") or 0
    if n == 0 then return end
    local which = (button == "RightButton") and "2" or "1"
    if not self:GetAttribute("spell" .. which) then return end
    local current = self:GetAttribute("unit" .. which)
    if which == "1" and current and SecureCmdOptionParse("[@" .. current .. ",help,nodead] 1") then return end
    local step = (which == "2") and (self:GetAttribute("lg-step") or 1) or 1
    for i = 0, n - 1 do
        local idx = (step - 1 + i) % n + 1
        local unit = self:GetAttribute("lg-u" .. idx)
        if unit and SecureCmdOptionParse("[@" .. unit .. ",help,nodead] 1") then
            self:SetAttribute("unit" .. which, unit)
            if which == "2" and not down then self:SetAttribute("lg-step", idx % n + 1) end
            return
        end
    end
]]
-- pop-outs: the row shows its own and hides the others; leaving hides it unless
-- the mouse is over the pop-out (restricted code, so it works in combat)
local FLY_ENTER = [[
    local mine = self:GetFrameRef("lg-fly")
    for i = 1, 10 do
        local o = self:GetFrameRef("lg-fly" .. i)
        if o and o ~= mine then o:Hide() end
    end
    if mine and self:GetAttribute("lg-hasfly") then mine:Show() end
]]
local FLY_LEAVE = [[
    local mine = self:GetFrameRef("lg-fly")
    if mine and mine:IsShown() and not mine:IsUnderMouse(true) and not self:IsUnderMouse(true) then mine:Hide() end
]]
local PLAYER_LEAVE = [[
    local f = self:GetParent()
    if f and not f:IsUnderMouse(true) then f:Hide() end
]]
local header
local function secureHeader()
    if header then return header end
    if not (SecureHandlerWrapScript and SecureCmdOptionParse) then return nil end
    local ok, f = pcall(CreateFrame, "Frame", "LiebeGruesseBlessHeader", UIParent, "SecureHandlerBaseTemplate")
    if ok and f then header = f end
    return header
end
local function setRef(frame, label, ref)
    if not SecureHandlerSetFrameRef then return false end
    return pcall(SecureHandlerSetFrameRef, frame, label, ref)
end
local function wrap(button, script, body)
    local h = secureHeader()
    if not h then return false end
    return pcall(SecureHandlerWrapScript, button, script, h, body)
end
-- the order for the combat snippet: the chosen target, then whoever misses
-- the blessing, then the rest of the class
local function rotation(button, class, first, needList, pool)
    local list, seen = {}, {}
    local function add(u) if u and not seen[u] then seen[u] = true; list[#list + 1] = u end end
    add(first)
    for _, u in ipairs(needList or {}) do add(u) end
    for _, u in ipairs(pool or B.classUnits[class] or {}) do add(u) end
    local old = button.lgRotation or 0
    local attrs = { ["lg-n"] = #list, ["lg-step"] = 1 }
    for i = 1, math.max(#list, old) do attrs["lg-u" .. i] = list[i] or false end
    button.lgRotation = #list
    setSecure(button, attrs)
end

local function fmtLeft(sec)
    if not sec or sec == math.huge then return "" end
    if sec >= 60 then return ("%dm"):format(math.floor(sec / 60)) end
    return ("%ds"):format(math.max(0, math.floor(sec)))
end
local function showTimes() return opt().times ~= false end

local function blessIcon(b, size)
    return ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(B.Icon(b) or 135995, size or 14, size or 14)
end

-- tint: all buffed = good, some = warn, nobody = bad
local function tint(tex, have, total, present)
    if not present or total == 0 then tex:SetVertexColor(Theme.Color("rowAlt")); tex:SetAlpha(1); return end
    local role = (have >= total) and "good" or (have == 0 and "bad" or "warn")
    local r, g, b = Theme.Color(role)
    tex:SetVertexColor(r, g, b)
    tex:SetAlpha(0.2)
end
local function countText(have, total, estimated)
    local role = (have >= total) and "good" or (have == 0 and "bad" or "warn")
    return Theme.HexColor(role, ((estimated and "~" or "") .. "%d/%d"):format(have, total))
end

---------------------------------------------------------------------------
-- Menus: single blessing for a player, add one for someone new
---------------------------------------------------------------------------
-- blessing menu for one player (singles of paladin p, default you); "class blessing" removes the single
function Bar.SingleMenu(anchor, key, p)
    local me = p or B.Me()
    if not me then return end
    if inCombat() then ns.Print(L.BLESS_WHEEL_COMBAT); return end
    if not B.CanEdit(me) then ns.Print(L.BLESS_CANT_EDIT); return end
    local m = B.members[key]
    local items = {}
    for _, b in ipairs(B.LIST) do
        if B.CanCast(me, b.key) then
            items[#items + 1] = { value = b.key, text = blessIcon(b.key, 16) .. "  " .. B.Name(b.key) }
        end
    end
    local classB = m and me.set and me.set[m.class]
    items[#items + 1] = { value = "none", text = Theme.HexColor("muted", classB and L.BLESS_SINGLE_CLASS:format(B.Name(classB)) or L.BLESS_SINGLE_REMOVE) }
    UI.OpenMenu(anchor, items, function(v)
        B.SetSingle(me, key, v ~= "none" and v or nil)
    end, 200, me.single and me.single[key] or "none")
end

-- pick a group member (grouped by class, optionally one class), then his blessing
function Bar.AddSingle(anchor, after, p, onlyClass)
    if inCombat() then ns.Print(L.BLESS_WHEEL_COMBAT); return end
    local me = p or B.Me()
    if not me then return end
    if not B.CanEdit(me) then ns.Print(L.BLESS_CANT_EDIT); return end
    UI.SearchMenu(anchor, {
        width = 260, placeholder = L.BLESS_SINGLE_SEARCH, hint = L.BLESS_SINGLE_HINT,
        build = function(q)
            local out = {}
            for _, class in ipairs(B.CLASSES) do
                local list = {}
                if not onlyClass or onlyClass == class then
                    for _, m in pairs(B.members) do
                        if m.class == class and (q == "" or (m.name or ""):lower():find(q, 1, true) or ns.ClassName(class):lower():find(q, 1, true)) then
                            list[#list + 1] = m
                        end
                    end
                end
                table.sort(list, function(a, b) return a.key < b.key end)
                if #list > 0 then
                    out[#out + 1] = { head = ns.ClassName(class) }
                    for _, m in ipairs(list) do
                        local single = me.single and me.single[m.key]
                        local kind = B.UnitType(m.unit, m.key, class)
                        out[#out + 1] = { value = m.key, text = ns.ColorName(m.name, class),
                            right = single and blessIcon(single, 14) or "", tag = L["BLESS_TYPE_" .. kind:upper()],
                            setIcon = function(tex) ns.SetSpecIcon(tex, class, ns.SpecPoints(ns.Database.Member(m.key))) end }
                    end
                end
            end
            return out
        end,
        onPick = function(key) Bar.SingleMenu(after or anchor, key, me) end,
    })
end

---------------------------------------------------------------------------
-- Self buffs: aura, seal, Righteous Fury (cast on yourself, shown green while on)
---------------------------------------------------------------------------
Bar.AURAS = { { 465 }, { 7294 }, { 19746 }, { 19876 }, { 19888 }, { 19891 }, { 20218 } }
-- Seal of Fury (WoW: Forever): 1311656 is rank 2; rank 1 is found by name in the spell book
Bar.SEALS = { { 21084, 20154 }, { 21082 }, { 20165 }, { 20166 }, { 20164 }, { 20375 }, { 1311656 } }
Bar.FURY = { 25780 }
local knownByName = B.KnownByName
-- first known id of an entry, else the first id (for its name); casting goes by
-- name, so the game takes the highest rank you have
local function knownId(ids)
    for _, id in ipairs(ids) do if B.Known(id) then return id, true end end
    if knownByName(ids[1]) then return ids[1], true end
    return ids[1], false
end
function Bar.SelfChoices(list)
    local out = {}
    for _, ids in ipairs(list) do
        local id, known = knownId(ids)
        local name = B.SpellName(id)
        if name and (known or B.test) then out[#out + 1] = { value = ids[1], text = name, id = id } end
    end
    return out
end
local function choice(kind)
    local o = opt()
    if kind == "fury" then return Bar.FURY end
    local want = o[kind .. "Spell"]
    local list = kind == "aura" and Bar.AURAS or Bar.SEALS
    for _, ids in ipairs(list) do if ids[1] == want then return ids end end
    -- nothing chosen: the first one you know
    for _, ids in ipairs(list) do local _, k = knownId(ids); if k then return ids end end
end

-- the chosen (or first known) aura / seal: its first id
function Bar.SelfChoice(kind)
    local ids = choice(kind)
    return ids and ids[1]
end

-- names of your own buffs (last readable state is kept: hidden in combat)
local ownBuffs = {}
local function readOwnBuffs()
    local seen, reliable = {}, true
    for i = 1, 40 do
        local name
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok or ns.IsSecret(a) then reliable = false; break end
            if type(a) ~= "table" then break end
            name = a.name
        elseif UnitBuff then
            local ok, n = pcall(UnitBuff, "player", i)
            if not ok then reliable = false; break end
            if not n then break end
            name = n
        else
            break
        end
        if ns.IsSecret(name) then reliable = false elseif name then seen[name] = true end
    end
    if reliable then ownBuffs = seen end
    return ownBuffs
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function rowTexts(r, withClass)
    r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetTexture(Theme.WHITE); r.bg:SetAllPoints()
    r.base = UI.Fill(r, "rowAlt", "BACKGROUND"); r.base:SetAllPoints(); r.base:SetDrawLayer("BACKGROUND", -1)
    r.hl = UI.Fill(r, "hover", "HIGHLIGHT"); r.hl:SetAllPoints()
    r.mark = UI.Fill(r, "bad", "ARTWORK")
    r.mark:SetPoint("TOPLEFT"); r.mark:SetPoint("BOTTOMLEFT"); r.mark:SetWidth(2)
    r.class = r:CreateTexture(nil, "ARTWORK")
    r.class:SetSize(20, 20)
    r.class:SetPoint("LEFT", 6, 0)
    r.bless = r:CreateTexture(nil, "ARTWORK")
    r.bless:SetSize(20, 20)
    r.bless:SetPoint("LEFT", r.class, "RIGHT", 4, 0)
    r.bless:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.count = UI.Text(r, 13, "text")
    r.count:SetPoint("LEFT", r.bless, "RIGHT", 8, 0)
    r.left = UI.Text(r, 13, "good", "RIGHT")
    r.left:SetPoint("RIGHT", -6, 0)
end

-- player buttons of one pop-out (created on demand, outside of combat)
local function playerButton(fly, i)
    local b = fly.buttons[i]
    if b then return b end
    b = CreateFrame("Button", fly.lgName .. "P" .. i, fly, "SecureActionButtonTemplate")
    b:SetSize(FLY_W - 4, PROW_H - 2)
    b:SetPoint("TOPLEFT", 2, -2 - (i - 1) * PROW_H)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:HookScript("PostClick", function(self, mouse, down)
        noteClick(self, mouse)
        if mouse == "RightButton" and not down and self.key then Bar.SingleMenu(self, self.key) end
    end)
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetTexture(Theme.WHITE); b.bg:SetAllPoints()
    b.base = UI.Fill(b, "row", "BACKGROUND"); b.base:SetAllPoints(); b.base:SetDrawLayer("BACKGROUND", -1)
    b.hl = UI.Fill(b, "hover", "HIGHLIGHT"); b.hl:SetAllPoints()
    b.mark = UI.Fill(b, "accent", "ARTWORK")
    b.mark:SetPoint("TOPLEFT"); b.mark:SetPoint("BOTTOMLEFT"); b.mark:SetWidth(2)
    b.spec = b:CreateTexture(nil, "ARTWORK"); b.spec:SetSize(16, 16); b.spec:SetPoint("LEFT", 5, 0)
    b.bless = b:CreateTexture(nil, "ARTWORK"); b.bless:SetSize(18, 18); b.bless:SetPoint("LEFT", b.spec, "RIGHT", 4, 0)
    b.bless:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.left = UI.Text(b, 12, "good", "RIGHT"); b.left:SetPoint("RIGHT", -5, 0)
    b.name = UI.Text(b, 12, "text"); b.name:SetPoint("LEFT", b.bless, "RIGHT", 6, 0); b.name:SetPoint("RIGHT", b.left, "LEFT", -4, 0)
    b.name:SetWordWrap(false)
    b:SetScript("OnEnter", function(self)
        local m = self.key and B.members[self.key]
        if not m then return end
        ns.TipOwner(self, "ANCHOR_LEFT")
        local cr, cg, cb = ns.ClassColor(m.class)
        GameTooltip:AddLine(m.name, cr, cg, cb)
        local kind, source = B.UnitType(m.unit, m.key, m.class)
        GameTooltip:AddLine(L.BLESS_TIP_PLAYS:format(L["BLESS_TYPE_" .. kind:upper()] or kind, L["BLESS_SRC_" .. tostring(source):upper()] or ""), 0.8, 0.8, 0.8, true)
        if self.blessing then
            GameTooltip:AddLine((self.single and L.BLESS_TIP_SINGLE or L.BLESS_TIP_FROM_YOU):format(B.Name(self.blessing) or ""), 1, 0.82, 0)
            local has, _, est = B.SingleState(self.key, self.blessing)
            GameTooltip:AddLine(has and L.BLESS_TIP_HAS or L.BLESS_TIP_MISSING_ONE, has and 0.4 or 1, has and 1 or 0.4, 0.4)
            if est then GameTooltip:AddLine(L.BLESS_ESTIMATED, 0.6, 0.6, 0.6, true) end
            if self.single then GameTooltip:AddLine(self.pinned and L.BLESS_TIP_PINNED or L.BLESS_TIP_SMART, 0.6, 0.6, 0.6, true) end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.BLESS_PLAYER_TIP, 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel", function(self, delta)
        if not self.key then return end
        if inCombat() then ns.Print(L.BLESS_WHEEL_COMBAT); return end
        B.CycleSingle(B.Me(), self.key, delta)
    end)
    if not wrap(b, "OnLeave", PLAYER_LEAVE) then
        b:HookScript("OnLeave", function(self)
            local f = self:GetParent()
            if not inCombat() and f and not f:IsMouseOver() then f:Hide() end
        end)
    end
    b:Hide()
    fly.buttons[i] = b
    return b
end

local function makeFly(i, row)
    local ok, fly = pcall(CreateFrame, "Frame", "LiebeGruesseBlessFly" .. i, frame, "SecureHandlerEnterLeaveTemplate, BackdropTemplate")
    if not ok or not fly then fly = CreateFrame("Frame", "LiebeGruesseBlessFly" .. i, frame, "BackdropTemplate") end
    fly.lgName = "LiebeGruesseBlessFly" .. i
    fly:SetSize(FLY_W, PROW_H)
    fly:SetFrameStrata("MEDIUM")
    fly:SetFrameLevel((frame:GetFrameLevel() or 1) + 10)
    fly:EnableMouse(true)
    UI.Skin(fly, "bg", "border")
    fly.buttons = {}
    if fly.SetAttribute then pcall(fly.SetAttribute, fly, "_onleave", [[ if not self:IsUnderMouse(true) then self:Hide() end ]]) end
    -- without the secure handlers (outside of combat only)
    fly:HookScript("OnLeave", function(self) if not inCombat() and not self:IsMouseOver() then self:Hide() end end)
    fly:Hide()
    flies[i] = fly
    return fly
end

local function makeRow(i)
    local single = i == SINGLE_ROW
    local r = CreateFrame("Button", single and "LiebeGruesseBlessSingles" or ("LiebeGruesseBlessRow" .. i), frame, "SecureActionButtonTemplate")
    r:SetSize(WIDTH - 8, ROW_H - 2)
    r:RegisterForClicks("AnyUp", "AnyDown")
    rowTexts(r)
    if single then
        r.class:SetTexture(Theme.Icon("users", 32)); r.class:SetVertexColor(Theme.Color("accent"))
        r.count:ClearAllPoints(); r.count:SetPoint("LEFT", r.class, "RIGHT", 8, 0)
        r.bless:Hide()
        r:SetScript("OnEnter", function(self)
            UI.Tooltip(self, L.BLESS_SINGLES_TITLE, { L.BLESS_SINGLE_DONE_TIP:format(Bar.SingleCount()), " ", L.BLESS_SINGLE_BTN_TIP })
        end)
        r:HookScript("PostClick", function(self, mouse, down)
            if not down and mouse == "LeftButton" and not inCombat() then Bar.AddSingle(self) end
        end)
    else
        -- down and up: the cast follows the key-down setting, noting twice is harmless
        r:HookScript("PostClick", function(self, mouse) noteClick(self, mouse) end)
        wrap(r, "OnClick", ROTATE)
        r:SetScript("OnEnter", function(self)
            if not self.cls then return end
            ns.TipOwner(self, opt().side == "right" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
            local cr, cg, cb = ns.ClassColor(self.cls)
            GameTooltip:AddLine(ns.ClassIcon(self.cls, 14) .. " " .. ns.ClassName(self.cls), cr, cg, cb)
            GameTooltip:AddLine(B.Name(self.blessing) or "", 1, 0.82, 0)
            if self.absent then GameTooltip:AddLine(L.BLESS_ROW_ABSENT, 0.6, 0.6, 0.6, true) end
            local st = B.status[self.cls]
            if st and st.estimated and not self.absent then
                GameTooltip:AddLine((ns.BlessNative and ns.BlessNative.Active()) and L.BLESS_ESTIMATED_LIVE or L.BLESS_ESTIMATED, 0.6, 0.6, 0.6, true)
            end
            for _, m in ipairs(B.missing) do
                if m.class == self.cls then
                    for _, b in ipairs(m.list) do
                        if b == self.blessing then GameTooltip:AddLine(L.BLESS_TIP_MISSING:format(m.name), 1, 0.4, 0.4) end
                    end
                end
            end
            for _, s in ipairs(B.Singles(B.Me())) do
                if s.member.class == self.cls and s.blessing ~= self.blessing then
                    GameTooltip:AddLine(L.BLESS_TIP_INSTEAD:format(s.member.name, B.Name(s.blessing)), 0.55, 0.75, 1, true)
                end
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.BLESS_ROW_TIP, 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        -- wheel: change the blessing for this class (secure attributes can only
        -- follow outside of combat, so it is blocked there)
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", function(self, delta)
            if not self.cls then return end
            if inCombat() then ns.Print(L.BLESS_WHEEL_COMBAT); return end
            if B.Cycle(B.Me(), self.cls, delta, true) then
                self.blessing = B.Me().set[self.cls]
                if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
            end
        end)
    end
    r:HookScript("OnLeave", function() GameTooltip:Hide() end)
    -- pop-out with the players
    local fly = makeFly(i, r)
    r.fly = fly
    if header and setRef(r, "lg-fly", fly) then
        r.secureFly = true
        wrap(r, "OnEnter", FLY_ENTER)
        wrap(r, "OnLeave", FLY_LEAVE)
    else
        r:HookScript("OnEnter", function(self)
            if inCombat() then return end
            for _, f in pairs(flies) do if f ~= self.fly then f:Hide() end end
            if self.hasFly then self.fly:Show() end
        end)
        r:HookScript("OnLeave", function(self)
            if not inCombat() and not self.fly:IsMouseOver() then self.fly:Hide() end
        end)
    end
    r:Hide()
    rows[i] = r
    return r
end

-- aura / seal / fury: one secure button each
local function makeSelfButton(kind)
    local b = CreateFrame("Button", "LiebeGruesseBless" .. kind:sub(1, 1):upper() .. kind:sub(2), frame, "SecureActionButtonTemplate")
    b:SetSize(WIDTH - 8, ROW_H - 4)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.kind = kind
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetTexture(Theme.WHITE); b.bg:SetAllPoints()
    b.base = UI.Fill(b, "rowAlt", "BACKGROUND"); b.base:SetAllPoints(); b.base:SetDrawLayer("BACKGROUND", -1)
    b.hl = UI.Fill(b, "hover", "HIGHLIGHT"); b.hl:SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(20, 20); b.icon:SetPoint("LEFT", 6, 0)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.state = UI.Text(b, 11, "muted", "RIGHT"); b.state:SetPoint("RIGHT", -6, 0)
    b.label = UI.Text(b, 12, "text"); b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0); b.label:SetPoint("RIGHT", b.state, "LEFT", -4, 0)
    b.label:SetWordWrap(false)
    b:SetScript("OnEnter", function(self)
        UI.Tooltip(self, self.spell or L["BLESS_SELF_" .. kind:upper()], { self.active and L.BLESS_SELF_ON or L.BLESS_SELF_OFF, " ", L.BLESS_SELF_TIP })
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:HookScript("PostClick", function(self, mouse, down)
        if down or mouse ~= "RightButton" or inCombat() then return end
        if kind == "fury" then return end
        local items = Bar.SelfChoices(kind == "aura" and Bar.AURAS or Bar.SEALS)
        UI.OpenMenu(self, items, function(v) opt()[kind .. "Spell"] = v; Bar.Update() end, 200, opt()[kind .. "Spell"])
    end)
    b:Hide()
    selfButtons[kind] = b
    return b
end

local function smartAssign()
    if inCombat() then ns.Print(L.BLESS_WHEEL_COMBAT); return end
    if B.Suggest() then ns.Print(L.BLESS_SUGGESTED) else ns.Print(L.BLESS_CANT_EDIT) end
end

local function create()
    if frame or inCombat() then return frame end
    frame = UI.Panel(UIParent, "bg", "border")
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetWidth(WIDTH)
    frame:Hide()

    local head = CreateFrame("Frame", nil, frame)
    head:SetPoint("TOPLEFT", 4, -4)
    head:SetPoint("TOPRIGHT", -4, -4)
    head:SetHeight(HEAD_H - 2)
    local open = UI.IconButton(head, "users", 22, function() ns.Window.Show("blessings") end)
    open:SetPoint("LEFT")
    open.tip = L.PAGE_BLESSINGS
    local quick = UI.IconButton(head, "layout-grid", 22, function() if ns.BlessAssign then ns.BlessAssign.Toggle() end end)
    quick:SetPoint("LEFT", open, "RIGHT", 3, 0)
    quick.tip, quick.tipLines = L.BLESS_QUICK, { L.BLESS_QUICK_TIP }
    local smart = UI.IconButton(head, "sparkles", 22, smartAssign)
    smart:SetPoint("LEFT", quick, "RIGHT", 3, 0)
    smart.tip, smart.tipLines = L.BLESS_SMART, { L.BLESS_SMART_TIP }
    frame.smart = smart
    local lock = ns.Movers.LockButton("blessingsBar", frame, head, 22)
    lock:SetPoint("LEFT", smart, "RIGHT", 3, 0)
    frame.nextIcon = head:CreateTexture(nil, "ARTWORK")
    frame.nextIcon:SetSize(22, 22)
    frame.nextIcon:SetPoint("RIGHT")
    frame.nextIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    for _, kind in ipairs({ "aura", "seal", "fury" }) do makeSelfButton(kind) end

    -- cast the next missing blessing (secure); right click: smart assign
    auto = CreateFrame("Button", "LiebeGruesseBlessAuto", frame, "SecureActionButtonTemplate, BackdropTemplate")
    auto:SetSize(WIDTH - 8, 26)
    auto:RegisterForClicks("AnyUp", "AnyDown")
    UI.Skin(auto, "button", "border")
    auto.icon = UI.Icon(auto, "zap", 14, "accent")
    auto.icon:SetPoint("LEFT", 8, 0)
    auto.left = UI.Text(auto, 12, "good", "RIGHT")
    auto.left:SetPoint("RIGHT", -8, 0)
    auto.label = UI.Text(auto, 12, "text")
    auto.label:SetPoint("LEFT", auto.icon, "RIGHT", 8, 0)
    auto.label:SetText(L.BLESS_AUTO)
    -- registered for down and up (the cast follows the key-down setting):
    -- PostClick runs for both, the assignment only once on release
    auto:SetScript("PostClick", function(_, button, down)
        if button == "LeftButton" then noteClick(auto, button) end
        if down then return end
        if button == "RightButton" and not inCombat() then
            if B.Suggest() then ns.Print(L.BLESS_SUGGESTED) end
        end
    end)
    auto:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(Theme.Color("accent"))
        UI.Tooltip(self, L.BLESS_AUTO, { L.BLESS_AUTO_TIP })
    end)
    auto:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(Theme.Color("border")); GameTooltip:Hide() end)

    secureHeader()
    for i = 1, SINGLE_ROW do makeRow(i) end
    -- every row knows every pop-out (to hide the others)
    for _, r in ipairs(rows) do
        if r.secureFly then
            for j, f in pairs(flies) do setRef(r, "lg-fly" .. j, f) end
        end
    end
    frame.empty = UI.Text(frame, 11, "muted", "CENTER")
    frame.empty:SetWordWrap(true)
    frame.empty:SetText(L.BLESS_BAR_EMPTY)
    ns.Movers.Attach("blessingsBar", frame)
    -- the live strip lives outside the bar frame: hide it with the bar
    frame:HookScript("OnHide", function()
        if ns.BlessNative and not inCombat() then ns.Safe(ns.BlessNative.Layout, {}) end
    end)
    return frame
end

---------------------------------------------------------------------------
-- Update: texts every time, secure attributes only out of combat
---------------------------------------------------------------------------
local function shouldShow()
    if B.test then return true end
    if not B.Enabled() or not B.IsPaladin() then return false end
    if ns.Movers.active then return true end
    local o = opt()
    if not o.bar then return false end
    if not IsInGroup() then return o.solo end
    if o.raidOnly then return IsInRaid() end
    return true
end

-- texts of one class row; safe in combat
local function paintRow(r)
    local class, blessing, present = r.cls, r.blessing, not r.absent
    local units = B.classUnits[class] or {}
    local st = B.status[class] or { total = #units, have = {}, left = {}, need = {} }
    -- total: players who should get it (a single from you replaces it on someone)
    local have = st.have[blessing] or 0
    local total = st.want and st.want[blessing] or (st.total > 0 and st.total or #units)
    if not B.status[class] then total = #units end
    ns.SetClassIcon(r.class, class)
    r.bless:SetTexture(B.Icon(blessing))
    local left = st.left[blessing]
    if present then
        -- "~": aura data hidden (combat), the numbers are the last known state
        r.count:SetText(opt().counts ~= false and countText(have, total, st.estimated) or "")
        r.left:SetText(showTimes() and fmtLeft(left) or "")
        r.left:SetTextColor(Theme.Color(left and left < 300 and "warn" or "good"))
    else
        r.count:SetText(Theme.HexColor("muted", "—"))
        r.left:SetText("")
    end
    tint(r.bg, have, total, present)
    r.mark:SetShown(present and have < total)
    r:SetAlpha(present and 1 or 0.55)
    return st, have, total, left
end

-- your singles: done (on the player), total (players in the group)
function Bar.SingleCount()
    local done, total = 0, 0
    for _, s in ipairs(B.Singles(B.Me())) do
        total = total + 1
        if B.SingleState(s.key, s.blessing) then done = done + 1 end
    end
    return done, total
end

local function paintSingleRow(r)
    local done, total = Bar.SingleCount()
    r.count:SetText(L.BLESS_SINGLE_HEAD .. "  " .. (total == 0 and Theme.HexColor("muted", "—") or countText(done, total)))
    r.left:SetText(total == 0 and Theme.HexColor("accent", "+") or "")
    tint(r.bg, done, total, total > 0)
    r.mark:SetShown(total > 0 and done < total)
end

-- one player in a pop-out: what you give him and whether he has it
local function paintPlayer(b)
    local m = B.members[b.key]
    if not m then return end
    if not ns.SetSpecIcon(b.spec, m.class, ns.SpecPoints(ns.Database.Member(b.key))) then ns.SetClassIcon(b.spec, m.class) end
    b.bless:SetTexture(b.blessing and B.Icon(b.blessing) or nil)
    local name = ns.Names.Display(m.name):match("^(%S+)") or m.name
    local cr, cg, cb = ns.ClassColor(m.class)
    local has, left, est = false, nil, false
    if b.blessing then has, left, est = B.SingleState(b.key, b.blessing) end
    local dead = ns.Call(UnitIsDeadOrGhost, m.unit) or ns.Call(UnitIsConnected, m.unit) == false
    b.name:SetText(ns.Hex(cr, cg, cb, (est and "~" or "") .. name))
    b.left:SetText(not b.blessing and "" or (has and (showTimes() and fmtLeft(left) or "") or Theme.HexColor("bad", L.BLESS_SINGLE_MISSING)))
    if has then b.left:SetTextColor(Theme.Color(left and left < 300 and "warn" or "good")) end
    tint(b.bg, has and 1 or 0, b.blessing and 1 or 0, b.blessing ~= nil)
    b.mark:SetShown(b.single or false)
    b:SetAlpha(dead and 0.5 or 1)
end

-- fills a pop-out with players (outside of combat): list of { key, blessing, single, pinned }
local function fillFly(i, row, list)
    local fly = flies[i]
    if not fly then return end
    local n = math.min(#list, MAX_PLAYERS)
    local hasFly = opt().players ~= false and n > 0
    fly:ClearAllPoints()
    if opt().side == "right" then fly:SetPoint("TOPLEFT", row, "TOPRIGHT", 0, 2)
    else fly:SetPoint("TOPRIGHT", row, "TOPLEFT", 0, 2) end
    fly:SetHeight(math.max(1, n) * PROW_H + 4)
    for j = 1, n do
        local e, b = list[j], playerButton(fly, j)
        b.key, b.blessing, b.single, b.pinned = e.key, e.blessing, e.single, e.pinned
        paintPlayer(b)
        local m = B.members[e.key]
        local spell = e.blessing and B.SpellName(B.SpellFor(e.blessing, "single"))
        local ok = spell and m and usable(m.unit)
        setSecure(b, { type1 = ok and "spell" or nil, spell1 = ok and spell or nil, unit1 = ok and m.unit or nil, type2 = false, spell2 = false, unit2 = false })
        b:Show()
    end
    for j = n + 1, #fly.buttons do fly.buttons[j]:Hide(); fly.buttons[j].key = nil end
    row.hasFly = hasFly
    row.flyList = list
    setSecure(row, { ["lg-hasfly"] = hasFly or false })
    if B.test then row:SetAttribute("lg-hasfly", hasFly or nil) end
    if not hasFly then fly:Hide() end
end

-- players of a class with what you give each of them
local function classPlayers(class)
    local me = B.Me()
    local out = {}
    for _, unit in ipairs(B.classUnits[class] or {}) do
        local key = B.unitKey[unit]
        if key then
            local single = me and me.single and me.single[key]
            out[#out + 1] = { key = key, blessing = me and B.Gives(me, key, class), single = single ~= nil,
                pinned = me and me.pinned and me.pinned[key] or false }
        end
    end
    return out
end

-- self buff buttons (aura / seal / fury): which one, cast attributes, green while on
local function paintSelf(kind, b, combat)
    local ids = choice(kind)
    local id = ids and knownId(ids)
    local name = id and B.SpellName(id)
    b.spell = name
    local buffs = ownBuffs
    b.active = name and buffs[name] or false
    b.icon:SetTexture(id and ((C_Spell and C_Spell.GetSpellTexture and ns.Call(C_Spell.GetSpellTexture, id)) or (GetSpellTexture and ns.Call(GetSpellTexture, id))) or nil)
    b.label:SetText(name or L["BLESS_SELF_" .. kind:upper()])
    b.state:SetText(b.active and Theme.HexColor("good", L.BLESS_SELF_ON_SHORT) or Theme.HexColor("bad", L.BLESS_SELF_OFF_SHORT))
    tint(b.bg, b.active and 1 or 0, 1, name ~= nil)
    if not combat then setSecure(b, { type1 = name and "spell" or nil, spell1 = name, unit1 = "player" }) end
    return name ~= nil
end

local function combatRefresh()
    for _, r in ipairs(rows) do
        if r:IsShown() then
            if r.cls and r.blessing then paintRow(r) elseif r == rows[SINGLE_ROW] then paintSingleRow(r) end
            for _, b in ipairs(r.fly and r.fly.buttons or {}) do if b:IsShown() and b.key then paintPlayer(b) end end
        end
    end
    for kind, b in pairs(selfButtons) do if b:IsShown() then paintSelf(kind, b, true) end end
end

function Bar.Update()
    if frame and inCombat() then
        if frame:IsShown() then readOwnBuffs(); combatRefresh() end
        return
    end
    if not shouldShow() then
        if frame and frame:IsShown() and not inCombat() then frame:Hide() end
        return
    end
    if not create() then return end
    if not B.Me() then B.Rebuild() end
    local me = B.Me()
    -- first time on this character: fill in your own blessings right away,
    -- so the bar works without a click on Smart assign
    local char = ns.Database.Char()
    -- (done once something was assigned: right after login the spells can be unknown yet)
    if me and not B.test and not char.blessingsAuto and not Bar.autoRunning and not inCombat() and not next(me.set or {}) then
        me.can = B.OwnSkills()
        local any = false
        for _, v in pairs(me.can) do if v > 0 then any = true end end
        Bar.autoRunning = true   -- Suggest calls Update again
        local ok = any and B.Suggest(true)
        Bar.autoRunning = false
        if ok and next(me.set or {}) then
            char.blessingsAuto = true
            ns.Print(L.BLESS_AUTO_FIRST)
            return   -- Suggest has updated the bar
        end
    end
    readOwnBuffs()
    local o = opt()
    local set = me and me.set or {}
    -- solo every assigned class gets a row, so you can see and change your plan
    local solo = not IsInGroup() and not B.test
    local y = HEAD_H + 4
    -- self buffs on top
    for _, kind in ipairs({ "aura", "seal", "fury" }) do
        local b = selfButtons[kind]
        local on = o[kind] == true and B.IsPaladin() or (B.test and o[kind] == true)
        if on and paintSelf(kind, b, false) then
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", 4, -y); b:Show()
            y = y + ROW_H - 2
        else
            b:Hide()
        end
    end
    auto:ClearAllPoints(); auto:SetPoint("TOPLEFT", 4, -y)
    y = y + 26 + 4
    local n = 0
    local nextCast
    local shortest
    local function candidate(score, spell, unit, blessing)
        if not nextCast or score > nextCast.score then
            nextCast = { score = score, spell = spell, unit = unit, blessing = blessing }
        end
    end
    for _, class in ipairs(B.CLASSES) do
        local blessing = set[class]
        local units = B.classUnits[class]
        local present = units and #units > 0
        if blessing and (present or solo) then
            n = n + 1
            local r = rows[n]
            r.cls, r.blessing, r.absent = class, blessing, not present
            local st, have, total, left = paintRow(r)
            if present and left and (not shortest or left < shortest) then shortest = left end
            if not present then
                setSecure(r, { type1 = false, spell1 = false, unit1 = false, type2 = false, spell2 = false, unit2 = false })
                fillFly(n, r, {})
            else
                local greater = B.SpellName(B.SpellFor(blessing, "greater"))
                local single = B.SpellName(B.SpellFor(blessing, "single"))
                local need = st.need and st.need[blessing]
                local pool = (st.units and st.units[blessing]) or (B.status[class] and {}) or nil
                local gUnit = greater and pickUnit(class, greater, need)
                local sUnit = single and pickUnit(class, single, need, pool)
                setSecure(r, {
                    type1 = (greater or single) and "spell" or nil, spell1 = greater or single, unit1 = greater and gUnit or sUnit,
                    type2 = (single and sUnit) and "spell" or nil, spell2 = sUnit and single or nil, unit2 = sUnit,
                })
                rotation(r, class, sUnit, need, pool)
                fillFly(n, r, classPlayers(class))
                -- the next cast: the class with the fewest buffed, then the shortest time left;
                -- class blessings before singles (a greater one replaces your single on that class)
                if (have < total or (left and left < 300)) and (greater or single) then
                    candidate(1000000 + (total - have) * 10000 - (left or 0), greater or single, greater and gUnit or sUnit, blessing)
                end
            end
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 4, -y)
            r:Show()
            y = y + ROW_H
        end
    end
    for i = n + 1, #B.CLASSES do rows[i]:Hide(); if flies[i] then flies[i]:Hide() end end
    -- singles: one button, its pop-out lists the players
    local singles = (IsInGroup() or B.test) and me and B.Singles(me) or {}
    local srow = rows[SINGLE_ROW]
    if (IsInGroup() or B.test) and me then
        paintSingleRow(srow)
        local list = {}
        for _, s in ipairs(singles) do
            list[#list + 1] = { key = s.key, blessing = s.blessing, single = true, pinned = s.pinned }
            local spell = B.SpellName(B.SpellFor(s.blessing, "single"))
            local has, left = B.SingleState(s.key, s.blessing)
            if has and left and (not shortest or left < shortest) then shortest = left end
            if spell and usable(s.member.unit) and (not has or (left and left < 300)) then
                candidate(has and -(left or 0) or 5000, spell, s.member.unit, s.blessing)
            end
        end
        fillFly(SINGLE_ROW, srow, list)
        srow:ClearAllPoints(); srow:SetPoint("TOPLEFT", 4, -y); srow:Show()
        y = y + ROW_H
    else
        srow:Hide(); flies[SINGLE_ROW]:Hide()
    end
    -- live status strip (drawn by the game, also in combat)
    if ns.BlessNative then
        local live = {}
        if not B.test then
            for i = 1, n do
                local r = rows[i]
                if not r.absent then
                    local st = B.status[r.cls]
                    local list = (st and st.units and st.units[r.blessing]) or B.classUnits[r.cls] or {}
                    live[#live + 1] = { row = r, units = list, blessing = r.blessing }
                end
            end
        end
        ns.Safe(ns.BlessNative.Layout, live)
    end
    setSecure(auto, { type1 = nextCast and "spell" or nil, spell1 = nextCast and nextCast.spell, unit1 = nextCast and nextCast.unit })
    auto.left:SetText(showTimes() and shortest and fmtLeft(shortest) or "")
    auto.left:SetTextColor(Theme.Color(shortest and shortest < 300 and "warn" or "good"))
    local empty = n == 0 and not srow:IsShown()
    frame.empty:SetShown(empty)
    if empty then
        frame.empty:ClearAllPoints()
        frame.empty:SetPoint("TOPLEFT", 6, -y)
        frame.empty:SetPoint("TOPRIGHT", -6, -y)
        y = y + 44
    end
    frame:SetHeight(y + 2)
    frame:Show()
    frame.nextIcon:SetTexture(nextCast and B.Icon(nextCast.blessing) or nil)
    frame.nextIcon:SetShown(nextCast ~= nil)
end

function Bar.Shown() return frame ~= nil and frame:IsShown() end

-- scale of the bar (also in "Move elements")
function Bar.Scale() return ns.Movers.Scale and ns.Movers.Scale("blessingsBar") or 1 end
function Bar.SetScale(v)
    if inCombat() then return end
    if ns.Movers.SetScale then ns.Movers.SetScale("blessingsBar", v) end
end

ns.On("LG_BLESSINGS", function() Bar.Update() end)
ns.On("LG_MOVERS", function() ns.AfterCombat("bless-bar", Bar.Update) end)
ns.On("PLAYER_REGEN_ENABLED", function() ns.After(0.5, Bar.Update) end)
ns.On("LG_READY", function()
    ns.Movers.Anchor("blessingsBar", L.BLESS_BAR, { "RIGHT", "RIGHT", -40, 120 }, WIDTH, 120, nil, { icon = "sparkles", scalable = true,
        settings = function() ns.Window.Show("blessings") end })
    if B.IsPaladin() then ns.After(5, Bar.Update) end
end)
