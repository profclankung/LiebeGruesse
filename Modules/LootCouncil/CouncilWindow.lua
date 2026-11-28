-- Council window: candidates per item, votes and awarding
local _, ns = ...
local UI, Theme, L, Items, Names, Council = ns.UI, ns.Theme, ns.L, ns.Items, ns.Names, ns.Council

local CouncilWindow = {}
ns.CouncilWindow = CouncilWindow

local frame, list
local state = { item = 1, selected = nil, prep = false }

local function iconText(item, size)
    if not item then return "" end
    return ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(Items.Icon(item), size or 16, size or 16)
end

local function voteCount(s, i, key)
    local n = 0
    for _ in pairs(s.votes[i] and s.votes[i][key] or {}) do n = n + 1 end
    return n
end

local function myVote(s, i, key)
    return s.votes[i] and s.votes[i][key] and s.votes[i][key][Names.Me()] or false
end

local function filter()
    local st = ns.Database.Settings()
    st.lcFilter = st.lcFilter or { pass = true, waiting = true, removed = true }
    return st.lcFilter
end

-- Rows: every responder plus group members still waiting
local function rows()
    local s = Council.session
    local result = {}
    if not s or not s.items[state.item] then return result end
    local i = state.item
    local f = filter()
    local seen = {}
    for key, c in pairs(s.cand[i]) do
        seen[key] = true
        local info, order = Council.ResponseInfo(c.r, s)
        if c.removed then order = order + 200 end
        local hidden = (c.removed and not f.removed) or ((c.r == "pass" or c.r == "autopass") and not f.pass)
        if not hidden then
            result[#result + 1] = { key = key, c = c, info = info, order = order, votes = voteCount(s, i, key) }
        end
    end
    if not s.test and f.waiting then
        for unit, key, name in ns.GroupUnits() do
            if not seen[key] then
                local _, class = ns.Call(UnitClass, unit)
                local info, order = Council.ResponseInfo("wait", s)
                result[#result + 1] = { key = key, c = { name = name, c = class, g = {} }, info = info, order = order, votes = 0, waiting = true }
            end
        end
    end
    return result
end

---------------------------------------------------------------------------
-- Right-click menus
---------------------------------------------------------------------------
local function candidateMenu(row)
    local s = Council.session
    if not s then return end
    local i = state.item
    local item = s.items[i]
    local key = row.key
    local ml = Council.AmML(s) and not s.ended
    local open = item and not item.awarded and not s.ended
    local name = row.c.name or key
    local entries = { { title = ns.ColorName(Names.Display(name), row.c.c) } }
    if Council.AmCouncil(s) and open and not row.waiting then
        local mine = myVote(s, i, key)
        entries[#entries + 1] = { text = mine and L.LC_UNVOTE or L.LC_VOTE, func = function() Council.Vote(i, key, not mine) end,
            disabled = not s.selfVote and Names.Same(key, Names.Me()) }
    end
    if ml and open then
        entries[#entries + 1] = { divider = true }
        entries[#entries + 1] = { text = L.LC_AWARD, color = "text", func = function() CouncilWindow.ConfirmAward(i, key) end }
        local reasons = {}
        for _, r in ipairs(Council.Config().reasons or {}) do
            reasons[#reasons + 1] = { text = r, func = function() CouncilWindow.ConfirmAward(i, key, r) end }
        end
        if #reasons == 0 then reasons[1] = { text = L.LC_NO_REASONS, disabled = true } end
        entries[#entries + 1] = { text = L.LC_AWARD_FOR, submenu = reasons }
        entries[#entries + 1] = { divider = true }
        local responses = {}
        for _, r in ipairs(s.responses) do
            responses[#responses + 1] = { text = ns.Hex(r.c[1], r.c[2], r.c[3], r.t), checked = row.c.r == r.k,
                func = function() Council.ChangeResponse(i, key, r.k, row.c.name, row.c.c) end }
        end
        entries[#entries + 1] = { text = L.LC_CHANGE_RESPONSE, submenu = responses }
        entries[#entries + 1] = { text = L.LC_REASK, submenu = {
            { text = L.LC_REASK_ITEM, func = function() Council.Reask(i, key) end },
            { text = L.LC_REASK_ALL_ITEMS, func = function() Council.Reask(nil, key) end },
        } }
        if not row.waiting then
            entries[#entries + 1] = { text = L.LC_REQUEST_ROLL, func = function() Council.RequestRoll(i, key) end }
            entries[#entries + 1] = { text = row.c.removed and L.LC_RESTORE or L.LC_REMOVE_CAND,
                func = function() Council.SetRemoved(i, key, not row.c.removed) end }
        end
    end
    entries[#entries + 1] = { divider = true }
    entries[#entries + 1] = { text = L.LC_WHISPER_CAND, func = function()
        local g = ns.Guild.Find(key)
        if ChatFrame_SendTell then ChatFrame_SendTell(g and g.name or Names.Display(name)) end
    end }
    ns.UI.ContextMenu(entries)
end

local function itemMenu(i)
    local s = Council.session
    if not s or not s.items[i] then return end
    local item = s.items[i]
    local ml = Council.AmML(s) and not s.ended
    local open = not item.awarded
    local entries = { { title = Items.Link(item.s) or item.s } }
    if ml and open then
        entries[#entries + 1] = { text = L.LC_AWARD_LATER, tip = L.LC_AWARD_LATER_TIP, func = function() Council.AwardLater(i) end }
        entries[#entries + 1] = { text = L.LC_REASK_EVERYONE, func = function() Council.Reask(i, nil) end }
        entries[#entries + 1] = { text = L.LC_ADD_ROLLS, tip = L.LC_ADD_ROLLS_TIP, func = function() Council.AddRolls(i) end }
        entries[#entries + 1] = { text = L.LC_REQUEST_ROLLS, tip = L.LC_REQUEST_ROLLS_TIP, func = function() Council.RequestRoll(i) end }
        entries[#entries + 1] = { text = L.LC_RESET_VOTES, func = function() Council.ResetVotes(i) end }
        entries[#entries + 1] = { divider = true }
    end
    entries[#entries + 1] = { text = L.LC_POST_STANDINGS, func = function() Council.PostStandings(i) end, disabled = not IsInGroup() }
    entries[#entries + 1] = { text = L.LC_LINK_ITEM, func = function()
        if ChatEdit_InsertLink then ChatEdit_InsertLink(Items.Link(item.s) or item.s) end
    end }
    ns.UI.ContextMenu(entries)
end

local function filterMenu()
    local f = filter()
    local function toggle(k) return function() f[k] = not f[k]; CouncilWindow.Refresh() end end
    ns.UI.ContextMenu({
        { title = L.LC_FILTER },
        { text = L.LC_FILTER_PASS, checked = f.pass, func = toggle("pass") },
        { text = L.LC_FILTER_WAITING, checked = f.waiting, func = toggle("waiting") },
        { text = L.LC_FILTER_REMOVED, checked = f.removed, func = toggle("removed") },
    })
end

local bagCache = {}
local function prepVisible()
    local s = Council.session
    return not s or state.prep
end

local function updateButtons()
    local s = Council.session
    if not frame then return end
    local prep = prepVisible()
    local sel = state.selected
    local item = s and s.items[state.item]
    local canAct = s and not s.ended and item and not item.awarded and sel
    for _, b in ipairs({ frame.vote, frame.award, frame.reason, frame.reset, frame.reannounce, frame.finish }) do b:SetShown(not prep) end
    if not prep then
        frame.vote:SetEnabled(canAct and Council.AmCouncil(s) and (s.selfVote or not Names.Same(sel, Names.Me())) or false)
        if canAct and myVote(s, state.item, sel) then frame.vote:SetText(L.LC_UNVOTE) else frame.vote:SetText(L.LC_VOTE) end
        frame.award:SetShown(s and Council.AmML(s) or false)
        frame.award:SetEnabled(canAct and Council.AmML(s) or false)
        local ml = s and Council.AmML(s) and not s.ended or false
        frame.finish:SetShown(ml)
        frame.reason:SetShown(s and Council.AmML(s) or false)
        frame.reason:Refresh()
        -- narrow window: "reset" and "ask again" move into a small menu
        local narrow = (frame:GetWidth() or 1000) < 1060
        frame.reset:SetShown(ml and not narrow)
        frame.reannounce:SetShown(ml and not s.test and not narrow)
        frame.more:SetShown(ml and narrow)
    else
        frame.more:Hide()
    end
    local running = s and not s.ended
    -- "Start session" and "Add all" are always visible in the queue view
    frame.start:SetShown(prep and not running or false)
    frame.start:SetText(L.LC_START_PENDING:format(#Council.pending))
    local mayStart = #Council.pending > 0 and (Council.IAmLootMaster() or not IsInGroup())
    frame.start:SetEnabled(mayStart)
    frame.start.tip = { mayStart and L.LC_START_TIP or (#Council.pending == 0 and L.LC_START_NEED_ITEMS or L.LC_START_NEED_ML) }
    local open = 0
    for _, b in ipairs(bagCache) do if not b.queued then open = open + 1 end end
    frame.recent:SetShown(prep or false)
    frame.recent:SetText(L.LC_ADD_ALL:format(open))
    frame.recent:SetEnabled(open > 0)
    -- people outside the council only see the items, not the votes
    local outsider = s and not prep and not Council.AmCouncil(s)
    if outsider then
        for _, b in ipairs({ frame.vote, frame.award, frame.reason, frame.reset, frame.reannounce, frame.finish, frame.filter, frame.more }) do b:Hide() end
    end
    frame.clear:SetShown(prep and #Council.pending > 0)
    frame.prepToggle:SetShown(s ~= nil)
    frame.filter:SetShown(not prep)
    frame.prepToggle:SetText(prep and L.LC_BACK_TO_SESSION or L.LC_QUEUE_BUTTON:format(#Council.pending))
end

local function refreshPrep()
    bagCache = ns.CouncilQueue.BagItems()
    local rows = {}
    for i, str in ipairs(Council.pending) do rows[#rows + 1] = { key = i, index = i, s = str } end
    frame.prep.queue:SetRows(rows)
    local bags = {}
    for i, b in ipairs(bagCache) do b.key = i; bags[#bags + 1] = b end
    frame.prep.bags:SetRows(bags)
    frame.prep.queueTitle:SetText(L.LC_QUEUE_TITLE:format(#Council.pending))
    frame.prep.bagTitle:SetText(L.LC_BAGS_TITLE:format(#bagCache))
end

local function refresh()
    if not frame or not frame:IsShown() then return end
    local s = Council.session
    local prep = prepVisible()
    frame.prep:SetShown(prep)
    list:SetShown(not prep)
    for _, region in ipairs({ frame.itemIcon, frame.itemName, frame.itemInfo, frame.itemMenu }) do region:SetShown(not prep) end
    frame.itemMenu:SetShown(not prep and s ~= nil)
    if prep then
        for _, tab in ipairs(frame.tabs) do tab:Hide() end
        frame.titleText:SetText(L.LC_PREP_TITLE)
        refreshPrep()
        updateButtons()
        return
    end
    -- item tabs
    for _, tab in ipairs(frame.tabs) do tab:Hide() end
    if s then
        if not s.items[state.item] then state.item = 1 end
        for i, item in ipairs(s.items) do
            local tab = frame.tabs[i]
            if not tab then
                tab = UI.ItemIcon(frame.side, 40)
                tab.check = tab:CreateTexture(nil, "OVERLAY")
                tab.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                tab.check:SetSize(18, 18)
                tab.check:SetPoint("BOTTOMRIGHT", 4, -4)
                frame.tabs[i] = tab
            end
            tab:SetPoint("TOP", 0, -8 - (i - 1) * 46)
            tab:SetItem(item.s)
            tab.check:SetShown(item.awarded ~= nil)
            if i == state.item then tab:SetBackdropBorderColor(Theme.Color("gold")) end
            tab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            tab:SetScript("OnClick", function(_, button)
                state.item = i; state.selected = nil; refresh()
                if button == "RightButton" then itemMenu(i) end
            end)
        end
        local item = s.items[state.item]
        local info = item and Items.Info(item.s)
        frame.itemIcon:SetItem(item and item.s)
        local q = info and info.quality
        local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
        frame.itemName:SetText(info and ((c and c.hex or "") .. info.name .. "|r") or L.LOADING)
        local status
        if item and item.awarded then
            status = Theme.HexColor("good", L.LC_AWARDED_TO:format(Names.Display(item.awarded)))
        elseif s.ended then
            status = Theme.HexColor("muted", L.LC_SESSION_ENDED)
        else
            local answers = 0
            for _ in pairs(s.cand[state.item] or {}) do answers = answers + 1 end
            status = L.LC_ANSWERS:format(answers)
        end
        frame.itemInfo:SetText(("%s  %s  ·  %s"):format(info and info.equipLoc and _G[info.equipLoc] or "",
            info and info.level and (L.ITEM_LEVEL_SHORT .. " " .. info.level) or "", status))
        frame.titleText:SetText(L.LC_WINDOW_TITLE:format(Names.Display(s.ml)) .. (s.test and (" " .. Theme.HexColor("warn", L.LC_TEST_TAG)) or ""))
    else
        frame.itemIcon:SetItem(nil)
        frame.itemName:SetText(L.LC_NO_SESSION)
        frame.itemInfo:SetText(#Council.pending > 0 and L.LC_PENDING_HINT or "")
        frame.titleText:SetText(L.LC_WINDOW_TITLE:format("–"))
    end
    local outsider = s and not Council.AmCouncil(s)
    list:SetShown(not outsider)
    frame.outsider:SetShown(outsider or false)
    if outsider then
        local mine = s.mine and s.mine[state.item]
        local info = mine and Council.ResponseInfo(mine, s)
        frame.outsider:SetText(L.LC_ONLY_COUNCIL .. "\n\n" .. (info and L.LC_YOUR_ANSWER:format(ns.Hex(info.c[1], info.c[2], info.c[3], info.t))
            or L.LC_NO_ANSWER_YET))
        list:SetRows({})
    else
        list:SetRows(rows())
    end
    updateButtons()
end
CouncilWindow.Refresh = refresh

function CouncilWindow.ConfirmAward(i, key, reason)
    local s = Council.session
    if not s or not s.items[i] then return end
    local c = s.cand[i][key]
    local name = Names.Display(c and c.name or key)
    StaticPopupDialogs.LIEBEGRUESSE_AWARD = {
        text = L.LC_CONFIRM_AWARD, button1 = YES or "Yes", button2 = NO or "No",
        OnAccept = function(_, data) Council.Award(data.i, data.key, data.reason) end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    local reasonText = reason and (" (" .. reason .. ")") or ""
    StaticPopup_Show("LIEBEGRUESSE_AWARD", Items.Link(s.items[i].s) or "?", name .. reasonText, { i = i, key = key, reason = reason })
end

local function create()
    frame = UI.Panel(UIParent, "bg", "border")
    if frame.SetClipsChildren then frame:SetClipsChildren(true) end
    frame:SetSize(1000, 500)
    frame.defaultSize = { 1000, 500 }
    UI.Resizable(frame, "council", 760, 380, 1800, 1200, function() if frame:IsShown() then refresh() end end)

    UI.Float(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    -- moved by dragging the window itself (not in "move elements": it would cover the screen)
    UI.RememberPosition(frame, "councilWindow", { "CENTER", "CENTER", 0, 40 })
    tinsert(UISpecialFrames, "LiebeGruesseCouncilWindow")
    _G.LiebeGruesseCouncilWindow = frame

    local crest = frame:CreateTexture(nil, "OVERLAY")
    crest:SetTexture(ns.media .. "icon")
    crest:SetSize(30, 30)
    crest:SetPoint("TOPLEFT", 8, -6)
    frame.titleText = UI.Text(frame, 14, "gold")
    frame.titleText:SetPoint("LEFT", crest, "RIGHT", 8, 0)
    local close = UI.CloseX(frame, nil, 20)

    frame.side = UI.Panel(frame, "panel", "borderDim")
    frame.side:SetPoint("TOPLEFT", 8, -42)
    frame.side:SetPoint("BOTTOMLEFT", 8, 8)
    frame.side:SetWidth(56)
    frame.tabs = {}

    frame.itemIcon = UI.ItemIcon(frame, 40)
    frame.itemIcon:SetPoint("TOPLEFT", frame.side, "TOPRIGHT", 10, 0)
    frame.itemName = UI.Text(frame, 15, "text")
    frame.itemName:SetPoint("TOPLEFT", frame.itemIcon, "TOPRIGHT", 10, -2)
    frame.itemName:SetPoint("TOPRIGHT", -150, -44)
    frame.itemMenu = UI.Button(frame, L.LC_ITEM_MENU, 130, 22, function() itemMenu(state.item) end, "chevron-down")
    frame.itemMenu:SetPoint("TOPRIGHT", -8, -48)
    frame.itemInfo = UI.Text(frame, 11, "muted")
    frame.itemInfo:SetPoint("TOPLEFT", frame.itemName, "BOTTOMLEFT", 0, -5)

    frame.vote = UI.Button(frame, L.LC_VOTE, 130, 24, function()
        local s = Council.session
        if not s or not state.selected then return end
        Council.Vote(state.item, state.selected, not myVote(s, state.item, state.selected))
    end)
    frame.vote:SetPoint("BOTTOMLEFT", frame.side, "BOTTOMRIGHT", 10, 0)
    frame.award = UI.Button(frame, L.LC_AWARD, 130, 24, function()
        if state.selected then CouncilWindow.ConfirmAward(state.item, state.selected, state.reason) end
    end)
    frame.award:SetPoint("LEFT", frame.vote, "RIGHT", 8, 0)
    frame.reason = UI.Dropdown(frame, 150, function()
        local items = { { value = false, text = L.LC_REASON_ANSWER } }
        for _, r in ipairs(Council.Config().reasons or {}) do items[#items + 1] = { value = r, text = r } end
        return items
    end, function() return state.reason or false end, function(v) state.reason = v or nil end)
    frame.reason:SetPoint("LEFT", frame.award, "RIGHT", 8, 0)
    frame.reset = UI.Button(frame, L.LC_RESET_VOTES, 120, 24, function() Council.ResetVotes(state.item) end)
    frame.reset:SetPoint("LEFT", frame.reason, "RIGHT", 8, 0)
    frame.reannounce = UI.Button(frame, L.LC_REANNOUNCE, 120, 24, function() Council.Reannounce() end)
    frame.reannounce:SetPoint("LEFT", frame.reset, "RIGHT", 8, 0)
    frame.more = UI.Button(frame, L.LC_MORE, 90, 24, function(self)
        local s = Council.session
        UI.ContextMenu({
            { text = L.LC_RESET_VOTES, func = function() Council.ResetVotes(state.item) end },
            { text = L.LC_REANNOUNCE, func = function() Council.Reannounce() end, disabled = s and s.test },
        })
    end, "chevron-down")
    frame.more:SetPoint("LEFT", frame.reason, "RIGHT", 8, 0)
    frame.more:Hide()
    frame.recent = UI.Button(frame, "", 220, 24, function() ns.CouncilQueue.AddAll(); refresh() end)
    frame.clear = UI.Button(frame, L.LC_CLEAR_QUEUE, 110, 24, function() ns.CouncilQueue.Clear() end)
    frame.prepToggle = UI.Button(frame, "", 170, 22, function() state.prep = not state.prep; refresh() end)
    frame.prepToggle:SetPoint("RIGHT", close, "LEFT", -8, 0)
    frame.filter = UI.Button(frame, L.LC_FILTER, 80, 22, filterMenu)
    frame.filter:SetPoint("RIGHT", frame.prepToggle, "LEFT", -8, 0)
    frame.finish = UI.Button(frame, L.LC_END_SESSION, 130, 24, function() Council.End() end)
    frame.finish:SetPoint("BOTTOMRIGHT", -8, 8)
    frame.start = UI.Button(frame, "", 200, 24, function()
        Council.Start(Council.pending, false)
    end)
    frame.start:SetPoint("RIGHT", frame.finish, "LEFT", -8, 0)
    frame.recent:SetPoint("RIGHT", frame.start, "LEFT", -8, 0)
    frame.clear:SetPoint("BOTTOMLEFT", frame.side, "BOTTOMRIGHT", 10, 0)

    -- preparation: queue + tradeable bag items, drag & drop target
    local prep = CreateFrame("Frame", nil, frame)
    prep:SetPoint("TOPLEFT", frame.side, "TOPRIGHT", 10, 0)
    prep:SetPoint("BOTTOMRIGHT", -8, 40)
    frame.prep = prep
    prep.hint = UI.Text(prep, 11, "muted")
    prep.hint:SetPoint("TOPLEFT", 2, -2)
    prep.hint:SetPoint("TOPRIGHT", -2, -2)
    prep.hint:SetWordWrap(true)
    prep.hint:SetText(L.LC_PREP_HINT)
    prep.queueTitle = UI.Text(prep, 13, "gold")
    prep.queueTitle:SetPoint("TOPLEFT", 2, -40)
    prep.bagTitle = UI.Text(prep, 13, "gold")
    prep.bagTitle:SetPoint("TOPLEFT", prep, "TOP", 8, -40)
    local function itemName(row)
        local info = Items.Info(row.s)
        return info and info.link or row.s
    end
    prep.queue = UI.List(prep, {
        rowHeight = 26, noHeader = true,
        columns = {
            { key = "name", flex = true, icon = function(r) return Items.Icon(r.s) end, text = itemName },
            { key = "il", width = 50, align = "CENTER",
              text = function(r) local l = Items.Level(r.s); return l and Theme.HexColor("muted", tostring(l)) or "" end },
            { key = "remove", width = 30, align = "CENTER", text = function() return UI.Glyph("x", "bad", 12) end,
              onClick = function(r) ns.CouncilQueue.Remove(r.index) end, tip = function() return L.LC_REMOVE_ITEM end },
        },
        onEnter = function(line, r) Items.ShowTooltip(line, r.s) end,
        onClick = function(r) if IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(Items.Link(r.s) or r.s) end end,
    })
    prep.queue:SetPoint("TOPLEFT", 0, -62)
    prep.queue:SetPoint("BOTTOMRIGHT", prep, "BOTTOM", -8, 0)
    prep.queue:SetEmptyText(L.LC_QUEUE_EMPTY)
    prep.bags = UI.List(prep, {
        rowHeight = 26, noHeader = true,
        columns = {
            { key = "add", width = 30, align = "CENTER",
              text = function(r) return r.queued and UI.Glyph("badge-check", "good", 13) or UI.Glyph("chevron-right", "accent", 13) end,
              onClick = function(r) if not r.queued then ns.CouncilQueue.Add(r.s) end end,
              tip = function(r) return r.queued and L.LC_ALREADY_QUEUED or L.LC_ADD_ITEM end },
            { key = "name", flex = true, icon = function(r) return Items.Icon(r.s) end, text = itemName },
            { key = "why", width = 110, align = "RIGHT",
              text = function(r)
                  local t = L["LC_WHY_" .. r.why] or r.why
                  if r.left and r.left > 0 then t = t .. " " .. L.LC_TIME_LEFT:format(math.ceil(r.left / 60)) end
                  return Theme.HexColor(r.queued and "muted" or "textDim", t)
              end },
        },
        onEnter = function(line, r) Items.ShowTooltip(line, r.s) end,
        onClick = function(r) if not r.queued then ns.CouncilQueue.Add(r.s) end end,
    })
    prep.bags:SetPoint("TOPLEFT", prep, "TOP", 8, -62)
    prep.bags:SetPoint("BOTTOMRIGHT")
    prep.bags:SetEmptyText(L.LC_BAGS_EMPTY)
    local function drop() if ns.CouncilQueue.DropCursor() then refresh() end end
    for _, target in ipairs({ frame, prep, prep.queue.body, prep.bags.body }) do
        target:EnableMouse(true)
        target:SetScript("OnReceiveDrag", drop)
        target:HookScript("OnMouseUp", function() if GetCursorInfo and GetCursorInfo() == "item" then drop() end end)
    end

    list = UI.List(frame, {
        rowHeight = 22, sortKey = "resp",
        columns = {
            { key = "name", title = L.COL_NAME, width = 160, text = function(r)
                  if r.c.removed then return Theme.HexColor("muted", Names.Display(r.c.name or r.key) .. " " .. L.LC_REMOVED_TAG) end
                  return ns.ColorName(r.c.name or r.key, r.c.c) .. (r.c.whisper and Theme.HexColor("muted", " (w)") or "")
                      .. (r.c.changed and Theme.HexColor("muted", " *") or "")
              end,
              sort = function(r) return r.key end },
            { key = "resp", title = L.LC_RESPONSE, width = 110,
              text = function(r) return ns.Hex(r.info.c[1], r.info.c[2], r.info.c[3], r.info.t) end,
              sort = function(r) return r.order * 1000 - r.votes end },
            { key = "il", title = L.COL_ILVL, width = 50, align = "CENTER",
              text = function(r) return r.c.il and ("%.1f"):format(r.c.il) or "–" end, sort = function(r) return r.c.il or 0 end, defaultDesc = true },
            { key = "diff", title = "+iLvl", width = 50, align = "CENTER",
              text = function(r)
                  local s = Council.session
                  local item = s and s.items[state.item]
                  local level = item and Items.Level(item.s)
                  local worst
                  for _, g in ipairs(r.c.g or {}) do
                      local l = Items.Level(g)
                      if l and (not worst or l < worst) then worst = l end
                  end
                  if not level or not worst then return Theme.HexColor("muted", "–") end
                  local d = level - worst
                  return Theme.HexColor(d > 0 and "good" or (d < 0 and "bad" or "muted"), (d > 0 and "+" or "") .. math.floor(d))
              end },
            { key = "roll", title = L.LC_ROLL, width = 46, align = "CENTER",
              text = function(r) return r.c.roll and tostring(r.c.roll) or Theme.HexColor("muted", "–") end,
              sort = function(r) return r.c.roll or 0 end, defaultDesc = true },
            { key = "gear", title = L.LC_EQUIPPED, width = 70,
              text = function(r) return iconText(r.c.g and r.c.g[1], 18) .. " " .. iconText(r.c.g and r.c.g[2], 18) end },
            { key = "note", title = L.LC_NOTE, flex = true,
              text = function(r) return r.c.n and Theme.HexColor("text", r.c.n) or "" end },
            { key = "votes", title = L.LC_VOTES, width = 60, align = "CENTER",
              text = function(r)
                  local s = Council.session
                  local mine = s and myVote(s, state.item, r.key)
                  if r.votes == 0 then return Theme.HexColor("muted", "0") end
                  return Theme.HexColor(mine and "gold" or "text", tostring(r.votes) .. (mine and " *" or ""))
              end,
              sort = function(r) return r.votes end, defaultDesc = true },
            { key = "menu", title = "", width = 28, align = "CENTER",
              text = function() return UI.Glyph("chevron-down", "textDim", 12) end,
              onClick = function(row) state.selected = row.key; list:Draw(); updateButtons(); candidateMenu(row) end,
              tip = function() return L.LC_MENU, { L.LC_RIGHT_CLICK_HINT } end },
        },
        onClick = function(row, button)
            state.selected = row.key
            list:Draw()
            updateButtons()
            if button == "RightButton" then candidateMenu(row) end
        end,
        isSelected = function(row) return row.key == state.selected end,
        onEnter = function(line, row)
            ns.TipOwner(line, "ANCHOR_RIGHT")
            GameTooltip:SetText(ns.ColorName(row.c.name or row.key, row.c.c))
            if row.c.n then GameTooltip:AddLine(L.LC_NOTE .. ": " .. row.c.n, 1, 1, 1, true) end
            for _, g in ipairs(row.c.g or {}) do
                local info = Items.Info(g)
                GameTooltip:AddDoubleLine(iconText(g, 14) .. " " .. (info and info.link or g), Items.Level(g) or "", 1, 1, 1, 0.7, 0.7, 0.7)
            end
            local s = Council.session
            local voters = s and s.votes[state.item] and s.votes[state.item][row.key]
            if voters and next(voters) then
                local names = {}
                for v in pairs(voters) do names[#names + 1] = Names.Display(v) end
                table.sort(names)
                GameTooltip:AddLine(L.LC_VOTED_BY:format(table.concat(names, ", ")), 0.9, 0.76, 0.48, true)
            end
            GameTooltip:AddLine(L.LC_RIGHT_CLICK_HINT, 0.55, 0.55, 0.55, true)
            GameTooltip:Show()
        end,
    })
    frame.outsider = UI.Text(frame, 13, "textDim", "CENTER")
    frame.outsider:SetPoint("CENTER", 30, 0)
    frame.outsider:SetWidth(600)
    frame.outsider:SetWordWrap(true)
    frame.outsider:Hide()
    local answerAgain = UI.Button(frame, L.LC_OPEN_POPUP, 160, 24, function() if ns.CouncilPopup then ns.CouncilPopup.Show() end end)
    answerAgain:SetPoint("TOP", frame.outsider, "BOTTOM", 0, -12)
    frame.outsider:HookScript("OnShow", function() answerAgain:Show() end)
    frame.outsider:HookScript("OnHide", function() answerAgain:Hide() end)
    answerAgain:Hide()
    list:SetPoint("TOPLEFT", frame.itemIcon, "BOTTOMLEFT", 0, -12)
    list:SetPoint("BOTTOMRIGHT", -8, 40)
    list:SetEmptyText(L.LC_NO_ANSWERS)
    frame:HookScript("OnShow", refresh)
end

function CouncilWindow.Show()
    if not frame then create() end
    frame:Show()
    refresh()
end

-- Opens the window on the queue (after Alt-click or drag & drop)
function CouncilWindow.ShowQueue()
    if Council.session and not Council.session.ended then
        if not frame or not frame:IsShown() then return end
    end
    state.prep = true
    CouncilWindow.Show()
end

function CouncilWindow.Toggle()
    if frame and frame:IsShown() then frame:Hide() else CouncilWindow.Show() end
end

ns.On("LG_COUNCIL_START", function(_, s)
    state.item, state.selected, state.prep = 1, nil, false
    if ns.Database.Settings().modules.council == false then return end
    if Council.AmCouncil(s) then CouncilWindow.Show() end
end)
ns.On("LG_COUNCIL", function() ns.Debounce("council-window", 0.2, refresh) end)
ns.On("LG_ITEMS", function() refresh() end)
ns.On("GROUP_ROSTER_UPDATE", function() ns.Debounce("council-window", 0.5, refresh) end)
ns.On("BAG_UPDATE_DELAYED", function()
    if frame and frame:IsShown() and prepVisible() then ns.Debounce("council-bags", 0.5, refresh) end
end)

