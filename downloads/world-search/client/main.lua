-- =====================================================
-- WORLD SEARCH SYSTEM - CLIENT MAIN
-- =====================================================

local WorldSearchClient = {}
WorldSearchClient.isSearching = false
WorldSearchClient.currentSearch = nil
WorldSearchClient.searchProgress = 0

-- Initialize client with proper interaction_core integration
CreateThread(function()
    -- Wait a moment for other scripts to load
    Wait(1000) -- Increased wait time for interaction_core to initialize
    
    print("^2[WorldSearch]^7 Initializing world search system with interaction_core integration...")
    
    -- Use the sync helper to properly detect InteractionCore
    InteractionCoreSync.WhenReady(function()
        print("^2[WorldSearch]^7 InteractionCore unified UI system confirmed ready - using unified mode")
        WorldSearchClient.interactionCoreRef = "sync" -- Use sync helper mode
        WorldSearchClient.hasInteractionCore = true
        
        -- Initialize UI system with unified mode
        if WorldSearchUI then
            WorldSearchUI.InitializeUI(true) -- Pass true for unified mode
        end
    end)
    
    -- Set initial state based on sync helper
    local hasInteractionCore = InteractionCoreSync.CheckReady()
    local interactionCoreRef = hasInteractionCore and "sync" or nil
    
    if not hasInteractionCore then
        print("^1[WorldSearch]^7 InteractionCore not available - running in independent mode")
    end
    
    -- Store the interaction core reference globally for this resource
    WorldSearchClient.interactionCoreRef = interactionCoreRef
    WorldSearchClient.hasInteractionCore = hasInteractionCore
    
    -- Check if object detection loaded
    if WorldSearchObjectDetection then
        print("^2[WorldSearch]^7 Object detection system is available!")
    else
        print("^1[WorldSearch]^7 Object detection system failed to load!")
    end
    
    local statusMsg = hasInteractionCore and "with interaction_core integration" or "in independent mode"
    WorldSearchUtils.DebugPrint("World Search Client initialized " .. statusMsg)
    
    -- Request existing zones from server for debug visualization
    if WorldSearchConfig.Debug and WorldSearchConfig.ShowDebugBoxes then
        TriggerServerEvent('worldsearch:requestDebugZones')
    end
    
    -- Start interaction detection system
    WorldSearchClient.StartInteractionDetection()
end)

-- Interaction detection system with InteractionCore integration
function WorldSearchClient.StartInteractionDetection()
    CreateThread(function()
        while true do
            Wait(500) -- Reduced frequency to prevent spam (was 100ms, now 500ms)
            
            if not WorldSearchClient.isSearching then
                -- Method 1: Try to use InteractionCore if available
                local nearbyInteractions = WorldSearchClient.GetNearbyInteractions()
                
                -- Method 2: Object detection integration
                local currentObject = nil
                if WorldSearchObjectDetection then
                    currentObject = WorldSearchObjectDetection.GetCurrentObject()
                    
                    -- If InteractionCore is available, register detected objects as interactions (only once per object)
                    if currentObject and WorldSearchClient.hasInteractionCore then
                        -- Create object ID to check if already registered
                        local objectId = string.format("detected_%s_%.0f_%.0f_%.0f", 
                            currentObject.model or "unknown", 
                            currentObject.coords.x or 0, 
                            currentObject.coords.y or 0, 
                            currentObject.coords.z or 0)
                        
                        -- Only register if not already registered
                        if not WorldSearchClient.registeredDetectedObjects or not WorldSearchClient.registeredDetectedObjects[objectId] then
                            WorldSearchClient.RegisterDetectedObject(currentObject)
                        end
                    end
                end
                
                -- Prioritize InteractionCore interactions over independent object detection
                local activeInteraction = nil
                if nearbyInteractions and #nearbyInteractions > 0 then
                    activeInteraction = nearbyInteractions[1] -- Use closest interaction
                elseif currentObject and not WorldSearchClient.hasInteractionCore then
                    -- Only use independent object detection if InteractionCore is not available
                    activeInteraction = currentObject
                end
                
                -- Only update and log when interaction changes to prevent spam
                if activeInteraction and activeInteraction ~= WorldSearchClient.currentObject then
                    WorldSearchClient.currentObject = activeInteraction
                    WorldSearchClient.showPrompt = true
                    
                    -- Only print debug when interaction changes
                    if nearbyInteractions and #nearbyInteractions > 0 then
                        WorldSearchUtils.DebugPrint("Entered InteractionCore interaction: %s", activeInteraction.id or "unknown")
                    else
                        WorldSearchUtils.DebugPrint("Entered object detection: %s (distance: %.2f)", 
                            activeInteraction.config.name, activeInteraction.distance)
                    end
                elseif not activeInteraction and WorldSearchClient.currentObject then
                    WorldSearchClient.currentObject = nil
                    WorldSearchClient.showPrompt = false
                    WorldSearchUtils.DebugPrint("Left interaction area")
                end
            else
                WorldSearchClient.showPrompt = false
            end
        end
    end)
