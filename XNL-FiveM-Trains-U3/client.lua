-- QBCore Metro Train System
-- Enhanced with QBCore, qb-target, and qb-banking integration

local QBCore = nil
local PlayerData = {}
local isLoggedIn = false

-- Player state variables
local IsPlayerInMetro = false
local PlayerHasMetroTicket = false
local PlayerDetectedInMetro = false
local UnpaidPassenger = 0
local CurrentTicketInfo = nil -- Stores current ticket data

-- Initialize QBCore
if Config.UseQBCore then
    Citizen.CreateThread(function()
        while QBCore == nil do
            TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)
            Citizen.Wait(200)
        end
        
        while not isLoggedIn do
            Citizen.Wait(1000)
        end
        
        PlayerData = QBCore.Functions.GetPlayerData()
    end)

    -- QBCore Events
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        isLoggedIn = true
        PlayerData = QBCore.Functions.GetPlayerData()
    end)

    RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
        isLoggedIn = false
        PlayerData = {}
    end)

    RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
        PlayerData = val
    end)
end

-- Initialize train system
Citizen.CreateThread(function()
    -- Enable train tracks and spawning
    SwitchTrainTrack(0, true) -- Main train tracks
    SwitchTrainTrack(3, true) -- Metro tracks
    SetTrainTrackSpawnFrequency(0, 120000) -- Train spawn frequency
    SetTrainTrackSpawnFrequency(3, 120000) -- Metro spawn frequency
    SetRandomTrains(true)
    SetTrainsForceDoorsOpen(false)
    
    if Config.Debug then
        print("^2[XNL-Trains]^7 Train system initialized")
    end
end)

-- Setup qb-target interactions for ticket machines
Citizen.CreateThread(function()
    if not Config.UseQBTarget then return end
    
    Wait(1000) -- Wait for qb-target to load
    
    for _, model in pairs(Config.TicketMachines) do
        exports['qb-target']:AddTargetModel(model, {
            options = {
                {
                    type = "client",
                    event = "xnl-trains:client:buyTicket",
                    icon = "fas fa-ticket-alt",
                    label = Config.Message[Config.Language]['buyticket'],
                },
            },
            distance = Config.TargetDistance
        })
    end
    
    if Config.Debug then
        print("^2[XNL-Trains]^7 qb-target interactions registered")
    end
end)

-- Buy ticket event (triggered by qb-target)
RegisterNetEvent('xnl-trains:client:buyTicket', function()
    if Config.UseQBInventory then
        -- Check if player already has a ticket in inventory
        QBCore.Functions.TriggerCallback('xnl-trains:server:hasTicket', function(hasTicket, ticketData)
            if hasTicket then
                if ticketData and ticketData.info and ticketData.info.expires_at then
                    local currentTime = os.time()
                    if currentTime > ticketData.info.expires_at then
                        ShowNotification(Config.Message[Config.Language]['ticket_expired'], 'error')
                        -- Remove expired ticket
                        TriggerServerEvent('xnl-trains:server:removeExpiredTicket')
                        return
                    end
                end
                ShowNotification(Config.Message[Config.Language]['already_got_ticket'], 'error')
                return
            end
            
            -- Proceed with purchase
            TriggerServerEvent('xnl-trains:server:buyTicket')
        end)
    else
        -- Original system fallback
        if PlayerHasMetroTicket then
            ShowNotification(Config.Message[Config.Language]['already_got_ticket'], 'error')
            return
        end
        
        TriggerServerEvent('xnl-trains:server:buyTicket')
    end
end)

-- Use ticket event (for inventory item)
RegisterNetEvent('xnl-trains:client:useTicket', function(item)
    if not item or not item.info then
        ShowNotification(Config.Message[Config.Language]['ticket_expired'], 'error')
        return
    end
    
    local currentTime = os.time()
    
    -- Check if ticket is expired
    if item.info.expires_at and currentTime > item.info.expires_at then
        ShowNotification(Config.Message[Config.Language]['ticket_expired'], 'error')
        TriggerServerEvent('xnl-trains:server:removeExpiredTicket')
        return
    end
    
    -- Check if ticket is already used
    if item.info.used then
        ShowNotification(Config.Message[Config.Language]['ticket_already_used'], 'error')
        return
    end
    
    -- Validate ticket and mark as active
    PlayerHasMetroTicket = true
    CurrentTicketInfo = item.info
    ShowNotification(Config.Message[Config.Language]['ticket_used'], 'success')
    
    -- Update ticket as used in database
    TriggerServerEvent('xnl-trains:server:useTicket', item.info.ticket_id)
end)

