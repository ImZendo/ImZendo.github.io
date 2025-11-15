-- lockpick_resource/server.lua
-- Enhanced server-side lockpick system with security, logging, and framework integration

local Framework = nil
local cooldowns = {}
local lockpickAttempts = {}

-- Framework Detection
CreateThread(function()
    -- Wait for resources to load
    Wait(1000)
    
    -- Auto-detect framework
    if GetResourceState('es_extended') == 'started' then
        Framework = 'ESX'
        ESX = exports['es_extended']:getSharedObject()
    elseif GetResourceState('qb-core') == 'started' then
        Framework = 'QB'
        QBCore = exports['qb-core']:GetCoreObject()
    end
    
    if Config.Debug then
        print("[Lockpick] Server framework detected: " .. (Framework or "None"))
    end
end)

-- Utility Functions
local function GetPlayerIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)
    for _, id in pairs(identifiers) do
        if string.find(id, "license:") then
            return id
        end
    end
    return nil
end

local function HasItem(src, itemName, amount)
    if not Config.RequiredItem.enabled then
        return true
    end
    
    amount = amount or 1
    
    if Framework == 'ESX' then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            local item = xPlayer.getInventoryItem(itemName)
            return item and item.count >= amount
        end
    elseif Framework == 'QB' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            local item = Player.Functions.GetItemByName(itemName)
            return item and item.amount >= amount
        end
    end
    
    -- Fallback - assume player has item
    return true
end

local function RemoveItem(src, itemName, amount)
    if not Config.RequiredItem.enabled then
        return true
    end
    
    amount = amount or 1
    
    if Framework == 'ESX' then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            xPlayer.removeInventoryItem(itemName, amount)
            return true
        end
    elseif Framework == 'QB' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            Player.Functions.RemoveItem(itemName, amount)
            return true
        end
    end
    
    return false
end

local function IsOnCooldown(src)
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return false end
    
    local cooldownTime = cooldowns[identifier]
    if cooldownTime and GetGameTimer() < cooldownTime then
        return true
    end
    
    return false
end

local function SetCooldown(src)
    local identifier = GetPlayerIdentifier(src)
    if identifier then
        cooldowns[identifier] = GetGameTimer() + Config.LockpickSettings.cooldownTime
    end
end

local function GetAttempts(src)
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return 0 end
    
    return lockpickAttempts[identifier] or 0
end

local function AddAttempt(src)
    local identifier = GetPlayerIdentifier(src)
    if identifier then
        lockpickAttempts[identifier] = (lockpickAttempts[identifier] or 0) + 1
    end
end

local function ResetAttempts(src)
    local identifier = GetPlayerIdentifier(src)
    if identifier then
        lockpickAttempts[identifier] = 0
    end
end

