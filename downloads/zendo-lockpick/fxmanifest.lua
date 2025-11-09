fx_version 'cerulean'
game 'gta5'

name 'Zendo Lockpick'
description 'Advanced lockpicking system with interactive minigame'
author 'Zendo'
version '1.0.0'

-- Dependencies
dependency 'interaction_core' -- Required for interaction system

-- Shared scripts
shared_scripts {
    'config.lua'
}

-- Client scripts
client_scripts {
    'client.lua'
}

-- Server scripts
server_scripts {
    'server.lua'
}

-- UI Files
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css', 
    'html/script.js',
    'html/sounds/*.ogg'
}

-- Lua 5.4
lua54 'yes'