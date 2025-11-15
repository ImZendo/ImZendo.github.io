-- =====================================================
-- WORLD SEARCH SYSTEM - SERVER SEARCH LOGIC
-- =====================================================

local SearchManager = {}

-- Advanced search tracking
SearchManager.searchSessions = {}      -- Active search sessions
SearchManager.searchHistory = {}       -- Player search history
SearchManager.zoneStates = {}          -- Per-zone search states
SearchManager.dynamicZones = {}        -- Dynamically created zones

-- Initialize search manager
function SearchManager.Initialize()
    WorldSearchUtils.DebugPrint("Search Manager initialized")
    
    -- Clean up old search sessions every 5 minutes
    CreateThread(function()
        while true do
            Wait(300000) -- 5 minutes
            SearchManager.CleanupOldSessions()
        end
    end)
end

-- Clean up abandoned search sessions
function SearchManager.CleanupOldSessions()
    local currentTime = GetGameTimer()
    local cleanedCount = 0
    
    for playerId, session in pairs(SearchManager.searchSessions) do
        if currentTime - session.lastActivity > 120000 then -- 2 minutes
            SearchManager.searchSessions[playerId] = nil
            cleanedCount = cleanedCount + 1
        end
    end
    
    if cleanedCount > 0 then
        WorldSearchUtils.DebugPrint("Cleaned up %d abandoned search sessions", cleanedCount)
    end
end

-- Enhanced search session management
function SearchManager.StartSearchSession(playerId, zone, callback)
    local session = {
        playerId = playerId,
        zoneId = zone.id,
        zone = zone,
        startTime = GetGameTimer(),
        lastActivity = GetGameTimer(),
        callback = callback,
        status = 'active',
        progressChecks = 0
    }
    
    SearchManager.searchSessions[playerId] = session
    
    -- Initialize player search history if needed
    if not SearchManager.searchHistory[playerId] then
        SearchManager.searchHistory[playerId] = {
            totalSearches = 0,
            successfulSearches = 0,
            lastSearchTime = 0,
            zoneCooldowns = {}
        }
    end
    
    -- Track zone state
    if not SearchManager.zoneStates[zone.id] then
        SearchManager.zoneStates[zone.id] = {
            totalSearches = 0,
            lastSearchTime = 0,
            searchingPlayers = {}
        }
    end
    
    SearchManager.zoneStates[zone.id].searchingPlayers[playerId] = GetGameTimer()
    
    WorldSearchUtils.DebugPrint("Started search session for player %s in zone %s", playerId, zone.id)
    return session
end

-- Update search session activity
function SearchManager.UpdateSearchActivity(playerId)
    local session = SearchManager.searchSessions[playerId]
    if session then
        session.lastActivity = GetGameTimer()
        session.progressChecks = session.progressChecks + 1
        return true
    end
    return false
end

-- Complete search with enhanced loot calculation
function SearchManager.CompleteSearchSession(playerId)
    local session = SearchManager.searchSessions[playerId]
    if not session then
        return false, "No active search session"
    end
    
    local zone = session.zone
    local playerHistory = SearchManager.searchHistory[playerId]
    
    -- Calculate search success based on multiple factors
    local lootResult = SearchManager.CalculateAdvancedLoot(playerId, zone, session)
    
    -- Update statistics
    playerHistory.totalSearches = playerHistory.totalSearches + 1
    playerHistory.lastSearchTime = GetGameTimer()
    
    if lootResult and lootResult.item ~= "nothing" then
        playerHistory.successfulSearches = playerHistory.successfulSearches + 1
    end
    
    -- Update zone statistics
    local zoneState = SearchManager.zoneStates[zone.id]
    zoneState.totalSearches = zoneState.totalSearches + 1
    zoneState.lastSearchTime = GetGameTimer()
    zoneState.searchingPlayers[playerId] = nil
    
    -- Set zone cooldown for player
    playerHistory.zoneCooldowns[zone.id] = GetGameTimer()
    
    -- Clean up session
    SearchManager.searchSessions[playerId] = nil
    
    WorldSearchUtils.DebugPrint("Completed search session for player %s, result: %s", 
        playerId, lootResult and lootResult.item or "nothing")
    
    return true, lootResult
