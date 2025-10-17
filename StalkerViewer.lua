StalkerViewer = Stalker:NewModule("StalkerViewer", "AceTimer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("Stalker", true)

local Stalker = Stalker
local Config = StalkerConfig
local Data = StalkerData
local STALKER_ENCOUNTER = STALKER_ENCOUNTER

local GUI = {}
local units = {
    recent = {},
    display = {},
}

local PAGE_SIZE = 32
local TAB_PLAYER = 1
local TAB_GUILD = 2
local VIEW_PLAYER_EVENT = 1
local VIEW_PLAYER_HISTORY = 2
local VIEW_GUILD = 3
local COLOR_NORMAL = {1, 1, 1}
local COLOR_KOS = {1, 0, 0}
local COLOR_TRACK = {0, 1, 0}

GUI.ListFrameLines = {
    [VIEW_PLAYER_EVENT] = {},
    [VIEW_PLAYER_HISTORY] = {},
    [VIEW_GUILD] = {},
}
GUI.ListFrameFields = {
    [VIEW_PLAYER_EVENT] = {},
    [VIEW_PLAYER_HISTORY] = {},
    [VIEW_GUILD] = {},
}

local SORT = {
    ["StalkerViewerPlayersNameSort"] = "name",
    ["StalkerViewerPlayersLevelSort"] = "level",
    ["StalkerViewerPlayersClassSort"] = "class",
    ["StalkerViewerPlayersGuildSort"] = "guild",
    ["StalkerViewerPlayersKillsSort"] = "kills",
    ["StalkerViewerPlayersDeathsSort"] = "deaths",
    ["StalkerViewerGuildsGuildSort"] = "guild",
    ["StalkerViewerGuildsKillsSort"] = "kills",
    ["StalkerViewerGuildsDeathsSort"] = "deaths",
    ["StalkerViewerLastSort"] = "last",
}

function StalkerViewer:OnInitialize()
    -- create lookup tables for all gui list lines and btns
    local views = {
        [VIEW_PLAYER_EVENT] = "StalkerViewerPlayerEventFrameListFrame",
        [VIEW_PLAYER_HISTORY] = "StalkerViewerPlayerHistoryFrameListFrame",
        [VIEW_GUILD] = "StalkerViewerGuildFrameListFrame",
    }

    for view, frame in pairs(views) do
        GUI.ListFrameLines[view] = {}
        setmetatable(GUI.ListFrameLines[view], {
            __index = function(t, k)
                local b = _G[views[view].."Line"..k]
                if b then
                    rawset(t, k, b)
                    return b
                end
            end,
        })

        for line = 1, PAGE_SIZE do
            GUI.ListFrameFields[view][line] = {}
            setmetatable(GUI.ListFrameFields[view][line], {
                __index = function(t, k)
                    local f = _G[views[view].."Line"..line..k]
                    if f then
                        rawset(t, k, f)
                        return f
                    end
                end,
            })
        end
    end

    -- set initial view
    self.sortBy = "last"
    self.view = VIEW_PLAYER_HISTORY
    self.playerview = VIEW_PLAYER_HISTORY
    StalkerViewerTypeToggleButton:SetText(L["Event View"])

    -- localization
    StalkerViewerKosCheckboxText:SetText(L["KOS"])
    StalkerViewerTrackCheckboxText:SetText(L["Tracking"])
    StalkerViewerKillsDeathsCheckboxText:SetText(KILLS.."/"..DEATHS)
    StalkerViewerNoteCheckboxText:SetText(LABEL_NOTE)
    
    table.insert(UISpecialFrames, "StalkerViewerFrame")
end

function StalkerViewer:OnDisable()
    self:Hide()
end

function StalkerViewer:Show()
    if Stalker:IsEnabled() then
        StalkerViewerFilterBox:SetText("")
        StalkerViewerKosCheckbox:SetChecked(false)
        StalkerViewerTrackCheckbox:SetChecked(false)
        StalkerViewerKillsDeathsCheckbox:SetChecked(false)
        StalkerViewerNoteCheckbox:SetChecked(false)
        StalkerViewerFrame:Show()
        self:Recalulate()
        self:ScheduleRepeatingTimer("Refresh", 1)
    end
end

function StalkerViewer:Hide()
    self:CancelAllTimers()
    StalkerViewerFrame:Hide()
    self:Cleanup()
end

function StalkerViewer:Toggle()
    if StalkerViewerFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function StalkerViewer:IsShown()
    return StalkerViewerFrame:IsShown()
end

function StalkerViewer:TogglePlayerView()
    if self.playerview == VIEW_PLAYER_HISTORY then
        self.playerview = VIEW_PLAYER_EVENT
    elseif self.playerview == VIEW_PLAYER_EVENT then
        self.playerview = VIEW_PLAYER_HISTORY
    end

    self:UpdateView()
end

function StalkerViewer:UpdateView()
    local tab = PanelTemplates_GetSelectedTab(StalkerViewerTabFrame)

    if tab == TAB_PLAYER then
        StalkerViewerGuildFrame:Hide()

        StalkerViewerTypeToggleButton:Enable()

        if self.playerview == VIEW_PLAYER_HISTORY then
            self.view = VIEW_PLAYER_HISTORY
            StalkerViewerTypeToggleButton:SetText(L["Event View"])
            StalkerViewerPlayerEventFrame:Hide()
            StalkerViewerPlayerHistoryFrame:Show()
        elseif self.playerview == VIEW_PLAYER_EVENT then
            self.view = VIEW_PLAYER_EVENT
            StalkerViewerTypeToggleButton:SetText(L["History View"])
            StalkerViewerPlayerHistoryFrame:Hide()
            StalkerViewerPlayerEventFrame:Show()
        end

        StalkerViewerTrackCheckbox:Show()
        StalkerViewerKillsDeathsCheckbox:ClearAllPoints()
        StalkerViewerKillsDeathsCheckbox:SetPoint("LEFT", StalkerViewerTrackCheckboxText, "RIGHT", 12, -1)

    elseif tab == TAB_GUILD then
        self.view = VIEW_GUILD

        StalkerViewerTypeToggleButton:SetText("")
        StalkerViewerTypeToggleButton:Disable()

        StalkerViewerPlayerEventFrame:Hide()
        StalkerViewerPlayerHistoryFrame:Hide()
        StalkerViewerGuildFrame:Show()

        StalkerViewerTrackCheckbox:Hide()
        StalkerViewerKillsDeathsCheckbox:ClearAllPoints()
        StalkerViewerKillsDeathsCheckbox:SetPoint("LEFT", StalkerViewerKosCheckboxText, "RIGHT", 12, -1)

        if (self.sortBy == "name") or (self.sortBy == "level") or (self.sortBy == "class") then
            self.sortBy = "last"
        end
    end

    self:Refresh()
end

function StalkerViewer:OnNewEvent(unit)
    self.newevents = true
end

function StalkerViewer:SetSortColumn(name)
    name = SORT[name]
    if name then
        self.sortBy = name
        self:Recalulate()
    end
end

function StalkerViewer:Recalulate()
    if not self:IsShown() or not self:IsEnabled() then return end

    self.newevents = false
    StalkerViewerRefreshButton:UnlockHighlight()

    local tab = PanelTemplates_GetSelectedTab(StalkerViewerTabFrame)

    local i = 1

    if tab == TAB_PLAYER then
        for _, unit in Data:GetPlayers(self.sortBy) do
            units.recent[i] = unit
            i = i + 1
        end
    else
        for _, unit in Data:GetGuilds(self.sortBy) do
            units.recent[i] = unit
            i = i + 1
        end
    end

    for j = i, #units.recent do units.recent[j] = nil end

    self:Filter()
end

function StalkerViewer:Filter()
    if not self:IsShown() or not self:IsEnabled() then return end

    local tab = PanelTemplates_GetSelectedTab(StalkerViewerTabFrame)

    local filter = StalkerViewerFilterBox:GetText() or ""

    local filterkos = StalkerViewerKosCheckbox:GetChecked()
    local filtertrack = StalkerViewerTrackCheckbox:GetChecked()
    local filterpvp = StalkerViewerKillsDeathsCheckbox:GetChecked()
    local filternote = StalkerViewerNoteCheckbox:GetChecked()

    local i = 1
    for _, unit in ipairs(units.recent) do
        local session = Data:GetUnitSession(unit)

        if (filter == ""
                or (unit.name and unit.name:sub(1, string.len(filter)):lower() == filter:lower()) -- name match
                or (unit.guild and unit.guild:sub(1, string.len(filter)):lower() == filter:lower())) -- guild match
                and (not filterkos or unit.kos)
                and (not filtertrack or (session and session.track))
                and (not filterpvp or ((unit.kills and unit.kills > 0) or (unit.deaths and unit.deaths > 0)))
                and (not filternote or unit.note)
            then
                units.display[i] = unit
                i = i + 1
        end
    end

    for j = i, #units.display do units.display[j] = nil end

    self:Refresh()
end


function StalkerViewer:Refresh()
    if self.refreshing then return end
    self.refreshing = true

    local tab = PanelTemplates_GetSelectedTab(StalkerViewerTabFrame)
    local view = StalkerViewer.view

    -- set offest location to current scroll position
    local Scroll = StalkerViewerTabFrameTabContentFrameScrollFrame
    FauxScrollFrame_Update(Scroll, #units.display, PAGE_SIZE, 15)
    local offset = FauxScrollFrame_GetOffset(Scroll)
    Scroll:Show()

    local now = time()

    -- loop through all gui frame lines
    for row = 1, PAGE_SIZE do
        local line = GUI.ListFrameLines[view][row]

        -- use offset to find where to start displaying records
        local i = row + offset

        if i <= #units.display then
            local unit = units.display[i]
            local session = Data:GetUnitSession(unit)

            line.unit = unit

            local age = now - unit.last

            local r, g, b
            if session.track and (age < STALKER_ENCOUNTER * 3) then
                r, g, b = unpack(COLOR_TRACK)
            elseif (unit.kos or Data:IsGuildKos(unit)) and (age < STALKER_ENCOUNTER) then
                r, g, b = unpack(COLOR_KOS)
            else
                r, g, b = unpack(COLOR_NORMAL)
            end

            if tab == TAB_PLAYER then
                local name = GUI.ListFrameFields[view][row]["Name"]
                name:SetText(unit.name)
                name:SetTextColor(r, g, b)

                local level = GUI.ListFrameFields[view][row]["Level"]
                level:SetText(Stalker:FormatLevel(unit.level))
                level:SetTextColor(r, g, b)

                local class = GUI.ListFrameFields[view][row]["Class"]
                class:SetText(Stalker:FormatClass(unit.class))
                class:SetTextColor(r, g, b)

                local guild = GUI.ListFrameFields[view][row]["Guild"]
                guild:SetText(unit.guild or "?")
                guild:SetTextColor(r, g, b)

                if view == VIEW_PLAYER_EVENT then
                    local zone = GUI.ListFrameFields[view][row]["Zone"]
                    local _, z = Data:GetLocationName(unit.locC, unit.locZ)
                    zone:SetText(z or "?")
                    zone:SetTextColor(r, g, b)

                    local source = GUI.ListFrameFields[view][row]["Source"]
                    source:SetText(Stalker:FormatSourceName(unit.source))
                    source:SetTextColor(r, g, b)
                else
                    local kills = GUI.ListFrameFields[view][row]["Kills"]
                    kills:SetText(unit.kills or 0)
                    kills:SetTextColor(r, g, b)

                    local deaths = GUI.ListFrameFields[view][row]["Deaths"]
                    deaths:SetText(unit.deaths or 0)
                    deaths:SetTextColor(r, g, b)

                    local note = GUI.ListFrameFields[view][row]["Note"]
                    note:SetText(unit.note or "")
                    note:SetTextColor(r, g, b)
                end

                local last = GUI.ListFrameFields[view][row]["Last"]
                last:SetText((unit.last and unit.last > 0) and Stalker:FormatTime(unit.last) or "?")
                last:SetTextColor(r, g, b)

                local flags = GUI.ListFrameFields[view][row]["Flags"]
                local f = ""
                if session.track then f = f .. "T" end
                if unit.kos then f = f .. "K" end
                if Data:IsGuildKos(unit) then f = f .. "G" end
                flags:SetText(f)
                flags:SetTextColor(r, g, b)
            else
                local guild = GUI.ListFrameFields[view][row]["Guild"]
                guild:SetText(unit.guild ~= nil and unit.guild or "?")
                guild:SetTextColor(r, g, b)

                local kills = GUI.ListFrameFields[view][row]["Kills"]
                kills:SetText(unit.kills or 0)
                kills:SetTextColor(r, g, b)

                local deaths = GUI.ListFrameFields[view][row]["Deaths"]
                deaths:SetText(unit.deaths or 0)
                deaths:SetTextColor(r, g, b)

                local note = GUI.ListFrameFields[view][row]["Note"]
                note:SetText(unit.note or "")
                note:SetTextColor(r, g, b)

                local last = GUI.ListFrameFields[view][row]["Last"]
                last:SetText((unit.last and unit.last > 0) and Stalker:FormatTime(unit.last) or "?")
                last:SetTextColor(r, g, b)

                local flags = GUI.ListFrameFields[view][row]["Flags"]
                local f = ""
                if unit.kos then f = f .. "G" end
                flags:SetText(f)
                flags:SetTextColor(r, g, b)
            end

            line:Show()
        else
            line:Hide()
        end
    end

    self.refreshing = false
end

function StalkerViewer:OnRefreshButtonUpdate(frame, elapsed)
    if not self.newevents then return end

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

-- remove all references to units to help with GC
function StalkerViewer:Cleanup()
    for _, lines in pairs(GUI.ListFrameLines) do
        for _, line in pairs(lines) do
            line.unit = nil
        end
    end

    for i in ipairs(units.recent) do units.recent[i] = nil end
    for i in ipairs(units.display) do units.display[i] = nil end
end
