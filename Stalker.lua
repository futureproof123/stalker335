Stalker = LibStub("AceAddon-3.0"):NewAddon("Stalker", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("Stalker", true)

Stalker.version = "1.0"
Stalker.revision = tonumber("28")
--Stalker.revision = tonumber("1")

local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")
local Astrolabe = DongleStub("Astrolabe-0.4")

local Data
local Config
local Alerts
local Agent
local Monitor
local Viewer
local bor = bit.bor
local band = bit.band
local time = time
local UnitIsPlayer = UnitIsPlayer
local UnitIsFriend = UnitIsFriend
local UnitName = UnitName
local UnitGUID = UnitGUID
local UnitLevel = UnitLevel
local UnitClass = UnitClass
local GetGuildInfo = GetGuildInfo

-- will be a pointer to StalkerData's locally scoped db
local db

-- activity within this time concidered same encounter
STALKER_ENCOUNTER = 60
local STALKER_ENCOUNTER = STALKER_ENCOUNTER

-- the limit on number of tracked players
STALKER_TRACKED_LIMIT = 20
local STALKER_TRACKED_LIMIT = STALKER_TRACKED_LIMIT

-- stalker unit struct types
STALKER_PLAYER = 1
STALKER_PET = 2
STALKER_GUILD = 3
local STALKER_PLAYER = STALKER_PLAYER
local STALKER_PET = STALKER_PET
local STALKER_GUILD = STALKER_GUILD

-- stalker player types
STALKER_ME = nil -- i know. this just makes code easier to read

-- combatlog event types
STALKER_COMBAT_HOSTILE = bor(COMBATLOG_OBJECT_REACTION_HOSTILE, COMBATLOG_OBJECT_CONTROL_PLAYER)
STALKER_COMBAT_HOSTILE_PLAYER = bor(STALKER_COMBAT_HOSTILE, COMBATLOG_OBJECT_TYPE_PLAYER)
STALKER_COMBAT_HOSTILE_PET = bor(STALKER_COMBAT_HOSTILE, COMBATLOG_OBJECT_TYPE_PET)
STALKER_COMBAT_HOSTILE_GUARDIAN = bor(STALKER_COMBAT_HOSTILE, COMBATLOG_OBJECT_TYPE_GUARDIAN)
STALKER_COMBAT_FRIENDLY = bor(COMBATLOG_OBJECT_REACTION_FRIENDLY, COMBATLOG_OBJECT_CONTROL_PLAYER)
STALKER_COMBAT_FRIENDLY_PLAYER = bor(STALKER_COMBAT_FRIENDLY, COMBATLOG_OBJECT_TYPE_PLAYER)
STALKER_COMBAT_FRIENDLY_PET = bor(STALKER_COMBAT_FRIENDLY, COMBATLOG_OBJECT_TYPE_PET)
STALKER_COMBAT_ME = bor(COMBATLOG_OBJECT_AFFILIATION_MINE, STALKER_COMBAT_FRIENDLY_PLAYER)
local STALKER_COMBAT_HOSTILE = STALKER_COMBAT_HOSTILE
local STALKER_COMBAT_HOSTILE_PLAYER = STALKER_COMBAT_HOSTILE_PLAYER
local STALKER_COMBAT_HOSTILE_PET = STALKER_COMBAT_HOSTILE_PET
local STALKER_COMBAT_HOSTILE_GUARDIAN = STALKER_COMBAT_HOSTILE_GUARDIAN
local STALKER_COMBAT_FRIENDLY = STALKER_COMBAT_FRIENDLY
local STALKER_COMBAT_FRIENDLY_PLAYER = STALKER_COMBAT_FRIENDLY_PLAYER
local STALKER_COMBAT_FRIENDLY_PET = STALKER_COMBAT_FRIENDLY_PET
local STALKER_COMBAT_ME = STALKER_COMBAT_ME

local STALKER_COMBATLOG_COMBAT = 1 -- combatlog events we record hostile unit info about
local STALKER_COMBATLOG_DEATH = 2 -- combatlog events we process as death events

local STALKER_COMBATLOG_MELEE = 1 -- combatlog event type
local STALKER_COMBATLOG_SPELL = 2 -- combatlog spell type
local STALKER_COMBATLOG_OTHER = 3 -- combatlog other types

-- for combatlog event lookups
-- index 1 = stalker event type
-- index 2 = stalker spell type
-- index 3 = whether this event should overwrite current spell displayed in the Stalker Monitor
local STALKER_COMBATLOG_TYPES = {
    ["SWING_DAMAGE"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_MELEE, true},
    ["SWING_MISSED"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_MELEE, true},
    ["RANGE_DAMAGE"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["RANGE_MISSED"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_CAST_START"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_CAST_SUCCESS"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_CAST_FAILED"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_MISSED"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_DAMAGE"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_HEAL"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_ENERGIZE"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_DRAIN"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_LEECH"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_SUMMON"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_RESURRECT"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_CREATE"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_INSTAKILL"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_INTERRUPT"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_EXTRA_ATTACKS"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, false},
    ["SPELL_DURABILITY_DAMAGE"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, false},
    ["SPELL_DURABILITY_DAMAGE_ALL"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, false},
    ["SPELL_AURA_APPLIED"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_AURA_APPLIED_DOSE"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, false},
    ["SPELL_AURA_REMOVED"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_AURA_REMOVED_DOSE"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, false},
    ["SPELL_AURA_BROKEN"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_AURA_BROKEN_SPELL"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_AURA_REFRESH"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_DISPEL"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_STOLEN"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true},
    ["SPELL_PERIODIC_MISSED"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, false},
    ["SPELL_PERIODIC_DAMAGE"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, false},
    ["SPELL_PERIODIC_HEAL"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, false},
    ["SPELL_PERIODIC_ENERGIZE"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, false},
    ["SPELL_PERIODIC_DRAIN"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, false},
    ["SPELL_PERIODIC_LEECH"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, false},
    ["SPELL_DISPEL_FAILED"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, false},
    ["ENVIRONMENTAL"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_OTHER, false},
    ["PET_CAST"] = {STALKER_COMBATLOG_COMBAT, STALKER_COMBATLOG_SPELL, true}, -- our own addition. all pet spells are converted to this
    ["UNIT_DIED"] = {STALKER_COMBATLOG_DEATH},
}

-- for spell lookups
local STALKER_PLAYER_SPELLS = _G["STALKER_PLAYER_SPELLS"]
local STALKER_PET_SPELLS = _G["STALKER_PET_SPELLS"]

STALKER_LOCATION_WORLD = 1
STALKER_LOCATION_PVP = 2
STALKER_LOCATION_INSTANCE = 3
STALKER_LOCATION_SANCTUARY = 4
STALKER_LOCATION_COMBAT = 5 -- like wintergrasp
local STALKER_LOCATION_WORLD = STALKER_LOCATION_WORLD
local STALKER_LOCATION_PVP = STALKER_LOCATION_PVP
local STALKER_LOCATION_INSTANCE = STALKER_LOCATION_INSTANCE
local STALKER_LOCATION_SANCTUARY = STALKER_LOCATION_SANCTUARY
local STALKER_LOCATION_COMBAT = STALKER_LOCATION_COMBAT

STALKER_TT_IGNORE = "\001"
local STALKER_TT_IGNORE = STALKER_TT_IGNORE

-- Localization strings for xml
STALKER_L_MONITOR = "Stalker "..L["Monitor"]
STALKER_L_VIEWER = "Stalker "..L["Viewer"]
STALKER_L_FLAGS = L["Flags"]
STALKER_L_LAST = L["Last"]
STALKER_L_SOURCE = L["Source"]
STALKER_L_FILTER = FILTER..":"
STALKER_L_SHOWONLY = L["Show Only"]..":"
STALKER_L_GUILDS = L["Guilds"]


function Stalker:OnInitialize()
    Data = StalkerData
    Alerts = StalkerAlerts
    Agent = StalkerAgent
    Config = StalkerConfig
    Monitor = StalkerMonitor
    Viewer = StalkerViewer

    self.debugcats = {}
    self.debugging = false

    Config:Initialize()

    self:RegisterChatCommand("stalker", "ChatCommand")

    -- create a launcher dataobject. this is used by LDBIcon to create a
    -- minimap icon
    local launcher = LDB:NewDataObject("Stalker", {
        type = "launcher",
        icon = "Interface\\AddOns\\Stalker\\Images\\Stalker",
        OnClick = function(self, button)
            GameTooltip:Hide()
            if button == "RightButton" and IsShiftKeyDown() then
                Stalker:ShowMinimapDropdown(self)
            elseif button == "LeftButton" then
                Monitor:Toggle()
            elseif button == "RightButton" then
                Viewer:Toggle()
            end
        end,
        OnTooltipShow = function(tooltip)
            CloseDropDownMenus(1)
            tooltip:AddLine("|cffee0000Stalker|r |cffffffff".. Stalker.version.."."..Stalker.revision.."|r")
            if Stalker:IsEnabled() then
                tooltip:AddLine(L["|cffffff00Left Click|r |cffffffffto toggle Stalker Monitor|r"])
                tooltip:AddLine(L["|cffffff00Right Click|r |cffffffffto toggle Stalker Viewer|r"])
            end
            tooltip:AddLine(L["|cffffff00Shift-Right Click|r |cffffffffto open menu|r"])
        end,
    })

    LDBIcon:Register("Stalker", launcher, Config:GetOption("profile", "general.minimapicon"))

    Config:RegisterForUpdates("profile", "general.enabled", function(v) Stalker:OnEnabledUpdate(v) end)
    Config:RegisterForUpdates("profile", "general.agent.enabled", function(v) Stalker:OnAgentEnabledUpdate(v) end)
    Config:RegisterForUpdates("profile", "general.minimapicon.hide", function(v) Stalker:OnEnableMinimapButtonUpdate(v) end)
    Config:RegisterForUpdates("profile", "general.disableSanctuaries", function(v) Stalker:OnDisableSanctuaryUpdate(v) end)
    Config:RegisterForUpdates("profile", "general.disableCombatZone", function(v) Stalker:OnDisableCombatUpdate(v) end)

    self.player = {
        name = UnitName("player"),
        playerFaction = (UnitFactionGroup("player") == "Alliance" and FACTION_ALLIANCE or FACTION_HORDE),
        hostileFaction = (UnitFactionGroup("player") == "Alliance" and FACTION_HORDE or FACTION_ALLIANCE)
    }

    self.listening = false
    self.initialized = false
end

function Stalker:OnEnable()
    if Config:GetOption("profile", "general.enabled") then
        self:UpdateZoneType()
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("ZONE_CHANGED", "ZoneChanged")
        self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "ZoneChanged")
        self:RegisterEvent("ZONE_CHANGED_INDOORS", "ZoneChanged")
        self:ScheduleRepeatingTimer("Refresh", 1)
        self:ScheduleRepeatingTimer("PurgeExpiredData", 60)
        self:ScheduleTimer(function() Stalker.initialized = true end, 5)
    else
        self:Disable()
    end
end

function Stalker:OnDisable()
    self:UnregisterAllEvents()
    self:CancelAllTimers()
    self.listening = false
    self.initialized = false
end

-- recieves pointer to StalkerData db
function Stalker:SetDataDb(val)
    db = val
end

function Stalker:ChatCommand(input)
    LibStub("AceConfigCmd-3.0").HandleCommand(Stalker, "stalker", "Stalker", input)
end

function Stalker:Refresh()
    self:UpdateUnit("target")
end

function Stalker:PurgeExpiredData()
    Data:PurgeExpiredData()
end


---
--- ADDON CONFIG CHANGES
---

function Stalker:OnEnabledUpdate(value)
   if value then self:Enable() else self:Disable() end 
end

function Stalker:OnEnableMinimapButtonUpdate(value)
    if self:IsEnabled() then
        if value then LDBIcon:Hide("Stalker") else LDBIcon:Show("Stalker") end
    end
end

function Stalker:OnAgentEnabledUpdate(enabled)
    if enabled then
        Agent:Enable()
    else
        Agent:Disable()
    end

    Alerts:Print(L["Agent was ACTION"](enabled))
end

function Stalker:OnDisableSanctuaryUpdate()
    self:UpdateZoneType()
end

function Stalker:OnDisableCombatUpdate()
    self:UpdateZoneType()
end

function Stalker:OnDebugOptionUpdate(v)
    if not v or v == "" then
        self.debugcats = {}
        self.debugging = false
        self:Print("Debugging turned off")
    else
        local cat, lvl = strsplit(" ", v)
        self.debugcats[cat] = tonumber(lvl)
        self.debugging = true
        self:Print("Debugging turned on")
    end
end


--
-- EVENT FUNCTIONS
--

function Stalker:ZoneChanged()
    self:UpdateZoneType()
end

function Stalker:COMBAT_LOG_EVENT_UNFILTERED(_, last, eventName, srcGuid, srcName, srcFlags, dstGuid, dstName, dstFlags, spellId, spellName)
    if (not self.listening) or (not self.initialized) then return end

    -- if this is a supported event
    if STALKER_COMBATLOG_TYPES[eventName] then
        -- only used when testing in bgs
        if srcName then srcName, srcRealm = strsplit("-", srcName) end
        if dstName then dstName, dstRealm = strsplit("-", dstName) end

        local now = time()

        -- if this event involves a hostile (player controlled) unit and is a supported event type
        if (srcFlags and (band(srcFlags, STALKER_COMBAT_HOSTILE) == STALKER_COMBAT_HOSTILE)) or (dstFlags and (band(dstFlags, STALKER_COMBAT_HOSTILE) == STALKER_COMBAT_HOSTILE)) and (STALKER_COMBATLOG_TYPES[eventName][1] == STALKER_COMBATLOG_COMBAT) then
            local name, guid, level, class, unit, session

            -- event generated by hostile player source
            if band(srcFlags, STALKER_COMBAT_HOSTILE_PLAYER) == STALKER_COMBAT_HOSTILE_PLAYER then
                name = srcName
                guid = srcGuid

                -- guess class and level based on spell used
                local spell = STALKER_PLAYER_SPELLS[spellId]
                level = (spell and spell[2])
                class = (spell and spell[1])

            -- event generated by hostile pet source
            elseif (band(srcFlags, STALKER_COMBAT_HOSTILE_PET) == STALKER_COMBAT_HOSTILE_PET) or (band(srcFlags, STALKER_COMBAT_HOSTILE_GUARDIAN) == STALKER_COMBAT_HOSTILE_GUARDIAN) then
                -- attempt to get the pet owners name from a custom tooltip
                owner = db.tooltips.pets[srcGuid]
                if (not owner) or (owner.name == STALKER_TT_IGNORE) then return end
                name = owner.name

                -- guess owner class and level based on pet spell used
                local spell = STALKER_PET_SPELLS[spellId]
                level = (spell and spell[2])
                class = (spell and spell[1])

                -- change spell name to a general one
                spellName = ((band(dstFlags, STALKER_COMBAT_FRIENDLY) == STALKER_COMBAT_FRIENDLY) and "Pet Attack" or "Pet Spell")
                eventName = "PET_CAST"

            -- event generated by hostile player being the target of something
            elseif band(dstFlags, STALKER_COMBAT_HOSTILE_PLAYER) == STALKER_COMBAT_HOSTILE_PLAYER then
                name = dstName
                guid = dstGuid

            -- event generated by hostile pet being the target of something
            elseif (band(dstFlags, STALKER_COMBAT_HOSTILE_PET) == STALKER_COMBAT_HOSTILE_PET) or (band(dstFlags, STALKER_COMBAT_HOSTILE_GUARDIAN) == STALKER_COMBAT_HOSTILE_GUARDIAN) then
                -- attempt to get the pet owners name from a custom tooltip
                owner = db.tooltips.pets[dstGuid]
                if (not owner) or (owner.name == STALKER_TT_IGNORE) then return end
                name = owner.name
            else
                return
            end

            -- make sure this isnt someone we should ignore, like a dueled player
            if db.ignored[name] then return end

            -- attempt to get the unit record for this player
            unit = Data:GetPlayer(name)

            if unit then
                session = Data:GetUnitSession(unit)

                -- when players die they may still have dots up on players. we need
                -- to ensure those events dont mark them alive prematurely. so after
                -- death events for this player are blocked from marking them alive
                -- for 2 seconds, after that only non-periodic spells can mark them
                -- alive again. this probably needs tweaking.
                if session.dead and (session.dead < (now - 2)) and (eventName ~= "SPELL_PERIODIC_DAMAGE") then
                    session.dead = nil
                end
            end

            unit, session = self:ProcessHostileEvent(unit, session, STALKER_ME, name, guid, level, class)

            -- if a hostile sourced attack then update their session
            if band(srcFlags, STALKER_COMBAT_HOSTILE) == STALKER_COMBAT_HOSTILE then
                -- save data for Stalker Monitor display
                session.targetName = dstName
                session.targetFlags = dstFlags

                -- if target is friendly set last pvp time. used in Stalker Monitor to
                -- flag pvp'ers
                if band(dstFlags, STALKER_COMBAT_FRIENDLY) == STALKER_COMBAT_FRIENDLY then
                    Data:LogPvp(unit)
                end

                -- if target was me log the pvp event so we can track kills/deaths
                if band(dstFlags, STALKER_COMBAT_ME) == STALKER_COMBAT_ME then
                    Data:LogIncomingPvp(unit)
                end

                -- give swing attacks a better spell name
                if STALKER_COMBATLOG_TYPES[eventName][2] == STALKER_COMBATLOG_MELEE then spellName = "Melee" end

                -- only change current spell if its marked as true in STALKER_COMBATLOG_TYPES,
                -- or there is no current spell set
                if spellName and (STALKER_COMBATLOG_TYPES[eventName][3] or (not session.spell)) then
                    session.spell = spellName
                end


            -- if a friendly attacking a hostile player log pvp info            
            elseif (band(srcFlags, STALKER_COMBAT_FRIENDLY) == STALKER_COMBAT_FRIENDLY) and (band(dstFlags, STALKER_COMBAT_HOSTILE_PLAYER) == STALKER_COMBAT_HOSTILE_PLAYER) then
                Data:LogPvp(unit)

                -- if I attacked hostile player tag them as attacked by me so
                -- we can track kills/deaths
                if band(srcFlags, STALKER_COMBAT_ME) == STALKER_COMBAT_ME then
                    Data:LogOutgoingPvp(unit)
                end

            end

            self:NotifyModules(unit)

        -- process death events
        elseif eventName == "UNIT_DIED" then
            -- hostile player died. check to see if I have attacked them recently.
            if (band(dstFlags, STALKER_COMBAT_HOSTILE_PLAYER) == STALKER_COMBAT_HOSTILE_PLAYER) and (not db.ignored[dstName]) then
                local unit, session = self:ProcessHostileEvent(nil, nil, STALKER_ME, dstName, dstGuid)
                Data:LogHostilePvpDeath(unit, session) -- woot
                self:NotifyModules(unit)

            -- I died, check to see if others have attacked me recently
            elseif band(dstFlags, STALKER_COMBAT_ME) == STALKER_COMBAT_ME then
                Data:LogMyPvpDeath() -- boo
            end
        end
    end
end

function Stalker:PLAYER_TARGET_CHANGED()
    Stalker:UpdateUnit("target")
end

function Stalker:UPDATE_MOUSEOVER_UNIT()
    Stalker:UpdateUnit("mouseover")
end

-- process moused over and targeted hostiles
function Stalker:UpdateUnit(unitId)
    if (not self.listening) or (not self.initialized) then return end
    if not UnitIsPlayer(unitId) then return end

    local name = UnitName(unitId)

    -- if this is a friendly add them to the ignore list so they dont get
    -- flagged as a hostile while dueling.
    if UnitIsFriend("player", unitId) then
        db.ignored[name] = time()
    else
        if db.ignored[name] then return end

        local guid = UnitGUID(unitId)
        if not guid then return end

        -- NOTE about level. We use bit 8 of integer var 'level' to indicate if the
        -- level is definitively know or not. for combat events we are only guessing
        -- the level based on the spell cast. Here we know what level they are
        -- since we targeted (or moused over them). Turning on bit 8 also has the
        -- advantage of making a known level higher than its guessed counterpart,
        -- which allows ProcessHostileEvent() below to compare which one takes
        -- precedence.
        local level = UnitLevel(unitId)
        level = (level > 0 and bor(level, 0x80) or 0)
        
        local class = Data:GetClassId(UnitClass(unitId))
        local guild = GetGuildInfo(unitId) or ""
        local unit, session

        -- we update the death status of the player since we know it definitively
        unit = Data:GetPlayer(name)
        if unit then
            session = Data:GetUnitSession(unit)
            session.dead = (UnitIsDeadOrGhost(unitId) and (session.dead and session.dead or time()))
        end

        local unit = self:ProcessHostileEvent(unit, session, STALKER_ME, name, guid, level, class, guild)
        self:NotifyModules(unit)
    end
end

function Stalker:ProcessHostileEvent(unit, session, source, name, guid, level, class, guild, C, Z, X, Y)
    local now = time()

    if not unit then
        unit = Data:GetPlayer(name)
    end

    -- if location wasnt provided then we default to our current position.
    -- Stalker agents (other addon users) could provide their own position
    -- in the event call.
    if not (C and Z and X and Y) then C, Z, X, Y = self:GetCurrentLocation() end

    -- trim guid down to min size
    guid = guid and guid:sub(guid:find("[^0Xx]"), -1)

    -- if unit already exsists update info
    if unit then

        -- get the session for storing temp data about unit
        if not session then
            session = Data:GetUnitSession(unit)
        end

        if (not unit.guid) and guid then
            unit.guid = guid
        end

        -- in the combat event function above we used spell detection to
        -- determine a minimum level of the player. here we only record their
        -- level if its greater than the one already known.
        if level and ((not unit.level) or (level > unit.level)) then
            unit.level = level
        end

        if class and not unit.class then
            unit.class = class
        end

        if guild and (unit.guild ~= guild) then
            unit.guild = guild
        end

        unit.locC = C
        unit.locZ = Z
        unit.locX = X
        unit.locY = Y

        -- unit.source = who generated this event. other Stalker agents (other
        -- addon users) can also be the source of events
        unit.source = source

        -- unit.last = timestamp indicating when we last saw this unit
        -- session.last = the time is seconds since the last event
        session.last = now - unit.last
        unit.last = now

    -- first time we have seen this unit so create a new one
    else
        unit = {
            type = STALKER_PLAYER,
            name = name,
            guid = guid,
            level = level,
            class = class,
            guild = guild,
            last = now,
            locC = C,
            locZ = Z,
            locX = X,
            locY = Y,
            source = source,
        }

        Data:AddPlayer(unit)

        -- create a new session for unit. this keeps track of data we dont want
        -- stored permanently in the db.
        session = Data:GetUnitSession(unit)
        session.last = now
    end

    -- record guild event
    if unit.guild and unit.guild ~= "" then
        self:ProcessGuildEvent(unit)
    end

    return unit, session
end

function Stalker:ProcessGuildEvent(unit)
    local now = time()

    local guild = Data:GetGuild(unit.guild)

    if guild then
        local session = Data:GetUnitSession(guild)

        session.last = now - guild.last
        guild.last = (unit.last or now)
    else
        guild = {
            type = STALKER_GUILD,
            guild = unit.guild,
            last = (unit.last or now),
        }

        Data:AddGuild(guild)

        local session = Data:GetUnitSession(guild)
        session.last = (guild.last and (now - guild.last) or now)
    end

    return guild
end

function Stalker:NotifyModules(unit)
    Monitor:OnNewEvent(unit)
    Viewer:OnNewEvent(unit)
    Alerts:SendAlerts(unit)
    Agent:SendAlerts(unit)
end


--
-- LOCATION FUNCTIONS
--

do -- Stalker:UpdateZoneType()
    local type = {
        ["none"] = STALKER_LOCATION_WORLD,
        ["pvp"] = STALKER_LOCATION_PVP,
        ["arena"] = STALKER_LOCATION_PVP,
        ["party"] = STALKER_LOCATION_INSTANCE,
        ["raid"] = STALKER_LOCATION_INSTANCE,
        ["sanctuary"] = STALKER_LOCATION_SANCTUARY,
        ["combat"] = STALKER_LOCATION_COMBAT,
    }

    function Stalker:UpdateZoneType()
        local inInstance, instanceType = IsInInstance()
        local pvpType = GetZonePVPInfo()

        if pvpType == "sanctuary" then instanceType = "sanctuary" end
        if pvpType == "combat" then instanceType = "combat" end

        -- uncomment to test in battlegrounds
        --if instanceType == "pvp" then inInstance = nil instanceType = "none" end

        self.location = type[instanceType]

        if inInstance or
            ((self.location == STALKER_LOCATION_SANCTUARY) and Config:GetOption("profile", "general.disableSanctuaries")) or
            ((self.location == STALKER_LOCATION_COMBAT) and Config:GetOption("profile", "general.disableCombatZone"))
        then 
            self.listening = false
        else
            self.listening = true
        end
    end
end

-- get distance from your current location to unit
function Stalker:GetDistance(unit)
    if (not self:UnitHasValidLocation(unit)) then return end
    local c, z, x, y = self:GetCurrentLocation()
    if (not (c and z and x and y)) or (c <= 0) or (z <= 0) then return end
    return Astrolabe:ComputeDistance(c, z, x, y, unit.locC, unit.locZ, unit.locX, unit.locY)
end

do -- Stalker:GetCurrentLocation()
    local function round(n, p)
        local m = 10^(p or 0)
        return math.floor(n * m + 0.5) / m
    end

    function Stalker:GetCurrentLocation()
        local c, z, x, y = Astrolabe:GetCurrentPlayerPosition()
        -- round to 5 places to save storage
        return c, z, (x and round(x, 5)), (y and round(y, 5))
    end
end

function Stalker:UnitHasValidLocation(unit)
    return (unit.locC and unit.locZ and unit.locX and unit.locY and (unit.locC > 0) and (unit.locZ > 0)) and true
end

--
-- KOS PLAYER DIALOG
--
do
    local function OnOkClick()
        StalkerDialogFrame.OnOkClick = nil

        local name = StalkerDialogFrameEditbox:GetText()
        if not name then return end
        name = strtrim(name)
        if name == "" then return end
        name = name:sub(1, 1):upper()..name:sub(2):lower()

        local player = Data:GetPlayer(name)
        if player then
            Data:SetPlayerKos(player, true)
        else
            unit = {
                type = STALKER_PLAYER,
                name = name,
                last = 0,
                kos = 1,
                source = STALKER_ME,
            }

            Data:AddPlayer(unit)
            Viewer:Recalulate()
        end

        Alerts:Print(L["Player NAME was ACTION your KOS List"](Stalker:FormatName(name, true, true), true))
    end

    function Stalker:ShowAddKosPlayerDialog()
        StalkerDialogFrameTitle:SetText("Stalker - "..L["Add KOS Player"])
        StalkerDialogFrameText:SetText(L["Enter player name to add to KOS list"]..":")
        StalkerDialogFrameEditbox:SetMaxLetters(12)
        StalkerDialogFrame.OnOkClick = OnOkClick
        StalkerDialogFrame:Show()
        CloseDropDownMenus(1)
    end
end

--
-- KOS GUILD DIALOG
--
do
    local function OnOkClick()
        StalkerDialogFrame.OnOkClick = nil

        local name = StalkerDialogFrameEditbox:GetText()
        name = strtrim(name)
        if not name or name == "" then return end

        local guild = Data:GetGuild(name)
        if guild then
            Data:SetGuildKos(guild, true)
        else
            guild = {
                type = STALKER_GUILD,
                guild = name,
                last = 0,
                kos = 1,
            }

            Data:AddGuild(guild)
            Viewer:Recalulate()
        end

        Alerts:Print(L["Guild NAME was ACTION your KOS List"](Stalker:FormatName(guild.guild, true, true), true))
    end

    function Stalker:ShowAddKosGuildDialog()
        StalkerDialogFrameTitle:SetText("Stalker - "..L["Add KOS Guild"])
        StalkerDialogFrameText:SetText(L["Enter guild name to add to KOS list"]..":")
        StalkerDialogFrameEditbox:SetMaxLetters(24)
        StalkerDialogFrame.OnOkClick = OnOkClick
        StalkerDialogFrame:Show()
        CloseDropDownMenus(1)
    end
end

---
--- ADD NOTE DIALOG
--
do
    local function OnOkClick(unit)
        StalkerDialogFrame.OnOkClick = nil
        local text = StalkerDialogFrameEditbox:GetText()
        text = text:gsub("^[%s%c]+", ""):gsub("[%s%c]+$", "")
        Data:SetUnitNote(unit, text)
        Viewer:Refresh()
    end

    function Stalker:ShowSetNoteDialog(unit)
        StalkerDialogFrameTitle:SetText("Stalker - "..L["Set Note"])
        StalkerDialogFrameText:SetText(L["Enter note"]..":")
        StalkerDialogFrameEditbox:SetText(unit.note or "")
        StalkerDialogFrameEditbox:SetMaxLetters(255)
        StalkerDialogFrame.OnOkClick = function() OnOkClick(unit) end
        StalkerDialogFrame:Show()
    end
end

---
--- WHISPER POSITION DIALOG
--
do
    local function OnOkClick(unit)
        StalkerDialogFrame.OnOkClick = nil
        local text = StalkerDialogFrameEditbox:GetText()
        text = text:gsub("^[%s%c]+", ""):gsub("[%s%c]+$", "")
        Alerts:SendPosition(unit, "WHISPER", text)
    end

    function Stalker:ShowWhisperPositionDialog(unit)
        StalkerDialogFrameTitle:SetText("Stalker - "..L["Whisper Player Position"])
        StalkerDialogFrameText:SetText(L["Enter player name to whisper"]..":")
        StalkerDialogFrameEditbox:SetText("")
        StalkerDialogFrameEditbox:SetMaxLetters(12)
        StalkerDialogFrame.OnOkClick = function() OnOkClick(unit) end
        StalkerDialogFrame:Show()
    end
end

--
-- MINIMAP ICON MENU
--
do
    local function createDropdown()
        local info

        if UIDROPDOWNMENU_MENU_LEVEL == 1 then
            if Config:GetOption("profile", "general.enabled") then
                info = UIDropDownMenu_CreateInfo()
                info.text = L["KOS"]
                info.hasArrow = true
                info.value = "kos"
                UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

                info = UIDropDownMenu_CreateInfo()
                info.text = L["Alerts"]
                info.hasArrow = true
                info.value = "alerts"
                UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
            end

            info = UIDropDownMenu_CreateInfo()
            info.text = L["Open Options Panel"]
            info.func = function() Stalker:ShowOptionsPanel() end
            info.checked = false
            UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

        elseif UIDROPDOWNMENU_MENU_LEVEL == 2 then
            if UIDROPDOWNMENU_MENU_VALUE == "kos" then
                info = UIDropDownMenu_CreateInfo()
                info.text = L["Add KOS Player"]
                info.func = function() Stalker:ShowAddKosPlayerDialog() end
                info.checked = false
                UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

                info = UIDropDownMenu_CreateInfo()
                info.text = L["Add KOS Guild"]
                info.func = function() Stalker:ShowAddKosGuildDialog() end
                info.checked = false
                UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

            elseif UIDROPDOWNMENU_MENU_VALUE == "alerts" then
                info = UIDropDownMenu_CreateInfo()
                info.text = L["Enable Hostile Alerting"]
                info.func = function() Stalker:ToggleHostileAlerts() end
                info.checked = Config:GetOption("profile", "alerts.hostile.enabled")
                UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

                info = UIDropDownMenu_CreateInfo()
                info.text = L["Enable KOS Alerting"]
                info.func = function() Stalker:ToggleKosAlerts() end
                info.checked = Config:GetOption("profile", "alerts.kos.enabled")
                UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

                info = UIDropDownMenu_CreateInfo()
                info.text = L["Enable Tracked Alerting"]
                info.func = function() Stalker:ToggleTrackedAlerts() end
                info.checked = Config:GetOption("profile", "alerts.tracked.enabled")
                UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
            end
        end
    end

    function Stalker:ShowOptionsPanel()
        InterfaceOptionsFrame_OpenToCategory(Config.BlizOptionsGeneral)
        InterfaceOptionsFrame_OpenToCategory(Config.BlizOptions)
        CloseDropDownMenus(1)
    end

    function Stalker:ShowMinimapDropdown(frame)
        CloseDropDownMenus(1)
        UIDropDownMenu_Initialize(StalkerDropDownMenu, createDropdown, "MENU")
        UIDropDownMenu_SetAnchor(StalkerDropDownMenu, 0, 0, "TOPRIGHT", frame, "TOPLEFT")
        ToggleDropDownMenu(1, nil, StalkerDropDownMenu)    
    end

    function Stalker:ToggleHostileAlerts()
        Config:SetOption("profile", "alerts.hostile.enabled", not Config:GetOption("profile", "alerts.hostile.enabled"))
        CloseDropDownMenus(1)
    end

    function Stalker:ToggleKosAlerts()
        Config:SetOption("profile", "alerts.kos.enabled", not Config:GetOption("profile", "alerts.kos.enabled"))
        CloseDropDownMenus(1)
    end

    function Stalker:ToggleTrackedAlerts()
        Config:SetOption("profile", "alerts.tracked.enabled", not Config:GetOption("profile", "alerts.tracked.enabled"))
        CloseDropDownMenus(1)
    end
end


--
-- COMMON UNIT DROPDOWN
--
do
    local function createDropdown(node)
        local info

        local unit = node.unit
        local session = Data:GetUnitSession(unit)

        if UIDROPDOWNMENU_MENU_LEVEL == 1 then
            info = UIDropDownMenu_CreateInfo()
            info.isTitle = true
            info.text = (unit.type == STALKER_PLAYER and unit.name or unit.guild)
            info.checked = false
            UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

            if unit.type == STALKER_PLAYER then
                info = UIDropDownMenu_CreateInfo()
                info.text = L["Track"]
                info.value = unit
                info.func = function() Stalker:ToggleTrack(unit) end
                info.checked = session.track
                info.disabled = (not Agent:IsEnabled()) or (not unit.guid) or (not unit.class) or ((Data:GetTrackedPlayerCount() >= STALKER_TRACKED_LIMIT) and (not session.track))
                UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

                info = UIDropDownMenu_CreateInfo()
                info.text = L["KOS Player"]
                info.value = unit
                info.func = function() Stalker:TogglePlayerKos(unit) end
                info.checked = unit.kos
                UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
            end

            info = UIDropDownMenu_CreateInfo()
            info.text = L["KOS Guild"]
            info.value = unit
            info.func = function() Stalker:ToggleGuildKos(unit) end
            info.checked = Data:IsGuildKos(unit)
            info.disabled = (not unit.guild or unit.guild == "")
            UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

            if unit.type == STALKER_PLAYER then
                if (unit.locX and unit.locY) then
                    info = UIDropDownMenu_CreateInfo()
                    info.text = L["Send Alert"]
                    info.hasArrow = true
                    UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

                    info = UIDropDownMenu_CreateInfo()
                    info.text = L["Create Waypoint"]
                    info.value = unit
                    info.func = function() Stalker:CreateWaypoint(unit) end
                    info.checked = false
                    info.disabled = (not Stalker:UnitHasValidLocation(unit))
                    UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
                end
            end

            info = UIDropDownMenu_CreateInfo()
            info.text = L["Set Note"]
            info.value = unit
            info.func = function() Stalker:ShowSetNoteDialog(unit) end
            info.checked = false
            UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

        elseif UIDROPDOWNMENU_MENU_LEVEL == 2 then
            if IsInGuild() then
                info = UIDropDownMenu_CreateInfo()
                info.text = GUILD
                info.value = unit
                info.func = function() Alerts:SendPosition(unit, "GUILD") end
                info.checked = false
                UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
            end

            if GetNumPartyMembers() > 0 then
                info = UIDropDownMenu_CreateInfo()
                info.text = CHAT_MSG_PARTY
                info.value = unit
                info.func = function() Alerts:SendPosition(unit, "PARTY") end
                UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
            end

            if GetNumRaidMembers() > 0 then
                info = UIDropDownMenu_CreateInfo()
                info.text = CHAT_MSG_RAID
                info.value = unit
                info.func = function() Alerts:SendPosition(unit, "RAID") end
                UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
            end

            info = UIDropDownMenu_CreateInfo()
            info.text = CHAT_MSG_WHISPER_INFORM
            info.value = unit
            info.func = function() Stalker:ShowWhisperPositionDialog(unit) end
            info.checked = false
            UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

            info = UIDropDownMenu_CreateInfo()
            info.text = SAY_MESSAGE
            info.value = unit
            info.func = function() Alerts:SendPosition(unit, "SAY") end
            info.checked = false
            UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

            info = UIDropDownMenu_CreateInfo()
            info.text = YELL_MESSAGE
            info.value = unit
            info.func = function() Alerts:SendPosition(unit, "YELL") end
            info.checked = false
            UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
        end

    end

    function Stalker:ShowUnitDropDown(node, button)
        if button ~= "RightButton" then return end

        GameTooltip:Hide()

        StalkerDropDownMenu.unit = node.unit

        local cursor = GetCursorPosition() / UIParent:GetEffectiveScale()
        local center = node:GetLeft() + (node:GetWidth() / 2)

        UIDropDownMenu_Initialize(StalkerDropDownMenu, createDropdown, "MENU")
        UIDropDownMenu_SetAnchor(StalkerDropDownMenu , cursor - center, 0, "TOPRIGHT", node, "TOP")
        CloseDropDownMenus(1)
        ToggleDropDownMenu(1, nil, StalkerDropDownMenu)    
    end

    function Stalker:ToggleTrack(unit)
        local session = Data:GetUnitSession(unit)
        Data:SetPlayerTrack(unit, (not session.track))
        Viewer:Filter()
        Alerts:Print(L["Player NAME being tracked"](Stalker:FormatName(unit.name, true, true), session.track))
        if (Data:GetTrackedPlayerCount() >= STALKER_TRACKED_LIMIT) then
            Alerts:Print(L["The limit on the number of Tracked players has been reached."])
        end
    end

    function Stalker:TogglePlayerKos(unit)
        Data:SetPlayerKos(unit, not unit.kos)
        Viewer:Filter()
        Alerts:Print(L["Player NAME was ACTION your KOS List"](Stalker:FormatName(unit.name, true, true), unit.kos))
    end

    function Stalker:ToggleGuildKos(unit)
        local value = (not Data:IsGuildKos(unit))
        Data:SetGuildKos(unit, value)
        Viewer:Filter()
        Alerts:Print(L["Guild NAME was ACTION your KOS List"](Stalker:FormatName(unit.guild, true, true), value))
    end

    local showWaypointMsg = true
    function Stalker:CreateWaypoint(unit)
        if TomTom then
            if type(TomTom.AddZWaypoint) == "function" then
                if showWaypointMsg then
                    self:Print(L["Creating a waypoint"]("TomTom"))
                end
                TomTom:AddZWaypoint(unit.locC, unit.locZ, unit.locX*100, unit.locY*100, unit.name)
            else
                self:Print(L["Waypoints are not supported"]("TomTom"))
            end

        elseif Cartographer_Waypoints then
            if type(Cartographer_Waypoints.AddLHWaypoint) == "function" then
                if showWaypointMsg then
                    self:Print(L["Creating a waypoint"]("Cartographer"))
                end
                Cartographer_Waypoints:AddLHWaypoint(unit.locC, unit.locZ, unit.locX*100, unit.locY*100, unit.name, unit.name)
            else
                self:Print(L["Waypoints are not supported"]("Cartographer"))
            end

        elseif Cartographer3_Waypoints then
            if type(Cartographer3_Waypoints.SetWaypoint) == "function" then
                if showWaypointMsg then
                    self:Print(L["Creating a waypoint"]("Cartographer"))
                end
                Cartographer3_Waypoints.SetWaypoint(unit.locC, unit.locZ, unit.locX, unit.locY, unit.name, unit.name)
            else
                self:Print(L["Waypoints are not supported"]("Cartographer"))
            end
        else
            self:Print(L["Waypoint support requires the Cartographer or TomTom map addon."])
        end         

        showWaypointMsg = false
    end
end

--
-- COMMON UNIT TOOLTIP
--
do
    local tooltip = GameTooltip

    function Stalker:NodeOnEnter(node)
        if not Config:GetOption("profile", "general.tooltips.enabled") then return end

        local unit = node.unit
        local session = Data:GetUnitSession(unit)

        GameTooltip_SetDefaultAnchor(tooltip, node)
        tooltip:ClearLines()

        tooltip:AddLine("|cffcc4c38"..tostring(unit.name).."|r")

        if not unit.guild then
            tooltip:AddLine("|cff666666<"..L["Guild Unknown"]..">|r")
        elseif unit.guild ~= "" then
            tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE..tostring(unit.guild)..FONT_COLOR_CODE_CLOSE)
        end

        if unit.level and unit.class then
            tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE..LEVEL.." "..Stalker:FormatLevel(unit.level).." "..Data:GetClassName(unit.class) .. FONT_COLOR_CODE_CLOSE)
        else
            tooltip:AddLine("|cff666666<"..L["Level/Class Unknown"]..">|r")
        end

        local continent, zone = Data:GetLocationName(unit.locC, unit.locZ)
        if continent and zone then
            tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE..ZONE..": "..FONT_COLOR_CODE_CLOSE..zone)
            tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE..CONTINENT..": "..FONT_COLOR_CODE_CLOSE..continent)
        end

        if unit.locX and unit.locY then
            tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE..L["Coordinates"]..": "..FONT_COLOR_CODE_CLOSE..self:FormatCoords(unit.locX, unit.locY))
        end

        local distance = Stalker:GetDistance(unit)
        if distance then
            distance = (distance > 50 and (string.format("%.0f", distance) .. "yd") or "Near You")
            tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE..L["Distance"]..": "..FONT_COLOR_CODE_CLOSE..distance)
        end

        if unit.last and unit.last > 0 then
            tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE..L["Seen"]..": "..FONT_COLOR_CODE_CLOSE..self:FormatTime(unit.last).." "..L["ago"])
        end

        if unit.kills or unit.deaths then
            tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE..KILLS..": "..FONT_COLOR_CODE_CLOSE..(unit.kills and unit.kills or 0))
        end

        if unit.kills or unit.deaths then
            tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE..DEATHS..": "..FONT_COLOR_CODE_CLOSE..(unit.deaths and unit.deaths or 0))
        end

        if unit.source then
            tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE..L["Source"]..": " .. FONT_COLOR_CODE_CLOSE .. self:FormatSourceName(unit.source))
        end

        local flags = ""
        if session.track then flags = flags..L["Track"] end
        if unit.kos then flags = flags..(flags ~= "" and ", " or "")..L["KOS"] end
        if Data:IsGuildKos(unit) then flags = flags..(flags ~= "" and ", " or "")..L["Guild KOS"] end
        if flags ~= "" then
            tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE..L["Flags"]..": "..FONT_COLOR_CODE_CLOSE..flags)
        end

        tooltip:Show()
    end

    function Stalker:NodeOnLeave()
        tooltip:Hide()
    end
