--=============================================================
-- QBCore Integration Settings
--=============================================================
Config = {}

-- QBCore Settings
Config.UseQBCore = true -- Set to false to use original system
Config.QBCoreExport = 'qb-core' -- Your QBCore export name

-- Inventory Settings
Config.UseQBInventory = true -- Use qb-inventory for physical tickets
Config.TicketItemName = 'metro_ticket' -- Item name in qb-core/shared/items.lua
Config.TicketExpireTime = 24 -- Hours until ticket expires (24 = 1 day)

-- Banking Settings
Config.PayWithBank = true -- true = bank account, false = cash
Config.TicketPrice = 25 -- Price for metro ticket
Config.BankAccount = 'bank' -- QBCore bank account type

-- Database Settings
Config.UseDatabase = true -- Store ticket purchases in database
Config.PersistentTickets = true -- Tickets survive server restarts

-- Target Settings
Config.UseQBTarget = true -- Use qb-target for interactions
Config.TargetDistance = 2.0 -- Distance for qb-target interactions

-- Security Settings
Config.AllowEnterTrainWanted = false -- Allow players with wanted level to enter
Config.ReportTerroristOnMetro = true -- Give wanted level for shooting on metro
Config.TerroristWantedLevel = 4 -- Wanted level for shooting on metro
Config.IllegalBoardingWantedLevel = 1 -- Wanted level for boarding without ticket

-- Notification Settings
Config.NotificationType = 'qb' -- 'qb' for QBCore notifications, 'original' for SMS style

-- Debug
Config.Debug = true

-- Language Settings
Config.Language = 'en' 
Config.Message = {}

Config.Message['en'] = {
	['we_warned_you'] = "Police have been notified of your illegal boarding!",
	['no_ticket_leave'] = "You don't have a ticket! Please leave the metro or police will be called.",
	['buyticket'] = "Buy Metro Ticket",
	['buyticket_desc'] = "Purchase a metro ticket for $" .. Config.TicketPrice,
	['use_ticket'] = "Use Metro Ticket",
	['use_ticket_desc'] = "Show your metro ticket to validate entry",
	['los_santos_transit'] = "Los Santos Transit",
	['tourist_information'] = "Tourist Information",
	['already_got_ticket'] = "You already have a valid metro ticket in your inventory!",
	['account_nomoney'] = "You don't have enough money for a metro ticket!",
	['ticket_purchased'] = "Metro ticket purchased and added to your inventory!",
	['ticket_used'] = "Metro ticket validated for travel!",
	['ticket_expired'] = "Your metro ticket has expired!",
	['no_ticket_inventory'] = "You don't have a metro ticket in your inventory!",
	['ticket_already_used'] = "This metro ticket has already been used!",
	['entered_metro'] = "You've exited the metro.",
	['terrorist'] = "Terrorist behavior detected on public transport!",
	['travel_metro'] = "Thank you for traveling with Los Santos Transit!",
	['ticket_required'] = "You need a valid metro ticket to board!",
	['payment_success'] = "Payment successful!",
	['payment_failed'] = "Payment failed - insufficient funds!",
	['inventory_full'] = "Your inventory is full! Cannot give metro ticket.",
}

Config.Message['fr'] = {
	['we_warned_you'] = "La police a été informée de votre embarquement illégal !",
	['no_ticket_leave'] = "Vous n'avez pas de billet ! Veuillez quitter le métro.",
	['buyticket'] = "Acheter un Ticket",
	['buyticket_desc'] = "Acheter un ticket de métro pour $" .. Config.TicketPrice,
	['los_santos_transit'] = "Los Santos Transit",
	['tourist_information'] = "Information Touriste",
	['already_got_ticket'] = "Vous avez déjà un ticket valide !",
	['account_nomoney'] = "Vous n'avez pas assez d'argent !",
	['ticket_purchased'] = "Ticket acheté avec succès !",
	['entered_metro'] = "Vous êtes sorti du métro, votre ticket a été invalidé.",
	['terrorist'] = "Comportement terroriste détecté !",
	['travel_metro'] = "Merci d'avoir voyagé avec Los Santos Transit !",
	['ticket_required'] = "Vous avez besoin d'un ticket !",
	['payment_success'] = "Paiement réussi !",
	['payment_failed'] = "Paiement échoué - fonds insuffisants !",
}

-- Ticket Machine Locations (for qb-target)
Config.TicketMachines = {
    'prop_train_ticket_02',
    'prop_train_ticket_02_tu', 
    'v_serv_tu_statio3_'
}

