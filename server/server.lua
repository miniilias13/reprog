-- Variables
local savedMaps = {}

-- Initialisation de la base de données
MySQL.ready(function()
    -- Création de la table vehicle_maps
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `vehicle_maps` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `name` varchar(50) NOT NULL,
            `identifier` varchar(50) NOT NULL,
            `params` longtext NOT NULL,
            `totalPoints` int(11) NOT NULL DEFAULT '0',
            `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function(success)
        if success then
            print("^2[INFO] Table vehicle_maps vérifiée/créée avec succès^7")
            
            -- Vérification si l'item existe déjà
            MySQL.Async.fetchAll('SELECT * FROM items WHERE name = @name', {
                ['@name'] = 'reprog_box'
            }, function(result)
                if result and #result > 0 then
                    print("^2[INFO] Item reprog_box existe déjà^7")
                else
                    -- Création de l'item s'il n'existe pas
                    MySQL.Async.execute([[
                        INSERT INTO `items` (`name`, `label`, `weight`) 
                        VALUES ('reprog_box', 'Boitier de Reprog', 1)
                    ]], {}, function(insertSuccess)
                        if insertSuccess then
                            print("^2[INFO] Item reprog_box créé avec succès^7")
                        else
                            print("^1[ERROR] Erreur lors de la création de l'item reprog_box^7")
                        end
                    end)
                end
            end)
        else
            print("^1[ERROR] Erreur lors de la vérification/création de la table vehicle_maps^7")
        end
    end)
end)

-- Fonction pour charger les configurations
function LoadSavedMaps()
    MySQL.Async.fetchAll('SELECT * FROM vehicle_maps', {}, function(results)
        if results then
            for _, map in ipairs(results) do
                savedMaps[map.id] = {
                    name = map.name,
                    identifier = map.identifier,
                    params = json.decode(map.params),
                    totalPoints = map.totalPoints,
                    timestamp = map.timestamp
                }
            end
        end
    end)
end

-- Synchronisation des modifications
RegisterNetEvent('vehicleMod:syncModification')
AddEventHandler('vehicleMod:syncModification', function(vehicleNetId, modData, identifier)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if xPlayer and xPlayer.identifier == identifier then
        -- Propager les modifications aux autres clients
        TriggerClientEvent('vehicleMod:applyModification', -1, vehicleNetId, modData, identifier)
    end
end)

RegisterNetEvent('reprog:requestSavedMaps')
AddEventHandler('reprog:requestSavedMaps', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if xPlayer then
        local playerMaps = GetPlayerMaps(xPlayer.identifier)
        TriggerClientEvent('reprog:updateSavedMaps', source, playerMaps)
    end
end)

-- Sauvegarde d'une configuration
RegisterNetEvent('reprog:saveMap')
AddEventHandler('reprog:saveMap', function(data)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then 
        TriggerClientEvent('reprog:saveConfirmation', source, false, "Session invalide")
        return 
    end

    if not data or not data.name or not data.params then
        TriggerClientEvent('reprog:saveConfirmation', source, false, "Données invalides")
        return
    end


    MySQL.Async.insert('INSERT INTO vehicle_maps (name, identifier, params, totalPoints) VALUES (?, ?, ?, ?)', {
        data.name,
        xPlayer.identifier,
        json.encode(data.params),
        data.totalPoints or 0
    }, function(insertId)
        
        if insertId then
            savedMaps[insertId] = {
                name = data.name,
                identifier = xPlayer.identifier,
                params = data.params,
                totalPoints = data.totalPoints,
                timestamp = os.time()
            }
            
            local playerMaps = GetPlayerMaps(xPlayer.identifier)
            TriggerClientEvent('reprog:updateSavedMaps', source, playerMaps)
            TriggerClientEvent('reprog:saveConfirmation', source, true, "Configuration sauvegardée")
        else
            TriggerClientEvent('reprog:saveConfirmation', source, false, "Erreur lors de la sauvegarde")
        end
        
    end)
end)

function GetPlayerMaps(identifier)
    local playerMaps = {}
    for id, map in pairs(savedMaps) do
        if map.identifier == identifier then
            playerMaps[id] = {
                name = map.name,
                params = map.params,
                totalPoints = map.totalPoints or 0
            }
        end
    end
    return playerMaps
end

-- Chargement d'une configuration
RegisterNetEvent('reprog:loadMap')
AddEventHandler('reprog:loadMap', function(mapId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    MySQL.Async.fetchAll('SELECT * FROM vehicle_maps WHERE id = ? AND identifier = ?', {
        mapId,
        xPlayer.identifier
    }, function(results)
        if results and #results > 0 then
            local map = results[1]
            local config = {
                params = json.decode(map.params),
                totalPoints = map.totalPoints
            }
            
            TriggerClientEvent('reprog:loadConfig', source, config)
            TriggerClientEvent('reprog:notification', source, 'Configuration chargée', 'success')
        else
            TriggerClientEvent('reprog:notification', source, 'Configuration introuvable', 'error')
        end
    end)
end)

-- Suppression d'une configuration
RegisterNetEvent('reprog:deleteMap')
AddEventHandler('reprog:deleteMap', function(mapId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end

    MySQL.Async.execute('DELETE FROM vehicle_maps WHERE id = ? AND identifier = ?', {
        mapId,
        xPlayer.identifier
    }, function(rowsChanged)
        if rowsChanged > 0 then
            savedMaps[mapId] = nil
            
            -- Informer le client du succès
            TriggerClientEvent('reprog:deleteSuccess', source)
            
            -- Envoyer la liste mise à jour
            local playerMaps = GetPlayerMaps(xPlayer.identifier)
            TriggerClientEvent('reprog:updateSavedMaps', source, playerMaps)
        else
            TriggerClientEvent('reprog:notification', source, 'Erreur lors de la suppression', 'error')
        end
    end)
end)

-- Récupération des configurations d'un joueur
RegisterNetEvent('reprog:requestMaps')
AddEventHandler('reprog:requestMaps', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if xPlayer then
        local playerMaps = GetPlayerMaps(xPlayer.identifier)
        TriggerClientEvent('reprog:updateSavedMaps', source, playerMaps)
    end
end)

-- Fonction pour récupérer les configurations d'un joueur
function GetPlayerMaps(identifier)
    local playerMaps = {}
    
    MySQL.Async.fetchAll('SELECT * FROM vehicle_maps WHERE identifier = ?', {identifier}, 
        function(results)
            if results then
                for _, map in ipairs(results) do
                    local params = json.decode(map.params)
                    if params then
                        playerMaps[map.id] = {
                            name = map.name,
                            params = params,
                            totalPoints = map.totalPoints,
                            timestamp = map.timestamp
                        }
                    end
                end
            end
        end
    )
    Wait(100) -- Petit délai pour s'assurer que la requête est terminée
    return playerMaps
end

-- Événement de vérification de l'item
ESX.RegisterUsableItem('reprog_box', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        TriggerClientEvent('reprog:checkVehicle', source)
    end
end)
