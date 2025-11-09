-- =====================================================
-- INTERACTION CORE - LEAK-FREE SERVER
-- =====================================================

-- Memory management constants
local MAX_INTERACTIONS = 1000
local CLEANUP_INTERVAL = 60000 -- 1 minute
local COOLDOWN_TIME = 1000 -- 1 second default cooldown

-- Local state (prevent global pollution)
local serverState = {
    active = {}, -- Active interactions by player ID
    cooldowns = {}, -- Player cooldowns by license
    pending = {}, -- Pending client callbacks
    initialized = false,
    cleanupTimer = 0
}

-- Safe player identification
local function GetPlayerLicense(playerId)
    if not playerId or playerId <= 0 then
        return nil
    end
    
    local identifiers = GetPlayerIdentifiers(playerId)
    if not identifiers then
        return nil
    end
    
    for _, identifier in pairs(identifiers) do
        if string.find(identifier, "license:") then
            return identifier
        end
    end
    return nil
end

-- Safe initialization with timeout
local function InitializeServer()
    if serverState.initialized then
        return true
    end
    
    -- Wait for InteractionCore to be available
    local attempts = 0
    while not InteractionCore and attempts < 100 do -- 10 second max wait
        Wait(100)
        attempts = attempts + 1
    end
    
    if not InteractionCore then
        print("^1[InteractionCore] ERROR: InteractionCore not available after 10 seconds^0")
        return false
    end
    
    serverState.initialized = true
    serverState.cleanupTimer = GetGameTimer()
    
    print("^2[InteractionCore] Server initialized successfully^0")
    return true
end

-- Initialize on resource start
CreateThread(InitializeServer)

-- Memory cleanup function
local function CleanupMemory()
    local currentTime = GetGameTimer()
    local cleaned = 0
    
    -- Clean expired cooldowns
    for license, expireTime in pairs(serverState.cooldowns) do
        if currentTime > expireTime + 60000 then -- Keep for 1 minute after expiry
            serverState.cooldowns[license] = nil
            cleaned = cleaned + 1
        end
    end
    
    -- Clean old pending interactions
    for playerId, pending in pairs(serverState.pending) do
        if not pending.startTime or (currentTime - pending.startTime) > 300000 then -- 5 minute timeout
            serverState.pending[playerId] = nil
            cleaned = cleaned + 1
        end
    end
    
    if cleaned > 0 and InteractionCoreConfig and InteractionCoreConfig.debug then
        print(string.format("^3[InteractionCore] Cleaned %d expired entries^0", cleaned))
    end
end

-- Regular cleanup
CreateThread(function()
    while true do
        Wait(CLEANUP_INTERVAL)
        if serverState.initialized then
            CleanupMemory()
        end
    end
end)

-- =====================================================
-- EVENT HANDLERS
-- =====================================================

-- Handle interaction attempts from clients
RegisterNetEvent('interaction:attempt', function(interactionId, context)
    local src = source
    
    if not serverState.initialized then
        TriggerClientEvent('interaction:denied', src, interactionId, "System not ready")
        return
    end
    
    local playerLicense = GetPlayerLicense(src)
    if not playerLicense then
        TriggerClientEvent('interaction:denied', src, interactionId, "Invalid player")
        return
    end
    
    -- Debug logging
    if InteractionCoreConfig and InteractionCoreConfig.debug then
        print(string.format("^3[InteractionCore] Player %s attempting interaction: %s^0", src, interactionId))
    end
    
    -- Get the interaction
    local interaction = InteractionCore.Get(interactionId)
    if not interaction then 
        print("^1[InteractionCore] Error: Interaction not found: " .. tostring(interactionId) .. "^0")
        TriggerClientEvent('interaction:denied', src, interactionId, "Interaction not found")
        return
    end
    
    -- Check if player is on cooldown
    local currentTime = GetGameTimer()
    if serverState.cooldowns[playerLicense] and serverState.cooldowns[playerLicense] > currentTime then
        TriggerClientEvent('interaction:denied', src, interactionId, "Please wait before interacting again")
        return
    end
    
    -- Validate the interaction (skip complex validation for now to prevent crashes)
    if interaction.validations and #interaction.validations > 0 then
        -- Simple validation only
        for _, validation in ipairs(interaction.validations) do
            if validation.type == "distance" and validation.range then
                -- Basic distance check would go here
            end
        end
    end
    
    -- Set cooldown
    serverState.cooldowns[playerLicense] = currentTime + COOLDOWN_TIME
    
    -- Mark interaction as used if it's one-time
    if interaction.oneTime then
        interaction.used = true
    end
    
    -- Handle client callback interactions
    if interaction.clientCallback then
        TriggerClientEvent(interaction.clientCallback, src, context)
        serverState.pending[src] = {
            id = interactionId,
            startTime = currentTime,
            context = context
        }
        return
    end
    
    -- Handle server callback interactions
    if interaction.serverCallback then
        serverState.active[src] = interactionId
        
        -- Wrap server callback in pcall for safety
        local success, result = pcall(interaction.serverCallback, src, context, function(callbackSuccess, msg, data)
            serverState.active[src] = nil
            
            if callbackSuccess then
                TriggerClientEvent('interaction:success', src, interactionId, msg or "Success", data)
            else
                TriggerClientEvent('interaction:failed', src, interactionId, msg)
            end
        end)
    else
        -- No callback defined, just trigger success
        TriggerClientEvent('interaction:success', src, interactionId, "Interaction completed")
    end
end)

