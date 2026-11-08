"""Ajoute des habitants a l'open space : humains (couleurs, coiffures, lunettes aleatoires) et robots.
Usage : python3 forge/make_population.py   (deterministe : meme resultat a chaque fois)"""
import json, os, random
OUT = os.path.join(os.path.dirname(__file__), '..', 'pixel_chars', 'characters')
rnd = random.Random(2077)
SKINS = ['ffd6aa', 'f2c28f', 'e0a878', 'c68b5c', '9c6a42', '6e4a2e', 'ffdcc0']
HAIRS = ['2c222b', '4a3020', '8a5a2c', 'd8b060', 'b8402c', 'c8c8d0', '141414', '5a3a6a', '2a6a8a']
SHIRTS = ['3b6ed0', 'd23c46', '3ba070', 'e6a63c', '8a4ac8', 'e8e8f0', '2a2a3a', 'e0708a', '5ac8c8', 'a0a0a8']
PANTS = ['34385a', '2a2a2a', '5a4a3a', '3a5a4a', '6a6a78', '1c2a4a', '7a5a3a']
BOTS = ['5ca8c8', 'e8883c', '9a6ad0', '6ad07a', 'd25a5a', 'e8d058', 'c8c8d8', '58d0b8']
HUMANS = ['nina', 'hugo', 'zoe', 'leo', 'ines', 'tom', 'sara', 'yann', 'lea', 'adam', 'mia', 'noah', 'eva', 'lucas', 'jade', 'theo']
BOTNAMES = ['bot_red', 'bot_yellow', 'bot_white', 'bot_teal', 'bot_pink', 'bot_lime']

def write(name, d):
    with open(os.path.join(OUT, name + '.character.json'), 'w') as f:
        json.dump(d, f, indent=1)

for n in HUMANS:
    head = rnd.choice(['short', 'short', 'long', 'cap'])
    d = {
        "name": n,
        "library": "res://pixel_chars/library/human.parts.txt",
        "anims": ["res://pixel_chars/library/human.anims.json"],
        "colors": {"skin": '#' + rnd.choice(SKINS), "hair": '#' + rnd.choice(HAIRS),
                   "shirt": '#' + rnd.choice(SHIRTS), "pants": '#' + rnd.choice(PANTS)},
        "variants": {"head": head, "torso": rnd.choice(['default', 'default', 'tie'])},
        "extras": ['glasses'] if rnd.random() < 0.3 else [],
    }
    write(n, d)

for n in BOTNAMES:
    write(n, {
        "name": n,
        "library": "res://pixel_chars/library/robot.parts.txt",
        "anims": ["res://pixel_chars/library/human.anims.json"],
        "colors": {"primary": '#' + rnd.choice(BOTS)},
        "variants": {"head": "default", "torso": "default"},
        "extras": [],
    })
print(len(HUMANS), 'humains,', len(BOTNAMES), 'robots ajoutes')
