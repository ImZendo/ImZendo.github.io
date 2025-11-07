-- Lockpick Job System - Client Side
-- Free download from Anthony Benitez Portfolio
-- A complete lockpicking job system with skill progression and rewards

local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local isDoingLockpickJob = false
local currentJobData = {}
local lockpickSkill = 0
local activeTargets = {}

-- Configuration
local Config = {
    JobName = "lockpick_job",
    MinSkillLevel = 0,
    MaxSkillLevel = 100,
    BaseReward = 150,
    SkillIncrement = 2,
    CooldownTime = 300, -- 5 minutes
    Locations = {
        {coords = vector3(123.45, -678.90, 30.12), heading = 180.0, difficulty = 1},
        {coords = vector3(234.56, -789.01, 25.34), heading = 90.0, difficulty = 2},
        {coords = vector3(345.67, -890.12, 35.56), heading = 270.0, difficulty = 3},
        {coords = vector3(456.78, -901.23, 28.78), heading = 0.0, difficulty = 4},
    }
}

-- Initialize player data
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    TriggerServerEvent('lockpick-job:server:loadPlayerData')
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

-- Lockpick job start handler
RegisterNetEvent('lockpick-job:client:startJob', function()
    if isDoingLockpickJob then
        QBCore.Functions.Notify('You are already doing a lockpick job!', 'error')
        return
    end
    
    if PlayerData.job.name ~= Config.JobName then
        QBCore.Functions.Notify('You need to be employed as a locksmith to do this job!', 'error')
        return
    end
    
    StartLockpickJob()
end)

