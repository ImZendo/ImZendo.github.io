# Interaction Core System

**Advanced Interaction Framework for FiveM**  
Created by Anthony Benitez

## Overview

The Interaction Core System is a comprehensive framework for creating interactive elements in FiveM servers. It provides a flexible, extensible system for handling player interactions with objects, NPCs, and locations throughout the game world.

## Features

- **Multiple Interaction Types**: Simple, animated, progressive, menu-based, conditional, and timed interactions
- **Advanced Conditions**: Job, gang, item, and custom condition requirements
- **Visual Elements**: Blips, markers, and help text support
- **Performance Optimized**: Efficient distance checking and resource management
- **Highly Configurable**: Extensive customization options for every aspect
- **Developer Friendly**: Clean API with comprehensive documentation
- **Framework Agnostic**: Works with any FiveM framework with minimal modifications

## Interaction Types

### 1. Simple Interaction
Basic interaction that executes a callback function immediately.

### 2. Animated Interaction  
Plays an animation before executing the callback.

### 3. Progressive Interaction
Shows a progress bar during interaction completion.

### 4. Menu Interaction
Opens a menu or UI interface when triggered.

### 5. Conditional Interaction
Executes based on specific player conditions (job, items, etc.).

### 6. Timed Interaction
Requires the player to stay within range for a specified duration.

## API Documentation

### Creating Interactions

```lua
local interactionId = InteractionCore:CreateInteraction({
    id = 'unique_interaction_id',           -- Optional: Auto-generated if not provided
    coords = vector3(x, y, z),              -- Required: Interaction location
    distance = 2.5,                         -- Optional: Interaction distance (default: 2.5)
    type = InteractionCore.Types.SIMPLE,    -- Optional: Interaction type
    helpText = 'Press ~INPUT_CONTEXT~ to interact', -- Optional: Help text
    
    -- Callback function
    callback = function(data)
        print('Interaction triggered!')
    end,
    
    -- Conditions
    job = 'police',                         -- Optional: Required job
    gang = 'ballas',                        -- Optional: Required gang  
    item = 'lockpick',                      -- Optional: Required item
    conditions = {                          -- Optional: Custom conditions
        function() return true end
    },
    
    -- Visual options
    blip = {                               -- Optional: Blip configuration
        sprite = 1,
        color = 1,
        scale = 0.8,
        name = 'Interaction Point'
    },
    marker = {                             -- Optional: Marker configuration
        type = 1,
        size = {x = 1.0, y = 1.0, z = 1.0},
        color = {r = 255, g = 0, b = 0, alpha = 100},
        drawDistance = 50.0
    },
    
    -- Animation (for ANIMATED type)
    animation = {
        dict = 'anim@heists@keycard@',
        name = 'exit',
        duration = 2000
    },
    
    -- Progress bar (for PROGRESSIVE type)
    progressBar = {
        duration = 5000,
        label = 'Processing...',
        canCancel = true,
        disableMovement = true
    },
    
    -- Menu (for MENU type)
    menu = {
        -- Your menu configuration
    },
    
    -- Custom data
    data = {
        customValue = 'example'
    },
    
    -- Timing options
    cooldown = 1000,                       -- Optional: Cooldown between uses
    timer = 10000                          -- Optional: Timer duration (for TIMED type)
})
```

### Managing Interactions

```lua
-- Remove an interaction
InteractionCore:RemoveInteraction(interactionId)

-- Check active interactions
local activeInteractions = InteractionCore.activeInteractions

-- Get specific interaction
local interaction = InteractionCore.interactions[interactionId]
```

### Configuration Options

```lua
InteractionCore.Config = {
    maxInteractionDistance = 2.5,  -- Default interaction distance
    keyBind = 38,                  -- Default key bind (E key)
    showHelpText = true,           -- Show help text by default
    animationDuration = 2000,      -- Default animation duration
    cooldownTime = 1000,           -- Default cooldown time
    debugMode = false              -- Enable debug messages
}
```

## Usage Examples

### Simple Shop Interaction
```lua
InteractionCore:CreateInteraction({
    coords = vector3(25.7, -1347.3, 29.49),
    helpText = 'Press ~INPUT_CONTEXT~ to open shop',
    callback = function()
        -- Open shop menu
        TriggerEvent('shop:client:open')
    end,
    blip = {
        sprite = 52,
        color = 2,
        name = 'Shop'
    }
})
```

### Job-Specific Interaction
```lua
InteractionCore:CreateInteraction({
    coords = vector3(441.7, -979.6, 30.6),
    type = InteractionCore.Types.PROGRESSIVE,
    job = 'police',
    helpText = 'Press ~INPUT_CONTEXT~ to access evidence locker',
    progressBar = {
        duration = 3000,
        label = 'Accessing locker...',
        canCancel = false
    },
    callback = function()
        TriggerEvent('police:client:evidenceLocker')
    end
})
```

