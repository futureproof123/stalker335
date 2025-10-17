StalkerAlerts = Stalker:NewModule("StalkerAlerts")

local LSM = LibStub("LibSharedMedia-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Stalker", true)

local Stalker = Stalker
local Config = StalkerConfig
local Data = StalkerData

local timers = {
    ["sound"] = 0,
    ["flash"] = 0,
    ["console"] = 0,
    ["screen"] = 0,
}

LSM:Register("sound", "War Drums", [[Sound\Event Sounds\Event_wardrum_ogre.wav]])

local function translate(unit, template, style, perspective)
    local session = Data:GetUnitSession(unit)
    local continent, zone = StalkerData:GetLocationName(unit.locC, unit.locZ)

    local msg = template
    msg = msg:gsub("%%type", (unit.kos and "KOS" or (session.track and "Tracked" or "Hostile")))
    msg = msg:gsub("%%faction", Stalker.player.hostileFaction)
    msg = msg:gsub("%%enemy", Stalker:FormatName(unit.name, true, style))
    msg = msg:gsub("%%level", Stalker:FormatLevel(unit.level))
    msg = msg:gsub("%%class", Stalker:FormatClass(unit.class))
    msg = msg:gsub("%%guild", (unit.guild and Stalker:FormatGuild(unit.guild) or ""))
    msg = msg:gsub("%%zone", zone or "?")
    msg = msg:gsub("%%continent", continent or "?")
    msg = msg:gsub("%%coords", ((unit.locX and unit.locY) and Stalker:FormatCoords(unit.locX, unit.locY, true, style) or "?"))
    msg = msg:gsub("%%source", Stalker:FormatSourceName(unit.source, true, style, perspective))
    msg = msg:gsub("%%note", (unit.note or ""))
    msg = msg:gsub("%%time", Stalker:FormatTime(unit.last))
    msg = msg:gsub("%%newline", (style and "\n" or ""))
    msg = msg:gsub("||", "|")
    return msg
end

local flasher
local function flash()
    if not flasher then
        flasher = CreateFrame("Frame", "StalkerFlashFrame")
        flasher:SetToplevel(true)
        flasher:SetFrameStrata("FULLSCREEN_DIALOG")
        flasher:SetAllPoints(UIParent)
        flasher:EnableMouse(false)
        flasher:Hide()
        flasher.texture = flasher:CreateTexture(nil, "BACKGROUND")
        flasher.texture:SetTexture("Interface\\FullScreenTextures\\LowHealth")
        flasher.texture:SetAllPoints(UIParent)
        flasher.texture:SetBlendMode("ADD")
        flasher:SetScript("OnShow", function(self)
            self.elapsed = 0
            self:SetAlpha(0)
        end)
        flasher:SetScript("OnUpdate", function(self, elapsed)
            elapsed = self.elapsed + elapsed
            if elapsed < 2.6 then
                local alpha = elapsed % 1.3
                if alpha < 0.15 then
                    self:SetAlpha(alpha / 0.15)
                elseif alpha < 0.9 then
                    self:SetAlpha(1 - (alpha - 0.15) / 0.6)
                else
                    self:SetAlpha(0)
                end
            else
                self:Hide()
            end
            self.elapsed = elapsed
        end)
    end
    flasher:Show()
end

function StalkerAlerts:SendAlerts(unit)
    local session = Data:GetUnitSession(unit)

    -- only process alerts for this unit if its been at least STALKER_ENCOUNTER
    -- since we've seen them.
    if session.last < STALKER_ENCOUNTER then return end

    local now = time()

    -- classify the category of alert that may be sent
    local category = (unit.kos and "kos" or (session.track and "tracked" or "hostile"))

    -- Play sound
    local enabled, interval = self:GetAlert(category, "sound")
    if enabled then
        if timers.sound < (now - interval) then
            PlaySoundFile(LSM:Fetch("sound", "War Drums"))
            timers.sound = now
        end
    end

    -- Screen flash
    local enabled, interval = self:GetAlert(category, "flash")
    if enabled then
        if timers.flash <  (now - interval) then
            flash()
            timers.flash = now
        end
    end

    -- Console message
    local enabled, interval, message = self:GetAlert(category, "console", true)
    if enabled then
        if timers.console <  (now - interval) then
            Stalker:Print(translate(unit, message, true))
            timers.console = now
        end
    end

    -- Screen message
    local enabled, interval, message = self:GetAlert(category, "screen", true)
    if enabled then
        if timers.screen <  (now - interval) then
            UIErrorsFrame:AddMessage(translate(unit, message, true), 1, 0, 0, 1, UIERRORS_HOLD_TIME)
            timers.screen = now
        end
    end
end

function StalkerAlerts:Print(msg)
    Stalker:Print(msg)
end

function StalkerAlerts:GetAlert(category, type, hasMessage)
    local enabled, interval, message

    if Config:GetOption("profile", "alerts."..category..".enabled") then
        enable = Config:GetOption("profile", "alerts."..category.."."..type..".enabled")
        if enable > 0 then
            if (enable == 1) or ((enable == 2) and Config:GetOption("profile", "alerts.global."..type..".enabled")) then
                interval = (enable == 1 and Config:GetOption("profile", "alerts."..category.."."..type..".interval") or Config:GetOption("profile", "alerts.global."..type..".interval"))
                if hasMessage then
                    message = (enable == 1 and Config:GetOption("profile", "alerts."..category.."."..type..".message") or Config:GetOption("profile", "alerts.global."..type..".message"))
                end
                enabled = true
            end
        end
    end

    return enabled, interval, message
end

function StalkerAlerts:SendPosition(unit, channel, name)
    local msg = translate(unit, StalkerConfig:GetOption("profile", "alerts.channel.message"), false, STALKER_PLAYER)
    ChatThrottleLib:SendChatMessage("NORMAL", "STALKER", msg, channel, nil, name)
end