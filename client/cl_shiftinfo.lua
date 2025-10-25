local currentjob = ""
local initialized = false
local Framework = Config and Config.Framework or 'ESX'
local ESX, QBCore

Citizen.CreateThread(function()
    if Framework == 'ESX' then
        if not ESX then
            ESX = exports['es_extended'] and exports['es_extended']:getSharedObject() or ESX
                if not ESX then
                    pcall(function() TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end) end)
                end
        end
    elseif Framework == 'QBCore' then
        if not QBCore then
            pcall(function() QBCore = exports['qb-core']:GetCoreObject() end)
        end
    end
    TriggerEvent('chat:removeSuggestion', '/shiftinfo')
end)

local function handleJoined(jobName)
    TriggerServerEvent('pm_shifttimer:userjoined', jobName or '')
end

local function onJobChange(newJob)
    if not newJob or not newJob.name then return end
    if currentjob ~= '' and currentjob ~= newJob.name then
        TriggerServerEvent('pm_shifttimer:jobchanged', currentjob, newJob.name, 1)
    elseif currentjob == '' then
        TriggerServerEvent('pm_shifttimer:jobchanged', currentjob, newJob.name, 0)
    end
    currentjob = newJob.name
end

if Framework == 'ESX' then
    RegisterNetEvent('esx:playerLoaded')
    AddEventHandler('esx:playerLoaded', function(xPlayer)
        if initialized then return end
        initialized = true
        local job = xPlayer and xPlayer.job and xPlayer.job.name or (ESX and ESX.GetPlayerData and ESX.GetPlayerData().job and ESX.GetPlayerData().job.name)
        currentjob = job or ''
        handleJoined(currentjob)
    end)

    RegisterNetEvent('esx:setJob')
    AddEventHandler('esx:setJob', function(job)
        onJobChange(job)
    end)
elseif Framework == 'QBCore' then
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
    AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
        if initialized then return end
        initialized = true
        local pdata = QBCore and QBCore.Functions.GetPlayerData and QBCore.Functions.GetPlayerData() or nil
        local jobName = pdata and pdata.job and pdata.job.name or ''
        currentjob = jobName
        handleJoined(currentjob)
    end)

    RegisterNetEvent('QBCore:Client:OnJobUpdate')
    AddEventHandler('QBCore:Client:OnJobUpdate', function(job)
        onJobChange(job)
    end)
end