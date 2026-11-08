# Bot Life

Open space isométrique en pixel art, avec des humains et des robots (les bots) qui travaillent, jouent et se déplacent.
Godot 4.4, rendu 2D, tri en profondeur par Y-sort.

Le projet contient trois choses :

1. **Une scène démo** (`scenes/office_demo.tscn`) : un open space complet avec 9 postes de travail, un coin ping-pong, des bornes d'arcade, un salon, etc.
2. **Pixel Char Studio** (`addons/pixel_char_studio`) : un plugin d'éditeur pour créer des personnages et leurs animations.
3. **Les forges Python** (`forge/`) : scripts qui génèrent la bibliothèque de pièces, les animations, les personnages de départ et les décors.

## Lancer la démo

Ouvrir le dossier dans Godot 4.4 ou plus, lancer le projet (F5). La scène principale est `scenes/office_demo.tscn`.
Les personnages sont composés à l'exécution, rien n'est à exporter.

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
python3 forge/export_office_assets.py  # décors vers assets/office/ + atlas.json
```

## Tests

Tests sans interface (nécessitent Godot 4.4 en ligne de commande) :

```
godot --headless --path . --script tests/export_check.gd
godot --headless --path . tests/logic_check.tscn
```

`ui_check.tscn` vérifie l'interface du plugin (à lancer avec un affichage, ou sous `xvfb-run`).

## Utiliser dans un autre projet Godot

Copier `addons/pixel_char_studio`, `pixel_chars` et (pour les décors) `assets/office` ainsi que `scenes/patrol.gd` si besoin, puis activer le plugin.

## État

Version 0.1. Les tests ont été exécutés sur Godot 4.4.1 Linux (sans affichage et sous Xvfb). Le rendu n'a pas encore été vérifié sur Windows.