local function LogLockpickAttempt(src, vehicle, success, reason)
    if not Config.Logging.enabled then return end
    
    local playerName = GetPlayerName(src)
    local identifier = GetPlayerIdentifier(src)
    local vehicleModel = GetEntityModel(vehicle)
    local vehicleName = GetDisplayNameFromVehicleModel(vehicleModel)
    local vehicleCoords = GetEntityCoords(vehicle)
    
    local logData = {
        player = {
            name = playerName,
            identifier = identifier,
            source = src
        },
        vehicle = {
            model = vehicleModel,
            name = vehicleName,
            coordinates = vehicleCoords,
            netId = NetworkGetNetworkIdFromEntity(vehicle)
        },
        success = success,
        reason = reason or "N/A",
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    }
    
    -- Log to console
    local logMessage = string.format(
        "[Lockpick] %s (%s) %s lockpicking %s at %s",
        playerName,
        identifier,
        success and "succeeded" or "failed",
        vehicleName,
        string.format("%.2f, %.2f, %.2f", vehicleCoords.x, vehicleCoords.y, vehicleCoords.z)
    )
    
    print(logMessage)
    
    -- Discord webhook logging
    if Config.Logging.webhook and Config.Logging.webhook ~= "" then
        local embed = {
            {
                title = "Lockpick " .. (success and "Success" or "Failure"),
                color = success and 3066993 or 15158332, -- Green or Red
                fields = {
                    {
                        name = "Player",
                        value = string.format("%s (%s)", playerName, identifier),
                        inline = true
                    },
                    {
                        name = "Vehicle",
                        value = vehicleName,
                        inline = true
                    },
                    {
                        name = "Location",
                        value = string.format("%.2f, %.2f, %.2f", vehicleCoords.x, vehicleCoords.y, vehicleCoords.z),
                        inline = true
                    },
                    {
                        name = "Result",
                        value = reason or (success and "Success" or "Failed"),
                        inline = false
                    }
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
        
        PerformHttpRequest(Config.Logging.webhook, function(err, text, headers) end, 'POST', json.encode({
            embeds = embed
        }), { ['Content-Type'] = 'application/json' })
    end
end

local function ValidateLockpickAttempt(src, vehicle)
    -- Check if player exists
    if not src or src <= 0 then
        return false, "Invalid player"
    end
    
    -- Check if vehicle exists
    if not DoesEntityExist(vehicle) then
        return false, "Vehicle not found"
    end
    
    -- Check if player has required item
    if not HasItem(src, Config.RequiredItem.itemName) then
        return false, "Missing required item: " .. Config.RequiredItem.itemName
    end
    
    -- Check cooldown
    if IsOnCooldown(src) then
        return false, "Player is on cooldown"
    end
    
    -- Check distance (server-side validation)
    local playerPed = GetPlayerPed(src)
    if not DoesEntityExist(playerPed) then
        return false, "Player not found"
    end
    
    local playerCoords = GetEntityCoords(playerPed)
    local vehicleCoords = GetEntityCoords(vehicle)
    local distance = #(playerCoords - vehicleCoords)
    
    if distance > Config.VehicleSettings.lockpickRange then
        return false, "Too far from vehicle"
    end
    
    -- Check if vehicle is already unlocked
    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    if lockStatus == 1 then
        return false, "Vehicle is already unlocked"
    end
    
    -- Check vehicle class and model restrictions (server-side validation)
    local vehicleClass = GetVehicleClass(vehicle)
    local vehicleModel = GetEntityModel(vehicle)
    local vehicleName = string.lower(GetDisplayNameFromVehicleModel(vehicleModel))
    
    -- Check allowed classes
    local isClassAllowed = false
    for _, class in pairs(Config.VehicleSettings.allowedVehicleClasses) do
        if class == vehicleClass then
            isClassAllowed = true
            break
        end
    end
    
    if not isClassAllowed then
        return false, "Vehicle class not allowed"
    end
    
    -- Check blacklisted models
    for _, blacklisted in pairs(Config.VehicleSettings.blacklistedModels) do
        if string.lower(blacklisted) == vehicleName then
            return false, "Vehicle model is blacklisted"
        end
    end
    
    return true, nil
end

-- Register the interaction with interaction_core
CreateThread(function()
    -- Wait for core to load before registering
    Wait(2000)
    
    -- Test if interaction_core is available
    if GetResourceState('interaction_core') ~= 'started' then
        print("[Lockpick] ❌ interaction_core is not started!")
        return
    end
    
    -- Test if export function exists
    local success, error = pcall(function()
        return exports['interaction_core']:RegisterInteraction({
            id = "test",
            type = 'custom'
        })
    end)
    
    if not success then
        print("[Lockpick] ❌ RegisterInteraction export not found: " .. tostring(error))
        return
    end
    
    -- Try to register the actual interaction (using numeric constants since we don't have access to InteractionCoreConfig)
    success = exports['interaction_core']:RegisterInteraction({
        id = "lockpick:vehicle",
        type = 1, -- VEHICLE type
        range = Config.VehicleSettings.lockpickRange,
        prompt = 'Press ~INPUT_CONTEXT~ to lockpick vehicle',
        validations = {
            {
                type = 1, -- DISTANCE validation type
                range = Config.VehicleSettings.lockpickRange
            },
            {
                type = 5, -- CUSTOM validation type
                callback = function(playerId, context, interaction)
                    local vehicle = NetworkGetEntityFromNetworkId(context.targetNetId)
                    if not DoesEntityExist(vehicle) then return false end
                    return GetVehicleDoorLockStatus(vehicle) == 2 -- Locked
                end
            }
        },
        clientCallback = "lockpick:openMinigame",
        -- This is just for validation since we're using clientCallback
        -- The actual lockpicking is handled by the client minigame
        serverCallback = function(src, context, cb)
            local vehicle = NetworkGetEntityFromNetworkId(context.targetNetId)
            
            -- Validate the attempt
            local isValid, validationError = ValidateLockpickAttempt(src, vehicle)
            if not isValid then
                LogLockpickAttempt(src, vehicle, false, validationError)
                return cb(false, validationError)
            end
            
            -- Just trigger the minigame - actual success/failure handled by clientCallback response
            cb(true, "Starting lockpick minigame...")
        end
    })

    if success then
        print("[Lockpick] ✅ Lockpick interaction registered successfully")
    else
        print("[Lockpick] ⚠️ Failed to register lockpick interaction")
    end
end)

-- Handle lockpick minigame results from client
RegisterNetEvent('interaction:clientCallback', function(interactionId, success, msg, data)
    if interactionId ~= "lockpick:vehicle" then return end
    
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(data.targetNetId)
    
    -- Add attempt counter
    AddAttempt(src)
    
    if success then
        -- Success case
        SetVehicleDoorsLocked(vehicle, 1) -- Unlock vehicle
        
        -- Remove item on successful use if configured
        if Config.RequiredItem.removeOnUse then
            RemoveItem(src, Config.RequiredItem.itemName, 1)
        end
        
        -- Reset attempts on success
        ResetAttempts(src)
        
        -- Log successful attempt
        LogLockpickAttempt(src, vehicle, true, "Successfully unlocked")
    else
        -- Failure case
        SetCooldown(src)
        
        -- Check if lockpick should break
        if Config.RequiredItem.removeOnBreak and math.random() < Config.LockpickSettings.breakChance then
            RemoveItem(src, Config.RequiredItem.itemName, 1)
            LogLockpickAttempt(src, vehicle, false, "Lockpick broke")
        else
            LogLockpickAttempt(src, vehicle, false, "Failed to pick lock")
        end
    end
end)

-- Manual lockpick server event (for direct command usage)
RegisterNetEvent('lockpick:server:attemptLockpick', function(vehicleNetId)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    
    -- Validate the attempt
    local isValid, validationError = ValidateLockpickAttempt(src, vehicle)
    if not isValid then
        TriggerClientEvent('lockpick:client:result', src, false, validationError)
        LogLockpickAttempt(src, vehicle, false, validationError)
        return
    end
    
    -- For manual attempts, we simulate the minigame server-side
    local success = math.random() < Config.LockpickSettings.successChance
    
    if success then
        SetVehicleDoorsLocked(vehicle, 1)
        
        if Config.RequiredItem.removeOnUse then
            RemoveItem(src, Config.RequiredItem.itemName, 1)
        end
        
        ResetAttempts(src)
        LogLockpickAttempt(src, vehicle, true, "Manual lockpick success")
        TriggerClientEvent('lockpick:client:result', src, true, "Vehicle unlocked successfully!")
    else
        SetCooldown(src)
        AddAttempt(src)
        
        if Config.RequiredItem.removeOnBreak and math.random() < Config.LockpickSettings.breakChance then
            RemoveItem(src, Config.RequiredItem.itemName, 1)
            TriggerClientEvent('lockpick:client:result', src, false, "Your lockpick broke!")
        else
            TriggerClientEvent('lockpick:client:result', src, false, "Failed to pick the lock.")
        end
        
        LogLockpickAttempt(src, vehicle, false, "Manual lockpick failure")
    end
end)

-- Admin commands for testing/management
if Config.Debug then
    RegisterCommand('lockpick_reset_cooldown', function(source, args, rawCommand)
        local src = source
        if src == 0 then -- Console
            local targetSrc = tonumber(args[1])
            if targetSrc then
                local identifier = GetPlayerIdentifier(targetSrc)
                if identifier then
                    cooldowns[identifier] = nil
                    print("[Lockpick] Cooldown reset for player " .. targetSrc)
                end
            end
        end
    end, true)
    
    RegisterCommand('lockpick_reset_attempts', function(source, args, rawCommand)
        local src = source
        if src == 0 then -- Console
            local targetSrc = tonumber(args[1])
            if targetSrc then
                ResetAttempts(targetSrc)
                print("[Lockpick] Attempts reset for player " .. targetSrc)
            end
        end
    end, true)
end

-- Cleanup disconnected players
AddEventHandler('playerDropped', function(reason)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    
    if identifier then
        cooldowns[identifier] = nil
        lockpickAttempts[identifier] = nil
    end
end)

-- Handle durability reduction for custom items
RegisterNetEvent('zendo-lockpick:reduceDurability', function(itemName, durabilityLoss)
    local src = source
    
    -- Only process if custom durability system is enabled
    if not Config.RequiredItem.customItem.durabilityEnabled then
        return
    end
    
    if Framework == 'ESX' then
        -- ESX durability handling (if supported by your inventory)
        -- You may need to adapt this to your specific ESX inventory system
        TriggerClientEvent('esx:showNotification', src, 'Lockpick durability reduced')
    elseif Framework == 'QB' then
        -- QB-Core durability handling
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            -- Example QB durability reduction - adapt to your inventory system
            Player.Functions.SetItemMetadata(itemName, { durability = durabilityLoss })
        end
    end
end)

-- Built-in item management (if you want to add the lockpick item to inventories)
RegisterNetEvent('zendo-lockpick:addBuiltInItem', function(amount)
    local src = source
    amount = amount or 1
    
    if not Config.RequiredItem.useBuiltInItem then
        return
    end
    
    local itemData = Config.RequiredItem.builtInItem
    
    if Framework == 'ESX' then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            xPlayer.addInventoryItem(itemData.name, amount)
        end
    elseif Framework == 'QB' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            Player.Functions.AddItem(itemData.name, amount, false, {
                description = itemData.description,
                weight = itemData.weight
            })
        end
    end
end)

if Config.Debug then
    print("[Lockpick] Server script loaded with flexible item system")
end