end

--
-- STRING FORMATTING FUNCTIONS
--

function Stalker:FormatName(name, bracket, colorize, friend)
    return (bracket and "<" or "")..(colorize and (friend and "|cff009919" or "|cffcc4c38") or "")..name..(colorize and "|r" or "")..(bracket and ">" or "")
end

function Stalker:FormatSourceName(name, bracket, colorize, perspective)
    return ((name == STALKER_ME and perspective == STALKER_ME) and self:FormatName(YOU, bracket) or ((name == STALKER_ME and perspective == STALKER_PLAYER) and self:FormatName(COMBATLOG_FILTER_STRING_ME) or self:FormatName(name, bracket, colorize, true)))
end

function Stalker:FormatLevel(level)
    if not level then return "?" end
    level = tonumber(level)
    if level == 0 then return "??" end
    return tostring(bit.band(level, 0x7F))..((bit.band(level, 0x80) == 0) and "+" or "")
end

function Stalker:FormatClass(id)
    if not id then return "?" end
    local class = Data:GetClassName(id)
    return (class == "Death Knight" and "DK" or class)
end

function Stalker:FormatGuild(name, bracket, colorize)
    return (bracket and "<" or "")..(colorize and "|cffffff00" or "")..name..(colorize and "|r" or "")..(bracket and ">" or "")
