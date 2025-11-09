-- Vehicle Lockpicking System
-- Let's players break into locked vehicles with a fun minigame

local playerIsTryingToLockpick = false
local lockpickingAnimation = "mini@safe_cracking"
local animationName = "dial_turn_clock_normal"

-- Keep track of which vehicle we're trying to unlock
local targetVehicleNetId = nil
local targetVehicle = nil

-- For showing nice popup messages
local isShowingPopup = false

-- Show a nice popup message to the player
local function ShowPlayerPopup(messageType, title, message, duration)
    duration = duration or (messageType == 'success' and 5000 or 4000)
    
    SetNuiFocus(false, false) -- Make sure UI doesn't interfere with game
    SendNUIMessage({
        action = 'showNotificationPopup',
        type = messageType,
        title = title,
        message = message,
        duration = duration
    })
    
    isShowingPopup = true
    
    -- Hide the popup automatically after some time
    CreateThread(function()
        Wait(duration + 500)
        isShowingPopup = false
    end)
end

-- Hide any popup that's currently showing
local function HidePlayerPopup()
    if isShowingPopup then
        SendNUIMessage({
            action = 'hideNotificationPopup'
        })
        isShowingPopup = false
    end
end

-- Framework Detection
local Framework = nil
local PlayerData = {}

-- Initialize framework
CreateThread(function()
    -- Auto-detect framework
    if GetResourceState('es_extended') == 'started' then
        Framework = 'ESX'
        ESX = exports['es_extended']:getSharedObject()
        PlayerData = ESX.GetPlayerData()
        
        RegisterNetEvent('esx:playerLoaded', function(xPlayer)
            PlayerData = xPlayer
        end)
        
        RegisterNetEvent('esx:setJob', function(job)
            PlayerData.job = job
        end)
    elseif GetResourceState('qb-core') == 'started' then
        Framework = 'QB'
        QBCore = exports['qb-core']:GetCoreObject()
        PlayerData = QBCore.Functions.GetPlayerData()
        
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
            PlayerData = QBCore.Functions.GetPlayerData()
        end)
        
        RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
            PlayerData.job = JobInfo
        end)
    end
    
    if Config.Debug then
        print("[Lockpick] Framework detected: " .. (Framework or "None"))
    end
end)

-- Utility Functions
local function ShowNotification(message, type)
    if Framework == 'ESX' then
        ESX.ShowNotification(message)
    elseif Framework == 'QB' then
        QBCore.Functions.Notify(message, type or 'primary')
    else
        -- Fallback to chat
        TriggerEvent('chat:addMessage', {
            args = { '^3[Lockpick]', message }
        })
    end
end

-- Get the correct lockpick item name based on configuration
local function GetLockpickItemName()
    if Config.RequiredItem.useBuiltInItem then
        return Config.RequiredItem.builtInItem.name
    else
        return Config.RequiredItem.customItem.itemName
    end
end

-- Check if player has the required lockpick item
local function HasLockpickItem()
    if not Config.RequiredItem.enabled then
        return true
    end
    
    local itemName = GetLockpickItemName()
    
    if Framework == 'ESX' then
        local item = ESX.SearchInventory(itemName, 1)
        return item ~= nil and item.count > 0
    elseif Framework == 'QB' then
        local Player = QBCore.Functions.GetPlayerData()
        if Player.items then
            for _, item in pairs(Player.items) do
                if item.name == itemName and item.amount > 0 then
                    return true
                end
            end
        end
        return false
    end
    
    -- Fallback - assume player has item if no framework detected
    return true
end

-- Remove lockpick item from inventory based on configuration
local function RemoveLockpickItem(amount)
    local itemName = GetLockpickItemName()
    amount = amount or 1
    
    if Framework == 'ESX' then
        TriggerServerEvent('esx:removeInventoryItem', itemName, amount)
    elseif Framework == 'QB' then
        TriggerServerEvent('inventory:server:RemoveItem', itemName, amount)
    end
    
    -- Handle durability system if enabled
    if not Config.RequiredItem.useBuiltInItem and Config.RequiredItem.customItem.durabilityEnabled then
        TriggerServerEvent('zendo-lockpick:reduceDurability', itemName, Config.RequiredItem.customItem.durabilityLoss)
    end
