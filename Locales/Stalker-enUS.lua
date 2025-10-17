local L = LibStub("AceLocale-3.0"):NewLocale("Stalker", "enUS", true)

if L then

    -- Note: Dont translate the work "Stalker"

    L["Monitor"] = true -- as in Stalker Monitor
    L["Viewer"] = true -- as in Stalker Monitor
    L["Level/Class Unknown"] = true
    L["Guilds"] = true
    L["Guild Unknown"] = true
    L["Coordinates"] = true
    L["Distance"] = true
    L["Source"] = true
    L["Last"] = true -- last time player was seen
    L["Seen"] = true -- as in last time seen
    L["ago"] = true -- as in long ago
    L["Flags"] = true -- whether player is kos or tracked
    L["Near You"] = true -- as in close to you

    L["Event View"] = true
    L["History View"] = true
    L["Show Only"] = true

    --
    -- DROPDOWN MENUS
    --

    L["Track"] = true
    L["Tracking"] = true
    L["KOS"] = true -- Kill On Site
    L["KOS Player"] = true -- as in you want add the player to KOS list
    L["KOS Guild"] = true -- as in you want add the guild to KOS list
    L["Guild KOS"] = true -- as in the guild is KOS
    L["Send Alert"] = true
    L["Create Waypoint"] = true
    L["Set Note"] = true
    L["Alerts"] = true
    L["Open Options Panel"] = true
    L["Add KOS Player"] = true
    L["Add KOS Guild"] = true
    L["Enable Hostile Alerting"] = true
    L["Enable KOS Alerting"] = true
    L["Enable Tracked Alerting"] = true
    L["Enter player name to add to KOS list"] = true
    L["Enter guild name to add to KOS list"] = true
    L["Enter note"] = true
    L["Whisper Player Position"] = true
    L["Enter player name to whisper"] = true
    L["|cffffff00Left Click|r |cffffffffto toggle Stalker Monitor|r"] = true
    L["|cffffff00Right Click|r |cffffffffto toggle Stalker Viewer|r"] = true
    L["|cffffff00Shift-Right Click|r |cffffffffto open menu|r"] = true

    L["Player NAME being tracked"] = function(name, tracked)
        return "Player "..name..(tracked and " is now being tracked. You will be alerted if they are detected by yourself or another Stalker user." or " is no longer being tracked")
    end

    L["Player NAME was ACTION your KOS List"] = function(name, kos)
        return "Player "..name.." was "..(kos and "added to" or "removed from").." your KOS list"
    end

    L["Guild NAME was ACTION your KOS List"] = function(name, kos)
        return "Guild "..name.." was "..(kos and "added to" or "removed from").." your KOS list"
    end

    L["The limit on the number of Tracked players has been reached."] = true

    L["Creating a waypoint"] = function(type)
        return string.format("Creating a %s waypoint to the location where you last detected this player. Keep in mind this is the location you were at, not the player.", type)
    end

    L["Waypoints are not supported"] = function(type)
        return string.format("Waypoints are not supported in this version of %s.", type)
    end

    L["Waypoint support requires the Cartographer or TomTom map addon."] = true

    --
    -- ADDON OPTION SCREEN
    --

    L["Addon for detecting, managing, and tracking hostile players."] = true
    L["Toggle the Stalker Monitor"] = true
    L["Toggle the Stalker Viewer"] = true
    L["Open Options Panel"] = true
    L["Reset Stalker Monitor position to center of screen"] = true
    L["Reset Database. Removes all players and guilds from the database."] = true

    --| General Options
    L["General Options"] = true
    L["Options related to the entire addon."] = true
    L["Enable Addon"] = true
    L["Disabling the Stalker addon will turn off all detection and alerting."] = true
    L["Enable Minimap Button"] = true
    L["Displays the Stalker minimap button around the game's Minimap."] = true
    L["Enable Tooltips"] = true
    L["Enables a Stalker tooltip containing information on hostiles."] = true
    L["Enable Agent"] = true
    L["Enables the Stalker Agent to share hostile tracking data with other Stalker addon users. Disabling will prevent you from tracking hostiles."] = true
    L["Disable in Sanctuaries"] = true
    L["Disables Stalker in sanctuary zones where combat is not possible."] = true
    L["Disable in Combat Zones (Wintergrasp)"] = true
    L["Disables Stalker in combat zones like Wintergrasp."] = true

    --| Alert Options
    L["Alert Options"] = true
    L["Controls how and when alerts are sent when hostile, KOS, and Tracked players are detected."] = true

    L["Global Alerts"] = true
    L["Global alert settings which apply the Hostile, KOS, and Tracked categories unless overridden at the category level."] = true
    L["Hostile Alerts"] = true
    L["Alerts sent when any hostile player is detected. Default is disabled."] = true
    L["KOS Alerts"] = true
    L["Alerts sent when KOS players are detected."] = true
    L["Tracked Alerts"] = true
    L["Alerts sent when Tracked players are detected."] = true
    L["Channel Alerts"] = true
    L["Channel message sent when using the Alert submenu of players (accessed by right clicking a player in the Stalker Monitor or Viewer)."] = true

    L["Sound Alerts"] = true
    L["Screen Flash Alerts"] = true
    L["Console Message Alerts"] = true
    L["Screen Message Alerts"] = true
    L["Enables alerting for enabled alerts in this category. This setting can also be controlled via the Stalker minimap icon."] = true

    L["Enable Alert"] = true
    L["Enable Alerting"] = true
    L["Alert Interval Time"] = true
    L["Alert Message"] = true

    L["Plays a sound when this type of hostile is detected."] = true
    L["The time is seconds that must elapse before another sound alert can occur. Default is 120 (2 minutes)."] = true
    L["Flashes the screen when this type of hostile is detected."] = true
    L["The time is seconds that must elapse before another screen flash alert can occur. Default is 120 (2 minutes)."] = true
    L["Sends a message to the console when this type of hostile is detected."] = true
    L["The message to send to the console when this type of hostile is detected."] = true
    L["The time is seconds that must elapse before another console message alert can occur. Default is 0 seconds."] = true
    L["Sends a message to the screen when this type of hostile is detected."] = true
    L["The message to send to the screen when this type of hostile is detected."] = true
    L["The time is seconds that must elapse before another screen message alert can occur. Default is 120 (2 minutes)."] = true

    L["Monitor Options"] = true
    L["Options related to the Stalker Monitor window."] = true
    L["Show on Startup"] = true
    L["Shows Stalker Monitor on startup."] = true
    L["Maximum Entries"] = true
    L["The maximum number of hostiles to display in the Stalker Monitor. Default is 10."] = true
    L["Refresh Time"] = true
    L["The time in seconds between Stalker Monitor refreshes. All entries will be re-sorted by last event time. Default is 5 seconds."] = true
    L["Fadeout Time"] = true
    L["The time in seconds it takes for hostile players to fade and disappear from the Stalker Monitor. New activity will restart this timer. Default is 60 (1 minute)."] = true
    L["Anchor Point"] = true
    L["Where to anchor the Stalker Monitor. |cffffff00Top|r will grow the Monitor downward. |cffffff00Bottom|r grow upward. |cffffff00Center|r will grow in both directions"] = true
    L["Reset Position"] = true

    L["%type player %enemy detected near %source in %zone at %coords"] = true
    L["Stalker %type player %enemy detected near %source!%newline||cffffffff%note||r"] = true
    L["Alert! %faction player %enemy detected near %source %time ago in %zone at %coords"] = true

    --
    -- TOOLTIP PARSERS
    --
    
    L["TT_LEVEL_LINE"] = "^Level [%d?]"
    L["TT_PET_OWNER_LINE"] = "^(%S+)'s "


    ---
    --- STALKER MONITOR
    ---

    L["No Hostiles Detected"] = true
    L["Disabled In Sanctuaries"] = true
    L["Disabled In Combat Zones"] = true
    L["Disabled In Battlegrounds"] = true
    L["Disabled In Instances"] = true

    -- 
    -- STALKER AGENT
    --

    L["Agent is disabled in options"] = true
    L["Agent had issues connecting to the communications channel so is disconnecting. You can try unchecking and rechecking the Enable Agent option in options to reestablish the connection."] = true
    L["Agent was ACTION"] = function(enabled)
        return "Agent was "..(enabled and "enabled" or "disabled")
    end

end