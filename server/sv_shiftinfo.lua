---@diagnostic disable: missing-parameter

local timers = {}

DefaultWebhook = 'https://discord.com/api/webhooks/...' -- Replace with your default webhook URL
WebhookColor = 3447003

local Framework = Config and Config.Framework or 'ESX'
local ESX, QBCore

if Framework == 'ESX' then
    ESX = ESX or (exports['es_extended'] and exports['es_extended']:getSharedObject()) or ESX
    if not ESX then
        pcall(function() TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end) end)
    end
elseif Framework == 'QBCore' then
    local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok then QBCore = obj end
end

local dcname = Config.DiscordBotName or 'Shift Logger'
local avatar = Config.DiscordAvatar or ''
local shift_Busy = false
local shift_StartDate = os.time({year=2025, month=10, day=25, hour=0, sec=0})

local function ensureJobTable(job)
    if job and timers[job] == nil then
        timers[job] = {}
    end
end

local function trimStr(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function fToUpper(str)
    return (str:gsub("^%l", string.upper))
end

local function sortedByValue(tbl, sortFunction)
    local keys = {}
    for key in pairs(tbl) do table.insert(keys, key) end
    table.sort(keys, function(a, b) return sortFunction(tbl[a], tbl[b]) end)
    return keys
end

local function WriteToJson(identifier, character, time, job, minutes)
    while shift_Busy do
        Citizen.Wait(100)
    end

    shift_Busy = true
    local file = LoadResourceFile(GetCurrentResourceName(), "server/shifts.json")
    local data = file and json.decode(file) or {}

    if not data[character] then
        data[character] = {}
    end

    table.insert(data[character], {time, identifier, job, tostring(minutes)})
    SaveResourceFile(GetCurrentResourceName(), "server/shifts.json", json.encode(data, {indent = true}), -1)
    shift_Busy = false
end

local function getPlayerInfo(src)
    if Framework == 'ESX' then
        local xPlayer = ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(src)
        if not xPlayer then return nil end
        local name = (xPlayer.getName and xPlayer.getName()) or xPlayer.name or GetPlayerName(src)
        local identifier = xPlayer.identifier or GetPlayerIdentifier(src, 0)
        local job = (xPlayer.job and xPlayer.job.name) or 'unemployed'
        return { name = name, identifier = identifier, job = job }
    elseif Framework == 'QBCore' then
        local Player = QBCore and QBCore.Functions.GetPlayer and QBCore.Functions.GetPlayer(src)
        if not Player then return nil end
        local ci = Player.PlayerData and Player.PlayerData.charinfo or {}
        local name = (ci and ci.firstname and ci.lastname) and (ci.firstname .. ' ' .. ci.lastname) or GetPlayerName(src)
        local identifier = (Player.PlayerData and Player.PlayerData.citizenid) or GetPlayerIdentifier(src, 0)
        local job = (Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.name) or 'unemployed'
        return { name = name, identifier = identifier, job = job }
    else
        return { name = GetPlayerName(src), identifier = GetPlayerIdentifier(src, 0), job = 'unknown' }
    end
end

local function fixTime(seconds)
    if seconds < 60 then
        return '1 minute'
    elseif seconds < 3600 then
        return string.format('%d minutes', math.floor(seconds/60))
    else
        return string.format('%d hours %d minutes', math.floor(seconds/3600), math.floor((seconds%3600)/60))
    end
end

local function getDiscordSettingsForJob(job)
    local cfg = Config.ShiftJobs and Config.ShiftJobs[job] or nil
    local webhook = DefaultWebhook or ''
    local color = (cfg and cfg.color) or WebhookColor or 3447003
    local label = (cfg and cfg.label) or fToUpper(job or 'Job')
    return webhook, color, label
end

function DiscordLog(name, message, color, job)
    local webhook, c, _ = getDiscordSettingsForJob(job or 'default')
    local embedColor = color or c or Config.DefaultColor or 3447003
    local connect = {
        {
            ["color"] = embedColor,
            ["title"] = "**".. name .."**",
            ["description"] = message,
            ["footer"] = { ["text"] = Config.ServerName .. " Logs" },
        }
    }
    if webhook and webhook ~= '' then
        PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({username = dcname, embeds = connect, avatar_url = avatar}), { ['Content-Type'] = 'application/json' })
    else
        print('[Shift Timer] No webhook configured, message not sent:', name)
    end
end

RegisterServerEvent("pm_shifttimer:userjoined")
AddEventHandler("pm_shifttimer:userjoined", function(job)
    local src = source
    local info = getPlayerInfo(src)
    if not info then return end
    if job and job ~= '' then
        ensureJobTable(job)
        for i = #timers[job], 1, -1 do
            local l = timers[job][i]
            if l and (l.id == src or l.identifier == info.identifier) then
                table.remove(timers[job], i)
            end
        end
        table.insert(timers[job], { id = src, identifier = info.identifier, name = info.name, time = os.time(), date = os.date("%d/%m/%Y %X") })
    end

    if IsPlayerAceAllowed(src, Config.AcePerm) then
        ensureJobTable('staff')
        for i = #timers['staff'], 1, -1 do
            local l = timers['staff'][i]
            if l and (l.id == src or l.identifier == info.identifier) then
                table.remove(timers['staff'], i)
            end
        end
        table.insert(timers['staff'], { id = src, identifier = info.identifier, name = info.name, time = os.time(), date = os.date("%d/%m/%Y %X") })
    end
end)

