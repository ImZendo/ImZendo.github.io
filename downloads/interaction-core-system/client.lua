-- =====================================================
-- INTERACTION CORE - CLIENT MAIN (LEAK-FREE)
-- =====================================================

-- Client state management
local clientState = {
    initialized = false,
    isInInteraction = false,
    currentInteraction = nil,
    promptActive = false,
    lastCheckTime = 0
}

-- Configuration constants
local UPDATE_INTERVAL = InteractionCoreConfig.ClientUpdateRate or 250
local MAX_UPDATE_INTERVAL = 1000
local PROMPT_UPDATE_RATE = 0

-- =====================================================
-- UNIFIED UI SYSTEM
-- =====================================================

local InteractionUI = {
    currentPrompt = nil,
    currentProgress = nil,
    notifications = {},
    isVisible = false
}

-- Show interaction prompt
function InteractionUI.ShowPrompt(text, key)
    InteractionUI.currentPrompt = {
        text = text or "Press ~INPUT_CONTEXT~ to interact",
        key = key or "E",
        startTime = GetGameTimer()
    }
    InteractionUI.isVisible = true
end

-- Hide interaction prompt
function InteractionUI.HidePrompt()
    InteractionUI.currentPrompt = nil
    InteractionUI.isVisible = false
end

-- Show progress bar
function InteractionUI.ShowProgress(text, duration, progress)
    InteractionUI.currentProgress = {
        text = text or "Processing...",
        duration = duration or 5000,
        progress = progress or 0.0,
        startTime = GetGameTimer()
    }
end

-- Update progress
function InteractionUI.UpdateProgress(progress, text)
    if InteractionUI.currentProgress then
        InteractionUI.currentProgress.progress = math.max(0.0, math.min(1.0, progress))
        if text then
            InteractionUI.currentProgress.text = text
        end
    end
end

-- Hide progress bar
function InteractionUI.HideProgress()
    InteractionUI.currentProgress = nil
end

-- Show notification
function InteractionUI.ShowNotification(text, type, duration)
    local notification = {
        text = text or "Notification",
        type = type or "info", -- "info", "success", "warning", "error"
        duration = duration or 3000,
        startTime = GetGameTimer(),
        alpha = 0
    }
    
    table.insert(InteractionUI.notifications, notification)
    
    -- Auto-remove after duration
    CreateThread(function()
        Wait(duration)
        for i, notif in ipairs(InteractionUI.notifications) do
            if notif == notification then
                table.remove(InteractionUI.notifications, i)
                break
            end
        end
    end)
end

-- Draw modern UI prompt
function InteractionUI.DrawModernPrompt(prompt)
    local pos = InteractionCoreConfig.UI.Positions.prompt
    local size = InteractionCoreConfig.UI.Sizes
    local colors = InteractionCoreConfig.UI.Colors
    
    -- Background
    DrawRect(pos.x, pos.y, size.promptWidth, size.promptHeight, 
        colors.background.r, colors.background.g, colors.background.b, colors.background.a)
    
    -- Border
    DrawRect(pos.x, pos.y, size.promptWidth + 0.002, size.promptHeight + 0.002, 
        colors.primary.r, colors.primary.g, colors.primary.b, 200)
    
    -- Text
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.35, 0.35)
    SetTextColour(colors.text.r, colors.text.g, colors.text.b, colors.text.a)
    SetTextCentre(true)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(prompt.text)
    EndTextCommandDisplayText(pos.x, pos.y - 0.01)
end

-- Draw modern progress bar
function InteractionUI.DrawModernProgress(progress)
    local pos = InteractionCoreConfig.UI.Positions.progress
    local size = InteractionCoreConfig.UI.Sizes
    local colors = InteractionCoreConfig.UI.Colors
    
    -- Background
    DrawRect(pos.x, pos.y, size.progressWidth, size.progressHeight,
        colors.background.r, colors.background.g, colors.background.b, 200)
    
    -- Progress fill
    local fillWidth = size.progressWidth * progress.progress
    DrawRect(pos.x - (size.progressWidth/2) + (fillWidth/2), pos.y, fillWidth, size.progressHeight,
        colors.primary.r, colors.primary.g, colors.primary.b, 220)
    
    -- Border
    DrawRect(pos.x, pos.y, size.progressWidth + 0.002, size.progressHeight + 0.002,
        colors.text.r, colors.text.g, colors.text.b, 255)
    
    -- Progress text
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.3, 0.3)
    SetTextColour(colors.text.r, colors.text.g, colors.text.b, colors.text.a)
    SetTextCentre(true)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(progress.text)
    EndTextCommandDisplayText(pos.x, pos.y - 0.025)
