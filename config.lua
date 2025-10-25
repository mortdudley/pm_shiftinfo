Config = {}

Config.Framework = 'QBCore' -- Framework selector: 'ESX' or 'QBCore'

Config.ServerName = ""

Config.AcePerm = "group.admin" -- Permission required to use /shiftinfo command - change "group.admin" to your desired ace permission

-- Optional per-job overrides. If empty, all jobs use DefaultWebhook/Color.
-- Example:
-- Config.ShiftJobs = {
--   police = { label = 'Police', webhook = 'https://discord.com/api/webhooks/...', color = 3447003 },
--   ambulance = { label = 'EMS', webhook = 'https://discord.com/api/webhooks/...', color = 15158332 },
-- }
-- Probably don't use this. Any webhook listed in the config will be exposed to the client
-- meaning any idiot with dev tools can see it and spam it. I will eventually get around to 
-- moving all of this to the server side. I'll probably just create a server config file

Config.ShiftJobs = {}

Config.DiscordBotName = "Shift Logger"
Config.DiscordAvatar = ""