end

local function GetVehicleInDirection()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local forwardVector = GetEntityForwardVector(playerPed)
    local forwardCoords = playerCoords + forwardVector * Config.VehicleSettings.lockpickRange
    
    local vehicle = GetClosestVehicle(forwardCoords.x, forwardCoords.y, forwardCoords.z, Config.VehicleSettings.lockpickRange, 0, 70)
    
    if DoesEntityExist(vehicle) then
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(playerCoords - vehicleCoords)
        
        if distance <= Config.VehicleSettings.lockpickRange then
            return vehicle
        end
    end
    
    return nil
end

local function CanLockpickVehicle(vehicle)
    if not DoesEntityExist(vehicle) then
        return false, "Vehicle not found"
    end
    
    -- Check if vehicle is already unlocked
    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    if lockStatus == 1 then
        return false, "Vehicle is already unlocked"
    end
    
    -- Check vehicle class
    local vehicleClass = GetVehicleClass(vehicle)
    local allowedClasses = Config.VehicleSettings.allowedVehicleClasses
    local isClassAllowed = false
    
    for _, class in pairs(allowedClasses) do
        if class == vehicleClass then
            isClassAllowed = true
            break
        end
    end
    
    if not isClassAllowed then
        return false, "This type of vehicle cannot be lockpicked"
    end
    
    -- Check blacklisted models
    local vehicleModel = GetEntityModel(vehicle)
    local vehicleName = string.lower(GetDisplayNameFromVehicleModel(vehicleModel))
    
    for _, blacklisted in pairs(Config.VehicleSettings.blacklistedModels) do
        if string.lower(blacklisted) == vehicleName then
            return false, "This vehicle cannot be lockpicked"
        end
    end
    
    -- Check if it's an emergency vehicle
    if not Config.VehicleSettings.emergencyVehicles then
        local vehicleClass = GetVehicleClass(vehicle)
        if vehicleClass == 18 then -- Emergency vehicles
            return false, "Emergency vehicles cannot be lockpicked"
        end
    end
    
    -- Check if it's a player vehicle (if configured)
    if not Config.VehicleSettings.playerVehicles then
        -- This would require integration with your vehicle ownership system
        -- For now, we'll skip this check
    end
    
    return true, nil
end

local function PlayLockpickAnimation()
    local playerPed = PlayerPedId()
    
    if Config.UseAnimations then
        RequestAnimDict(lockpickingAnimation)
        while not HasAnimDictLoaded(lockpickingAnimation) do
            Wait(1)
        end
        
        TaskPlayAnim(playerPed, lockpickingAnimation, animationName, 8.0, -8.0, -1, 1, 0, false, false, false)
    end
end

local function StopLockpickAnimation()
    local playerPed = PlayerPedId()
    
    if Config.UseAnimations then
        ClearPedTasksImmediately(playerPed)
    end
end

-- Start the actual lockpicking minigame
local function BeginLockpickingMinigame(vehicle, callback)
    if playerIsTryingToLockpick then
        return -- Already busy with another lockpick attempt
    end
    
    playerIsTryingToLockpick = true
    
    -- Make sure player has the required lockpick tool
    if not HasLockpickItem() then
        local itemName = Config.RequiredItem.useBuiltInItem and 
                        Config.RequiredItem.builtInItem.label or 
                        "a lockpick"
        
        ShowPlayerPopup(
            'failure',
            'Missing Equipment!',
            'You need ' .. itemName .. ' to break into vehicles. Find one and come back.'
        )
        playerIsTryingToLockpick = false
        return callback(false)
    end
    
    -- Make the player do a lockpicking animation
    PlayLockpickAnimation()
    
    -- Prevent player from doing other things while lockpicking
    CreateThread(function()
        while playerIsTryingToLockpick do
            DisableControlAction(0, 24, true) -- Can't attack
            DisableControlAction(0, 25, true) -- Can't aim
            DisableControlAction(0, 44, true) -- Can't take cover
            DisableControlAction(0, 37, true) -- Can't switch weapons
            DisableControlAction(0, 199, true) -- Can't open pause menu
            DisableControlAction(0, 200, true) -- Can't open pause menu
            Wait(1)
        end
    end)
    
    -- Set up the minigame with current difficulty settings
    local gameSettings = {
        gameType = Config.Minigame.type,
        difficulty = Config.LockpickSettings.difficulty,
        pins = Config.Minigame.pins,
        maxAttempts = Config.LockpickSettings.maxAttempts,
        timeLimit = Config.LockpickSettings.timeLimit
    }
    
    -- Show the lockpicking interface to the player
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'startLockpick',
        config = gameSettings
    })