end

-- Get nearby interactions from InteractionCore
-- Register a detected object as an InteractionCore interaction (dynamic registration)
function WorldSearchClient.RegisterDetectedObject(objectData)
    if not WorldSearchClient.hasInteractionCore or not objectData then
        return false
    end
    
    -- Create a unique ID for this object instance
    local objectId = string.format("detected_%s_%.0f_%.0f_%.0f", 
        objectData.model or "unknown", 
        objectData.coords.x or 0, 
        objectData.coords.y or 0, 
        objectData.coords.z or 0)
    
    -- Check if already registered
    if WorldSearchClient.registeredDetectedObjects and WorldSearchClient.registeredDetectedObjects[objectId] then
        return true -- Already registered
    end
    
    -- Initialize registry if needed
    if not WorldSearchClient.registeredDetectedObjects then
        WorldSearchClient.registeredDetectedObjects = {}
    end
    
    -- Create interaction data
    local interactionData = {
        id = objectId,
        type = InteractionCoreConfig.Types.OBJECT,
        coords = objectData.coords,
        range = objectData.config.searchRange or 2.0,
        prompt = objectData.config.prompt or ("Press ~INPUT_CONTEXT~ to search " .. objectData.config.name),
        -- This will be handled by the server through directSearch
        clientCallback = function()
            -- Trigger the existing object search system
            WorldSearchObjectDetection.SearchObject(objectData)
        end
    }
    
    -- Try to register with InteractionCore
    local success = false
    if WorldSearchClient.interactionCoreRef == "exports" then
        local registerSuccess, result = pcall(function()
            return exports['interaction_core']:RegisterInteraction(interactionData)
        end)
        success = registerSuccess and result
    elseif WorldSearchClient.interactionCoreRef and WorldSearchClient.interactionCoreRef.Register then
        success = WorldSearchClient.interactionCoreRef.Register(interactionData)
    elseif InteractionCore and InteractionCore.Register then
        success = InteractionCore.Register(interactionData)
    end
    
    if success then
        WorldSearchClient.registeredDetectedObjects[objectId] = {
            objectData = objectData,
            registrationTime = GetGameTimer and GetGameTimer() or 0
        }
        WorldSearchUtils.DebugPrint("Registered detected object as interaction: %s", objectId)
        return true
    else
        -- Only log failures occasionally to prevent spam (already fixed the root cause)
        if math.random(1, 50) == 1 then
            WorldSearchUtils.DebugPrint("Failed to register detected object: %s", objectId)
        end
        return false
    end
end