end

-- Draw notification
function InteractionUI.DrawModernNotification(notification, index)
    local pos = InteractionCoreConfig.UI.Positions.notification
    local size = InteractionCoreConfig.UI.Sizes
    local colors = InteractionCoreConfig.UI.Colors
    
    -- Calculate position with offset for multiple notifications
    local yOffset = (size.notificationHeight + 0.01) * index
    local notifY = pos.y + yOffset
    
    -- Fade in/out animation
    local currentTime = GetGameTimer()
    local elapsed = currentTime - notification.startTime
    local fadeInTime = 300
    local fadeOutTime = 500
    
    if elapsed < fadeInTime then
        notification.alpha = (elapsed / fadeInTime) * 255
    elseif elapsed > (notification.duration - fadeOutTime) then
        local remaining = notification.duration - elapsed
        notification.alpha = (remaining / fadeOutTime) * 255
    else
        notification.alpha = 255
    end
    
    -- Choose color based on type
    local bgColor = colors.background
    local borderColor = colors.primary
    
    if notification.type == "success" then
        borderColor = colors.success
    elseif notification.type == "warning" then
        borderColor = colors.warning
    elseif notification.type == "error" then
        borderColor = colors.danger
    end
    
    -- Background
    DrawRect(pos.x, notifY, size.notificationWidth, size.notificationHeight,
        bgColor.r, bgColor.g, bgColor.b, math.floor(notification.alpha * 0.7))
    
    -- Border
    DrawRect(pos.x, notifY, size.notificationWidth + 0.002, size.notificationHeight + 0.002,
        borderColor.r, borderColor.g, borderColor.b, math.floor(notification.alpha))
    
    -- Text
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.35, 0.35)
    SetTextColour(colors.text.r, colors.text.g, colors.text.b, math.floor(notification.alpha))
    SetTextCentre(true)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(notification.text)
    EndTextCommandDisplayText(pos.x, notifY - 0.01)
end

-- Main UI render loop
CreateThread(function()
    while true do
        Wait(0)
        
        if not InteractionCoreConfig.UI or not InteractionCoreConfig.UI.ShowPrompts then
            goto continue
        end
        
        -- Draw prompt
        if InteractionUI.currentPrompt then
            if InteractionCoreConfig.UI.Style == "modern" then
                InteractionUI.DrawModernPrompt(InteractionUI.currentPrompt)
            else
                -- Simple mode - use native help text
                BeginTextCommandDisplayHelp("STRING")
                AddTextComponentSubstringPlayerName(InteractionUI.currentPrompt.text)
                EndTextCommandDisplayHelp(0, false, true, -1)
            end
        end
        
        -- Draw progress bar
        if InteractionUI.currentProgress and InteractionCoreConfig.UI.ShowProgress then
            if InteractionCoreConfig.UI.Style == "modern" then
                InteractionUI.DrawModernProgress(InteractionUI.currentProgress)
            end
        end
        
        -- Draw notifications
        if InteractionCoreConfig.UI.ShowNotifications then
            for i, notification in ipairs(InteractionUI.notifications) do
                if InteractionCoreConfig.UI.Style == "modern" then
                    InteractionUI.DrawModernNotification(notification, i - 1)
                end
            end
        end
        
        ::continue::
    end
end)

-- Safe initialization with improved global access
local function InitializeClient()
    if clientState.initialized then
        return true
    end
    
    -- Wait for InteractionCore to be available with multiple access methods
    local attempts = 0
    while (not InteractionCore and not _G.InteractionCore and not rawget(_G, 'InteractionCore')) and attempts < 100 do -- 10 second max wait
        Wait(100)
        attempts = attempts + 1
    end
    
    -- Try to get InteractionCore from different sources
    local coreRef = InteractionCore or _G.InteractionCore or rawget(_G, 'InteractionCore')
    
    if not coreRef then
        print("^1[InteractionCore] ERROR: InteractionCore not available on client after 10 seconds^0")
        print("^1[InteractionCore] CRITICAL: Exports may not work properly^0")
        -- Don't return false, continue initialization to ensure exports are still available
    else
        -- Ensure global access for other scripts
        _G.InteractionCore = coreRef
        rawset(_G, 'InteractionCore', coreRef)
        print("^2[InteractionCore] Leak-free client initialized - Global access ensured^0")
    end
    
    clientState.initialized = true
    
    -- Test global access for debugging
    CreateThread(function()
        Wait(2000)
        if _G.InteractionCore and _G.InteractionCore.GetAll then
            print("^2[InteractionCore] Confirmed: Global InteractionCore.GetAll accessible to other scripts^0")
        else
            print("^1[InteractionCore] WARNING: Global InteractionCore.GetAll still not accessible^0")
        end
    end)
    
    return true
