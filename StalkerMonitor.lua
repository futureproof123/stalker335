StalkerMonitor = Stalker:NewModule("StalkerMonitor", "AceTimer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("Stalker", true)

local Stalker = Stalker
local Config = StalkerConfig
local Data = StalkerData
local bor = bit.bor
local band = bit.band
local STALKER_ENCOUNTER = STALKER_ENCOUNTER
local STALKER_ME = STALKER_ME
local STALKER_COMBAT_HOSTILE = STALKER_COMBAT_HOSTILE
local STALKER_COMBAT_FRIENDLY = STALKER_COMBAT_FRIENDLY
local STALKER_COMBAT_ME = STALKER_COMBAT_ME
local STALKER_LOCATION_WORLD = STALKER_LOCATION_WORLD
local STALKER_LOCATION_PVP = STALKER_LOCATION_PVP
local STALKER_LOCATION_INSTANCE = STALKER_LOCATION_INSTANCE
local STALKER_LOCATION_SANCTUARY = STALKER_LOCATION_SANCTUARY

local GUI = {}
local units = {
    recent = {},
    display = {},
}
-- DELETE ME
STALKERMONITOR_DB = units


local TITLE_HEIGHT = 22
local BAR_INSET = 5
local BAR_HEIGHT = 22
local BAR_FONT_NAME_HEIGHT = 11
local BAR_FONT_HEIGHT = 9
local BAR_FONT_COLOR = {r = 1, g = 1, b = 1, a = 1}
local BAR_ALPHA_MAX = 70
local BAR_ALPHA_MIN = 20
local COLOR_NORMAL = {.25, .25, .5}
local COLOR_KOS = {.75, 0, 0}
local COLOR_TRACK = {0, .75, 0}
local COLOR_DEAD = {.25, .25, .25}
local COLOR_NEUTRAL = {1, 1, 1}
local COLOR_FRIENDLY = {FACTION_BAR_COLORS[6].r, FACTION_BAR_COLORS[6].g, FACTION_BAR_COLORS[6].b}
local COLOR_HOSTILE = {FACTION_BAR_COLORS[2].r, FACTION_BAR_COLORS[2].g, FACTION_BAR_COLORS[2].b}

local DISABLED_MESSAGES = {
    [STALKER_LOCATION_WORLD] = L["No Hostiles Detected"],
    [STALKER_LOCATION_SANCTUARY]= L["Disabled In Sanctuaries"],
    [STALKER_LOCATION_COMBAT] = L["Disabled In Combat Zones"],
    [STALKER_LOCATION_INSTANCE] = L["Disabled In Instances"],
    [STALKER_LOCATION_PVP] = L["Disabled In Battlegrounds"],
}

-- find value in haystack
local function tfind(haystack, needle)
    for k,v in pairs(haystack) do
        if v == needle then return k end
    end
end

function StalkerMonitor:OnInitialize()
    GUI.Frame = StalkerMonitorFrame
    GUI.PlayersFrame = StalkerMonitorPlayersFrame
    GUI.PlayerButtons = {}
    self.displayed = 0

    -- go ahead and create one btn to ensure we can test the protected state
    -- of its parent frame since we use secure templates.
    self:GetPlayerButton(1)

    self.maxunits = Config:GetOption("profile", "monitor.maxunits")
    Config:RegisterForUpdates("profile", "monitor.maxunits", function(v) StalkerMonitor:OnMaxUnitsUpdate(v) end)
    self.fadetime = Config:GetOption("profile", "monitor.fadetime")
    Config:RegisterForUpdates("profile", "monitor.fadetime", function(v) StalkerMonitor:OnFadetimeUpdate(v) end)
    Config:RegisterForUpdates("profile", "monitor.anchor", function() StalkerMonitor:OnAnchorUpdate() end)
    
    if StalkerConfig:GetOption("profile", "monitor.startup") then
        self:Show()
    end
end

function StalkerMonitor:OnEnable()
    self:ScheduleRepeatingTimer("Refresh", 1)
    self:ScheduleRepeatingTimer("Recalulate", Config:GetOption("profile", "monitor.refreshtime"))
end

function StalkerMonitor:OnDisable()
    self:CancelAllTimers()
    self:Hide()
end

function StalkerMonitor:Show()
    if Stalker:IsEnabled() then
        GUI.Frame:Show()
        self.paused = false
        StalkerMonitorPauseButton:Show()
        StalkerMonitorPlayButton:Hide()
        self:RestoreFrame()
        self:Refresh()
    end
end

function StalkerMonitor:Hide()
    GUI.Frame:Hide()
    StalkerMonitor:OnMonitorLeave(true)
end

function StalkerMonitor:Toggle()
    if GUI.Frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function StalkerMonitor:IsShown()
    return GUI.Frame:IsShown()
end

function StalkerMonitor:OnMaxUnitsUpdate(value)
    self.maxunits = value
end

function StalkerMonitor:OnFadetimeUpdate(value)
    self.fadetime = value
end

function StalkerMonitor:OnAnchorUpdate()
    self:SaveFrame()
    self:RestoreFrame()
end

function StalkerMonitor:OnNewEvent(unit)
    if not self:IsEnabled() then return end

    -- the recent list hold units as they come in. we dont add them to the
    -- display list immediately to keep it from jumping around so much during
    -- heavy event periods.
    local recent = units.recent

    -- the list of units to display. its contents are displayed (Refresh())
    -- every second, and resorted (Recalculate()) every profile.monitor.refreshtime
    local display = units.display

    -- add unit to top of recent list if not there
    if not tfind(recent, unit) then
        table.insert(recent, 1, unit)
    end

    -- add unit to top of displayed list if not there
    if (self.displayed < self.maxunits) and (not tfind(display, unit)) then
        table.insert(display, 1, unit)
    end
end

do -- StalkerData:Recalulate()

    local function sorter(a, b)
        return a.last > b.last
    end

    -- expire inactive units from recent list, and rebuild and sort display list
    function StalkerMonitor:Recalulate()
        local recent = units.recent
        local display = units.display

        local now = time()

        -- expire units from recent list and add unexpired ones to display list
        local i = 1
        while recent[i] do
            if (now - recent[i].last) > self.fadetime then
                table.remove(recent, i)
            else
                display[i] = recent[i]
                i = i + 1
            end
        end

        for j = i, #display do display[j] = nil end

        -- resort display list
        table.sort(display, sorter)
    end

end

function StalkerMonitor:ClearDisplay()
    units.recent = {}
    self:Recalulate()
    self:Refresh()
end

function StalkerMonitor:Refresh()
    if not self:IsEnabled() or not self:IsShown() or self.paused or not GUI.PlayersFrame:CanChangeProtectedState() then return end

    local now = time()
    local textWidth

    local i = 1
    for _, unit in ipairs(units.display) do
        if i > self.maxunits then break end

        local age = now - unit.last

        if age < self.fadetime then
            local session = Data:GetUnitSession(unit)

            local r, g, b

            -- get button and set a reference to unit
            local btn = self:GetPlayerButton(i)
            btn.unit = unit

            if not textWidth then textWidth = btn.Text:GetWidth() end

            -- set color of bar based on whether kos or tracked
            if session.track then
                r, g, b = unpack(COLOR_TRACK)
            elseif (unit.kos or Data:IsGuildKos(unit)) then
                r, g, b = unpack(COLOR_KOS)
            elseif session.dead then
                r, g, b = unpack(COLOR_DEAD)
            else
                r, g, b = unpack(COLOR_NORMAL)
            end

            -- set alpha of bar based on age of last activity
            local a = (BAR_ALPHA_MAX - (age * ((BAR_ALPHA_MAX - BAR_ALPHA_MIN) / self.fadetime))) / 100
            btn.Texture:SetVertexColor(r, g, b, a)
            btn.HighlightTexture:SetVertexColor(r, g, b, 1)

            -- set height of timer bar based on age of last activity
            local height = (BAR_HEIGHT - 4) - (age * ((BAR_HEIGHT - 4) / self.fadetime))
            btn.Timer:SetHeight(height)

            -- set player name
            btn.Name:SetText(unit.name)
            btn.Name:SetWidth(textWidth * .60)

            -- set player level and class
            btn.LevelClass:SetText((unit.level and unit.class) and (Stalker:FormatLevel(unit.level) .. " " .. Stalker:FormatClass(unit.class)) or "Unknown")
            btn.LevelClass:SetWidth(textWidth * .60)

            local info1text
            local info1color

            if unit.source == STALKER_ME then
                if session.dead then
                    info1text = "Dead"
                    info1color = COLOR_NEUTRAL
                elseif not session.targetFlags then
                    info1text = ""
                    info1color = COLOR_NEUTRAL
                elseif (band(session.targetFlags, COMBATLOG_OBJECT_TYPE_MASK) == 0) or (unit.name == session.targetName) then
                    info1text = "<Self>"
                    info1color = COLOR_NEUTRAL
                elseif band(session.targetFlags, STALKER_COMBAT_ME) == STALKER_COMBAT_ME then
                    info1text = "<You>"
                    info1color = COLOR_NEUTRAL
                elseif band(session.targetFlags, COMBATLOG_OBJECT_TYPE_NPC) == COMBATLOG_OBJECT_TYPE_NPC then
                    info1text = "<NPC>"
                    info1color = COLOR_NEUTRAL
                elseif band(session.targetFlags, STALKER_COMBAT_FRIENDLY) == STALKER_COMBAT_FRIENDLY then
                    info1text = session.targetName
                    info1color = COLOR_FRIENDLY
                elseif band(session.targetFlags, STALKER_COMBAT_HOSTILE) == STALKER_COMBAT_HOSTILE then
                    info1text = session.targetName
                    info1color = COLOR_HOSTILE
                else
                    info1text = "<Object>"
                    info1color = COLOR_NEUTRAL
                end

                btn.Info1:SetText(info1text)
                btn.Info1:SetWidth(textWidth - btn.Name:GetStringWidth() - 8)
                r, g, b = unpack(info1color)
                btn.Info1:SetTextColor(r, g, b)

                btn.Info2:SetText((session.spell and (not session.dead)) and session.spell or "")
                btn.Info2:SetWidth(textWidth - btn.LevelClass:GetStringWidth() - 8)
            else
                info1text = "Near " .. "<"..unit.source..">"
                btn.Info1:SetText(info1text)
                btn.Info1:SetWidth(textWidth - btn.Name:GetStringWidth() - 8)

                local _, zone = Data:GetLocationName(unit.locC, unit.locZ)
                btn.Info2:SetText(zone)
                btn.Info2:SetWidth(textWidth - btn.LevelClass:GetStringWidth() - 8)
            end

            local slot = 4
            for i = 1, slot do
                btn.Flags.Slots[i]:Hide()
            end

            if unit.kos or Data:IsGuildKos(unit) then
                btn.Flags.Slots[slot]:SetTexture("Interface\\AddOns\\Stalker\\Images\\FlagKos")
                btn.Flags.Slots[slot]:Show()
                slot = slot - 1
            end

            if session.track then
                btn.Flags.Slots[slot]:SetTexture("Interface\\AddOns\\Stalker\\Images\\FlagTrack")
                btn.Flags.Slots[slot]:Show()
                slot = slot - 1
            end

            if session.map then
                btn.Flags.Slots[slot]:SetTexture("Interface\\AddOns\\Stalker\\Images\\FlagDisplay")
                btn.Flags.Slots[slot]:Show()
                slot = slot - 1
            end

            if session.pvp and ((now - session.pvp) < 60) and (not session.dead) then
                btn.Flags.Slots[slot]:SetTexture("Interface\\AddOns\\Stalker\\Images\\FlagPvp")
                btn.Flags.Slots[slot]:Show()
                slot = slot - 1

                if (now - session.pvp) < 10 then
                    btn.Flasher.timer = 10
                else
                    btn.Flasher:SetAlpha(0)
                    btn.Flasher.timer = 0
                end
            else
                btn.Flasher:SetAlpha(0)
                btn.Flasher.timer = 0
            end

            if slot == 4 then
                btn.Flags:SetWidth(1)
            elseif slot >= 2 then
                btn.Flags:SetWidth(9)
            else
                btn.Flags:SetWidth(19)
            end

            btn:SetAttribute("macrotext", "/target " .. unit.name)

            btn:Show()

            i = i + 1
        end
    end

    self.displayed = i - 1

    -- hide remaining btns
    for i = self.displayed + 1, #GUI.PlayerButtons do
        GUI.PlayerButtons[i].unit = nil
        GUI.PlayerButtons[i]:Hide()
    end

    self:ResizeFrame()
end

function StalkerMonitor:GetPlayerButton(index)
    local btn = GUI.PlayerButtons[index]

    if not btn then
        btn = CreateFrame("Button", "StalkerMonitorPlayerButton"..index, GUI.PlayersFrame, "StalkerMonitorPlayerButtonTemplate")
        GUI.PlayerButtons[index] = btn

        if index == 1 then
            btn:SetPoint("TOPLEFT", GUI.PlayersFrame, "TOPLEFT", BAR_INSET, -1)
            btn:SetPoint("TOPRIGHT", GUI.PlayersFrame, "TOPRIGHT", -(BAR_INSET), -1)
        else
            btn:SetPoint("TOPLEFT", GUI.PlayerButtons[index - 1], "BOTTOMLEFT", 0, -1)
            btn:SetPoint("RIGHT", GUI.PlayersFrame, "RIGHT", -(BAR_INSET), -1)
        end

        btn.Texture = getglobal("StalkerMonitorPlayerButton"..index.."Texture")
        btn.HighlightTexture = getglobal("StalkerMonitorPlayerButton"..index.."HighlightTexture")
        btn.Timer = getglobal("StalkerMonitorPlayerButton"..index.."FrameTimerFrameBarFrame")
        btn.Flags = getglobal("StalkerMonitorPlayerButton"..index.."FrameFlagsFrame")

        btn.Text = getglobal("StalkerMonitorPlayerButton"..index.."FrameTextFrame")
        btn.Name = getglobal("StalkerMonitorPlayerButton"..index.."FrameTextFrameNameText")
        btn.LevelClass = getglobal("StalkerMonitorPlayerButton"..index.."FrameTextFrameLevelClassText")
        btn.Info1 = getglobal("StalkerMonitorPlayerButton"..index.."FrameTextFrameInfo1Text")
        btn.Info2 = getglobal("StalkerMonitorPlayerButton"..index.."FrameTextFrameInfo2Text")

        btn.Flags.Slots = {
            [1] = getglobal("StalkerMonitorPlayerButton"..index.."FrameFlagsFrameSlot1"),
            [2] = getglobal("StalkerMonitorPlayerButton"..index.."FrameFlagsFrameSlot2"),
            [3] = getglobal("StalkerMonitorPlayerButton"..index.."FrameFlagsFrameSlot3"),
            [4] = getglobal("StalkerMonitorPlayerButton"..index.."FrameFlagsFrameSlot4")
        }

        btn.Flasher = getglobal("StalkerMonitorPlayerButton"..index.."FrameFlasher")

        btn:SetAttribute("type1", "macro")
        btn:SetID(index)
    end

    return btn
end

function StalkerMonitor:OnPlayerButtonFlasherUpdate(frame, elapsed)
    if frame.timer == 0 then return end

    frame.timer = frame.timer - elapsed

    if frame.timer > 0 then
        local alpha = GetTime() % 1.3
        if alpha < 0.15 then
            frame:SetAlpha(alpha / 0.15)
        elseif alpha < 0.9 then
            frame:SetAlpha(1 - (alpha - 0.15) / 0.6)
        else
            frame:SetAlpha(0)
        end
    else
        frame.timer = 0
    end
end

function StalkerMonitor:OnPlayButtonUpdate(frame, elapsed)
    if not self.paused then return end

    local timer = frame.timer + elapsed

    if (timer < .5) then
        frame.timer = timer
        return
    end

    while (timer >= .5) do
        timer = timer - .5
    end
    frame.timer = timer

    if (frame.state) then
        frame:UnlockHighlight()
        frame.state = nil
    else
        frame:LockHighlight()
        frame.state = true
    end    
end

function StalkerMonitor:SaveFrame()
    local x, y = GUI.Frame:GetCenter()

    local anchor = Config:GetOption("profile", "monitor.anchor")
    if anchor == "TOP" then
        y = GUI.Frame:GetTop()
    elseif anchor == "BOTTOM" then
        y = GUI.Frame:GetBottom()
    end

    x = (x * GUI.Frame:GetEffectiveScale() / UIParent:GetScale()) - (GetScreenWidth() / 2)
    y = (y * GUI.Frame:GetEffectiveScale() / UIParent:GetScale()) - (GetScreenHeight() / 2)
    Config:SetOption("profile", "monitor.position.x", x)
    Config:SetOption("profile", "monitor.position.y", y)
    Config:SetOption("profile", "monitor.position.w", GUI.Frame:GetWidth())
end

function StalkerMonitor:RestoreFrame()
    local x = Config:GetOption("profile", "monitor.position.x")
    local y = Config:GetOption("profile", "monitor.position.y")
    x = x * UIParent:GetScale() / GUI.Frame:GetEffectiveScale()
    y = y * UIParent:GetScale() / GUI.Frame:GetEffectiveScale()
    GUI.Frame:ClearAllPoints()
    GUI.Frame:SetPoint(Config:GetOption("profile", "monitor.anchor"), UIParent, "CENTER", x, y)
    GUI.Frame:SetWidth(Config:GetOption("profile", "monitor.position.w"))
    self:ResizeFrame()
end

function StalkerMonitor:ResetPosition()
    Config:SetOption("profile", "monitor.position.x", 0)
    Config:SetOption("profile", "monitor.position.y", 0)
    StalkerMonitor:RestoreFrame()
end

function StalkerMonitor:ResizeFrame()
    if StalkerMonitor.moving then return end

    -- resize height of frame
    local height = ((BAR_HEIGHT + 1) * self.displayed) + (self.displayed > 0 and 0 or (BAR_HEIGHT + 1)) + (self.cursorInFrame and TITLE_HEIGHT or 9)
    GUI.Frame:SetHeight(height)

    -- hide hostile msg if needed
    if self.displayed > 0 then
        StalkerMonitorDisabledText:Hide()
    elseif Stalker.listening then
        StalkerMonitorDisabledText:SetText(DISABLED_MESSAGES[STALKER_LOCATION_WORLD])
        StalkerMonitorDisabledText:Show()
    else
        StalkerMonitorDisabledText:SetText(DISABLED_MESSAGES[Stalker.location])
        StalkerMonitorDisabledText:Show()
    end
end
function StalkerMonitor:OnMonitorEnter()
    if not self.cursorInFrame then
        self.cursorInFrame = true
        StalkerMonitorHeaderFrame:Show()
        GUI.PlayersFrame:ClearAllPoints()
        GUI.PlayersFrame:SetPoint("TOPLEFT", GUI.Frame, "TOPLEFT", 0, -18)
        GUI.PlayersFrame:SetPoint("BOTTOMRIGHT", GUI.Frame, "BOTTOMRIGHT")
        StalkerMonitor:Refresh()
    end
end

function StalkerMonitor:OnMonitorLeave(force)
    if self.paused and not force then return end

    local x, y = GetCursorPosition()
    x = x / GUI.Frame:GetEffectiveScale()
    y = y / GUI.Frame:GetEffectiveScale()
    if force or (x < GUI.Frame:GetLeft()) or (x > GUI.Frame:GetRight()) or (y > GUI.Frame:GetTop()) or (y < GUI.Frame:GetBottom()) then
        self.cursorInFrame = nil
        StalkerMonitorHeaderFrame:Hide()
        GUI.PlayersFrame:ClearAllPoints()
        GUI.PlayersFrame:SetPoint("TOPLEFT", GUI.Frame, "TOPLEFT", 0, -5)
        GUI.PlayersFrame:SetPoint("BOTTOMRIGHT", GUI.Frame, "BOTTOMRIGHT")
        StalkerMonitor:Refresh()
    end
end