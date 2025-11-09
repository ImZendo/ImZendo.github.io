# 🔓 Zendo Lockpicking System

> Advanced vehicle lockpicking minigame with flexible item management and framework integration.

## 🎮 Features

- **Interactive Circular Minigame**: Precise timing-based lockpicking challenge
- **Flexible Item System**: Works with built-in items OR your existing inventory
- **Framework Auto-Detection**: Supports ESX, QB-Core, or standalone operation
- **Production Optimized**: Memory-safe, performance-focused architecture
- **Clean Configuration**: Easy setup with comprehensive customization options

## 🔧 Configuration Highlights

```lua
-- Choose your item system
Config.RequiredItem = {
    enabled = true,
    useBuiltInItem = false,  -- Set to true for automatic lockpick items
    customItem = {
        itemName = 'lockpick',
        removeOnBreak = true
    }
}

-- Adjust difficulty
Config.Minigame = {
    difficulty = 'medium',  -- 'easy', 'medium', 'hard'
    timeLimit = 15,
    maxAttempts = 3
}
```

## 🚀 Quick Setup

1. Configure your preferred item system in `config.lua`
2. Ensure both `zendo-lockpic` and `interaction_core` are started
3. Approach any locked vehicle and press **E** to begin lockpicking

## 📁 File Structure

```
zendo-lockpic/
├── client.lua          # Main client logic & minigame integration
├── server.lua          # Server-side validation & item management  
├── config.lua          # Comprehensive configuration options
├── fxmanifest.lua      # Resource manifest
└── html/               # Minigame UI assets
    ├── index.html      # Minigame interface
    ├── script.js       # Game logic & collision detection
    └── style.css       # Modern UI styling
```

## 🎯 How It Works

The system uses a sophisticated circular lockpicking minigame where players must time their clicks to align a moving red line with randomly positioned green target zones. Success requires skill and precision, making it engaging without being frustrating.

---

**Part of the Advanced Vehicle Lockpicking System**