end

function Stalker:FormatCoords(x, y, bracket, colorize)
    return (bracket and "[" or "")..(colorize and "|cffffff00" or "")..(x and string.format("%.1f", x * 100) or "?")..", "..(y and string.format("%.1f", y * 100) or "?")..(colorize and "|r" or "")..(bracket and "]" or "")
end

function Stalker:FormatTime(timestamp)
    if timestamp == 0 then return "Long " end

    local age = time() - timestamp

    local days
    if age >= 86400 then
        days = math.modf(age / 86400)
        age = age - (days * 86400)
    end

    local hours
    if age >= 3600 then
        hours = math.modf(age / 3600)
        age = age - (hours * 3600)
    end

    local minutes
    if age >= 60 then
        minutes = math.modf(age / 60)
        age = age - (minutes * 60)
    end

    local seconds = age

    local text = (days and days .. "d " or "") .. ((hours and not days) and hours .. "h " or "") .. ((minutes and not hours and not days) and minutes .. "m " or "") .. ((seconds and not minutes and not hours and not days) and seconds .. "s " or "")

    return strtrim(text)
end

function Stalker:debug(category, level, ...)
    if not self.debugging then return end
    if self.debugcats[category] then
        if level <= self.debugcats[category] then
            local args = {}
            for i = 1, select("#",...) do
                table.insert(args, tostring(select(i,...)))
            end
            self:Print(category:upper()..":"..GetTime()..": "..table.concat(args, ", "))
        end
    end
end

---
--- UNIT TESTING
---
function Stalker:CaptureBlizFunctions()
    UnitIsPlayer = sutUnitIsPlayer
    UnitIsFriend = sutUnitIsFriend
    UnitGUID = sutUnitGUID
    UnitName = sutUnitName
    UnitLevel = sutUnitLevel
    UnitClass = sutUnitClass
    GetGuildInfo = sutGetGuildInfo
end

function Stalker:RestoreBlizFunctions()
    UnitIsPlayer = _G["UnitIsPlayer"]
    UnitIsFriend = _G["UnitIsFriend"]
    UnitGUID = _G["UnitGUID"]
    UnitName = _G["UnitName"]
    UnitLevel = _G["UnitLevel"]
    UnitClass = _G["UnitClass"]
    GetGuildInfo = _G["GetGuildInfo"]
end