end

-- Handle what happens when the minigame finishes
RegisterNUICallback('lockpickResult', function(data, cb)
    SetNuiFocus(false, false)
    playerIsTryingToLockpick = false
    StopLockpickAnimation()
    
    -- Check if the player succeeded or failed
    if data.success then
        ShowNotification(Config.Notifications.success.message, Config.Notifications.success.type)
        
        -- Let's see what we're working with
        print("^2[Lockpick Success] Trying to unlock the vehicle now...^0")
        print("^3[Debug] Target Vehicle: " .. tostring(targetVehicle) .. "^0")
        print("^3[Debug] Target NetId: " .. tostring(targetVehicleNetId) .. "^0")
        
        -- Find the vehicle we were trying to unlock
        local vehicleToUnlock = nil
        
        if targetVehicleNetId then
            vehicleToUnlock = NetToVeh(targetVehicleNetId)
            print("^3[Vehicle Recovery] Found vehicle using NetId " .. targetVehicleNetId .. ": " .. tostring(vehicleToUnlock) .. "^0")
        elseif targetVehicle and DoesEntityExist(targetVehicle) then
            vehicleToUnlock = targetVehicle
            print("^3[Vehicle Recovery] Using stored vehicle: " .. tostring(vehicleToUnlock) .. "^0")
        end
        
        -- Actually unlock the vehicle doors
        if vehicleToUnlock and DoesEntityExist(vehicleToUnlock) then
            local currentLockStatus = GetVehicleDoorLockStatus(vehicleToUnlock)
            print("^3[Vehicle Status] Current lock status: " .. currentLockStatus .. "^0")
            
            SetVehicleDoorsLocked(vehicleToUnlock, 1) -- 1 means unlocked
            SetVehicleDoorsLockedForAllPlayers(vehicleToUnlock, false)
            
            -- Double-check that it worked
            local newLockStatus = GetVehicleDoorLockStatus(vehicleToUnlock)
            print("^2[Success!] Vehicle unlocked! Status changed from " .. currentLockStatus .. " to " .. newLockStatus .. "^0")
            
            -- Tell the player they did great
            ShowPlayerPopup(
                'success',
                'Vehicle Unlocked!',
                'Nice work! The vehicle is now unlocked and ready to drive.',
                5000
            )
            
            -- Keep track of this vehicle
            targetVehicle = vehicleToUnlock
        else
            print("^1[Error] Something went wrong - couldn't find the vehicle to unlock!^0")
            print("^1[Debug] NetId: " .. tostring(targetVehicleNetId) .. "^0")
            print("^1[Debug] Vehicle Entity: " .. tostring(targetVehicle) .. "^0")
        end
        
        -- Remove item on successful use if configured
        local removeOnUse = Config.RequiredItem.useBuiltInItem or 
                           Config.RequiredItem.customItem.removeOnUse
        if removeOnUse then
            RemoveLockpickItem(1)
        end
        
        TriggerServerEvent('interaction:clientCallback', "lockpick:vehicle", true, "Vehicle unlocked successfully!", {
            targetNetId = targetVehicleNetId
        })
    else
        -- Remove item on break if configured
        local removeOnBreak = Config.RequiredItem.useBuiltInItem or 
                             Config.RequiredItem.customItem.removeOnBreak
        local breakChance = Config.RequiredItem.consumeChance or Config.LockpickSettings.breakChance
        
        if removeOnBreak and math.random() < breakChance then
            RemoveLockpickItem(1)
            -- Tell player their tool broke
            ShowPlayerPopup(
                'failure',
                'Lockpick Broke!',
                'Oops! Your lockpick snapped. You\'ll need to find another one to try again.',
                5000
            )
        else
            -- Tell player they just failed this time
            ShowPlayerPopup(
                'failure',
                'Lockpicking Failed!',
                'That didn\'t work out. The lock was tougher than expected. Try again!',
                4000
            )
        end
        
        TriggerServerEvent('interaction:clientCallback', "lockpick:vehicle", false, "Failed to pick the lock", {
            targetNetId = targetVehicleNetId
        })
    end
    
    cb('ok')
end)

