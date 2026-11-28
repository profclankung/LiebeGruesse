-- Who in the group died, and when – without the combat log (Forever forbids it).
-- Group units are read once per second while a fight runs and on unit flag
-- changes (throttled). Only "alive → dead" counts: players who were already
-- dead or a ghost before, and feigning hunters, never do.
--   LG_DEATH (key, unit, GetTime())   LG_ALIVE (key)
-- Used by the raid night boards and the speedrun death counter.
local _, ns = ...
local DW = {}
ns.DeathWatch = DW

local state = {}          -- [key] = "alive" | "dead"
DW.state = state
local ticker

-- true/false, or nil when the game does not tell (secret value)
local function readDead(unit)
    if ns.Call(UnitIsFeignDeath, unit) == true then return false end
    local v = ns.Call(UnitIsDeadOrGhost, unit)
    if v == nil then return nil end
    return v == true
end
DW.ReadDead = readDead

function DW.Scan()
    if not IsInGroup() then wipe(state); return end
    local seen, now = {}, GetTime()
    for unit, key in ns.GroupUnits() do
        seen[key] = true
        local dead = readDead(unit)
        if dead ~= nil then
            local old = state[key]
            if dead and old == "alive" then
                state[key] = "dead"
                ns.Fire("LG_DEATH", key, unit, now)
            elseif not dead and old == "dead" then
                state[key] = "alive"
                ns.Fire("LG_ALIVE", key)
            elseif old == nil then
                state[key] = dead and "dead" or "alive"
            end
        end
    end
    for key in pairs(state) do if not seen[key] then state[key] = nil end end
end

function DW.IsDead(key) return state[key] == "dead" end

-- keys that are alive right now
function DW.Alive()
    local list = {}
    for key, s in pairs(state) do if s == "alive" then list[#list + 1] = key end end
    table.sort(list)
    return list
end

local function fighting()
    return InCombatLockdown() or ns.Call(UnitAffectingCombat, "player") == true or ns.EncounterInProgress()
end

-- only needed in a raid night (raid instance, guild raid) or during a speedrun
function DW.Needed()
    if not IsInGroup() then return false end
    if ns.CommunityRaid and ns.CommunityRaid.Active() then return true end
    local run = ns.Runs and ns.Runs.Active()
    return run ~= nil and run.start ~= nil and not run.fin
end

-- the 1 s reader runs only while a fight is going on
local function tick()
    DW.Scan()
    if not fighting() and ticker then ticker:Cancel(); ticker = nil end
end
function DW.Start()
    if not DW.Needed() then return end
    DW.Scan()
    if not ticker then ticker = C_Timer.NewTicker(1, ns.Guard(tick)) end
end
function DW.Running() return ticker ~= nil end

ns.On("PLAYER_REGEN_DISABLED", DW.Start)
ns.On("ENCOUNTER_START", DW.Start)
local function scanIfNeeded() if DW.Needed() then DW.Scan() end end
ns.On("PLAYER_REGEN_ENABLED", function() ns.After(1, scanIfNeeded) end)
ns.On("GROUP_ROSTER_UPDATE", function() ns.Debounce("deathwatch-roster", 1, scanIfNeeded) end)
ns.On("PLAYER_DEAD", scanIfNeeded)
ns.On("PLAYER_ALIVE", scanIfNeeded)
ns.On("PLAYER_UNGHOST", scanIfNeeded)

-- outside of fights (falling, drowning …): unit flags, throttled to 2 per second
local lastScan = 0
ns.On("UNIT_FLAGS", function()
    if ticker or not IsInGroup() or not DW.Needed() then return end
    if GetTime() - lastScan < 0.5 then
        ns.Debounce("deathwatch-flags", 0.6, function() lastScan = GetTime(); DW.Scan() end)
        return
    end
    lastScan = GetTime()
    DW.Scan()
end)
