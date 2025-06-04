# XNL-Trains QBCore Integration

## Overview
This update adds full QBCore integration to the XNL-Trains script, including:
- QBCore money system integration (qb-banking)
- qb-target interactions for ticket machines
- QBCore notification system
- Proper player data handling
- Admin commands
- Export functions for other resources

## Installation

### 1. Requirements
- QBCore Framework
- qb-target
- qb-core (obviously)

### Optional Dependencies
- qb-banking (for enhanced banking features)
- qb-policejob (for police alerts)
- oxmysql (if you want database ticket persistence)

### 2. Installation Steps

1. **Replace the original files** with the new QBCore versions:
   - `config.lua` → New configuration with QBCore settings
   - `client.lua` → Updated with QBCore integration
   - `server.lua` → New server-side script for money handling
   - `fxmanifest.lua` → Updated with proper dependencies

2. **Configure the script** in `config.lua`:
   ```lua
   Config.UseQBCore = true -- Enable QBCore integration
   Config.PayWithBank = true -- true = bank, false = cash
   Config.TicketPrice = 25 -- Set your desired ticket price
   Config.UseQBTarget = true -- Enable qb-target interactions
   ```

3. **Start the resource** in your server.cfg:
   ```
   ensure XNL-FiveM-Trains
   ```

## Configuration Options

### QBCore Settings
```lua
Config.UseQBCore = true -- Enable/disable QBCore features
Config.QBCoreExport = 'qb-core' -- Your QBCore export name
Config.PayWithBank = true -- Payment method (bank/cash)
Config.TicketPrice = 25 -- Ticket price
```

### Target System
```lua
Config.UseQBTarget = true -- Use qb-target for interactions
Config.TargetDistance = 2.0 -- Interaction distance
```

### Security Features
```lua
Config.AllowEnterTrainWanted = false -- Allow wanted players
Config.ReportTerroristOnMetro = true -- Police alerts for shooting
Config.TerroristWantedLevel = 4 -- Wanted level for shooting
Config.IllegalBoardingWantedLevel = 1 -- Wanted level for no ticket
```

### Notifications
```lua
Config.NotificationType = 'qb' -- 'qb' or 'original' style
```

## Key Features

### 1. QBCore Money Integration
- Automatically charges players using QBCore money system
- Supports both bank and cash payments
- Proper transaction logging
- Insufficient funds handling

### 2. qb-target Integration
- Click-to-interact with ticket machines
- No more proximity-based key prompts
- Clean, modern interaction system
- Configurable interaction distance

### 3. Enhanced Notifications
- QBCore notification system
- Fallback to original SMS-style notifications
- Multiple notification types (success, error, warning)

### 4. Admin Features
- `/giveticket [playerid]` - Give tickets to players
- `/traininfo` - Check money and ticket info
- Debug commands for testing

### 5. Export Functions
```lua
-- Give a player a free ticket
exports['XNL-FiveM-Trains']:GivePlayerTicket(playerId)

-- Get current ticket price
local price = exports['XNL-FiveM-Trains']:GetTicketPrice()

-- Charge player custom amount
local success = exports['XNL-FiveM-Trains']:ChargePlayerForTicket(playerId, customPrice)
```

## Money System Integration

### Payment Process
1. Player interacts with ticket machine via qb-target
2. Client checks if player already has ticket
3. Server-side money validation and transaction
4. Success/failure notification to client
5. Ticket activation or error message

### Transaction Flow
```lua
-- Server checks player money
local Player = QBCore.Functions.GetPlayer(src)
local hasMoney = Player.PlayerData.money.bank >= Config.TicketPrice

-- Remove money if sufficient funds
if hasMoney then
    Player.Functions.RemoveMoney('bank', Config.TicketPrice, 'metro-ticket')
    -- Give ticket to player
end
```

## Security Features

### Fare Evasion Detection
- Automatic detection when players board without tickets
- Progressive warning system
- Police alerts through QBCore police system
- Configurable wanted levels

### Anti-Terrorism System
- Detects shooting on metro vehicles
- Automatic police alerts
- High wanted level assignment
- Configurable enforcement

## Language Support

The script maintains the original multi-language support:
- English (en)
- French (fr) 
- Spanish (es)

Configure in `config.lua`:
```lua
Config.Language = 'en' -- Set your preferred language
```

## Troubleshooting

### Common Issues

1. **"QBCore object not found"**
   - Ensure QBCore is started before this resource
   - Check that `Config.QBCoreExport` matches your QBCore export name

2. **"qb-target not working"**
   - Verify qb-target is installed and running
   - Check target distance in config
   - Ensure ticket machine models are correct

3. **"Money not being deducted"**
   - Verify player has sufficient funds
   - Check if `Config.PayWithBank` matches intended payment method
   - Enable debug mode to see transaction logs

4. **"Notifications not showing"**
   - Check `Config.NotificationType` setting
   - Verify QBCore is properly initialized
   - Try switching to 'original' notification type

### Debug Mode
Enable debug mode in config for detailed logging:
```lua
Config.Debug = true
```

This will provide console output for:
- Player money checks
- Transaction results
- Ticket purchases
- System initialization

## Migration from Original

### Backwards Compatibility
- Set `Config.UseQBCore = false` to use original system
- Set `Config.UseQBTarget = false` for original proximity system
- Original SMS notifications available via config

### Data Migration
- No database changes required
- Tickets are session-based (not persistent)
- Optional database integration available (see commented code in server.lua)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Enable debug mode to identify issues
3. Verify all dependencies are installed and running
4. Check server console for error messages

## Credits

- Original script: VenomXNL
- Based on work by: Blumlaut/Bluethefurry
- QBCore integration: Assistant
- Framework: QBCore Framework