end

-- Advanced loot calculation with multiple factors
function SearchManager.CalculateAdvancedLoot(playerId, zone, session)
    -- Get loot table from WorldSearch module
    if not WorldSearch or not WorldSearch.lootTables then
        return {item = "nothing", amount = 0, message = "WorldSearch system not initialized"}
    end
    
    local lootTable = WorldSearch.lootTables[zone.lootTable]
    if not lootTable then
        return {item = "nothing", amount = 0, message = "Invalid loot table"}
    end
    
    -- Base loot roll
    local baseLoot = WorldSearchUtils.RollLoot(lootTable)
    
    -- Apply modifiers based on various factors
    local modifiers = SearchManager.CalculateLootModifiers(playerId, zone, session)
    
    -- Apply luck/skill modifiers
    if modifiers.luckyRoll and baseLoot.item == "nothing" then
        -- Give player another chance
        baseLoot = WorldSearchUtils.RollLoot(lootTable)
        WorldSearchUtils.DebugPrint("Lucky roll triggered for player %s", playerId)
    end
    
    -- Apply quantity modifiers
    if baseLoot.amount and modifiers.quantityMultiplier > 1.0 then
        baseLoot.amount = math.ceil(baseLoot.amount * modifiers.quantityMultiplier)
        WorldSearchUtils.DebugPrint("Quantity bonus applied: x%.2f", modifiers.quantityMultiplier)
    end
    
    -- Apply rare item chance
    if modifiers.rareItemChance > 0 and math.random(1, 100) <= modifiers.rareItemChance then
        baseLoot = SearchManager.GetRareItem(zone)
        WorldSearchUtils.DebugPrint("Rare item triggered for player %s", playerId)
    end
    
    return baseLoot
end

-- Calculate loot modifiers based on player stats and conditions
function SearchManager.CalculateLootModifiers(playerId, zone, session)
    local modifiers = {
        luckyRoll = false,
        quantityMultiplier = 1.0,
        rareItemChance = 0,
        qualityBonus = 0
    }
    
    local playerHistory = SearchManager.searchHistory[playerId]
    local searchDuration = GetGameTimer() - session.startTime
    
    -- Experience bonus (more searches = better results)
    if playerHistory.totalSearches >= 10 then
        modifiers.quantityMultiplier = modifiers.quantityMultiplier + 0.1
        modifiers.rareItemChance = modifiers.rareItemChance + 2
    end
    
    if playerHistory.totalSearches >= 50 then
        modifiers.quantityMultiplier = modifiers.quantityMultiplier + 0.2
        modifiers.rareItemChance = modifiers.rareItemChance + 3
    end
    
    -- Success rate bonus (reward consistent players)
    local successRate = playerHistory.successfulSearches / math.max(playerHistory.totalSearches, 1)
    if successRate < 0.3 then -- Bad luck protection
        modifiers.luckyRoll = true
    elseif successRate > 0.7 then -- Reward skill
        modifiers.rareItemChance = modifiers.rareItemChance + 5
    end
    
    -- Time-based bonus (thorough searching)
    local expectedDuration = zone.searchTime or WorldSearchConfig.DefaultSearchTime
    if searchDuration >= expectedDuration then
        modifiers.quantityMultiplier = modifiers.quantityMultiplier + 0.15
    end
    
    -- Zone freshness bonus (less searched zones have better loot)
    local zoneState = SearchManager.zoneStates[zone.id]
    local timeSinceLastSearch = GetGameTimer() - zoneState.lastSearchTime
    if timeSinceLastSearch > 600000 then -- 10 minutes
        modifiers.quantityMultiplier = modifiers.quantityMultiplier + 0.25
        modifiers.rareItemChance = modifiers.rareItemChance + 8
    end
    
    -- Check for special conditions (time of day, weather, etc.)
    local hour = GetClockHours()
    if hour >= 22 or hour <= 6 then -- Night time bonus
        modifiers.rareItemChance = modifiers.rareItemChance + 3
    end
    
    return modifiers
end

