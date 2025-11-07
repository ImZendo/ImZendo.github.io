# Lockpick Job System

**Free Download from Anthony Benitez Portfolio**

A complete lockpicking job system for FiveM servers using the QBCore framework. This system provides an immersive locksmith job experience with skill progression, rewards, and administrative controls.

## Features

- **Skill Progression System**: Players develop their lockpicking skills over time
- **Dynamic Job Locations**: Multiple configurable lockpicking locations with varying difficulty
- **Reward System**: Earnings based on skill level and job difficulty
- **Database Integration**: Persistent skill and progress tracking
- **Administrative Commands**: Full admin control over player skills and statistics
- **QBCore Integration**: Seamless integration with QBCore framework
- **Anti-Exploit Protection**: Cooldowns and validation to prevent abuse

## Installation

1. **Download Files**: Download all files from this package
2. **Place Files**: 
   - Place `lockpick-job-client.lua` in your resource's `client/` folder
   - Place `lockpick-job-server.lua` in your resource's `server/` folder
3. **Update fxmanifest.lua**:
   ```lua
   client_scripts {
       'client/lockpick-job-client.lua'
   }
   
   server_scripts {
       '@oxmysql/lib/MySQL.lua', -- or your preferred MySQL resource
       'server/lockpick-job-server.lua'
   }
   ```
4. **Configure Database**: The system will automatically create the required database table
5. **Add Job**: Add the locksmith job to your QBCore jobs configuration
6. **Configure Locations**: Edit the locations in the client file to match your server

## Configuration

### Job Setup (qb-core/shared/jobs.lua)
```lua
['lockpick_job'] = {
    label = 'Locksmith',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        ['0'] = {
            name = 'Apprentice',
            payment = 50
        },
        ['1'] = {
            name = 'Journeyman', 
            payment = 75
        },
        ['2'] = {
            name = 'Master Locksmith',
            payment = 100
        },
    },
},
```

### Item Setup (qb-core/shared/items.lua)
```lua
['lockpick'] = {
    ['name'] = 'lockpick',
    ['label'] = 'Lockpick',
    ['weight'] = 300,
    ['type'] = 'item',
    ['image'] = 'lockpick.png',
    ['unique'] = false,
    ['useable'] = true,
    ['shouldClose'] = false,
    ['combinable'] = nil,
    ['description'] = 'Very useful if you lose your keys a lot'
},
```

## Usage

### For Players
1. Get employed as a locksmith (`/setjob [id] lockpick_job`)
2. Obtain lockpicks from shops or other players
3. Use `/lockpickskill` to check your current skill level
4. Trigger the job start event or use in-game job system
5. Follow GPS to lockpicking locations
6. Complete the minigame to earn money and skill XP

### For Administrators
- `/setlockpickskill [playerid] [skill]` - Set a player's skill level (0-100)
- `/lockpickstats [playerid]` - View a player's lockpicking statistics

## Skill System

- **Skill Range**: 0-100
- **Skill Gain**: 2-8 points per successful job (based on difficulty)
- **Success Rate**: Increases with skill level (max 85% success rate)
- **Difficulty Modifiers**: Harder locations provide more skill and money but lower success rates
- **Tool Durability**: Lockpicks can break, especially at lower skill levels

## Rewards

- **Base Reward**: $150 per job
- **Skill Multiplier**: Higher skill = higher rewards
- **Difficulty Multiplier**: Harder jobs = better pay
- **Bonus Chances**: Random bonus events for extra rewards

## Database Schema

```sql
CREATE TABLE player_lockpick_skills (
    citizenid VARCHAR(50) PRIMARY KEY,
    skill_level INT DEFAULT 0,
    jobs_completed INT DEFAULT 0,
    last_job_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Dependencies

- QBCore Framework
- MySQL Resource (oxmysql recommended)
- qb-target (for interaction zones)

## Customization

### Locations
Edit the `Config.Locations` table in the client file to add/remove/modify lockpicking locations:

```lua
{coords = vector3(x, y, z), heading = 0.0, difficulty = 1}
```

### Rewards and Skill
Modify the `Config` table values to adjust:
- Base rewards
- Skill increment amounts
- Maximum skill level
- Cooldown times

### Minigame
Replace the `StartLockpickingMinigame()` function with your preferred lockpicking minigame system.

## Support

This is a free resource provided as-is. For custom modifications or support, contact Anthony Benitez through the portfolio website.

## License

Free to use and modify for personal and commercial FiveM servers. Attribution appreciated but not required.

---

**Created by Anthony Benitez**  
Portfolio: [Your Portfolio URL]  
Discord: [Your Discord]