function WorldSearchClient.GetNearbyInteractions()
    local nearbyInteractions = {}
    
    if not WorldSearchClient.hasInteractionCore then
        return nearbyInteractions
    end
    
    local allInteractions = nil
    
    -- Try to get interactions based on available access method
    if WorldSearchClient.interactionCoreRef == "exports" then
        -- Use exports method
        local success, result = pcall(function()
            return exports['interaction_core']:GetAllInteractions()
        end)
        if success and result then
            allInteractions = result
        end
    elseif WorldSearchClient.interactionCoreRef and WorldSearchClient.interactionCoreRef.GetAll then
        -- Use direct reference
        allInteractions = WorldSearchClient.interactionCoreRef.GetAll()
    elseif InteractionCore and InteractionCore.GetAll then
        -- Try global access
        allInteractions = InteractionCore.GetAll()
    elseif _G.InteractionCore and _G.InteractionCore.GetAll then
        allInteractions = _G.InteractionCore.GetAll()
    else
        -- Final fallback to exports
        local success, result = pcall(function()
            return exports['interaction_core']:GetAllInteractions()
        end)
        if success and result then
            allInteractions = result
        end
    end
    
    if not allInteractions then
        return nearbyInteractions
    end
    
    -- Filter interactions relevant to world search
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for id, interaction in pairs(allInteractions) do
        if interaction and interaction.enabled and interaction.coords then
            local distance = #(playerCoords - vector3(interaction.coords.x, interaction.coords.y, interaction.coords.z))
            
            -- Check if this is a world-search related interaction
            if distance <= (interaction.range or 2.0) and 
               (interaction.type == "world_search" or string.find(id, "worldsearch") or string.find(id, "search")) then
                table.insert(nearbyInteractions, {
                    id = id,
                    interaction = interaction,
                    distance = distance,
                    coords = interaction.coords,
                    range = interaction.range
                })
            end
        end
    end
    
    -- Sort by distance
    table.sort(nearbyInteractions, function(a, b) return a.distance < b.distance end)
    
    return nearbyInteractions
end

-- Add object tracking variables
WorldSearchClient.currentObject = nil
WorldSearchClient.showPrompt = false

-- Note: AttemptSearch is now handled by the object detection system
-- Objects are searched directly through WorldSearchObjectDetection.StartObjectSearch()

-- Handle search start from server
RegisterNetEvent('worldsearch:startSearch')
AddEventHandler('worldsearch:startSearch', function(searchData)
    if WorldSearchClient.isSearching then
        WorldSearchUtils.DebugPrint("Already searching, ignoring new search request")
        return
    end
    
    WorldSearchClient.StartClientSearch(searchData)
end)

-- Handle search completion from server  
RegisterNetEvent('worldsearch:searchCompleted')
AddEventHandler('worldsearch:searchCompleted', function(zoneId, loot)
    WorldSearchClient.OnSearchCompleted(zoneId, loot)
end)

-- Handle debug zone addition from server
RegisterNetEvent('worldsearch:addDebugZone')
AddEventHandler('worldsearch:addDebugZone', function(zoneData)
    WorldSearchUtils.DebugPrint("Received debug zone from server: %s", zoneData.name or "Unknown")
    if WorldSearchConfig.Debug and WorldSearchConfig.ShowDebugBoxes then
        exports['world-search']:AddDebugZone(zoneData)
        WorldSearchUtils.DebugPrint("Added debug zone to UI: %s", zoneData.name or "Unknown")
    end
end)

-- Handle debug zone removal from server
RegisterNetEvent('worldsearch:removeDebugZone')
AddEventHandler('worldsearch:removeDebugZone', function(zoneId)
    WorldSearchUtils.DebugPrint("Removing debug zone from server: %s", zoneId)
    if WorldSearchConfig.Debug and WorldSearchConfig.ShowDebugBoxes then
        exports['world-search']:RemoveDebugZone(zoneId)
    end
end)

