-- =====================================================
-- WORLD SEARCH SYSTEM - UTILITY FUNCTIONS
-- =====================================================

WorldSearchUtils = {}

-- Calculate distance between two points
function WorldSearchUtils.GetDistance(pos1, pos2)
    if type(pos1) == "table" then
        pos1 = vector3(pos1.x or pos1[1], pos1.y or pos1[2], pos1.z or pos1[3])
    end
    if type(pos2) == "table" then
        pos2 = vector3(pos2.x or pos2[1], pos2.y or pos2[2], pos2.z or pos2[3])
    end
    return #(pos1 - pos2)
end

-- Format time in MM:SS format
function WorldSearchUtils.FormatTime(milliseconds)
    local seconds = math.floor(milliseconds / 1000)
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60
    return string.format("%02d:%02d", minutes, seconds)
end

-- Generate a unique ID
function WorldSearchUtils.GenerateId()
    return string.format("%s_%d", "ws", math.random(100000, 999999))
end

-- Check if player has required item (framework agnostic)
function WorldSearchUtils.HasItem(playerId, itemName, amount)
    amount = amount or 1
    
    -- ESX Check
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            local item = xPlayer.getInventoryItem(itemName)
            return item and item.count >= amount
        end
    end
    
    -- QBCore Check  
    if QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local item = Player.Functions.GetItemByName(itemName)
            return item and item.amount >= amount
        end
    end
    
    -- Default/Custom implementation
    -- Trigger event and wait for response
    return true -- Fallback - allow search
end

-- Check if player has required job (framework agnostic)
function WorldSearchUtils.HasJob(playerId, jobName, grade)
    grade = grade or 0
    
    -- ESX Check
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            return xPlayer.job.name == jobName and xPlayer.job.grade >= grade
        end
    end
    
    -- QBCore Check
    if QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            return Player.PlayerData.job.name == jobName and Player.PlayerData.job.grade.level >= grade
        end
    end
    
    return true -- Fallback - allow access
end

-- Give item to player (framework agnostic)
function WorldSearchUtils.GiveItem(playerId, itemName, amount, metadata)
    amount = amount or 1
    
    if WorldSearchConfig.Debug then
        print(string.format("[WorldSearch] Giving %s x%d to player %s", itemName, amount, playerId))
    end
    
    -- ESX Implementation
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            xPlayer.addInventoryItem(itemName, amount, metadata)
            return true
        end
    end
    
    -- QBCore Implementation
    if QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            Player.Functions.AddItem(itemName, amount, false, metadata)
            return true
        end
    end
    
    -- Trigger custom event for other frameworks
    TriggerEvent('worldsearch:giveItem', playerId, itemName, amount, metadata)
    return true
end

-- Give money to player (framework agnostic)
function WorldSearchUtils.GiveMoney(playerId, amount, moneyType)
    moneyType = moneyType or 'cash'
    
    if WorldSearchConfig.Debug then
        print(string.format("[WorldSearch] Giving $%d (%s) to player %s", amount, moneyType, playerId))
    end
    
    -- ESX Implementation
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            xPlayer.addMoney(moneyType, amount)
            return true
        end
    end
    
    -- QBCore Implementation  
    if QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            Player.Functions.AddMoney(moneyType, amount)
            return true
        end
    end
    
    -- Trigger custom event for other frameworks
    TriggerEvent('worldsearch:giveMoney', playerId, amount, moneyType)
    return true
end

-- Send notification to player (framework agnostic)
function WorldSearchUtils.Notify(playerId, message, type, duration)
    type = type or 'info'
    duration = duration or 4000
    
    -- ESX Implementation
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            xPlayer.showNotification(message)
            return
        end
    end
    
    -- QBCore Implementation
    if QBCore then
        TriggerClientEvent('QBCore:Notify', playerId, message, type, duration)
        return
    end
    
    -- Fallback - use FiveM native
    TriggerClientEvent('chat:addMessage', playerId, {
        color = {255, 255, 255},
        multiline = true,
        args = {"World Search", message}
    })
end

-- Validate search zone data
function WorldSearchUtils.ValidateSearchZone(data)
    if not data then
        return false, "No data provided"
    end
    
    if not data.name or type(data.name) ~= "string" then
        return false, "Invalid or missing name"
    end
    
    if not data.coords then
        return false, "Missing coordinates" 
    end
    
    if not data.range or type(data.range) ~= "number" or data.range <= 0 then
        return false, "Invalid range"
    end
    
    if not data.lootTable or type(data.lootTable) ~= "string" then
        return false, "Invalid loot table"
    end
    
    return true
end

-- Get random item from loot table
function WorldSearchUtils.RollLoot(lootTable)
    if not lootTable or #lootTable == 0 then
        return nil
    end
    
    local roll = math.random(1, 100)
    local currentChance = 0
    
    for _, loot in ipairs(lootTable) do
        currentChance = currentChance + loot.chance
        if roll <= currentChance then
            local amount = 1
            if loot.min and loot.max then
                amount = math.random(loot.min, loot.max)
            elseif loot.amount then
                amount = loot.amount
            end
            
            return {
                item = loot.item,
                amount = amount,
                message = loot.message
            }
        end
    end
    
    -- Fallback to nothing
    return {
        item = "nothing",
        amount = 0,
        message = "Nothing found..."
    }
end

-- Debug print function
function WorldSearchUtils.DebugPrint(message, ...)
    if WorldSearchConfig.Debug then
        print(string.format("[WorldSearch DEBUG] " .. message, ...))
    end
end