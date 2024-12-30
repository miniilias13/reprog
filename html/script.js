
// Variables globales
let currentVehicle = null;
let totalPoints = 0;

// Initialisation
document.addEventListener('DOMContentLoaded', () => {
    initializeTabs();
    initializeSliders();
    initializePresets();
    setupButtons();
    setupCloseHandlers();
});

// Gestion des onglets
function initializeTabs() {
    const tabs = document.querySelectorAll('.tab-btn');
    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            tabs.forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(content => 
                content.classList.remove('active'));
            
            tab.classList.add('active');
            const targetId = tab.getAttribute('data-tab');
            document.getElementById(targetId).classList.add('active');
        });
    });
}

// Gestion des sliders et points
function initializeSliders() {
    document.querySelectorAll('.slider').forEach(slider => {
        slider.addEventListener('input', (e) => {
            const value = e.target.value;
            e.target.closest('.slider-container').querySelector('.value').textContent = value;
            updateAllPointsDisplays();
        });
    });
}

function updateAllPointsDisplays() {
    totalPoints = calculateTotalPoints();
    
    // Mise à jour du compteur principal
    document.querySelectorAll('.points-display').forEach(display => {
        display.textContent = `${totalPoints}/50`;
    });

    // Mise à jour du compteur dans la page Manuel
    const pointsValue = document.querySelector('.points-counter .points-value');
    if (pointsValue) {
        pointsValue.textContent = totalPoints;
        const container = pointsValue.closest('.points-counter');
        if (container) {
            container.classList.toggle('exceeded', totalPoints > 50);
        }
    }

    // Message d'avertissement si dépassement
    if (totalPoints > 50) {
        showNotification('Attention : Points maximum dépassés', 'warning');
    }
}

function calculateTotalPoints() {
    return Array.from(document.querySelectorAll('.slider'))
        .reduce((sum, slider) => sum + parseInt(slider.value || 0), 0);
}

// Gestion des presets
function initializePresets() {
    document.querySelectorAll('.preset-card').forEach(card => {
        card.addEventListener('click', async () => {
            const preset = card.dataset.preset;
            try {
                card.classList.add('loading');
                const response = await fetch(`https://${GetParentResourceName()}/applyPreset`, {
                    method: 'POST',
                    body: JSON.stringify({ preset })
                });

                const result = await response.json();
                if (result.success) {
                    showNotification(`Preset ${preset} appliqué`, 'success');
                    if (result.config) {
                        updateSlidersFromConfig(result.config);
                        // Basculer sur l'onglet Manuel pour voir les changements
                        document.querySelector('.tab-btn[data-tab="manual"]').click();
                    }
                }
            } catch (error) {
                showNotification('Erreur d\'application du preset', 'error');
            } finally {
                card.classList.remove('loading');
            }
        });
    });
}

function updateSlidersFromConfig(config) {
    Object.entries(config).forEach(([param, value]) => {
        const slider = document.querySelector(`.slider[data-param="${param}"]`);
        if (slider) {
            slider.value = value;
            slider.closest('.slider-container').querySelector('.value').textContent = value;
        }
    });
    updateAllPointsDisplays();
}

// Configuration des boutons
function setupButtons() {
    setupApplyButton();
    setupSaveButton();
    
    // Bouton reset
    const resetBtn = document.querySelector('.reset-btn');
    resetBtn?.addEventListener('click', () => {
        $.post(`https://${GetParentResourceName()}/resetVehicle`, JSON.stringify({}));
        // Remettre tous les sliders à 0
        document.querySelectorAll('.slider').forEach(slider => {
            slider.value = 0;
            slider.closest('.slider-container').querySelector('.value').textContent = '0';
        });
        updateAllPointsDisplays();
    });
}

