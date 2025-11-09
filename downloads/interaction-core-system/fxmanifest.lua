fx_version 'cerulean'
game 'gta5'

name 'interaction_core'
description 'Leak-free interaction system for FiveM - standalone, crash-safe, memory optimized'
author 'InteractionCore Team'
version '2.0.0-leakfree'

-- Load order is critical for leak-free operation
shared_scripts {
    'shared/config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

-- Minimal exports to prevent memory issues
exports {
    'RegisterInteraction',
    'RemoveInteraction', 
    'GetInteraction',
    'IsPlayerInInteraction',
    'GetCurrentInteraction',
    'CancelCurrentInteraction'
}

server_exports {
    'RegisterInteraction',
    'RemoveInteraction',
    'GetInteraction',
    'IsPlayerInInteraction',
    'GetPlayerInteraction',
    'CancelPlayerInteraction'
}

-- Lua 5.4 compatibility
lua54 'yes'