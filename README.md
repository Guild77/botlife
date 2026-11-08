# Bot Life

Open space isométrique en pixel art, avec des humains et des robots (les bots) qui travaillent, jouent et se déplacent.
Godot 4.7, rendu 2D en 1920x1080 natif, tri en profondeur par Y-sort.

Le projet contient quatre choses :

1. **Une scène de jeu** (`scenes/office_demo.tscn`) : un grand open space de 44 x 32 tuiles (45 bureaux, labo de bots, salon, arcade, ping-pong, coin café) avec une soixantaine d'habitants.
2. **Le Craft** : l'éditeur de personnages, accessible en jeu (touche C) pour dessiner ou importer un personnage et modifier ses animations.
3. **Pixel Char Studio** (`addons/pixel_char_studio`) : le même éditeur, en plugin Godot (onglet « Persos »).
4. **Les forges Python** (`forge/`) : scripts qui génèrent la bibliothèque de pièces, les animations, les personnages et les décors.

## Lancer la démo

Ouvrir le dossier dans Godot 4.7 (testé sur 4.7.2), lancer le projet (F5). La scène principale est `scenes/office_demo.tscn`.
Les personnages sont composés à l'exécution, rien n'est à exporter.

La résolution native est de 1920x1080 : les sprites gardent leur taille de pixel art (1 pixel d'art = 1 pixel d'écran) et le zoom se fait dans le jeu.

| Commande | Action |
|---|---|
| Flèches ou ZQSD (WASD) | déplacer la caméra |
| Clic droit (ou molette enfoncée) + glisser | déplacer la caméra |
| Molette | zoom x1, x2, x3, x4 (centré sur la souris) |
| C ou bouton « Craft » | ouvrir le Craft |
| Échap (dans le Craft) | retour au bureau |

## Le Craft : créer un personnage en jeu

Touche **C** : le jeu se met en pause et l'éditeur s'ouvre en plein écran. Étapes :

