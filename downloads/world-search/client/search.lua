-- =====================================================
-- WORLD SEARCH SYSTEM - CLIENT SEARCH LOGIC
-- =====================================================

local WorldSearchEngine = {}

-- Search state tracking
WorldSearchEngine.nearbyZones = {}
WorldSearchEngine.lastZoneCheck = 0
WorldSearchEngine.zoneCheckInterval = 1000 -- Check every second

-- Initialize search engine
function WorldSearchEngine.Initialize()
    CreateThread(function()
        while true do
            WorldSearchEngine.UpdateNearbyZones()
            Wait(WorldSearchEngine.zoneCheckInterval)
        end
    end)
    
    WorldSearchUtils.DebugPrint("Search engine initialized")
end

-- Update nearby search zones (if implementing client-side zone detection)
function WorldSearchEngine.UpdateNearbyZones()
    local playerPed = PlayerPedId()
    if not DoesEntityExist(playerPed) then
        return
    end
    
    local playerCoords = GetEntityCoords(playerPed)
    WorldSearchEngine.nearbyZones = {}
    
    -- This would typically get zones from server or config
    -- For now, we rely on interaction_core for zone detection
    
    WorldSearchEngine.lastZoneCheck = GetGameTimer()
end

-- Check if specific object can be searched
function WorldSearchEngine.CanSearchObject(entity)
    if not DoesEntityExist(entity) then
        return false
    end
    
    local model = GetEntityModel(entity)
    local modelName = string.lower(tostring(model))
    
    -- Define searchable object models
    local searchableObjects = {
        -- Dumpsters
        [GetHashKey("prop_dumpster_01a")] = "dumpster",
        [GetHashKey("prop_dumpster_02a")] = "dumpster", 
        [GetHashKey("prop_dumpster_02b")] = "dumpster",
        [GetHashKey("prop_dumpster_3a")] = "dumpster",
        [GetHashKey("prop_dumpster_4a")] = "dumpster",
        [GetHashKey("prop_dumpster_4b")] = "dumpster",
        
        -- Trash bins
        [GetHashKey("prop_bin_01a")] = "trash_bin",
        [GetHashKey("prop_bin_02a")] = "trash_bin",
        [GetHashKey("prop_bin_03a")] = "trash_bin",
        [GetHashKey("prop_bin_04a")] = "trash_bin",
        [GetHashKey("prop_bin_05a")] = "trash_bin",
        [GetHashKey("prop_bin_07a")] = "trash_bin",
        [GetHashKey("prop_bin_07b")] = "trash_bin",
        [GetHashKey("prop_bin_07c")] = "trash_bin",
        [GetHashKey("prop_bin_07d")] = "trash_bin",
        [GetHashKey("prop_bin_08a")] = "trash_bin",
        [GetHashKey("prop_bin_08open")] = "trash_bin",
        [GetHashKey("prop_bin_10a")] = "trash_bin",
        [GetHashKey("prop_bin_10b")] = "trash_bin",
        [GetHashKey("prop_bin_11a")] = "trash_bin",
        [GetHashKey("prop_bin_12a")] = "trash_bin",
        [GetHashKey("prop_bin_13a")] = "trash_bin",
        [GetHashKey("prop_bin_14a")] = "trash_bin",
        [GetHashKey("prop_bin_14b")] = "trash_bin",
        
        -- Benches
        [GetHashKey("prop_bench_01a")] = "bench",
        [GetHashKey("prop_bench_01b")] = "bench",
        [GetHashKey("prop_bench_01c")] = "bench",
        [GetHashKey("prop_bench_02")] = "bench",
        [GetHashKey("prop_bench_03")] = "bench",
        [GetHashKey("prop_bench_04")] = "bench",
        [GetHashKey("prop_bench_05")] = "bench",
        [GetHashKey("prop_bench_06")] = "bench",
        [GetHashKey("prop_bench_07")] = "bench",
        [GetHashKey("prop_bench_08")] = "bench",
        [GetHashKey("prop_bench_09")] = "bench",
        [GetHashKey("prop_bench_10")] = "bench",
        [GetHashKey("prop_bench_11")] = "bench",
        
        -- Mailboxes
        [GetHashKey("prop_postbox_01a")] = "mailbox",
        [GetHashKey("prop_letterbox_04")] = "mailbox",
        [GetHashKey("prop_mail_bag_01")] = "mailbox",
        
        -- News stands
        [GetHashKey("prop_news_disp_02a")] = "news_stand",
        [GetHashKey("prop_news_disp_02c")] = "news_stand",
        [GetHashKey("prop_news_disp_03a")] = "news_stand",
        [GetHashKey("prop_news_disp_05f")] = "news_stand",
        [GetHashKey("prop_news_disp_06a")] = "news_stand",
        
        -- Vending machines
        [GetHashKey("prop_vend_coffe_01")] = "vending_machine",
        [GetHashKey("prop_vend_soda_01")] = "vending_machine", 
        [GetHashKey("prop_vend_soda_02")] = "vending_machine",
        [GetHashKey("prop_vend_water_01")] = "vending_machine",
        [GetHashKey("prop_vend_fags_01")] = "vending_machine",
    }
    
    return searchableObjects[model] or false
