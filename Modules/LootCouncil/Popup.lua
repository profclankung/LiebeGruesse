-- Response popup: every raider answers for each item of a session
local _, ns = ...
local UI, Theme, L, Items, Council = ns.UI, ns.Theme, ns.L, ns.Items, ns.Council

local frame
local ROW_HEIGHT = 64

local function buildRow(parent, index)
    local row = UI.Panel(parent, "panel", "borderDim")
    row:SetHeight(ROW_HEIGHT - 4)
    row.icon = UI.ItemIcon(row, 36)
    row.icon:SetPoint("TOPLEFT", 8, -8)
    row.name = UI.Text(row, 13, "text")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
    row.name:SetPoint("TOPRIGHT", -170, -8)
    row.slotText = UI.Text(row, 11, "muted")
    row.slotText:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.equipped = {}
    for i = 1, 2 do
        local e = UI.ItemIcon(row, 22)
        e:SetPoint("TOPRIGHT", -8 - (i - 1) * 26, -8)
        row.equipped[i] = e
    end
    row.equippedLabel = UI.Text(row, 10, "muted", "RIGHT")
    row.equippedLabel:SetPoint("RIGHT", row.equipped[2], "LEFT", -6, 0)
    row.equippedLabel:SetText(L.LC_EQUIPPED)
    row.note = UI.EditBox(row, 150, 20, L.LC_NOTE)
    row.note:SetPoint("BOTTOMRIGHT", -8, 6)
    row.buttons = {}
    row.done = UI.Text(row, 12, "gold")
    row.done:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, -16)
    return row
end

local refresh
local function create()
    frame = UI.Panel(UIParent, "bg", "border")
    if frame.SetClipsChildren then frame:SetClipsChildren(true) end
    frame:SetSize(690, 120)
    frame.defaultSize = { 690, 120 }
    -- width is free; the height follows the number of items
    UI.Resizable(frame, "lcPopup", 520, 100, 1400, 900, function() if frame:IsShown() then refresh() end end)
    UI.Float(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    ns.Movers.Attach("lcPopup", frame)
    local crest = frame:CreateTexture(nil, "OVERLAY")
    crest:SetTexture(ns.media .. "icon")
    crest:SetSize(32, 32)
    crest:SetPoint("TOPLEFT", 8, -6)
    frame.title = UI.Text(frame, 14, "gold")
    frame.title:SetPoint("LEFT", crest, "RIGHT", 8, 0)
    frame.timer = UI.Text(frame, 12, "muted", "RIGHT")
    frame.timer:SetPoint("TOPRIGHT", -40, -14)
    local close = UI.CloseX(frame, nil, 20)
    frame.rows = {}
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.acc = (self.acc or 0) + elapsed
        if self.acc < 0.5 then return end
        self.acc = 0
        local s = Council.session
        if not s or s.ended then self:Hide(); return end
        local left = s.timeout - (GetTime() - s.receivedAt)
        if left <= 0 then
            for i in ipairs(s.items) do
                if not s.mine[i] then Council.Respond(i, "none", "") end
            end
            self:Hide()
            return
        end
        self.timer:SetText(L.LC_POPUP_LEFT:format(ns.Duration(left)))
    end)
end

function refresh()
    local s = Council.session
    if not frame or not s then return end
    frame.title:SetText(L.LC_POPUP_TITLE:format(ns.Names.Display(s.ml)))
    local open = 0
    for i, item in ipairs(s.items) do
        local row = frame.rows[i]
        if not row then
            row = buildRow(frame, i)
            frame.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 8, -44 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", -8, -44 - (i - 1) * ROW_HEIGHT)
        row.icon:SetItem(item.s)
        local info = Items.Info(item.s)
        local q = info and info.quality
        local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
        row.name:SetText(info and ((c and c.hex or "") .. info.name .. "|r") or L.LOADING)
        local slotName = info and info.equipLoc and _G[info.equipLoc] or ""
        row.slotText:SetText(("%s  %s"):format(slotName or "", info and info.level and (L.ITEM_LEVEL_SHORT .. " " .. info.level) or ""))
        local slots = info and Items.EQUIP_SLOTS[info.equipLoc] or {}
        for e = 1, 2 do
            local slot = slots[e]
            row.equipped[e]:SetItem(slot and Items.String(ns.Call(GetInventoryItemLink, "player", slot)) or nil)
        end
        row.equippedLabel:SetShown(#slots > 0)

        local answered = s.mine[i]
        if not answered and not item.awarded and ns.Database.Settings().lcAutoPass and info and not Council.CanUse(item.s) then
            s.mine[i] = "autopass"
            answered = "autopass"
            ns.After(0.1, function() Council.Respond(i, "autopass", "") end)
        end
        -- answer buttons share the room between the icon and the note box
        local room = (frame:GetWidth() or 690) - 16 - 52 - 166
        local bw = math.max(48, math.min(110, math.floor(room / math.max(1, #s.responses)) - 4))
        for b, resp in ipairs(s.responses) do
            local btn = row.buttons[b]
            if not btn then
                btn = UI.Button(row, "", 76, 20)
                row.buttons[b] = btn
            end
            btn:ClearAllPoints()
            btn:SetWidth(bw)
            btn:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8 + (b - 1) * (bw + 4), -16)
            btn.tip = { resp.t }
            btn:SetText(resp.t)
            btn.label:SetTextColor(resp.c[1], resp.c[2], resp.c[3])
            btn:SetScript("OnClick", function()
                Council.Respond(i, resp.k, row.note:GetText() or "")
            end)
            btn:SetShown(not answered and not item.awarded)
        end
        for b = #s.responses + 1, #row.buttons do row.buttons[b]:Hide() end
        row.note:SetShown(not answered and not item.awarded)
        if item.awarded then
            row.done:SetText(L.LC_AWARDED_TO:format(ns.Names.Display(item.awarded)))
        elseif answered then
            local r = Council.ResponseInfo(answered, s)
            row.done:SetText(L.LC_YOUR_ANSWER:format(ns.Hex(r.c[1], r.c[2], r.c[3], r.t)))
        end
        row.done:SetShown(answered ~= nil or item.awarded ~= nil)
        if not answered and not item.awarded then open = open + 1 end
        row:Show()
    end
    for i = #s.items + 1, #frame.rows do frame.rows[i]:Hide() end
    local h = 48 + #s.items * ROW_HEIGHT
    frame:SetHeight(h)
    if frame.SetResizeBounds then frame:SetResizeBounds(520, h, 1400, h) end
    return open
end

local Popup = {}
ns.CouncilPopup = Popup

function Popup.Show()
    if not frame then create() end
    frame:Show()
    refresh()
end

ns.On("LG_COUNCIL_START", function(_, s)
    if ns.Database.Settings().modules.council == false then return end
    if s and not s.ended then Popup.Show() end
end)
ns.On("LG_COUNCIL", function()
    if frame and frame:IsShown() then
        local open = refresh()
        if open == 0 then ns.After(4, function()
            local s = Council.session
            local still = 0
            if s then for i, item in ipairs(s.items) do if not s.mine[i] and not item.awarded then still = still + 1 end end end
            if still == 0 and frame then frame:Hide() end
        end) end
    end
end)
ns.On("LG_ITEMS", function() if frame and frame:IsShown() then refresh() end end)

ns.On("LG_READY", function()
    ns.Movers.Anchor("lcPopup", L.MOVER_LC_POPUP, { "TOP", "TOP", 0, -290 }, 690, 120, nil,
        { icon = "gem", scalable = true, settings = function() ns.Window.Show("council"); if ns.CouncilPage then ns.CouncilPage.ShowSetup() end end })
end)
