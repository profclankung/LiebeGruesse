-- "Modules" page: switch whole modules on/off. Their settings are in each
-- module's own page (tab "Settings"); the gear button opens it.
-- Everything is on by default; each player decides for themselves.
local _, ns = ...
local UI, Theme, L = ns.UI, ns.Theme, ns.L

local MODULES = {
    { key = "cooldowns", settings = true, icon = "timer", page = "cooldowns" },
    { key = "council", settings = true, icon = "gem", page = "council" },
    { key = "blessings", settings = true, icon = "sparkles", page = "blessings" },
    { key = "community", icon = "crown", page = "community" },
    { key = "professions", settings = true, icon = "scroll-text", page = "professions" },
    { key = "feed", settings = true, icon = "newspaper", page = "feed" },
    { key = "stats", icon = "badge-check", page = "stats" },
    { key = "runs", settings = true, icon = "flag", page = "runs" },
    { key = "achievements", settings = true, icon = "trophy", page = "achievements" },
    { key = "bugs", icon = "bug" },
    { key = "greet", icon = "message-circle" },
}

local function settings() return ns.Database.Settings() end

local function apply()
    ns.Window.BuildNav()
    ns.Fire("LG_COOLDOWNS")
    ns.Fire("LG_MODULES")
end

UI.AddPage("modules", L.PAGE_MODULES, 89, function(content, page)
    local form = UI.Form(content)
    page.Search = function(text) return form:Filter(text) end
    page.SearchEnter = function() form:JumpFirst() end
    page.head = L.HEAD_MODULES
    form.scroll:SetPoint("TOPLEFT")
    form.scroll:SetPoint("BOTTOMRIGHT", -8, 0)
    local st = settings()
    local function isOn(key) return function() return st.modules[key] ~= false end end
    local gears = {}
    local function updateGears()
        for _, g in ipairs(gears) do
            local p = ns.Window.Page(g.page)
            g:SetShown(st.modules[g.key] ~= false and p ~= nil and ns.Window.PageVisible(p))
        end
    end

    -- every module: icon, name, switch (two columns); what it does in the tooltip.
    -- The settings of a module are in its own page (tab "Settings", gear button).
    local mods = form:Section(L.SET_MODULES, { wide = true, grid = true })
    for _, m in ipairs(MODULES) do
        local name = L["PAGE_" .. m.key:upper()] or m.key
        local toggle, row = mods:Toggle(name, isOn(m.key), function(v) st.modules[m.key] = v; apply(); updateGears() end,
            { tip = L["MOD_" .. m.key:upper() .. "_TEXT"] })
        row.icon = UI.Icon(row, m.icon, 16, "accent")
        row.icon:SetPoint("LEFT", 16, 0)
        row.label:SetPoint("LEFT", 42, 0)
        row.searchText = L["MOD_" .. m.key:upper() .. "_TEXT"] or ""
        if m.settings then
            local gear = UI.IconButton(row, "settings", 18, function() ns.Window.ShowSettings(m.page) end)
            gear:SetPoint("RIGHT", toggle, "LEFT", -10, 0)
            gear.tip = L.MOD_OPEN_SETTINGS
            gear.key, gear.page = m.key, m.page
            gears[#gears + 1] = gear
        end
    end

    -- who sees the loot council page (stays here: a hidden page cannot switch itself back on)
    local council = form:Section(L.PAGE_COUNCIL, { show = isOn("council") })
    council:Toggle(L.SET_COUNCIL_ONLY, function() return st.modules.councilOnlyMembers end, function(v)
        st.modules.councilOnlyMembers = v
        apply()
        updateGears()
    end, { tip = L.SET_COUNCIL_ONLY_TIP })
    -- the page is hidden for you: your popup option lives here
    council:Toggle(L.LC_AUTOPASS, function() return st.lcAutoPass end, function(v) st.lcAutoPass = v end,
        { col = 2, tip = L.LC_AUTOPASS_TIP, show = function() return not ns.Council.PageAllowed() end })

    page.OnShow = function()
        updateGears()
        form:Refresh()
    end
end, { section = "settings", icon = "badge-check" })
