StalkerConfig = Stalker:NewModule("StalkerConfig")

local L = LibStub("AceLocale-3.0"):GetLocale("Stalker", true)

local db -- the SavedVariables db
local dbIndex = {} -- an index to db
local updates = {} -- array of callbacks to notify of specific db changes

local DEFAULT_SOUND_INTERVAL = 120
local DEFAULT_FLASH_INTERVAL = 120
local DEFAULT_CONSOLE_INTERVAL = 0
local DEFAULT_CONSOLE_MESSAGE = L["%type player %enemy detected near %source in %zone at %coords"]
local DEFAULT_SCREEN_INTERVAL = 120
local DEFAULT_SCREEN_MESSAGE = L["Stalker %type player %enemy detected near %source!%newline||cffffffff%note||r"]

local alerts = {
    categories = {
        global = {
            name = "        "..L["Global Alerts"].."        ",
            description = L["Global alert settings which apply the Hostile, KOS, and Tracked categories unless overridden at the category level."],
        },
        hostile = {
            name = L["Hostile Alerts"],
            description = L["Alerts sent when any hostile player is detected. Default is disabled."],
        },
        kos = {
            name = L["KOS Alerts"],
            description = L["Alerts sent when KOS players are detected."],
        },
        tracked = {
            name = L["Tracked Alerts"],
            description = L["Alerts sent when Tracked players are detected."],
        },
    },
    types = {
        sound = {
            name = L["Sound Alerts"],
            enabled = {
                description = L["Plays a sound when this type of hostile is detected."],
            },
            interval = {
                description = L["The time is seconds that must elapse before another sound alert can occur. Default is 120 (2 minutes)."],
            },
        },
        flash = {
            name = L["Screen Flash Alerts"],
            enabled = {
                description = L["Flashes the screen when this type of hostile is detected."],
            },
            interval = {
                description = L["The time is seconds that must elapse before another screen flash alert can occur. Default is 120 (2 minutes)."],
            },
        },
        console = {
            name = L["Console Message Alerts"],
            enabled = {
                description = L["Sends a message to the console when this type of hostile is detected."],
            },
            message = {
                description = L["The message to send to the console when this type of hostile is detected."],
            },
            interval = {
                description = L["The time is seconds that must elapse before another console message alert can occur. Default is 0 seconds."],
            },
        },
        screen = {
            name = L["Screen Message Alerts"],
            enabled = {
                description = L["Sends a message to the screen when this type of hostile is detected."],
            },
            message = {
                description = L["The message to send to the screen when this type of hostile is detected."],
            },
            interval = {
                description = L["The time is seconds that must elapse before another screen message alert can occur. Default is 120 (2 minutes)."],
            },
        },
    },
}

local function genAlertOpts(cat, type, order, message)
    local cfg = alerts.types[type]

    local option = {
        name = cfg.name,
        type = "group",
        inline = true,
        order = order,
        args = {},
    }

    option.args.enabled = {
        desc = cfg.enabled.description,
        order = 1,
        get = function() return StalkerConfig:GetOption("profile", "alerts."..cat.."."..type..".enabled") end,
        set = function(_, v) StalkerConfig:SetOption("profile", "alerts."..cat.."."..type..".enabled", v) end,
    }

    if cat == "global" then
        option.args.enabled.name = L["Enable Alert"]
        option.args.enabled.type = "toggle"
    else
        option.args.enabled.name = ""
        option.args.enabled.type = "select"
        option.args.enabled.values = {
            [0] = "Disabled",
            [1] = "Enabled",
            [2] = "Use Global Settings",
        }
        option.args.enabled.disabled = function() return disabledAlertOption(cat) end
    end

    if message then
        option.args.message = {
            name = L["Alert Message"],
            desc = cfg.message.description,
            order = 2,
            type = "input",
            width = "full",
            disabled = function() return disabledAlertOption(cat.."."..type) end,
            get = function() return StalkerConfig:GetOption("profile", "alerts."..cat.."."..type..".message") end,
            set = function(_, v) StalkerConfig:SetOption("profile", "alerts."..cat.."."..type..".message", v) end
        }
    end

    option.args.interval = {
        name = L["Alert Interval Time"],
        desc = cfg.interval.description,
        order = 3,
        type = "range",
        width = "full",
        min = 0,
        max = 600,
        step = 1,
        disabled = function() return disabledAlertOption(cat.."."..type) end,
        get = function() return StalkerConfig:GetOption("profile", "alerts."..cat.."."..type..".interval") end,
        set = function(_, v) StalkerConfig:SetOption("profile", "alerts."..cat.."."..type..".interval", v) end,
    }

    return option
