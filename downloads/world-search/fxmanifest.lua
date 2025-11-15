fx_version 'cerulean'
game 'gta5'

name 'world-search'
description 'Modular search system for interaction_core - find loot, clues, and items'
author 'ImZendo'
version '1.0.0'

-- Dependencies 
dependencies {
    'interaction_core'
}

-- Load order is important  
shared_scripts {
    '@interaction_core/shared/config.lua', -- Load InteractionCore config first
    'shared/config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/object_status_ui_minimal.lua',  -- Load minimal UI first for testing
    'client/interaction_sync.lua',  -- Load sync helper first
    'client/object_detection.lua',
    'client/main.lua',
    'client/search.lua',
    'client/ui.lua',
    'client/interaction_integration.lua'
}

server_scripts {
    'server/main.lua',
    'server/search.lua',
    'server/loot.lua',
    'test_integration.lua'
}

-- Exports for other resources
exports {
    'AddSearchZone',
    'RemoveSearchZone',
    'AddLootTable',
    'IsPlayerSearching',
    'GetSearchZones',
    'GetCurrentZone',
    'ShouldShowPrompt',
    'GetSearchProgress',
    'GetCurrentObject',
    'GetNearbyObjects',
    'GetDetectedObject'
}

server_exports {
    'AddSearchZone',
    'RemoveSearchZone', 
    'AddLootTable',
    'GetPlayerSearchData',
    'ResetSearchCooldown',
    'AddCustomLootCallback'
}

-- Lua 5.4 compatibility
lua54 'yes'