function setupApplyButton() {
    const applyBtn = document.querySelector('.apply-btn');
    applyBtn?.addEventListener('click', async () => {
        if (totalPoints > 50) {
            showNotification('Impossible d\'appliquer : trop de points utilisés', 'error');
            return;
        }

        const modifications = getCurrentConfig();
        try {
            applyBtn.classList.add('loading');
            const response = await fetch(`https://${GetParentResourceName()}/applyModifications`, {
                method: 'POST',
                body: JSON.stringify(modifications)
            });

            const result = await response.json();
            if (result.success) {
                showNotification('Modifications appliquées', 'success');
                applyBtn.classList.add('success');
            }
        } catch (error) {
            showNotification('Erreur d\'application', 'error');
            applyBtn.classList.add('error');
        } finally {
            setTimeout(() => {
                applyBtn.classList.remove('loading', 'success', 'error');
            }, 1000);
        }
    });
}

function setupSaveButton() {
    const saveBtn = document.querySelector('.save-btn');
    const nameInput = document.querySelector('.save-config input');
    
    saveBtn?.addEventListener('click', () => {
        const name = nameInput.value.trim();
        if (!name) {
            showNotification('Entrez un nom pour la configuration', 'error');
            nameInput.classList.add('error');
            setTimeout(() => nameInput.classList.remove('error'), 1000);
            return;
        }

        const saveData = {
            name: name,
            params: getCurrentConfig(),
            totalPoints: calculateTotalPoints()
        };


        $.post('https://' + GetParentResourceName() + '/saveConfig', JSON.stringify(saveData))
        .done(function(response) {
            if (response.success) {
                showNotification('Configuration sauvegardée', 'success');
                nameInput.value = '';
            } else {
                showNotification('Erreur lors de la sauvegarde', 'error');
            }
        })
        .fail(function(error) {
            console.error('Erreur lors de la requête:', error);
            showNotification('Erreur lors de la sauvegarde', 'error');
        });
    });
}

function getCurrentConfig() {
    const config = {};
    document.querySelectorAll('.slider').forEach(slider => {
        config[slider.dataset.param] = parseInt(slider.value || 0);
    });
    return config;
}

// Mise à jour des jauges
function updateTemperatureGauge(temp) {
    const gauge = document.querySelector('.temperature .gauge-fill');
    const value = document.querySelector('.temperature .value');
    
    if (!gauge || !value) {
        console.error('Éléments température non trouvés:', {
            gauge: !!gauge,
            value: !!value
        });
        return;
    }
    
    const percentage = ((temp - 90) / (130 - 90)) * 100;
    
    gauge.style.width = `${Math.min(100, Math.max(0, percentage))}%`;
    value.textContent = `${Math.round(temp)}°C`;
    
    if (temp > 115) {
        gauge.style.background = 'var(--danger-color)';
    } else if (temp > 100) {
        gauge.style.background = 'var(--warning-color)';
    } else {
        gauge.style.background = 'var(--primary-color)';
    }
}

function updateReliabilityGauge(reliability) {
    const gauge = document.querySelector('.reliability .gauge-fill');
    const value = document.querySelector('.reliability .value');
    
    if (!gauge || !value) {
        console.error('Éléments fiabilité non trouvés:', {
            gauge: !!gauge,
            value: !!value
        });
        return;
    }
    
    gauge.style.width = `${reliability}%`;
    value.textContent = `${Math.round(reliability)}%`;
    
    if (reliability < 30) {
        gauge.style.background = 'var(--danger-color)';
    } else if (reliability < 70) {
        gauge.style.background = 'var(--warning-color)';
    } else {
        gauge.style.background = 'var(--success-color)';
    }
}

// Gestion des configurations sauvegardées
function updateSavedMaps(maps) {
    const container = document.querySelector('.saved-maps');
    if (!container) return;

    container.innerHTML = '';
    
    if (!maps || Object.keys(maps).length === 0) {
        container.innerHTML = '<div class="no-saves">Aucune configuration sauvegardée</div>';
        return;
    }

    Object.entries(maps).forEach(([id, map]) => {
        if (!map) return;
        
        const element = document.createElement('div');
        element.className = 'preset-card';
        element.innerHTML = `
            <div class="config-info">
                <h3>${map.name || 'Sans nom'}</h3>
                <p>Points: ${map.totalPoints || 0}/50</p>
            </div>
            <div class="actions">
                <button class="button" onclick="loadMap('${id}')">CHARGER</button>
                <button class="button delete-btn" onclick="deleteMap('${id}')">SUPPRIMER</button>
            </div>
        `;
        container.appendChild(element);
    });
}