-- Get rare item for zone
function SearchManager.GetRareItem(zone)
    local rareItems = {
        ["dumpster"] = {
            {item = "diamond_ring", chance = 30, min = 1, max = 1, message = "A diamond ring! Someone's going to be upset..."},
            {item = "gold_watch", chance = 25, min = 1, max = 1, message = "An expensive-looking watch!"},
            {item = "rare_collectible", chance = 20, min = 1, max = 1, message = "A rare collectible item!"},
            {item = "money", chance = 25, min = 100, max = 500, message = "A wad of cash hidden in the trash!"}
        },
        ["bench"] = {
            {item = "wallet", chance = 40, min = 1, max = 1, message = "Someone dropped their wallet!"},
            {item = "phone", chance = 30, min = 1, max = 1, message = "A lost smartphone!"},
            {item = "keys", chance = 30, min = 1, max = 1, message = "A set of car keys!"}
        },
        ["mailbox"] = {
            {item = "love_letter", chance = 35, min = 1, max = 1, message = "An old love letter..."},
            {item = "check", chance = 30, min = 1, max = 1, message = "An uncashed check!"},
            {item = "rare_stamp", chance = 20, min = 1, max = 1, message = "A valuable stamp!"},
            {item = "money", chance = 15, min = 50, max = 200, message = "Cash in an envelope!"}
        }
    }
    
    local zoneRareItems = rareItems[zone.lootTable] or rareItems["dumpster"]
    return WorldSearchUtils.RollLoot(zoneRareItems)
end

-- Cancel search session
function SearchManager.CancelSearchSession(playerId, reason)
    local session = SearchManager.searchSessions[playerId]
    if not session then
        return false
    end
    
    -- Update zone state
    local zoneState = SearchManager.zoneStates[session.zoneId]
    if zoneState and zoneState.searchingPlayers[playerId] then
        zoneState.searchingPlayers[playerId] = nil
    end
    
    -- Clean up session
    SearchManager.searchSessions[playerId] = nil
    
    WorldSearchUtils.DebugPrint("Cancelled search session for player %s: %s", playerId, reason)
    return true
end

-- Get player search statistics
function SearchManager.GetPlayerStats(playerId)
    return SearchManager.searchHistory[playerId] or {
        totalSearches = 0,
        successfulSearches = 0,
        lastSearchTime = 0,
        zoneCooldowns = {}
    }
end

-- Check if player can search zone (advanced cooldown system)
function SearchManager.CanPlayerSearchZone(playerId, zoneId)
    local playerHistory = SearchManager.searchHistory[playerId]
    if not playerHistory then
        return true, "No history"
    end
    
    local zoneCooldown = playerHistory.zoneCooldowns[zoneId]
    if not zoneCooldown then
        return true, "No previous search"
    end
    
    local timeSinceSearch = GetGameTimer() - zoneCooldown
    local cooldownTime = WorldSearchConfig.SearchCooldown
    
    if timeSinceSearch < cooldownTime then
        local remainingTime = math.ceil((cooldownTime - timeSinceSearch) / 1000)
        return false, string.format("Zone cooldown: %d seconds remaining", remainingTime)
    end
    
    return true, "Cooldown expired"
end

-- Handle dynamic zone registration from client
RegisterNetEvent('worldsearch:registerDynamicZone')
AddEventHandler('worldsearch:registerDynamicZone', function(zoneData)
    local playerId = source
    
    -- Validate dynamic zone data
    if not zoneData or not zoneData.coords then
        return
    end
    
    -- Add to dynamic zones
    local zoneId = WorldSearchUtils.GenerateId()
    zoneData.id = zoneId
    zoneData.dynamic = true
    zoneData.createdBy = playerId
    zoneData.createdAt = GetGameTimer()
    
    SearchManager.dynamicZones[zoneId] = zoneData
    
    -- Register with main system
    WorldSearch.RegisterSearchZone(zoneData)
    
    WorldSearchUtils.DebugPrint("Registered dynamic zone %s created by player %s", zoneId, playerId)
end)

-- Initialize on resource start
CreateThread(function()
    Wait(3000)
    SearchManager.Initialize()
end)