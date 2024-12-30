-- Variables locales
local isUIOpen = false 
local savedMaps = {}
local baseVehicleStats = {}
local vehicleParamPoints = {}
local activeSmokeFX = {}


-- Fonctions utilitaires
local function ShowNotification(message, type)
    if type == "error" then
        ESX.ShowNotification("~r~" .. message)
    elseif type == "success" then
        ESX.ShowNotification("~g~" .. message)
    else
        ESX.ShowNotification(message)
    end
end

local function getCurrentVehicleStats(vehicle)
    local stats = {}
    if not DoesEntityExist(vehicle) then return stats end

    for paramName, param in pairs(Config.engineParams) do
        local currentValue = GetVehicleHandlingFloat(vehicle, "CHandlingData", param.key)
        local model = GetEntityModel(vehicle)
        local baseValue = baseVehicleStats[model] and baseVehicleStats[model][param.key] or currentValue
        
        stats[paramName] = {
            name = param.description,
            value = currentValue,
            baseValue = baseValue,
            percentChange = currentValue ~= 0 and baseValue ~= 0 
                and ((currentValue - baseValue) / baseValue) * 100 
                or 0
        }
    end
    return stats
end

-- Gestion de l'interface
local function openTuningUI(vehicle)
    if isUIOpen then return end
    
    local xPlayer = ESX.GetPlayerData()
    local identifier = xPlayer.identifier
    
    local vehicleData = {
        params = getCurrentVehicleStats(vehicle),
        temperature = exports[GetCurrentResourceName()]:updateVehicleTemperature(vehicle, identifier),
        reliability = exports[GetCurrentResourceName()]:calculateReliability(vehicle, identifier)
    }
    
    if not baseVehicleStats[GetEntityModel(vehicle)] then
        exports[GetCurrentResourceName()]:saveBaseVehicleStats(vehicle)
    end
    
    isUIOpen = true
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        type = 'showUI',
        vehicleData = vehicleData,
        vehicle = NetworkGetNetworkIdFromEntity(vehicle)
    })
end

local function closeUI()
    if not isUIOpen then return end
    
    isUIOpen = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        type = 'hideUI'
    })
end

-- Gestion des cartographies
local function saveEngineMap(name)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not DoesEntityExist(vehicle) then return false end
    
    local map = {
        params = {},
        vehicleModel = GetEntityModel(vehicle),
        timestamp = GetGameTimer(),
        description = "Cartographie personnalisée"
    }
    
    for paramName, param in pairs(Config.engineParams) do
        map.params[paramName] = GetVehicleHandlingFloat(vehicle, "CHandlingData", param.key)
    end
    
    savedMaps[name] = map
    return true
end

-- Callbacks NUI
RegisterNUICallback('closeUI', function(data, cb)
    closeUI()
    cb('ok')
end)

RegisterNUICallback('applyModifications', function(data, cb)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not vehicle then 
        ShowNotification("Vous devez être dans un véhicule", "error")
        cb({success = false})
        return 
    end

    local xPlayer = ESX.GetPlayerData()
    local identifier = xPlayer.identifier

    -- Vérification des points
    local totalPoints = 0
    for _, level in pairs(data) do
        totalPoints = totalPoints + level
    end

    if totalPoints > Config.maxPoints then
        ShowNotification("Trop de points utilisés", "error")
        cb({success = false})
        return
    end

    -- Application des modifications pour ce joueur spécifique
    local success = exports[GetCurrentResourceName()]:applyPlayerModifications(vehicle, identifier, data)
    
    if success then
        ShowNotification("Modifications appliquées", "success")
        -- Synchronisation avec les autres joueurs
        local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
        TriggerServerEvent("vehicleMod:syncModification", vehicleNetId, data, identifier)
    else
        ShowNotification("Erreur lors de l'application des modifications", "error")
    end

    cb({success = success})
end)

