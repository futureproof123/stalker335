StalkerData = Stalker:NewModule("StalkerData")

local L = LibStub("AceLocale-3.0"):GetLocale("Stalker", true)

local Stalker = Stalker
local Config = StalkerConfig

local bor = bit.bor
local band = bit.band
local time = time
local STALKER_ENCOUNTER = STALKER_ENCOUNTER
local STALKER_PLAYER = STALKER_PLAYER
local STALKER_GUILD = STALKER_GUILD
local STALKER_TT_IGNORE = STALKER_TT_IGNORE

local db = {
    session = {
        players = {},
        guilds = {},
    },
    pvp = {
        incoming = {},
        outgoing = {},
    },
    ignored = {},
    agents = {},
    tooltips = {
        pets = {},
        guilds = {},
    },
    classes = {"Warrior","Paladin","Hunter","Rogue","Priest","Death Knight","Shaman","Mage","Warlock","Druid"},
    map = {},
}

-- DELETE ME
STALKERDATA_DB = db

-- sessions have weak keys (pointers to units)
setmetatable(db.session.players, {
    __mode = "k",
    __index = function(t, k)
        rawset(t, k, {})
        return t[k]
    end,
})
setmetatable(db.session.guilds, {
    __mode = "k",
    __index = function(t, k)
        rawset(t, k, {})
        return t[k]
    end,
})

-- pvp timers have weak keys (pointers to units)
setmetatable(db.pvp.incoming, {__mode = "k"})
setmetatable(db.pvp.outgoing, {__mode = "k"})

-- memoized reverse lookup of classes
setmetatable(db.classes, {
    __index = function(t, k)
        for i,v in pairs(t) do
            if v == k then
                rawset(t, k, i)
                return i
            end
        end
    end,
})


local cache = {
    units = {
        players = {
            name = {data = {}},
            level = {data = {}},
            class = {data = {}},
            guild = {data = {}},
            kills = {data = {}},
            deaths = {data = {}},
            last = {data = {}},
        },
        guilds = {
            guild = {data = {}},
            kills = {data = {}},
            deaths = {data = {}},
            last = {data = {}},
        },
    },
}

-- caches have weak values (pointers to units)
setmetatable(cache.units.players.last.data, {__mode = "v"})
setmetatable(cache.units.guilds.last.data, {__mode = "v"})
setmetatable(cache.units.guilds.guild.data, {__mode = "v"})

-- create a temp table pool
local tp = {}
setmetatable(tp, {__mode = "k"})

local function getTable()
    local t = next(tp) or {}
    tp[t] = nil
    return t
end

local function releaseTable(t)
    if type(t) ~= "table" then return end
    for k in pairs(t) do t[k] = nil end
    t[1] = true; t[1] = nil
    tp[t] = true
    return nil
end

local emptyTable = {}

function StalkerData:OnInitialize()
    Stalker:SetDataDb(db)
    self:LoadMapData()
end

function StalkerData:OnEnable()
    -- unit testing
    if StalkerUnitTest then StalkerUnitTest:LoadData(db, cache) end
end

function StalkerData:SetSavedVariablesDb(val)
    db.units = val.factionrealm.units
end

function StalkerData:PurgeExpiredData()
    self:PurgeUnits()
    self:PurgePvpTimers()
    self:PurgeTooltipLookups()
end

function StalkerData:LoadMapData()
    local continents = {GetMapContinents()}
    for index, name in ipairs(continents) do
        db.map[index] = {GetMapZones(index)}
        db.map[index].name = name
    end
end

function StalkerData:GetLocationName(continent, zone)
    local c = db.map[continent] and db.map[continent].name or nil
    local z = c and (db.map[continent][zone] and db.map[continent][zone] or nil) or nil
    return c, z
end

function StalkerData:GetClassName(id)
    return db.classes[id]
end

function StalkerData:GetClassId(name)
    return db.classes[name]
end


--
-- UNIT FUNCTIONS
--
function StalkerData:GetUnitSession(unit)
    assert(unit, "Invalid unit (" .. tostring(unit) .. ")")
    assert(unit.type, "Invalid unit type (" .. tostring(unit.type) .. ")")
    if unit.type == STALKER_PLAYER then
        return db.session.players[unit]
    elseif unit.type == STALKER_GUILD then
        return db.session.guilds[unit]
    end
end

function StalkerData:SetUnitNote(unit, note)
    assert(unit, "Invalid unit (" .. tostring(unit) .. ")")
    assert(unit.type, "Invalid unit type (" .. tostring(unit.type) .. ")")
    unit.note = note
