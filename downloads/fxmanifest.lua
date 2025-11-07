fx_version 'cerulean'
game 'gta5'

author 'Anthony Benitez'
description 'Complete Lockpick Job System with Skill Progression'
version '1.0.0'

-- Client Scripts
client_scripts {
    'client/lockpick-job-client.lua'
}

-- Server Scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/lockpick-job-server.lua'
}

-- Dependencies
dependencies {
    'qb-core',
    'qb-target',
    'oxmysql'
}

-- Lua 5.4
lua54 'yes'