-- Ticket purchase response
RegisterNetEvent('xnl-trains:client:ticketPurchased', function(success, ticketData)
    if success then
        if Config.UseQBInventory then
            PlayTicketMachineAnimation()
            ShowNotification(Config.Message[Config.Language]['ticket_purchased'], 'success')
            -- Ticket is automatically added to inventory by server
        else
            PlayerHasMetroTicket = true
            PlayTicketMachineAnimation()
            ShowNotification(Config.Message[Config.Language]['ticket_purchased'], 'success')
        end
    else
        ShowNotification(Config.Message[Config.Language]['account_nomoney'], 'error')
    end
end)

-- Inventory full notification
RegisterNetEvent('xnl-trains:client:inventoryFull', function()
    ShowNotification(Config.Message[Config.Language]['inventory_full'], 'error')
end)

-- Play ticket machine animation
function PlayTicketMachineAnimation()
    local playerPed = PlayerPedId()
    local animDict = "mini@atmenter"
    
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(1)
    end
    
    TaskPlayAnim(playerPed, animDict, "enter", 8.0, 1.0, 3000, 0, 0.0, 0, 0, 0)
    RemoveAnimDict(animDict)
    
    -- Play ATM sound
    Citizen.SetTimeout(2000, function()
        PlaySoundFrontend(-1, "ATM_WINDOW", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    end)
end

-- Metro detection and validation system
Citizen.CreateThread(function()
    while true do
        Wait(3000) -- Check every 3 seconds
        
        if IsPedOnVehicle(PlayerPedId()) then
            local coordA = GetEntityCoords(PlayerPedId(), 1)
            local coordB = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 0.0, -1.0)
            local metro = GetVehicleInDirection(coordA, coordB)
            
            if DoesEntityExist(metro) and GetEntityModel(metro) == GetHashKey("metrotrain") then
                if not PlayerDetectedInMetro then
                    PlayerDetectedInMetro = true
                    
                    -- Check for valid ticket when boarding
                    if Config.UseQBInventory then
                        QBCore.Functions.TriggerCallback('xnl-trains:server:hasValidTicket', function(hasValidTicket)
                            if hasValidTicket then
                                PlayerHasMetroTicket = true
                                ShowNotification(Config.Message[Config.Language]['travel_metro'], 'success')
                            else
                                PlayerHasMetroTicket = false
                                HandleIllegalBoarding()
                            end
                        end)
                    else
                        if PlayerHasMetroTicket then
                            ShowNotification(Config.Message[Config.Language]['travel_metro'], 'success')
                        else
                            HandleIllegalBoarding()
                        end
                    end
                end
                
                -- Handle passengers without tickets
                if not PlayerHasMetroTicket then
                    UnpaidPassenger = UnpaidPassenger + 1
                    
                    if UnpaidPassenger == 1 then
                        ShowNotification(Config.Message[Config.Language]['no_ticket_leave'], 'error')
                    elseif UnpaidPassenger >= 3 then
                        if UnpaidPassenger == 3 then
                            ShowNotification(Config.Message[Config.Language]['we_warned_you'], 'error')
                        end
                        
                        -- Give wanted level for illegal boarding
                        if Config.UseQBCore and QBCore then
                            TriggerServerEvent('police:server:policeAlert', 'Metro fare evasion reported')
                        else
                            SetPlayerWantedLevel(PlayerId(), Config.IllegalBoardingWantedLevel, 0)
                            SetPlayerWantedLevelNow(PlayerId(), 0)
                        end
                    end
                end
            end
        else
            -- Player exited metro
            if PlayerDetectedInMetro then
                PlayerDetectedInMetro = false
                UnpaidPassenger = 0
                
                if PlayerHasMetroTicket then
                    if Config.UseQBInventory then
                        -- Remove used ticket from inventory when exiting
                        if CurrentTicketInfo and CurrentTicketInfo.ticket_id then
                            TriggerServerEvent('xnl-trains:server:removeUsedTicket', CurrentTicketInfo.ticket_id)
                            CurrentTicketInfo = nil
                        end
                    end
                    PlayerHasMetroTicket = false
                    ShowNotification(Config.Message[Config.Language]['entered_metro'], 'primary')
                end
            end
        end
    end
end)

