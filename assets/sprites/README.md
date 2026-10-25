# Dossier des Sprites (assets/sprites/)

Textures PNG découpées et nettoyées (fond transparent) avec support des 4 directions / axes (`haut`, `bas`, `gauche`, `droite`) et compatibilité avec les scripts du projet.

## 🧭 Convention de Nommage des Axes

Pour chaque entité / item, les 4 directions sont disponibles en français et en anglais :
* **Haut / Up / Back** : `<nom>_haut.png` ou `<nom>_up.png`
* **Bas / Down / Front** : `<nom>_bas.png` ou `<nom>_down.png`
* **Gauche / Left** : `<nom>_gauche.png` ou `<nom>_left.png`
* **Droite / Right** : `<nom>_droite.png` ou `<nom>_right.png`
* **Texture par défaut** : `<nom>.png` (permet le chargement direct sans suffixe)

---

## 📋 Répertoire des Sprites Disponibles

| Catégorie | Fichiers de Base | Suffixes Directionnels Disponibles | Fichiers Compatibilité Code | Description |
|---|---|---|---|---|
| **Survivant (Générique)** | `survivor.png`, `player.png` | `_bas`, `_haut`, `_gauche`, `_droite` (+ `_down`, `_up`, `_left`, `_right`) | `player.png` | Survivant jouable (260x260, centré) |
| **Survivant Joel** | `joel.png` | `_bas`, `_haut`, `_gauche`, `_droite` | `joel.png` | Joel (TLOU) jouable (260x260, 4 directions authentiques) |
| **Survivante Ellie** | `ellie.png` | `_bas`, `_haut`, `_gauche`, `_droite` | `ellie.png` | Ellie (TLOU) jouable (260x260, 4 directions authentiques) |
| **Boss Le Colosse** | `colosse_boss.png` | `_bas`, `_haut`, `_gauche`, `_droite`, `_attack` | `colosse_boss.png` | Bloater colossal (boule de spores & nuage toxique) |
| **Zombie Basique** | `zombie.png`, `zombie_basic.png` | `_bas`, `_haut`, `_gauche`, `_droite` (+ `_down`, `_up`, `_left`, `_right`) | `zombie_basic.png` | Zombie standard vert (256x290) |
| **Zombie Citrouille** | `zombie_citrouille.png`, `zombie_pumpkin.png` | `_bas`, `_haut`, `_gauche`, `_droite` (+ `_down`, `_up`, `_left`, `_right`) | `zombie_pumpkin.png` | Variante tête de citrouille (250x250) |
| **Chien Zombie** | `zombie_dog.png`, `zombie_chien.png` | `_bas`, `_haut`, `_gauche`, `_droite` (+ `_down`, `_up`, `_left`, `_right`) | `zombie_dog.png` | Chien zombie rapide (280x245) |
| **Boss Frankenstein** | `frankenstein.png`, `frankenstein_boss.png` | `_bas`, `_haut`, `_gauche`, `_droite` (+ `_down`, `_up`, `_left`, `_right`) | `frankenstein_boss.png` | Boss colossal (256x286) |
| **Dragonslayer** | `dragonslayer.png` | `_bas`, `_haut`, `_gauche`, `_droite` (+ `_down`, `_up`, `_left`, `_right`) | `dragonslayer.png` | Épée colossale type Berserk |
| **Pistolet Laser** | `laser_gun.png`, `pistolet_laser.png` | `_bas`, `_haut`, `_gauche`, `_droite` (+ `_down`, `_up`, `_left`, `_right`) | `laser_gun.png` | Arme Ray Gun BO2 |
| **Faucille & Marteau** | `sickle_hammer.png`, `faucille_marteau.png` | `_bas`, `_droite`, `_haut`, `_gauche`, `_0`, `_1`, `_2`, `_3` | `sickle_hammer.png` | Boomerang communiste orbital |
| **Coffre / Boîte Mystère** | `chest.png`, `mystery_box.png` | `_bas`, `_haut`, `_gauche`, `_droite` | `mystery_box.png` | Boîte mystère BO2 |
| **Bottes de Dash** | `dash_boots.png`, `dash.png`, `boots.png` | `_bas`, `_haut`, `_gauche`, `_droite` | `dash_boots.png` | Item passif Dash rapide |
| **Potion de Vie** | `popolife.png`, `potion_vie.png`, `regen.png` | `_bas`, `_haut`, `_gauche`, `_droite` | `popolife.png` | Item passif Régénération de PV |
| **Aimant (Tayon)** | `aimant.png`, `tayon.png`, `magnet.png` | `_bas`, `_haut`, `_gauche`, `_droite` | `aimant.png` | Item passif Tayon / attraction XP |
