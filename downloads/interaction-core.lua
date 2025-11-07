-- Interaction Core System - Main Module
-- Advanced interaction framework for FiveM servers
-- Created by Anthony Benitez

local InteractionCore = {}
InteractionCore.interactions = {}
InteractionCore.activeInteractions = {}
InteractionCore.playerInteractions = {}

-- Configuration
InteractionCore.Config = {
    maxInteractionDistance = 2.5,
    keyBind = 38, -- E key
    showHelpText = true,
    animationDuration = 2000,
    cooldownTime = 1000,
    debugMode = false
}

-- Interaction types
InteractionCore.Types = {
    SIMPLE = 'simple',           -- Basic interaction with callback
    ANIMATED = 'animated',       -- Interaction with animation
    PROGRESSIVE = 'progressive', -- Progress bar interaction
    MENU = 'menu',              -- Opens menu/UI
    CONDITIONAL = 'conditional', -- Conditional based on player state
    TIMED = 'timed'             -- Time-based interaction
}

-- Initialize the system
function InteractionCore:Initialize()
    self:CreateKeyMapping()
    self:StartInteractionThread()
    self:RegisterEvents()
    
    if self.Config.debugMode then
        print('[INTERACTION-CORE] System initialized successfully')
    end
end

-- Create key mapping
function InteractionCore:CreateKeyMapping()
    RegisterKeyMapping('interact', 'Interact', 'keyboard', 'e')
    RegisterCommand('interact', function()
        self:ProcessInteraction()
    end, false)
end

-- Start main interaction thread
function InteractionCore:StartInteractionThread()
    Citizen.CreateThread(function()
        while true do
            local sleep = 500
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            
            -- Clear previous active interactions
            self.activeInteractions = {}
            
            -- Check all registered interactions
            for id, interaction in pairs(self.interactions) do
                if self:IsInteractionValid(interaction, playerPed, playerCoords) then
                    local distance = #(playerCoords - interaction.coords)
                    
                    if distance <= interaction.distance then
                        self.activeInteractions[id] = interaction
                        sleep = 0
                        
                        -- Show help text if enabled
                        if self.Config.showHelpText and interaction.helpText then
                            self:ShowHelpText(interaction.helpText)
                        end
                    end
                end
            end
            
            Wait(sleep)
        end
    end)
end

-- Register events
function InteractionCore:RegisterEvents()
    -- Handle resource restart
    AddEventHandler('onResourceStop', function(resourceName)
        if GetCurrentResourceName() == resourceName then
            self:CleanupInteractions()
        end
    end)
end

-- Create a new interaction
function InteractionCore:CreateInteraction(data)
    local interactionId = data.id or self:GenerateId()
    
    local interaction = {
        id = interactionId,
        coords = data.coords or vector3(0, 0, 0),
        distance = data.distance or self.Config.maxInteractionDistance,
        type = data.type or self.Types.SIMPLE,
        helpText = data.helpText or 'Press ~INPUT_CONTEXT~ to interact',
        callback = data.callback,
        conditions = data.conditions or {},
        cooldown = data.cooldown or self.Config.cooldownTime,
        animation = data.animation,
        progressBar = data.progressBar,
        menu = data.menu,
        data = data.data or {},
        active = true,
        lastUsed = 0,
        -- Conditional options
        job = data.job,
        gang = data.gang,
        item = data.item,
        -- Visual options
        blip = data.blip,
        marker = data.marker,
        -- Permissions
        permissions = data.permissions or {}
    }
    
    self.interactions[interactionId] = interaction
    
    -- Create blip if specified
    if interaction.blip then
        self:CreateInteractionBlip(interaction)
    end
    
    -- Create marker if specified
    if interaction.marker then
        self:CreateInteractionMarker(interaction)
    end
    
    if self.Config.debugMode then
        print(string.format('[INTERACTION-CORE] Created interaction: %s', interactionId))
    end
    
    return interactionId
end

-- Remove an interaction
function InteractionCore:RemoveInteraction(interactionId)
    local interaction = self.interactions[interactionId]
    
    if interaction then
        -- Remove blip
        if interaction.blipHandle then
            RemoveBlip(interaction.blipHandle)
        end
        
        -- Remove from active interactions
        self.activeInteractions[interactionId] = nil
        
        -- Remove from main interactions table
        self.interactions[interactionId] = nil
        
        if self.Config.debugMode then
            print(string.format('[INTERACTION-CORE] Removed interaction: %s', interactionId))
        end
        
        return true
    end
    
    return false
end