-- Terrorist detection system
Citizen.CreateThread(function()
    while true do
        Wait(100)
        
        if PlayerDetectedInMetro and Config.ReportTerroristOnMetro then
            if IsPedShooting(PlayerPedId()) then
                ShowNotification(Config.Message[Config.Language]['terrorist'], 'error')
                
                if Config.UseQBCore and QBCore then
                    TriggerServerEvent('police:server:policeAlert', 'Shots fired on metro - terrorist activity')
                else
                    SetPlayerWantedLevel(PlayerId(), Config.TerroristWantedLevel, 0)
                    SetPlayerWantedLevelNow(PlayerId(), 0)
                end
            end
        end
    end
end)

-- Utility function to get vehicle in direction (raycast)
function GetVehicleInDirection(coordFrom, coordTo)
    local rayHandle = CastRayPointToPoint(coordFrom.x, coordFrom.y, coordFrom.z, coordTo.x, coordTo.y, coordTo.z, 10, PlayerPedId(), 0)
    local _, _, _, _, vehicle = GetRaycastResult(rayHandle)
    return vehicle
end

-- Handle illegal boarding
function HandleIllegalBoarding()
    if not Config.AllowEnterTrainWanted then
        if Config.UseQBCore and QBCore then
            -- Check if player has active wanted level through QBCore
            if PlayerData.metadata and PlayerData.metadata.ishandcuffed then
                ShowNotification("You cannot board the metro while wanted!", 'error')
                return
            end
        else
            if GetPlayerWantedLevel(PlayerId()) > 0 then
                ShowNotification("You cannot board the metro while wanted!", 'error')
                return
            end
        end
    end
    
    ShowNotification(Config.Message[Config.Language]['ticket_required'], 'error')
end

-- Notification system
function ShowNotification(message, type)
    if Config.UseQBCore and QBCore then
        if Config.NotificationType == 'qb' then
            QBCore.Functions.Notify(message, type)
        else
            -- Use original SMS style notifications
            SetNotificationTextEntry("STRING")
            AddTextComponentString(message)
            SetNotificationBackgroundColor(140)
            SetNotificationMessage("CHAR_LS_TOURIST_BOARD", "CHAR_LS_TOURIST_BOARD", true, 4, Config.Message[Config.Language]['los_santos_transit'], Config.Message[Config.Language]['tourist_information'], message)
            DrawNotification(false, true)
            PlaySoundFrontend(GetSoundId(), "Text_Arrive_Tone", "Phone_SoundSet_Default", true)
        end
    else
        -- Fallback notification system
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if Config.UseQBTarget then
            for _, model in pairs(Config.TicketMachines) do
                exports['qb-target']:RemoveTargetModel(model)
            end
        end
    end
end)

-- Debug commands
if Config.Debug then
    RegisterCommand('xnl_giveticket', function()
        PlayerHasMetroTicket = true
        ShowNotification("Debug: Metro ticket given", 'success')
    end, false)
    
    RegisterCommand('xnl_removeticket', function()
        PlayerHasMetroTicket = false
        ShowNotification("Debug: Metro ticket removed", 'error')
    end, false)
    
    RegisterCommand('xnl_checkmoney', function()
        if Config.UseQBCore and QBCore then
            local Player = QBCore.Functions.GetPlayerData()
            local cash = Player.money.cash or 0
            local bank = Player.money.bank or 0
            print("^3[DEBUG] Cash: $" .. cash .. " | Bank: $" .. bank)
        end
    end, false)
end