RegisterNUICallback('applyPreset', function(data, cb)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not vehicle then 
        ShowNotification("Vous devez être dans un véhicule", "error")
        cb({success = false})
        return 
    end

    local preset = Config.engineMaps[data.preset]
    if not preset then
        ShowNotification("Preset invalide", "error")
        cb({success = false})
        return
    end

    local xPlayer = ESX.GetPlayerData()
    local identifier = xPlayer.identifier

    -- Créer une copie nettoyée du preset
    local cleanPreset = {}
    for paramName, value in pairs(preset) do
        if Config.engineParams[paramName] then
            cleanPreset[paramName] = tonumber(value) or 0
        end
    end

    local success = exports[GetCurrentResourceName()]:applyPlayerModifications(vehicle, identifier, cleanPreset)
    
    if success then
        ShowNotification("Cartographie " .. (preset.description or "personnalisée") .. " appliquée", "success")
        local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
        TriggerServerEvent("vehicleMod:syncModification", vehicleNetId, cleanPreset, identifier)
    else
        ShowNotification("Erreur lors de l'application du preset", "error")
    end

    cb({success = success})
end)

RegisterNUICallback('saveMap', function(data, cb)
    if not data.name then
        ShowNotification("Nom invalide", "error")
        cb({success = false})
        return
    end

    local success = saveEngineMap(data.name)
    if success then
        ShowNotification("Configuration sauvegardée: " .. data.name, "success")
        SendNUIMessage({
            type = 'updateSavedMaps',
            maps = savedMaps
        })
    else
        ShowNotification("Erreur lors de la sauvegarde", "error")
    end

    cb({success = success})
end)

