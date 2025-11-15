-- =====================================================
-- WORLD SEARCH SYSTEM - CONFIGURATION
-- =====================================================

WorldSearchConfig = {
    -- Debug settings
    Debug = true,
    ShowDebugBoxes = true,         -- Show visual boxes around interaction zones
    BoxDebugColor = {r = 255, g = 0, b = 0, a = 100}, -- Red with transparency
    BoxDebugOutline = {r = 255, g = 255, b = 255, a = 255}, -- White outline
    
    -- Search settings
    DefaultSearchTime = 5000,      -- 5 seconds to complete a search
    SearchCooldown = 30000,        -- 30 seconds between searches at same location
    MaxSearchDistance = 2.5,       -- Maximum distance to search object/location
    
    -- Interaction prompt settings
    PromptThrottleTime = 100,      -- Milliseconds between prompt checks (prevents spam)
    HelpTextInterval = 2000,       -- Show help text every X milliseconds while in area
    NotificationDuration = 3000,   -- How long to show notification when entering area
    
    -- Player restrictions
    MaxActiveSearches = 3,         -- Max concurrent search zones per player
    GlobalCooldown = 5000,         -- 5 seconds between any searches
    
    -- Animation settings
    SearchAnimation = {
        dict = "amb@prop_human_bum_bin@",
        anim = "bin_0",
        flag = 49
    },
    
    -- UI settings
    ProgressBarColor = {r = 255, g = 165, b = 0}, -- Orange
    NotificationTime = 4000,
    
    -- Search types
    SearchTypes = {
        WORLD_OBJECT = 1,    -- Dumpsters, bins, etc.
        LOCATION = 2,        -- Specific coordinates
        NPC_SEARCH = 3,      -- Search NPCs
        VEHICLE_SEARCH = 4,  -- Search vehicles
        CUSTOM = 5           -- Custom search areas
    },
    
    -- Default loot tables
    DefaultLootTables = {
        ["trash_bin"] = {
            {item = "bottle", chance = 15, min = 1, max = 2},
            {item = "burger", chance = 8, min = 1, max = 1},
            {item = "nothing", chance = 77, message = "You found nothing useful..."}
        },
        ["dumpster"] = {
            {item = "scrap_metal", chance = 20, min = 1, max = 3},
            {item = "bottle", chance = 15, min = 1, max = 2},
            {item = "plastic", chance = 12, min = 1, max = 2},
            {item = "nothing", chance = 53, message = "Just trash and bad smells..."}
        },
        ["mailbox"] = {
            {item = "letter", chance = 25, min = 1, max = 1},
            {item = "package", chance = 5, min = 1, max = 1},
            {item = "nothing", chance = 70, message = "The mailbox is empty."}
        },
        ["bench"] = {
            {item = "money", chance = 10, min = 5, max = 25},
            {item = "phone", chance = 2, min = 1, max = 1},
            {item = "nothing", chance = 88, message = "Nothing hidden under the bench."}
        },
        ["npc_pockets"] = {
            {item = "money", chance = 35, min = 10, max = 100},
            {item = "id_card", chance = 15, min = 1, max = 1},
            {item = "phone", chance = 8, min = 1, max = 1},
            {item = "keys", chance = 12, min = 1, max = 1},
            {item = "nothing", chance = 30, message = "Their pockets are empty."}
        }
    },
    
    -- Searchable object definitions (by model name)
    SearchableObjects = {
        -- Dumpsters
        ["prop_dumpster_01a"] = {
            name = "Dumpster",
            lootTable = "dumpster",
            searchRange = 2.0,
            prompt = "Press ~INPUT_CONTEXT~ to search dumpster",
            searchTime = 6000, -- 6 seconds
            animDict = "amb@prop_human_bum_bin@",
            animName = "bin_0"
        },
        ["prop_dumpster_02a"] = {
            name = "Large Dumpster", 
            lootTable = "dumpster",
            searchRange = 2.5,
            prompt = "Press ~INPUT_CONTEXT~ to search dumpster",
            searchTime = 7000,
            animDict = "amb@prop_human_bum_bin@",
            animName = "bin_0"
        },
        ["prop_dumpster_02b"] = {
            name = "Industrial Dumpster",
            lootTable = "dumpster", 
            searchRange = 2.5,
            prompt = "Press ~INPUT_CONTEXT~ to search dumpster",
            searchTime = 7000,
            animDict = "amb@prop_human_bum_bin@",
            animName = "bin_0"
        },
        ["prop_dumpster_3a"] = {
            name = "Blue Dumpster",
            lootTable = "dumpster",
            searchRange = 2.0,
            prompt = "Press ~INPUT_CONTEXT~ to search dumpster", 
            searchTime = 6000,
            animDict = "amb@prop_human_bum_bin@",
            animName = "bin_0"
        },
        ["prop_dumpster_4a"] = {
            name = "Green Dumpster",
            lootTable = "dumpster",
            searchRange = 2.0,
            prompt = "Press ~INPUT_CONTEXT~ to search dumpster",
            searchTime = 6000,
            animDict = "amb@prop_human_bum_bin@", 
            animName = "bin_0"
        },
        ["prop_dumpster_4b"] = {
            name = "Rusty Dumpster",
            lootTable = "dumpster",
            searchRange = 2.0,
            prompt = "Press ~INPUT_CONTEXT~ to search dumpster",
            searchTime = 6000,
            animDict = "amb@prop_human_bum_bin@",
            animName = "bin_0"
        },

        -- Trash bins
        ["prop_bin_01a"] = {
            name = "Trash Bin",
            lootTable = "trash_bin", 
            searchRange = 1.5,
            prompt = "Press ~INPUT_CONTEXT~ to search bin",
            searchTime = 4000,
            animDict = "amb@prop_human_bum_bin@",
            animName = "bin_0"
        },
        ["prop_bin_02a"] = {
            name = "Street Bin",
            lootTable = "trash_bin",
            searchRange = 1.5,
            prompt = "Press ~INPUT_CONTEXT~ to search bin", 
            searchTime = 4000,
            animDict = "amb@prop_human_bum_bin@",
            animName = "bin_0"
        },
        ["prop_bin_03a"] = {
            name = "Park Bin",
            lootTable = "trash_bin",
            searchRange = 1.5,
            prompt = "Press ~INPUT_CONTEXT~ to search bin",
            searchTime = 4000,
            animDict = "amb@prop_human_bum_bin@",
            animName = "bin_0"
        },
        ["prop_bin_04a"] = {
            name = "City Bin",
            lootTable = "trash_bin",
            searchRange = 1.5, 
            prompt = "Press ~INPUT_CONTEXT~ to search bin",
            searchTime = 4000,
            animDict = "amb@prop_human_bum_bin@",
            animName = "bin_0"
        },
        ["prop_bin_05a"] = {
            name = "Metal Bin",
            lootTable = "trash_bin",
            searchRange = 1.5,
            prompt = "Press ~INPUT_CONTEXT~ to search bin",
            searchTime = 4000,
            animDict = "amb@prop_human_bum_bin@",
            animName = "bin_0"
        },

        -- Benches
        ["prop_bench_01a"] = {
            name = "Park Bench",
            lootTable = "bench",
            searchRange = 1.8,
            prompt = "Press ~INPUT_CONTEXT~ to search under bench",
            searchTime = 5000,
            animDict = "amb@world_human_bum_slumped@",
            animName = "base"
        },
        ["prop_bench_01b"] = {
            name = "Wooden Bench", 
            lootTable = "bench",
            searchRange = 1.8,
            prompt = "Press ~INPUT_CONTEXT~ to search under bench",
            searchTime = 5000,
            animDict = "amb@world_human_bum_slumped@",
            animName = "base"
        },
        ["prop_bench_01c"] = {
            name = "Metal Bench",
            lootTable = "bench", 
            searchRange = 1.8,
            prompt = "Press ~INPUT_CONTEXT~ to search under bench",
            searchTime = 5000,
            animDict = "amb@world_human_bum_slumped@",
            animName = "base"
        },
        ["prop_bench_02"] = {
            name = "Bus Stop Bench",
            lootTable = "bench",
            searchRange = 1.8,
            prompt = "Press ~INPUT_CONTEXT~ to search under bench",
            searchTime = 5000,
            animDict = "amb@world_human_bum_slumped@",
            animName = "base" 
        },

        -- Mailboxes
        ["prop_postbox_01a"] = {
            name = "Mailbox",
            lootTable = "mailbox",
            searchRange = 1.5,
            prompt = "Press ~INPUT_CONTEXT~ to check mailbox",
            searchTime = 3000,
            animDict = "amb@prop_human_atm@",
            animName = "base"
        }
    },

    -- Object detection settings
    ObjectDetection = {
        ScanRadius = 10.0,        -- How far to look for objects
        ScanInterval = 1000,      -- How often to scan (ms)
        MaxObjects = 5,           -- Max objects to track at once
        EnableDebugMarkers = true -- Show debug markers on detected objects
    },
    
    -- Special items that trigger events
    SpecialItems = {
        ["clue_paper"] = {
            event = "worldsearch:foundClue",
            message = "You found an interesting clue!"
        },
        ["treasure_map"] = {
            event = "worldsearch:foundMap", 
            message = "You discovered a treasure map!"
        }
    },
    
    -- Interaction prompts
    Prompts = {
        search_object = "Press ~INPUT_CONTEXT~ to search",
        search_npc = "Press ~INPUT_CONTEXT~ to search person", 
        search_vehicle = "Press ~INPUT_CONTEXT~ to search vehicle",
        search_location = "Press ~INPUT_CONTEXT~ to investigate"
    },
    
    -- Notification messages
    Messages = {
        searching = "Searching...",
        search_complete = "Search completed!",
        search_failed = "Nothing found.",
        search_cooldown = "You need to wait before searching here again.",
        already_searching = "You are already searching something.",
        too_far = "You are too far away to search.",
        no_permission = "You don't have permission to search here.",
        found_item = "Found: %s x%d",
        found_money = "Found $%d",
        search_interrupted = "Search interrupted!"
    }
}