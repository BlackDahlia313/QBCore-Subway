fx_version 'cerulean'
game 'gta5'

name 'XNL-FiveM-Trains'
description 'Metro/Train system with QBCore integration and physical tickets'
author 'VenomXNL | QBCore integration by Assistant'
version '2.1.0'

-- QBCore resource dependencies
dependencies {
    'qb-core',
    'qb-target',
    'oxmysql'
}

-- Optional dependencies
optional_dependencies {
    'qb-banking',
    'qb-policejob',
    'qb-inventory'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

-- Export functions
exports {
    'GetTicketPrice',
    'GivePlayerTicket', 
    'ChargePlayerForTicket',
    'GetPlayerTickets'
}

lua54 'yes'