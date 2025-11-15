-- =====================================================
-- WORLD SEARCH SYSTEM - CLIENT UI
-- =====================================================

local WorldSearchUI = {}

-- UI State
WorldSearchUI.showProgressBar = false
WorldSearchUI.progressValue = 0.0
WorldSearchUI.progressText = ""
WorldSearchUI.notifications = {}
WorldSearchUI.debugZones = {} -- Store zones for debug visualization
WorldSearchUI.showDebugBoxes = false

-- Prompt state tracking
WorldSearchUI.currentPromptZone = nil
WorldSearchUI.promptActive = false
WorldSearchUI.lastPromptCheck = 0

-- Initialize UI system
function WorldSearchUI.Initialize()
    WorldSearchUI.showDebugBoxes = WorldSearchConfig.ShowDebugBoxes or false
    WorldSearchUtils.DebugPrint("Search UI initialized - Debug boxes: %s", tostring(WorldSearchUI.showDebugBoxes))
end

-- Add debug zone for visualization
function WorldSearchUI.AddDebugZone(zoneData)
    if not WorldSearchUI.showDebugBoxes then
        return
    end
    
    local debugZone = {
        id = zoneData.id,
        coords = zoneData.coords,
        range = zoneData.range or 2.0,
        name = zoneData.name or "Unknown Zone",
        color = WorldSearchConfig.BoxDebugColor or {r = 255, g = 0, b = 0, a = 100},
        outline = WorldSearchConfig.BoxDebugOutline or {r = 255, g = 255, b = 255, a = 255}
    }
    
    WorldSearchUI.debugZones[zoneData.id] = debugZone
    WorldSearchUtils.DebugPrint("Added debug zone: %s at %.1f,%.1f,%.1f", debugZone.name, debugZone.coords.x, debugZone.coords.y, debugZone.coords.z)
end

-- Remove debug zone
function WorldSearchUI.RemoveDebugZone(zoneId)
    if WorldSearchUI.debugZones[zoneId] then
        WorldSearchUI.debugZones[zoneId] = nil
        WorldSearchUtils.DebugPrint("Removed debug zone: %s", zoneId)
    end
end

-- Toggle debug boxes on/off
function WorldSearchUI.ToggleDebugBoxes()
    WorldSearchUI.showDebugBoxes = not WorldSearchUI.showDebugBoxes
    WorldSearchUtils.DebugPrint("Debug boxes toggled: %s", tostring(WorldSearchUI.showDebugBoxes))
    return WorldSearchUI.showDebugBoxes
end

-- Get debug zones (for debugging)
function WorldSearchUI.GetDebugZones()
    return WorldSearchUI.debugZones
end

-- Draw debug boxes around interaction zones
function WorldSearchUI.DrawDebugBoxes()
    if not WorldSearchUI.showDebugBoxes or not WorldSearchConfig.Debug then
        return
    end
    
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for zoneId, zone in pairs(WorldSearchUI.debugZones) do
        local distance = #(playerCoords - vector3(zone.coords.x, zone.coords.y, zone.coords.z))
        
        -- Only draw zones within reasonable distance to avoid performance issues
        if distance < 100.0 then
            -- Draw the interaction sphere/box
            WorldSearchUI.DrawZoneBox(zone)
            
            -- Draw zone label if close enough
            if distance < 25.0 then
                WorldSearchUI.DrawZoneLabel(zone, distance)
            end
        end
    end
end

