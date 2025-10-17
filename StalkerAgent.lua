StalkerAgent = Stalker:NewModule("StalkerAgent", "AceTimer-3.0", "AceEvent-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("Stalker", true)
local Serializer = LibStub("AceSerializer-3.0")

-- StalkerAgent has two responsibilities. The first is to broadcast messages
-- containing the user's tracked players on a custom channel
-- (StalkerAgent:BroadcastTrackedUpdate()). The second is to process the
-- messages being broadcast by other addon users (agents) on that same channel
-- (StalkerAgent:OnBroadcastReceive()). When a broadcast message is received
-- from an agent the tracked players in the message are added to a list
-- (Data:AddAgentTracked()). An agent is automatically alerted if a tracked
-- player in that list is detected (StalkerAgent:SendAlerts()).
--
--
-- * General broadcast message format:
--   Command|Version|Frame|Data
--
--   Command -  A one character indicator of the message type. At this time
--              only t (TrackedUpdate) is supported.
--   Version -  A one character indicator of the command version. This allows
--              newer message formats to be introduced in the future.
--   Frame -    Message number. Used to batch multiple messages into one
--              broadcast.
--   Data -     Payload of the command. See the TrackedUpdate command below for
--              details.
--
-- * TrackedUpdate (t) broadcast command Data format:
--   ([TRACKEDUPDATE_PLAYER|Name|TRACKEDUPDATE_TERMINATOR]...)
--
--   Name  - The tracked player's name.
--
--
-- Some limitations are designed into this module to prevent abuse and
-- performance issues from occuring. These include:
--
--  -[ Sent Broadcasts (sent list of tracked players)
--  * We are not broadcasting player positions, only player names. Player
--    positions are only reported directly via an addon-to-addon whisper (see
--    Sent and Received Unicasts below).
--  * A limit of STALKER_TRACKED_LIMIT tracked players can be sent per
--    broadcast.
--  * A broadcast can consist of muliple channel messages (or frames). This is
--    done since the total characters in the tracked player list may exceed the
--    games message size limit of 255. Each frame is numbered starting at 1.
--
--  -[ Received Broadcasts (received list of tracked players)
--  * A broadcast can consist of muliple channel messages (or frames). Each
--    frame number is timestamped to prevent that same frame number from being
--    received again for TRACKEDUPDATE_INTERVAL. Future broadcasts/frames
--    received from the same player inside this interval will be ignored.
--  * The tracked players from broadcasts will only be kept for
--    TRACKEDUPDATE_INTERVAL. Agents must continue broadcasting their tracked
--    list to keep this list refreshed. But as mentioned previously, they cant
--    resend their list until the TRACKEDUPDATE_INTERVAL has passed.
--
--  -[ Sent Unicasts (addon-to-addon whisper report of player position)
--  * Nothing noteworthy here
--
--  -[ Received Unicasts (addon-to-addon whisper reception of player position)
--  * Only one whisper will be processed per second per agent. The tracked
--    player in a whisper MUST contain, among other things, the guid and class
--    of the tracked player. This allows the addon to validate that info against
--    what it knows about that player. If the info doesnt match the message
--    will be rejected.


local Stalker = Stalker
local Config = StalkerConfig
local Data = StalkerData
local time = time
local STALKER_ENCOUNTER = STALKER_ENCOUNTER
local STALKER_TRACKED_LIMIT = STALKER_TRACKED_LIMIT

-- the custom chat channel for broadcasts
local BROADCAST_CHANNEL = "StalkerAddonIU"
local STATUS_DISABLED = 0
local STATUS_DISCONNECTED = 1
local STATUS_CONNECTED = 2

-- Command: TrackedUpdate Broadcast - used to broadcast a list of tracked players
local TRACKEDUPDATE_CMD = "t"
local TRACKEDUPDATE_VERSION = "a"
local TRACKEDUPDATE_INTERVAL = 60
local TRACKEDUPDATE_WINDOW = 5
local TRACKEDUPDATE_TERMINATOR = "\001"
local TRACKEDUPDATE_PLAYER = "\002"
local TRACKEDUPDATE_UNIT = "(["..TRACKEDUPDATE_PLAYER.."])([^"..TRACKEDUPDATE_TERMINATOR.."]+)"..TRACKEDUPDATE_TERMINATOR

-- Command: TrackedAlert Unicast - used to whisper an agent the position of a tracked player
local TRACKEDALERT_CMD = "t"
local TRACKEDALERT_VERSION = "a"

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
    t[1] = 1; t[1] = nil
    tp[t] = true
    return nil
end

-- table to track when commands are received from other agents. this allows us
-- to throttle them
local agents = {}
setmetatable(agents, {
    __index = function(t, name)
        local agent = getTable()
        agent.last = 0
        rawset(t, name, agent)
        return agent
    end,
})

function StalkerAgent:OnInitialize()
    self.modWarning = 0
    self.resetPassword = false
    self.banned = {}
end

function StalkerAgent:OnEnable()
    if Config:GetOption("profile", "general.agent.enabled") then
        self:ScheduleRepeatingTimer("BroadcastTrackedUpdate", TRACKEDUPDATE_INTERVAL)
        self:ScheduleRepeatingTimer("PurgeExpiredAgents", TRACKEDUPDATE_INTERVAL / 4)

        self:RegisterEvent("CHAT_MSG_CHANNEL", "OnBroadcastReceive")
        self:RegisterEvent("CHAT_MSG_ADDON", "OnUnicastReceive")
        self:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE_USER")

        self:ScheduleTimer("ConnectChannel", 20)
    else
        Stalker:Print(L["Agent is disabled in options"])
        self:Disable()
        self.status = STATUS_DISABLED
    end
end

function StalkerAgent:OnDisable()
    self:UnregisterAllEvents()
    self:CancelAllTimers()
    LeaveChannelByName(BROADCAST_CHANNEL)
    self.status = STATUS_DISCONNECTED
    Data:UntrackAllPlayers()
end

function StalkerAgent:ConnectChannel()
    local id = GetChannelName(BROADCAST_CHANNEL)
    if (not id) or (id == 0) then
        JoinTemporaryChannel (BROADCAST_CHANNEL)
        id = GetChannelName(BROADCAST_CHANNEL)
    end
    self.status = STATUS_CONNECTED
    return id
end

function StalkerAgent:CheckStatus()
    id = GetChannelName(BROADCAST_CHANNEL)
    if (not id) or (id == 0) then
        Stalker:Print(L["Agent had issues connecting to the communications channel so is disconnecting. You can try unchecking and rechecking the Enable Agent option in options to reestablish the connection."])
        StalkerAgent:Disable()
    else
        return id
    end
end

do
    local function broadcast(command, version, frame, data)
        local id = StalkerAgent:ConnectChannel()

        message = string.format("%s%s%s%s", command, version, frame, data)
        ChatThrottleLib:SendChatMessage("BULK", "STALKER", message, "CHANNEL", nil, id)

        Stalker:debug("agent", 2, "BroadcastTrackedUpdate()", message, message:len(), id)
    end

    function StalkerAgent:BroadcastTrackedUpdate()
        if not self:CheckStatus() then return end

        local total = 0
        local frame = 1
        local buffer = ""

        for _, unit in Data:GetTrackedUnits() do
            if total >= STALKER_TRACKED_LIMIT then break end

            total = total + 1

            local size = 2 + buffer:len()

            local name = TRACKEDUPDATE_PLAYER..unit.name..TRACKEDUPDATE_TERMINATOR

            if (size + name:len()) > 255 then
                broadcast(TRACKEDUPDATE_CMD, TRACKEDUPDATE_VERSION, frame, buffer)
                frame = frame + 1
                buffer = name
            else
                buffer = buffer..name
            end
        end

        if buffer:len() > 0 then
            broadcast(TRACKEDUPDATE_CMD, TRACKEDUPDATE_VERSION, frame, buffer)
        end
    end
end

function StalkerAgent:OnBroadcastReceive(event, message, sender, ...)
    if select(7, ...) ~= BROADCAST_CHANNEL then return end

    if not (sender or message) then return end

    -- ignore our own broadcasts
    if sender == Stalker.player.name then return end

    -- parse the header
    local command, version, frame = message:match("^([a-z])([a-z])([1-4])")

    -- check if this is a supported command
    if command ~= TRACKEDUPDATE_CMD then
        Stalker:debug("agent", 1, "OnBroadcastReceive()", "Invalid command", sender, message)
        return
    end

    -- validate the command version
    if version > TRACKEDALERT_VERSION then
        Stalker:debug("agent", 1, "OnBroadcastReceive()", "Invalid version", sender, message)
        return
    end

    local agent = agents[sender]
    local now = time()

    -- make sure this frame hasnt been received in the past
    -- TRACKEDUPDATE_INTERVAL seconds
    if agent["TrackedUpdate"..frame] and ((now - agent["TrackedUpdate"..frame]) < (TRACKEDUPDATE_INTERVAL - TRACKEDUPDATE_WINDOW)) then
        Stalker:debug("agent", 1, "OnBroadcastReceive()", "Premature message frame received", sender, now, agent["TrackedUpdate"..frame])
        return
    end
    agent["TrackedUpdate"..frame] = now
    agent.last = now

    -- grab the data payload portion of the message
    local data = message:sub(4)

    -- process each name in the list, adding each to the agent list
    local count = 0
	for type, name in data:gmatch(TRACKEDUPDATE_UNIT) do
        if type == TRACKEDUPDATE_PLAYER then
            count = count + 1
            if count > STALKER_TRACKED_LIMIT then break end
            Data:AddAgentTracked(sender, name)
        end
    end
    Stalker:debug("agent", 2, "OnBroadcastReceive()", "Players for agent added", sender, count)
end

do
    local function unicast(target, command, version, data)
        local message = Serializer:Serialize(command, version, data)
        ChatThrottleLib:SendAddonMessage("ALERT", "STALKER", message, "WHISPER", target)
    end

    function StalkerAgent:SendAlerts(unit)
        if not self:IsEnabled() then return end
        if unit.source ~= STALKER_ME then return end
        for agent in pairs(Data:GetAgents(unit.name)) do
            unicast(agent, TRACKEDALERT_CMD, TRACKEDALERT_VERSION, {unit.name,unit.guid,unit.level,unit.class,unit.guild,unit.locC,unit.locZ,unit.locX,unit.locY})
            Stalker:debug("agent", 2, "SendAlerts()", agent, unit.name,unit.guid,unit.level,unit.class,unit.guild,unit.locC,unit.locZ,unit.locX,unit.locY)
        end
    end
end

function StalkerAgent:OnUnicastReceive(event, prefix, message, type, sender)
    if prefix ~= "STALKER" then return end
    if type ~= "WHISPER" then return end
    if not sender then return end

    local agent = agents[sender]
    local now = time()

    -- ensure we only process one command per second from the same user
    if agent.TrackedAlert == now then return end
    agent.TrackedAlert = now
    agent.last = now

    local success, command, version, data = Serializer:Deserialize(message)
    if not success then
        Stalker:debug("agent", 1, "OnUnicastReceive()", "Failed deserialize", sender, message)
        return
    end

    -- check if this is a supported command
    if command ~= TRACKEDALERT_CMD then
        Stalker:debug("agent", 1, "OnUnicastReceive()", "Invalid command", sender, command, message)
        return
    end

    -- validate the command version
    version = tostring(version)
    if (not version:match("^[a-z]$")) or (version ~= TRACKEDUPDATE_VERSION) then
        Stalker:debug("agent", 1, "OnUnicastReceive()", "Invalid version", sender, version, message)
        return
    end

    local name, guid, level, class, guild, locC, locZ, locX, locY = unpack(data)

    if (not guid) or (not guid:match("^%x+$")) then
        Stalker:debug("agent", 1, "OnUnicastReceive()", "Invalid guid format", sender, name, guid, level, class, guild, locC, locZ, locX, locY)
        return
    end

    class = tonumber(class)
    if (not class) or (not Data:GetClassName(class)) then
        Stalker:debug("agent", 1, "OnUnicastReceive()", "Invalid class", sender, name, guid, level, class, guild, locC, locZ, locX, locY)
        return
    end

    level = tonumber(level)
    if (not level) or (bit.band(level, 0x7F) > 80) then
        Stalker:debug("agent", 1, "OnUnicastReceive()", "Invalid level format", sender, name, guid, level, class, guild, locC, locZ, locX, locY)
        return
    end

    local unit = Data:GetPlayer(name)
    if not unit then
        Stalker:debug("agent", 1, "OnUnicastReceive()", "Unknown name", sender, name, guid, level, class, guild, locC, locZ, locX, locY)
        return
    end

    if (guid ~= unit.guid) or (class ~= unit.class) then
        Stalker:debug("agent", 1, "OnUnicastReceive()", "Mismatched guid or class", sender, name, guid, level, class, guild, locC, locZ, locX, locY)
        return
    end

    local session = Data:GetUnitSession(unit)
    if not session.track then
        Stalker:debug("agent", 1, "OnUnicastReceive()", "Player not tracked", sender, name, guid, level, class, guild, locC, locZ, locX, locY)
        return
    end

    local c, z = Data:GetLocationName(locC, locZ)
    if not (c and z) then
        Stalker:debug("agent", 1, "OnUnicastReceive()", "Unknown location", sender, name, guid, level, class, guild, locC, locZ, locX, locY)
        return
    end

    locX = tostring(locX)
    locY = tostring(locY)
    if (not locX:match("^0%.%d+$")) or (not locY:match("^0%.%d+$")) then
        Stalker:debug("agent", 1, "OnUnicastReceive()", "Invalid coords", sender, name, guid, level, class, guild, locC, locZ, locX, locY)
        return
    end

    Stalker:debug("agent", 2, "OnUnicastReceive()", sender, tostring(name), tostring(guid), tonumber(level), tonumber(class), tostring(guild), tonumber(locC), tonumber(locZ), tonumber(locX), tonumber(locY))

    Stalker:ProcessHostileEvent(unit, session, sender, tostring(name), tostring(guid), tonumber(level), tonumber(class), tostring(guild), tonumber(locC), tonumber(locZ), tonumber(locX), tonumber(locY))
    Stalker:NotifyModules(unit)
end

function StalkerAgent:PurgeExpiredAgents()
    -- remove expired agents
    local now = time()
    for name, agent in pairs(agents) do
        if (now - agent.last) > 300 then
            agents[name] = releaseTable(agents[name])
            Stalker:debug("agent", 2, "StalkerAgent:PurgeExpiredAgents()", name)
        end
    end

    -- remove expired agents
    Data:PurgeExpiredAgents(TRACKEDUPDATE_INTERVAL + TRACKEDUPDATE_WINDOW)
end

function StalkerAgent:CHAT_MSG_CHANNEL_NOTICE_USER(_, ...)
    if select(9, ...) ~= BROADCAST_CHANNEL then return end

    local userA, userB = select(2, ...), select(5, ...)
    if userA == "" then userA = nil end
    if userB == "" then userB = nil end

    local srcName, dstName
    if userB then
        srcName = userB
        dstName = userA
    elseif userA then
        srcName = userA
    else
        return
    end

    local event = select(1, ...)
    local now = time()

    if event == "OWNER_CHANGED" then
        self.resetPassword = true
        if srcName == Stalker.player.name then
            SetChannelPassword(BROADCAST_CHANNEL, "")
            for _, name in ipairs(self.banned) do
                ChannelUnban(BROADCAST_CHANNEL, name)
            end
        end
    elseif event == "PASSWORD_CHANGED" then
        self.resetPassword = (not self.resetPassword)

        if self.resetPassword then
            if (now - self.modWarning) > 30 then
                Stalker:Print("WARNING! Channel owner "..Stalker:FormatName(srcName, true, true, true).." has set a password for the Stalker Agent communication channel. This is an abuse of the channel owner role. Attempting to automatically revert the change, but this player's action may prevent the Agent feature from working properly until that player reverts the change or logs out.")
                self.modWarning = now
            end
            if srcName == Stalker.player.name then
                SetChannelPassword(BROADCAST_CHANNEL, "")
            end
        end
    elseif event == "PLAYER_KICKED" then
        if (now - self.modWarning) > 2 then
            Stalker:Print("WARNING! Channel owner "..Stalker:FormatName(srcName, true, true, true).." has kicked a player from the Stalker Agent communication channel. This is an abuse of the channel owner role.")
            self.modWarning = now
        end
    elseif event == "PLAYER_BANNED" then
        Stalker:Print("WARNING! Channel owner "..Stalker:FormatName(srcName, true, true, true).." has banned a player from the Stalker Agent communication channel. This is an abuse of the channel owner role. Attempting to automatically revert the change, but this player's action may prevent the Agent feature from working properly until that player reverts the change or logs out.")
        self.modWarning = now
        table.insert(self.banned, dstName)
        if srcName == Stalker.player.name then
            ChannelUnban(BROADCAST_CHANNEL, dstName)
        end
    end
end
