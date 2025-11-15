-- =====================================================
-- WORLD-SEARCH - INTERACTION_CORE SYNC HELPER
-- =====================================================

local InteractionCoreSync = {}
InteractionCoreSync.isReady = false
InteractionCoreSync.callbacks = {}

-- Check if interaction_core is fully ready with exports
function InteractionCoreSync.CheckReady()
    if InteractionCoreSync.isReady then
        return true
    end
    
    -- Check resource state
    local resourceState = GetResourceState('interaction_core')
    if resourceState ~= 'started' then
        -- Debug: Only show this occasionally to avoid spam
        if math.random(1, 50) == 1 then
            print(string.format("^6[WorldSearch DEBUG]^7 interaction_core state: %s (need 'started')", resourceState))
        end
        return false
    end
    
    -- Check critical exports with detailed error reporting
    local success, result = pcall(function()
        local exportsObj = exports['interaction_core']
        if not exportsObj then
            return false, "exports object is nil"
        end
        
        local requiredExports = {
            'ShowUnifiedPrompt',
            'ShowUnifiedNotification', 
            'ShowUnifiedProgress'
        }
        
        for _, exportName in ipairs(requiredExports) do
            if not exportsObj[exportName] then
                return false, "missing export: " .. exportName
            end
        end
        
        return true, "all exports available"
    end)
    
    if success and result == true then
        InteractionCoreSync.isReady = true
        
        -- Execute any pending callbacks
        for _, callback in ipairs(InteractionCoreSync.callbacks) do
            pcall(callback)
        end
        InteractionCoreSync.callbacks = {}
        
        print("^2[WorldSearch] InteractionCore unified UI system confirmed ready^0")
        return true
    elseif not success then
        -- Debug: Show error occasionally 
        if math.random(1, 100) == 1 then
            print("^6[WorldSearch DEBUG]^7 Export check error:", result)
        end
    end
    
    return false
end

-- Wait for interaction_core to be ready
function InteractionCoreSync.WhenReady(callback)
    if InteractionCoreSync.CheckReady() then
        callback()
    else
        table.insert(InteractionCoreSync.callbacks, callback)
    end
end

-- Safe export call with fallback
function InteractionCoreSync.SafeCall(exportName, fallback, ...)
    if not InteractionCoreSync.isReady then
        if fallback then fallback(...) end
        return false
    end
    
    local success, result = pcall(function(...)
        return exports['interaction_core'][exportName](...)
    end, ...)
    
    if not success and fallback then
        fallback(...)
    end
    
    return success
end

-- Initialize sync system
CreateThread(function()
    local attempts = 0
    local maxAttempts = 300 -- Increased to 30 seconds (300 * 100ms)
    
    while not InteractionCoreSync.CheckReady() and attempts < maxAttempts do
        -- More detailed debugging every 50 attempts (5 seconds)
        if attempts % 50 == 0 and attempts > 0 then
            local state = GetResourceState('interaction_core')
            print(string.format("^6[WorldSearch DEBUG]^7 Waiting for InteractionCore... Attempt %d/%d, State: %s", attempts, maxAttempts, state))
        end
        
        Wait(100)
        attempts = attempts + 1
    end
    
    if not InteractionCoreSync.isReady then
        print("^3[WorldSearch] InteractionCore sync timeout after 30 seconds - running in independent mode^0")
        print("^3[WorldSearch] Make sure interaction_core is started and functioning properly^0")
    end
end)

-- Export the sync helper
_G.InteractionCoreSync = InteractionCoreSync

-- Debug command to test sync status
RegisterCommand('wsync', function()
    print("^6=== WorldSearch InteractionCore Sync Status ===^0")
    print("IsReady:", InteractionCoreSync.isReady)
    print("Resource State:", GetResourceState('interaction_core'))
    
    local success, exportsAvailable = pcall(function()
        return exports['interaction_core'] ~= nil
    end)
    print("Exports Available:", success and exportsAvailable or "Error checking")
    
    if success and exportsAvailable then
        local uiExports = {'ShowUnifiedPrompt', 'ShowUnifiedNotification', 'ShowUnifiedProgress'}
        for _, exportName in ipairs(uiExports) do
            local hasExport = exports['interaction_core'][exportName] ~= nil
            print(string.format("  %s: %s", exportName, hasExport and "✓" or "✗"))
        end
    end
    
    print("Pending Callbacks:", #InteractionCoreSync.callbacks)
    print("^6=== End Sync Status ===^0")
end, false)