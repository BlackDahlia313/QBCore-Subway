-- QBCore Metro Train System - Server Side
-- Handles ticket purchases, inventory items, and database persistence

local QBCore = nil

-- Initialize QBCore
if Config.UseQBCore then
    QBCore = exports[Config.QBCoreExport]:GetCoreObject()
end

-- Database initialization
if Config.UseDatabase then
    Citizen.CreateThread(function()
        if Config.Debug then
            print("^2[XNL-Trains]^7 Initializing database tables...")
        end
        
        MySQL.ready(function()
            MySQL.query([[
                CREATE TABLE IF NOT EXISTS `metro_tickets` (
                    `id` INT AUTO_INCREMENT PRIMARY KEY,
                    `citizenid` VARCHAR(50) NOT NULL,
                    `ticket_id` VARCHAR(100) UNIQUE NOT NULL,
                    `purchased_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    `expires_at` TIMESTAMP NOT NULL,
                    `used_at` TIMESTAMP NULL,
                    `is_used` BOOLEAN DEFAULT FALSE,
                    `price_paid` INT NOT NULL DEFAULT 0,
                    INDEX `idx_citizenid` (`citizenid`),
                    INDEX `idx_ticket_id` (`ticket_id`),
                    INDEX `idx_expires_at` (`expires_at`)
                )
            ]], function(success)
                if success then
                    print("^2[XNL-Trains]^7 Database tables ready")
                else
                    print("^1[XNL-Trains]^7 Failed to create database tables")
                end
            end)
        end)
    end)
end

-- Handle ticket purchase
RegisterNetEvent('xnl-trains:server:buyTicket', function()
    local src = source
    
    if not Config.UseQBCore or not QBCore then
        -- Fallback: always allow ticket purchase
        TriggerClientEvent('xnl-trains:client:ticketPurchased', src, true)
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        if Config.Debug then
            print("^1[XNL-Trains]^7 Player not found for source: " .. src)
        end
        return
    end
    
    local success = false
    local ticketData = nil
    
    -- Check money and process payment
    if Config.PayWithBank then
        local bankMoney = Player.PlayerData.money.bank or 0
        if bankMoney >= Config.TicketPrice then
            success = Player.Functions.RemoveMoney('bank', Config.TicketPrice, 'metro-ticket-purchase')
        end
    else
        local cashMoney = Player.PlayerData.money.cash or 0
        if cashMoney >= Config.TicketPrice then
            success = Player.Functions.RemoveMoney('cash', Config.TicketPrice, 'metro-ticket-purchase')
        end
    end
    
    if success then
        if Config.UseQBInventory then
            -- Create ticket item data
            local ticketId = GenerateTicketId()
            local expiresAt = os.time() + (Config.TicketExpireTime * 3600) -- Convert hours to seconds
            
            ticketData = {
                ticket_id = ticketId,
                purchased_at = os.time(),
                expires_at = expiresAt,
                price_paid = Config.TicketPrice,
                used = false
            }
            
            -- Add physical item to inventory
            local itemAdded = Player.Functions.AddItem(Config.TicketItemName, 1, false, ticketData)
            
            if itemAdded then
                -- Store in database if enabled
                if Config.UseDatabase then
                    MySQL.insert('INSERT INTO metro_tickets (citizenid, ticket_id, expires_at, price_paid) VALUES (?, ?, FROM_UNIXTIME(?), ?)', {
                        Player.PlayerData.citizenid,
                        ticketId,
                        expiresAt,
                        Config.TicketPrice
                    })
                end
                
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.TicketItemName], 'add')
                
                if Config.Debug then
                    print("^2[XNL-Trains]^7 Player " .. GetPlayerName(src) .. " purchased metro ticket (ID: " .. ticketId .. ")")
                end
            else
                -- Refund if inventory full
                if Config.PayWithBank then
                    Player.Functions.AddMoney('bank', Config.TicketPrice, 'metro-ticket-refund')
                else
                    Player.Functions.AddMoney('cash', Config.TicketPrice, 'metro-ticket-refund')
                end
                
                TriggerClientEvent('xnl-trains:client:inventoryFull', src)
                success = false
            end
        end
        
        -- Log transaction
        TriggerEvent('qb-log:server:CreateLog', 'banking', 'Metro Ticket Purchase', 'green', 
            GetPlayerName(src) .. " purchased a metro ticket for $" .. Config.TicketPrice, false)
    else
        if Config.Debug then
            print("^3[XNL-Trains]^7 Player " .. GetPlayerName(src) .. " insufficient funds for metro ticket")
        end
    end
    
    -- Send result back to client
    TriggerClientEvent('xnl-trains:client:ticketPurchased', src, success, ticketData)
end)

-- Callbacks for ticket validation
QBCore.Functions.CreateCallback('xnl-trains:server:hasTicket', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        cb(false, nil)
        return 
    end
    
    local ticket = Player.Functions.GetItemByName(Config.TicketItemName)
    if ticket and ticket.amount > 0 then
        cb(true, ticket)
    else
        cb(false, nil)
    end
end)

QBCore.Functions.CreateCallback('xnl-trains:server:hasValidTicket', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        cb(false)
        return 
    end
    
    local ticket = Player.Functions.GetItemByName(Config.TicketItemName)
    if ticket and ticket.amount > 0 and ticket.info then
        local currentTime = os.time()
        
        -- Check if ticket is expired
        if ticket.info.expires_at and currentTime > ticket.info.expires_at then
            cb(false)
            return
        end
        
        -- Check if ticket is already used (if single-use tickets)
        if ticket.info.used then
            cb(false)
            return
        end
        
        cb(true)
    else
        cb(false)
    end
end)

-- Handle ticket usage
RegisterNetEvent('xnl-trains:server:useTicket', function(ticketId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    if Config.UseDatabase then
        MySQL.update('UPDATE metro_tickets SET used_at = NOW(), is_used = 1 WHERE ticket_id = ? AND citizenid = ?', {
            ticketId,
            Player.PlayerData.citizenid
        })
    end
    
    if Config.Debug then
        print("^2[XNL-Trains]^7 Ticket used: " .. ticketId .. " by " .. GetPlayerName(src))
    end
end)

-- Remove expired tickets
RegisterNetEvent('xnl-trains:server:removeExpiredTicket', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local ticket = Player.Functions.GetItemByName(Config.TicketItemName)
    if ticket then
        Player.Functions.RemoveItem(Config.TicketItemName, ticket.amount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.TicketItemName], 'remove')
    end
end)

-- Remove used tickets after exiting metro
RegisterNetEvent('xnl-trains:server:removeUsedTicket', function(ticketId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local ticket = Player.Functions.GetItemByName(Config.TicketItemName)
    if ticket and ticket.info and ticket.info.ticket_id == ticketId then
        Player.Functions.RemoveItem(Config.TicketItemName, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.TicketItemName], 'remove')
        
        if Config.Debug then
            print("^2[XNL-Trains]^7 Used ticket removed: " .. ticketId)
        end
    end
end)

-- Utility function to generate unique ticket IDs
function GenerateTicketId()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result = 'LST-'
    
    for i = 1, 8 do
        local randIndex = math.random(1, #chars)
        result = result .. string.sub(chars, randIndex, randIndex)
    end
    
    return result .. '-' .. os.time()
end

-- Admin commands for ticket management
if Config.Debug then
    QBCore.Commands.Add('giveticket', 'Give a metro ticket to a player', {{name = 'id', help = 'Player ID'}}, true, function(source, args)
        local targetId = tonumber(args[1])
        if targetId then
            local Player = QBCore.Functions.GetPlayer(targetId)
            if Player then
                local ticketId = GenerateTicketId()
                local expiresAt = os.time() + (Config.TicketExpireTime * 3600)
                
                local ticketData = {
                    ticket_id = ticketId,
                    purchased_at = os.time(),
                    expires_at = expiresAt,
                    price_paid = 0, -- Free ticket
                    used = false
                }
                
                local success = Player.Functions.AddItem(Config.TicketItemName, 1, false, ticketData)
                if success then
                    TriggerClientEvent('inventory:client:ItemBox', targetId, QBCore.Shared.Items[Config.TicketItemName], 'add')
                    TriggerClientEvent('QBCore:Notify', source, 'Metro ticket given to ' .. GetPlayerName(targetId), 'success')
                    TriggerClientEvent('QBCore:Notify', targetId, 'You received a free metro ticket!', 'success')
                else
                    TriggerClientEvent('QBCore:Notify', source, 'Player inventory is full', 'error')
                end
            else
                TriggerClientEvent('QBCore:Notify', source, 'Player not found', 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', source, 'Invalid player ID', 'error')
        end
    end, 'admin')
    
    QBCore.Commands.Add('traininfo', 'Get train system information', {}, false, function(source, args)
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            local cash = Player.PlayerData.money.cash or 0
            local bank = Player.PlayerData.money.bank or 0
            local ticket = Player.Functions.GetItemByName(Config.TicketItemName)
            local hasTicket = ticket and ticket.amount > 0 or false
            
            TriggerClientEvent('QBCore:Notify', source, 'Cash: 

-- Optional: Database integration for persistent tickets
--[[
-- Uncomment and modify this section if you want persistent tickets across sessions

RegisterNetEvent('xnl-trains:server:saveTicket', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Save to database or player metadata
    MySQL.Async.execute('INSERT INTO player_metro_tickets (citizenid, expires_at) VALUES (?, ?) ON DUPLICATE KEY UPDATE expires_at = VALUES(expires_at)', {
        citizenid,
        os.time() + (24 * 60 * 60) -- Expires in 24 hours
    })
end)

RegisterNetEvent('xnl-trains:server:checkTicket', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    MySQL.Async.fetchAll('SELECT * FROM player_metro_tickets WHERE citizenid = ? AND expires_at > ?', {
        citizenid,
        os.time()
    }, function(result)
        local hasTicket = #result > 0
        TriggerClientEvent('xnl-trains:client:ticketStatus', src, hasTicket)
    end)
end)
--]]

-- Server-side logging and analytics
local ticketsPurchasedToday = 0

RegisterNetEvent('xnl-trains:server:logTicketPurchase', function()
    ticketsPurchasedToday = ticketsPurchasedToday + 1
    
    if Config.Debug then
        print("^2[XNL-Trains]^7 Total tickets purchased today: " .. ticketsPurchasedToday)
    end
end)

-- Reset daily counter at midnight
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000 * 60) -- Check every hour
        
        local currentHour = tonumber(os.date('%H'))
        if currentHour == 0 then -- Midnight
            ticketsPurchasedToday = 0
            if Config.Debug then
                print("^2[XNL-Trains]^7 Daily ticket counter reset")
            end
        end
    end
end)

-- Export functions for other resources
exports('GetTicketPrice', function()
    return Config.TicketPrice
end)

exports('GivePlayerTicket', function(playerId)
    if Config.UseQBCore and QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            TriggerClientEvent('xnl-trains:client:ticketPurchased', playerId, true)
            return true
        end
    end
    return false
end)

exports('ChargePlayerForTicket', function(playerId, customPrice)
    local price = customPrice or Config.TicketPrice
    
    if Config.UseQBCore and QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local success = false
            
            if Config.PayWithBank then
                success = Player.Functions.RemoveMoney('bank', price, 'metro-ticket-custom')
            else
                success = Player.Functions.RemoveMoney('cash', price, 'metro-ticket-custom')
            end
            
            return success
        end
    end
    return false
end) .. cash .. ' | Bank: 

-- Optional: Database integration for persistent tickets
--[[
-- Uncomment and modify this section if you want persistent tickets across sessions

RegisterNetEvent('xnl-trains:server:saveTicket', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Save to database or player metadata
    MySQL.Async.execute('INSERT INTO player_metro_tickets (citizenid, expires_at) VALUES (?, ?) ON DUPLICATE KEY UPDATE expires_at = VALUES(expires_at)', {
        citizenid,
        os.time() + (24 * 60 * 60) -- Expires in 24 hours
    })
end)

RegisterNetEvent('xnl-trains:server:checkTicket', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    MySQL.Async.fetchAll('SELECT * FROM player_metro_tickets WHERE citizenid = ? AND expires_at > ?', {
        citizenid,
        os.time()
    }, function(result)
        local hasTicket = #result > 0
        TriggerClientEvent('xnl-trains:client:ticketStatus', src, hasTicket)
    end)
end)
--]]

-- Server-side logging and analytics
local ticketsPurchasedToday = 0

RegisterNetEvent('xnl-trains:server:logTicketPurchase', function()
    ticketsPurchasedToday = ticketsPurchasedToday + 1
    
    if Config.Debug then
        print("^2[XNL-Trains]^7 Total tickets purchased today: " .. ticketsPurchasedToday)
    end
end)

-- Reset daily counter at midnight
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000 * 60) -- Check every hour
        
        local currentHour = tonumber(os.date('%H'))
        if currentHour == 0 then -- Midnight
            ticketsPurchasedToday = 0
            if Config.Debug then
                print("^2[XNL-Trains]^7 Daily ticket counter reset")
            end
        end
    end
end)

-- Export functions for other resources
exports('GetTicketPrice', function()
    return Config.TicketPrice
end)

exports('GivePlayerTicket', function(playerId)
    if Config.UseQBCore and QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            TriggerClientEvent('xnl-trains:client:ticketPurchased', playerId, true)
            return true
        end
    end
    return false
end)

exports('ChargePlayerForTicket', function(playerId, customPrice)
    local price = customPrice or Config.TicketPrice
    
    if Config.UseQBCore and QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local success = false
            
            if Config.PayWithBank then
                success = Player.Functions.RemoveMoney('bank', price, 'metro-ticket-custom')
            else
                success = Player.Functions.RemoveMoney('cash', price, 'metro-ticket-custom')
            end
            
            return success
        end
    end
    return false
end) .. bank .. ' | Ticket Price: 

-- Optional: Database integration for persistent tickets
--[[
-- Uncomment and modify this section if you want persistent tickets across sessions

RegisterNetEvent('xnl-trains:server:saveTicket', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Save to database or player metadata
    MySQL.Async.execute('INSERT INTO player_metro_tickets (citizenid, expires_at) VALUES (?, ?) ON DUPLICATE KEY UPDATE expires_at = VALUES(expires_at)', {
        citizenid,
        os.time() + (24 * 60 * 60) -- Expires in 24 hours
    })
end)

RegisterNetEvent('xnl-trains:server:checkTicket', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    MySQL.Async.fetchAll('SELECT * FROM player_metro_tickets WHERE citizenid = ? AND expires_at > ?', {
        citizenid,
        os.time()
    }, function(result)
        local hasTicket = #result > 0
        TriggerClientEvent('xnl-trains:client:ticketStatus', src, hasTicket)
    end)
end)
--]]

-- Server-side logging and analytics
local ticketsPurchasedToday = 0

RegisterNetEvent('xnl-trains:server:logTicketPurchase', function()
    ticketsPurchasedToday = ticketsPurchasedToday + 1
    
    if Config.Debug then
        print("^2[XNL-Trains]^7 Total tickets purchased today: " .. ticketsPurchasedToday)
    end
end)

-- Reset daily counter at midnight
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000 * 60) -- Check every hour
        
        local currentHour = tonumber(os.date('%H'))
        if currentHour == 0 then -- Midnight
            ticketsPurchasedToday = 0
            if Config.Debug then
                print("^2[XNL-Trains]^7 Daily ticket counter reset")
            end
        end
    end
end)

-- Export functions for other resources
exports('GetTicketPrice', function()
    return Config.TicketPrice
end)

exports('GivePlayerTicket', function(playerId)
    if Config.UseQBCore and QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            TriggerClientEvent('xnl-trains:client:ticketPurchased', playerId, true)
            return true
        end
    end
    return false
end)

exports('ChargePlayerForTicket', function(playerId, customPrice)
    local price = customPrice or Config.TicketPrice
    
    if Config.UseQBCore and QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local success = false
            
            if Config.PayWithBank then
                success = Player.Functions.RemoveMoney('bank', price, 'metro-ticket-custom')
            else
                success = Player.Functions.RemoveMoney('cash', price, 'metro-ticket-custom')
            end
            
            return success
        end
    end
    return false
end) .. Config.TicketPrice .. ' | Has Ticket: ' .. tostring(hasTicket), 'primary')
        end
    end)
    
    QBCore.Commands.Add('removeticket', 'Remove metro ticket from player', {{name = 'id', help = 'Player ID'}}, true, function(source, args)
        local targetId = tonumber(args[1])
        if targetId then
            local Player = QBCore.Functions.GetPlayer(targetId)
            if Player then
                local ticket = Player.Functions.GetItemByName(Config.TicketItemName)
                if ticket then
                    Player.Functions.RemoveItem(Config.TicketItemName, ticket.amount)
                    TriggerClientEvent('inventory:client:ItemBox', targetId, QBCore.Shared.Items[Config.TicketItemName], 'remove')
                    TriggerClientEvent('QBCore:Notify', source, 'Removed metro ticket from ' .. GetPlayerName(targetId), 'success')
                else
                    TriggerClientEvent('QBCore:Notify', source, 'Player does not have a metro ticket', 'error')
                end
            else
                TriggerClientEvent('QBCore:Notify', source, 'Player not found', 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', source, 'Invalid player ID', 'error')
        end
    end, 'admin')
    
    QBCore.Commands.Add('metrostats', 'Get metro system statistics', {}, true, function(source, args)
        if Config.UseDatabase then
            MySQL.query('SELECT COUNT(*) as total_tickets, SUM(price_paid) as total_revenue FROM metro_tickets WHERE DATE(purchased_at) = CURDATE()', {}, function(result)
                if result[1] then
                    local stats = result[1]
                    TriggerClientEvent('QBCore:Notify', source, 'Today: ' .. stats.total_tickets .. ' tickets sold, 

-- Optional: Database integration for persistent tickets
--[[
-- Uncomment and modify this section if you want persistent tickets across sessions

RegisterNetEvent('xnl-trains:server:saveTicket', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Save to database or player metadata
    MySQL.Async.execute('INSERT INTO player_metro_tickets (citizenid, expires_at) VALUES (?, ?) ON DUPLICATE KEY UPDATE expires_at = VALUES(expires_at)', {
        citizenid,
        os.time() + (24 * 60 * 60) -- Expires in 24 hours
    })
end)

RegisterNetEvent('xnl-trains:server:checkTicket', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    MySQL.Async.fetchAll('SELECT * FROM player_metro_tickets WHERE citizenid = ? AND expires_at > ?', {
        citizenid,
        os.time()
    }, function(result)
        local hasTicket = #result > 0
        TriggerClientEvent('xnl-trains:client:ticketStatus', src, hasTicket)
    end)
end)
--]]

-- Server-side logging and analytics
local ticketsPurchasedToday = 0

RegisterNetEvent('xnl-trains:server:logTicketPurchase', function()
    ticketsPurchasedToday = ticketsPurchasedToday + 1
    
    if Config.Debug then
        print("^2[XNL-Trains]^7 Total tickets purchased today: " .. ticketsPurchasedToday)
    end
end)

-- Reset daily counter at midnight
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000 * 60) -- Check every hour
        
        local currentHour = tonumber(os.date('%H'))
        if currentHour == 0 then -- Midnight
            ticketsPurchasedToday = 0
            if Config.Debug then
                print("^2[XNL-Trains]^7 Daily ticket counter reset")
            end
        end
    end
end)

-- Export functions for other resources
exports('GetTicketPrice', function()
    return Config.TicketPrice
end)

exports('GivePlayerTicket', function(playerId)
    if Config.UseQBCore and QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            TriggerClientEvent('xnl-trains:client:ticketPurchased', playerId, true)
            return true
        end
    end
    return false
end)

exports('ChargePlayerForTicket', function(playerId, customPrice)
    local price = customPrice or Config.TicketPrice
    
    if Config.UseQBCore and QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local success = false
            
            if Config.PayWithBank then
                success = Player.Functions.RemoveMoney('bank', price, 'metro-ticket-custom')
            else
                success = Player.Functions.RemoveMoney('cash', price, 'metro-ticket-custom')
            end
            
            return success
        end
    end
    return false
end) .. (stats.total_revenue or 0) .. ' revenue', 'primary')
                end
            end)
        else
            TriggerClientEvent('QBCore:Notify', source, 'Database statistics not enabled', 'error')
        end
    end, 'admin')
end

-- Server-side logging and analytics
local ticketsPurchasedToday = 0

RegisterNetEvent('xnl-trains:server:logTicketPurchase', function()
    ticketsPurchasedToday = ticketsPurchasedToday + 1
    
    if Config.Debug then
        print("^2[XNL-Trains]^7 Total tickets purchased today: " .. ticketsPurchasedToday)
    end
end)

-- Reset daily counter at midnight
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000 * 60) -- Check every hour
        
        local currentHour = tonumber(os.date('%H'))
        if currentHour == 0 then -- Midnight
            ticketsPurchasedToday = 0
            if Config.Debug then
                print("^2[XNL-Trains]^7 Daily ticket counter reset")
            end
        end
    end
end)

-- Export functions for other resources
exports('GetTicketPrice', function()
    return Config.TicketPrice
end)

exports('GivePlayerTicket', function(playerId)
    if Config.UseQBCore and QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local ticketId = GenerateTicketId()
            local expiresAt = os.time() + (Config.TicketExpireTime * 3600)
            
            local ticketData = {
                ticket_id = ticketId,
                purchased_at = os.time(),
                expires_at = expiresAt,
                price_paid = 0,
                used = false
            }
            
            return Player.Functions.AddItem(Config.TicketItemName, 1, false, ticketData)
        end
    end
    return false
end)

exports('ChargePlayerForTicket', function(playerId, customPrice)
    local price = customPrice or Config.TicketPrice
    
    if Config.UseQBCore and QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local success = false
            
            if Config.PayWithBank then
                success = Player.Functions.RemoveMoney('bank', price, 'metro-ticket-custom')
            else
                success = Player.Functions.RemoveMoney('cash', price, 'metro-ticket-custom')
            end
            
            return success
        end
    end
    return false
end)

exports('GetPlayerTickets', function(playerId)
    if Config.UseQBCore and QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            return Player.Functions.GetItemByName(Config.TicketItemName)
        end
    end
    return nil
end)

-- Optional: Database integration for persistent tickets
--[[
-- Uncomment and modify this section if you want persistent tickets across sessions

RegisterNetEvent('xnl-trains:server:saveTicket', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Save to database or player metadata
    MySQL.Async.execute('INSERT INTO player_metro_tickets (citizenid, expires_at) VALUES (?, ?) ON DUPLICATE KEY UPDATE expires_at = VALUES(expires_at)', {
        citizenid,
        os.time() + (24 * 60 * 60) -- Expires in 24 hours
    })
end)

RegisterNetEvent('xnl-trains:server:checkTicket', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    MySQL.Async.fetchAll('SELECT * FROM player_metro_tickets WHERE citizenid = ? AND expires_at > ?', {
        citizenid,
        os.time()
    }, function(result)
        local hasTicket = #result > 0
        TriggerClientEvent('xnl-trains:client:ticketStatus', src, hasTicket)
    end)
end)
--]]

-- Server-side logging and analytics
local ticketsPurchasedToday = 0

RegisterNetEvent('xnl-trains:server:logTicketPurchase', function()
    ticketsPurchasedToday = ticketsPurchasedToday + 1
    
    if Config.Debug then
        print("^2[XNL-Trains]^7 Total tickets purchased today: " .. ticketsPurchasedToday)
    end
end)

-- Reset daily counter at midnight
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000 * 60) -- Check every hour
        
        local currentHour = tonumber(os.date('%H'))
        if currentHour == 0 then -- Midnight
            ticketsPurchasedToday = 0
            if Config.Debug then
                print("^2[XNL-Trains]^7 Daily ticket counter reset")
            end
        end
    end
end)

-- Export functions for other resources
exports('GetTicketPrice', function()
    return Config.TicketPrice
end)

exports('GivePlayerTicket', function(playerId)
    if Config.UseQBCore and QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            TriggerClientEvent('xnl-trains:client:ticketPurchased', playerId, true)
            return true
        end
    end
    return false
end)

exports('ChargePlayerForTicket', function(playerId, customPrice)
    local price = customPrice or Config.TicketPrice
    
    if Config.UseQBCore and QBCore then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local success = false
            
            if Config.PayWithBank then
                success = Player.Functions.RemoveMoney('bank', price, 'metro-ticket-custom')
            else
                success = Player.Functions.RemoveMoney('cash', price, 'metro-ticket-custom')
            end
            
            return success
        end
    end
    return false
end)