-- =====================================================
-- WORLD SEARCH - INTERACTION_CORE INTEGRATION
-- =====================================================

WorldSearchIntegration = {
    initialized = false,
    registeredInteractions = {},
    useInteractionCore = false
}

-- Initialize integration with interaction_core
function WorldSearchIntegration.Init()
    CreateThread(function()
        -- Wait for interaction_core to be available
        local attempts = 0
        local maxAttempts = 50 -- 5 seconds max wait
        
        while attempts < maxAttempts do
            -- Check multiple ways to access InteractionCore
            if InteractionCore or _G.InteractionCore or rawget(_G, 'InteractionCore') then
                WorldSearchIntegration.useInteractionCore = true
                print("^2[WorldSearch] Integration with InteractionCore enabled^0")
                break
            end
            
            -- Check if exports are available
            local success, result = pcall(function()
                return exports['interaction_core'] ~= nil
            end)
            
            if success and result then
                WorldSearchIntegration.useInteractionCore = true
                print("^2[WorldSearch] Integration with InteractionCore enabled via exports^0")
                break
            end
            
            Wait(100)
            attempts = attempts + 1
        end
        
        if not WorldSearchIntegration.useInteractionCore then
            print("^3[WorldSearch] Running without InteractionCore integration^0")
        end
        
        WorldSearchIntegration.initialized = true
        
        -- Register existing objects as interactions
        if WorldSearchIntegration.useInteractionCore then
            WorldSearchIntegration.RegisterObjectInteractions()
        end
    end)
end

-- Register all searchable objects as InteractionCore interactions
function WorldSearchIntegration.RegisterObjectInteractions()
    -- DISABLED: Client-side registration conflicts with server-side system
    -- The server-side world-search system should handle interaction registration
    print("^3[WorldSearch] Client-side interaction registration disabled - using server-side system^0")
    return
end