-- Metro Exit Points (same as original)
Config.MetroExitPoints = {
	{StationId=0, x=230.82389831543, y=-1204.0643310547, z=38.902523040771},
	{StationId=0, x=249.59216308594, y=-1204.7095947266, z=38.92488861084},
	{StationId=0, x=270.33166503906, y=-1204.5366210938, z=38.902912139893},
	{StationId=0, x=285.96697998047, y=-1204.2261962891, z=38.929733276367},
	{StationId=0, x=304.13528442383, y=-1204.3720703125, z=38.892612457275},
	{StationId=1, x=-294.53421020508, y=-353.38571166992, z=10.063089370728},
	{StationId=1, x=-294.96997070313, y=-335.69766235352, z=10.06309223175},
	{StationId=1, x=-294.66772460938, y=-318.29565429688, z=10.063152313232},
	{StationId=1, x=-294.73403930664, y=-303.77200317383, z=10.063160896301},
	{StationId=1, x=-294.84133911133, y=-296.04568481445, z=10.063159942627},
	{StationId=2, x=-795.28063964844, y=-126.3436050415, z=19.950298309326},
	{StationId=2, x=-811.87170410156, y=-136.16409301758, z=19.950319290161},
	{StationId=2, x=-819.25689697266, y=-140.25764465332, z=19.95037651062},
	{StationId=2, x=-826.06652832031, y=-143.90898132324, z=19.95037651062},
	{StationId=2, x=-839.2587890625, y=-151.32421875, z=19.950378417969},
	{StationId=2, x=-844.77874755859, y=-154.31440734863, z=19.950380325317},
	{StationId=3, x=-1366.642578125, y=-440.04803466797, z=15.045327186584},
	{StationId=3, x=-1361.4998779297, y=-446.50497436523, z=15.045324325562},
	{StationId=3, x=-1357.4061279297, y=-453.40963745117, z=15.045320510864},
	{StationId=3, x=-1353.4593505859, y=-461.88238525391, z=15.045323371887},
	{StationId=3, x=-1346.1264648438, y=-474.15142822266, z=15.045383453369},
	{StationId=3, x=-1338.1717529297, y=-488.97756958008, z=15.045383453369},
	{StationId=3, x=-1335.0261230469, y=-493.50796508789, z=15.045380592346},
	{StationId=4, x=-530.67529296875, y=-673.33935546875, z=11.808959960938},
	{StationId=4, x=-517.35559082031, y=-672.76635742188, z=11.808965682983},
	{StationId=4, x=-499.44836425781, y=-673.37664794922, z=11.808973312378},
	{StationId=4, x=-483.1321105957, y=-672.68438720703, z=11.809024810791},
	{StationId=4, x=-468.05545043945, y=-672.74371337891, z=11.80902671814},
	{StationId=5, x=-206.90379333496, y=-1014.9454345703, z=30.138082504272},
	{StationId=5, x=-212.65534973145, y=-1031.6101074219, z=30.208702087402},
	{StationId=5, x=-212.65534973145, y=-1031.6101074219, z=30.208702087402},
	{StationId=5, x=-217.0216217041, y=-1042.4768066406, z=30.573789596558},
	{StationId=5, x=-221.29409790039, y=-1054.5914306641, z=30.13950920105},
	{StationId=6, x=101.89681243896, y=-1714.7589111328, z=30.112174987793},
	{StationId=6, x=113.05246734619, y=-1724.7247314453, z=30.111650466919},
	{StationId=6, x=122.72943878174, y=-1731.7276611328, z=30.54141998291},
	{StationId=6, x=132.55198669434, y=-1739.7276611328, z=30.109527587891},
	{StationId=7, x=-532.24133300781, y=-1263.6896972656, z=26.901586532593},
	{StationId=7, x=-539.62115478516, y=-1280.5207519531, z=26.908163070679},
	{StationId=7, x=-545.18548583984, y=-1290.9525146484, z=26.901586532593},
	{StationId=7, x=-549.92230224609, y=-1302.8682861328, z=26.901605606079},
	{StationId=8, x=-872.75714111328, y=-2289.3198242188, z=-11.732793807983},
	{StationId=8, x=-875.53247070313, y=-2297.67578125, z=-11.732793807983},
	{StationId=8, x=-880.05035400391, y=-2309.1235351563, z=-11.732788085938},
	{StationId=8, x=-883.25482177734, y=-2321.3303222656, z=-11.732738494873},
	{StationId=8, x=-890.087890625, y=-2336.2553710938, z=-11.732738494873},
	{StationId=8, x=-894.92395019531, y=-2350.4128417969, z=-11.732727050781},
	{StationId=9, x=-1062.7882080078, y=-2690.7492675781, z=-7.4116077423096},
	{StationId=9, x=-1071.6839599609, y=-2701.8503417969, z=-7.410071849823},
	{StationId=9, x=-1079.0869140625, y=-2710.7033691406, z=-7.4100732803345},
	{StationId=9, x=-1086.8758544922, y=-2720.0673828125, z=-7.4101362228394},
	{StationId=9, x=-1095.3796386719, y=-2729.8442382813, z=-7.4101347923279},
	{StationId=9, x=-1103.7401123047, y=-2740.369140625, z=-7.4101300239563}
}