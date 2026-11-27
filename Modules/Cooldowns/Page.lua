-- Cooldowns page: displays (style) and spells (placement, rows, columns)
local _, ns = ...
local UI, Theme, L, Names = ns.UI, ns.Theme, ns.L, ns.Names
local Spells, Cooldowns = ns.CooldownSpells, ns.Cooldowns

local function cd() return ns.Database.Settings().cd end
local function Bars() return ns.CooldownBars end
local function relayout() ns.Fire("LG_COOLDOWNS") end

local state = { display = "raid", spell = nil, filter = "all" }
ns.CooldownsPage = {
    Open = function(key)
        state.display = key or state.display
        ns.Window.Show("cooldowns")
        if ns.CooldownsPage.selectTab then ns.CooldownsPage.selectTab("displays") end
    end,
}

local function displayItems(withOff)
    local items = {}
    for _, key in ipairs(Bars().Keys()) do
        local d = Bars().Display(key)
        -- own bars with their own spell selection are not part of the placement
        if not d.pick then items[#items + 1] = { value = key, text = d.name } end
    end
    if withOff then items[#items + 1] = { value = "off", text = L.CD_GROUP_OFF } end
    return items
end

local function className(class)
    if class == "ALL" then return L.CD_ALL_CLASSES end
    return ns.ClassName(class)
end

local function opts(list)
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = { value = e[1], text = e[2] } end
    return out
end

---------------------------------------------------------------------------
-- Displays tab
---------------------------------------------------------------------------
local function buildDisplays(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints()

    local left = CreateFrame("Frame", nil, tab)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(230)
    local head = UI.Text(left, 13, "gold")
    head:SetPoint("TOPLEFT", 2, -6)
    head:SetText(L.CD_DISPLAYS)
    local list = UI.List(left, {
        noHeader = true, rowHeight = 32,
        columns = { { key = "name", title = "", flex = true,
            text = function(r)
                local d = Bars().Display(r.key)
                return Theme.HexColor(d.enabled and "text" or "muted", d.name) .. "\n" ..
                    Theme.HexColor("muted", (d.mode == "icons" and L.CD_MODE_ICONS or L.CD_MODE_BARS) .. (d.enabled and "" or (" · " .. L.CD_GROUP_OFF)))
            end },
            -- switch the display on/off right in the list
            { key = "on", title = "", width = 40, align = "CENTER", text = function() return "" end,
              toggle = { get = function(r) return Bars().Display(r.key).enabled end,
                  set = function(r, v)
                      Bars().Display(r.key).enabled = v
                      Bars().Layout()
                      tab.Refresh()
                  end, tip = L.CD_DISPLAY_ENABLED } } },
        onClick = function(row) state.display = row.key; tab.Refresh() end,
        isSelected = function(row) return row.key == state.display end,
    })
    list:SetPoint("TOPLEFT", 0, -32)
    list:SetPoint("BOTTOMRIGHT", 0, 40)
    local add = UI.Button(left, L.CD_ADD_DISPLAY, 112, 28, function()
        local entries = { { title = L.CD_NEW_BAR_TITLE } }
        for _, t in ipairs(Bars().TEMPLATE_ORDER) do
            entries[#entries + 1] = { text = L["CD_TPL_" .. t], tip = L["CD_TPL_" .. t .. "_TIP"],
                func = function() state.display = Bars().AddDisplay(t); tab.Refresh() end }
        end
        UI.ContextMenu(entries)
    end)
    add:SetPoint("BOTTOMLEFT")
    local remove = UI.Button(left, L.CD_REMOVE_DISPLAY, 110, 28, function()
        if Bars().RemoveDisplay(state.display) then state.display = "raid"; tab.Refresh() else ns.Print(L.CD_CANNOT_REMOVE) end
    end)
    remove:SetPoint("BOTTOMRIGHT")

    local right = CreateFrame("Frame", nil, tab)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 18, 0)
    right:SetPoint("BOTTOMRIGHT")
    local form = UI.Form(right)
    form.scroll:SetPoint("TOPLEFT")
    form.scroll:SetPoint("BOTTOMRIGHT", -8, 0)

    local function sel() return Bars().Display(state.display) end
    local function get(field) return function() return sel()[field] end end
    local function set(field) return function(v) sel()[field] = v; relayout() end end
    local function isBars() return sel().mode ~= "icons" end
    local function isIcons() return sel().mode == "icons" end
    local function color(field) return function() local c = sel()[field]; return c[1], c[2], c[3], c[4] end end
    local function setColor(field) return function(r, g, b, a) sel()[field] = { r, g, b, a or 1 }; relayout() end end
    local pct = function(v) return ("%d%%"):format(v * 100 + 0.5) end

    local tracker = form:Section(L.CD_TRACKER)
    tracker:Toggle(L.CD_ENABLED, function() return cd().enabled end, function(v) cd().enabled = v; relayout() end)
    tracker:Toggle(L.CD_SHOW_SOLO, function() return cd().showSolo end, function(v) cd().showSolo = v; relayout() end)
    tracker:Toggle(L.CD_OBSERVE, function() return cd().observe ~= false end, function(v) cd().observe = v end, { tip = L.CD_OBSERVE_TIP })
    tracker:Toggle(L.CD_LOCKED, function() return cd().locked end, function(v) cd().locked = v; relayout() end,
        { col = 2, tip = L.CD_LOCKED_TIP })

    local actions = function() return opts({ { "whisper", L.CD_ACTION_WHISPER }, { "call", L.CD_ACTION_CALL }, { "none", L.CD_ACTION_NONE } }) end
    local click = form:Section(L.CD_CLICK_ACTIONS)
    click:Dropdown(L.CD_KEY_LEFT, actions, function() return cd().clickLeft end, function(v) cd().clickLeft = v end)
    click:Dropdown(L.CD_KEY_SHIFT, actions, function() return cd().clickShift end, function(v) cd().clickShift = v end)
    click:Dropdown(L.CD_KEY_RIGHT, actions, function() return cd().clickRight end, function(v) cd().clickRight = v end)
    click:Toggle(L.CD_ONLY_READY, function() return cd().onlyReady end, function(v) cd().onlyReady = v end, { tip = L.CD_ONLY_READY_TIP })
    click:Edit(L.CD_WHISPER_TEXT, function() return cd().whisperText or L.CD_WHISPER_DEFAULT end,
        function(v) cd().whisperText = (v ~= "" and v ~= L.CD_WHISPER_DEFAULT) and v or nil end, { col = 2, width = 230, tip = L.CD_TOKENS })
    click:Edit(L.CD_CALL_TEXT, function() return cd().callText or L.CD_CALL_DEFAULT end,
        function(v) cd().callText = (v ~= "" and v ~= L.CD_CALL_DEFAULT) and v or nil end, { col = 2, width = 230, tip = L.CD_TOKENS })
    click:Note(L.CD_TOKENS, { col = 2 })

    -- own bars: own spell selection and player filters
    local function isCustom() return not Bars().IsBuiltin(state.display) end
    local function isPick() return isCustom() and sel().pick == true end
    local own = form:Section(L.CD_OWN_BAR)
    own:Note(L.CD_OWN_BAR_HINT, { col = 0, height = 30, show = isCustom })
    own:Toggle(L.CD_PICK, function() return sel().pick == true end, function(v)
        sel().pick = v; sel().picks = sel().picks or {}; relayout(); tab.Refresh()
    end, { tip = L.CD_PICK_TIP, show = isCustom })
    own:Toggle(L.CD_ONLY_ME, get("onlyMe"), set("onlyMe"), { col = 2, show = isCustom, tip = L.CD_ONLY_ME_TIP })
    own:Toggle(L.CD_MY_GROUP, get("mySubgroup"), set("mySubgroup"), { show = isCustom, tip = L.CD_MY_GROUP_TIP })
    own:Edit(L.CD_PLAYERS, function() return sel().players or "" end, function(v) sel().players = v; relayout() end,
        { col = 2, width = 230, placeholder = L.CD_PLAYERS_PH, show = isCustom, tip = L.CD_PLAYERS_TIP })

    -- spell checklist (search + list)
    local pickFrame = CreateFrame("Frame", nil, form.body)
    local pickSearch = UI.EditBox(pickFrame, 220, 24, L.CD_PICK_SEARCH)
    pickSearch:SetPoint("TOPLEFT")
    local pickCount = UI.Text(pickFrame, 11, "muted")
    pickCount:SetPoint("LEFT", pickSearch, "RIGHT", 10, 0)
    local pickQuery = ""
    local pickList = UI.List(pickFrame, {
        noHeader = true, rowHeight = 22,
        columns = {
            { key = "on", width = 28, align = "CENTER",
              text = function(r)
                  local on = sel().picks and sel().picks[r.spell.id]
                  return UI.Glyph(on and "badge-check" or "ring", on and "accent" or "borderDim", 13)
              end },
            { key = "name", flex = true, icon = function(r) return Spells.Icon and Spells.Icon(r.spell) or nil end,
              text = function(r)
                  local on = sel().picks and sel().picks[r.spell.id]
                  return Theme.HexColor(on and "text" or "textDim", Spells.Name(r.spell))
              end },
            { key = "class", width = 110, text = function(r)
                  if r.spell.class == "ALL" then return Theme.HexColor("muted", className("ALL")) end
                  return "|c" .. ns.ClassHex(r.spell.class) .. className(r.spell.class) .. "|r"
              end },
        },
        onClick = function(r)
            local on = not (sel().picks and sel().picks[r.spell.id])
            Bars().TogglePick(state.display, r.spell.id, on)
            tab.RefreshPicks()
        end,
    })
    pickList:SetPoint("TOPLEFT", 0, -32)
    pickList:SetPoint("BOTTOMRIGHT")
    pickSearch.onChange = function(_, text) pickQuery = (text or ""):lower(); tab.RefreshPicks() end
    own:Custom(pickFrame, 300, { col = 0, show = isPick })
    function tab.RefreshPicks()
        if not isPick() then return end
        local rows, n = {}, 0
        for _, spell in ipairs(Spells.list) do
            local name = Spells.Name(spell) or ""
            if sel().picks and sel().picks[spell.id] then n = n + 1 end
            if pickQuery == "" or name:lower():find(pickQuery, 1, true) or className(spell.class):lower():find(pickQuery, 1, true) then
                rows[#rows + 1] = { key = spell.id, spell = spell }
            end
        end
        table.sort(rows, function(a, b)
            local pa = sel().picks and sel().picks[a.spell.id] and 0 or 1
            local pb = sel().picks and sel().picks[b.spell.id] and 0 or 1
            if pa ~= pb then return pa < pb end
            if a.spell.class ~= b.spell.class then return a.spell.class < b.spell.class end
            return (Spells.Name(a.spell) or "") < (Spells.Name(b.spell) or "")
        end)
        pickList:SetRows(rows)
        pickCount:SetText(L.CD_PICK_COUNT:format(n))
    end

    local cond = form:Section(L.CD_CONDITIONS)
    cond:Note(L.CD_CONDITIONS_HINT, { col = 0, height = 30 })
    local function free() return not sel().attach end
    cond:Note(L.CD_ATTACH_PARTY_ONLY, { col = 0, height = 30, show = function() return sel().attach end })
    cond:Toggle(L.CD_WHEN_SOLO, get("whenSolo"), set("whenSolo"), { show = free })
    cond:Toggle(L.CD_WHEN_PARTY, get("whenParty"), set("whenParty"), { show = free })
    cond:Toggle(L.CD_WHEN_RAID, get("whenRaid"), set("whenRaid"), { show = free })
    cond:Dropdown(L.CD_WHERE, function() return opts({ { "any", L.CD_WHERE_ANY }, { "instance", L.CD_WHERE_INSTANCE },
        { "dungeon", L.CD_WHERE_DUNGEON }, { "raid", L.CD_WHERE_RAID }, { "world", L.CD_WHERE_WORLD } }) end,
        get("where"), set("where"), { col = 2 })
    cond:Segment(L.CD_COMBAT_COND, opts({ { "any", L.CD_COMBAT_ANY }, { "combat", L.CD_COMBAT_IN }, { "nocombat", L.CD_COMBAT_OUT } }),
        get("combat"), set("combat"), { col = 2, width = 240 })

    local layout = form:Section(L.CD_STYLE_LAYOUT)
    layout:Edit(L.CD_DISPLAY_NAME, get("name"), function(v) if v ~= "" then sel().name = v; relayout(); list:Draw() end end)
    layout:Toggle(L.CD_DISPLAY_ENABLED, get("enabled"), function(v) sel().enabled = v; relayout(); list:Draw() end)
    layout:Segment(L.CD_MODE, opts({ { "bars", L.CD_MODE_BARS }, { "icons", L.CD_MODE_ICONS } }), get("mode"),
        function(v) sel().mode = v; relayout(); list:Draw() end, { width = 180 })
    layout:Segment(L.CD_GROW, opts({ { "DOWN", L.CD_GROW_DOWN }, { "UP", L.CD_GROW_UP } }), get("grow"), set("grow"), { width = 180 })
    layout:Dropdown(L.CD_SORT, function() return opts({ { "name", L.CD_SORT_NAME }, { "ready", L.CD_SORT_READY }, { "remaining", L.CD_SORT_REMAINING } }) end,
        get("sort"), set("sort"))
    layout:Toggle(L.CD_COLLAPSE, get("collapse"), set("collapse"), { tip = L.CD_COLLAPSE_TIP })
    layout:Toggle(L.CD_HIDE_READY, get("hideReady"), set("hideReady"))
    layout:Toggle(L.CD_EXCLUDE_SELF, get("excludeSelf"), set("excludeSelf"))
    layout:Toggle(L.CD_NAME_ABOVE, get("nameAbove"), set("nameAbove"), { tip = L.CD_NAME_ABOVE_TIP })
    layout:Slider(L.CD_PICK_COLUMNS, 0, 8, 1, function() return sel().pickColumns or (sel().pick and 1 or 0) end, set("pickColumns"),
        { col = 2, tip = L.CD_PICK_COLUMNS_TIP, fmt = function(v) return v == 0 and L.CD_COLUMNS_MANUAL or tostring(v) end })
    layout:Slider(L.CD_SCALE, 0.5, 2, 0.05, get("scale"), set("scale"), { col = 2, fmt = pct })
    layout:Slider(L.CD_BAR_WIDTH, 40, 400, 1, get("width"), set("width"), { col = 2, show = isBars })
    layout:Slider(L.CD_BAR_HEIGHT, 8, 48, 1, get("height"), set("height"), { col = 2, show = isBars })
    layout:Slider(L.CD_ICON_WIDTH, 12, 80, 1, get("iconWidth"), set("iconWidth"), { col = 2, show = isIcons })
    layout:Slider(L.CD_ICON_HEIGHT, 12, 80, 1, get("iconHeight"), set("iconHeight"), { col = 2, show = isIcons })
    layout:Segment(L.CD_ICON_BORDER, opts({ { "none", L.CD_BORDER_NONE }, { "black", L.CD_BORDER_BLACK }, { "class", L.CD_BORDER_CLASS } }),
        get("iconBorder"), set("iconBorder"), { width = 240, show = isIcons })
    layout:Slider(L.CD_ICONS_PER_ROW, 1, 12, 1, get("iconsPerRow"), set("iconsPerRow"), { col = 2, show = isIcons })
    -- hang the icons at the group's unit frames 
    local function isAttached() return isIcons() and sel().attach == true end
    layout:Toggle(L.CD_ATTACH, get("attach"), set("attach"), { show = isIcons, tip = L.CD_ATTACH_TIP })
    layout:Segment(L.CD_ATTACH_SIDE, opts({ { "LEFT", L.CD_SIDE_LEFT }, { "RIGHT", L.CD_SIDE_RIGHT }, { "TOP", L.CD_SIDE_TOP }, { "BOTTOM", L.CD_SIDE_BOTTOM } }),
        get("attachSide"), set("attachSide"), { width = 240, show = isAttached })
    layout:Segment(L.CD_ATTACH_ALIGN, opts({ { "TOP", L.CD_ALIGN_START }, { "CENTER", L.CD_ALIGN_CENTER }, { "BOTTOM", L.CD_ALIGN_END } }),
        get("attachAlign"), set("attachAlign"), { width = 240, show = isAttached, tip = L.CD_ATTACH_ALIGN_TIP })
    layout:Slider(L.CD_ATTACH_GAP, -20, 60, 1, get("attachX"), set("attachX"), { col = 2, show = isAttached })
    layout:Slider(L.CD_ATTACH_SHIFT, -60, 60, 1, get("attachY"), set("attachY"), { col = 2, show = isAttached })
    layout:Edit(L.CD_FRAME_HINT, function() return cd().frameHint or "" end,
        function(v) cd().frameHint = v; ns.CooldownBars.RescanFrames(); relayout() end,
        { show = isAttached, placeholder = L.CD_FRAME_HINT_PH, tip = L.CD_FRAME_HINT_TIP })
    layout:Buttons({ { L.CD_FRAME_CHECK, function()
        local found = ns.CooldownBars.FoundFrames()
        if #found == 0 then ns.Print(L.CD_FRAME_NONE) end
        for _, e in ipairs(found) do
            ns.Print(("%s → %s"):format(e.name or "?", e.frame or Theme.HexColor("bad", L.CD_FRAME_MISSING)))
        end
    end } }, { show = isAttached })
    layout:Slider(L.CD_SPACING, 0, 20, 1, get("spacing"), set("spacing"), { col = 2 })
    layout:Slider(L.CD_COL_SPACING, 0, 60, 1, get("colSpacing"), set("colSpacing"), { col = 2 })

    local text = form:Section(L.CD_STYLE_TEXT)
    text:Dropdown(L.FONT, function() return Theme.Fonts() end, get("font"), set("font"))
    text:Slider(L.FONT_SIZE, 6, 24, 1, get("fontSize"), set("fontSize"))
    text:Dropdown(L.CD_OUTLINE, function() return opts({ { "NONE", L.CD_OUTLINE_NONE }, { "OUTLINE", L.CD_OUTLINE_THIN }, { "THICKOUTLINE", L.CD_OUTLINE_THICK } }) end,
        get("outline"), set("outline"))
    text:Dropdown(L.CD_TEXT, function() return opts({ { "name", L.CD_TEXT_NAME }, { "fullname", L.CD_TEXT_FULLNAME },
        { "name_spell", L.CD_TEXT_NAME_SPELL }, { "spell_name", L.CD_TEXT_SPELL_NAME }, { "spell", L.CD_TEXT_SPELL }, { "none", L.CD_TEXT_NONE } }) end,
        get("textFormat"), set("textFormat"), { col = 2, show = isBars })
    text:Toggle(L.CD_SHOW_TIME, get("showTime"), set("showTime"), { col = 2 })
    text:Toggle(L.CD_SHOW_NAMES, get("showNames"), set("showNames"), { col = 2, show = isIcons })
    text:Toggle(L.CD_HIDE_READY_TIME, get("hideReadyTime"), set("hideReadyTime"), { col = 2, show = isBars, tip = L.CD_HIDE_READY_TIME_TIP })
    text:Edit(L.CD_READY_TEXT_SHORT, get("readyText"), set("readyText"), { col = 2, placeholder = L.CD_READY,
        show = function() return isBars() and not sel().hideReadyTime end })
    text:Slider(L.CD_LABEL_OFFSET, 0, 20, 1, get("labelOffset"), set("labelOffset"), { show = isBars })

    local look = form:Section(L.CD_STYLE_LOOK)
    look:Dropdown(L.CD_TEXTURE, function() return Theme.Textures() end, get("texture"), set("texture"), { show = isBars })
    look:Toggle(L.CD_SHOW_ICON, get("showIcon"), set("showIcon"), { show = isBars })
    look:Segment(L.CD_ICON_SIDE, opts({ { "LEFT", L.LEFT_SIDE }, { "RIGHT", L.RIGHT_SIDE } }), get("iconSide"), set("iconSide"),
        { width = 160, show = isBars })
    look:Slider(L.CD_ICON_ZOOM, 0, 0.9, 0.05, get("iconZoom"), set("iconZoom"), { fmt = pct, show = isBars })
    look:Toggle(L.CD_BORDER, get("border"), set("border"))
    look:Segment(L.CD_FILL, opts({ { "drain", L.CD_FILL_DRAIN }, { "fill", L.CD_FILL_FILL } }), get("fill"), set("fill"),
        { width = 180, show = isBars })
    look:Toggle(L.CD_REVERSE, get("reverse"), set("reverse"), { show = isBars, tip = L.CD_REVERSE_TIP })
    look:Toggle(L.CD_FADE_READY, get("fadeReady"), set("fadeReady"), { tip = L.CD_FADE_READY_TIP })
    look:Slider(L.CD_FADE_ALPHA, 0, 1, 0.05, get("fadeAlpha"), set("fadeAlpha"), { fmt = pct, show = function() return sel().fadeReady end })
    look:Dropdown(L.CD_COLOR_MODE, function() return opts({ { "wa", L.CD_COLOR_WA }, { "class", L.CD_COLOR_CLASS }, { "custom", L.CD_COLOR_CUSTOM } }) end,
        get("colorMode"), set("colorMode"), { col = 2 })
    look:Color(L.CD_BAR_COLOR, color("barColor"), setColor("barColor"), { col = 2, alpha = true, show = function() return sel().colorMode == "custom" end })
    look:Dropdown(L.CD_CD_COLOR_MODE, function() return opts({ { "same", L.CD_CD_SAME }, { "dim", L.CD_CD_DIM }, { "grey", L.CD_CD_GREY }, { "custom", L.CD_COLOR_CUSTOM } }) end,
        get("cdColorMode"), set("cdColorMode"), { col = 2, show = isBars })
    look:Color(L.CD_CD_COLOR, color("cdColor"), setColor("cdColor"), { col = 2, alpha = true,
        show = function() return isBars() and sel().cdColorMode == "custom" end })
    look:Color(L.CD_BG_COLOR, color("bgColor"), setColor("bgColor"), { col = 2, alpha = true, show = isBars })
    look:Segment(L.CD_TEXT_COLOR_MODE, opts({ { "white", L.CD_TEXT_WHITE }, { "class", L.CD_COLOR_CLASS } }), get("textColorMode"),
        set("textColorMode"), { col = 2, width = 180, show = isBars })
    look:Color(L.CD_TEXT_COLOR, color("textColor"), setColor("textColor"), { col = 2 })
    look:Color(L.CD_READY_COLOR, color("readyColor"), setColor("readyColor"), { col = 2, show = isBars })

    local reset = form:Section(L.CD_RESET)
    reset:Buttons({
        { L.CD_RESET_POSITION, function() Bars().ResetPosition(state.display) end, width = 190, icon = "move" },
        { L.CD_RESET_STYLE, function() Bars().ResetDisplay(state.display); tab.Refresh() end, width = 190, icon = "rotate-ccw" },
        { L.CD_WA_LOOK, function() Bars().ApplyWALook(state.display); relayout(); tab.Refresh() end, width = 190, icon = "palette" },
    })

    function tab.Refresh()
        local rows = {}
        for _, key in ipairs(Bars().Keys()) do rows[#rows + 1] = { key = key } end
        list:SetRows(rows)
        if tab.RefreshPicks then tab.RefreshPicks() end
        layout.head.text:SetText(ns.Upper(L.CD_STYLE_LAYOUT) .. "  " .. Theme.HexColor("muted", "· " .. sel().name))
        form:Refresh()
    end
    tab.form = form
    return tab
end

---------------------------------------------------------------------------
-- Spells tab
---------------------------------------------------------------------------
local function buildSpells(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints()

    local idBox = UI.EditBox(tab, 120, 26, L.CD_SPELL_ID)
    idBox:SetPoint("TOPLEFT")
    local addBtn = UI.Button(tab, L.CD_ADD_SPELL, 190, 26, function()
        local ok, why = Spells.AddCustom(idBox:GetText())
        if ok then
            state.spell = tonumber(idBox:GetText())
            idBox:SetText("")
            tab.Refresh()
        else
            ns.Print(why == "exists" and L.CD_SPELL_EXISTS or L.CD_SPELL_UNKNOWN)
        end
    end, "sparkles")
    addBtn:SetPoint("LEFT", idBox, "RIGHT", 8, 0)
    addBtn.tip = { L.CD_ADD_SPELL_TIP }
    idBox.onEnter = function() addBtn:Click() end

    local filter = UI.Dropdown(tab, 190, function()
        local list = { { value = "all", text = L.CD_ALL_SPELLS } }
        for _, item in ipairs(displayItems(true)) do list[#list + 1] = item end
        return list
    end, function() return state.filter end, function(v) state.filter = v; tab.Refresh() end)
    filter:SetPoint("LEFT", addBtn, "RIGHT", 14, 0)

    local editor = CreateFrame("Frame", nil, tab)
    editor:SetPoint("TOPRIGHT", 0, -38)
    editor:SetPoint("BOTTOMRIGHT")
    editor:SetWidth(380)

    local list = UI.List(tab, {
        rowHeight = 26, sortKey = "place",
        columns = {
            { key = "name", title = L.CD_SPELL, flex = true, text = function(r) return Spells.Name(r.spell) end,
              icon = function(r) return Spells.Icon(r.spell) end },
            { key = "class", title = L.CD_CLASS, width = 90,
              text = function(r) return r.spell.class == "ALL" and className("ALL") or ("|c%s%s|r"):format(ns.ClassHex(r.spell.class), className(r.spell.class)) end },
            { key = "place", title = L.CD_PLACE, width = 150,
              text = function(r)
                  if r.cfg.display == "off" or not r.cfg.enabled then return Theme.HexColor("muted", L.CD_GROUP_OFF) end
                  local d = Bars().Display(r.cfg.display)
                  return ("%s  %s"):format(d and d.name or r.cfg.display, Theme.HexColor("muted", L.CD_COL_ROW:format(r.cfg.col, r.cfg.row)))
              end,
              sort = function(r)
                  local d = (r.cfg.display ~= "off" and r.cfg.enabled) and Bars().Display(r.cfg.display)
                  return ("%02d%02d%02d%04d"):format(d and (d.order or 50) or 99, r.cfg.col, r.cfg.row, r.spell.order)
              end },
            { key = "cd", title = L.CD_COOLDOWN, width = 60, align = "CENTER", text = function(r) return ns.Duration(r.cfg.cd) end,
              sort = function(r) return r.cfg.cd end },
        },
        onClick = function(row) state.spell = row.spell.id; tab.Refresh() end,
        isSelected = function(row) return row.spell.id == state.spell end,
    })
    list:SetPoint("TOPLEFT", 0, -38)
    list:SetPoint("BOTTOMRIGHT", editor, "BOTTOMLEFT", -16, 0)

    local function current() return state.spell and Spells.byId[state.spell] end
    local function get(field) return function() local s = current(); return s and Spells.Config(s)[field] end end
    local function set(field) return function(v) local s = current(); if s then Spells.Set(s, field, v); list:SetRows(list.rows) end end end

    local cardHead = CreateFrame("Frame", nil, editor)
    cardHead:SetPoint("TOPLEFT")
    cardHead:SetPoint("TOPRIGHT")
    cardHead:SetHeight(52)
    local hbg = UI.Fill(cardHead, "panel")
    hbg:SetAllPoints()
    local hbar = UI.Fill(cardHead, "accent", "ARTWORK")
    hbar:SetPoint("TOPLEFT"); hbar:SetPoint("BOTTOMLEFT"); hbar:SetWidth(2)
    local icon = cardHead:CreateTexture(nil, "ARTWORK")
    icon:SetSize(34, 34)
    icon:SetPoint("LEFT", 12, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local title = UI.Text(cardHead, 14, "text")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    title:SetPoint("TOPRIGHT", -10, -9)
    local sub = UI.Text(cardHead, 11, "muted")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    local formHolder = CreateFrame("Frame", nil, editor)
    formHolder:SetPoint("TOPLEFT", 0, -62)
    formHolder:SetPoint("BOTTOMRIGHT")
    local form = UI.Form(formHolder)
    form.noIndex = true
    form.scroll:SetPoint("TOPLEFT")
    form.scroll:SetPoint("BOTTOMRIGHT", -8, 0)
    local place = form:Section(L.CD_PLACEMENT)
    place:Toggle(L.CD_SPELL_ENABLED, get("enabled"), set("enabled"), { col = 0 })
    place:Dropdown(L.CD_DISPLAY, function() return displayItems(true) end, get("display"), set("display"), { col = 0 })
    place:Slider(L.CD_COLUMN, 1, 12, 1, get("col"), set("col"), { col = 0 })
    place:Slider(L.CD_ROW, 1, 30, 1, get("row"), set("row"), { col = 0 })
    place:Edit(L.CD_COOLDOWN_SHORT, function() return tostring(get("cd")() or "") end, function(v)
        local s, n = current(), tonumber(v)
        if s and n and n > 0 then Spells.Set(s, "cd", n ~= s.cd and n or nil) end
    end, { col = 0, tip = L.CD_COOLDOWN_SECONDS, width = 120 })
    local look = form:Section(L.CD_SPELL_LOOK)
    look:Edit(L.CD_SPELL_LABEL, get("label"), function(v) set("label")(v ~= "" and v or nil) end,
        { col = 0, placeholder = L.CD_SPELL_LABEL_PH, tip = L.CD_SPELL_LABEL_TIP })
    look:Toggle(L.CD_SPELL_OWN_COLOR, function() return get("color")() ~= nil end, function(v)
        set("color")(v and { 1, 0.56, 0.2, 1 } or nil)
    end, { col = 0 })
    look:Color(L.CD_SPELL_COLOR, function() local c = get("color")() or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end,
        function(r, g, b, a) set("color")({ r, g, b, a or 1 }) end, { col = 0, alpha = true, show = function() return get("color")() ~= nil end })
    local who = form:Section(L.CD_WHO)
    who:Toggle(L.ROLE_TANK, get("tank"), set("tank"), { col = 0 })
    who:Toggle(L.ROLE_HEALER, get("healer"), set("healer"), { col = 0 })
    who:Toggle(L.ROLE_DAMAGE, get("damage"), set("damage"), { col = 0 })
    who:Edit(L.CD_PLAYER_FILTER_SHORT, get("filter"), function(v) set("filter")(v ~= "" and v or nil) end,
        { col = 0, placeholder = L.LC_NAMES_PLACEHOLDER, tip = L.CD_PLAYER_FILTER })
    local actions = form:Section(L.CD_ACTIONS)
    actions:Buttons({
        { L.CD_RESET_SPELL, function() local s = current(); if s then Spells.Reset(s); tab.Refresh() end end, width = 150, icon = "rotate-ccw" },
        { L.CD_DELETE_SPELL, function()
            local s = current()
            if s and s.custom then Spells.RemoveCustom(s.id); state.spell = nil; tab.Refresh() end
        end, width = 150, icon = "x" },
    })
    local empty = UI.Text(editor, 12, "muted", "CENTER")
    empty:SetPoint("CENTER")
    empty:SetText(L.CD_PICK_SPELL)

    function tab.Refresh()
        local rows = {}
        for _, spell in ipairs(Spells.list) do
            local cfg = Spells.Config(spell)
            local shown = state.filter == "all" or (state.filter == "off" and (cfg.display == "off" or not cfg.enabled))
                or (cfg.display == state.filter and cfg.enabled)
            if shown then rows[#rows + 1] = { key = spell.id, spell = spell, cfg = cfg } end
        end
        list:SetRows(rows)
        tab.list = list
        filter:Refresh()
        local s = current()
        cardHead:SetShown(s ~= nil)
        formHolder:SetShown(s ~= nil)
        empty:SetShown(s == nil)
        if not s then return end
        icon:SetTexture(Spells.Icon(s))
        title:SetText(Spells.Name(s))
        sub:SetText(("ID %d · %s%s"):format(s.id, className(s.class), s.custom and ("  " .. L.CD_CUSTOM) or ""))
        form:Refresh()
    end
    -- rows hold a config snapshot; rebuild it after edits
    local setRows = list.SetRows
    function list:SetRows(rows)
        for _, r in ipairs(rows or {}) do r.cfg = Spells.Config(r.spell) end
        setRows(self, rows)
    end
    return tab
end


---------------------------------------------------------------------------
-- Layout board: which spells a display shows, in which column and row
---------------------------------------------------------------------------
local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "ALL" }

local function buildBoard(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints()
    local CARD_H, GAP, POOL_W = 30, 4, 270
    local selected -- spell id
    local poolFilter = { search = "", class = "all", cat = "all" }

    ---------------------------------------------------------------------
    -- data helpers
    ---------------------------------------------------------------------
    local function spellsIn(key)
        local cols = {}
        for _, spell in ipairs(Spells.list) do
            local cfg = Spells.Config(spell)
            if cfg.display == key then
                cols[cfg.col] = cols[cfg.col] or {}
                table.insert(cols[cfg.col], { spell = spell, cfg = cfg })
            end
        end
        for _, list in pairs(cols) do
            table.sort(list, function(a, b)
                if a.cfg.row ~= b.cfg.row then return a.cfg.row < b.cfg.row end
                return a.spell.order < b.spell.order
            end)
        end
        return cols
    end

    local function override(id)
        local all = ns.Database.Settings().cd.spells
        all[id] = all[id] or {}
        return all[id]
    end

    local function renumber(list)
        for k, e in ipairs(list) do override(e.spell.id).row = k end
    end

    -- puts a spell into column `col` at position `index` of the current display
    local function insert(spell, col, index)
        local cols = spellsIn(state.display)
        for c, list in pairs(cols) do
            for k = #list, 1, -1 do
                if list[k].spell == spell then
                    table.remove(list, k)
                    if c == col and k < index then index = index - 1 end
                end
            end
        end
        cols[col] = cols[col] or {}
        index = math.max(1, math.min(#cols[col] + 1, index or (#cols[col] + 1)))
        table.insert(cols[col], index, { spell = spell, cfg = Spells.Config(spell) })
        local o = override(spell.id)
        o.display, o.col = state.display, col
        if o.enabled == false then o.enabled = nil end
        for _, list in pairs(cols) do renumber(list) end
        selected = spell.id
        relayout()
        tab.Refresh()
    end

    local function removeSpell(spell)
        local o = override(spell.id)
        o.display = "off"
        local cols = spellsIn(state.display)
        for _, list in pairs(cols) do renumber(list) end
        relayout()
        tab.Refresh()
    end

    local function move(dCol, dRow)
        local spell = selected and Spells.byId[selected]
        if not spell then return end
        local cfg = Spells.Config(spell)
        if cfg.display ~= state.display then return end
        local list = spellsIn(state.display)[cfg.col] or {}
        local index
        for k, e in ipairs(list) do if e.spell == spell then index = k end end
        if not index then return end
        if dRow ~= 0 then
            insert(spell, cfg.col, index + dRow + (dRow > 0 and 1 or 0))
        else
            local target = math.max(1, math.min(12, cfg.col + dCol))
            if target ~= cfg.col then insert(spell, target, nil) end
        end
    end

    ---------------------------------------------------------------------
    -- top bar
    ---------------------------------------------------------------------
    local pick = UI.Dropdown(tab, 200, function() return displayItems(false) end, function() return state.display end,
        function(v) state.display = v; selected = nil; tab.Refresh() end)
    pick:SetPoint("TOPLEFT")
    local actions = UI.Toolbar(tab, {
        { text = "", width = 30, icon = "chevron-down", onClick = function() move(0, -1) end, tip = L.CD_MOVE_UP },
        { text = "", width = 30, icon = "chevron-down", onClick = function() move(0, 1) end, tip = L.CD_MOVE_DOWN },
        { text = "", width = 30, icon = "chevron-right", onClick = function() move(-1, 0) end, tip = L.CD_MOVE_LEFT },
        { text = "", width = 30, icon = "chevron-right", onClick = function() move(1, 0) end, tip = L.CD_MOVE_RIGHT },
        { text = L.CD_SHOW_HIDE, width = 130, onClick = function()
            local spell = selected and Spells.byId[selected]
            if spell then Spells.Set(spell, "enabled", not Spells.Config(spell).enabled); tab.Refresh() end
        end },
        { text = L.CD_REMOVE_FROM, width = 110, icon = "x", onClick = function()
            local spell = selected and Spells.byId[selected]
            if spell then removeSpell(spell) end
        end },
        { text = L.CD_ADD_COLUMN, width = 130, onClick = function()
            local d = Bars().Display(state.display)
            d.boardCols = math.min(12, (d.boardCols or 1) + 1)
            tab.Refresh()
        end, tip = L.CD_ADD_COLUMN_TIP },
    })
    actions:SetPoint("LEFT", pick, "RIGHT", 12, 0)
    actions.buttons[1].icon:SetTexCoord(0, 1, 1, 0)
    actions.buttons[3].icon:SetTexCoord(1, 0, 0, 1)
    local hint = UI.Text(tab, 11, "muted")
    hint:SetPoint("TOPLEFT", 0, -34)
    hint:SetText(L.CD_BOARD_HINT)

    ---------------------------------------------------------------------
    -- columns (left) and spell pool with filters (right)
    ---------------------------------------------------------------------
    local poolPanel = UI.Panel(tab, "rowAlt", "borderDim")
    poolPanel:SetPoint("TOPRIGHT", 0, -56)
    poolPanel:SetPoint("BOTTOMRIGHT")
    poolPanel:SetWidth(POOL_W)
    local poolTitle = UI.Text(poolPanel, 12, "gold")
    poolTitle:SetPoint("TOPLEFT", 10, -10)
    local poolSearch = UI.EditBox(poolPanel, POOL_W - 20, 24, L.CD_SEARCH_SPELL)
    poolSearch:SetPoint("TOPLEFT", 10, -32)
    poolSearch.onChange = function(_, text) poolFilter.search = (text or ""):lower(); tab.Refresh() end
    function tab.SetSearch(text) if poolSearch:GetText() ~= (text or "") then poolSearch:SetText(text or "") end end
    local classDrop = UI.Dropdown(poolPanel, (POOL_W - 26) / 2, function()
        local items = { { value = "all", text = L.CD_ALL_CLASSES } }
        for _, c in ipairs(CLASS_ORDER) do
            items[#items + 1] = { value = c, text = c == "ALL" and L.CD_ANY_CLASS or ("|c%s%s|r"):format(ns.ClassHex(c), className(c)) }
        end
        return items
    end, function() return poolFilter.class end, function(v) poolFilter.class = v; tab.Refresh() end)
    classDrop:SetPoint("TOPLEFT", poolSearch, "BOTTOMLEFT", 0, -6)
    local catDrop = UI.Dropdown(poolPanel, (POOL_W - 26) / 2, function()
        local items = { { value = "all", text = L.CD_ALL_CATEGORIES } }
        for _, c in ipairs(Spells.CATEGORIES) do items[#items + 1] = { value = c, text = L["CD_CAT_" .. c] } end
        items[#items + 1] = { value = "custom", text = L.CD_CUSTOM }
        return items
    end, function() return poolFilter.cat end, function(v) poolFilter.cat = v; tab.Refresh() end)
    catDrop:SetPoint("LEFT", classDrop, "RIGHT", 6, 0)
    local onlyFree = UI.Check(poolPanel, L.CD_ONLY_UNUSED, function() return poolFilter.unused end,
        function(v) poolFilter.unused = v; tab.Refresh() end, L.CD_ONLY_UNUSED_TIP)
    onlyFree:SetPoint("TOPLEFT", classDrop, "BOTTOMLEFT", 0, -8)
    local poolArea = CreateFrame("Frame", nil, poolPanel)
    poolArea:SetPoint("TOPLEFT", 8, -122)
    poolArea:SetPoint("BOTTOMRIGHT", -14, 8)
    local poolScroll, poolBody = UI.ScrollArea(poolArea)
    poolScroll:SetPoint("TOPLEFT")
    poolScroll:SetPoint("BOTTOMRIGHT")

    local colArea = CreateFrame("Frame", nil, tab)
    colArea:SetPoint("TOPLEFT", 0, -56)
    colArea:SetPoint("BOTTOMRIGHT", poolPanel, "BOTTOMLEFT", -14, 0)
    local colScroll, colBody = UI.ScrollArea(colArea)
    colScroll:SetPoint("TOPLEFT")
    colScroll:SetPoint("BOTTOMRIGHT", -8, 0)

    ---------------------------------------------------------------------
    -- drag & drop
    ---------------------------------------------------------------------
    local ghost = UI.Panel(UIParent, "panel", "accent")
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetSize(200, CARD_H)
    ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
    ghost.icon:SetSize(20, 20); ghost.icon:SetPoint("LEFT", 6, 0); ghost.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ghost.text = UI.Text(ghost, 12, "text"); ghost.text:SetPoint("LEFT", ghost.icon, "RIGHT", 6, 0)
    ghost:Hide()
    local marker = UI.Fill(colBody, "accent", "OVERLAY")
    marker:SetHeight(2)
    marker:Hide()
    local dragging, layout

    local function cursor()
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        return x / scale, y / scale
    end

    -- column and insert position under the cursor, or nil
    local function dropTarget()
        if not layout or not colArea:IsMouseOver() then return nil end
        local cx, cy = cursor()
        local left, top = colBody:GetLeft(), colBody:GetTop()
        if not left or not top then return nil end
        local scale = colBody:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local x, y = cx / scale - left, top - cy / scale
        local col = math.floor(x / (layout.colW + 8)) + 1
        if col < 1 or col > layout.count then return nil end
        local list = layout.cols[col] or {}
        local index = math.floor((y - 30 + CARD_H / 2) / (CARD_H + GAP)) + 1
        index = math.max(1, math.min(#list + 1, index))
        return col, index
    end

    local function startDrag(c)
        if not c.entry then return end
        dragging = c.entry.spell
        selected = dragging.id
        ghost.icon:SetTexture(Spells.Icon(dragging))
        ghost.text:SetText(Spells.Name(dragging))
        ghost:SetWidth(math.max(160, (ghost.text:GetStringWidth() or 100) + 44))
        ghost:Show()
        ghost:SetScript("OnUpdate", function(self)
            local x, y = cursor()
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + 12, y - 4)
            local col, index = dropTarget()
            if col then
                marker:ClearAllPoints()
                marker:SetPoint("TOPLEFT", colBody, "TOPLEFT", (col - 1) * (layout.colW + 8), -(30 + (index - 1) * (CARD_H + GAP)) + 2)
                marker:SetWidth(layout.colW)
                marker:Show()
            else
                marker:Hide()
            end
        end)
        c:SetAlpha(0.4)
    end

    local function stopDrag(c)
        if not dragging then return end
        local spell = dragging
        dragging = nil
        ghost:SetScript("OnUpdate", nil)
        ghost:Hide()
        marker:Hide()
        c:SetAlpha(1)
        local col, index = dropTarget()
        if col then
            insert(spell, col, index)
        elseif poolPanel:IsMouseOver() and Spells.Config(spell).display == state.display then
            removeSpell(spell)
        else
            tab.Refresh()
        end
    end

    ---------------------------------------------------------------------
    -- cards
    ---------------------------------------------------------------------
    local function newCard(parent)
        local c = CreateFrame("Button", nil, parent, "BackdropTemplate")
        c:SetHeight(CARD_H)
        c:SetBackdrop({ bgFile = Theme.WHITE, edgeFile = Theme.WHITE, edgeSize = 1 })
        c:RegisterForDrag("LeftButton")
        c.stripe = c:CreateTexture(nil, "ARTWORK"); c.stripe:SetTexture(Theme.WHITE)
        c.stripe:SetPoint("TOPLEFT", 1, -1); c.stripe:SetPoint("BOTTOMLEFT", 1, 1); c.stripe:SetWidth(3)
        c.icon = c:CreateTexture(nil, "ARTWORK"); c.icon:SetSize(20, 20); c.icon:SetPoint("LEFT", 9, 0)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.grip = UI.Icon(c, "move", 12, "muted"); c.grip:SetPoint("RIGHT", -8, 0)
        c.name = UI.Text(c, 12, "text")
        c.name:SetPoint("LEFT", c.icon, "RIGHT", 6, 0)
        c.name:SetPoint("RIGHT", c.grip, "LEFT", -6, 0)
        c:SetScript("OnClick", function(self)
            selected = self.entry and self.entry.spell.id
            tab.Refresh()
        end)
        c:SetScript("OnDoubleClick", function(self)
            if not self.entry then return end
            if self.inPool then insert(self.entry.spell, 1, nil)
            else Spells.Set(self.entry.spell, "enabled", not self.entry.cfg.enabled); tab.Refresh() end
        end)
        c:SetScript("OnDragStart", startDrag)
        c:SetScript("OnDragStop", stopDrag)
        c:SetScript("OnEnter", function(self)
            if not self.entry or dragging then return end
            ns.TipOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetSpellByID, GameTooltip, self.entry.spell.id)
            GameTooltip:AddLine(self.inPool and L.CD_DRAG_ADD or L.CD_DRAG_MOVE, 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return c
    end

    local colCards, poolCards, heads, classHeads = {}, {}, {}, {}

    local function place(c, entry, x, y, w, inPool)
        c.entry, c.inPool = entry, inPool
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", c:GetParent(), "TOPLEFT", x, -y)
        c:SetWidth(w)
        local sel = entry.spell.id == selected
        c:SetBackdropColor(Theme.Color(sel and "accentDim" or "panel"))
        c:SetBackdropBorderColor(Theme.Color(sel and "accent" or "panel"))
        local r, g, b = ns.ClassColor(entry.spell.class ~= "ALL" and entry.spell.class or nil)
        c.stripe:SetVertexColor(r, g, b, 1)
        c.icon:SetTexture(Spells.Icon(entry.spell))
        local shown = entry.cfg.enabled and not inPool
        c.icon:SetDesaturated(not inPool and not entry.cfg.enabled)
        local label = Spells.Name(entry.spell)
        if inPool and entry.cfg.display ~= "off" and entry.cfg.enabled then
            local d = Bars().Display(entry.cfg.display)
            label = label .. Theme.HexColor("muted", "  · " .. (d and d.name or entry.cfg.display))
        elseif not inPool and not entry.cfg.enabled then
            label = label .. Theme.HexColor("muted", "  (" .. L.CD_HIDDEN .. ")")
        end
        c.name:SetText(label)
        c.name:SetTextColor(Theme.Color((shown or inPool) and "text" or "muted"))
        c:SetAlpha(1)
        c:Show()
    end

    local function header(store, parent, i, size, role)
        if store[i] then return store[i] end
        local h = CreateFrame("Frame", nil, parent)
        h:SetHeight(size or 24)
        h.text = UI.Text(h, 12, role or "gold")
        h.text:SetPoint("LEFT", 2, 0)
        h.line = UI.Divider(h)
        h.line:SetPoint("BOTTOMLEFT"); h.line:SetPoint("BOTTOMRIGHT")
        store[i] = h
        return h
    end

    local function poolMatches(entry)
        local spell, cfg = entry.spell, entry.cfg
        if poolFilter.class ~= "all" and spell.class ~= poolFilter.class then return false end
        if poolFilter.cat ~= "all" and spell.cat ~= poolFilter.cat then return false end
        if poolFilter.unused and cfg.display ~= "off" and cfg.enabled then return false end
        if poolFilter.search ~= "" and not (Spells.Name(spell) or ""):lower():find(poolFilter.search, 1, true) then return false end
        return true
    end

    function tab.Refresh()
        if Bars().Display(state.display) == nil or Bars().Display(state.display).pick then state.display = "raid" end
        pick:Refresh(); classDrop:Refresh(); catDrop:Refresh(); onlyFree:Refresh()
        local cols = spellsIn(state.display)
        local maxCol = 0
        for col in pairs(cols) do maxCol = math.max(maxCol, col) end
        local d = Bars().Display(state.display)
        local count = math.min(12, math.max(maxCol, d.boardCols or 1, 1))
        d.boardCols = count
        local width = (colBody:GetWidth() or 600) - 48
        local colW = math.max(64, math.floor((width - (count - 1) * 8) / count))
        layout = { cols = cols, count = count, colW = colW }

        -- columns
        local n, maxY = 0, 0
        for _, h in ipairs(heads) do h:Hide() end
        for col = 1, count do
            local x = (col - 1) * (colW + 8)
            local h = header(heads, colBody, col)
            h:ClearAllPoints(); h:SetPoint("TOPLEFT", colBody, "TOPLEFT", x, 0); h:SetWidth(colW)
            h.text:SetText(colW < 100 and ("#" .. col) or (L.CD_COLUMN .. " " .. col))
            if not h.close then
                h.close = UI.IconButton(h, "x", 18, nil, true)
                h.close.tip = L.CD_REMOVE_COLUMN
                h.close:SetPoint("RIGHT", -2, 2)
            end
            local removable = col == count and count > 1 and not (cols[col] and #cols[col] > 0)
            h.close:SetShown(removable)
            h.close:SetScript("OnClick", function() d.boardCols = count - 1; GameTooltip:Hide(); tab.Refresh() end)
            h:Show()
            local y = 30
            for _, entry in ipairs(cols[col] or {}) do
                n = n + 1
                colCards[n] = colCards[n] or newCard(colBody)
                place(colCards[n], entry, x, y, colW, false)
                y = y + CARD_H + GAP
            end
            maxY = math.max(maxY, y + CARD_H)
        end
        -- "+" column at the end: adds an empty column
        if not tab.addCol then
            tab.addCol = CreateFrame("Button", nil, colBody, "BackdropTemplate")
            tab.addCol:SetBackdrop({ bgFile = Theme.WHITE, edgeFile = Theme.WHITE, edgeSize = 1 })
            tab.addCol.plus = UI.Text(tab.addCol, 20, "accent", "CENTER")
            tab.addCol.plus:SetPoint("CENTER")
            tab.addCol.plus:SetText("+")
            tab.addCol:SetScript("OnEnter", function(self)
                self:SetBackdropBorderColor(Theme.Color("accent"))
                UI.Tooltip(self, L.CD_ADD_COLUMN, { L.CD_ADD_COLUMN_TIP })
            end)
            tab.addCol:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(Theme.Color("borderDim")); GameTooltip:Hide() end)
        end
        tab.addCol:SetBackdropColor(Theme.Color("rowAlt"))
        tab.addCol:SetBackdropBorderColor(Theme.Color("borderDim"))
        tab.addCol:ClearAllPoints()
        tab.addCol:SetPoint("TOPLEFT", colBody, "TOPLEFT", count * (colW + 8), 0)
        tab.addCol:SetSize(40, math.max(120, maxY - 10))
        tab.addCol:SetShown(count < 12)
        tab.addCol:SetScript("OnClick", function() d.boardCols = math.min(12, count + 1); tab.Refresh() end)
        for k = n + 1, #colCards do colCards[k]:Hide() end
        colBody:SetHeight(maxY + 10)
        colScroll.UpdateBar()

        -- pool grouped by class
        local groups, total = {}, 0
        for _, spell in ipairs(Spells.list) do
            local cfg = Spells.Config(spell)
            local entry = { spell = spell, cfg = cfg }
            if cfg.display ~= state.display and poolMatches(entry) then
                groups[spell.class] = groups[spell.class] or {}
                table.insert(groups[spell.class], entry)
                total = total + 1
            end
        end
        poolTitle:SetText(L.CD_NOT_SHOWN .. Theme.HexColor("muted", "  " .. total))
        local y, m, hn = 0, 0, 0
        local pw = (poolBody:GetWidth() or (POOL_W - 22))
        for _, h in ipairs(classHeads) do h:Hide() end
        for _, class in ipairs(CLASS_ORDER) do
            local list = groups[class]
            if list then
                hn = hn + 1
                local h = header(classHeads, poolBody, hn, 22, "text")
                h:ClearAllPoints(); h:SetPoint("TOPLEFT", poolBody, "TOPLEFT", 0, -y); h:SetWidth(pw)
                local label = class == "ALL" and L.CD_ANY_CLASS or ("|c%s%s|r"):format(ns.ClassHex(class), className(class))
                h.text:SetText(label .. Theme.HexColor("muted", "  " .. #list))
                h:Show()
                y = y + 26
                table.sort(list, function(a, b) return a.spell.order < b.spell.order end)
                for _, entry in ipairs(list) do
                    m = m + 1
                    poolCards[m] = poolCards[m] or newCard(poolBody)
                    place(poolCards[m], entry, 0, y, pw, true)
                    y = y + CARD_H + GAP
                end
                y = y + 6
            end
        end
        for k = m + 1, #poolCards do poolCards[k]:Hide() end
        poolBody:SetHeight(y + 10)
        poolScroll.UpdateBar()

        local spell = selected and Spells.byId[selected]
        local inDisplay = spell and Spells.Config(spell).display == state.display
        for k = 1, 6 do actions.buttons[k]:SetEnabled(inDisplay and true or false) end
    end
    colBody:SetScript("OnSizeChanged", function() if tab:IsShown() then tab.Refresh() end end)
    return tab
end

UI.AddPage("cooldowns", L.PAGE_COOLDOWNS, 50, function(content, page)
    local toolbar = UI.Toolbar(content, {
        { text = L.CD_PREVIEW_SHORT, width = 130, icon = "sparkles", tip = L.CD_PREVIEW_TIP,
          onClick = function() Cooldowns.SetPreview(not Cooldowns.IsPreview()); page.OnShow() end },
        { text = L.MOVE_ELEMENTS, width = 160, icon = "move", tip = L.MOVE_ELEMENTS_TIP, onClick = function() ns.Window.ToggleMovers() end },
        { text = L.CD_RESET_ALL_POSITIONS, width = 190, icon = "rotate-ccw", onClick = function()
            for _, key in ipairs(Bars().Keys()) do Bars().ResetPosition(key) end
        end },
    })
    toolbar:SetPoint("TOPLEFT")
    toolbar:SetPoint("TOPRIGHT", -ns.Window.SearchReserve(), 0)
    local tabs = {}
    local holder = CreateFrame("Frame", nil, content)
    holder:SetPoint("TOPLEFT", 0, -74)
    holder:SetPoint("BOTTOMRIGHT")
    tabs.board = buildBoard(holder)
    tabs.displays = buildDisplays(holder)
    tabs.spells = buildSpells(holder)
    local bar = UI.SubTabs(content, { { key = "board", title = L.CD_TAB_BOARD }, { key = "displays", title = L.CD_TAB_DISPLAYS },
        { key = "spells", title = L.CD_TAB_SPELLS } }, function(key)
        for k, t in pairs(tabs) do t:SetShown(k == key) end
        tabs[key].Refresh()
    end)
    bar:SetPoint("TOPLEFT", 0, -36)
    bar:SetPoint("TOPRIGHT", 0, -36)
    bar:Select("board")
    ns.CooldownsPage.selectTab = function(key) bar:Select(key) end
    page.ShowSettings = function() bar:Select("displays") end
    tabs.displays.form.reveal = function() bar:Select("displays") end
    -- header search: spells in the pool (board), display settings, spell list
    page.searchHint = L.CD_SEARCH_PAGE
    -- display settings and the spell list are searched (nothing is hidden); the tab with hits opens
    tabs.displays.SearchHits = function(q) return tabs.displays.form:Filter(q) end
    tabs.displays.SearchApply = function(q) tabs.displays.form:Filter(q) end
    tabs.spells.SearchHits = function(q) tabs.spells.Refresh(); return tabs.spells.list:SearchHits(q) end
    tabs.spells.SearchApply = function(q) tabs.spells.Refresh(); tabs.spells.list:ShowFirstHit(q) end
    page.Search = function(text) return UI.TabSearch(bar, tabs, text) end
    page.OnShow = function()
        toolbar.buttons[1]:SetText(Cooldowns.IsPreview() and L.CD_PREVIEW_OFF or L.CD_PREVIEW_SHORT)
        toolbar.buttons[1].fullText = toolbar.buttons[1].label:GetText()
        toolbar:Fit()
        tabs[bar.current].Refresh()
    end
end, { section = "raid", icon = "timer", module = "cooldowns" })

-- throttled (a debounce never ran while casts kept coming in a raid)
local pageRefreshPending = false
ns.On("LG_COOLDOWNS", function()
    if pageRefreshPending then return end
    pageRefreshPending = true
    ns.After(0.3, function() pageRefreshPending = false; ns.Window.Refresh("cooldowns") end)
end)