end

-- Optimized main loop with dynamic intervals
CreateThread(function()
    InitializeClient()
    
    while true do
        local sleep = MAX_UPDATE_INTERVAL
        
        if clientState.initialized and not clientState.isInInteraction then
            sleep = UPDATE_INTERVAL
            
            -- Safe coordinate retrieval
            local playerPed = PlayerPedId()
            if playerPed and playerPed > 0 then
                local coords = GetEntityCoords(playerPed)
                if coords then
                    local hasNearby = CheckForNearbyInteractions(coords)
                    
                    -- Handle interaction input
                    if clientState.currentInteraction and IsControlJustPressed(0, InteractionCoreConfig.DefaultKey) then
                        HandleInteractionAttempt()
                        sleep = 100 -- Quick response after input
                    end
                    
                    -- Reduce update frequency if no interactions nearby
                    if not hasNearby then
                        sleep = MAX_UPDATE_INTERVAL
                    end
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- Check for nearby interactions (optimized, leak-free)
function CheckForNearbyInteractions(playerCoords)
    if not playerCoords or not clientState.initialized then
        return false
    end
    
    local hasNearbyInteraction = false
    local closestInteraction = nil
    local closestDistance = 5.0 -- Default max range
    
    -- Get all interactions safely - try InteractionCore first, then fallback
    local allInteractions = nil
    
    if InteractionCore and InteractionCore.GetAll then
        allInteractions = InteractionCore.GetAll()
    elseif _G.InteractionCore and _G.InteractionCore.GetAll then
        allInteractions = _G.InteractionCore.GetAll()
    end
    
    if allInteractions then
            for id, interaction in pairs(allInteractions) do
            if interaction and interaction.enabled then
                -- Proper distance calculation
                local interactionCoords = nil
                
                -- Handle entity-based interactions first
                if interaction.entity and DoesEntityExist(interaction.entity) then
                    interactionCoords = GetEntityCoords(interaction.entity)
                elseif interaction.coords then
                    -- Handle both vector3 and table coordinate formats
                    if type(interaction.coords) == "table" then
                        -- Create vector3 with fallback if not available
                        if vector3 then
                            interactionCoords = vector3(interaction.coords.x or 0, interaction.coords.y or 0, interaction.coords.z or 0)
                        else
                            interactionCoords = {
                                x = interaction.coords.x or 0,
                                y = interaction.coords.y or 0,
                                z = interaction.coords.z or 0
                            }
                        end
                    else
                        interactionCoords = interaction.coords
                    end
                end
                
                if interactionCoords then
                    
                    local distance = #(playerCoords - interactionCoords)
                    
                    if distance <= (interaction.range or 2.0) and distance < closestDistance then
                        closestDistance = distance
                        closestInteraction = interaction
                        closestInteraction.id = id -- Ensure ID is set
                        hasNearbyInteraction = true
                        
                        if InteractionCoreConfig.Debug then
                            print(string.format("Found nearby interaction: %s at distance %.2f", id, distance))
                        end
                    end
                end
            end
        end
    else
        if InteractionCoreConfig.Debug then
            print("No interactions available - InteractionCore not accessible")
        end
    end
    
    -- Update current interaction safely
    if closestInteraction ~= clientState.currentInteraction then
        if clientState.currentInteraction and clientState.currentInteraction.onExit then
            pcall(clientState.currentInteraction.onExit)
        end
        
        clientState.currentInteraction = closestInteraction
        
        if clientState.currentInteraction then
            if clientState.currentInteraction.onEnter then
                pcall(clientState.currentInteraction.onEnter)
            end
            ShowInteractionPrompt(clientState.currentInteraction)
        else
            HideInteractionPrompt()
        end
    end
    
    return hasNearbyInteraction
end

-- Handle interaction attempt (simplified)
function HandleInteractionAttempt()
    if not clientState.currentInteraction or clientState.isInInteraction then
        return
    end
    
    local playerPed = PlayerPedId()
    if not playerPed or playerPed <= 0 then
        return
    end
    
    local playerCoords = GetEntityCoords(playerPed)
    if not playerCoords then
        return
    end
    
    -- Prepare basic context with entity support
    local context = {
        coords = {x = playerCoords.x, y = playerCoords.y, z = playerCoords.z},
        playerPed = playerPed
    }
    
    -- Add target entity if interaction is entity-based
    if clientState.currentInteraction.entity then
        context.targetEntity = clientState.currentInteraction.entity
        context.targetNetId = NetworkGetNetworkIdFromEntity(clientState.currentInteraction.entity)
    end
    
    -- Set interaction state
    clientState.isInInteraction = true
    HideInteractionPrompt()
    
    -- Send to server
    TriggerServerEvent('interaction:attempt', clientState.currentInteraction.id, context)
end

-- Show interaction prompt (unified UI)
function ShowInteractionPrompt(interaction)
    if not interaction or not interaction.prompt then
        return
    end
    
    -- Use unified UI system
    clientState.promptActive = true
    InteractionUI.ShowPrompt(interaction.prompt, "E")
end

-- Hide interaction prompt
function HideInteractionPrompt()
    clientState.promptActive = false
    InteractionUI.HidePrompt()
end

-- =====================================================
-- EVENT HANDLERS (SIMPLIFIED)
-- =====================================================

-- Handle successful interaction
RegisterNetEvent('interaction:success', function(interactionId, message, data)
    clientState.isInInteraction = false
    
    if message then
        print("^2[Interaction] " .. message .. "^0")
    end
    
    local interaction = InteractionCore.Get(interactionId)
    if interaction and interaction.onSuccess then
        pcall(interaction.onSuccess, data)
    end
end)

-- Handle failed interaction
RegisterNetEvent('interaction:failed', function(interactionId, message)
    clientState.isInInteraction = false
    
    if message then
        print("^1[Interaction] " .. message .. "^0")
    end
    
    local interaction = InteractionCore.Get(interactionId)
    if interaction and interaction.onFailed then
        pcall(interaction.onFailed, message)
    end
end)

-- Handle denied interaction
RegisterNetEvent('interaction:denied', function(interactionId, reason)
    clientState.isInInteraction = false
    
    if reason then
        print("^3[Interaction] " .. reason .. "^0")
    end
end)

-- Handle cancelled interaction
RegisterNetEvent('interaction:cancelled', function(interactionId)
    clientState.isInInteraction = false
    print("^3[Interaction] Interaction cancelled^0")
end)

-- Handle timed out interaction
RegisterNetEvent('interaction:timeout', function(interactionId)
    clientState.isInInteraction = false
    print("^3[Interaction] Interaction timed out^0")
end)

-- =====================================================
-- CLIENT EXPORTS (LEAK-FREE)
-- =====================================================

-- Register a new interaction (client-side only)
function RegisterInteraction(data)
    if not clientState.initialized then
        return false
    end
    return InteractionCore and InteractionCore.Register and InteractionCore.Register(data) or false
end

-- Remove an interaction (client-side only)  
function RemoveInteraction(interactionId)
    if clientState.currentInteraction and clientState.currentInteraction.id == interactionId then
        clientState.currentInteraction = nil
        HideInteractionPrompt()
    end
    return InteractionCore and InteractionCore.Remove and InteractionCore.Remove(interactionId) or false
end

-- Get an interaction
function GetInteraction(interactionId)
    if not clientState.initialized then
        return nil
    end
    return InteractionCore and InteractionCore.Get and InteractionCore.Get(interactionId) or nil
end

-- Get all interactions (for exports)
function GetAllInteractions()
    if not clientState.initialized then
        return {}
    end
    return InteractionCore and InteractionCore.GetAll and InteractionCore.GetAll() or {}
end

-- Check if player is currently in an interaction
function IsPlayerInInteraction()
    return clientState.isInInteraction
end

-- =====================================================
-- UI SYSTEM EXPORTS
-- =====================================================

-- Show interaction prompt via unified UI
function ShowUnifiedPrompt(text, key)
    return InteractionUI.ShowPrompt(text, key)
end

-- Hide interaction prompt via unified UI
function HideUnifiedPrompt()
    return InteractionUI.HidePrompt()
end

-- Show progress bar via unified UI
function ShowUnifiedProgress(text, duration, progress)
    return InteractionUI.ShowProgress(text, duration, progress)
end

-- Update progress bar via unified UI
function UpdateUnifiedProgress(progress, text)
    return InteractionUI.UpdateProgress(progress, text)
end

-- Hide progress bar via unified UI
function HideUnifiedProgress()
    return InteractionUI.HideProgress()
end

-- Show notification via unified UI
function ShowUnifiedNotification(text, type, duration)
    return InteractionUI.ShowNotification(text, type, duration)
end

-- Hide all notifications via unified UI
function HideUnifiedNotification()
    InteractionUI.notifications = {}
end

-- Debug: Log export registration
CreateThread(function()
    Wait(1000)
    print("^6[InteractionCore] Unified UI exports initialized:^0")
    print("^2✓ ShowUnifiedPrompt, HideUnifiedPrompt^0")
    print("^2✓ ShowUnifiedProgress, UpdateUnifiedProgress, HideUnifiedProgress^0") 
    print("^2✓ ShowUnifiedNotification, HideUnifiedNotification^0")
    print("^6[InteractionCore] If you see export errors, restart the resource^0")
end)

-- Get current interaction
function GetCurrentInteraction()
    return clientState.currentInteraction
end

-- Force cancel current interaction
function CancelCurrentInteraction()
    if clientState.isInInteraction and clientState.currentInteraction then
        TriggerServerEvent('interaction:cancel', clientState.currentInteraction.id)
        clientState.isInInteraction = false
        HideInteractionPrompt()
    end
end

-- Cleanup on resource stop to prevent memory leaks
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        clientState.initialized = false
        clientState.isInInteraction = false
        clientState.currentInteraction = nil
        clientState.promptActive = false
        print("^3[InteractionCore] Client cleaned up on resource stop^0")
    end
end)