end

local function genAlertCat(cat, order)
    local cfg = alerts.categories[cat]

    local option = {
        name = cfg.name,
        type = "group",
        order = order,
        args = {
            description = {
                order = 1,
                type = "description",
                name = cfg.description.."\n",
            },
            soundalerts = genAlertOpts(cat, "sound", 3, false),
            flashalerts = genAlertOpts(cat, "flash", 4, false),
            consolealerts = genAlertOpts(cat, "console", 5, true),
            screenalerts = genAlertOpts(cat, "screen", 6, true),
        },
    }

    if cat ~= "global" then
        option.args.enabled = {
            name = L["Enable Alerting"],
            desc = L["Enables alerting for enabled alerts in this category. This setting can also be controlled via the Stalker minimap icon."],
            order = 2,
            type = "toggle",
            width = "full",
            get = function() return StalkerConfig:GetOption("profile", "alerts."..cat..".enabled") end,
            set = function(_, v) StalkerConfig:SetOption("profile", "alerts."..cat..".enabled", v) end,
        }
    end

    return option
end

function disabledAlertOption(category)
    local enabled = StalkerConfig:GetOption("profile", "alerts."..category..".enabled")
    return (enabled == false) or (enabled == 0) or (enabled == 2)
end

local options = {
    main = {
        name = "Stalker",
        type = "group",
        args = {
            title = {
                order = 1,
                type = "description",
                name = L["Addon for detecting, managing, and tracking hostile players."].."\n\n",
                cmdHidden = true,
            },
            about = {
                name = "About",
                type = "group",
                inline = true,
                cmdHidden = true,
                args = {
                    version = {
                        order = 1,
                        type = "description",           
                        name = "|cffffd700".."Version"..": "..GREEN_FONT_COLOR_CODE..Stalker.version.." (Rev "..Stalker.revision..")",
                        cmdHidden = true
                    },
                    author = {
                        order = 2,
                        type = "description",
                        name = "|cffffd700".."Author"..": ".."|cffff8c00".."Croy9000",
                        cmdHidden = true
                    },
                    category = {
                        order = 3,
                        type = "description",
                        name = "|cffffd700".."Category"..": "..HIGHLIGHT_FONT_COLOR_CODE.."Combat",
                        cmdHidden = true
                    },
                    website = {
                        order = 4,
                        type = "description",
                        name = "|cffffd700".."Website"..": "..HIGHLIGHT_FONT_COLOR_CODE.."http://www.curse.com/",
                        cmdHidden = true
                    },
                }
            },
            monitor = {
                name = L["Toggle the Stalker Monitor"],
                type = "execute",
                order = 1,
                func = function() StalkerMonitor:Toggle() end,
                guiHidden = true,
            },
            viewer = {
                name = L["Toggle the Stalker Viewer"],
                type = "execute",
                order = 2,
                func = function() StalkerViewer:Toggle() end,
                guiHidden = true,
            },
            options = {
                name = L["Open Options Panel"],
                type = "execute",
                order = 3,
                func = function() Stalker:ShowOptionsPanel() end,
                guiHidden = true,
            },
            resetdb = {
                name = L["Reset Database. Removes all players and guilds from the database."],
                type = "execute",
                order = 4,
                func = function() StalkerData:ResetDb() end,
                guiHidden = true,
            },
            debug = {
                name = "Debug",
                type = "input",
                order = 100,
                get = function() return "" end,
                set = function(a, v) Stalker:OnDebugOptionUpdate(v) end,
                guiHidden = true,
                cmdHidden = true,
            },
        }
    },
    general = {
        name = L["General Options"],
        type = "group",
        order = 1,
        args = {
            desc = {
                order = 1,
                type = "description",
                name = L["Options related to the entire addon."].."\n\n",
            },
            enabled = {
                name = L["Enable Addon"],
                desc = L["Disabling the Stalker addon will turn off all detection and alerting."],
                order = 2,
                type = "toggle",
                width = "full",
                get = function() return StalkerConfig:GetOption("profile", "general.enabled") end,
                set = function(_, v) StalkerConfig:SetOption("profile", "general.enabled", v) end
            },
            minimapbutton = {
                name = L["Enable Minimap Button"],
                desc = L["Displays the Stalker minimap button around the game's Minimap."],
                order = 3,
                type = "toggle",
                width = "full",
                get = function() return not StalkerConfig:GetOption("profile", "general.minimapicon.hide") end,
                set = function(_, v) StalkerConfig:SetOption("profile", "general.minimapicon.hide", not v) end
            },
            tooltips = {
                name = L["Enable Tooltips"],
                desc = L["Enables a Stalker tooltip containing information on hostiles."],
                order = 4,
                type = "toggle",
                width = "full",
                get = function() return StalkerConfig:GetOption("profile", "general.tooltips.enabled") end,
                set = function(_, v) StalkerConfig:SetOption("profile", "general.tooltips.enabled", v) end
            },
            agent = {
                name = L["Enable Agent"],
                desc = L["Enables the Stalker Agent to share hostile tracking data with other Stalker addon users. Disabling will prevent you from tracking hostiles."],
                order = 5,
                type = "toggle",
                width = "full",
                get = function() return StalkerConfig:GetOption("profile", "general.agent.enabled") end,
                set = function(_, v) StalkerConfig:SetOption("profile", "general.agent.enabled", v) end
            },
            sanctuaries = {
                name = L["Disable in Sanctuaries"],
                desc = L["Disables Stalker in sanctuary zones where combat is not possible."],
                order = 6,
                type = "toggle",
                width = "full",
                get = function() return StalkerConfig:GetOption("profile", "general.disableSanctuaries") end,
                set = function(_, v) StalkerConfig:SetOption("profile", "general.disableSanctuaries", v) end
            },
            combatzone = {
                name = L["Disable in Combat Zones (Wintergrasp)"],
                desc = L["Disables Stalker in combat zones like Wintergrasp."],
                order = 7,
                type = "toggle",
                width = "full",
                get = function() return StalkerConfig:GetOption("profile", "general.disableCombatZone") end,
                set = function(_, v) StalkerConfig:SetOption("profile", "general.disableCombatZone", v) end
            },
        },
    },
    alerts = {
        name = L["Alert Options"],
        type = "group",
        childGroups = "tab",
        order = 1,
        args = {
            descr = {
                order = 1,
                type = "description",
                name = L["Controls how and when alerts are sent when hostile, KOS, and Tracked players are detected."].."\n",
            },
            global = genAlertCat("global", 1),
            channel = {
                name = "        "..L["Channel Alerts"].."        ",
                type = "group",
                order = 2,
                args = {
                    message = {
                        name = L["Alert Message"],
                        desc = L["Channel message sent when using the Alert submenu of players (accessed by right clicking a player in the Stalker Monitor or Viewer)."],
                        order = 1,
                        type = "input",
                        width = "full",
                        get = function() return StalkerConfig:GetOption("profile", "alerts.channel.message") end,
                        set = function(_, v) StalkerConfig:SetOption("profile", "alerts.channel.message", v) end,
                    },
                },
            },
            hostile = genAlertCat("hostile", 3),
            kos = genAlertCat("kos", 4),
            tracked = genAlertCat("tracked", 5),
        },
    },
    monitor = {
        name = L["Monitor Options"],
        type = "group",
        order = 1,
        args = {
            descr = {
                order = 1,
                type = "description",
                name = L["Options related to the Stalker Monitor window."].."\n\n",
            },
            startup = {
                name = L["Show on Startup"],
                desc = L["Shows Stalker Monitor on startup."],
                order = 2,
                type = "toggle",
                width = "full",
                get = function() return StalkerConfig:GetOption("profile", "monitor.startup") end,
                set = function(_, v) StalkerConfig:SetOption("profile", "monitor.startup", v) end
            },
            maxunits = {
                name = L["Maximum Entries"],
                desc = L["The maximum number of hostiles to display in the Stalker Monitor. Default is 10."],
                order = 3,
                type = "range",
                width = "full",
                min = 1,
                max = 40,
                step = 1,
                get = function() return StalkerConfig:GetOption("profile", "monitor.maxunits") end,
                set = function(_, v) StalkerConfig:SetOption("profile", "monitor.maxunits", v) end
            },
            refreshtime = {
                name = L["Refresh Time"],
                desc = L["The time in seconds between Stalker Monitor refreshes. All entries will be re-sorted by last event time. Default is 5 seconds."],
                order = 4,
                type = "range",
                width = "full",
                min = 5,
                max = 20,
                step = 1,
                get = function() return StalkerConfig:GetOption("profile", "monitor.refreshtime") end,
                set = function(_, v) StalkerConfig:SetOption("profile", "monitor.refreshtime", v) end
            },
            fadetime = {
                name = L["Fadeout Time"],
                desc = L["The time in seconds it takes for hostile players to fade and disappear from the Stalker Monitor. New activity will restart this timer. Default is 60 (1 minute)."],
                order = 5,
                type = "range",
                width = "full",
                min = 30,
                max = 210,
                step = 1,
                get = function() return StalkerConfig:GetOption("profile", "monitor.fadetime") end,
                set = function(_, v) StalkerConfig:SetOption("profile", "monitor.fadetime", v) end
            },
            anchor = {
                name = L["Anchor Point"],
                desc = L["Where to anchor the Stalker Monitor. |cffffff00Top|r will grow the Monitor downward. |cffffff00Bottom|r grow upward. |cffffff00Center|r will grow in both directions"],
                order = 6,
                type = "select",
                values = {["CENTER"]="Center", ["TOP"]="Top", ["BOTTOM"]="Bottom"},
                get = function() return StalkerConfig:GetOption("profile", "monitor.anchor") end,
                set = function(_, v) StalkerConfig:SetOption("profile", "monitor.anchor", v) end
            },
            reset = {
                name = L["Reset Position"],
                desc = L["Reset Stalker Monitor position to center of screen"],
                type = "execute",
                order = 7,
                func = function() StalkerMonitor:ResetPosition() end,
            },
        },
    },
}