-- Progress notification callback (optional)
RegisterNUICallback('lockpickProgress', function(data, cb)
    if Config.ShowProgress then
        ShowNotification("🎯 " .. data.message, "success")
    end
    cb('ok')
end)

RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    isLockpicking = false
    StopLockpickAnimation()
    cb('ok')
end)

-- Register minigame event called from interaction_core
-- When the interaction system tells us to start lockpicking
RegisterNetEvent('lockpick:openMinigame', function(context)
    local vehicle = NetToVeh(context.targetNetId)
    targetVehicleNetId = context.targetNetId
    targetVehicle = vehicle
    
    -- Debug minigame startup
    print("^3[ZendoLockpick] MINIGAME START - Debug info:^0")
    print("^3[ZendoLockpick] NetId received: " .. tostring(context.targetNetId) .. "^0")
    print("^3[ZendoLockpick] Vehicle entity: " .. tostring(vehicle) .. "^0")
    print("^3[ZendoLockpick] Vehicle exists: " .. tostring(DoesEntityExist(vehicle)) .. "^0")
    print("^3[ZendoLockpick] Stored NetId: " .. tostring(targetVehicleNetId) .. "^0")
    print("^3[ZendoLockpick] Stored Vehicle: " .. tostring(targetVehicle) .. "^0")
    if DoesEntityExist(vehicle) then
        local lockStatus = GetVehicleDoorLockStatus(vehicle)
        print("^3[ZendoLockpick] Current lock status: " .. lockStatus .. "^0")
    end
    
    -- Validate vehicle
    local canLockpick, reason = CanLockpickVehicle(vehicle)
    if not canLockpick then
        ShowNotification(reason, "error")
        print("^1[ZendoLockpick] Validation failed: " .. reason .. "^0")
        return
    end
    
    -- Show player what's about to happen
    ShowPlayerPopup(
        'start',
        'Starting Lockpick',
        'Line up the red marker with the green zone and hit SPACE. Take your time and be precise!'
    )
    
    -- Begin the lockpicking minigame
    BeginLockpickingMinigame(vehicle, function(success)
        -- The result will be handled by the minigame interface
    end)
end)

-- Listen for result
RegisterNetEvent('interaction:success', function(interactionId, msg)
    if interactionId ~= "lockpick:vehicle" then return end
    if Config.Debug then
        print("[Lockpick] Success: " .. msg)
    end
end)

RegisterNetEvent('interaction:failed', function(interactionId, msg)
    if interactionId ~= "lockpick:vehicle" then return end
    if Config.Debug then
        print("[Lockpick] Failed: " .. msg)
    end
end)



-- Clean up when the script stops
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if playerIsTryingToLockpick then
            SetNuiFocus(false, false)
            StopLockpickAnimation()
            playerIsTryingToLockpick = false
        end
        -- Hide any popups that might be showing
        HidePlayerPopup()
    end
end)

-- Print startup info about item configuration
if Config.Debug then
    if Config.RequiredItem.enabled then
        local itemType = Config.RequiredItem.useBuiltInItem and "Built-in lockpick system" or "Custom inventory item"
        local itemName = Config.RequiredItem.useBuiltInItem and 
                        Config.RequiredItem.builtInItem.name or 
                        Config.RequiredItem.customItem.itemName
        print("[Lockpick] Client loaded - Item system: " .. itemType .. " (" .. itemName .. ")")
    else
        print("[Lockpick] Client loaded - No item requirement (free lockpicking)")
    end
end