### Animated Interaction with Item Requirement
```lua
InteractionCore:CreateInteraction({
    coords = vector3(1273.0, -1720.4, 54.6),
    type = InteractionCore.Types.ANIMATED,
    item = 'lockpick',
    animation = {
        dict = 'anim@heists@keycard@',
        name = 'exit',
        duration = 4000
    },
    helpText = 'Press ~INPUT_CONTEXT~ to pick lock',
    callback = function()
        TriggerEvent('lockpicking:client:start')
    end,
    marker = {
        type = 1,
        size = {x = 1.5, y = 1.5, z = 0.5},
        color = {r = 255, g = 255, b = 0, alpha = 120}
    }
})
```

### Timed Interaction
```lua
InteractionCore:CreateInteraction({
    coords = vector3(-1037.8, -2737.6, 20.1),
    type = InteractionCore.Types.TIMED,
    timer = 10000, -- 10 seconds
    helpText = 'Stay in the area to hack the system',
    callback = function()
        TriggerEvent('hacking:client:success')
    end,
    conditions = {
        function()
            -- Custom condition: check if player has hacking device
            return HasItem('hacking_device')
        end
    }
})
```

## Integration with Frameworks

### QBCore Integration
```lua
-- In your client-side script
local QBCore = exports['qb-core']:GetCoreObject()

-- Check player job
function InteractionCore:ValidateConditions(interaction, playerPed)
    if interaction.job then
        local PlayerData = QBCore.Functions.GetPlayerData()
        if PlayerData.job.name ~= interaction.job then
            return false
        end
    end
    -- ... rest of validation
end
```

### ESX Integration
```lua
-- In your client-side script
local ESX = exports['es_extended']:getSharedObject()

-- Check player job
function InteractionCore:ValidateConditions(interaction, playerPed)
    if interaction.job then
        local PlayerData = ESX.GetPlayerData()
        if PlayerData.job.name ~= interaction.job then
            return false
        end
    end
    -- ... rest of validation
end
```

## Advanced Features

### Custom Conditions
```lua
InteractionCore:CreateInteraction({
    coords = vector3(x, y, z),
    conditions = {
        function()
            -- Check if it's nighttime
            local hour = GetClockHours()
            return hour >= 22 or hour <= 6
        end,
        function()
            -- Check if player is not in vehicle
            return not IsPedInAnyVehicle(PlayerPedId(), false)
        end
    },
    callback = function()
        -- Your callback here
    end
})
```

### Dynamic Interaction Updates
```lua
-- Get interaction and modify it
local interaction = InteractionCore.interactions['my_interaction']
if interaction then
    interaction.helpText = 'New help text'
    interaction.distance = 5.0
    interaction.active = false -- Disable temporarily
end
```

### Performance Optimization
- Interactions automatically optimize based on player distance
- Unused interactions can be disabled to save resources
- Built-in cleanup on resource stop

## Installation

1. Download the `interaction-core.lua` file
2. Place it in your resource's client folder
3. Add to your `fxmanifest.lua`:
   ```lua
   client_scripts {
       'client/interaction-core.lua'
   }
   ```
4. The system will auto-initialize when the resource starts

## Customization

### Adding New Interaction Types
```lua
-- Add new type to InteractionCore.Types
InteractionCore.Types.CUSTOM = 'custom'

-- Add handler in HandleInteractionType function
elseif interactionType == self.Types.CUSTOM then
    self:HandleCustomInteraction(interaction, playerPed)
```

### Custom Progress Bar Integration
Replace the `ShowProgressBar` function with your preferred progress bar system:
```lua
function InteractionCore:ShowProgressBar(data, callback)
    -- Replace with your progress bar system
    exports['progressbar']:Progress(data, callback)
end
```

### Custom Menu Integration
Replace the `OpenMenu` function with your preferred menu system:
```lua
function InteractionCore:OpenMenu(menuData, interactionData)
    -- Replace with your menu system  
    exports['qb-menu']:openMenu(menuData)
end
```

## Performance Notes

- The system uses optimized distance checking to minimize performance impact
- Interactions outside render distance are automatically excluded from processing
- Sleep values are dynamically adjusted based on nearby interactions
- All interactions are cleaned up automatically when the resource stops

## License

Free to use and modify for personal and commercial FiveM servers. Attribution appreciated but not required.

---

**Created by Anthony Benitez**  
Portfolio: [Your Portfolio URL]