1. **Nouveau (copie)** : donner un nom. Par défaut la case « Pièces et animations à moi » est cochée : le personnage a sa propre bibliothèque de pièces et d'animations, on peut tout modifier sans toucher aux autres.
2. **Personnage** : couleurs (peau, cheveux, haut, bas...), coiffure, accessoires.
3. **Pieces (pixels)** : dessiner une pièce au pixel (clic gauche peint, clic droit efface, les boutons de couleur sont des rôles). **Copier en nouvelle variante** crée par exemple une nouvelle coiffure, de face et de dos.
4. **Importer PNG...** : choisir une image (PNG, WebP, JPG). Elle devient une nouvelle variante de la pièce affichée : réduite si elle dépasse la grille du corps (12 x 22), chaque pixel est rapproché du rôle de couleur le plus proche, donc les couleurs restent modifiables. Ensuite on retouche au pixel si besoin, puis on la choisit dans l'onglet Personnage.
5. **Animations** : toute la bibliothèque (marche, assis, ping-pong...) fonctionne immédiatement avec la nouvelle apparence. On peut la modifier image par image ou en créer de nouvelles (à la main ou avec l'assistant IA).
6. **Sauver tout**, puis **Retour au bureau** : le personnage apparaît dans l'open space, à un bureau libre ou en promenade.

Les personnages créés en jeu sont enregistrés dans le dossier utilisateur du jeu (sous Windows `%APPDATA%\Godot\app_userdata\Bot Life\characters`) et réapparaissent à chaque lancement. Les personnages du projet (dossier `pixel_chars/characters`) restent modifiables lors d'un lancement depuis l'éditeur Godot, mais en lecture seule dans un jeu exporté : utiliser alors « Nouveau (copie) ».

Limite actuelle : seules deux vues sont dessinées (face et dos), les 4 directions s'obtiennent par miroir. L'import d'une image alimente la vue affichée (face ou dos), la vue opposée reçoit une copie de la pièce de repos, à retoucher.


## Le plugin « Persos »

Activer le plugin dans Projet > Paramètres du projet > Extensions. Un onglet **Persos** apparaît en haut de l'éditeur.
Boutons du haut : **Nouveau (copie)**, **Sauver tout**, **Exporter PNG + atlas**. Quatre onglets :

- **Personnage** : couleurs (par rôle), choix des pièces, bibliothèque d'animations perso,
- **Animations** : lecture dans les 4 directions, édition image par image (décalages, rotation, accessoires, durée, boucle),
- **Pieces (pixels)** : dessiner ou modifier les pièces en pixels, avec variantes,
- **Assistant IA** : copier un prompt, coller le JSON produit par une IA, importer.

### Animations

Les 6 animations de base obligatoires : `idle`, `walk`, `run`, `jump`, `sit`, `lie`.
Les skills : `type` (taper sur l'ordinateur), `write` (écrire), `basket_dribble`, `basket_shoot`, `pingpong_ready`, `pingpong_hit`.
La bibliothèque est dans `pixel_chars/library/human.anims.json`. Humains et robots la partagent : les robots réutilisent les formes de bras et de jambes des humains.

### Ajouter un personnage

1. Dans l'onglet Persos, **Nouveau (copie)** : le personnage choisi est dupliqué sous un nouveau nom.
2. Onglet **Personnage** : régler les couleurs et les pièces.
3. **Sauver tout**. Le fichier `.character.json` est créé.
4. Dans une scène : ajouter un nœud `PixelCharacter`, renseigner `character_file`, puis `play_anim("walk", "se")`.

```gdscript
var pc := PixelCharacter.new()
pc.character_file = "res://pixel_chars/characters/alex.character.json"
add_child(pc)
pc.play_anim("type", "ne")   # directions : se, sw, ne, nw
pc.face(Vector2(1, 0))       # oriente selon un vecteur d'écran
```

### Ajouter une animation

À la main : onglet **Animations**, **Dupliquer** une animation proche, puis modifier les images (variante de pièce, décalage dx/dy, rotation, accessoire).

Avec une IA : onglet **Assistant IA**, décrire l'animation voulue, **Copier prompt : animation**, coller dans l'IA de votre choix, puis coller le JSON obtenu et cliquer **Importer animation(s)**. Le JSON est validé avant d'être ajouté, il n'est jamais appliqué s'il est invalide. Aucune clé d'API n'est nécessaire.

### Ajouter une pièce

Les pièces sont dessinées en ASCII dans `pixel_chars/library/human.parts.txt` et `robot.parts.txt`. Chaque lettre est un **rôle de couleur** (peau, cheveux, haut, bas, etc.), ce qui permet de changer les couleurs d'un personnage sans redessiner. Grille du corps : 12 x 22 dans un cadre de 40 x 40, ancre des pieds en (20, 37).
Seules deux vues sont dessinées (face et dos). Les 4 directions sont obtenues par miroir.

## Forges Python

```
python3 forge/make_library.py          # pièces, animations, personnages de départ
python3 forge/make_population.py       # 16 humains et 6 robots supplémentaires (couleurs aléatoires fixes)
python3 forge/export_office_assets.py  # décors vers assets/office/ + atlas.json
```

## Tests

Tests sans interface (nécessitent Godot 4.7 en ligne de commande) :

```
godot --headless --path . --script tests/export_check.gd
godot --headless --path . tests/logic_check.tscn
godot --headless --path . tests/craft_check.tscn
```

`craft_check.tscn` teste le Craft de bout en bout (nouveau personnage, import PNG, sauvegarde, rechargement).
`ui_check.tscn` vérifie l'interface du plugin (à lancer avec un affichage, ou sous `xvfb-run`).

## Utiliser dans un autre projet Godot

Copier `addons/pixel_char_studio`, `pixel_chars` et (pour les décors) `assets/office` ainsi que `scenes/patrol.gd` si besoin, puis activer le plugin.

## État

Version 0.1. Testé sous Windows avec Godot 4.7 (confirmé par l'auteur), et en ligne de commande sur Godot 4.7.2 Linux (sans affichage et sous Xvfb).