-- Draw a 3D box around the zone
function WorldSearchUI.DrawZoneBox(zone)
    local coords = vector3(zone.coords.x, zone.coords.y, zone.coords.z)
    local range = zone.range
    
    -- Draw the box outline (8 corners connected)
    local corners = {
        vector3(coords.x - range, coords.y - range, coords.z - 1.0),
        vector3(coords.x + range, coords.y - range, coords.z - 1.0),
        vector3(coords.x + range, coords.y + range, coords.z - 1.0),
        vector3(coords.x - range, coords.y + range, coords.z - 1.0),
        vector3(coords.x - range, coords.y - range, coords.z + 2.0),
        vector3(coords.x + range, coords.y - range, coords.z + 2.0),
        vector3(coords.x + range, coords.y + range, coords.z + 2.0),
        vector3(coords.x - range, coords.y + range, coords.z + 2.0),
    }
    
    local color = zone.outline
    
    -- Draw bottom square
    DrawLine(corners[1].x, corners[1].y, corners[1].z, corners[2].x, corners[2].y, corners[2].z, color.r, color.g, color.b, color.a)
    DrawLine(corners[2].x, corners[2].y, corners[2].z, corners[3].x, corners[3].y, corners[3].z, color.r, color.g, color.b, color.a)
    DrawLine(corners[3].x, corners[3].y, corners[3].z, corners[4].x, corners[4].y, corners[4].z, color.r, color.g, color.b, color.a)
    DrawLine(corners[4].x, corners[4].y, corners[4].z, corners[1].x, corners[1].y, corners[1].z, color.r, color.g, color.b, color.a)
    
    -- Draw top square
    DrawLine(corners[5].x, corners[5].y, corners[5].z, corners[6].x, corners[6].y, corners[6].z, color.r, color.g, color.b, color.a)
    DrawLine(corners[6].x, corners[6].y, corners[6].z, corners[7].x, corners[7].y, corners[7].z, color.r, color.g, color.b, color.a)
    DrawLine(corners[7].x, corners[7].y, corners[7].z, corners[8].x, corners[8].y, corners[8].z, color.r, color.g, color.b, color.a)
    DrawLine(corners[8].x, corners[8].y, corners[8].z, corners[5].x, corners[5].y, corners[5].z, color.r, color.g, color.b, color.a)
    
    -- Draw vertical lines
    DrawLine(corners[1].x, corners[1].y, corners[1].z, corners[5].x, corners[5].y, corners[5].z, color.r, color.g, color.b, color.a)
    DrawLine(corners[2].x, corners[2].y, corners[2].z, corners[6].x, corners[6].y, corners[6].z, color.r, color.g, color.b, color.a)
    DrawLine(corners[3].x, corners[3].y, corners[3].z, corners[7].x, corners[7].y, corners[7].z, color.r, color.g, color.b, color.a)
    DrawLine(corners[4].x, corners[4].y, corners[4].z, corners[8].x, corners[8].y, corners[8].z, color.r, color.g, color.b, color.a)
    
    -- Draw a semi-transparent filled area (ground level)
    local fillColor = zone.color
    DrawPoly(
        corners[1].x, corners[1].y, corners[1].z,
        corners[2].x, corners[2].y, corners[2].z,
        corners[3].x, corners[3].y, corners[3].z,
        fillColor.r, fillColor.g, fillColor.b, fillColor.a
    )
    DrawPoly(
        corners[1].x, corners[1].y, corners[1].z,
        corners[3].x, corners[3].y, corners[3].z,
        corners[4].x, corners[4].y, corners[4].z,
        fillColor.r, fillColor.g, fillColor.b, fillColor.a
    )
end

-- Draw zone label with information
function WorldSearchUI.DrawZoneLabel(zone, distance)
    local coords = vector3(zone.coords.x, zone.coords.y, zone.coords.z + 1.5)
    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z)
    
    if onScreen then
        local labelText = string.format("%s\nRange: %.1fm\nDist: %.1fm", zone.name, zone.range, distance)
        
        -- Background
        local lineCount = 3
        local lineHeight = 0.025
        local bgHeight = lineCount * lineHeight + 0.01
        DrawRect(screenX, screenY, 0.15, bgHeight, 0, 0, 0, 180)
        
        -- Text
        SetTextFont(4)
        SetTextProportional(1)
        SetTextScale(0.3, 0.3)
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(1, 0, 0, 0, 255)
        SetTextCentre(true)
        
        BeginTextCommandDisplayText("STRING")
        AddTextComponentSubstringPlayerName(labelText)
        EndTextCommandDisplayText(screenX, screenY - (bgHeight/2) + 0.01)
    end