-- Debug command to test InteractionCore functionality
if InteractionCoreConfig.Debug then
    RegisterCommand('testinteraction', function()
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        
        print("^2=== InteractionCore Test ===^0")
        print("Initialized:", clientState.initialized)
        print("Player coords:", coords.x, coords.y, coords.z)
        print("Current interaction:", clientState.currentInteraction and clientState.currentInteraction.id or "None")
        
        -- Test registration
        local testData = {
            id = 'test:interaction',
            type = InteractionCoreConfig.Types.WORLD,
            coords = {x = coords.x + 2, y = coords.y, z = coords.z},
            range = 3.0,
            prompt = 'Test Interaction'
        }
        
        local success = RegisterInteraction(testData)
        print("Test interaction registered:", success)
        
        -- Test retrieval
        local retrieved = GetInteraction('test:interaction')
        print("Test interaction retrieved:", retrieved ~= nil)
        
        -- Test GetAll
        local all = GetAllInteractions()
        local count = 0
        if all then
            for _ in pairs(all) do count = count + 1 end
        end
        print("Total interactions:", count)
        
        print("^2=== Test Complete ===^0")
    end, false)
end

-- Explicitly export all unified UI functions to ensure they're available
exports('ShowUnifiedPrompt', ShowUnifiedPrompt)
exports('HideUnifiedPrompt', HideUnifiedPrompt)
exports('ShowUnifiedProgress', ShowUnifiedProgress)
exports('UpdateUnifiedProgress', UpdateUnifiedProgress)
exports('HideUnifiedProgress', HideUnifiedProgress)
exports('ShowUnifiedNotification', ShowUnifiedNotification)
exports('HideUnifiedNotification', HideUnifiedNotification)

-- Export core interaction functions
exports('RegisterInteraction', RegisterInteraction)
exports('RemoveInteraction', RemoveInteraction)
exports('GetInteraction', GetInteraction)
exports('GetAllInteractions', GetAllInteractions)
exports('IsPlayerInInteraction', IsPlayerInInteraction)
exports('GetCurrentInteraction', GetCurrentInteraction)
exports('CancelCurrentInteraction', CancelCurrentInteraction)

print("^2[InteractionCore] Leak-free client ready with explicit exports^0")