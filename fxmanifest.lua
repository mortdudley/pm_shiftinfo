fx_version 'adamant'

game 'gta5'

description 'PM Shift Info'

author 'Mort Dudley'

version '1.0.0'

server_scripts {
	'server/*.lua'
}

shared_scripts {
	'config.lua'
} 

client_scripts {
	'client/*.lua'
}

files {
    'server/shifts.json'
}