RegisterServerEvent("pm_shifttimer:jobchanged")
AddEventHandler("pm_shifttimer:jobchanged", function(old, new, method)
    local src = source
    local info = getPlayerInfo(src)
    if not info then return end

    if old and old ~= '' and timers[old] then
        for i = 1, #timers[old] do
            local entry = timers[old][i]
            if entry and (entry.id == src or entry.identifier == info.identifier) then
                local duration = os.time() - entry.time
                local timetext = fixTime(duration)
                local _, color, label = getDiscordSettingsForJob(old)
                local header = (label .. ' Shift')
                local msg = ("%s ended their shift.\nDate: %s\nDuration: %s"):format(entry.name or info.name, entry.date, timetext)
                DiscordLog(header, msg, color, old)
                WriteToJson(info.identifier, entry.name or info.name, entry.time, old, math.max(1, math.floor(duration/60)))
                table.remove(timers[old], i)
                break
            end
        end
    end

    if new and new ~= '' then
        ensureJobTable(new)
        for i = #timers[new], 1, -1 do
            local l = timers[new][i]
            if l and (l.id == src or l.identifier == info.identifier) then
                table.remove(timers[new], i)
            end
        end
        table.insert(timers[new], { id = src, identifier = info.identifier, name = info.name, time = os.time(), date = os.date("%d/%m/%Y %X") })
    end
end)

AddEventHandler("playerDropped", function(reason)
    local src = source
    local info = getPlayerInfo(src)
    local ended = 0
    for job, list in pairs(timers) do
        for n = #list, 1, -1 do
            local entry = list[n]
            if entry and entry.id == src then
                local duration = os.time() - entry.time
                local timetext = fixTime(duration)
                local _, color, label = getDiscordSettingsForJob(job)
                local header = (label .. ' Shift')
                local msg = ("%s disconnected. Shift ended.\nDate: %s\nDuration: %s\nReason: %s"):format(entry.name or (info and info.name or GetPlayerName(src)), entry.date, timetext, tostring(reason or ''))
                DiscordLog(header, msg, color, job)
                WriteToJson(entry.identifier or (info and info.identifier or GetPlayerIdentifier(src, 0)), entry.name or (info and info.name or GetPlayerName(src)), entry.time, job, math.max(1, math.floor(duration/60)))
                table.remove(list, n)
                ended = ended + 1
            end
        end
    end
end)

Citizen.CreateThread(function()
    DiscordLog("[" .. Config.ServerName .. " Logs]", "Shift logger started!", Config.DefaultColor or 3447003, 'default')
end)

Citizen.CreateThread(function()
    shift_Busy = true
    local file = LoadResourceFile(GetCurrentResourceName(), "server/shifts.json")
    local data = file and json.decode(file) or {}
    local expr = os.time() - ((3600 * 24 * 30) + 1)

    for k, v in pairs(data) do
        local remove = {}
        for i=1, #v, 1 do
            if v[i] and v[i][1] and v[i][1] < expr then
                table.insert(remove, i)
            end
        end
        for i=#remove, 1, -1 do
            local ts = v[remove[i]][1]
            local job = v[remove[i]][3]
            local txt = ('Removed "%s" %s Shift on %s'):format(k, job or '?', os.date('%c', ts or 0))
            print(txt)
            table.remove(data[k], remove[i])
        end
    end

    SaveResourceFile(GetCurrentResourceName(), "server/shifts.json", json.encode(data, {indent = true}), -1)
    shift_Busy = false
end)

RegisterServerEvent("pm_shifttimer:dutyChange")
AddEventHandler("pm_shifttimer:dutyChange", function(job, status)
    local src = source
    local info = getPlayerInfo(src)
    if not job or job == '' then return end
    if not info then return end
    ensureJobTable(job)

    if status == false then
        for i = 1, #timers[job], 1 do
            if timers[job][i].id == src then
                local entry = timers[job][i]
                local duration = os.time() - entry.time
                local timetext = fixTime(duration)
                local _, color, label = getDiscordSettingsForJob(job)
                local header = (label .. ' Shift')
                local msg = ("%s went off duty.\nDate: %s\nDuration: %s"):format(entry.name or info.name, entry.date, timetext)
                DiscordLog(header, msg, color, job)
                WriteToJson(entry.identifier or info.identifier, entry.name or info.name, entry.time, job, math.max(1, math.floor(duration/60)))
                table.remove(timers[job], i)
                return
            end
        end
    elseif status == true then
        for i = #timers[job], 1, -1 do
            local l = timers[job][i]
            if l and (l.id == src or l.identifier == info.identifier) then
                table.remove(timers[job], i)
            end
        end
        table.insert(timers[job], { id = src, identifier = info.identifier, name = info.name, time = os.time(), date = os.date("%d/%m/%Y %X") })
    end
end)

