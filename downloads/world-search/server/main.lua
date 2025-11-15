-- =====================================================
-- WORLD SEARCH SYSTEM - SERVER MAIN
-- =====================================================

WorldSearch = {}  -- Make it global so other files can access it
WorldSearch.activeSearches = {}  -- Track active searches by player
WorldSearch.searchZones = {}     -- All registered search zones  
WorldSearch.lootTables = {}      -- All loot tables
WorldSearch.playerCooldowns = {} -- Player search cooldowns

-- Initialize the resource
CreateThread(function()
    -- Wait for interaction_core to load and be available
    local attempts = 0
    local interactionCoreReady = false
    
    while attempts < 100 do -- 10 second max wait
        Wait(100)
        attempts = attempts + 1
        
        local resourceState = GetResourceState('interaction_core')
        
        -- Debug: Print every 10 attempts to track progress
        if attempts % 10 == 0 then
            print(string.format("^6[WorldSearch DEBUG]^7 Attempt %d/100 - interaction_core state: %s", attempts, resourceState))
        end
        
        -- Check if interaction_core resource is started and ready
        if resourceState == 'started' then
            -- Simple check: try to access exports table
            local success, hasExports = pcall(function()
                return exports['interaction_core'] ~= nil
            end)
            
            if success and hasExports then
                -- Give it a moment to fully initialize
                Wait(200)
                
                -- Try to access the RegisterInteraction server export
                local exportSuccess, exportExists = pcall(function()
                    local func = exports['interaction_core']['RegisterInteraction']
                    return func ~= nil
                end)
                
                if exportSuccess and exportExists then
                    print("^6[WorldSearch DEBUG]^7 RegisterInteraction export found and verified")
                    interactionCoreReady = true
                    break
                else
                    print(string.format("^6[WorldSearch DEBUG]^7 Export check failed - success: %s, exists: %s", tostring(exportSuccess), tostring(exportExists)))
                end
            else
                print(string.format("^6[WorldSearch DEBUG]^7 Exports table access failed - success: %s, hasExports: %s", tostring(success), tostring(hasExports)))
            end
        end
    end
    
    if not interactionCoreReady then
        print("^3[WorldSearch]^7 InteractionCore not available - running in independent mode")
        print("^3[WorldSearch]^7 Some features may be limited without interaction_core")
        -- Continue initialization without interaction_core
    else
        print("^2[WorldSearch]^7 InteractionCore detected and ready")
    end
    
    WorldSearchUtils.DebugPrint("Initializing World Search System...")
    
    -- Load default loot tables
    for name, table in pairs(WorldSearchConfig.DefaultLootTables) do
        WorldSearch.lootTables[name] = table
        WorldSearchUtils.DebugPrint("Loaded loot table: %s", name)
    end
    
    -- Wait a bit more then register default search zones
    Wait(1000)
    local zonesRegistered = 0
    for _, zone in ipairs(WorldSearchConfig.DefaultSearchZones) do
        if WorldSearch.RegisterSearchZone(zone) then
            zonesRegistered = zonesRegistered + 1
        end
    end
    
    WorldSearchUtils.DebugPrint("World Search System initialized with %d/%d zones", zonesRegistered, #WorldSearchConfig.DefaultSearchZones)
    
    -- Register searchable objects as interaction zones (for object detection integration)
    WorldSearch.RegisterSearchableObjects()
end)

-- Register all searchable objects from config as interaction zones
function WorldSearch.RegisterSearchableObjects()
    if not WorldSearchConfig.SearchableObjects then
        WorldSearchUtils.DebugPrint("No searchable objects defined in config")
        return
    end
    
    local registered = 0
    for modelName, objectConfig in pairs(WorldSearchConfig.SearchableObjects) do
        -- Create a dynamic zone for this object type that will be triggered by object detection
        local zoneData = {
            id = "searchable_object_" .. modelName,
            name = objectConfig.name,
            type = "OBJECT_SEARCH",
            lootTable = objectConfig.lootTable,
            searchTime = objectConfig.searchTime or WorldSearchConfig.DefaultSearchTime,
            animDict = objectConfig.animDict,
            animName = objectConfig.animName,
            prompt = objectConfig.prompt,
            range = objectConfig.searchRange or WorldSearchConfig.MaxSearchDistance,
            -- This will be triggered by the object detection system
            dynamic = true,
            objectModel = modelName
        }
        
        if WorldSearch.RegisterSearchZone(zoneData) then
            registered = registered + 1
        end
    end
    
    WorldSearchUtils.DebugPrint("Registered %d searchable object types as interaction zones", registered)
end

-- Register a new search zone
function WorldSearch.RegisterSearchZone(data)
    local isValid, error = WorldSearchUtils.ValidateSearchZone(data)
    if not isValid then
        print(string.format("^1[WorldSearch] Failed to register zone '%s': %s^0", data.name or "unknown", error))
        return false
    end
    
    -- Generate unique ID if not provided
    local zoneId = data.id or WorldSearchUtils.GenerateId()
    data.id = zoneId
    
    -- Store the search zone
    WorldSearch.searchZones[zoneId] = data
    
    -- Register with interaction_core (map to correct InteractionCore types)
    local interactionType = InteractionCoreConfig.Types.WORLD -- Default to WORLD type
    if data.searchType == WorldSearchConfig.SearchTypes.VEHICLE_SEARCH then
        interactionType = InteractionCoreConfig.Types.VEHICLE
    elseif data.searchType == WorldSearchConfig.SearchTypes.NPC_SEARCH then
        interactionType = InteractionCoreConfig.Types.PED
    elseif data.searchType == WorldSearchConfig.SearchTypes.WORLD_OBJECT then
        interactionType = InteractionCoreConfig.Types.OBJECT
    end
    
    local interactionData = {
        id = 'worldsearch:' .. zoneId,
        type = interactionType,
        coords = data.coords,
        range = data.range or WorldSearchConfig.MaxSearchDistance,
        prompt = data.prompt or WorldSearchConfig.Prompts.search_object,
        serverCallback = function(playerId, context, callback)
            WorldSearch.HandleSearchAttempt(playerId, zoneId, callback)
        end,
        validations = data.validations or {},
        oneTime = data.oneTime or false,
        cooldown = data.cooldown or WorldSearchConfig.SearchCooldown
    }
    
    -- Add custom validations if specified
    if data.requireItem then
        table.insert(interactionData.validations, {
            type = 'CUSTOM',
            callback = function(playerId)
                return WorldSearchUtils.HasItem(playerId, data.requireItem)
            end
        })
    end
    
    if data.requireJob then
        table.insert(interactionData.validations, {
            type = 'CUSTOM', 
            callback = function(playerId)
                return WorldSearchUtils.HasJob(playerId, data.requireJob.name, data.requireJob.grade)
            end
        })
    end
    
    -- Register with interaction_core if available
    local success = false
    local interactionCoreAvailable = false
    
    -- Check if interaction_core is available
    if GetResourceState('interaction_core') == 'started' then
        local registerSuccess, registerResult = pcall(function()
            return exports['interaction_core']:RegisterInteraction(interactionData)
        end)
        
        if registerSuccess and registerResult then
            success = true
            interactionCoreAvailable = true
            WorldSearchUtils.DebugPrint("Successfully registered interaction: %s", interactionData.id)
        end
    end
    
    if not interactionCoreAvailable then
        WorldSearchUtils.DebugPrint("InteractionCore not available - zone registered in independent mode: %s", interactionData.id)
        success = true -- Allow registration to continue
    elseif not success then
        print(string.format("^1[WorldSearch] Failed to register interaction: %s^0", interactionData.id))
        return false
    end
    
    -- Send zone data to all clients for debug visualization
    if WorldSearchConfig.Debug and WorldSearchConfig.ShowDebugBoxes then
        TriggerClientEvent('worldsearch:addDebugZone', -1, {
            id = zoneId,
            coords = data.coords,
            range = data.range or WorldSearchConfig.MaxSearchDistance,
            name = data.name
        })
    end
    
    WorldSearchUtils.DebugPrint("Registered search zone: %s (ID: %s)", data.name, zoneId)
    return zoneId
end

-- Handle search attempt
function WorldSearch.HandleSearchAttempt(playerId, zoneId, callback)
    local zone = WorldSearch.searchZones[zoneId]
    if not zone then
        callback(false, "Search zone not found")
        return
    end
    
    -- Check if player is already searching
    if WorldSearch.activeSearches[playerId] then
        callback(false, WorldSearchConfig.Messages.already_searching)
        return
    end
    
    -- Check global cooldown
    local playerCooldown = WorldSearch.playerCooldowns[playerId]
    if playerCooldown and (GetGameTimer() - playerCooldown) < WorldSearchConfig.GlobalCooldown then
        local remaining = math.ceil((WorldSearchConfig.GlobalCooldown - (GetGameTimer() - playerCooldown)) / 1000)
        callback(false, string.format("Wait %d seconds before searching again.", remaining))
        return
    end
    
    -- Start the search
    WorldSearch.StartSearch(playerId, zone, callback)
end

-- Start search process
function WorldSearch.StartSearch(playerId, zone, callback)
    WorldSearch.activeSearches[playerId] = {
        zone = zone,
        startTime = GetGameTimer(),
        callback = callback
    }
    
    WorldSearchUtils.DebugPrint("Player %s started searching zone: %s", playerId, zone.name)
    
    -- Notify client to start search animation/progress
    TriggerClientEvent('worldsearch:startSearch', playerId, {
        zoneId = zone.id,
        duration = zone.searchTime or WorldSearchConfig.DefaultSearchTime,
        animation = zone.animation or WorldSearchConfig.SearchAnimation
    })
    
    -- Set up search completion timer
    CreateThread(function()
        local searchDuration = zone.searchTime or WorldSearchConfig.DefaultSearchTime
        Wait(searchDuration)
        
        -- Check if search is still active (not cancelled)
        if WorldSearch.activeSearches[playerId] then
            WorldSearch.CompleteSearch(playerId)
        end
    end)
end

-- Complete search and give loot
function WorldSearch.CompleteSearch(playerId)
    local searchData = WorldSearch.activeSearches[playerId]
    if not searchData then
        return
    end
    
    local zone = searchData.zone
    local callback = searchData.callback
    
    -- Clear active search
    WorldSearch.activeSearches[playerId] = nil
    WorldSearch.playerCooldowns[playerId] = GetGameTimer()
    
    -- Get loot table
    local lootTable = WorldSearch.lootTables[zone.lootTable]
    if not lootTable then
        callback(false, "Invalid loot table")
        return
    end
    
    -- Roll for loot
    local loot = WorldSearchUtils.RollLoot(lootTable)
    if not loot then
        callback(false, WorldSearchConfig.Messages.search_failed)
        return
    end
    
    -- Process the loot
    local success = WorldSearch.ProcessLoot(playerId, loot, zone)
    
    if success then
        callback(true, loot.message or WorldSearchConfig.Messages.search_complete)
        
        -- Trigger completion event for other resources
        TriggerEvent('worldsearch:searchCompleted', playerId, zone.id, loot)
        TriggerClientEvent('worldsearch:searchCompleted', playerId, zone.id, loot)
    else
        callback(false, WorldSearchConfig.Messages.search_failed)
    end
end

-- Process loot rewards
function WorldSearch.ProcessLoot(playerId, loot, zone)
    if not loot or not loot.item or loot.item == "nothing" then
        return true -- "Nothing" is still a successful search
    end
    
    -- Handle money separately
    if loot.item == "money" then
        WorldSearchUtils.GiveMoney(playerId, loot.amount)
        WorldSearchUtils.Notify(playerId, string.format(WorldSearchConfig.Messages.found_money, loot.amount))
        return true
    end
    
    -- Handle regular items
    local success = WorldSearchUtils.GiveItem(playerId, loot.item, loot.amount)
    if success then
        WorldSearchUtils.Notify(playerId, string.format(WorldSearchConfig.Messages.found_item, loot.item, loot.amount))
        
        -- Check for special items
        local specialItem = WorldSearchConfig.SpecialItems[loot.item]
        if specialItem then
            WorldSearchUtils.Notify(playerId, specialItem.message)
            TriggerEvent(specialItem.event, playerId, loot, zone)
        end
    end
    
    return success
end

-- Cancel search (called when player moves away or cancels)
function WorldSearch.CancelSearch(playerId, reason)
    local searchData = WorldSearch.activeSearches[playerId]
    if not searchData then
        return false
    end
    
    WorldSearch.activeSearches[playerId] = nil
    
    WorldSearchUtils.DebugPrint("Search cancelled for player %s: %s", playerId, reason or "unknown")
    WorldSearchUtils.Notify(playerId, WorldSearchConfig.Messages.search_interrupted)
    
    -- Notify callback of cancellation
    if searchData.callback then
        searchData.callback(false, WorldSearchConfig.Messages.search_interrupted)
    end
    
    return true
end

-- Export functions for other resources
function AddSearchZone(data)
    return WorldSearch.RegisterSearchZone(data)
end

function RemoveSearchZone(zoneId)
    if WorldSearch.searchZones[zoneId] then
        WorldSearch.searchZones[zoneId] = nil
        
        -- Remove from interaction_core if available
        if GetResourceState('interaction_core') == 'started' then
            local success, result = pcall(function()
                return exports['interaction_core']:RemoveInteraction('worldsearch:' .. zoneId)
            end)
            if not success then
                WorldSearchUtils.DebugPrint("Failed to remove interaction from interaction_core: %s", zoneId)
            end
        end
        
        -- Remove debug zone from clients
        if WorldSearchConfig.Debug and WorldSearchConfig.ShowDebugBoxes then
            TriggerClientEvent('worldsearch:removeDebugZone', -1, zoneId)
        end
        
        WorldSearchUtils.DebugPrint("Removed search zone: %s", zoneId)
        return true
    end
    return false
end

function AddLootTable(name, lootTable)
    WorldSearch.lootTables[name] = lootTable
    WorldSearchUtils.DebugPrint("Added loot table: %s", name)
    return true
end

function GetPlayerSearchData(playerId)
    return WorldSearch.activeSearches[playerId]
end

function ResetSearchCooldown(playerId)
    WorldSearch.playerCooldowns[playerId] = nil
    return true
end

-- Event handlers
RegisterNetEvent('worldsearch:cancelSearch')
AddEventHandler('worldsearch:cancelSearch', function()
    local playerId = source
    WorldSearch.CancelSearch(playerId, "player_cancelled")
end)

-- Handle client request for existing debug zones
RegisterNetEvent('worldsearch:requestDebugZones')
AddEventHandler('worldsearch:requestDebugZones', function()
    local playerId = source
    
    if not WorldSearchConfig.Debug or not WorldSearchConfig.ShowDebugBoxes then
        return
    end
    
    WorldSearchUtils.DebugPrint("Sending debug zones to player %s", playerId)
    
    -- Send all existing zones to the requesting client
    for zoneId, zone in pairs(WorldSearch.searchZones) do
        TriggerClientEvent('worldsearch:addDebugZone', playerId, {
            id = zoneId,
            coords = zone.coords,
            range = zone.range or WorldSearchConfig.MaxSearchDistance,
            name = zone.name
        })
    end
end)

-- Handle direct search requests (bypass interaction_core)
RegisterNetEvent('worldsearch:directSearch')
AddEventHandler('worldsearch:directSearch', function(zoneData)
    local playerId = source
    
    WorldSearchUtils.DebugPrint("Direct search request from player %s for zone: %s", playerId, zoneData.name)
    
    -- Check if player is already searching
    if WorldSearch.activeSearches[playerId] then
        WorldSearchUtils.Notify(playerId, WorldSearchConfig.Messages.already_searching)
        return
    end
    
    -- Check global cooldown
    local playerCooldown = WorldSearch.playerCooldowns[playerId]
    if playerCooldown and (GetGameTimer() - playerCooldown) < WorldSearchConfig.GlobalCooldown then
        local remaining = math.ceil((WorldSearchConfig.GlobalCooldown - (GetGameTimer() - playerCooldown)) / 1000)
        WorldSearchUtils.Notify(playerId, string.format("Wait %d seconds before searching again.", remaining))
        return
    end
    
    -- Find the appropriate registered zone based on the object name or loot table
    local targetZoneId = nil
    for zoneId, zone in pairs(WorldSearch.searchZones) do
        if zone.name == zoneData.name or zone.lootTable == zoneData.lootTable then
            targetZoneId = zoneId
            break
        end
    end
    
    if not targetZoneId then
        WorldSearchUtils.DebugPrint("No registered zone found for object: %s", zoneData.name)
        WorldSearchUtils.Notify(playerId, "This object cannot be searched")
        return
    end
    
    -- Start the search using the registered zone
    WorldSearch.HandleSearchAttempt(playerId, targetZoneId, function(success, message, data)
        if success then
            WorldSearchUtils.Notify(playerId, message or "Search completed!")
        else
            WorldSearchUtils.Notify(playerId, message or "Search failed!")
        end
    end)
end)

-- Handle player disconnection
AddEventHandler('playerDropped', function(reason)
    local playerId = source
    WorldSearch.CancelSearch(playerId, "player_disconnected")
end)

-- Debug command (remove in production)
if WorldSearchConfig.Debug then
    RegisterCommand('wsinfo', function(source, args)
        local playerId = source
        print("=== World Search Server Debug Info ===")
        print("Active searches:", json.encode(WorldSearch.activeSearches))
        
        local zoneCount = 0
        for k, v in pairs(WorldSearch.searchZones) do
            zoneCount = zoneCount + 1
        end
        print("Search zones registered:", zoneCount)
        
        local lootCount = 0
        for k, v in pairs(WorldSearch.lootTables) do
            lootCount = lootCount + 1
        end
        print("Loot tables loaded:", lootCount)
        
        print("interaction_core available:", exports['interaction_core'] ~= nil)
        
        -- List all registered zones
        print("Zone details:")
        for zoneId, zone in pairs(WorldSearch.searchZones) do
            print(string.format("  %s: %s at %.1f,%.1f,%.1f (range: %.1f)", 
                zoneId, zone.name, zone.coords.x, zone.coords.y, zone.coords.z, zone.range))
        end
        
        if playerId > 0 then
            WorldSearchUtils.Notify(playerId, "Debug info printed to server console")
        end
    end, false)
end