end


--
-- PLAYER FUNCTIONS
--

function StalkerData:AddPlayer(unit)
    assert(unit, "Invalid unit (" .. tostring(unit) .. ")")
    assert(unit.type and unit.type == STALKER_PLAYER, "Invalid unit type (" .. tostring(unit.type) .. ")")
    assert(unit.name, "Invalid unit name (" .. tostring(unit.name) .. ")")
    db.units.players[unit.name] = unit
end

function StalkerData:IsPlayer(name)
    return (db.units.players[name] and true or false)
end

function StalkerData:GetPlayer(name)
    return db.units.players[name]
end

function StalkerData:SetPlayerTrack(unit, value)
    assert(unit, "Invalid unit (" .. tostring(unit) .. ")")
    assert(unit.type and unit.type == STALKER_PLAYER, "Invalid unit type (" .. tostring(unit.type) .. ")")
    db.session.players[unit].track = (value and 1 or nil)
end

function StalkerData:SetPlayerKos(unit, value)
    assert(unit, "Invalid unit (" .. tostring(unit) .. ")")
    assert(unit.type and unit.type == STALKER_PLAYER, "Invalid unit type (" .. tostring(unit.type) .. ")")
    unit.kos = (value and 1 or nil)
end

function StalkerData:UntrackAllPlayers()
    for _, unit in self:GetTrackedUnits() do
        unit.track = nil
    end
end

function StalkerData:GetTrackedPlayerCount()
    local count = 0
    for _ in self:GetTrackedUnits() do
        count = count + 1
    end
    return count
end


--
-- GUILD FUNCTIONS
--
function StalkerData:AddGuild(unit)
    assert(unit, "Invalid unit (" .. tostring(unit) .. ")")
    assert(unit.type and unit.type == STALKER_GUILD, "Invalid unit type (" .. tostring(unit.type) .. ")")
    assert(unit.guild and unit.guild ~= "", "Invalid guild name (" .. tostring(unit.guild) .. ")")
    db.units.guilds[unit.guild] = unit
end

function StalkerData:GetGuild(name)
    return ((name and name ~= "") and db.units.guilds[name] or nil)
end

function StalkerData:IsGuildKos(unit)
    assert(unit, "Invalid unit (" .. tostring(unit) .. ")")
    assert(unit.type, "Invalid unit type (" .. tostring(unit.type) .. ")")
    if unit.type == STALKER_GUILD then
        return unit.kos
    elseif (unit.type == STALKER_PLAYER) and unit.guild and (unit.guild ~= "") then
        return db.units.guilds[unit.guild].kos
    end
end

function StalkerData:SetGuildKos(unit, value)
    assert(unit, "Invalid unit (" .. tostring(unit) .. ")")
    assert(unit.type, "Invalid unit type (" .. tostring(unit.type) .. ")")
    if unit.type == STALKER_GUILD then
        unit.kos = (value and 1 or nil)
    elseif (unit.type == STALKER_PLAYER) and unit.guild and (unit.guild ~= "") then
        db.units.guilds[unit.guild].kos = (value and 1 or nil)
    end
end


---
--- PVP FUNCTIONS
---

-- set unit pvp flag to current time. used by Stalker Monitor to show pvp'ers
function StalkerData:LogPvp(unit)
    assert(unit, "Invalid unit (" .. tostring(unit) .. ")")
    assert(unit.type, "Invalid unit type (" .. tostring(unit.type) .. ")")
    db.session.players[unit].pvp = time()
end

-- set time I attacked hostile. hostile kills within STALKER_ENCOUNTER time
-- are credited to me as a kill.
function StalkerData:LogOutgoingPvp(unit)
    assert(unit, "Invalid unit (" .. tostring(unit) .. ")")
    assert(unit.type, "Invalid unit type (" .. tostring(unit.type) .. ")")
    db.pvp.outgoing[unit] = time()
end

-- set time I was attacked by hostile. my deaths within STALKER_ENCOUNTER time
-- are credited to them as a death.
function StalkerData:LogIncomingPvp(unit)
    assert(unit, "Invalid unit (" .. tostring(unit) .. ")")
    assert(unit.type, "Invalid unit type (" .. tostring(unit.type) .. ")")
    db.pvp.incoming[unit] = time()
end

