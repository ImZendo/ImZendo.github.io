-- =====================================================
-- WORLD SEARCH - OBJECT DETECTION SYSTEM
-- =====================================================

print("^6[WorldSearch DEBUG]^7 Object detection script executing...")

-- Check if config is available
if not WorldSearchConfig then
    print("^1[WorldSearch DEBUG]^7 WorldSearchConfig not available! This is the problem.")
    return
else
    print("^2[WorldSearch DEBUG]^7 WorldSearchConfig available: true")
end

-- Check if SearchableObjects exists in config
if not WorldSearchConfig.SearchableObjects then
    print("^1[WorldSearch DEBUG]^7 SearchableObjects not found in config!")
    return
else
    local count = 0
    for k, v in pairs(WorldSearchConfig.SearchableObjects) do
        count = count + 1
    end
    print("^2[WorldSearch DEBUG]^7 Found " .. count .. " searchable objects in config")
end

WorldSearchObjectDetection = {
    nearbyObjects = {},
    lastScanTime = 0,
    currentObject = nil,
    debugMarkers = {}
}

-- Make sure it's globally accessible
_G.WorldSearchObjectDetection = WorldSearchObjectDetection

-- Debug: Check if ObjectStatusUI is available
CreateThread(function()
    Wait(2000) -- Give time for all scripts to load 
    print("^6[WorldSearch DEBUG]^7 Checking ObjectStatusUI availability...")
    if ObjectStatusUI then
        print("^2[WorldSearch DEBUG]^7 ObjectStatusUI is available!")
        if ObjectStatusUI.Show then
            print("^2[WorldSearch DEBUG]^7 ObjectStatusUI.Show function exists")
        else
            print("^1[WorldSearch DEBUG]^7 ObjectStatusUI.Show function missing")
        end
    else
        print("^1[WorldSearch DEBUG]^7 ObjectStatusUI is NOT available!")
        print("^1[WorldSearch DEBUG]^7 _G.ObjectStatusUI:", _G.ObjectStatusUI and "exists" or "nil")
    end
end)

-- Initialize object detection system
function WorldSearchObjectDetection.Init()
    print("^2[WorldSearch]^7 Initializing object detection system...")
    
    -- Simple test first
    CreateThread(function()
        print("^2[WorldSearch]^7 Object detection thread started!")
    end)
    
    WorldSearchObjectDetection.StartObjectScanning()
    print("^2[WorldSearch]^7 Object detection system initialized successfully!")
end

-- Start the object scanning thread
function WorldSearchObjectDetection.StartObjectScanning()
    CreateThread(function()
        while true do
            local currentTime = GetGameTimer()
            if currentTime - WorldSearchObjectDetection.lastScanTime > WorldSearchConfig.ObjectDetection.ScanInterval then
                WorldSearchObjectDetection.ScanForNearbyObjects()
                WorldSearchObjectDetection.lastScanTime = currentTime
            end
            
            -- Check for interaction with current object
            WorldSearchObjectDetection.CheckObjectInteraction()
            
            -- Draw debug markers if enabled
            if WorldSearchConfig.ObjectDetection.EnableDebugMarkers then
                WorldSearchObjectDetection.DrawDebugMarkers()
            end
            
            Wait(100) -- Reduce CPU usage
        end
    end)
end