-- Start client-side search process
function WorldSearchClient.StartClientSearch(searchData)
    WorldSearchClient.isSearching = true
    WorldSearchClient.currentSearch = searchData
    WorldSearchClient.searchProgress = 0
    
    local playerPed = PlayerPedId()
    local duration = searchData.duration or WorldSearchConfig.DefaultSearchTime
    
    WorldSearchUtils.DebugPrint("Starting client search, duration: %dms", duration)
    
    -- Load and play animation
    if searchData.animation then
        WorldSearchClient.PlaySearchAnimation(playerPed, searchData.animation)
    end
    
    -- Start progress bar/UI
    WorldSearchClient.ShowSearchProgress(duration)
    
    -- Monitor for cancellation conditions
    CreateThread(function()
        local startTime = GetGameTimer()
        local playerCoords = GetEntityCoords(playerPed)
        
        while WorldSearchClient.isSearching do
            Wait(100)
            
            -- Check if player moved too far
            local currentCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords - currentCoords)
            
            if distance > WorldSearchConfig.MaxSearchDistance then
                WorldSearchClient.CancelSearch("moved_too_far")
                break
            end
            
            -- Check for manual cancellation (ESC key or similar)
            if IsControlJustPressed(0, 200) then -- ESC key
                WorldSearchClient.CancelSearch("player_cancelled")
                break
            end
            
            -- Update progress
            local elapsed = GetGameTimer() - startTime
            WorldSearchClient.searchProgress = math.min(elapsed / duration, 1.0)
        end
    end)
end

-- Play search animation
function WorldSearchClient.PlaySearchAnimation(ped, animData)
    local animDict = animData.dict or WorldSearchConfig.SearchAnimation.dict
    local animName = animData.anim or WorldSearchConfig.SearchAnimation.anim
    local animFlag = animData.flag or WorldSearchConfig.SearchAnimation.flag
    
    -- Load animation dictionary
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
    
    -- Play animation
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, animFlag, 0, false, false, false)
    
    WorldSearchUtils.DebugPrint("Playing search animation: %s/%s", animDict, animName)
end

-- Show search progress UI (unified system)
function WorldSearchClient.ShowSearchProgress(duration)
    local startTime = GetGameTimer()
    
    -- Use unified UI system if available with safe checking
    local usingUnifiedUI = false
    if GetResourceState('interaction_core') == 'started' then
        local exportSuccess, exportResult = pcall(function()
            return exports['interaction_core'] and exports['interaction_core'].ShowUnifiedProgress
        end)
        
        if exportSuccess and exportResult then
            local callSuccess = pcall(function()
                exports['interaction_core']:ShowUnifiedProgress("Searching...", duration, 0.0)
            end)
            
            if callSuccess then
                usingUnifiedUI = true
                CreateThread(function()
                    while WorldSearchClient.isSearching do
                        Wait(50) -- Less frequent updates for performance
                        
                        local elapsed = GetGameTimer() - startTime
                        local progress = math.min(elapsed / duration, 1.0)
                        
                        -- Update unified progress bar safely
                        pcall(function()
                            exports['interaction_core']:UpdateUnifiedProgress(progress, "Searching...")
                        end)
                        
                        -- Update local progress
                        WorldSearchClient.searchProgress = progress
                        
                        if progress >= 1.0 then
                            break
                        end
                    end
                    
                    -- Hide progress when done
                    pcall(function()
                        exports['interaction_core']:HideUnifiedProgress()
                    end)
                end)
            end
        end
    end
    
    if not usingUnifiedUI then
    else
        -- Fallback to original system
        CreateThread(function()
            while WorldSearchClient.isSearching do
                Wait(0)
                
                local elapsed = GetGameTimer() - startTime
                local progress = math.min(elapsed / duration, 1.0)
                
                -- Draw progress bar
                WorldSearchClient.DrawProgressBar(progress)
                
                -- Update progress
                WorldSearchClient.searchProgress = progress
                
                -- Check if completed (should be handled by server, but failsafe)
                if progress >= 1.0 then
                    break
                end
            end
        end)
    end
end