end

-- Show search progress bar
function WorldSearchUI.ShowProgress(text, duration)
    WorldSearchUI.showProgressBar = true
    WorldSearchUI.progressValue = 0.0
    WorldSearchUI.progressText = text or "Searching..."
    
    local startTime = GetGameTimer()
    
    CreateThread(function()
        while WorldSearchUI.showProgressBar do
            Wait(0)
            
            -- Calculate progress
            local elapsed = GetGameTimer() - startTime
            WorldSearchUI.progressValue = math.min(elapsed / duration, 1.0)
            
            -- Draw the progress bar
            WorldSearchUI.DrawProgressBar()
            
            -- Auto-hide when complete
            if WorldSearchUI.progressValue >= 1.0 then
                WorldSearchUI.HideProgress()
                break
            end
        end
    end)
end

-- Hide progress bar
function WorldSearchUI.HideProgress()
    WorldSearchUI.showProgressBar = false
    WorldSearchUI.progressValue = 0.0
    WorldSearchUI.progressText = ""
end

-- Draw progress bar
function WorldSearchUI.DrawProgressBar()
    if not WorldSearchUI.showProgressBar then
        return
    end
    
    local progress = WorldSearchUI.progressValue
    local x, y = 0.5, 0.85
    local width, height = 0.3, 0.025
    local color = WorldSearchConfig.ProgressBarColor or {r = 255, g = 165, b = 0}
    
    -- Background
    DrawRect(x, y, width, height, 0, 0, 0, 180)
    
    -- Progress fill
    local fillWidth = width * progress
    DrawRect(x - (width/2) + (fillWidth/2), y, fillWidth, height, color.r, color.g, color.b, 220)
    
    -- Border
    DrawRect(x, y, width + 0.002, height + 0.002, 255, 255, 255, 255)
    
    -- Progress text
    WorldSearchUI.DrawText(WorldSearchUI.progressText, x, y - 0.04, 0.4, {255, 255, 255, 255}, true)
    
    -- Percentage
    local percentage = string.format("%.0f%%", progress * 100)
    WorldSearchUI.DrawText(percentage, x, y + 0.02, 0.35, {255, 255, 255, 200}, true)
    
    -- Cancel instruction
    WorldSearchUI.DrawText("Press ~r~ESC~w~ to cancel", x, y + 0.055, 0.3, {255, 255, 255, 150}, true)
end

