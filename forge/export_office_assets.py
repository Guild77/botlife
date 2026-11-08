"""Exporte les sprites de decor (sols, murs, meubles) vers assets/office + atlas JSON.
Usage : python3 forge/export_office_assets.py   (necessite Pillow)"""
import os, sys, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'legacy_pixelgen'))
import furniture as F
from pxlib import Spr

OUT = os.path.join(HERE, '..', 'assets', 'office')
os.makedirs(OUT, exist_ok=True)
atlas = {}

def save(name, spr, flip=False):
    p = f'{name}.png'
    spr.im.save(os.path.join(OUT, p))
    atlas[name] = dict(file=p, w=spr.im.width, h=spr.im.height, anchor=[spr.vx, spr.vy], footprint=[spr.tx, spr.ty])

def both(name, spr):
    save(name + '_a', spr)
    save(name + '_b', spr.flipped())

save('floor_carpet', F.floor_carpet(0)); save('floor_wood', F.floor_wood()); save('floor_tile', F.floor_tile()); save('rug', F.rug())
for side in 'yx':
    save(f'wall_{side}', F.wall(side)); save(f'wall_{side}_window', F.wall(side, True))
for scr in ['code', 'term', 'chart', 'chat']:
    for fr in (0, 1):
        s = Spr(2, 1, 28); F.draw_desk(s); F.draw_desk_items(s, scr, 3, fr); s.finish()
        both(f'desk_{scr}_{fr}', s)
for n, fn in [('plant_small', F.plant_small), ('plant_big', F.plant_big), ('plant_snake', F.plant_snake), ('lamp', F.lamp),
              ('trash', F.trash), ('water_cooler', F.water_cooler)]:
    save(n, fn())
both('pingpong', F.pingpong())
for fr in (0, 1):
    both(f'arcade_blue_{fr}', F.arcade(fr)); both(f'arcade_pink_{fr}', F.arcade(fr, (150, 60, 90)))
    both(f'server_rack_{fr}', F.server_rack(fr))
both('sofa', F.sofa()); both('coffee_bar', F.coffee_bar()); both('bookshelf', F.bookshelf()); both('printer', F.printer())
both('partition', F.partition())
save('whiteboard_y', F.whiteboard('y')); save('whiteboard_x', F.whiteboard('x'))
# chaise en deux couches (le perso s'assoit entre les deux)
for i, c in enumerate([(200, 70, 70), (70, 150, 200), (90, 190, 120), (240, 190, 70), (150, 100, 210)]):
    b = Spr(1, 1, 24); F.draw_chair(b, 8, 8, c); b.finish()
    k = Spr(1, 1, 24); F.draw_chair(k, 8, 8, c, back=True); k.finish()
    save(f'chair{i}_base', b); save(f'chair{i}_back', k)
json.dump(dict(tile=[32, 16], frames=atlas), open(os.path.join(OUT, 'atlas.json'), 'w'), indent=1)
print(len(atlas), 'sprites ->', OUT)