-- add kill to hostile kill counter
function StalkerData:LogHostilePvpDeath(unit, session)
    assert(unit, "Invalid unit (" .. tostring(unit) .. ")")
    assert(unit.type, "Invalid unit type (" .. tostring(unit.type) .. ")")

    local now = time()

    -- save their time of death so we can ignore dots events that may still occur
    -- after their death
    session.dead = now

    -- add to kill count if last attack was within STALKER_ENCOUNTER
    if db.pvp.outgoing[unit] and (db.pvp.outgoing[unit] > (now - STALKER_ENCOUNTER)) then
        unit.kills = (unit.kills and (unit.kills + 1) or 1)
        db.pvp.outgoing[unit] = nil
        db.pvp.incoming[unit] = nil

        -- if player isnt guildless try to add to kill count
        local guild
        if unit.guild ~= "" then
            -- if guild not known try to do a tooltip parse to get it
            if unit.guild then
                guild = db.units.guilds[unit.guild]
            else
                guild = db.tooltips.guilds[unit.guid]
                if guild then
                    unit.guild = guild.name
                    guild = Stalker:ProcessGuildEvent(unit)
                end
            end

            if guild then
                guild.kills = (guild.kills and (guild.kills + 1) or 1)
            end
        end
    end
end

-- add death to hostile death counters
function StalkerData:LogMyPvpDeath()
    local now = time()

    -- go through all hostiles that have attacked me within STALKER_ENCOUNTER
    -- and add to death count for each since they all get credit
    for unit, last in pairs(db.pvp.incoming) do
        if last > (now - STALKER_ENCOUNTER) then
            unit.deaths = (unit.deaths and (unit.deaths + 1) or 1)
            db.pvp.outgoing[unit] = nil
            db.pvp.incoming[unit] = nil

            -- if player isnt guildless try to add to death count
            local guild
            if unit.guild ~= "" then
                -- if guild not known try to do a tooltip parse to get it
                if unit.guild then
                    guild = db.units.guilds[unit.guild]
                else
                    guild = db.tooltips.guilds[unit.guid]
                    if guild then
                        unit.guild = guild.name
                        guild = Stalker:ProcessGuildEvent(unit)
                    end
                end

                if guild then
                    guild.deaths = (guild.deaths and (guild.deaths + 1) or 1)
                end
            end
        end
    end
end

-- removes entries from the incoming and outgoing pvp lists if they are
-- older than STALKER_ENCOUNTER
function StalkerData:PurgePvpTimers()
    local now = time()

    -- clean up other expired timers
    for unit, last in pairs(db.pvp.incoming) do
        if last < (now - STALKER_ENCOUNTER) then
            db.pvp.incoming[unit] = nil
        end
    end

    for unit, last in pairs(db.pvp.outgoing) do
        if last < (now - STALKER_ENCOUNTER) then
            db.pvp.outgoing[unit] = nil
        end
    end
end


--
-- TOOLTIP LOOKUP PARSERS
--
do
    local tooltip = _G["StalkerCombatGameTooltip"]
    local tooltipLine1 = _G["StalkerCombatGameTooltipTextLeft1"]
    local tooltipLine2 = _G["StalkerCombatGameTooltipTextLeft2"]
    local tooltipLine3 = _G["StalkerCombatGameTooltipTextLeft3"]

    -- table to obtain pet owner name from pet unit guid
    setmetatable(db.tooltips.pets, {
        __index = function(tbl, guid)
            tooltip:ClearLines()
            tooltip:SetHyperlink("unit:" .. guid)

            local line2 = tooltipLine2:GetText()
            local line3 = tooltipLine3:GetText()
            local owner

            if line2 and line2:find(L["TT_LEVEL_LINE"]) then
                -- response format not recognized. cache an ignore value
                -- to ignore this guid for awhile
                owner = STALKER_TT_IGNORE
            elseif line3 and line3:find(L["TT_LEVEL_LINE"]) then
                _, _, owner = line2:find(L["TT_PET_OWNER_LINE"])
                if owner == "Unknown" then return end
            else
                -- response format not recognized. cache an ignore value
                -- to ignore this guid for awhile
                owner = STALKER_TT_IGNORE
            end

            -- only used when testing in bgs
            owner = strsplit("-", owner)

            local val = getTable()
            val.name = owner
            val.created = time()
            rawset(tbl, guid, val)
            return val
        end,
    })

    -- table to obtain guild name from player unit guid
    setmetatable(db.tooltips.guilds, {
        __index = function(tbl, guid)
            tooltip:ClearLines()
            tooltip:SetHyperlink("unit:" .. guid)

            local line2 = tooltipLine2:GetText()
            local line3 = tooltipLine3:GetText()
            local guild

            if line2 and line2:find(L["TT_LEVEL_LINE"]) then
                guild = ""
            elseif line3 and line3:find(L["TT_LEVEL_LINE"]) then
                guild = line2
            else
                return
            end

            local val = getTable()
            val.name = guild
            val.created = time()
            rawset(tbl, guid, val)
            return val
        end,
    })
