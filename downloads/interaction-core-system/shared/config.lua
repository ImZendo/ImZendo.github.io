-- =====================================================
-- INTERACTION CORE - CLEAN CONFIGURATION
-- =====================================================

InteractionCoreConfig = {
    -- System settings
    Debug = false, -- Disable debug to prevent spam
    MaxInteractions = 100, -- Prevent memory bloat
    CleanupInterval = 60000, -- Cleanup every 60 seconds
    
    -- Interaction settings
    DefaultRange = 2.0,
    DefaultKey = 38, -- E key
    ShowPrompts = true,
    
    -- UI Settings
    UI = {
        Style = "modern", -- "simple" or "modern"
        ShowPrompts = true,
        ShowProgress = true,
        ShowNotifications = true,
        
        -- Colors (RGBA)
        Colors = {
            primary = {r = 59, g = 130, b = 246, a = 255}, -- Blue
            success = {r = 34, g = 197, b = 94, a = 255},  -- Green
            warning = {r = 251, g = 191, b = 36, a = 255}, -- Yellow
            danger = {r = 239, g = 68, b = 68, a = 255},   -- Red
            background = {r = 0, g = 0, b = 0, a = 180},   -- Dark transparent
            text = {r = 255, g = 255, b = 255, a = 255}    -- White
        },
        
        -- Positions (screen coordinates 0.0-1.0)
        Positions = {
            prompt = {x = 0.5, y = 0.85},        -- Bottom center
            progress = {x = 0.5, y = 0.75},      -- Above prompt
            notification = {x = 0.5, y = 0.15}   -- Top center
        },
        
        -- Sizes
        Sizes = {
            promptWidth = 0.25,
            promptHeight = 0.045,
            progressWidth = 0.20,
            progressHeight = 0.015,
            notificationWidth = 0.30,
            notificationHeight = 0.04
        }
    },
    
    -- Performance settings
    ClientUpdateRate = 250, -- Milliseconds between client updates
    MaxNearbyChecks = 10, -- Maximum interactions to check per frame
    
    -- Interaction types (simplified)
    Types = {
        VEHICLE = 1,
        OBJECT = 2,
        PED = 3,
        WORLD = 4,
        CUSTOM = 5
    },
    
    -- Default prompts
    Prompts = {
        default = 'Press ~INPUT_CONTEXT~ to interact',
        lockpick = 'Press ~INPUT_CONTEXT~ to lockpick'
    },
    
    -- Validation types
    ValidationTypes = {
        DISTANCE = 1,
        ITEM = 2,
        JOB = 3,
        MONEY = 4,
        CUSTOM = 5
    }
}