-- Start lockpick job function
function StartLockpickJob()
    local randomLocation = Config.Locations[math.random(1, #Config.Locations)]
    
    currentJobData = {
        location = randomLocation,
        startTime = GetGameTimer(),
        completed = false
    }
    
    isDoingLockpickJob = true
    
    -- Create job blip
    CreateJobBlip(randomLocation.coords)
    
    QBCore.Functions.Notify('New lockpick job available! Check your GPS.', 'success')
    TriggerServerEvent('lockpick-job:server:jobStarted', currentJobData)
end

-- Create job blip
function CreateJobBlip(coords)
    if currentJobData.blip then
        RemoveBlip(currentJobData.blip)
    end
    
    currentJobData.blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(currentJobData.blip, 351)
    SetBlipDisplay(currentJobData.blip, 4)
    SetBlipScale(currentJobData.blip, 0.8)
    SetBlipColour(currentJobData.blip, 5)
    SetBlipAsShortRange(currentJobData.blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Lockpick Job")
    EndTextCommandSetBlipName(currentJobData.blip)
    
    SetBlipRoute(currentJobData.blip, true)
    SetBlipRouteColour(currentJobData.blip, 5)
end

-- Lockpicking minigame function
function StartLockpickingMinigame(difficulty)
    local success = false
    local attempts = 3
    
    while attempts > 0 and not success do
        -- Simulate lockpicking minigame
        QBCore.Functions.Notify(string.format('Lockpicking... Attempt %d/3', 4 - attempts), 'primary')
        
        -- Use your preferred minigame system here
        -- This is a simplified version using random chance based on skill
        local skillChance = math.min((lockpickSkill / Config.MaxSkillLevel) * 100, 85) -- Max 85% success rate
        local difficultyModifier = (1 - (difficulty * 0.15)) -- Reduce success rate by difficulty
        local finalChance = skillChance * difficultyModifier
        
        Wait(3000) -- Simulate minigame time
        
        local randomRoll = math.random(1, 100)
        
        if randomRoll <= finalChance then
            success = true
            QBCore.Functions.Notify('Lock picked successfully!', 'success')
        else
            attempts = attempts - 1
            if attempts > 0 then
                QBCore.Functions.Notify('Failed! Try again.', 'error')
            else
                QBCore.Functions.Notify('Lock picking failed completely!', 'error')
            end
        end
    end
    
    return success
end

-- Complete lockpick job
function CompleteLockpickJob(success)
    if not isDoingLockpickJob then return end
    
    local reward = 0
    local skillGain = 0
    
    if success then
        local difficulty = currentJobData.location.difficulty
        reward = Config.BaseReward * difficulty * (1 + (lockpickSkill / Config.MaxSkillLevel))
        skillGain = Config.SkillIncrement * difficulty
        
        -- Increase skill
        lockpickSkill = math.min(lockpickSkill + skillGain, Config.MaxSkillLevel)
        
        QBCore.Functions.Notify(string.format('Job completed! Earned $%d and %d skill XP', 
                               math.floor(reward), skillGain), 'success')
    else
        QBCore.Functions.Notify('Job failed! No reward earned.', 'error')
    end
    
    -- Clean up
    if currentJobData.blip then
        RemoveBlip(currentJobData.blip)
    end
    
    isDoingLockpickJob = false
    currentJobData = {}
    
    -- Send completion data to server
    TriggerServerEvent('lockpick-job:server:jobCompleted', {
        success = success,
        reward = reward,
        skillGain = skillGain,
        newSkillLevel = lockpickSkill
    })
end

-- Create interaction targets for job locations
Citizen.CreateThread(function()
    for i, location in pairs(Config.Locations) do
        exports['qb-target']:AddBoxZone("lockpick_job_" .. i, location.coords, 2.0, 2.0, {
            name = "lockpick_job_" .. i,
            heading = location.heading,
            debugPoly = false,
            minZ = location.coords.z - 1,
            maxZ = location.coords.z + 3,
        }, {
            options = {
                {
                    type = "client",
                    event = "lockpick-job:client:startLockpicking",
                    icon = "fas fa-key",
                    label = "Start Lockpicking",
                    job = Config.JobName,
                    locationIndex = i
                },
            },
            distance = 2.5
        })
    end
end)

-- Handle lockpicking interaction
RegisterNetEvent('lockpick-job:client:startLockpicking', function(data)
    if not isDoingLockpickJob then
        QBCore.Functions.Notify('You need to have an active lockpick job!', 'error')
        return
    end
    
    local locationIndex = data.locationIndex
    local targetLocation = Config.Locations[locationIndex]
    
    if targetLocation ~= currentJobData.location then
        QBCore.Functions.Notify('This is not your target location!', 'error')
        return
    end
    
    -- Check if player has lockpicks
    QBCore.Functions.TriggerCallback('lockpick-job:server:hasLockpicks', function(hasLockpicks)
        if hasLockpicks then
            local success = StartLockpickingMinigame(targetLocation.difficulty)
            CompleteLockpickJob(success)
            
            if success then
                -- Remove lockpick with chance to break
                local breakChance = 20 - (lockpickSkill / 5) -- Lower chance as skill increases
                if math.random(1, 100) <= breakChance then
                    TriggerServerEvent('lockpick-job:server:removeLockpick')
                    QBCore.Functions.Notify('Your lockpick broke!', 'error')
                end
            else
                -- Always remove lockpick on failure
                TriggerServerEvent('lockpick-job:server:removeLockpick')
            end
        else
            QBCore.Functions.Notify('You need lockpicks to do this job!', 'error')
        end
    end)
end)

-- Receive skill level from server
RegisterNetEvent('lockpick-job:client:updateSkill', function(newSkillLevel)
    lockpickSkill = newSkillLevel
end)

-- Command to check skill level
RegisterCommand('lockpickskill', function()
    QBCore.Functions.Notify(string.format('Lockpick Skill: %d/%d', lockpickSkill, Config.MaxSkillLevel), 'primary')
end)

-- Export functions for other resources
exports('GetLockpickSkill', function()
    return lockpickSkill
end)

exports('IsDoingLockpickJob', function()
    return isDoingLockpickJob
end)