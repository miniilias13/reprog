--[[
Problème quand on ce connect et qu'on rentre dans une voiture déjà reprog ça fausse les données


]]


-- config.lua
Config = {
    -- Niveaux de tuning
    minLevel = 1,
    maxLevel = 10,
    maxPoints = 50, -- Points disponibles pour les modifications
    
    -- Paramètres des modifications moteur
    engineParams = {
        couple = {
            key = "fDriveInertia",
            baseMultiplier = 0.15,    -- Réduit (était 0.4)
            description = "Couple moteur",
            maxIncrease = 0.3,       -- Réduit (était 0.8)
            linkedParam = "gearRatio",
            linkedImpact = 0.1
        },
        acceleration = {
            key = "fInitialDriveForce",
            baseMultiplier = 0.2,     -- Réduit (était 0.5)
            description = "Accélération",
            maxIncrease = 0.4,       -- Réduit (était 1.0)
            linkedParam = "vitesseMax",
            linkedImpact = 0.05
        },
        vitesseMax = {
            key = "fInitialDriveMaxFlatVel",
            baseMultiplier = 0.1,     -- Réduit (était 0.3)
            description = "Vitesse maximale",
            maxIncrease = 0.25,      -- Réduit (était 0.6)
            linkedParam = "engineBraking",
            linkedImpact = 0.1
        },
        rpmMin = {
            key = "fLowSpeedTractionLossMult",
            baseMultiplier = 0.05,    -- Réduit (était 0.15)
            description = "Régime minimal",
            maxIncrease = 0.2,       -- Réduit (était 0.4)
            linkedParam = "rpmMax",
            linkedImpact = 0.05
        },
        rpmMax = {
            key = "fClutchChangeRateScaleUpShift",
            baseMultiplier = 0.08,    -- Réduit (était 0.2)
            description = "Régime maximal",
            maxIncrease = 0.2,       -- Réduit (était 0.5)
            linkedParam = "rpmMin",
            linkedImpact = 0.05
        },
        gearRatio = {
            key = "fClutchChangeRateScaleDownShift",
            baseMultiplier = 0.08,    -- Réduit (était 0.2)
            description = "Rapport de boîte",
            maxIncrease = 0.2,       -- Réduit (était 0.5)
            linkedParam = "couple",
            linkedImpact = 0.1
        },
        engineBraking = {
            key = "fBrakeForce",
            baseMultiplier = 0.1,     -- Réduit (était 0.25)
            description = "Frein moteur",
            maxIncrease = 0.3,       -- Réduit (était 0.6)
            linkedParam = "vitesseMax",
            linkedImpact = 0.05
        }
    },
    
    -- Ajustons aussi les presets pour qu'ils soient plus impactants
    engineMaps = {
        eco = {
            couple = 4,              -- Réduit (était 6)
            acceleration = 3,        -- Réduit (était 5)
            vitesseMax = 3,         -- Réduit (était 4)
            rpmMin = 5,             -- Réduit (était 7)
            rpmMax = 3,             -- Réduit (était 4)
            gearRatio = 4,          -- Réduit (était 6)
            engineBraking = 6,      -- Réduit (était 8)
            description = "Cartographie Économique",
            totalPoints = 28        -- Réduit (était 40)
        },
        sport = {
            couple = 6,             -- Réduit (était 8)
            acceleration = 6,       -- Réduit (était 8)
            vitesseMax = 6,        -- Réduit (était 8)
            rpmMin = 4,            -- Réduit (était 6)
            rpmMax = 5,            -- Réduit (était 7)
            gearRatio = 5,         -- Réduit (était 7)
            engineBraking = 4,     -- Réduit (était 6)
            description = "Cartographie Sport",
            totalPoints = 36       -- Réduit (était 45)
        },
        racing = {
            couple = 8,            -- Réduit (était 10)
            acceleration = 8,      -- Réduit (était 10)
            vitesseMax = 8,       -- Réduit (était 10)
            rpmMin = 6,           -- Réduit (était 8)
            rpmMax = 7,           -- Réduit (était 9)
            gearRatio = 7,        -- Réduit (était 9)
            engineBraking = 3,    -- Réduit (était 4)
            description = "Cartographie Course",
            totalPoints = 47      -- Réduit (était 50)
        }
    },

    -- Paramètres de fiabilité
    reliability = {
        threshold = 30,
        baseDecrease = 4.5,
        minReliability = 10,
    },

    temperature = {
        baseTemp = 90,
        maxTemp = 130,
        cooldownRate = 0.8,
        heatupRate = 0.1,
        checkInterval = 1000,
        damageThreshold = 115,
    }
}