RegisterCommand('shiftinfo', function(source, args)
    if source <= 0 or IsPlayerAceAllowed(source, Config.AcePerm) then
        if #args == 2 and args[1]:lower() == 'staff' then
            local job = 'staff'
            local days = tonumber(args[2]) or 30
            local file = LoadResourceFile(GetCurrentResourceName(), "server/shifts.json")
            local data = file and json.decode(file) or {}
            local since = os.time() - (days * 24 * 3600)
            if since < shift_StartDate then since = shift_StartDate end

            local totals = {}
            for character, entries in pairs(data) do
                local minutes = 0
                for _, e in ipairs(entries) do
                    local ts, _identifier, eJob, mins = e[1], e[2], e[3], tonumber(e[4]) or 0
                    if eJob == job and ts >= since then
                        minutes = minutes + mins
                    end
                end
                if minutes > 0 then
                    totals[trimStr(character)] = minutes
                end
            end

            if next(totals) == nil then
                Notify(source, ("No staff activity in the last %d days."):format(days), 'info')
                return
            end

            local sorted = sortedByValue(totals, function(a,b) return a>b end)
            local lines = {}
            for i, name in ipairs(sorted) do
                if i > 25 then break end
                table.insert(lines, ("%d) %s — %d min"):format(i, name, totals[name]))
            end
            local msg = table.concat(lines, "\n")
            local _, color, _ = getDiscordSettingsForJob(job)
            local title = ("Staff Shifts — last %d days\n%s to %s"):format(days, os.date('%c', since), os.date('%c'))
            DiscordLog(title, msg, color, job)

        elseif #args == 3 and args[1] == 'times' then
            local job = args[2]
            local days = tonumber(args[3]) or 30
            local file = LoadResourceFile(GetCurrentResourceName(), "server/shifts.json")
            local data = file and json.decode(file) or {}
            local since = os.time() - (days * 24 * 3600)
            if since < shift_StartDate then since = shift_StartDate end

            local totals = {}
            for character, entries in pairs(data) do
                local minutes = 0
                for _, e in ipairs(entries) do
                    local ts, _identifier, eJob, mins = e[1], e[2], e[3], tonumber(e[4]) or 0
                    if eJob == job and ts >= since then
                        minutes = minutes + mins
                    end
                end
                if minutes > 0 then
                    totals[trimStr(character)] = minutes
                end
            end

            if next(totals) == nil then
                Notify(source, ('No data for %s in the last %d days.'):format(job, days), 'info')
                return
            end

            local sorted = sortedByValue(totals, function(a,b) return a>b end)
            local lines = {}
            for i, name in ipairs(sorted) do
                if i > 25 then break end
                table.insert(lines, ("%d) %s — %d min"):format(i, name, totals[name]))
            end
            local msg = table.concat(lines, "\n")
            local _, color, label = getDiscordSettingsForJob(job)
            local title = ("%s Shifts — last %d days\n%s to %s"):format(label, days, os.date('%c', since), os.date('%c'))
            DiscordLog(title, msg, color, job)
        elseif #args == 3 then
            local job = args[1]
            local character = args[2]
            local minutes = tonumber(args[3]) or 0
            if minutes < 1 then
                Notify(source, 'Minutes must be >= 1', 'error')
                return
            end

            local file = LoadResourceFile(GetCurrentResourceName(), "server/shifts.json")
            local data = file and json.decode(file) or {}

            if not data[character] then data[character] = {} end
            table.insert(data[character], { os.time(), 'MANUAL', job, tostring(minutes) })
            SaveResourceFile(GetCurrentResourceName(), "server/shifts.json", json.encode(data, {indent = true}), -1)
            Notify(source, ('Added manual shift for %s: %s minutes (%s)'):format(character, minutes, job), 'success')
        else
            Notify(source, 'Usage: /shiftinfo staff <days> OR /shiftinfo times <job> <days> OR /shiftinfo <job> <character> <minutes>', 'error')
        end
    end
end)

function Notify(source, text, ntype)
    local t = ntype or 'inform'
    if type(source) == 'number' and source > 0 then
        if Config.Framework == 'ESX' then
            TriggerClientEvent('esx:showNotification', source, text)
        elseif Config.Framework == 'QBCore' then
            TriggerClientEvent('QBCore:Notify', source, text, t)
        else
            TriggerClientEvent('chat:addMessage', source, { args = { 'Shift Timer', tostring(text) } })
        end
    else
        print(('[Shift Timer][%s] %s'):format(t, tostring(text)))
    end
end