local function forceReloadBaseStats(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    
    local model = GetEntityModel(vehicle)
    -- Force la réinitialisation des stats de base
    baseVehicleStats[model] = nil
    -- Sauvegarde les nouvelles stats de base
    return exports[GetCurrentResourceName()]:saveBaseVehicleStats(vehicle)
end

-- Événements
RegisterNetEvent('reprog:checkVehicle')
AddEventHandler('reprog:checkVehicle', function()
    local playerPed = PlayerPedId()
    if not IsPedInAnyVehicle(playerPed, false) then
        ShowNotification("Vous devez être dans un véhicule pour utiliser cet objet", "error")
        return
    end
    
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if vehicle and GetPedInVehicleSeat(vehicle, -1) == playerPed then
        
        -- Réinitialiser temporairement le véhicule pour obtenir les vraies stats de base
        local plate = GetVehicleNumberPlateText(vehicle)
        local tempStats = {}
        
        -- Sauvegarder les modifications actuelles
        if vehicleParamPoints[plate] then
            tempStats = vehicleParamPoints[plate]
        end
        
        -- Réinitialiser complètement le véhicule
        exports[GetCurrentResourceName()]:resetToBaseStats(vehicle)
        
        -- Forcer le rechargement des stats de base
        if forceReloadBaseStats(vehicle) then
            
            -- Réappliquer les modifications précédentes si nécessaire
            if tempStats.params then
                for paramName, level in pairs(tempStats.params) do
                    exports[GetCurrentResourceName()]:applyEngineModificationWithImpact(vehicle, paramName, level)
                end
            end
            
            -- Continuer avec l'ouverture de l'interface
            TriggerEvent('reprog:useBox')
            openTuningUI(vehicle)
        else
            ShowNotification("Erreur lors du chargement des stats de base", "error")
        end
    else
        ShowNotification("Vous devez être le conducteur du véhicule", "error")
    end
end)

RegisterNetEvent('vehicleMod:applyModification')
AddEventHandler('vehicleMod:applyModification', function(vehicleNetId, modData, identifier)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if DoesEntityExist(vehicle) then
        exports[GetCurrentResourceName()]:applyPlayerModifications(vehicle, identifier, modData)
    end
end)

RegisterNUICallback('saveConfig', function(data, cb)
    
    -- Déclencher l'événement serveur
    TriggerServerEvent('reprog:saveMap', data)
    
    -- Répondre au client
    cb({
        success = true,
        message = "Données transmises au serveur"
    })
end)

RegisterNUICallback('resetVehicle', function(data, cb)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle then
        -- Réinitialisation complète
        if exports[GetCurrentResourceName()]:resetToBaseStats(vehicle) then
            ShowNotification("Véhicule réinitialisé aux paramètres d'origine", "success")
            
            -- Mise à jour de l'UI
            if isUIOpen then
                SendNUIMessage({
                    type = 'updateStats',
                    temperature = Config.temperature.baseTemp,
                    reliability = 100,
                    points = 0
                })
            end
        else
            ShowNotification("Erreur lors de la réinitialisation", "error")
        end
    end
    cb({})
end)

-- Ajout d'un événement pour confirmer la sauvegarde
RegisterNetEvent('reprog:saveConfirmation')
AddEventHandler('reprog:saveConfirmation', function(success, message)
    SendNUIMessage({
        type = 'saveResult',
        success = success,
        message = message
    })
end)

RegisterNUICallback('requestSavedMaps', function(data, cb)
    TriggerServerEvent('reprog:requestMaps')
    cb({})
end)

RegisterNetEvent('reprog:updateSavedMaps')
AddEventHandler('reprog:updateSavedMaps', function(maps)
    SendNUIMessage({
        type = 'updateSavedMaps',
        maps = maps
    })
end)

RegisterNUICallback('deleteMap', function(data, cb)
    TriggerServerEvent('reprog:deleteMap', data.id)
    cb({})
end)

RegisterNetEvent('reprog:deleteSuccess')
AddEventHandler('reprog:deleteSuccess', function()
    -- Demander une mise à jour des configurations
    TriggerServerEvent('reprog:requestMaps')
end)

RegisterNUICallback('loadMap', function(data, cb)
    if data.id then
        TriggerServerEvent('reprog:loadMap', data.id)
    end
    cb({})
end)

RegisterNetEvent('reprog:loadConfig')
AddEventHandler('reprog:loadConfig', function(config)
    SendNUIMessage({
        type = 'loadConfig',
        config = config
    })
end)

-- Boucles principales
Citizen.CreateThread(function()
    while true do
        Wait(Config.temperature.checkInterval)
        
        local player = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(player, false)
        
        if vehicle and GetPedInVehicleSeat(vehicle, -1) == player then
            local xPlayer = ESX.GetPlayerData()
            local identifier = xPlayer.identifier
            
            -- Mise à jour de la température et de la fiabilité
            local temperature = exports[GetCurrentResourceName()]:updateVehicleTemperature(vehicle, identifier)
            local reliability = exports[GetCurrentResourceName()]:calculateReliability(vehicle, identifier)
            
            -- Effets de température
            if temperature > Config.temperature.damageThreshold then
                -- Dégâts moteur progressifs
                local damageMultiplier = (temperature - Config.temperature.damageThreshold) / 
                    (Config.temperature.maxTemp - Config.temperature.damageThreshold)
                
                SetVehicleEngineHealth(vehicle, 
                    math.max(200, GetVehicleEngineHealth(vehicle) - (damageMultiplier * 5.0)))
                
                -- Ratés moteur à haute température
                if temperature > Config.temperature.damageThreshold + 15 and math.random() < damageMultiplier * 0.8 then
                    SetVehicleEngineOn(vehicle, false, true, true)
                    Wait(math.random(100, 500))
                    SetVehicleEngineOn(vehicle, true, true, false)
                    ShowNotification("Le moteur surchauffe !", "error")
                end
            end
            
            -- Mise à jour de l'UI
            if isUIOpen then
                local mods = exports[GetCurrentResourceName()]:getPlayerModifications(vehicle, identifier)
                local totalPoints = 0
                for _, level in pairs(mods) do
                    totalPoints = totalPoints + level
                end
                
                SendNUIMessage({
                    type = 'updateStats',
                    temperature = temperature,
                    reliability = reliability,
                    points = totalPoints
                })
            end
        end
    end
end)

-- Gestion de la touche ECHAP
Citizen.CreateThread(function()
    while true do
        Wait(0)
        if isUIOpen and IsControlJustReleased(0, 177) then
            closeUI()
        end
    end
end)

-- Nettoyage à l'arrêt de la ressource
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    for plate, effect in pairs(activeSmokeFX) do
        StopParticleFxLooped(effect, 0)
    end
    activeSmokeFX = {}
    RemoveNamedPtfxAsset("core")
    
    if isUIOpen then
        closeUI()
    end
end)