-- Scan for searchable objects near the player
function WorldSearchObjectDetection.ScanForNearbyObjects()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local scanRadius = WorldSearchConfig.ObjectDetection.ScanRadius
    
    -- Clear previous results
    WorldSearchObjectDetection.nearbyObjects = {}
    WorldSearchObjectDetection.debugMarkers = {}
    
    -- Scan for each type of searchable object
    for modelName, objectConfig in pairs(WorldSearchConfig.SearchableObjects) do
        local modelHash = GetHashKey(modelName)
        local closestObject = GetClosestObjectOfType(
            playerCoords.x, playerCoords.y, playerCoords.z,
            scanRadius,
            modelHash,
            false, false, false
        )
        
        if closestObject ~= 0 and DoesEntityExist(closestObject) then
            local objectCoords = GetEntityCoords(closestObject)
            local distance = #(playerCoords - objectCoords)
            
            -- Only add if within search range
            if distance <= objectConfig.searchRange then
                local objectData = {
                    entity = closestObject,
                    model = modelName,
                    coords = objectCoords,
                    distance = distance,
                    config = objectConfig,
                    searched = WorldSearchObjectDetection.IsObjectSearched(closestObject)
                }
                
                table.insert(WorldSearchObjectDetection.nearbyObjects, objectData)
                
                -- Add debug marker
                if WorldSearchConfig.ObjectDetection.EnableDebugMarkers then
                    table.insert(WorldSearchObjectDetection.debugMarkers, {
                        coords = objectCoords,
                        range = objectConfig.searchRange,
                        name = objectConfig.name,
                        searched = objectData.searched
                    })
                end
            end
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(WorldSearchObjectDetection.nearbyObjects, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Limit to max objects
    local maxObjects = WorldSearchConfig.ObjectDetection.MaxObjects
    if #WorldSearchObjectDetection.nearbyObjects > maxObjects then
        for i = maxObjects + 1, #WorldSearchObjectDetection.nearbyObjects do
            WorldSearchObjectDetection.nearbyObjects[i] = nil
        end
    end
end

-- Check if player can interact with any nearby objects
function WorldSearchObjectDetection.CheckObjectInteraction()
    local previousObject = WorldSearchObjectDetection.currentObject
    WorldSearchObjectDetection.currentObject = nil
    
    if #WorldSearchObjectDetection.nearbyObjects == 0 then
        -- Hide prompt if we had an object before but don't now
        if WorldSearchObjectDetection.currentPromptObject then
            WorldSearchObjectDetection.HideInteractionPrompt()
            WorldSearchObjectDetection.currentPromptObject = nil
        end
        return
    end
    
    -- Get the closest object
    local closestObject = WorldSearchObjectDetection.nearbyObjects[1]
    if closestObject and closestObject.distance <= closestObject.config.searchRange then
        WorldSearchObjectDetection.currentObject = closestObject
        
        -- Only show prompt if this is a different object than what we're currently showing prompt for
        if not closestObject.searched then
            local objectKey = string.format("%s_%.1f_%.1f_%.1f", 
                GetEntityModel(closestObject.entity),
                closestObject.coords.x, 
                closestObject.coords.y, 
                closestObject.coords.z)
            
            -- Only show/update prompt if this is a different object
            if WorldSearchObjectDetection.currentPromptObject ~= objectKey then
                WorldSearchObjectDetection.ShowInteractionPrompt(closestObject)
                WorldSearchObjectDetection.currentPromptObject = objectKey
            end
        else
            -- Object is searched, hide prompt if showing
            if WorldSearchObjectDetection.currentPromptObject then
                WorldSearchObjectDetection.HideInteractionPrompt()
                WorldSearchObjectDetection.currentPromptObject = nil
            end
        end
        
        -- Check for input only when we have a current object
        if IsControlJustPressed(0, 38) then -- E key
            WorldSearchObjectDetection.StartObjectSearch(closestObject)
        end
    else
        -- Hide prompt if we had an object before but it's now out of range
        if WorldSearchObjectDetection.currentPromptObject then
            WorldSearchObjectDetection.HideInteractionPrompt()
            WorldSearchObjectDetection.currentPromptObject = nil
        end
    end
end

-- Show interaction prompt for an object (custom UI system)
function WorldSearchObjectDetection.ShowInteractionPrompt(objectData)
    -- Wait for ObjectStatusUI to be available
    if not ObjectStatusUI then
        CreateThread(function()
            local attempts = 0
            while not ObjectStatusUI and attempts < 50 do
                Wait(100)
                attempts = attempts + 1
            end
            
            if ObjectStatusUI then
                ObjectStatusUI.Show(objectData)
                print("^2[WorldSearch DEBUG]^7 Custom UI shown for:", objectData.config.name or "Unknown Object")
            else
                print("^1[WorldSearch ERROR]^7 ObjectStatusUI failed to load after 5 seconds")
            end
        end)
        return
    end
    
    ObjectStatusUI.Show(objectData)
    print("^2[WorldSearch DEBUG]^7 Custom UI shown for:", objectData.config.name or "Unknown Object")
end

-- Hide interaction prompt
function WorldSearchObjectDetection.HideInteractionPrompt()
    if ObjectStatusUI then
        ObjectStatusUI.Hide()
    end
end

-- Start searching an object
function WorldSearchObjectDetection.StartObjectSearch(objectData)
    -- Check if already searching (use global variable if WorldSearchClient not available)
    local isSearching = false
    if WorldSearchClient and WorldSearchClient.isSearching then
        isSearching = WorldSearchClient.isSearching
    end
    
    if isSearching then
        print("^3[WorldSearch]^7 Already searching something!")
        return
    end
    
    -- Hide the prompt immediately when starting search
    WorldSearchObjectDetection.HideInteractionPrompt()
    WorldSearchObjectDetection.currentPromptObject = nil
    
    if objectData.searched then
        print("^3[WorldSearch]^7 This object has already been searched recently!")
        return
    end
    
    print(string.format("^2[WorldSearch]^7 Starting search on %s", objectData.config.name))
    
    -- Mark object as being searched
    WorldSearchObjectDetection.MarkObjectAsSearched(objectData.entity)
    
    -- Trigger server search directly (bypass WorldSearchClient dependency)
    TriggerServerEvent('worldsearch:directSearch', {
        name = objectData.config.name,
        coords = objectData.coords,
        range = objectData.config.searchRange,
        lootTable = objectData.config.lootTable,
        searchTime = objectData.config.searchTime,
        animDict = objectData.config.animDict,
        animName = objectData.config.animName
    })
end

-- Track searched objects to prevent repeated searches
WorldSearchObjectDetection.searchedObjects = {}

function WorldSearchObjectDetection.MarkObjectAsSearched(entity)
    local coords = GetEntityCoords(entity)
    local key = string.format("%.2f_%.2f_%.2f", coords.x, coords.y, coords.z)
    WorldSearchObjectDetection.searchedObjects[key] = GetGameTimer()
    
    -- Update custom UI to show searched status
    if ObjectStatusUI then
        ObjectStatusUI.UpdateStatus(true)
    end
    
    -- Clear prompt state if this was the object we were showing prompt for
    local objectKey = string.format("%s_%.1f_%.1f_%.1f", 
        GetEntityModel(entity), coords.x, coords.y, coords.z)
    if WorldSearchObjectDetection.currentPromptObject == objectKey then
        WorldSearchObjectDetection.currentPromptObject = nil
    end
end

function WorldSearchObjectDetection.IsObjectSearched(entity)
    local coords = GetEntityCoords(entity)
    local key = string.format("%.2f_%.2f_%.2f", coords.x, coords.y, coords.z)
    local searchTime = WorldSearchObjectDetection.searchedObjects[key]
    
    if not searchTime then
        return false
    end
    
    -- Check if cooldown has expired
    local currentTime = GetGameTimer()
    local cooldown = WorldSearchConfig.SearchCooldown or 30000
    
    if currentTime - searchTime > cooldown then
        WorldSearchObjectDetection.searchedObjects[key] = nil
        return false
    end
    
    return true
end

-- Draw debug markers for detected objects
function WorldSearchObjectDetection.DrawDebugMarkers()
    for _, marker in ipairs(WorldSearchObjectDetection.debugMarkers) do
        local coords = marker.coords
        local range = marker.range
        
        -- Choose color based on search status
        local r, g, b, a = 0, 255, 0, 100 -- Green for searchable
        if marker.searched then
            r, g, b, a = 255, 0, 0, 100 -- Red for already searched
        end
        
        -- Draw a circle marker
        DrawMarker(
            1, -- Cylinder marker
            coords.x, coords.y, coords.z - 1.0,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            range * 2.0, range * 2.0, 0.5,
            r, g, b, a,
            false, true, 2, nil, nil, false
        )
        
        -- Draw object name above it
        local distance = #(GetEntityCoords(PlayerPedId()) - coords)
        if distance < 10.0 then
            WorldSearchObjectDetection.DrawText3D(
                coords.x, coords.y, coords.z + 1.0,
                marker.name .. (marker.searched and " (Searched)" or " (Available)")
            )
        end
    end
end

-- Draw 3D text for object labels
function WorldSearchObjectDetection.DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local pX, pY, pZ = table.unpack(GetGameplayCamCoords())
    
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
    end
end

-- Get current object player can interact with
function WorldSearchObjectDetection.GetCurrentObject()
    return WorldSearchObjectDetection.currentObject
end

-- Get all nearby objects
function WorldSearchObjectDetection.GetNearbyObjects()
    return WorldSearchObjectDetection.nearbyObjects
end

-- Export functions
exports('GetCurrentObject', WorldSearchObjectDetection.GetCurrentObject)
exports('GetNearbyObjects', WorldSearchObjectDetection.GetNearbyObjects)

-- Initialize when loaded
WorldSearchObjectDetection.Init()