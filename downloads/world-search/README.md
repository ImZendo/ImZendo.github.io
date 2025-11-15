# 🔍 World Search System

> A comprehensive modular plugin for `interaction_core` that enables players to search world objects, locations, and NPCs for randomized loot, clues, and items.

## 🌟 Features

### 🎯 **Interactive Search System**
- **World Objects**: Search dumpsters, trash bins, benches, mailboxes, and more
- **Location-Based**: Set up search zones at specific coordinates
- **NPC Searching**: Search unconscious or defeated NPCs
- **Vehicle Searching**: Look through abandoned or unlocked vehicles
- **Dynamic Zones**: Automatically detect searchable objects nearby

### 🎲 **Advanced Loot System**
- **Randomized Loot Tables**: Configurable drop rates and quantities
- **Rare Items**: Special items with unique effects and events
- **Experience Bonuses**: Better loot for experienced searchers
- **Zone Freshness**: Better rewards in recently unused areas
- **Bad Luck Protection**: Ensures unlucky players eventually find something

### ⚙️ **Smart Management**
- **Cooldown System**: Prevents spam with zone-specific cooldowns
- **Player Statistics**: Tracks search history and success rates
- **Framework Agnostic**: Works with ESX, QBCore, or standalone
- **Memory Optimized**: Efficient cleanup and resource management

### 🎨 **Rich User Experience**
- **Progress Bars**: Visual feedback during searches
- **Notifications**: Framework-integrated messages
- **Sound Effects**: Audio cues for discoveries
- **Particle Effects**: Visual rewards for finding loot
- **Cancellation**: Players can stop searches by moving or pressing ESC

## 📦 Installation

### Prerequisites
- **interaction_core**: This resource requires the interaction_core system
- **FiveM Server**: Build 2545+ recommended
- **Framework**: ESX, QBCore, or standalone (optional)

### Setup Steps

1. **Download and Extract**
   ```bash
   # Place in your resources folder
   resources/[gameplay]/world-search/
   ```

2. **Add to server.cfg**
   ```cfg
   # Ensure interaction_core starts first
   ensure interaction_core
   ensure world-search
   ```

3. **Configure the Resource**
   - Edit `shared/config.lua` to customize settings
   - Modify loot tables, search zones, and timings
   - Adjust framework integration if needed

4. **Restart Server**
   ```bash
   restart world-search
   ```

## 🔧 Configuration

### Basic Settings
```lua
WorldSearchConfig = {
    Debug = false,                    -- Enable debug logging
    DefaultSearchTime = 5000,         -- 5 seconds per search
    SearchCooldown = 30000,          -- 30 seconds between same-zone searches
    MaxSearchDistance = 2.5,         -- Maximum search range
    GlobalCooldown = 5000,           -- 5 seconds between any searches
}
```

### Loot Tables
```lua
-- Example loot table
WorldSearchConfig.DefaultLootTables["custom_container"] = {
    {item = "bread", chance = 25, min = 1, max = 3},
    {item = "water", chance = 20, min = 1, max = 2},
    {item = "money", chance = 15, min = 10, max = 50},
    {item = "nothing", chance = 40, message = "Empty container..."}
}
```

### Search Zones
```lua
-- Add custom search zone
table.insert(WorldSearchConfig.DefaultSearchZones, {
    name = "Police Station Lockers",
    coords = vector3(441.0, -979.0, 30.69),
    range = 2.0,
    searchType = WorldSearchConfig.SearchTypes.LOCATION,
    lootTable = "police_evidence",
    prompt = "Press ~INPUT_CONTEXT~ to search lockers",
    requireJob = {name = "police", grade = 0},
    oneTime = false
})
```

## 🎮 Usage

### For Players

