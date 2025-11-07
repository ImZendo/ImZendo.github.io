-- Lockpick Job System - Server Side
-- Free download from Anthony Benitez Portfolio
-- Server-side logic for the lockpicking job system

local QBCore = exports['qb-core']:GetCoreObject()
local playerSkillData = {}

-- Configuration
local Config = {
    JobName = "lockpick_job",
    RequiredItem = "lockpick",
    MaxSkillLevel = 100,
    DatabaseTable = "player_lockpick_skills"
}

-- Initialize database table (run once)
local function InitializeDatabase()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS player_lockpick_skills (
            citizenid VARCHAR(50) PRIMARY KEY,
            skill_level INT DEFAULT 0,
            jobs_completed INT DEFAULT 0,
            last_job_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
end

-- Load player skill data from database
local function LoadPlayerSkillData(citizenid)
    MySQL.Async.fetchAll('SELECT * FROM player_lockpick_skills WHERE citizenid = ?', {citizenid}, function(result)
        if result[1] then
            playerSkillData[citizenid] = {
                skillLevel = result[1].skill_level or 0,
                jobsCompleted = result[1].jobs_completed or 0,
                lastJobTime = result[1].last_job_time
            }
        else
            -- Create new record for player
            MySQL.Async.execute('INSERT INTO player_lockpick_skills (citizenid) VALUES (?)', {citizenid})
            playerSkillData[citizenid] = {
                skillLevel = 0,
                jobsCompleted = 0,
                lastJobTime = nil
            }
        end
        
        -- Send skill level to client
        local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        if Player then
            TriggerClientEvent('lockpick-job:client:updateSkill', Player.PlayerData.source, 
                             playerSkillData[citizenid].skillLevel)
        end
    end)
end

-- Save player skill data to database
local function SavePlayerSkillData(citizenid)
    if not playerSkillData[citizenid] then return end
    
    MySQL.Async.execute([[
        UPDATE player_lockpick_skills 
        SET skill_level = ?, jobs_completed = ?, last_job_time = NOW() 
        WHERE citizenid = ?
    ]], {
        playerSkillData[citizenid].skillLevel,
        playerSkillData[citizenid].jobsCompleted,
        citizenid
    })
end

-- Player loaded event
RegisterNetEvent('lockpick-job:server:loadPlayerData', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        LoadPlayerSkillData(Player.PlayerData.citizenid)
    end
end)

-- Job started event
RegisterNetEvent('lockpick-job:server:jobStarted', function(jobData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Log job start
    print(string.format('[LOCKPICK-JOB] Player %s (%s) started lockpick job', 
          Player.PlayerData.name, Player.PlayerData.citizenid))
end)

-- Job completion event
RegisterNetEvent('lockpick-job:server:jobCompleted', function(completionData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Initialize player data if not exists
    if not playerSkillData[citizenid] then
        playerSkillData[citizenid] = {skillLevel = 0, jobsCompleted = 0, lastJobTime = nil}
    end
    
    if completionData.success then
        -- Update player skill and job count
        playerSkillData[citizenid].skillLevel = completionData.newSkillLevel
        playerSkillData[citizenid].jobsCompleted = playerSkillData[citizenid].jobsCompleted + 1
        
        -- Give money reward
        Player.Functions.AddMoney('cash', completionData.reward, 'lockpick-job-reward')
        
        -- Save to database
        SavePlayerSkillData(citizenid)
        
        -- Send updated skill to client
        TriggerClientEvent('lockpick-job:client:updateSkill', src, completionData.newSkillLevel)
        
        -- Log successful completion
        print(string.format('[LOCKPICK-JOB] Player %s completed job: $%d reward, skill: %d', 
              Player.PlayerData.name, completionData.reward, completionData.newSkillLevel))
    else
        -- Log failed job
        print(string.format('[LOCKPICK-JOB] Player %s failed lockpick job', Player.PlayerData.name))
    end
end)

-- Check if player has lockpicks callback
QBCore.Functions.CreateCallback('lockpick-job:server:hasLockpicks', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        cb(false)
        return
    end
    
    local lockpicks = Player.Functions.GetItemByName(Config.RequiredItem)
    cb(lockpicks and lockpicks.amount > 0)
end)

-- Remove lockpick item
RegisterNetEvent('lockpick-job:server:removeLockpick', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        Player.Functions.RemoveItem(Config.RequiredItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.RequiredItem], "remove")
    end
end)

-- Get player skill data callback
QBCore.Functions.CreateCallback('lockpick-job:server:getSkillData', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        cb({skillLevel = 0, jobsCompleted = 0})
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    if playerSkillData[citizenid] then
        cb(playerSkillData[citizenid])
    else
        LoadPlayerSkillData(citizenid)
        cb({skillLevel = 0, jobsCompleted = 0})
    end
end)

-- Admin command to set player skill
QBCore.Commands.Add('setlockpickskill', 'Set a player\'s lockpick skill level (Admin Only)', {
    {name = 'id', help = 'Player ID'},
    {name = 'skill', help = 'Skill Level (0-100)'}
}, true, function(source, args)
    local targetId = tonumber(args[1])
    local skillLevel = tonumber(args[2])
    
    if not targetId or not skillLevel then
        TriggerClientEvent('QBCore:Notify', source, 'Invalid arguments!', 'error')
        return
    end
    
    if skillLevel < 0 or skillLevel > Config.MaxSkillLevel then
        TriggerClientEvent('QBCore:Notify', source, 
                          'Skill level must be between 0 and ' .. Config.MaxSkillLevel, 'error')
        return
    end
    
    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        TriggerClientEvent('QBCore:Notify', source, 'Player not found!', 'error')
        return
    end
    
    local citizenid = TargetPlayer.PlayerData.citizenid
    
    -- Initialize if needed
    if not playerSkillData[citizenid] then
        playerSkillData[citizenid] = {skillLevel = 0, jobsCompleted = 0, lastJobTime = nil}
    end
    
    -- Update skill
    playerSkillData[citizenid].skillLevel = skillLevel
    SavePlayerSkillData(citizenid)
    
    -- Update client
    TriggerClientEvent('lockpick-job:client:updateSkill', targetId, skillLevel)
    
    -- Notify both players
    TriggerClientEvent('QBCore:Notify', source, 
                      string.format('Set %s\'s lockpick skill to %d', 
                                   TargetPlayer.PlayerData.name, skillLevel), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 
                      string.format('Your lockpick skill has been set to %d', skillLevel), 'info')
end, 'admin')

-- Admin command to view player skill stats
QBCore.Commands.Add('lockpickstats', 'View a player\'s lockpick statistics (Admin Only)', {
    {name = 'id', help = 'Player ID'}
}, true, function(source, args)
    local targetId = tonumber(args[1])
    
    if not targetId then
        TriggerClientEvent('QBCore:Notify', source, 'Invalid player ID!', 'error')
        return
    end
    
    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        TriggerClientEvent('QBCore:Notify', source, 'Player not found!', 'error')
        return
    end
    
    local citizenid = TargetPlayer.PlayerData.citizenid
    
    QBCore.Functions.CreateCallback('lockpick-job:server:getSkillData', function(skillData)
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 255, 0},
            multiline = true,
            args = {"Lockpick Stats", 
                   string.format("Player: %s | Skill: %d/%d | Jobs Completed: %d", 
                                TargetPlayer.PlayerData.name, 
                                skillData.skillLevel, 
                                Config.MaxSkillLevel, 
                                skillData.jobsCompleted)}
        })
    end)(source)
end, 'admin')

-- Player disconnect cleanup
RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and playerSkillData[Player.PlayerData.citizenid] then
        SavePlayerSkillData(Player.PlayerData.citizenid)
    end
end)

-- Server startup
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        InitializeDatabase()
        print('[LOCKPICK-JOB] Server started successfully!')
    end
end)

-- Export functions
exports('GetPlayerSkillLevel', function(citizenid)
    return playerSkillData[citizenid] and playerSkillData[citizenid].skillLevel or 0
end)

exports('SetPlayerSkillLevel', function(citizenid, skillLevel)
    if not playerSkillData[citizenid] then
        playerSkillData[citizenid] = {skillLevel = 0, jobsCompleted = 0, lastJobTime = nil}
    end
    
    playerSkillData[citizenid].skillLevel = math.max(0, math.min(skillLevel, Config.MaxSkillLevel))
    SavePlayerSkillData(citizenid)
    return true
end)