
fx_version 'cerulean'
game 'gta5'

author 'Saaytex'
description 'reprog script'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    '@es_extended/locale.lua',
    'server/*.lua'
}

client_scripts {
    '@es_extended/locale.lua',
    'client/*.lua',
    'client/vehicleStats.lua'
}

dependencies {
    'es_extended'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/styles.css',
    'html/script.js'
}
