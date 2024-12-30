-- Variables pour le suivi des modifications par joueur
local playerVehicleModifications = {}
local vehicleBaseStats = {}
local vehicleTemperatures = {}
local activeSmokeFX = {}

-- Fonction pour générer une clé unique pour le suivi des modifications
local function getVehiclePlayerKey(vehicle, identifier)
    local plate = GetVehicleNumberPlateText(vehicle)
    return string.format("%s_%s", plate, identifier)
end

local function manageEngineSmoke(vehicle, temperature)
    if not DoesEntityExist(vehicle) then return end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    
    -- Fumée si température > 110°C
    if temperature > 110 and not activeSmokeFX[plate] then
        if not HasNamedPtfxAssetLoaded("core") then
            RequestNamedPtfxAsset("core")
            while not HasNamedPtfxAssetLoaded("core") do
                Wait(1)
            end
        end
        
        SetPtfxAssetNextCall("core")
        local smokeEffect = StartParticleFxLoopedOnEntity(
            "exp_grd_bzgas_smoke",
            vehicle,
            0.0, 2.5, 0.0,  -- Position à l'avant du véhicule
            0.0, 0.0, 0.0,  -- Rotation
            0.5,            -- Taille fixe
            false, false, false
        )
        activeSmokeFX[plate] = smokeEffect
        
    -- Arrêt de la fumée si température < 110°C
    elseif temperature <= 110 and activeSmokeFX[plate] then
        StopParticleFxLooped(activeSmokeFX[plate], 0)
        activeSmokeFX[plate] = nil
        RemoveNamedPtfxAsset("core")
    end
end

-- Calcul de la fiabilité basé sur les points utilisés
local function calculateReliability(vehicle, identifier)
    if not DoesEntityExist(vehicle) then return 100 end
    
    local key = getVehiclePlayerKey(vehicle, identifier)
    local mods = playerVehicleModifications[key]
    if not mods then 
        return 100 
    end
    
    local totalPoints = 0
    for paramName, level in pairs(mods) do
        if type(level) == "number" then
            totalPoints = totalPoints + level
        end
    end
    
    if totalPoints <= Config.reliability.threshold then
        return 100
    end
    
    local pointsOverThreshold = totalPoints - Config.reliability.threshold
    local reliabilityDecrease = pointsOverThreshold * Config.reliability.baseDecrease
    local finalReliability = math.max(Config.reliability.minReliability, 100 - reliabilityDecrease)
    
    return finalReliability
end

-- Fonction de mise à jour de la température
local function updateVehicleTemperature(vehicle, identifier)
    if not DoesEntityExist(vehicle) then return Config.temperature.baseTemp end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    if not vehicleTemperatures[plate] then
        vehicleTemperatures[plate] = Config.temperature.baseTemp
    end
    
    local key = getVehiclePlayerKey(vehicle, identifier)
    local mods = playerVehicleModifications[key]
    
    
    local totalPoints = 0
    for paramName, level in pairs(mods or {}) do
        if type(level) == "number" then
            totalPoints = totalPoints + level
        end
    end
    
    local currentTemp = vehicleTemperatures[plate]
    local speed = GetEntitySpeed(vehicle) * 3.6
    
    if totalPoints > Config.reliability.threshold then
        local extraPoints = totalPoints - Config.reliability.threshold
        local tempIncrease = extraPoints * Config.temperature.heatupRate
        
        if speed > 60 then
            tempIncrease = tempIncrease * (1 + (speed - 60) / 100)
        end
        
        currentTemp = currentTemp + tempIncrease
    end
    
    -- Refroidissement
    local cooling = 0
    local isEngineRunning = GetIsVehicleEngineRunning(vehicle)

    -- Si le moteur est éteint ou le véhicule à l'arrêt, refroidissement plus rapide
    if not isEngineRunning or speed < 0.5 then
        cooling = Config.temperature.cooldownRate * 5  -- Refroidissement 5x plus rapide à l'arrêt
    elseif speed < 30 then
        cooling = Config.temperature.cooldownRate * 1.5
    else
        cooling = Config.temperature.cooldownRate
    end

    -- Refroidissement plus rapide si la température est très élevée
    if currentTemp > Config.temperature.damageThreshold then
        cooling = cooling * 1.5  -- 50% de refroidissement supplémentaire si surchauffe
    end

    currentTemp = math.max(Config.temperature.baseTemp,
        currentTemp - cooling)
    
    vehicleTemperatures[plate] = currentTemp

    -- Gestion de la fumée basée sur la température
    manageEngineSmoke(vehicle, currentTemp)

    return currentTemp