-- Process interaction when key is pressed
function InteractionCore:ProcessInteraction()
    local playerPed = PlayerPedId()
    
    -- Find closest active interaction
    local closestInteraction = self:GetClosestActiveInteraction()
    
    if not closestInteraction then
        return
    end
    
    -- Check cooldown
    if GetGameTimer() - closestInteraction.lastUsed < closestInteraction.cooldown then
        if self.Config.debugMode then
            print('[INTERACTION-CORE] Interaction on cooldown')
        end
        return
    end
    
    -- Validate interaction conditions
    if not self:ValidateConditions(closestInteraction, playerPed) then
        return
    end
    
    -- Update last used time
    closestInteraction.lastUsed = GetGameTimer()
    
    -- Process interaction based on type
    self:HandleInteractionType(closestInteraction, playerPed)
end

-- Handle different interaction types
function InteractionCore:HandleInteractionType(interaction, playerPed)
    local interactionType = interaction.type
    
    if interactionType == self.Types.SIMPLE then
        self:HandleSimpleInteraction(interaction)
        
    elseif interactionType == self.Types.ANIMATED then
        self:HandleAnimatedInteraction(interaction, playerPed)
        
    elseif interactionType == self.Types.PROGRESSIVE then
        self:HandleProgressiveInteraction(interaction, playerPed)
        
    elseif interactionType == self.Types.MENU then
        self:HandleMenuInteraction(interaction)
        
    elseif interactionType == self.Types.CONDITIONAL then
        self:HandleConditionalInteraction(interaction)
        
    elseif interactionType == self.Types.TIMED then
        self:HandleTimedInteraction(interaction, playerPed)
    end
end

-- Handle simple interaction
function InteractionCore:HandleSimpleInteraction(interaction)
    if interaction.callback and type(interaction.callback) == 'function' then
        interaction.callback(interaction.data)
    end
end

-- Handle animated interaction
function InteractionCore:HandleAnimatedInteraction(interaction, playerPed)
    if interaction.animation then
        local animDict = interaction.animation.dict
        local animName = interaction.animation.name
        local duration = interaction.animation.duration or self.Config.animationDuration
        
        -- Load animation
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(100)
        end
        
        -- Play animation
        TaskPlayAnim(playerPed, animDict, animName, 8.0, 8.0, duration, 0, 0, false, false, false)
        
        -- Wait for animation to finish
        Wait(duration)
        
        -- Clear animation
        ClearPedTasks(playerPed)
        RemoveAnimDict(animDict)
    end
    
    -- Execute callback
    if interaction.callback and type(interaction.callback) == 'function' then
        interaction.callback(interaction.data)
    end
end

-- Handle progressive interaction (progress bar)
function InteractionCore:HandleProgressiveInteraction(interaction, playerPed)
    if interaction.progressBar then
        local progressData = {
            duration = interaction.progressBar.duration or 5000,
            label = interaction.progressBar.label or 'Processing...',
            canCancel = interaction.progressBar.canCancel or true,
            animation = interaction.progressBar.animation,
            prop = interaction.progressBar.prop,
            disableMovement = interaction.progressBar.disableMovement or true,
            disableCarMovement = interaction.progressBar.disableCarMovement or true,
            disableMouse = interaction.progressBar.disableMouse or false,
            disableCombat = interaction.progressBar.disableCombat or true
        }
        
        -- Start progress bar (using your preferred progress bar system)
        -- This is a placeholder - replace with your actual progress bar implementation
        self:ShowProgressBar(progressData, function(success)
            if success and interaction.callback and type(interaction.callback) == 'function' then
                interaction.callback(interaction.data)
            end
        end)
    end
end

-- Handle menu interaction
function InteractionCore:HandleMenuInteraction(interaction)
    if interaction.menu then
        -- Open menu (using your preferred menu system)
        -- This is a placeholder - replace with your actual menu implementation
        self:OpenMenu(interaction.menu, interaction.data)
    end
    
    if interaction.callback and type(interaction.callback) == 'function' then
        interaction.callback(interaction.data)
    end
end

-- Handle conditional interaction
function InteractionCore:HandleConditionalInteraction(interaction)
    -- Additional condition checks can be added here
    if interaction.callback and type(interaction.callback) == 'function' then
        interaction.callback(interaction.data)
    end
end

-- Handle timed interaction
function InteractionCore:HandleTimedInteraction(interaction, playerPed)
    local timerDuration = interaction.timer or 10000 -- Default 10 seconds
    local startTime = GetGameTimer()
    
    Citizen.CreateThread(function()
        while GetGameTimer() - startTime < timerDuration do
            -- Check if player moved away
            local currentCoords = GetEntityCoords(playerPed)
            if #(currentCoords - interaction.coords) > interaction.distance then
                if self.Config.debugMode then
                    print('[INTERACTION-CORE] Timed interaction cancelled - player moved away')
                end
                return
            end
            
            Wait(100)
        end
        
        -- Timer completed
        if interaction.callback and type(interaction.callback) == 'function' then
            interaction.callback(interaction.data)
        end
    end)
