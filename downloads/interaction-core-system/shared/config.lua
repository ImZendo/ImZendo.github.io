-- =====================================================
-- INTERACTION CORE - CLEAN CONFIGURATION
-- =====================================================

InteractionCoreConfig = {
    -- System settings
    Debug = false,
    MaxInteractions = 100, -- Prevent memory bloat
    CleanupInterval = 60000, -- Cleanup every 60 seconds
    
    -- Interaction settings
    DefaultRange = 2.0,
    DefaultKey = 38, -- E key
    ShowPrompts = true,
    
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
    }
}