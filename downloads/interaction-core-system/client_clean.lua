-- Vehicle Interaction System
-- Helps players interact with nearby vehicles (like lockpicking)

-- Keep track of what the player is doing
local playerState = {
    nearbyInteraction = nil,
    isBusy = false,
    showingPrompt = false,
    systemReady = false
}

-- How often to check for nearby vehicles (in milliseconds)
local NORMAL_CHECK_SPEED = 500 -- When looking for interactions
local SLOW_CHECK_SPEED = 2000 -- When nothing is happening

-- Make sure the interaction system is ready before we start
local function WaitForSystemToLoad()
    if playerState.systemReady then
        return true
    end
    
    -- Give the system up to 10 seconds to load
    local waitTime = 0
    while not InteractionCore and waitTime < 100 do
        Wait(100)
        waitTime = waitTime + 1
    end
    
    if not InteractionCore then
        print("^1[Vehicle Interactions] System failed to load properly^0")
        return false
    end
    
    playerState.systemReady = true
    print("^2[Vehicle Interactions] System ready for vehicle lockpicking^0")
    return true
end

-- Main loop that constantly checks for nearby vehicles to interact with
CreateThread(function()
    WaitForSystemToLoad()
    
    while true do
        local checkSpeed = SLOW_CHECK_SPEED
        
        if playerState.systemReady and not playerState.isBusy then
            checkSpeed = NORMAL_CHECK_SPEED
            
            -- Get the player's current position
            local playerPed = PlayerPedId()
            if playerPed and playerPed > 0 then
                local playerCoords = GetEntityCoords(playerPed)
                if playerCoords then
                    local foundNearbyInteraction = LookForNearbyVehicles(playerCoords)
                    
                    -- If player presses E while near a vehicle
                    if playerState.nearbyInteraction and IsControlJustPressed(0, 38) then -- E key
                        TryToInteractWithVehicle()
                        checkSpeed = 100 -- Check faster after player input
                    end
                    
                    -- If no vehicles nearby, slow down the checking
                    if not foundNearbyInteraction then
                        checkSpeed = SLOW_CHECK_SPEED
                    end
                end
            end
        end
        
        Wait(checkSpeed)
    end
end)

-- Look around for vehicles the player can interact with
function LookForNearbyVehicles(playerCoords)
    if not playerCoords or not playerState.systemReady then
        return false
    end
    
    local foundSomething = false
    local closestInteraction = nil
    local closestDistance = 5.0
    
    -- Ask the system for all available interactions
    if InteractionCore and InteractionCore.GetAll then
        local allInteractions = InteractionCore.GetAll()
        if allInteractions then
            for id, interaction in pairs(allInteractions) do
                if interaction and interaction.enabled then
                    -- Simple distance check to prevent crashes
                    local distance = #(playerCoords - vector3(0, 0, 0))
                    
                    if distance <= (interaction.range or 2.0) and distance < closestDistance then
                        closestDistance = distance
                        closestInteraction = interaction
                        foundSomething = true
                    end
                end
            end
        end
    end
    
    -- Update what the player is near
    if closestInteraction ~= playerState.nearbyInteraction then
        -- Player moved away from previous interaction
        if playerState.nearbyInteraction and playerState.nearbyInteraction.onExit then
            pcall(playerState.nearbyInteraction.onExit)
        end
        
        playerState.nearbyInteraction = closestInteraction
        
        -- Player moved near a new interaction
        if playerState.nearbyInteraction then
            if playerState.nearbyInteraction.onEnter then
                pcall(playerState.nearbyInteraction.onEnter)
            end
            ShowHelpPrompt(playerState.nearbyInteraction)
        else
            HideHelpPrompt()
        end
    end
    
    return foundSomething
end

-- Player wants to interact with the nearby vehicle
function TryToInteractWithVehicle()
    if not playerState.nearbyInteraction or playerState.isBusy then
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
    
    -- Prepare info about the interaction
    local interactionInfo = {
        coords = {x = playerCoords.x, y = playerCoords.y, z = playerCoords.z},
        playerPed = playerPed
    }
    
    -- Mark player as busy
    playerState.isBusy = true
    HideHelpPrompt()
    
    -- Tell the server about the interaction attempt
    TriggerServerEvent('interaction:attempt', playerState.nearbyInteraction.id, interactionInfo)
end

-- Show helpful text to the player
function ShowHelpPrompt(interaction)
    if not interaction or not interaction.prompt then
        return
    end
    
    playerState.showingPrompt = true
    
    CreateThread(function()
        while playerState.showingPrompt and playerState.nearbyInteraction == interaction do
            -- Show help text on screen
            BeginTextCommandDisplayHelp("STRING")
            AddTextComponentSubstringPlayerName(interaction.prompt or "Press ~INPUT_CONTEXT~ to interact")
            EndTextCommandDisplayHelp(0, false, true, -1)
            Wait(0)
        end
    end)
end

-- Hide the help text
function HideHelpPrompt()
    playerState.showingPrompt = false
end

-- ===== Server Response Handlers =====

-- The interaction worked successfully
RegisterNetEvent('interaction:success', function(interactionId, message, data)
    playerState.isBusy = false
    
    if message then
        print("^2[Vehicle Interactions] " .. message .. "^0")
    end
end)

-- The interaction failed
RegisterNetEvent('interaction:failed', function(interactionId, message)
    playerState.isBusy = false
    
    if message then
        print("^1[Vehicle Interactions] " .. message .. "^0")
    end
end)

-- The interaction was denied
RegisterNetEvent('interaction:denied', function(interactionId, reason)
    playerState.isBusy = false
    
    if reason then
        print("^3[Vehicle Interactions] " .. reason .. "^0")
    end
end)

-- The interaction was cancelled
RegisterNetEvent('interaction:cancelled', function(interactionId)
    playerState.isBusy = false
    print("^3[Vehicle Interactions] Interaction cancelled^0")
end)

-- The interaction timed out
RegisterNetEvent('interaction:timeout', function(interactionId)
    playerState.isBusy = false
    print("^3[Vehicle Interactions] Interaction timed out^0")
end)

-- ===== Functions for Other Scripts to Use =====

-- Register a new type of interaction
function RegisterInteraction(data)
    if not playerState.systemReady then
        return false
    end
    return InteractionCore and InteractionCore.Register and InteractionCore.Register(data) or false
end

-- Remove an interaction
function RemoveInteraction(interactionId)
    if playerState.nearbyInteraction and playerState.nearbyInteraction.id == interactionId then
        playerState.nearbyInteraction = nil
        HideHelpPrompt()
    end
    return InteractionCore and InteractionCore.Remove and InteractionCore.Remove(interactionId) or false
end

-- Get information about a specific interaction
function GetInteraction(interactionId)
    if not playerState.systemReady then
        return nil
    end
    return InteractionCore and InteractionCore.Get and InteractionCore.Get(interactionId) or nil
end

-- Check if player is currently interacting with something
function IsPlayerBusy()
    return playerState.isBusy
end

-- Get what the player is currently near
function GetCurrentInteraction()
    return playerState.nearbyInteraction
end

-- Force stop current interaction
function CancelCurrentInteraction()
    if playerState.isBusy and playerState.nearbyInteraction then
        TriggerServerEvent('interaction:cancel', playerState.nearbyInteraction.id)
        playerState.isBusy = false
        HideHelpPrompt()
    end
end

print("^2[Vehicle Interactions] Ready to help players interact with vehicles^0")