local defaults = {
    profile = {
        general = {
            enabled = true,
            disableSanctuaries = true,
            disableCombatZone = true,
            tooltips = {
                enabled = true,
            },
            minimapicon = {
                hide = false,
                minimapPos = 220,
                radius = 80,
            },
            agent = {
                enabled = true,
            },
        },
        monitor = {
            startup = true,
            maxunits = 10,
            refreshtime = 5,
            fadetime = 60,
            position = {
                x = 0,
                y = 0,
                w = 154,
            },
            anchor = "TOP",
        },
        alerts = {
            global = {
                sound = {
                    enabled = true,
                    interval = DEFAULT_SOUND_INTERVAL,
                },
                flash = {
                    enabled = true,
                    interval = DEFAULT_FLASH_INTERVAL,
                },
                console = {
                    enabled = true,
                    message = DEFAULT_CONSOLE_MESSAGE,
                    interval = DEFAULT_CONSOLE_INTERVAL,
                },
                screen = {
                    enabled = true,
                    message = DEFAULT_SCREEN_MESSAGE,
                    interval = DEFAULT_SCREEN_INTERVAL,
                },
            },
            hostile = {
                enabled = false,
                sound = {
                    enabled = 2,
                    interval = DEFAULT_SOUND_INTERVAL,
                },
                flash = {
                    enabled = 2,
                    interval = DEFAULT_FLASH_INTERVAL,
                },
                console = {
                    enabled = 2,
                    message = DEFAULT_CONSOLE_MESSAGE,
                    interval = DEFAULT_CONSOLE_INTERVAL,
                },
                screen = {
                    enabled = 2,
                    message = DEFAULT_SCREEN_MESSAGE,
                    interval = DEFAULT_SCREEN_INTERVAL,
                },
            },
            kos = {
                enabled = true,
                sound = {
                    enabled = 2,
                    interval = DEFAULT_SOUND_INTERVAL,
                },
                flash = {
                    enabled = 2,
                    interval = DEFAULT_FLASH_INTERVAL,
                },
                console = {
                    enabled = 2,
                    message = DEFAULT_CONSOLE_MESSAGE,
                    interval = DEFAULT_CONSOLE_INTERVAL,
                },
                screen = {
                    enabled = 2,
                    message = DEFAULT_SCREEN_MESSAGE,
                    interval = DEFAULT_SCREEN_INTERVAL,
                },
            },
            tracked = {
                enabled = true,
                sound = {
                    enabled = 2,
                    interval = DEFAULT_SOUND_INTERVAL,
                },
                flash = {
                    enabled = 2,
                    interval = DEFAULT_FLASH_INTERVAL,
                },
                console = {
                    enabled = 2,
                    message = DEFAULT_CONSOLE_MESSAGE,
                    interval = DEFAULT_CONSOLE_INTERVAL,
                },
                screen = {
                    enabled = 2,
                    message = DEFAULT_SCREEN_MESSAGE,
                    interval = DEFAULT_SCREEN_INTERVAL,
                },
            },
            channel = {
                message = L["Alert! %faction player %enemy detected near %source %time ago in %zone at %coords"],
            },
        },
    },
    factionrealm = {
        units = {
            players = {},
            guilds = {},
        },
    },
}

