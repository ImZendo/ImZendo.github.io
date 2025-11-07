-- Interaction Core - Usage Examples
-- Demonstrates advanced usage of the Interaction Core System
-- Created by Anthony Benitez

-- Example 1: Bank Robbery System
InteractionCore:CreateInteraction({
    id = 'bank_vault_door',
    coords = vector3(263.34, 214.37, 101.68),
    type = InteractionCore.Types.PROGRESSIVE,
    helpText = 'Press ~INPUT_CONTEXT~ to hack the vault door',
    job = 'criminal', -- Only criminals can use this
    item = 'hacking_device', -- Requires hacking device
    
    progressBar = {
        duration = 15000, -- 15 seconds
        label = 'Hacking vault security...',
        canCancel = true,
        disableMovement = true,
        disableCombat = true,
        animation = {
            dict = 'anim@heists@keycard@',
            name = 'exit'
        }
    },
    
    conditions = {
        -- Only works during certain hours
        function()
            local hour = GetClockHours()
            return hour >= 22 or hour <= 6
        end,
        -- Requires no police online
        function()
            return GetPoliceCount() == 0
        end
    },
    
    callback = function(data)
        TriggerEvent('banking:client:startRobbery')
        -- Remove hacking device with chance
        if math.random(100) <= 30 then
            TriggerServerEvent('inventory:server:removeItem', 'hacking_device', 1)
            QBCore.Functions.Notify('Your hacking device was fried!', 'error')
        end
    end,
    
    marker = {
        type = 1,
        size = {x = 1.0, y = 1.0, z = 0.5},
        color = {r = 255, g = 0, b = 0, alpha = 100},
        drawDistance = 10.0
    },
    
    cooldown = 300000 -- 5 minute cooldown
})

-- Example 2: Drug Lab Equipment
InteractionCore:CreateInteraction({
    id = 'meth_cook_station',
    coords = vector3(1391.77, 3605.25, 38.94),
    type = InteractionCore.Types.TIMED,
    helpText = 'Hold ~INPUT_CONTEXT~ to cook methamphetamine',
    timer = 30000, -- Must stay for 30 seconds
    
    conditions = {
        -- Must have required ingredients
        function()
            return HasAllItems({'pseudoephedrine', 'acetone', 'lithium'})
        end,
        -- Must not be wanted by police
        function()
            return not IsPlayerWanted()
        end
    },
    
    callback = function(data)
        -- Remove ingredients
        TriggerServerEvent('drugs:server:removeIngredients')
        -- Give meth with random quality
        local quality = math.random(60, 95)
        TriggerServerEvent('drugs:server:giveMeth', quality)
        
        QBCore.Functions.Notify('Meth cooked successfully! Quality: ' .. quality .. '%', 'success')
    end,
    
    blip = {
        sprite = 499,
        color = 1,
        scale = 0.6,
        name = 'Chemical Equipment'
    }
})

-- Example 3: Mechanic Repair Station
InteractionCore:CreateInteraction({
    id = 'mechanic_lift_station_1',
    coords = vector3(-347.13, -133.45, 39.01),
    type = InteractionCore.Types.ANIMATED,
    helpText = 'Press ~INPUT_CONTEXT~ to use repair lift',
    job = 'mechanic',
    
    animation = {
        dict = 'mini@repair',
        name = 'fixing_a_ped',
        duration = 5000
    },
    
    conditions = {
        -- Player must be near a vehicle
        function()
            local vehicle = GetClosestVehicle(GetEntityCoords(PlayerPedId()), 5.0, 0, 71)
            return vehicle ~= 0
        end
    },
    
    callback = function(data)
        local vehicle = GetClosestVehicle(GetEntityCoords(PlayerPedId()), 5.0, 0, 71)
        if vehicle ~= 0 then
            -- Repair vehicle
            SetVehicleFixed(vehicle)
            SetVehicleDeformationFixed(vehicle)
            SetVehicleUndriveable(vehicle, false)
            SetVehicleEngineOn(vehicle, false, false)
            
            QBCore.Functions.Notify('Vehicle repaired successfully!', 'success')
            
            -- Charge customer if NPC vehicle
            if not IsVehiclePlayerOwned(vehicle) then
                TriggerServerEvent('mechanic:server:chargeRepair', 250)
            end
        end
    end
})

-- Example 4: Police Evidence Locker
InteractionCore:CreateInteraction({
    id = 'police_evidence_locker',
    coords = vector3(441.7, -979.6, 30.6),
    type = InteractionCore.Types.MENU,
    helpText = 'Press ~INPUT_CONTEXT~ to access evidence locker',
    job = 'police',
    
    conditions = {
        -- Must be on duty
        function()
            local PlayerData = QBCore.Functions.GetPlayerData()
            return PlayerData.job.onduty
        end,
        -- Must have minimum rank
        function()
            local PlayerData = QBCore.Functions.GetPlayerData()
            return PlayerData.job.grade.level >= 2
        end
    },
    
    menu = {
        {
            header = 'Evidence Locker',
            txt = 'Secure storage for case evidence',
            isMenuHeader = true
        },
        {
            header = 'View Evidence',
            txt = 'Browse current evidence items',
            params = {
                event = 'police:client:viewEvidence'
            }
        },
        {
            header = 'Store Evidence',
            txt = 'Add items to evidence storage',
            params = {
                event = 'police:client:storeEvidence'
            }
        },
        {
            header = 'Case Files',
            txt = 'Access digital case records',
            params = {
                event = 'police:client:caseFiles'
            }
        }
    },
    
    callback = function(data)
        -- Menu will be handled by the menu system
    end,
    
    blip = {
        sprite = 60,
        color = 3,
        scale = 0.7,
        name = 'Evidence Locker'
    }
})