end

-- Sauvegarde des stats de base améliorée
local function saveBaseVehicleStats(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    
    local model = GetEntityModel(vehicle)
    if not vehicleBaseStats[model] then
        vehicleBaseStats[model] = {}
        for paramName, param in pairs(Config.engineParams) do
            local value = GetVehicleHandlingFloat(vehicle, "CHandlingData", param.key)
            if value and value ~= 0 then
                vehicleBaseStats[model][param.key] = value
            else
                vehicleBaseStats[model][param.key] = param.defaultValue or 1.0
            end
        end
    end
    return vehicleBaseStats[model]
end

-- Réinitialisation améliorée des stats d'un véhicule
local function resetToBaseStats(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    
    local model = GetEntityModel(vehicle)
    local baseStats = vehicleBaseStats[model]
    
    if not baseStats then
        baseStats = saveBaseVehicleStats(vehicle)
        if not baseStats then return false end
    end
    
    for paramName, param in pairs(Config.engineParams) do
        if baseStats[param.key] then
            SetVehicleHandlingFloat(vehicle, "CHandlingData", param.key, baseStats[param.key])
        end
    end
    
    SetVehicleEnginePowerMultiplier(vehicle, 1.0)
    ModifyVehicleTopSpeed(vehicle, 1.0)
    
    return true
end

-- Fonction pour appliquer les modifications pour un joueur spécifique
local function applyPlayerModifications(vehicle, identifier, modifications)
    if not DoesEntityExist(vehicle) then return false end
    
    resetToBaseStats(vehicle)
    
    -- Initialisation du total des points
    local totalPoints = 0
    
    for paramName, level in pairs(modifications) do
        -- Ignorer les champs non numériques et les descriptions
        if Config.engineParams[paramName] and type(level) ~= "string" then
            local param = Config.engineParams[paramName]
            local model = GetEntityModel(vehicle)
            local baseValue = vehicleBaseStats[model][param.key]
            
            -- Conversion explicite en nombre
            level = tonumber(level) or 0
            totalPoints = totalPoints + level
            
            local modifier = math.min((level * level * param.baseMultiplier), param.maxIncrease * 2)
            local newValue = baseValue * (1 + modifier)
            
            SetVehicleHandlingFloat(vehicle, "CHandlingData", param.key, newValue)
            
            if paramName == "acceleration" then
                ModifyVehicleTopSpeed(vehicle, 1.0 + (level * 0.1))
                SetVehicleEnginePowerMultiplier(vehicle, 1.0 + (level * 0.15))
            elseif paramName == "vitesseMax" then
                ModifyVehicleTopSpeed(vehicle, 1.0 + (level * 0.12))
            elseif paramName == "couple" then
                SetVehicleEnginePowerMultiplier(vehicle, 1.0 + (level * 0.2))
            end
        end
    end
    
    local key = getVehiclePlayerKey(vehicle, identifier)
    playerVehicleModifications[key] = modifications
    
    -- Mise à jour immédiate des statistiques
    local temperature = updateVehicleTemperature(vehicle, identifier)
    local reliability = calculateReliability(vehicle, identifier)
    
    if isUIOpen then
        SendNUIMessage({
            type = 'updateStats',
            temperature = temperature,
            reliability = reliability,
            points = totalPoints
        })
    end
    
    return true
end

-- Fonction pour obtenir les modifications actuelles d'un joueur
local function getPlayerModifications(vehicle, identifier)
    local key = getVehiclePlayerKey(vehicle, identifier)
    return playerVehicleModifications[key] or {}
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Nettoyage des effets de fumée
    for plate, effect in pairs(activeSmokeFX) do
        StopParticleFxLooped(effect, 0)
    end
    activeSmokeFX = {}
    RemoveNamedPtfxAsset("core")
end)

-- Export des fonctions
exports('getVehiclePlayerKey', getVehiclePlayerKey)
exports('saveBaseVehicleStats', saveBaseVehicleStats)
exports('resetToBaseStats', resetToBaseStats)
exports('applyPlayerModifications', applyPlayerModifications)
exports('getPlayerModifications', getPlayerModifications)
exports('calculateReliability', calculateReliability)
exports('updateVehicleTemperature', updateVehicleTemperature)