#### Basic Searching
1. **Approach** a searchable object or location
2. **Press E** when the prompt appears
3. **Wait** for the search to complete (don't move too far!)
4. **Receive** your loot and notification

#### Search Types
- **🗑️ Dumpsters**: Often contain scrap, bottles, sometimes valuables
- **🪑 Benches**: May hide money, phones, or personal items  
- **📮 Mailboxes**: Letters, packages, occasionally money
- **🏪 Vending Machines**: Coins, sometimes free items
- **👤 NPCs**: Money, IDs, keys (only if unconscious/defeated)

#### Tips for Better Loot
- **Search regularly** - experience improves your luck
- **Try different locations** - fresh areas have better rewards
- **Search at night** - bonus rare item chance
- **Be patient** - completing full searches gives bonuses

### For Developers

#### Adding Custom Search Zones
```lua
-- Server-side
exports['world-search']:AddSearchZone({
    name = "Secret Stash",
    coords = vector3(100.0, 200.0, 30.0),
    range = 1.5,
    lootTable = "secret_stash",
    prompt = "Press ~INPUT_CONTEXT~ to investigate",
    requireItem = "metal_detector",
    oneTime = true
})
```

#### Creating Custom Loot Tables
```lua
-- Server-side
exports['world-search']:AddLootTable("treasure_chest", {
    {item = "gold_bar", chance = 5, min = 1, max = 1, message = "Jackpot! A gold bar!"},
    {item = "silver_coin", chance = 15, min = 2, max = 5},
    {item = "old_jewelry", chance = 25, min = 1, max = 3},
    {item = "money", chance = 30, min = 100, max = 500},
    {item = "nothing", chance = 25, message = "The chest is empty..."}
})
```

#### Custom Loot Callbacks
```lua
-- Server-side - Handle special items
exports['world-search']:AddCustomLootCallback("magic_scroll", function(playerId, loot, zone)
    -- Custom handling for magic scroll
    TriggerClientEvent('magic:learnSpell', playerId, loot.spellType)
    return true, "You learned a new spell!"
end)
```

#### Checking Player Status
```lua
-- Client-side
if exports['world-search']:IsPlayerSearching() then
    print("Player is currently searching")
end

-- Server-side
local searchData = exports['world-search']:GetPlayerSearchData(playerId)
if searchData then
    print("Player is searching zone:", searchData.zone.name)
end
```

## 🎨 Customization

### Framework Integration

#### ESX Integration
```lua
-- Automatically detected - no additional setup needed
-- Uses ESX inventory, job, and money systems
```

#### QBCore Integration  
```lua
-- Automatically detected - no additional setup needed
-- Uses QBCore inventory, job, and money systems
```

#### Standalone Mode
```lua
-- Works without frameworks
-- Triggers events for custom inventory systems:
-- 'worldsearch:giveItem', 'worldsearch:giveMoney'
```

### Custom Animations
```lua
-- In search zone config
animation = {
    dict = "amb@prop_human_bum_bin@",
    anim = "bin_0", 
    flag = 49
}
```

### UI Customization
```lua
-- Progress bar colors
ProgressBarColor = {r = 255, g = 165, b = 0}, -- Orange

-- Notification settings
NotificationTime = 4000,
```

## 🔌 Events & Exports

### Client Exports
```lua
exports['world-search']:IsPlayerSearching()           -- Check if searching
exports['world-search']:GetSearchProgress()           -- Get search progress (0-1)
```

### Server Exports
```lua
exports['world-search']:AddSearchZone(data)           -- Add search zone
exports['world-search']:RemoveSearchZone(zoneId)      -- Remove search zone
exports['world-search']:AddLootTable(name, table)     -- Add loot table
exports['world-search']:GetPlayerSearchData(playerId) -- Get player search status
exports['world-search']:ResetSearchCooldown(playerId) -- Reset cooldown
exports['world-search']:AddCustomLootCallback(item, fn) -- Custom item handler
```

### Events
```lua
-- Server Events
'worldsearch:searchCompleted'     -- (playerId, zoneId, loot)
'worldsearch:specialLootFound'    -- (playerId, loot, zone)
'worldsearch:clueFound'           -- (playerId, clueId, loot, zone)
'worldsearch:treasureMapFound'    -- (playerId, location, loot, zone)

-- Client Events  
'worldsearch:searchCompleted'     -- (zoneId, loot)
'worldsearch:specialLootFound'    -- (loot, zone)
```

## 🎯 Examples

### Treasure Hunt System
```lua
-- Create treasure locations that require maps
local treasureZones = {
    {coords = vector3(1000, 2000, 30), reward = "gold_bars"},
    {coords = vector3(1500, 2500, 25), reward = "ancient_artifact"}
}

-- Handle treasure map usage
RegisterNetEvent('worldsearch:treasureMapFound')
AddEventHandler('worldsearch:treasureMapFound', function(playerId, treasureLocation, loot, zone)
    -- Create temporary treasure zone
    exports['world-search']:AddSearchZone({
        name = "Treasure Location",
        coords = treasureLocation.coords,
        range = 3.0,
        lootTable = "treasure_chest",
        oneTime = true,
        temporary = true
    })
end)
```

### Police Evidence Room
```lua
-- Restricted area for police only
exports['world-search']:AddSearchZone({
    name = "Evidence Locker",
    coords = vector3(441.7, -979.4, 30.69),
    range = 2.0,
    searchType = 2, -- LOCATION
    lootTable = "police_evidence",
    prompt = "Press ~INPUT_CONTEXT~ to search evidence",
    requireJob = {name = "police", grade = 1},
    searchTime = 10000, -- Takes longer to search
    cooldown = 300000   -- 5 minute cooldown
})
```

### Dynamic Scavenging
```lua
-- Automatically create search zones for nearby objects
CreateThread(function()
    while true do
        Wait(30000) -- Every 30 seconds
        
        local players = GetPlayers()
        for _, playerId in ipairs(players) do
            local ped = GetPlayerPed(playerId)
            local coords = GetEntityCoords(ped)
            
            -- Find nearby searchable objects
            local objects = exports['world-search']:FindNearbySearchableObjects(20.0)
            
            for _, obj in ipairs(objects) do
                -- Create temporary search zone
                exports['world-search']:AddSearchZone({
                    name = "Scavenge " .. obj.type,
                    coords = obj.coords,
                    range = 2.0,
                    lootTable = obj.type,
                    temporary = true,
                    autoRemove = 120000 -- Remove after 2 minutes
                })
            end
        end
    end
end)
```

## 🐛 Troubleshooting

### Common Issues

**Q: Search prompts not appearing**
- Ensure `interaction_core` is running and started before `world-search`
- Check console for errors during startup
- Verify search zone coordinates are correct

**Q: No loot dropping**
- Check loot table configuration in `shared/config.lua`
- Verify framework integration (ESX/QBCore items exist)
- Enable debug mode to see loot rolls in console

**Q: Performance issues**
- Reduce number of search zones if experiencing lag
- Increase cooldown timers to reduce server load
- Check for memory leaks with resource monitor

**Q: Framework integration not working**
- Verify ESX/QBCore is properly started
- Check item names exist in framework database
- Test with debug mode enabled

### Debug Commands
```lua
-- Enable debug mode in config.lua
WorldSearchConfig.Debug = true

-- Server console commands (if debug enabled)
wsinfo          -- Show search system statistics
```

## 🤝 Support

### Getting Help
1. **Check Configuration**: Verify all settings in `shared/config.lua`
2. **Enable Debug**: Turn on debug mode to see detailed logs
3. **Check Dependencies**: Ensure `interaction_core` is working properly
4. **Framework Compatibility**: Verify ESX/QBCore integration

### Contributing
- Submit issues and feature requests
- Create pull requests for improvements  
- Share custom loot tables and search zones
- Help with documentation and examples

## 📄 License

This project is open source. Feel free to modify and distribute according to your needs.

---

<p align="center">
  <strong>🔍 Discover the world around you - there's always something to find!</strong>
  <br>
  <em>Compatible with interaction_core • Framework Agnostic • Performance Optimized</em>
</p>