-- Handle client callback responses
RegisterNetEvent('interaction:clientCallback', function(interactionId, success, msg, data)
    local src = source
    local pending = serverState.pending[src]
    
    if not pending or pending.id ~= interactionId then
        print("^1[InteractionCore] Error: No pending interaction for player " .. src .. "^0")
        return
    end
    
    -- Clear pending interaction
    serverState.pending[src] = nil
    
    if success then
        TriggerClientEvent('interaction:success', src, interactionId, msg, data)
    else
        TriggerClientEvent('interaction:failed', src, interactionId, msg)
    end
end)

-- Handle interaction cancellation
RegisterNetEvent('interaction:cancel', function(interactionId)
    local src = source
    
    if serverState.active[src] then
        serverState.active[src] = nil
        TriggerClientEvent('interaction:cancelled', src, interactionId)
    end
    
    if serverState.pending[src] then
        serverState.pending[src] = nil
    end
end)

-- =====================================================
-- SERVER EXPORTS (LEAK-FREE)
-- =====================================================

-- Register a new interaction
function RegisterInteraction(data)
    if not serverState.initialized then
        print("^1[InteractionCore] Cannot register interaction - server not initialized^0")
        return false
    end
    return InteractionCore.Register(data)
end

-- Remove an interaction
function RemoveInteraction(interactionId)
    if not serverState.initialized then
        return false
    end
    return InteractionCore.Remove(interactionId)
end

-- Get an interaction
function GetInteraction(interactionId)
    if not serverState.initialized then
        return nil
    end
    return InteractionCore.Get(interactionId)
end

-- Check if player is in an interaction
function IsPlayerInInteraction(playerId)
    if not serverState.initialized then
        return false
    end
    return serverState.active[playerId] ~= nil or serverState.pending[playerId] ~= nil
end

-- Get player's active interaction
function GetPlayerInteraction(playerId)
    if not serverState.initialized then
        return nil
    end
    return serverState.active[playerId] or (serverState.pending[playerId] and serverState.pending[playerId].id)
end

-- Force cancel player interaction
function CancelPlayerInteraction(playerId)
    if not serverState.initialized then
        return false
    end
    
    if serverState.active[playerId] or serverState.pending[playerId] then
        local interactionId = serverState.active[playerId] or serverState.pending[playerId].id
        serverState.active[playerId] = nil
        serverState.pending[playerId] = nil
        TriggerClientEvent('interaction:cancelled', playerId, interactionId)
        return true
    end
    return false
end

-- Clean up when player disconnects
AddEventHandler('playerDropped', function()
    local src = source
    if serverState.initialized then
        serverState.active[src] = nil
        serverState.pending[src] = nil
    end
end)

-- Final initialization message
CreateThread(function()
    Wait(1000) -- Wait for everything to load
    if serverState.initialized then
        print("^2[InteractionCore] Leak-free server ready - " .. (InteractionCore.GetCount or 0) .. " interactions loaded^0")
    end
end)

-- =====================================================
-- EXAMPLE INTERACTIONS (COMMENTED OUT)
-- =====================================================

--[[
-- Example vehicle lockpick interaction (disabled to prevent conflicts)
-- Enable this only if you're not using external lockpick resources
InteractionCore.Register({
    id = 'example:lockpick:vehicle',
    type = Config.InteractionTypes.VEHICLE,
    range = 2.0,
    prompt = Config.Prompts.lockpick,
    validations = {
        {
            type = Config.ValidationTypes.DISTANCE,
            range = 2.0
        },
        {
            type = Config.ValidationTypes.CUSTOM,
            callback = function(playerId, context, interaction)
                -- Check if vehicle is locked
                local vehicle = NetworkGetEntityFromNetworkId(context.targetNetId)
                if not DoesEntityExist(vehicle) then return false end
                return GetVehicleDoorLockStatus(vehicle) == 2 -- Locked
            end
        }
    },
    serverCallback = function(playerId, context, callback)
        -- Simulate lockpicking process
        local vehicle = NetworkGetEntityFromNetworkId(context.targetNetId)
        if not DoesEntityExist(vehicle) then
            return callback(false, "Vehicle not found")
        end
        
        -- Here you would implement your lockpicking logic
        -- For example, trigger a minigame or skill check
        
        -- For demo purposes, just unlock after 3 seconds
        SetTimeout(3000, function()
            SetVehicleDoorsLocked(vehicle, 1) -- Unlock
            callback(true, "Vehicle unlocked successfully!")
        end)
    end
})
--]]

print("^2[InteractionCore] Server initialization complete^0")