-- make dbIndex a memoizing table capable of hashed string lookups into the db
-- table contents. this allows us to translate something like options["profile.general.agent.enabled"]
-- into a function pointing to that value in the db table

-- the function that parses the string key and returns the table and key it
-- represents. so parsing the key "profile.general.agent.enabled" would
-- return the table db.profile.general.agent and the string "enabled"
local function parse(key)
    local cfg
    local set
    local opt = db
    for _, val in pairs({strsplit(".", key)}) do
        opt = opt[val]
        if opt == nil then error("Specified option not found ("..key..")", 2) end
        if type(opt) == "table" then
            cfg = opt
        else
            set = val
        end
    end
    return cfg, set
end

-- takes the string key and returns a function that returns the value the
-- key represents. because this turns dbIndex into a memoizing table the
-- results are cached.
setmetatable(dbIndex, {
    __index = function(tbl, key)
        local cfg, set = parse(key)
        local fnc = function()
            local ret
            if set then ret = cfg[set] else ret = cfg end
            return ret
        end
        rawset(tbl, key, fnc)
        return fnc
    end,
})


function StalkerConfig:Initialize()
    db = LibStub("AceDB-3.0"):New("StalkerDB", defaults, "Default")
    LibStub("AceConfig-3.0"):RegisterOptionsTable("Stalker", options.main)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("StalkerGeneral", options.general)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("StalkerMonitor", options.monitor)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("StalkerAlerts", options.alerts)
    self.BlizOptions = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Stalker", "Stalker")
    self.BlizOptionsGeneral = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("StalkerGeneral", "General Options", "Stalker")
    self.BlizOptionsAlerts = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("StalkerAlerts", "Alert Options", "Stalker")
    self.BlizOptionsMonitor = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("StalkerMonitor", "Monitor Options", "Stalker")

    StalkerData:SetSavedVariablesDb(db)
end

function StalkerConfig:RegisterForUpdates(type, option, func)
    local key = type.."."..option
    if not updates[key] then updates[key] = {} end
    table.insert(updates[type.."."..option], func)
end

function StalkerConfig:GetOption(type, option)
    return dbIndex[type.."."..option]()
end

function StalkerConfig:SetOption(type, option, value)
    local key = type.."."..option
    local cfg, set = parse(key)
    cfg[set] = value
    if updates[key] then
        for _, func in ipairs(updates[key]) do
            func(value, option, type)
        end
    end
end