-- DISABLED FUNCTION - keeping for reference but not executing
--[[
function WorldSearchIntegration.RegisterObjectInteractions_DISABLED()
    for modelName, objectConfig in pairs(WorldSearchConfig.SearchableObjects) do
        local modelHash = GetHashKey(modelName)
        
        -- Find all objects of this type nearby
        local objects = {}
        local tempObject = GetClosestObjectOfType(
            playerCoords.x, playerCoords.y, playerCoords.z,
            scanRadius,
            modelHash,
            false, false, false
        )
        
        while tempObject and tempObject ~= 0 and #objects < 10 do -- Limit to prevent spam
            local objCoords = GetEntityCoords(tempObject)
            local exists = false
            
            -- Check if we already found this object
            for _, existing in ipairs(objects) do
                if #(objCoords - existing.coords) < 0.1 then
                    exists = true
                    break
                end
            end
            
            if not exists then
                table.insert(objects, {
                    entity = tempObject,
                    coords = objCoords
                })
            end
            
            -- Look for next object (expand search slightly)
            tempObject = GetClosestObjectOfType(
                objCoords.x + 1, objCoords.y + 1, objCoords.z,
                scanRadius,
                modelHash,
                false, false, false
            )
            
            if tempObject == objects[#objects].entity then
                break -- Same object, stop searching
            end
        end
        
        -- Register each found object as an interaction
        for i, objData in ipairs(objects) do
            local interactionId = string.format("worldsearch:%s:%d", modelName, i)
            
            local interactionData = {
                id = interactionId,
                type = InteractionCoreConfig.Types.OBJECT,
                coords = objData.coords,
                range = objectConfig.searchRange or 2.0,
                prompt = objectConfig.prompt or "Press ~INPUT_CONTEXT~ to search",
                serverCallback = function(playerId, context, callback)
                    -- Handle the search via world-search system
                    WorldSearchIntegration.HandleSearchInteraction(interactionId, objectConfig, playerId, context, callback)
                end,
                validations = {
                    {
                        type = InteractionCoreConfig.ValidationTypes.CUSTOM,
                        callback = function(playerId, context, interaction)
                            -- Check if object still exists
                            if objData.entity and DoesEntityExist(objData.entity) then
                                return not WorldSearchIntegration.IsObjectSearched(objData.coords)
                            end
                            return false
                        end
                    }
                }
            }
            
            -- Try to register the interaction
            local success = false
            
            -- Try direct access first
            if InteractionCore and InteractionCore.Register then
                success = InteractionCore.Register(interactionData)
            elseif _G.InteractionCore and _G.InteractionCore.Register then
                success = _G.InteractionCore.Register(interactionData)
            else
                -- Try via exports
                local exportSuccess, result = pcall(function()
                    return exports['interaction_core']:RegisterInteraction(interactionData)
                end)
                success = exportSuccess and result
            end
            
            if success then
                WorldSearchIntegration.registeredInteractions[interactionId] = {
                    objectConfig = objectConfig,
                    coords = objData.coords,
                    entity = objData.entity
                }
                registered = registered + 1
            end
        end
    end
    
    print(string.format("^2[WorldSearch] Registered %d searchable objects with InteractionCore^0", registered))
end
--]]

-- Handle search interaction from InteractionCore
function WorldSearchIntegration.HandleSearchInteraction(interactionId, objectConfig, playerId, context, callback)
    print(string.format("^3[WorldSearch] Handling search interaction: %s for player %d^0", interactionId, playerId))
    
    -- Check if this is the source player
    if source ~= playerId then
        print("^1[WorldSearch] Player ID mismatch in search interaction^0")
        callback(false, "Invalid player")
        return
    end
    
    -- Mark object as searched to prevent immediate re-search
    local interaction = WorldSearchIntegration.registeredInteractions[interactionId]
    if interaction then
        WorldSearchIntegration.MarkObjectAsSearched(interaction.coords)
    end
    
    -- Trigger world-search system
    TriggerServerEvent('worldsearch:directSearch', {
        name = objectConfig.name,
        coords = context.coords,
        range = objectConfig.searchRange,
        lootTable = objectConfig.lootTable,
        searchTime = objectConfig.searchTime,
        animDict = objectConfig.animDict,
        animName = objectConfig.animName,
        interactionId = interactionId
    })
    
    -- The callback will be handled by the world-search system
    -- We don't call it here to avoid duplicate responses
end

-- Track searched objects (similar to object detection system)
WorldSearchIntegration.searchedObjects = {}

function WorldSearchIntegration.MarkObjectAsSearched(coords)
    local key = string.format("%.2f_%.2f_%.2f", coords.x, coords.y, coords.z)
    WorldSearchIntegration.searchedObjects[key] = GetGameTimer()
end

function WorldSearchIntegration.IsObjectSearched(coords)
    local key = string.format("%.2f_%.2f_%.2f", coords.x, coords.y, coords.z)
    local searchTime = WorldSearchIntegration.searchedObjects[key]
    
    if not searchTime then
        return false
    end
    
    -- Check if cooldown has expired
    local currentTime = GetGameTimer()
    local cooldown = WorldSearchConfig.SearchCooldown or 30000
    
    if currentTime - searchTime > cooldown then
        WorldSearchIntegration.searchedObjects[key] = nil
        return false
    end
    
    return true
end

-- Clean up when objects are removed or script stops
function WorldSearchIntegration.Cleanup()
    for interactionId, _ in pairs(WorldSearchIntegration.registeredInteractions) do
        -- Try to remove interaction
        if InteractionCore and InteractionCore.Remove then
            InteractionCore.Remove(interactionId)
        elseif _G.InteractionCore and _G.InteractionCore.Remove then
            _G.InteractionCore.Remove(interactionId)
        else
            local success, result = pcall(function()
                return exports['interaction_core']:RemoveInteraction(interactionId)
            end)
        end
    end
    
    WorldSearchIntegration.registeredInteractions = {}
    print("^3[WorldSearch] Cleaned up InteractionCore integrations^0")
end

-- Debug command to test integration
if WorldSearchConfig and WorldSearchConfig.Debug then
    RegisterCommand('wsintegration', function()
        print("^2=== WorldSearch Integration Status ===^0")
        print("Initialized:", WorldSearchIntegration.initialized)
        print("Using InteractionCore:", WorldSearchIntegration.useInteractionCore)
        print("Registered interactions:", #WorldSearchIntegration.registeredInteractions)
        
        -- Test InteractionCore access
        local hasDirectAccess = InteractionCore ~= nil
        local hasGlobalAccess = _G.InteractionCore ~= nil
        local hasRawAccess = rawget(_G, 'InteractionCore') ~= nil
        
        print("InteractionCore access:")
        print("  Direct:", hasDirectAccess)
        print("  Global (_G):", hasGlobalAccess)
        print("  Raw access:", hasRawAccess)
        
        -- Test exports
        local hasExports = false
        local success, result = pcall(function()
            return exports['interaction_core']:GetAllInteractions()
        end)
        if success then
            hasExports = true
            print("  Exports working: true, interactions found:", result and #result or 0)
        else
            print("  Exports working: false")
        end
        
        -- Test interactions
        if WorldSearchIntegration.useInteractionCore then
            local allInteractions = nil
            
            if InteractionCore and InteractionCore.GetAll then
                allInteractions = InteractionCore.GetAll()
            elseif _G.InteractionCore and _G.InteractionCore.GetAll then
                allInteractions = _G.InteractionCore.GetAll()
            end
            
            if allInteractions then
                local wsCount = 0
                for id, _ in pairs(allInteractions) do
                    if string.find(id, "worldsearch") then
                        wsCount = wsCount + 1
                    end
                end
                print("WorldSearch interactions in InteractionCore:", wsCount)
            else
                print("Could not access interactions from InteractionCore")
            end
        end
        
        print("^2=== End Integration Status ===^0")
    end, false)
end

-- Initialize integration when this file loads
WorldSearchIntegration.Init()

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        WorldSearchIntegration.Cleanup()
    end
end)

print("^2[WorldSearch] InteractionCore integration system loaded^0")