-- Draw progress bar on screen
function WorldSearchClient.DrawProgressBar(progress)
    local x, y = 0.5, 0.8
    local width, height = 0.25, 0.03
    local color = WorldSearchConfig.ProgressBarColor
    
    -- Background
    DrawRect(x, y, width, height, 0, 0, 0, 150)
    
    -- Progress fill
    DrawRect(x - (width/2) + (width * progress / 2), y, width * progress, height, color.r, color.g, color.b, 200)
    
    -- Border
    DrawRect(x, y, width + 0.002, height + 0.002, 255, 255, 255, 200)
    
    -- Text
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.4, 0.4)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(1, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextCentre(true)
    
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName("Searching...")
    EndTextCommandDisplayText(x, y - 0.05)
    
    -- Progress percentage
    BeginTextCommandDisplayText("STRING") 
    AddTextComponentSubstringPlayerName(string.format("%.0f%%", progress * 100))
    EndTextCommandDisplayText(x, y + 0.025)
end

-- Cancel current search
function WorldSearchClient.CancelSearch(reason)
    if not WorldSearchClient.isSearching then
        return
    end
    
    WorldSearchUtils.DebugPrint("Cancelling search: %s", reason or "unknown")
    
    WorldSearchClient.isSearching = false
    WorldSearchClient.currentSearch = nil
    WorldSearchClient.searchProgress = 0
    
    -- Stop animation
    local playerPed = PlayerPedId()
    ClearPedTasks(playerPed)
    
    -- Notify server
    TriggerServerEvent('worldsearch:cancelSearch')
    
    -- Show cancellation message
    local message = WorldSearchConfig.Messages.search_interrupted
    if reason == "moved_too_far" then
        message = WorldSearchConfig.Messages.too_far
    end
    
    WorldSearchClient.ShowNotification(message, "error")
end

-- Handle search completion
function WorldSearchClient.OnSearchCompleted(zoneId, loot)
    WorldSearchClient.isSearching = false
    WorldSearchClient.currentSearch = nil
    WorldSearchClient.searchProgress = 0
    
    -- Stop animation
    local playerPed = PlayerPedId()
    ClearPedTasks(playerPed)
    
    -- Show completion message/effect
    if loot and loot.item ~= "nothing" then
        WorldSearchClient.ShowLootEffect(loot)
    end
    
    WorldSearchUtils.DebugPrint("Search completed for zone %s", zoneId)
end

-- Show loot discovery effect
function WorldSearchClient.ShowLootEffect(loot)
    -- Play sound effect
    PlaySoundFrontend(-1, "PICKUP_WEAPON_MONEY", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
    
    -- Show notification with item found
    local message = loot.message or "Found something!"
    if loot.item ~= "nothing" and loot.amount > 0 then
        if loot.item == "money" then
            message = string.format("Found $%d!", loot.amount)
        else
            message = string.format("Found %s x%d!", loot.item, loot.amount)
        end
    end
    
    WorldSearchClient.ShowNotification(message, "success")
end

-- Show notification (framework agnostic)
function WorldSearchClient.ShowNotification(message, type, duration)
    type = type or "info"
    duration = duration or WorldSearchConfig.NotificationTime
    
    -- ESX notification
    if ESX then
        ESX.ShowNotification(message)
        return
    end
    
    -- QBCore notification
    if QBCore then
        QBCore.Functions.Notify(message, type, duration)
        return
    end
    
    -- Fallback - native notification
    SetNotificationTextEntry("STRING")
    AddTextComponentString(message)
    DrawNotification(false, true)
end

-- Export functions for other resources
function IsPlayerSearching()
    return WorldSearchClient.isSearching
end

function GetSearchProgress()
    return WorldSearchClient.searchProgress
end

function GetCurrentZone()
    -- Return object data instead of zone data for backwards compatibility
    if WorldSearchClient.currentObject then
        local obj = WorldSearchClient.currentObject
        
        -- Handle different object structures (InteractionCore vs Object Detection)
        if obj.config then
            -- Object Detection system format
            return {
                name = obj.config.name,
                coords = obj.coords,
                range = obj.config.searchRange,
                lootTable = obj.config.lootTable,
                prompt = obj.config.prompt
            }
        elseif obj.prompt or obj.range then
            -- InteractionCore system format
            return {
                name = obj.id or "interaction",
                coords = obj.coords,
                range = obj.range,
                lootTable = obj.lootTable,
                prompt = obj.prompt
            }
        end
    end
    return nil
end

function ShouldShowPrompt()
    return WorldSearchClient.showPrompt
end

function GetCurrentObject()
    return WorldSearchClient.currentObject
end

-- Register exports
exports('IsPlayerSearching', IsPlayerSearching)
exports('GetSearchProgress', GetSearchProgress)
exports('GetCurrentZone', GetCurrentZone)
exports('ShouldShowPrompt', ShouldShowPrompt)
exports('GetCurrentObject', GetCurrentObject)

-- Proxy exports from object detection system
exports('GetNearbyObjects', function()
    if WorldSearchObjectDetection then
        return WorldSearchObjectDetection.GetNearbyObjects()
    end
    return {}
end)

-- Additional proxy for GetCurrentObject from object detection
exports('GetDetectedObject', function()
    if WorldSearchObjectDetection then
        return WorldSearchObjectDetection.GetCurrentObject()
    end
    return nil
end)

-- Debug commands
if WorldSearchConfig.Debug then
    RegisterCommand('wsstop', function()
        WorldSearchClient.CancelSearch("debug_command")
        print("Search cancelled via debug command")
    end, false)
    
    RegisterCommand('wstest', function()
        -- Test notification and effects
        WorldSearchClient.ShowLootEffect({
            item = "test_item",
            amount = 5,
            message = "Test loot found!"
        })
    end, false)
    
    RegisterCommand('wscheck', function()
        local systemType = WorldSearchClient.hasInteractionCore and "Integrated System" or "Independent System"
        local statusMsg = WorldSearchClient.hasInteractionCore and "with interaction_core integration" or "no interaction_core dependency"
        
        print("=== World Search Client Debug (" .. systemType .. ") ===")
        print("System Status:", systemType .. " (" .. statusMsg .. ")")
        print("InteractionCore available:", WorldSearchClient.hasInteractionCore)
        print("Is searching:", WorldSearchClient.isSearching)
        print("Current search:", WorldSearchClient.currentSearch)
        print("Current object:", WorldSearchClient.currentObject and (WorldSearchClient.currentObject.config and WorldSearchClient.currentObject.config.name or WorldSearchClient.currentObject.id or "Unknown") or "None")
        print("Show prompt:", WorldSearchClient.showPrompt)
        
        if WorldSearchClient.hasInteractionCore then
            print("Running in integrated mode with interaction_core")
            
            -- Test interaction access
            local nearbyInteractions = WorldSearchClient.GetNearbyInteractions()
            print("Nearby interactions found:", nearbyInteractions and #nearbyInteractions or 0)
            
            if nearbyInteractions and #nearbyInteractions > 0 then
                for i, interaction in ipairs(nearbyInteractions) do
                    print(string.format("  %d. %s (distance: %.2f)", i, interaction.id or "unknown", interaction.distance or 0))
                end
            end
        else
            print("Running in independent mode (no interaction_core dependency)")
        end
        
        -- Object detection info
        if WorldSearchObjectDetection then
            print("Object detection system: Available")
            local nearbyObjects = WorldSearchObjectDetection.GetNearbyObjects()
            if nearbyObjects then
                print("Nearby searchable objects:", #nearbyObjects)
                for i, obj in ipairs(nearbyObjects) do
                    print(string.format("  %d. %s (%.2fm) - %s", 
                        i, obj.config and obj.config.name or "Unknown", obj.distance or 0, 
                        obj.searched and "Searched" or "Available"))
                end
            else
                print("No nearby objects detected")
            end
        else
            print("Object detection system: Not loaded!")
        end
        
        -- Config check
        print("Debug enabled:", WorldSearchConfig.Debug)
        print("Show debug boxes:", WorldSearchConfig.ShowDebugBoxes)
    end, false)
    
    RegisterCommand('wstogglebox', function()
        local enabled = exports['world-search']:ToggleDebugBoxes()
        print("Debug boxes toggled:", enabled and "ON" or "OFF")
    end, false)
    
    RegisterCommand('wsaddtestzone', function()
        -- Add a test debug zone at player's current location
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        
        local testZone = {
            id = "test_zone_" .. math.random(1000, 9999),
            coords = {x = coords.x, y = coords.y, z = coords.z},
            range = 3.0,
            name = "Test Zone (Player Location)"
        }
        
        exports['world-search']:AddDebugZone(testZone)
        print("Added test debug zone at your location:", coords.x, coords.y, coords.z)
    end, false)
    
    RegisterCommand('wstestlegion', function()
        -- Add debug zone at Legion Square for testing
        local legionZone = {
            id = "legion_test",
            coords = {x = 195.12, y = -933.98, z = 30.69},
            range = 2.0,
            name = "Legion Square Test"
        }
        
        exports['world-search']:AddDebugZone(legionZone)
        print("Added Legion Square test zone")
    end, false)
    
    RegisterCommand('wstestinteraction', function()
        -- Test if we can see current interactions
        print("=== Interaction Test ===")
        
        local hasInteractionCore = InteractionCore ~= nil or _G.InteractionCore ~= nil
        print("InteractionCore available:", hasInteractionCore)
        
        if InteractionCore and InteractionCore.GetAll then
            local interactions = InteractionCore.GetAll()
            local count = 0
            print("Interactions found via InteractionCore:")
            for id, interaction in pairs(interactions) do
                count = count + 1
                if interaction.coords then
                    print(string.format("  %s: %.1f,%.1f,%.1f (range: %.1f)", 
                        id, interaction.coords.x, interaction.coords.y, interaction.coords.z, interaction.range or 2.0))
                end
            end
            print("Total interactions:", count)
        elseif _G.InteractionCore and _G.InteractionCore.GetAll then
            local interactions = _G.InteractionCore.GetAll()
            local count = 0
            print("Interactions found via _G.InteractionCore:")
            for id, interaction in pairs(interactions) do
                count = count + 1
                if interaction.coords then
                    print(string.format("  %s: %.1f,%.1f,%.1f (range: %.1f)", 
                        id, interaction.coords.x, interaction.coords.y, interaction.coords.z, interaction.range or 2.0))
                end
            end
            print("Total interactions:", count)
        else
            print("No InteractionCore access available!")
        end
        
        -- Check player position relative to Legion Square
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local legionCoords = vector3(195.12, -933.98, 30.69)
        local distance = #(coords - legionCoords)
        print(string.format("Player distance to Legion Square: %.2f", distance))
        print(string.format("Player coords: %.2f, %.2f, %.2f", coords.x, coords.y, coords.z))
    end, false)

    RegisterCommand('wsobj', function()
        print("^2[WorldSearch] Object Detection Test:^0")
        
        if not WorldSearchObjectDetection then
            print("^1Object detection system not loaded!^0")
            return
        end
        
        local currentObject = WorldSearchObjectDetection.GetCurrentObject()
        if currentObject then
            print(string.format("Current object: %s", currentObject.config and currentObject.config.name or "Unknown"))
            print(string.format("Distance: %.2fm", currentObject.distance or 0))
            print(string.format("Model: %s", currentObject.model or "Unknown"))
            print(string.format("Loot table: %s", currentObject.config and currentObject.config.lootTable or "None"))
            print(string.format("Searched: %s", currentObject.searched and "Yes" or "No"))
        else
            print("No object nearby")
        end
        
        local nearbyObjects = WorldSearchObjectDetection.GetNearbyObjects()
        print(string.format("Total nearby objects: %d", nearbyObjects and #nearbyObjects or 0))
        
        if nearbyObjects then
            for i, obj in ipairs(nearbyObjects) do
                print(string.format("%d. %s - %.2fm (%s)", 
                    i, obj.config and obj.config.name or "Unknown", obj.distance or 0, obj.searched and "Searched" or "Available"))
            end
        end
    end, false)
end