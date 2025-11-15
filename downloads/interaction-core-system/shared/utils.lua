-- =====================================================
-- INTERACTION CORE - CLEAN UTILITIES (LEAK-FREE)
-- =====================================================

-- Standalone InteractionCore namespace (prevent global pollution)
InteractionCore = {
    interactions = {},
    pending = {},
    lastCleanup = 0,
    interactionCount = 0
}

-- Simple interaction object (no complex inheritance)
local function CreateInteraction(data)
    if not data or not data.id then
        return nil
    end
    
    return {
        id = data.id,
        type = data.type or InteractionCoreConfig.Types.CUSTOM,
        range = data.range or InteractionCoreConfig.DefaultRange,
        prompt = data.prompt or InteractionCoreConfig.Prompts.default,
        coords = data.coords,
        entity = data.entity,
        validations = data.validations or {},
        serverCallback = data.serverCallback,
        clientCallback = data.clientCallback,
        onEnter = data.onEnter,
        onExit = data.onExit,
        enabled = data.enabled ~= false,
        oneTime = data.oneTime == true,
        used = false,
        created = GetGameTimer and GetGameTimer() or 0
    }
end

-- Validation function (simplified, no loops)
local function ValidateInteraction(interaction, playerId, context)
    if not interaction or not interaction.enabled then
        return false
    end
    
    if interaction.oneTime and interaction.used then
        return false
    end
    
    -- Basic distance validation only (prevent complex validation loops)
    if interaction.coords and context and context.coords then
        local dx = interaction.coords.x - context.coords.x
        local dy = interaction.coords.y - context.coords.y
        local dz = interaction.coords.z - context.coords.z
        local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
        
        if distance > interaction.range then
            return false
        end
    end
    
    -- Enhanced validation system
    if interaction.validations then
        for i = 1, math.min(#interaction.validations, 5) do -- Limit to 5 validations max
            local validation = interaction.validations[i]
            if validation then
                local validationResult = false
                
                -- Handle different validation types
                if validation.type == InteractionCoreConfig.ValidationTypes.DISTANCE then
                    if interaction.coords and context and context.coords then
                        local distance = InteractionCore.GetDistance(interaction.coords, context.coords)
                        validationResult = distance <= (validation.range or interaction.range or InteractionCoreConfig.DefaultRange)
                    end
                elseif validation.type == InteractionCoreConfig.ValidationTypes.CUSTOM and validation.callback then
                    local success, result = pcall(validation.callback, playerId, context, interaction)
                    validationResult = success and result
                else
                    -- For other validation types (ITEM, JOB, MONEY), use custom callback if provided
                    if validation.callback then
                        local success, result = pcall(validation.callback, playerId, context, interaction)
                        validationResult = success and result
                    else
                        validationResult = true -- Default to true if no callback provided
                    end
                end
                
                if not validationResult then
                    return false
                end
            end
        end
    end
    
    return true
end

-- Core functions (memory-safe)
function InteractionCore.Register(data)
    -- Prevent memory bloat
    if InteractionCore.interactionCount >= InteractionCoreConfig.MaxInteractions then
        print("^1[InteractionCore] Error: Maximum interactions reached (" .. InteractionCoreConfig.MaxInteractions .. ")^0")
        return false
    end
    
    if not data or not data.id then
        print("^1[InteractionCore] Error: Invalid interaction data^0")
        return false
    end
    
    -- Remove existing interaction if it exists (prevent duplicates)
    if InteractionCore.interactions[data.id] then
        InteractionCore.Remove(data.id)
    end
    
    local interaction = CreateInteraction(data)
    if not interaction then
        print("^1[InteractionCore] Error: Failed to create interaction^0")
        return false
    end
    
    InteractionCore.interactions[data.id] = interaction
    InteractionCore.interactionCount = InteractionCore.interactionCount + 1
    
    if InteractionCoreConfig.Debug then
        print("^2[InteractionCore] Registered: " .. data.id .. " (Count: " .. InteractionCore.interactionCount .. ")^0")
    end
    
    return true
end

function InteractionCore.Remove(interactionId)
    if not interactionId or not InteractionCore.interactions[interactionId] then
        return false
    end
    
    -- Clean removal
    InteractionCore.interactions[interactionId] = nil
    InteractionCore.interactionCount = math.max(0, InteractionCore.interactionCount - 1)
    
    if InteractionCoreConfig.Debug then
        print("^2[InteractionCore] Removed: " .. interactionId .. " (Count: " .. InteractionCore.interactionCount .. ")^0")
    end
    
    return true
end

function InteractionCore.Get(interactionId)
    if not interactionId then
        return nil
    end
    return InteractionCore.interactions[interactionId]
end

function InteractionCore.GetAll()
    return InteractionCore.interactions
end

function InteractionCore.GetCount()
    return InteractionCore.interactionCount
end

function InteractionCore.Validate(interactionId, playerId, context)
    local interaction = InteractionCore.Get(interactionId)
    if not interaction then
        return false
    end
    
    return ValidateInteraction(interaction, playerId, context)
end

function InteractionCore.MarkUsed(interactionId)
    local interaction = InteractionCore.Get(interactionId)
    if interaction and interaction.oneTime then
        interaction.used = true
    end
end

-- Memory cleanup function
function InteractionCore.Cleanup()
    if not GetGameTimer then
        return
    end
    
    local currentTime = GetGameTimer()
    local cleanupInterval = InteractionCoreConfig.CleanupInterval or 60000
    
    if currentTime - InteractionCore.lastCleanup < cleanupInterval then
        return
    end
    
    InteractionCore.lastCleanup = currentTime
    
    -- Clean up old pending interactions
    if InteractionCore.pending then
        for playerId, pendingData in pairs(InteractionCore.pending) do
            if pendingData.created and (currentTime - pendingData.created) > 300000 then -- 5 minutes
                InteractionCore.pending[playerId] = nil
                if InteractionCoreConfig.Debug then
                    print("^3[InteractionCore] Cleaned up stale pending interaction for player " .. playerId .. "^0")
                end
            end
        end
    end
    
    -- Clean up used one-time interactions
    local toRemove = {}
    for id, interaction in pairs(InteractionCore.interactions) do
        if interaction.oneTime and interaction.used and interaction.created and (currentTime - interaction.created) > 60000 then
            table.insert(toRemove, id)
        end
    end
    
    for _, id in ipairs(toRemove) do
        InteractionCore.Remove(id)
    end
    
    if InteractionCoreConfig.Debug and #toRemove > 0 then
        print("^3[InteractionCore] Cleaned up " .. #toRemove .. " used interactions^0")
    end
end

-- Safe utility functions
function InteractionCore.GetDistance(coords1, coords2)
    if not coords1 or not coords2 then
        return 999999.0
    end
    
    local dx = (coords1.x or 0) - (coords2.x or 0)
    local dy = (coords1.y or 0) - (coords2.y or 0)
    local dz = (coords1.z or 0) - (coords2.z or 0)
    
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- Initialize system
InteractionCore.lastCleanup = GetGameTimer and GetGameTimer() or 0

-- Make sure InteractionCore is globally accessible
_G.InteractionCore = InteractionCore
rawset(_G, 'InteractionCore', InteractionCore) -- Force global assignment

if InteractionCoreConfig and InteractionCoreConfig.Debug then
    print("^2[InteractionCore] Utilities loaded (leak-free version) - Global set^0")
else
    print("^2[InteractionCore] Utilities loaded - Global set^0")
end