end

--
-- AGENT FUNCTIONS
--

function StalkerData:AddAgentTracked(agent, name)
    if not db.agents[name] then
        db.agents[name] = getTable()
    end
    db.agents[name][agent] = time()
    Stalker:debug("agent", 2, "StalkerData:AddAgentTracked()", agent, name)
end

function StalkerData:GetAgents(name)
    if db.agents[name] then
        return db.agents[name]
    else
        return emptyTable
    end
end

---
--- CLEANUP FUNCTIONS
---

-- go through all units and remove older ones with no trackable data such as
-- kills, deaths, kos flagged, or notes.
function StalkerData:PurgeUnits()
    local now = time()

    -- on startup ensure we do a purge of old data in storage.
    if not self.lastUnitPurge then self.lastUnitPurge = 0 end

    -- run purge every 10 minutes
    if (now - self.lastUnitPurge) > 600 then
        -- temp table to track how many players are in each guild. this prevents
        -- us from removing guilds that have players with trackable data.
        local guilds = {}

        -- purge player units        
        for _, unit in pairs(db.units.players) do
            -- if player has guild add to guild count
            if unit.guild and (unit.guild ~= "") then
                guilds[unit.guild] = (guilds[unit.guild] and (guilds[unit.guild] + 1) or 1)
            end

            -- purge anything not updated in the last 24 hours
            if (unit.last < (now - 86400)) and (not unit.kos) and (not unit.note) and (not unit.kills) and (not unit.deaths) then
                db.units.players[unit.name] = nil

                -- if player was in a guild remove player from guild count
                if unit.guild and (unit.guild ~= "") then
                    guilds[unit.guild] = guilds[unit.guild] - 1
                end
            end
        end

        -- purge guild units        
        for _, unit in pairs(db.units.guilds) do
            -- purge anything not updated in the last 24 hours
            if (unit.last < (now - 86400)) and (not unit.kos) and (not unit.note) and (not unit.kills) and (not unit.deaths) then
                -- only remove guild if no players
                if guilds[unit.guild] and (guilds[unit.guild] < 1) then
                    db.units.guilds[unit.guild] = nil
                end
            end
        end

        StalkerViewer:Recalulate()

        self.lastUnitPurge = time()
    end
end

-- purge pet and guild lookups older than 5 min
function StalkerData:PurgeTooltipLookups()
    local now = time()
    for guid, entry in pairs(db.tooltips.pets) do
        if entry.created < (now - 300) then
            db.tooltips.pets[guid] = releaseTable(db.tooltips.pets[guid])
        end
    end
    for guid, entry in pairs(db.tooltips.guilds) do
        if entry.created < (now - 300) then
            db.tooltips.guilds[guid] = releaseTable(db.tooltips.guilds[guid])
        end
    end
end

-- purge ignore list entries older than 15 min
function StalkerData:PurgeIgnoreList()
    local now = time()
    for name, last in pairs(db.ignored) do
        if last < (now - 900) then
            db.ignored[name] = nil
        end
    end
end

-- very important function. purges players from the agent list. this is what
-- prevents too many tracked players from stacking up for any given agent.
-- an agent must resend its tracked players if it wants them to remain valid.
function StalkerData:PurgeExpiredAgents(expired)
    local now = time()
    -- name is a tracked player. agents are the people tracking him
    for name, agents in pairs(db.agents) do
        local count = 0
        for agent, last in pairs(agents) do
            count = count + 1
            if (now - last) > expired then
                db.agents[name][agent] = nil
                count = count - 1
                Stalker:debug("agent", 2, "StalkerData:PurgeExpiredAgents()", name, agent)
            end
        end
        if count == 0 then
            db.agents[name] = releaseTable(db.agents[name])
        end
    end
end


---
--- SORT FUNCTIONS
---

do -- StalkerData:SortPlayersByLast()

    local function sorter(a, b)
        return a.last > b.last
    end

    function StalkerData:SortPlayersByLast()
        local cache = cache.units.players.last.data

        local i = 1
        for _, unit in pairs(db.units.players) do
            cache[i] = unit
            i = i + 1
        end

        for j = i, #cache do cache[j] = nil end

        table.sort(cache, sorter)
    end