-- Example 5: ATM System
local atmLocations = {
    vector3(295.99, -896.09, 29.22),
    vector3(1138.23, -468.9, 66.73),
    vector3(-721.23, -415.48, 34.98),
    vector3(-1205.02, -324.78, 37.87)
}

for i, coords in pairs(atmLocations) do
    InteractionCore:CreateInteraction({
        id = 'atm_' .. i,
        coords = coords,
        type = InteractionCore.Types.MENU,
        helpText = 'Press ~INPUT_CONTEXT~ to use ATM',
        distance = 2.0,
        
        conditions = {
            -- Must have bank card
            function()
                return HasItem('bank_card')
            end,
            -- Must not be in vehicle
            function()
                return not IsPedInAnyVehicle(PlayerPedId(), false)
            end
        },
        
        menu = {
            {
                header = 'Bank ATM',
                txt = 'Automated Banking Services',
                isMenuHeader = true
            },
            {
                header = 'Check Balance',
                txt = 'View your account balance',
                params = {
                    event = 'banking:client:checkBalance'
                }
            },
            {
                header = 'Withdraw Cash',
                txt = 'Withdraw money from account',
                params = {
                    event = 'banking:client:withdrawCash'
                }
            },
            {
                header = 'Deposit Cash',
                txt = 'Deposit cash into account',
                params = {
                    event = 'banking:client:depositCash'
                }
            },
            {
                header = 'Transfer Money',
                txt = 'Send money to another account',
                params = {
                    event = 'banking:client:transferMoney'
                }
            }
        },
        
        callback = function(data)
            -- Banking menu will handle the rest
        end,
        
        marker = {
            type = 21,
            size = {x = 0.8, y = 0.8, z = 0.8},
            color = {r = 0, g = 255, b = 0, alpha = 100}
        }
    })
end

-- Example 6: Dynamic Shop System
function CreateShopInteraction(shopId, coords, shopType, shopName)
    InteractionCore:CreateInteraction({
        id = 'shop_' .. shopId,
        coords = coords,
        type = InteractionCore.Types.CONDITIONAL,
        helpText = string.format('Press ~INPUT_CONTEXT~ to browse %s', shopName),
        
        conditions = {
            -- Shop must be open
            function()
                local hour = GetClockHours()
                if shopType == '24/7' then
                    return true
                elseif shopType == 'clothing' then
                    return hour >= 8 and hour <= 22
                elseif shopType == 'gun' then
                    return hour >= 10 and hour <= 18
                end
                return false
            end
        },
        
        callback = function(data)
            local hour = GetClockHours()
            if not data.conditions[1]() then
                if shopType == 'clothing' then
                    QBCore.Functions.Notify('Store is closed! Open 8AM - 10PM', 'error')
                elseif shopType == 'gun' then
                    QBCore.Functions.Notify('Gun store is closed! Open 10AM - 6PM', 'error')
                end
                return
            end
            
            TriggerEvent('shop:client:openShop', shopId, shopType)
        end,
        
        blip = {
            sprite = shopType == 'gun' and 110 or shopType == 'clothing' and 73 or 52,
            color = shopType == 'gun' and 1 or shopType == 'clothing' and 3 or 2,
            scale = 0.8,
            name = shopName
        },
        
        marker = {
            type = 20,
            size = {x = 1.0, y = 1.0, z = 1.0},
            color = {r = 0, g = 150, b = 255, alpha = 120}
        }
    })
end

-- Create various shops
CreateShopInteraction('clothing_1', vector3(72.25, -1399.1, 29.38), 'clothing', 'Binco Clothing')
CreateShopInteraction('gunstore_1', vector3(-662.18, -935.52, 21.83), 'gun', 'Ammunition')
CreateShopInteraction('247_1', vector3(25.74, -1347.35, 29.5), '24/7', '24/7 Supermarket')

-- Utility functions for examples
function GetPoliceCount()
    -- Implementation depends on your server setup
    return exports['police']:GetOnlineOfficers() or 0
end

function HasItem(itemName)
    -- Implementation depends on your inventory system
    local PlayerData = QBCore.Functions.GetPlayerData()
    for _, item in pairs(PlayerData.items) do
        if item.name == itemName and item.amount > 0 then
            return true
        end
    end
    return false
end

function HasAllItems(itemList)
    for _, itemName in pairs(itemList) do
        if not HasItem(itemName) then
            return false
        end
    end
    return true
end

function IsPlayerWanted()
    -- Implementation depends on your police system
    return exports['police']:IsPlayerWanted(PlayerId()) or false
end

function IsVehiclePlayerOwned(vehicle)
    -- Implementation depends on your garage system
    return exports['garage']:IsPlayerVehicle(vehicle) or false
end