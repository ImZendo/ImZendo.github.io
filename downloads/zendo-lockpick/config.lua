Config = {}

-- General Settings
Config.Debug = false -- Enable debug messages
Config.UseSound = true -- Enable sound effects
Config.UseAnimations = true -- Enable lockpicking animations
Config.ShowProgress = true -- Show progress notifications during minigame

-- Lockpicking Settings
Config.LockpickSettings = {
    difficulty = 'medium', -- easy, medium, hard
    timeLimit = 30000, -- Time limit in milliseconds (30 seconds)
    maxAttempts = 3, -- Maximum attempts before lockpick breaks
    successChance = 0.75, -- Base success chance (75%)
    breakChance = 0.15, -- Chance lockpick breaks on failure (15%)
    experienceGain = 1, -- Experience points gained on success
    cooldownTime = 5000 -- Cooldown between attempts in milliseconds
}

-- ========================================
-- ITEM SYSTEM CONFIGURATION
-- ========================================
-- Choose how players get lockpicks:
-- • Option 1: Use built-in system (script creates items automatically)
-- • Option 2: Use your existing inventory items (ESX/QB items you already have)

Config.RequiredItem = {
    enabled = true, -- Require lockpick item to use (set false to allow free lockpicking)
    
    -- CHOOSE YOUR ITEM SYSTEM:
    useBuiltInItem = false, -- true = Use built-in lockpick | false = Use your custom item
    
    -- Built-in Item Settings (only used if useBuiltInItem = true)
    builtInItem = {
        name = 'zendo_lockpick',
        label = 'Vehicle Lockpick',
        description = 'A specialized tool for picking vehicle locks',
        weight = 100, -- Item weight (varies by inventory system)
        rare = false, -- Is this a rare item?
        canDrop = true, -- Can players drop this item?
        canUse = true -- Can players use this item directly?
    },
    
    -- Custom Item Settings (use your own existing item)
    customItem = {
        itemName = 'lockpick', -- Name of your existing lockpick item
        removeOnUse = false, -- Remove item every time it's used
        removeOnBreak = true, -- Remove item when lockpick attempt fails/breaks
        durabilityEnabled = false, -- Does your item system use durability?
        durabilityLoss = 10 -- How much durability to remove per use (if enabled)
    },
    
    -- Item Usage Settings (applies to both built-in and custom items)
    requiresSkill = false, -- Require player skill/level to use
    skillLevel = 1, -- Minimum skill level required
    consumeChance = 0.15 -- Chance item gets consumed on failure (0.0 to 1.0)
}

-- Vehicle Settings
Config.VehicleSettings = {
    lockpickRange = 2.5, -- Range to interact with vehicle
    allowedVehicleClasses = { -- Which vehicle classes can be lockpicked
        0,  -- Compacts
        1,  -- Sedans
        2,  -- SUVs
        3,  -- Coupes
        4,  -- Muscle
        5,  -- Sports Classics
        6,  -- Sports
        7,  -- Super
        9,  -- Off-road
        10, -- Industrial
        11, -- Utility
        12  -- Vans
    },
    blacklistedModels = { -- Vehicle models that cannot be lockpicked
        'police',
        'police2',
        'police3',
        'ambulance',
        'firetruk'
    },
    emergencyVehicles = false, -- Allow lockpicking emergency vehicles
    playerVehicles = false -- Allow lockpicking player-owned vehicles
}

-- Minigame Settings
Config.Minigame = {
    type = 'circle', -- circle, skillcheck, or custom
    pins = 5, -- Number of pins for circle minigame
    speed = 1.0, -- Speed multiplier for minigame
    zones = {
        easy = { size = 50, speed = 0.8 },
        medium = { size = 30, speed = 1.0 },
        hard = { size = 20, speed = 1.2 }
    }
}

-- Animation Settings
Config.Animations = {
    lockpicking = {
        dict = 'mini@safe_cracking',
        anim = 'dial_turn_clock_normal',
        flags = 1
    },
    duration = 3000 -- Animation duration in milliseconds
}

-- Sound Settings
Config.Sounds = {
    lockpicking = 'lockpick_sound',
    success = 'unlock_sound',
    failure = 'lockpick_break',
    volume = 0.3
}

-- Notification Settings
Config.Notifications = {
    success = {
        type = 'success',
        title = 'Lockpicking',
        message = 'Vehicle unlocked successfully!'
    },
    failure = {
        type = 'error',
        title = 'Lockpicking',
        message = 'Failed to pick the lock!'
    },
    noItem = {
        type = 'error',
        title = 'Lockpicking',
        message = 'You need a lockpick!'
    },
    vehicleNotFound = {
        type = 'error',
        title = 'Lockpicking',
        message = 'No vehicle found nearby!'
    },
    alreadyUnlocked = {
        type = 'info',
        title = 'Lockpicking',
        message = 'Vehicle is already unlocked!'
    },
    onCooldown = {
        type = 'warning',
        title = 'Lockpicking',
        message = 'You need to wait before trying again!'
    }
}

-- Framework Integration
Config.Framework = {
    name = 'auto', -- auto, esx, qb-core, custom
    inventorySystem = 'auto', -- auto, esx, qb-inventory, ox_inventory
    notificationSystem = 'auto' -- auto, esx, qb-core, ox_lib, custom
}

-- Logging Settings
Config.Logging = {
    enabled = true,
    webhook = '', -- Discord webhook URL for logging
    logSuccessfulAttempts = true,
    logFailedAttempts = false,
    logItemUsage = true
}