end

do -- StalkerData:SortGuildsByLast()

    local function sorter(a, b)
        return a.last > b.last
    end

    function StalkerData:SortGuildsByLast()
        local cache = cache.units.guilds.last.data

        local i = 1
        for _, unit in pairs(db.units.guilds) do
            cache[i] = unit
            i = i + 1
        end

        for j = i, #cache do cache[j] = nil end

        table.sort(cache, sorter)
    end

end

do -- StalkerData:SortGuildsByGuild()

    local function sorter(a, b)
        return a.guild < b.guild
    end

    function StalkerData:SortGuildsByGuild()
        local cache = cache.units.guilds.guild.data

        local i = 1
        for _, unit in pairs(db.units.guilds) do
            cache[i] = unit
            i = i + 1
        end

        for j = i, #cache do cache[j] = nil end

        table.sort(cache, sorter)
    end

end

---
--- CUSTOM ITERATORS
---

do -- StalkerData:GetPlayers()

    local sorters = {
        ["name"] = function (a, b) return (a.name and a.name or "") < (b.name and b.name or "") end,
        ["level"] = function (a, b) return (a.level and (a.level > 0 and a.level or 255) or 0) > (b.level and (b.level > 0 and b.level or 255) or 0) end,
        ["class"] = function (a, b) return (a.class and a.class or 0) < (b.class and b.class or 0) end,
        ["guild"] = function (a, b) return (a.guild and a.guild or "zzzzzz") < (b.guild and b.guild or "zzzzzz") end,
        ["kills"] = function (a, b) return (a.kills and a.kills or 0) > (b.kills and b.kills or 0) end,
        ["deaths"] = function (a, b) return (a.deaths and a.deaths or 0) > (b.deaths and b.deaths or 0) end,
        ["last"] = function (a, b) return (a.last and a.last or 0) > (b.last and b.last or 0) end,
    }

    local function sort(sortBy)
        local cache = cache.units.players[sortBy].data

        local i = 1
        for _, unit in pairs(db.units.players) do
            cache[i] = unit
            i = i + 1
        end

        for j = i, #cache do cache[j] = nil end

        table.sort(cache, sorters[sortBy])
    end

    local function iterator(data, index)
        index = index + 1

        if data[index] then
            return index, data[index], db.session.players[data[index]]
        else
            return
        end
    end

    function StalkerData:GetPlayers(sortBy)
        if not sortBy then sortBy = "last" end
        sort(sortBy)
        return iterator, cache.units.players[sortBy].data, 0
    end

end

do -- StalkerData:GetGuilds()

    local sorters = {
        ["guild"] = function (a, b) return (a.guild and a.guild or "zzzzzz") < (b.guild and b.guild or "zzzzzz") end,
        ["kills"] = function (a, b) return (a.kills and a.kills or 0) > (b.kills and b.kills or 0) end,
        ["deaths"] = function (a, b) return (a.deaths and a.deaths or 0) > (b.deaths and b.deaths or 0) end,
        ["last"] = function (a, b) return (a.last and a.last or 0) > (b.last and b.last or 0) end,
    }

    local function sort(sortBy)
        local cache = cache.units.guilds[sortBy].data

        local i = 1
        for _, unit in pairs(db.units.guilds) do
            cache[i] = unit
            i = i + 1
        end

        for j = i, #cache do cache[j] = nil end

        table.sort(cache, sorters[sortBy])
    end

    local function iterator(data, index)
        index = index + 1

        if data[index] then
            return index, data[index], db.session.guilds[data[index]]
        else
            return
        end
    end

    function StalkerData:GetGuilds(sortBy)
        if not sortBy then sortBy = "last" end
        sort(sortBy)
        return iterator, cache.units.guilds[sortBy].data, 0
    end

end

do -- StalkerData:GetTrackedUnits()

    local function iterator(data, index)
        local name, unit = next(data, index)

        while unit and (not db.session.players[unit].track) do
            name, unit = next(data, name)
        end
            
        if unit then
            return name, unit, db.session.players[unit]
        else
            return
        end
    end

    function StalkerData:GetTrackedUnits()
        return iterator, db.units.players
    end

end

function StalkerData:ResetDb()
    StalkerViewer:Hide()
    StalkerMonitor:Hide()
    db.units.players = {}
    db.units.guilds = {}
    StalkerMonitor:ClearDisplay()
end
