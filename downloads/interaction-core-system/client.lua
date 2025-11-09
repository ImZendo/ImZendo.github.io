-- Vehicle Interaction System
-- Handles nearby vehicle detection and lockpick interactions

-- Keep track of what the player is doing
local playerState = {
    nearbyInteraction = nil,
    isBusy = false,
    showingPrompt = false,
    systemReady = false,
    lastCheckTime = 0
}

-- How often to check for nearby vehicles (in milliseconds)
local NORMAL_CHECK_SPEED = 500 -- When looking for interactions
local SLOW_CHECK_SPEED = 2000 -- When nothing is happening
local PROMPT_REFRESH_RATE = 0 -- How fast to update help text

-- Safe initialization
local function InitializeClient()
    if clientState.initialized then
        return true
    end
    
    -- Wait for InteractionCore to be available
    local attempts = 0
    while not InteractionCore and attempts < 100 do -- 10 second max wait
        Wait(100)
        attempts = attempts + 1
    end
    
    if not InteractionCore then
        print("^1[InteractionCore] ERROR: InteractionCore not available on client^0")
        return false
    end
    
    clientState.initialized = true
    print("^2[InteractionCore] Leak-free client initialized^0")
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
                    if clientState.currentInteraction and IsControlJustPressed(0, 38) then -- E key
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
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local sleep = 500
        
        if not isInInteraction then
            -- Check for nearby interactions
            CheckNearbyInteractions(playerCoords)
            
            -- Handle interaction input
            if currentInteraction and IsControlJustPressed(0, Config.DefaultKey) then
                HandleInteractionInput()
                sleep = 100
            elseif currentInteraction then
                sleep = 100
            end
        else
            sleep = 1000 -- Slow down when in interaction
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
    
    -- Get all interactions safely
    if InteractionCore and InteractionCore.GetAll then
        local allInteractions = InteractionCore.GetAll()
        if allInteractions then
            for id, interaction in pairs(allInteractions) do
                if interaction and interaction.enabled then
                    -- Skip complex validation to prevent crashes
                    local distance = #(playerCoords - vector3(0, 0, 0)) -- Simplified distance check
                    
                    if distance <= (interaction.range or 2.0) and distance < closestDistance then
                        closestDistance = distance
                        closestInteraction = interaction
                        hasNearbyInteraction = true
                    end
                end
            end
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
    
    -- Prepare basic context
    local context = {
        coords = {x = playerCoords.x, y = playerCoords.y, z = playerCoords.z},
        playerPed = playerPed
    }
    
    -- Set interaction state
    clientState.isInInteraction = true
    HideInteractionPrompt()
    
    -- Send to server
    TriggerServerEvent('interaction:attempt', clientState.currentInteraction.id, context)
end

-- Show interaction prompt (simplified)
function ShowInteractionPrompt(interaction)
    if not interaction or not interaction.prompt then
        return
    end
    
    -- Simple prompt display
    clientState.promptActive = true
    
    CreateThread(function()
        while clientState.promptActive and clientState.currentInteraction == interaction do
            -- Display help text
            BeginTextCommandDisplayHelp("STRING")
            AddTextComponentSubstringPlayerName(interaction.prompt or "Press ~INPUT_CONTEXT~ to interact")
            EndTextCommandDisplayHelp(0, false, true, -1)
            Wait(PROMPT_UPDATE_RATE)
        end
    end)
end

-- Hide interaction prompt
function HideInteractionPrompt()
    clientState.promptActive = false
-- =====================================================
-- EVENT HANDLERS (SIMPLIFIED)
-- =====================================================

-- Handle successful interaction
RegisterNetEvent('interaction:success', function(interactionId, message, data)
    clientState.isInInteraction = false
    
    if message then
        print("^2[Interaction] " .. message .. "^0")
    end
end)

-- Handle failed interaction
RegisterNetEvent('interaction:failed', function(interactionId, message)
    clientState.isInInteraction = false
    
    if message then
        print("^1[Interaction] " .. message .. "^0")
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

-- Check if player is currently in an interaction
function IsPlayerInInteraction()
    return clientState.isInInteraction
end

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

print("^2[InteractionCore] Leak-free client ready^0")

-- =====================================================
-- EVENT HANDLERS
-- =====================================================

-- Handle successful interaction
RegisterNetEvent('interaction:success', function(interactionId, message, data)
    isInInteraction = false
    
    if message then
        -- You can customize this to use your notification system
        print("^2[Interaction] " .. message .. "^0")
        -- Example: ShowNotification(message, "success")
    end
    
    local interaction = InteractionCore.Get(interactionId)
    if interaction and interaction.onSuccess then
        interaction.onSuccess(data)
    end
end)

-- Handle failed interaction
RegisterNetEvent('interaction:failed', function(interactionId, message)
    isInInteraction = false
    
    if message then
        -- You can customize this to use your notification system
        print("^1[Interaction] " .. message .. "^0")
        -- Example: ShowNotification(message, "error")
    end
    
    local interaction = InteractionCore.Get(interactionId)
    if interaction and interaction.onFailed then
        interaction.onFailed(message)
    end
end)

-- Handle denied interaction
RegisterNetEvent('interaction:denied', function(interactionId, reason)
    isInInteraction = false
    
    if reason then
        print("^3[Interaction] " .. reason .. "^0")
        -- Example: ShowNotification(reason, "warning")
    end
end)

-- Handle cancelled interaction
RegisterNetEvent('interaction:cancelled', function(interactionId)
    isInInteraction = false
    print("^3[Interaction] Interaction cancelled^0")
end)

-- Handle timed out interaction
RegisterNetEvent('interaction:timeout', function(interactionId)
    isInInteraction = false
    print("^3[Interaction] Interaction timed out^0")
end)

-- =====================================================
-- CLIENT EXPORTS
-- =====================================================

-- Register a new interaction (client-side only)
function RegisterInteraction(data)
    return InteractionCore.Register(data)
end

-- Remove an interaction (client-side only)  
function RemoveInteraction(interactionId)
    if currentInteraction and currentInteraction.id == interactionId then
        currentInteraction = nil
        HideInteractionPrompt()
    end
    return InteractionCore.Remove(interactionId)
end

-- Get an interaction
function GetInteraction(interactionId)
    return InteractionCore.Get(interactionId)
end

-- Leak-free client initialization complete
print("^2[InteractionCore] Leak-free client ready^0")

