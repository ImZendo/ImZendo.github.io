-- =====================================================
-- WORLD SEARCH SYSTEM - INSTALLATION TEST
-- =====================================================

print("^2=== World Search System Test ===^0")
print("^3Checking integration with interaction_core...^0")

-- Test if interaction_core is available
CreateThread(function()
    Wait(2000) -- Wait for interaction_core to initialize
    
    if exports and exports['interaction_core'] then
        print("^2✓ interaction_core found and accessible^0")
        
        -- Test registering a simple search zone
        local testZone = {
            name = "Test Search Zone",
            coords = vector3(0.0, 0.0, 72.0), -- Above the map for testing
            range = 5.0,
            searchType = 1,
            lootTable = "trash_bin",
            prompt = "Press ~INPUT_CONTEXT~ to test search"
        }
        
        local success, error = pcall(function()
            return exports['interaction_core']:RegisterInteraction({
                id = 'worldsearch:test',
                type = testZone.searchType,
                coords = testZone.coords,
                range = testZone.range,
                prompt = testZone.prompt,
                serverCallback = function(playerId, context, callback)
                    print(string.format("^3Test search triggered by player %s^0", playerId))
                    callback(true, "Test search completed!")
                end
            })
        end)
        
        if success then
            print("^2✓ Successfully registered test search zone^0")
        else
            print("^1✗ Failed to register test search zone: " .. tostring(error) .. "^0")
        end
        
    else
        print("^1✗ interaction_core not found - ensure it's started before world-search^0")
    end
    
    -- Test world-search configuration
    if WorldSearchConfig then
        print("^2✓ World Search configuration loaded^0")
        print("^3- Default search time: " .. WorldSearchConfig.DefaultSearchTime .. "ms^0")
        print("^3- Default cooldown: " .. WorldSearchConfig.SearchCooldown .. "ms^0")
        print("^3- Loot tables loaded: " .. #WorldSearchConfig.DefaultLootTables .. "^0")
    else
        print("^1✗ World Search configuration not found^0")
    end
    
    -- Test utility functions
    if WorldSearchUtils then
        print("^2✓ World Search utilities loaded^0")
        
        -- Test distance calculation
        local dist = WorldSearchUtils.GetDistance(
            vector3(0, 0, 0),
            vector3(1, 1, 1)
        )
        print("^3- Distance function test: " .. string.format("%.2f", dist) .. " units^0")
    else
        print("^1✗ World Search utilities not found^0")
    end
    
    print("^2=== World Search System Test Complete ===^0")
    print("^3Check above for any errors. All ✓ means successful integration!^0")
end)