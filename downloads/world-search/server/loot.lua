-- =====================================================
-- WORLD SEARCH SYSTEM - SERVER LOOT MANAGEMENT
-- =====================================================

local LootManager = {}

-- Loot system state
LootManager.customLootTables = {}
LootManager.lootCallbacks = {}
LootManager.playerInventories = {} -- Cache for inventory checks
LootManager.lootHistory = {} -- Track what players have found

-- Initialize loot manager
function LootManager.Initialize()
    WorldSearchUtils.DebugPrint("Loot Manager initialized")
    
    -- Register default loot callbacks
    LootManager.RegisterLootCallback("money", LootManager.HandleMoneyLoot)
    LootManager.RegisterLootCallback("special", LootManager.HandleSpecialLoot)
    
    -- Initialize loot statistics tracking
    CreateThread(function()
        while true do
            Wait(600000) -- 10 minutes
            LootManager.UpdateLootStatistics()
        end
    end)
end

-- Register custom loot table
function LootManager.RegisterLootTable(name, lootTable, overwrite)
    if WorldSearch.lootTables[name] and not overwrite then
        WorldSearchUtils.DebugPrint("Loot table '%s' already exists, use overwrite=true to replace", name)
        return false
    end
    
    WorldSearch.lootTables[name] = lootTable
    WorldSearchUtils.DebugPrint("Registered loot table: %s with %d items", name, #lootTable)
    return true
end

-- Register custom loot callback
function LootManager.RegisterLootCallback(itemName, callback)
    LootManager.lootCallbacks[itemName] = callback
    WorldSearchUtils.DebugPrint("Registered loot callback for: %s", itemName)
end

-- Process loot with enhanced handling
function LootManager.ProcessLoot(playerId, loot, zone)
    if not loot or not loot.item then
        return false, "Invalid loot data"
    end
    
    -- Track loot in history
    LootManager.TrackLootHistory(playerId, loot, zone)
    
    -- Handle special "nothing" result
    if loot.item == "nothing" or loot.amount == 0 then
        return true, loot.message or WorldSearchConfig.Messages.search_failed
    end
    
    -- Check for custom loot callback
    local callback = LootManager.lootCallbacks[loot.item]
    if callback then
        return callback(playerId, loot, zone)
    end
    
    -- Handle money separately
    if loot.item == "money" then
        return LootManager.HandleMoneyLoot(playerId, loot, zone)
    end
    
    -- Handle regular items
    return LootManager.HandleItemLoot(playerId, loot, zone)
end

-- Handle money loot
function LootManager.HandleMoneyLoot(playerId, loot, zone)
    local amount = loot.amount or 10
    local moneyType = loot.moneyType or "cash"
    
    -- Apply any money multipliers
    local multiplier = LootManager.GetPlayerMoneyMultiplier(playerId)
    amount = math.floor(amount * multiplier)
    
    local success = WorldSearchUtils.GiveMoney(playerId, amount, moneyType)
    
    if success then
        local message = loot.message or string.format(WorldSearchConfig.Messages.found_money, amount)
        WorldSearchUtils.Notify(playerId, message, "success")
        
        -- Log the transaction
        WorldSearchUtils.DebugPrint("Gave $%d (%s) to player %s from zone %s", amount, moneyType, playerId, zone.id)
        
        return true, message
    else
        return false, "Failed to give money"
    end
end

-- Handle regular item loot
function LootManager.HandleItemLoot(playerId, loot, zone)
    local item = loot.item
    local amount = loot.amount or 1
    
    -- Check if player can carry more items
    if not LootManager.CanPlayerCarryItem(playerId, item, amount) then
        return false, "Inventory full"
    end
    
    -- Apply any item multipliers
    local multiplier = LootManager.GetPlayerItemMultiplier(playerId, item)
    amount = math.floor(amount * multiplier)
    
    local success = WorldSearchUtils.GiveItem(playerId, item, amount, loot.metadata)
    
    if success then
        local message = loot.message or string.format(WorldSearchConfig.Messages.found_item, item, amount)
        WorldSearchUtils.Notify(playerId, message, "success")
        
        -- Check for special item triggers
        LootManager.CheckSpecialItemTriggers(playerId, loot, zone)
        
        WorldSearchUtils.DebugPrint("Gave %s x%d to player %s from zone %s", item, amount, playerId, zone.id)
        
        return true, message
    else
        return false, "Failed to give item"
    end
end

-- Handle special loot (achievements, unlocks, etc.)
function LootManager.HandleSpecialLoot(playerId, loot, zone)
    local specialType = loot.specialType or "generic"
    
    WorldSearchUtils.DebugPrint("Processing special loot type '%s' for player %s", specialType, playerId)
    
    -- Trigger special events
    TriggerEvent('worldsearch:specialLootFound', playerId, loot, zone)
    TriggerClientEvent('worldsearch:specialLootFound', playerId, loot, zone)
    
    -- Handle specific special types
    if specialType == "clue" then
        return LootManager.HandleClue(playerId, loot, zone)
    elseif specialType == "map" then
        return LootManager.HandleTreasureMap(playerId, loot, zone)
    elseif specialType == "key" then
        return LootManager.HandleSpecialKey(playerId, loot, zone)
    end
    
    return true, loot.message or "Found something special!"
end

-- Handle clue items
function LootManager.HandleClue(playerId, loot, zone)
    -- Add clue to player's collection
    local clueId = loot.clueId or WorldSearchUtils.GenerateId()
    
    TriggerEvent('worldsearch:clueFound', playerId, clueId, loot, zone)
    
    local message = loot.message or "You found an interesting clue..."
    WorldSearchUtils.Notify(playerId, message, "warning")
    
    return true, message
end

-- Handle treasure map items
function LootManager.HandleTreasureMap(playerId, loot, zone)
    -- Generate treasure location
    local treasureLocation = LootManager.GenerateTreasureLocation()
    
    TriggerEvent('worldsearch:treasureMapFound', playerId, treasureLocation, loot, zone)
    
    local message = loot.message or "You found a treasure map! Check your inventory for details."
    WorldSearchUtils.Notify(playerId, message, "success")
    
    return true, message
end

-- Handle special key items
function LootManager.HandleSpecialKey(playerId, loot, zone)
    local keyType = loot.keyType or "generic"
    
    TriggerEvent('worldsearch:specialKeyFound', playerId, keyType, loot, zone)
    
    local message = loot.message or string.format("You found a %s key!", keyType)
    WorldSearchUtils.Notify(playerId, message, "success")
    
    return true, message
end

-- Check if player can carry item
function LootManager.CanPlayerCarryItem(playerId, item, amount)
    -- Framework-specific inventory checks
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            return xPlayer.canCarryItem(item, amount)
        end
    end
    
    if QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            -- QBCore inventory check logic
            return true -- Simplified for now
        end
    end
    
    -- Default: assume player can carry
    return true
end

-- Get player money multiplier based on various factors
function LootManager.GetPlayerMoneyMultiplier(playerId)
    local multiplier = 1.0
    
    -- Check for VIP status, perks, etc.
    -- This is framework-dependent
    
    return multiplier
end

-- Get player item multiplier
function LootManager.GetPlayerItemMultiplier(playerId, item)
    local multiplier = 1.0
    
    -- Apply item-specific multipliers
    -- Could be based on skills, perks, equipment, etc.
    
    return multiplier
end

-- Check for special item triggers
function LootManager.CheckSpecialItemTriggers(playerId, loot, zone)
    local specialItem = WorldSearchConfig.SpecialItems[loot.item]
    if specialItem then
        WorldSearchUtils.Notify(playerId, specialItem.message, "warning")
        TriggerEvent(specialItem.event, playerId, loot, zone)
        TriggerClientEvent(specialItem.event, playerId, loot, zone)
    end
end

-- Track loot history for statistics
function LootManager.TrackLootHistory(playerId, loot, zone)
    if not LootManager.lootHistory[playerId] then
        LootManager.lootHistory[playerId] = {}
    end
    
    table.insert(LootManager.lootHistory[playerId], {
        item = loot.item,
        amount = loot.amount,
        zone = zone.id,
        zoneName = zone.name,
        timestamp = GetGameTimer(),
        date = os.date("%Y-%m-%d %H:%M:%S")
    })
    
    -- Keep only last 100 entries per player
    local history = LootManager.lootHistory[playerId]
    if #history > 100 then
        table.remove(history, 1)
    end
end

-- Generate treasure location
function LootManager.GenerateTreasureLocation()
    local treasureSpots = {
        {x = 1234.56, y = -1234.56, z = 30.0, name = "Abandoned warehouse"},
        {x = 2345.67, y = -2345.67, z = 25.0, name = "Old pier"},
        {x = 3456.78, y = -3456.78, z = 40.0, name = "Mountain cave"},
        -- Add more treasure locations
    }
    
    return treasureSpots[math.random(#treasureSpots)]
end

-- Update loot statistics
function LootManager.UpdateLootStatistics()
    -- Calculate loot distribution, success rates, etc.
    local stats = {}
    
    for playerId, history in pairs(LootManager.lootHistory) do
        if #history > 0 then
            stats[playerId] = {
                totalFinds = #history,
                moneyFound = 0,
                itemsFound = {},
                lastActivity = history[#history].timestamp
            }
            
            for _, entry in ipairs(history) do
                if entry.item == "money" then
                    stats[playerId].moneyFound = stats[playerId].moneyFound + entry.amount
                else
                    stats[playerId].itemsFound[entry.item] = (stats[playerId].itemsFound[entry.item] or 0) + entry.amount
                end
            end
        end
    end
    
    WorldSearchUtils.DebugPrint("Updated loot statistics for %d players", 
        WorldSearchUtils.TableCount(stats))
end

-- Utility function to count table entries
function WorldSearchUtils.TableCount(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Export functions for other resources
function AddCustomLootCallback(itemName, callback)
    return LootManager.RegisterLootCallback(itemName, callback)
end

function GetPlayerLootHistory(playerId, limit)
    local history = LootManager.lootHistory[playerId] or {}
    limit = limit or #history
    
    local result = {}
    for i = math.max(1, #history - limit + 1), #history do
        table.insert(result, history[i])
    end
    
    return result
end

-- Initialize on resource start
CreateThread(function()
    Wait(4000)
    LootManager.Initialize()
end)