-- Enhanced text drawing function
function WorldSearchUI.DrawText(text, x, y, scale, color, center, font)
    font = font or 4
    color = color or {255, 255, 255, 255}
    
    SetTextFont(font)
    SetTextProportional(1)
    SetTextScale(scale, scale)
    SetTextColour(color[1], color[2], color[3], color[4])
    SetTextDropshadow(1, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    
    if center then
        SetTextCentre(true)
    end
    
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

-- Show floating notification
function WorldSearchUI.ShowNotification(message, type, duration)
    type = type or "info"
    duration = duration or 4000
    
    local notification = {
        message = message,
        type = type,
        startTime = GetGameTimer(),
        duration = duration,
        alpha = 0
    }
    
    table.insert(WorldSearchUI.notifications, notification)
    
    -- Auto-remove after duration
    CreateThread(function()
        Wait(duration + 1000) -- Extra time for fade out
        for i, notif in ipairs(WorldSearchUI.notifications) do
            if notif == notification then
                table.remove(WorldSearchUI.notifications, i)
                break
            end
        end
    end)
end

-- Draw notifications
function WorldSearchUI.DrawNotifications()
    if #WorldSearchUI.notifications == 0 then
        return
    end
    
    local baseY = 0.1
    local spacing = 0.05
    
    for i, notification in ipairs(WorldSearchUI.notifications) do
        local elapsed = GetGameTimer() - notification.startTime
        local progress = elapsed / notification.duration
        
        -- Calculate alpha for fade in/out effect
        local alpha = 255
        if progress < 0.1 then
            -- Fade in
            alpha = math.floor(255 * (progress / 0.1))
        elseif progress > 0.8 then
            -- Fade out
            alpha = math.floor(255 * ((1.0 - progress) / 0.2))
        end
        
        if alpha > 0 then
            local y = baseY + (spacing * (i - 1))
            local color = WorldSearchUI.GetNotificationColor(notification.type)
            color[4] = alpha
            
            -- Background
            DrawRect(0.5, y, 0.35, 0.04, 0, 0, 0, math.floor(alpha * 0.7))
            
            -- Text
            WorldSearchUI.DrawText(notification.message, 0.5, y - 0.015, 0.35, color, true, 4)
        end
    end
end

-- Get color for notification type
function WorldSearchUI.GetNotificationColor(type)
    local colors = {
        info = {255, 255, 255, 255},
        success = {46, 204, 113, 255},
        error = {231, 76, 60, 255},
        warning = {241, 196, 15, 255}
    }
    
    return colors[type] or colors.info
end

-- Show loot discovery effect
function WorldSearchUI.ShowLootEffect(loot)
    if not loot or loot.item == "nothing" then
        return
    end
    
    -- Play particle effect (if available)
    WorldSearchUI.PlayLootParticles()
    
    -- Show special notification for loot
    local message = loot.message
    if not message or message == "" then
        if loot.item == "money" then
            message = string.format("Found $%d", loot.amount)
        else
            message = string.format("Found %s x%d", loot.item, loot.amount)
        end
    end
    
    WorldSearchUI.ShowNotification(message, "success", 5000)
    
    -- Screen effect
    WorldSearchUI.PlayScreenEffect("MP_CELEBRATION", 1000)
end

-- Play particle effects for loot discovery
function WorldSearchUI.PlayLootParticles()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    -- Request particle effect
    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do
        Wait(10)
    end
    
    -- Play sparkle effect
    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedAtCoord("ent_sht_money", coords.x, coords.y, coords.z + 1.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
end

-- Play screen effect
function WorldSearchUI.PlayScreenEffect(effectName, duration)
    RequestStreamedTextureDict(effectName)
    
    CreateThread(function()
        StartScreenEffect(effectName, duration, false)
        Wait(duration)
        StopScreenEffect(effectName)
    end)
end

-- Show interaction hint
function WorldSearchUI.ShowInteractionHint(text, key)
    key = key or "E"
    local hintText = string.format("Press ~INPUT_CONTEXT~ %s", text)
    
    CreateThread(function()
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 100 do -- Show for 100ms
            Wait(0)
            WorldSearchUI.DrawText(hintText, 0.5, 0.9, 0.4, {255, 255, 255, 255}, true)
        end
    end)
end

-- Main UI rendering loop
CreateThread(function()
    while true do
        Wait(0)
        
        -- Draw notifications
        WorldSearchUI.DrawNotifications()
        
        -- Draw debug boxes if enabled
        WorldSearchUI.DrawDebugBoxes()
        
        -- Draw interaction prompts
        WorldSearchUI.DrawInteractionPrompts()
        
        -- Other UI elements are drawn in their respective functions
    end
end)

-- Draw interaction prompts (with debouncing to prevent spam)
function WorldSearchUI.DrawInteractionPrompts()
    local currentTime = GetGameTimer()
    
    -- Throttle prompt checks to prevent spam
    local throttleTime = WorldSearchConfig.PromptThrottleTime or 100
    if currentTime - WorldSearchUI.lastPromptCheck < throttleTime then
        return
    end
    WorldSearchUI.lastPromptCheck = currentTime
    
    -- Check if world-search client has a current zone
    if exports['world-search'] and exports['world-search'].GetCurrentZone then
        local currentZone = exports['world-search']:GetCurrentZone()
        local shouldShow = currentZone and exports['world-search']:ShouldShowPrompt()
        
        -- Check if zone changed
        local zoneId = currentZone and (currentZone.name or currentZone.id) or nil
        local zoneChanged = WorldSearchUI.currentPromptZone ~= zoneId
        
        if shouldShow and zoneChanged then
            -- New zone entered - show prompt once
            WorldSearchUI.currentPromptZone = zoneId
            WorldSearchUI.promptActive = true
            
            local promptText = currentZone.prompt or "Press ~INPUT_CONTEXT~ to search"
            
            -- Show notification using unified UI system
            local duration = WorldSearchConfig.NotificationDuration or 3000
            local notificationSuccess = false
            
            if GetResourceState('interaction_core') == 'started' then
                local exportSuccess, exportResult = pcall(function()
                    return exports['interaction_core'] and exports['interaction_core'].ShowUnifiedNotification
                end)
                
                if exportSuccess and exportResult then
                    local callSuccess = pcall(function()
                        exports['interaction_core']:ShowUnifiedNotification(promptText, "info", duration)
                    end)
                    notificationSuccess = callSuccess
                end
            end
            
            if not notificationSuccess then
                -- Fallback to world-search notification system
                WorldSearchUI.ShowNotification(promptText, "info", duration)
            end
            
        elseif shouldShow and WorldSearchUI.promptActive then
            -- Still in zone - show unified prompt occasionally
            local interval = WorldSearchConfig.HelpTextInterval or 2000
            if currentTime % interval < throttleTime then -- Show every interval for throttleTime duration
                local promptText = currentZone.prompt or "Press E to search"
                
                -- Use unified prompt system with safe checking
                local promptSuccess = false
                if GetResourceState('interaction_core') == 'started' then
                    local exportSuccess, exportResult = pcall(function()
                        return exports['interaction_core'] and exports['interaction_core'].ShowUnifiedPrompt
                    end)
                    
                    if exportSuccess and exportResult then
                        local callSuccess = pcall(function()
                            exports['interaction_core']:ShowUnifiedPrompt(promptText, "info")
                        end)
                        promptSuccess = callSuccess
                    end
                end
                
                if not promptSuccess then
                    -- Fallback to old help text system
                    BeginTextCommandDisplayHelp("STRING")
                    AddTextComponentSubstringPlayerName(currentZone.prompt or "Press ~INPUT_CONTEXT~ to search")
                    EndTextCommandDisplayHelp(0, false, true, -1)
                end
            end
            
        elseif not shouldShow and WorldSearchUI.promptActive then
            -- Left interaction area
            WorldSearchUI.currentPromptZone = nil
            WorldSearchUI.promptActive = false
        end
    else
        -- No export available, reset state
        if WorldSearchUI.promptActive then
            WorldSearchUI.currentPromptZone = nil
            WorldSearchUI.promptActive = false
        end
    end
end

-- Initialize UI
CreateThread(function()
    Wait(1000)
    WorldSearchUI.Initialize()
    WorldSearchUtils.DebugPrint("UI system initialized with %d debug zones", 
        WorldSearchUI.debugZones and #WorldSearchUI.debugZones or 0)
end)

-- Export functions
exports('ShowProgress', WorldSearchUI.ShowProgress)
exports('HideProgress', WorldSearchUI.HideProgress)
exports('ShowNotification', WorldSearchUI.ShowNotification)
exports('ShowLootEffect', WorldSearchUI.ShowLootEffect)
exports('ShowInteractionHint', WorldSearchUI.ShowInteractionHint)
exports('AddDebugZone', WorldSearchUI.AddDebugZone)
exports('RemoveDebugZone', WorldSearchUI.RemoveDebugZone)
exports('ToggleDebugBoxes', WorldSearchUI.ToggleDebugBoxes)
exports('GetDebugZones', WorldSearchUI.GetDebugZones)