function requestSavedMaps() {
    $.post(`https://${GetParentResourceName()}/requestSavedMaps`)
}

// Events handlers
window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch (data.type) {
        case 'showUI':
            document.body.classList.remove('hidden');
            requestSavedMaps(); // Demande les sauvegardes
            break;

        case 'updateSavedMaps':
            if (data.maps) {
                updateSavedMaps(data.maps);
            }
            break;

        case 'loadConfig':
            if (data.config && data.config.params) {
                // Mise à jour des sliders
                Object.entries(data.config.params).forEach(([param, value]) => {
                    const slider = document.querySelector(`.slider[data-param="${param}"]`);
                    if (slider) {
                        slider.value = value;
                        slider.closest('.slider-container').querySelector('.value').textContent = value;
                    }
                });
                updateAllPointsDisplays();
                showNotification('Configuration chargée', 'success');
                // Basculer vers l'onglet manuel
                document.querySelector('.tab-btn[data-tab="manual"]').click();
            }
            break;

        case 'loadConfig':
            if (data.config && data.config.params) {
                updateSlidersFromConfig(data.config.params);
                showNotification('Configuration chargée', 'success');
                document.querySelector('.tab-btn[data-tab="manual"]').click();
            }
            break;


        case 'updateStats':
            if (typeof data.temperature !== 'undefined') {
                updateTemperatureGauge(data.temperature);
            }
            if (typeof data.reliability !== 'undefined') {
                updateReliabilityGauge(data.reliability);
            }
            break;

        case 'hideUI':
            document.body.classList.add('hidden');
            break;
    }
});

function updatePointsDisplay(points) {
    document.querySelectorAll('.points-display').forEach(display => {
        display.textContent = `${points}/50`;
        display.style.color = points > 50 ? 'var(--danger-color)' : 'var(--text-color)';
    });
}

function updateAllStats(data) {
    if (data.temperature !== undefined) updateTemperatureGauge(data.temperature);
    if (data.reliability !== undefined) updateReliabilityGauge(data.reliability);
    if (data.points !== undefined) updateAllPointsDisplays();
}

// Fonctions globales pour les handlers onclick
window.loadMap = async (id) => {
    try {
        
        $.post(`https://${GetParentResourceName()}/loadMap`, JSON.stringify({
            id: parseInt(id)
        }))
    } catch (error) {
        console.error('Erreur lors du chargement:', error);
        showNotification('Erreur lors du chargement', 'error');
    }
};

window.deleteMap = async (id) => {
    try {
        
        $.post(`https://${GetParentResourceName()}/deleteMap`, JSON.stringify({
            id: id
        }));
        
        showNotification('Configuration supprimée', 'success');
        
        // Demander une mise à jour des configurations
        $.post(`https://${GetParentResourceName()}/requestSavedMaps`, '{}');
    } catch (error) {
        console.error('Erreur lors de la suppression:', error);
        showNotification('Erreur lors de la suppression', 'error');
    }
};

// Gestion des notifications
function showNotification(message, type = 'info') {
    const notif = document.createElement('div');
    notif.className = `notification ${type}`;
    notif.textContent = message;
    
    // Positionnement en haut à droite
    notif.style.position = 'fixed';
    notif.style.top = '20px';
    notif.style.right = '20px';
    
    document.body.appendChild(notif);
    
    // Animation d'entrée
    setTimeout(() => notif.classList.add('show'), 10);
    
    // Suppression automatique
    setTimeout(() => {
        notif.classList.add('fade-out');
        setTimeout(() => notif.remove(), 300);
    }, 3000);
}

function setupCloseHandlers() {
    document.querySelector('.close-btn')?.addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/closeUI`, { method: 'POST' });
    });

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape') {
            event.preventDefault();
            fetch(`https://${GetParentResourceName()}/closeUI`, { method: 'POST' });
        }
    });
}