end

-- Validate interaction conditions
function InteractionCore:ValidateConditions(interaction, playerPed)
    -- Job requirement
    if interaction.job then
        local PlayerData = QBCore.Functions.GetPlayerData()
        if PlayerData.job.name ~= interaction.job then
            return false
        end
    end
    
    -- Gang requirement
    if interaction.gang then
        local PlayerData = QBCore.Functions.GetPlayerData()
        if PlayerData.gang.name ~= interaction.gang then
            return false
        end
    end
    
    -- Item requirement
    if interaction.item then
        -- Check if player has required item
        -- This needs to be implemented based on your inventory system
        if not self:PlayerHasItem(interaction.item) then
            return false
        end
    end
    
    -- Custom conditions
    if interaction.conditions and type(interaction.conditions) == 'table' then
        for _, condition in pairs(interaction.conditions) do
            if type(condition) == 'function' and not condition() then
                return false
            end
        end
    end
    
    return true
end

-- Check if interaction is valid
function InteractionCore:IsInteractionValid(interaction, playerPed, playerCoords)
    if not interaction.active then
        return false
    end
    
    -- Basic validation
    if not interaction.coords or not interaction.callback then
        return false
    end
    
    return true
end

-- Get closest active interaction
function InteractionCore:GetClosestActiveInteraction()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local closestInteraction = nil
    local closestDistance = math.huge
    
    for id, interaction in pairs(self.activeInteractions) do
        local distance = #(playerCoords - interaction.coords)
        if distance < closestDistance then
            closestDistance = distance
            closestInteraction = interaction
        end
    end
    
    return closestInteraction
end

-- Show help text
function InteractionCore:ShowHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Create interaction blip
function InteractionCore:CreateInteractionBlip(interaction)
    if interaction.blip then
        local blip = AddBlipForCoord(interaction.coords.x, interaction.coords.y, interaction.coords.z)
        SetBlipSprite(blip, interaction.blip.sprite or 1)
        SetBlipDisplay(blip, interaction.blip.display or 4)
        SetBlipScale(blip, interaction.blip.scale or 0.8)
        SetBlipColour(blip, interaction.blip.color or 1)
        SetBlipAsShortRange(blip, interaction.blip.shortRange or true)
        
        if interaction.blip.name then
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(interaction.blip.name)
            EndTextCommandSetBlipName(blip)
        end
        
        interaction.blipHandle = blip
    end
end

-- Create interaction marker
function InteractionCore:CreateInteractionMarker(interaction)
    if interaction.marker then
        Citizen.CreateThread(function()
            while self.interactions[interaction.id] do
                local playerCoords = GetEntityCoords(PlayerPedId())
                local distance = #(playerCoords - interaction.coords)
                
                if distance <= interaction.marker.drawDistance or 50.0 then
                    DrawMarker(
                        interaction.marker.type or 1,
                        interaction.coords.x, interaction.coords.y, interaction.coords.z - 1.0,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        interaction.marker.size.x or 1.0,
                        interaction.marker.size.y or 1.0,
                        interaction.marker.size.z or 1.0,
                        interaction.marker.color.r or 255,
                        interaction.marker.color.g or 0,
                        interaction.marker.color.b or 0,
                        interaction.marker.alpha or 100,
                        false, true, 2, false, nil, nil, false
                    )
                end
                
                Wait(0)
            end
        end)
    end
end

-- Utility functions
function InteractionCore:GenerateId()
    return 'interaction_' .. math.random(100000, 999999)
end

function InteractionCore:PlayerHasItem(itemName)
    -- Implement based on your inventory system
    -- This is a placeholder
    return true
end

function InteractionCore:ShowProgressBar(data, callback)
    -- Implement your progress bar system here
    -- This is a placeholder
    if callback then
        callback(true)
    end
end

function InteractionCore:OpenMenu(menuData, interactionData)
    -- Implement your menu system here
    -- This is a placeholder
end

function InteractionCore:CleanupInteractions()
    for id, interaction in pairs(self.interactions) do
        if interaction.blipHandle then
            RemoveBlip(interaction.blipHandle)
        end
    end
    
    self.interactions = {}
    self.activeInteractions = {}
end

-- Export the InteractionCore object
_G.InteractionCore = InteractionCore

-- Auto-initialize
Citizen.CreateThread(function()
    InteractionCore:Initialize()
end)