end

-- Find searchable objects near player
function WorldSearchEngine.FindNearbySearchableObjects(radius)
    radius = radius or 10.0
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local searchableObjects = {}
    
    -- Get all objects in area
    local objects = GetGamePool('CObject')
    
    for _, object in ipairs(objects) do
        if DoesEntityExist(object) then
            local objCoords = GetEntityCoords(object)
            local distance = #(playerCoords - objCoords)
            
            if distance <= radius then
                local searchType = WorldSearchEngine.CanSearchObject(object)
                if searchType then
                    table.insert(searchableObjects, {
                        entity = object,
                        coords = objCoords,
                        distance = distance,
                        type = searchType,
                        model = GetEntityModel(object)
                    })
                end
            end
        end
    end
    
    -- Sort by distance
    table.sort(searchableObjects, function(a, b)
        return a.distance < b.distance
    end)
    
    return searchableObjects
end

-- Register dynamic search zones for nearby objects
function WorldSearchEngine.RegisterDynamicZones()
    local searchableObjects = WorldSearchEngine.FindNearbySearchableObjects(50.0)
    
    for _, obj in ipairs(searchableObjects) do
        -- Create temporary search zone
        local zoneData = {
            name = string.format("Dynamic %s", obj.type),
            coords = obj.coords,
            range = 2.0,
            searchType = WorldSearchConfig.SearchTypes.WORLD_OBJECT,
            lootTable = obj.type,
            prompt = WorldSearchConfig.Prompts.search_object,
            temporary = true,
            entity = obj.entity
        }
        
        -- Register with server (if server supports dynamic zones)
        TriggerServerEvent('worldsearch:registerDynamicZone', zoneData)
    end
end

-- Check if player can search nearby NPCs
function WorldSearchEngine.GetNearbySearchableNPCs(radius)
    radius = radius or 5.0
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local searchableNPCs = {}
    
    -- Get all peds in area
    local peds = GetGamePool('CPed')
    
    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) and ped ~= playerPed then
            local pedCoords = GetEntityCoords(ped)
            local distance = #(playerCoords - pedCoords)
            
            if distance <= radius then
                -- Check if NPC is unconscious, dead, or can be searched
                local canSearch = IsEntityDead(ped) or 
                                IsPedRagdoll(ped) or 
                                IsPedFalling(ped) or
                                GetPedConfigFlag(ped, 120, true) -- Is knocked out
                
                if canSearch then
                    table.insert(searchableNPCs, {
                        entity = ped,
                        coords = pedCoords,
                        distance = distance,
                        isDead = IsEntityDead(ped),
                        model = GetEntityModel(ped)
                    })
                end
            end
        end
    end
    
    return searchableNPCs
end

-- Initialize on resource start
CreateThread(function()
    Wait(2000)
    WorldSearchEngine.Initialize()
end)

-- Export functions
exports('FindNearbySearchableObjects', WorldSearchEngine.FindNearbySearchableObjects)
exports('CanSearchObject', WorldSearchEngine.CanSearchObject)
exports('GetNearbySearchableNPCs', WorldSearchEngine.GetNearbySearchableNPCs)