
# 🚗 Script de Reprogrammation Moteur FiveM

## 📋 Description
Un script FiveM avancé permettant la reprogrammation moteur des véhicules avec une interface utilisateur interactive. Le script simule de manière réaliste les modifications du moteur avec des effets sur la température, la fiabilité et les performances du véhicule.

## 📺 Aperçu
Une vidéo présentation du script sur ma chaîne Youtube.
[Regarder sur Youtube](https://youtu.be/z5v_-WWEmcQ)

## ✨ Fonctionnalités

### Interface Interactive
- Interface NUI moderne et intuitive
- Système de tabs pour une navigation fluide
- Affichage en temps réel des données moteur
- Jauges de température et de fiabilité

### Personnalisation du Moteur
- Modification de multiples paramètres moteur :
  - Couple moteur
  - Accélération
  - Vitesse maximale
  - Régime minimal et maximal
  - Rapport de boîte
  - Frein moteur

### Système de Points
- Système de points limités (max 50)
- Balance entre performance et fiabilité
- Restrictions sur les modifications excessives

### Gestion des Configurations
- Sauvegarde des configurations personnalisées
- Presets prédéfinis (Éco, Sport, Course)
- Chargement et suppression des configurations

### Effets Réalistes
- Simulation de température moteur
- Impact sur la fiabilité du véhicule
- Effets visuels de fumée en cas de surchauffe
- Dégâts moteur progressifs

## 📥 Installation

1. Assurez-vous d'avoir les dépendances requises :
   - es_extended
   - mysql-async

2. Copiez le dossier dans votre dossier `resources`

3. Ajoutez au `server.cfg` :
```cfg
ensure stx_reprog
```

## ⚙️ Configuration

Le fichier `config.lua` permet de personnaliser :
- Les paramètres de température moteur
- Les limites de modifications
- Les presets par défaut
- Les multiplicateurs de performances
- Les seuils de fiabilité et de dégâts

## 🔧 Utilisation

1. Utilisez l'item "boitier de reprog" dans un véhicule
2. Accédez à l'interface de reprogrammation
3. Modifiez les paramètres ou appliquez un preset
4. Sauvegardez vos configurations personnalisées
5. Surveillez la température et la fiabilité du moteur

## ⚠️ Points Importants

- Les modifications excessives peuvent endommager le moteur
- La température doit être surveillée pour éviter la surchauffe
- La fiabilité diminue avec l'augmentation des performances
- Les sauvegardes sont liées au joueur et au véhicule

## 📝 Notes Techniques

- Utilise le système de handling de GTA V
- Synchronisation client/serveur des modifications
- Sauvegarde en base de données des configurations
- Effets particulaires pour la fumée moteur
- Système de calcul de température en temps réel

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :
- Signaler des bugs
- Proposer des améliorations
- Soumettre des pull requests

## 📜 License

Ce script est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

## 🙏 Crédits

Développé par miniilias
Interface NUI basée sur des composants modernes
Intégration ESX

## 🔧 Support

Pour toute question ou problème :
- Créez une issue sur GitHub
