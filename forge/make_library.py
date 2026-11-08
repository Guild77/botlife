"""Genere la bibliotheque de pieces (ASCII) et d'animations (JSON) de Pixel Character Studio.
Les fichiers produits sont ensuite editables a la main dans Godot."""
import json, os
OUT = os.path.join(os.path.dirname(__file__), '..', 'pixel_chars')
GW, GH = 12, 22
PART_ORDER = ['leg_l', 'leg_r', 'torso', 'arm_l', 'arm_r', 'head', 'extra']
VIEWS = ['front', 'back']

def mirror_rows(rows):
    return [r[::-1] for r in rows]

def mirror(x, w):
    return GW - (x + w)

# ------------------------------------------------------------------ pieces humaines
H = {}  # (view, part, variant) -> (x, y, rows)

def add(view, part, var, x, y, rows):
    w = max(len(r) for r in rows)
    H[(view, part, var)] = (x, y, [r.ljust(w, '.') for r in rows])

def add_lr(view, base, var, x, y, rows):
    add(view, base + '_l', var, x, y, rows)
    w = max(len(r) for r in rows)
    add(view, base + '_r', var, mirror(x, w), y, mirror_rows([r.ljust(w, '.') for r in rows]))

def draw_line(grid, x0, y0, x1, y1, ch, thick=2):
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        for t in range(thick):
            if (x0, y0 + t) in grid or True:
                grid[(x0, y0 + t)] = ch
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy; x0 += sx
        if e2 <= dx:
            err += dx; y0 += sy

def grid_to_rows(grid):
    xs = [p[0] for p in grid]; ys = [p[1] for p in grid]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    rows = []
    for y in range(y0, y1 + 1):
        rows.append(''.join(grid.get((x, y), '.') for x in range(x0, x1 + 1)))
    return x0, y0, rows

heads_front = {
    'short': ["...hhhhhh...", "..hHhhhhhh..", "..hhhhhhhh..", "..hhsssshh..", "..hsessesh..", "..hssssssh..", "...ssssss...", ".....SS....."],
    'long': ["...hhhhhh...", "..hHhhhhhh..", "..hhhhhhhh..", "..hhsssshh..", "..hsessesh..", "..hssssssh..", "..hhsssshh..", "..hh.SS.hh..", "..hh....hh..", "..hh....hh.."],
    'cap': ["...CCCCCC...", "..CCCCCCCC..", "..CCCCCCCC..", "..hhsssshh..", "..hsessesh..", "..hssssssh..", "...ssssss...", ".....SS....."],
}
heads_back = {
    'short': ["...hhhhhh...", "..hHhhhhhh..", "..hhhhhhhh..", "..hhhhhhhh..", "..hhhhhhhh..", "..hhhhhhhh..", "...hhhhhh...", ".....SS....."],
    'long': ["...hhhhhh...", "..hHhhhhhh..", "..hhhhhhhh..", "..hhhhhhhh..", "..hhhhhhhh..", "..hhhhhhhh..", "..hhhhhhhh..", "..hhhhhhhh..", "...hhhhhh...", "...hhhhhh...", "....hhhh...."],
    'cap': ["...CCCCCC...", "..CCCCCCCC..", "..CCCCCCCC..", "..CCCCCCCC..", "..hhhhhhhh..", "..hhhhhhhh..", "...hhhhhh...", ".....SS....."],
}
for v, rows in heads_front.items():
    add('front', 'head', v, 0, 0, rows)
for v, rows in heads_back.items():
    add('back', 'head', v, 0, 0, rows)
add('front', 'extra', 'glasses', 3, 4, ["geggeg"])

add('front', 'torso', 'default', 2, 8, [".ttSStt.", ".tttttt.", ".tttttt.", ".tttttt.", ".tttttt.", "bbbbbbbb"])
add('front', 'torso', 'tie', 2, 8, [".ttSStt.", ".ttqqtt.", ".ttqqtt.", ".ttqqtt.", ".tttttt.", "bbbbbbbb"])
add('back', 'torso', 'default', 2, 8, [".tttttt.", ".tttttt.", ".tttttt.", ".tttttt.", ".tttttt.", "bbbbbbbb"])

for view in VIEWS:
    add_lr(view, 'arm', 'down', 1, 8, ["tt", "tT", "tT", "sS", "sS"])
    add_lr(view, 'arm', 'fwd', 1, 8, ["tt", "tT", "sS", "sS"])
    add_lr(view, 'arm', 'back', 1, 8, ["tt", "tT", "tT", "tT", "sS", "sS"])
    add_lr(view, 'arm', 'bent', 1, 8, ["tt.", "tT.", "tT.", "sSs"])
    add_lr(view, 'arm', 'out', -3, 8, ["....tt", "ssSttt", "ssSttT"])
    add_lr(view, 'arm', 'up', 0, 3, ["ss.", "ss.", "sS.", "sS.", "tT.", "ttt", ".tT"])
    add_lr(view, 'leg', 'stand', 2, 14, [".ppp", ".ppp", ".ppP", ".ppP", ".ppP", ".ppP", ".ppP", "kkkk"])
    add_lr(view, 'leg', 'lift', 2, 14, [".ppp", ".ppP", ".ppP", ".ppP", ".ppP", "kkkk"])
    add_lr(view, 'leg', 'lift3', 2, 14, [".ppp", ".ppP", ".ppP", ".ppP", "kkkk"])
    add_lr(view, 'leg', 'sit', 2, 16, [".ppp", ".ppP", ".ppP", ".ppP", ".ppP", "kkkk"])

# bras "reach" (vu de dos, mains vers le clavier en haut a droite) et "bent" en vue de face
for frame, (hl, hr) in {'a': (0, 1), 'b': (1, 0)}.items():
    g = {}
    draw_line(g, 2, 9, 5, 11, 't')
    draw_line(g, 5, 11, 11, 7 + hl, 's')
    x, y, rows = grid_to_rows(g)
    add('back', 'arm_l', 'reach_' + frame, x, y, rows)
    g = {}
    draw_line(g, 9, 9, 11, 10, 't')
    draw_line(g, 11, 10, 14, 8 + hr, 's')
    x, y, rows = grid_to_rows(g)
    add('back', 'arm_r', 'reach_' + frame, x, y, rows)
    add_lr('front', 'arm', 'reach_' + frame, 1, 8 - hl if False else 8, ["tt.", "tT.", "tT.", "sSs" if frame == 'a' else ".sS"])

# ------------------------------------------------------------------ props
PROPS = {
    'ball': [".ooo.", "oOOOo", "ooOoo", "oOOOo", ".ooo."],
    'paddle': [".rrr.", "rrrrr", "rrrrr", "rrrrr", ".rrr.", "..W..", "..W.."],
    'pball': ["ww", "ww"],
    'pen': ["n", "n", "n", "N"],
    'paper': ["wwwww", "wlwlw", "wwwww", "wlwlw"],
}

HUMAN_HEADER = """# Pixel Character Studio : bibliotheque de pieces "human"
# Format : lignes @... = directives ; apres "@part vue piece variante x y" viennent les lignes de pixels.
# Chaque lettre est un ROLE de couleur (voir @role). '.' = transparent. Ligne vide = fin de la piece.
@lib human
@grid 12 22
@origin 14 15
@frame 40 40
@anchor 20 37
@views se=front sw=front ne=back nw=back
@order leg_l leg_r torso arm_l arm_r head extra
@upper torso arm_l arm_r head extra
@lower leg_l leg_r
@rest head=short torso=default arm_l=down arm_r=down leg_l=stand leg_r=stand extra=none
@color skin ffd6aa
@color hair 2c222b
@color eyes 1c1826
@color glasses 3c405a
@color shirt 3b6ed0
@color pants 34385a
@color shoes 222030
@color tie d23c46
@color cap e6783c
@color ball e8883c
@color paddle d23c3c
@color wood a06e46
@color white f4f4fa
@color pen 2a2a40
@color paper_line 9aa0c0
@role s skin 1.0
@role S skin 0.80
@role h hair 1.0
@role H hair 1.4
@role e eyes 1.0
@role g glasses 1.0
@role t shirt 1.0
@role T shirt 0.78
@role p pants 1.0
@role P pants 0.75
@role b pants 0.6
@role k shoes 1.0
@role q tie 1.0
@role C cap 1.0
@role o ball 1.0
@role O ball 0.62
@role r paddle 1.0
@role W wood 1.0
@role w white 1.0
@role n pen 1.0
@role N pen 0.6
@role l paper_line 1.0
"""

def emit(path, header, parts, props, order=PART_ORDER):
    lines = [header.rstrip('\n'), '']
    for view in VIEWS:
        for part in order:
            for key in sorted(k for k in parts if k[0] == view and k[1] == part):
                x, y, rows = parts[key]
                lines.append(f"@part {view} {part} {key[2]} {x} {y}")
                lines += rows
                lines.append('')
    for name, rows in props.items():
        lines.append(f"@prop {name}")
        lines += rows
        lines.append('')
    open(path, 'w').write('\n'.join(lines) + '\n')

# ------------------------------------------------------------------ robot
R = {}
RMAP = str.maketrans({'t': 'm', 'T': 'x', 's': 'd', 'S': 'd', 'p': 'm', 'P': 'x', 'k': 'd', 'b': 'x'})
for (view, part, var), (x, y, rows) in H.items():
    if part in ('arm_l', 'arm_r', 'leg_l', 'leg_r'):
        R[(view, part, var)] = (x, y, [r.translate(RMAP) for r in rows])
r_head_front = [".....aa.....", ".....dd.....", "..hhhhhhhh..", "..mddddddm..", "..mdcddcdm..", "..mddddddm..", "..mmmmmmmm..", "....dddd...."]
r_head_back = [".....aa.....", ".....dd.....", "..hhhhhhhh..", "..mmmmmmmm..", "..mddddddm..", "..mmmmmmmm..", "..mddddddm..", "....dddd...."]
def plain(rows):
    return ['............', '............'] + rows[2:]
R[('front', 'head', 'default')] = (0, 0, r_head_front)
R[('front', 'head', 'plain')] = (0, 0, plain(r_head_front))
R[('back', 'head', 'default')] = (0, 0, r_head_back)
R[('back', 'head', 'plain')] = (0, 0, plain(r_head_back))
R[('front', 'torso', 'default')] = (2, 8, [".hhhhhh.", ".hhhhhh.", ".hdllch.", ".hhhhhh.", ".hmmmmh.", "xxxxxxxx"])
R[('back', 'torso', 'default')] = (2, 8, [".hhhhhh.", ".hmddmh.", ".hmddmh.", ".hhhhhh.", ".hmmmmh.", "xxxxxxxx"])
# reach : bras dessines par le meme tracé, couleurs robot
for (view, part, var), (x, y, rows) in list(R.items()):
    pass

ROBOT_HEADER = HUMAN_HEADER.split('@lib human')[0].replace('"human"', '"robot"') + """@lib robot
@grid 12 22
@origin 14 15
@frame 40 40
@anchor 20 37
@views se=front sw=front ne=back nw=back
@order leg_l leg_r torso arm_l arm_r head extra
@upper torso arm_l arm_r head extra
@lower leg_l leg_r
@rest head=default torso=default arm_l=down arm_r=down leg_l=stand leg_r=stand extra=none
@color primary 5ca8c8
@color dark 2e3452
@color accent ffaa3c
@color eye 5af4ff
@color antenna ff5454
@color metal c8cee0
@color ball e8883c
@color paddle d23c3c
@color wood a06e46
@color white f4f4fa
@color pen 2a2a40
@color paper_line 9aa0c0
@role h primary 1.3
@role m primary 1.0
@role x primary 0.7
@role d dark 1.0
@role l accent 1.0
@role c eye 1.0
@role a antenna 1.0
@role w metal 1.0
@role o ball 1.0
@role O ball 0.62
@role r paddle 1.0
@role W wood 1.0
@role n pen 1.0
@role N pen 0.6
@role l accent 1.0
"""

os.makedirs(os.path.join(OUT, 'library'), exist_ok=True)
emit(os.path.join(OUT, 'library', 'human.parts.txt'), HUMAN_HEADER, H, PROPS)
emit(os.path.join(OUT, 'library', 'robot.parts.txt'), ROBOT_HEADER, R, {k: v for k, v in PROPS.items() if k != 'paper'})

# ------------------------------------------------------------------ animations
def fr(p=None, upper=None, lower=None, all=None, rot=None, props=None, d=None, front=None, back=None):
    f = {}
    if p: f['p'] = p
    if upper: f['upper'] = upper
    if lower: f['lower'] = lower
    if all: f['all'] = all
    if rot: f['rot'] = rot
    if props: f['props'] = props
    if d: f['d'] = d
    if front: f['front'] = front
    if back: f['back'] = back
    return f

def arms(l, r): return {'arm_l': l, 'arm_r': r}
def legs(l, r): return {'leg_l': l, 'leg_r': r}
def P(**kw): return kw

ANIMS = {
 "idle": {"fps": 2, "loop": True, "frames": [fr(upper=[0, 0]), fr(upper=[0, 1])]},
 "walk": {"fps": 8, "loop": True, "frames": [
     fr(P(**legs('lift', 'stand'), **arms('back', 'fwd'))),
     fr(P(**legs('stand', 'stand')), upper=[0, 1]),
     fr(P(**legs('stand', 'lift'), **arms('fwd', 'back'))),
     fr(P(**legs('stand', 'stand')), upper=[0, 1])]},
 "run": {"fps": 12, "loop": True, "frames": [
     fr(P(**legs('lift3', 'stand'), **arms('back', 'fwd')), all=[0, -1]),
     fr(P(**legs('lift', 'lift'), **arms('down', 'down')), all=[0, -3]),
     fr(P(**legs('stand', 'lift3'), **arms('fwd', 'back')), all=[0, -1]),
     fr(P(**legs('lift', 'lift'), **arms('down', 'down')), all=[0, -3])]},
 "jump": {"fps": 8, "loop": False, "frames": [
     fr(P(**legs('sit', 'sit'), **arms('back', 'back')), upper=[0, 2]),
     fr(P(**legs('lift', 'lift'), **arms('up', 'up')), all=[0, -3]),
     fr(P(**legs('lift3', 'lift3'), **arms('up', 'up')), all=[0, -8]),
     fr(P(**legs('lift3', 'lift3'), **arms('out', 'out')), all=[0, -8]),
     fr(P(**legs('lift', 'lift'), **arms('out', 'out')), all=[0, -3]),
     fr(P(**legs('sit', 'sit'), **arms('out', 'out')), upper=[0, 2])]},
 "sit": {"fps": 2, "loop": True, "frames": [
     fr(P(**legs('sit', 'sit'), **arms('bent', 'bent')), upper=[0, 2]),
     fr(P(**legs('sit', 'sit'), **arms('bent', 'bent')), upper=[0, 3])]},
 "lie": {"fps": 2, "loop": True, "frames": [
     fr(rot=90, all=[6, 11]),
     fr(rot=90, all=[6, 11], upper=[0, 1])]},
 "type": {"fps": 10, "loop": True, "frames": [
     fr(P(**legs('sit', 'sit'), **arms('reach_a', 'reach_b')), upper=[0, 2]),
     fr(P(**legs('sit', 'sit'), **arms('reach_b', 'reach_b')), upper=[0, 2]),
     fr(P(**legs('sit', 'sit'), **arms('reach_b', 'reach_a')), upper=[0, 3]),
     fr(P(**legs('sit', 'sit'), **arms('reach_a', 'reach_a')), upper=[0, 2]),
     fr(P(**legs('sit', 'sit'), **arms('reach_a', 'reach_b')), upper=[0, 2]),
     fr(P(**legs('sit', 'sit'), **arms('reach_b', 'reach_a')), upper=[0, 3])]},
 "write": {"fps": 6, "loop": True, "frames": [
     fr(P(**arms('down', ['up', -1, 0])), props=[{"id": "pen", "x": 11, "y": 3}]),
     fr(P(**arms('down', ['up', 0, 0])), props=[{"id": "pen", "x": 12, "y": 3}], upper=[0, 0]),
     fr(P(**arms('down', ['up', 1, 0])), props=[{"id": "pen", "x": 13, "y": 3}]),
     fr(P(**arms('down', ['up', 0, 0])), props=[{"id": "pen", "x": 12, "y": 3}], upper=[0, 1])]},
 "basket_dribble": {"fps": 8, "loop": True, "frames": [
     fr(P(**arms('down', 'fwd')), props=[{"id": "ball", "x": 10, "y": 8}]),
     fr(P(**arms('down', 'back')), props=[{"id": "ball", "x": 10, "y": 13}], upper=[0, 1]),
     fr(P(**arms('down', 'back')), props=[{"id": "ball", "x": 10, "y": 17}], upper=[0, 1]),
     fr(P(**arms('down', 'fwd')), props=[{"id": "ball", "x": 10, "y": 12}])]},
 "basket_shoot": {"fps": 8, "loop": False, "frames": [
     fr(P(**legs('sit', 'sit'), **arms('bent', 'bent')), upper=[0, 2], props=[{"id": "ball", "x": 4, "y": 9}]),
     fr(P(**legs('lift', 'lift'), **arms('up', 'up')), all=[0, -3], props=[{"id": "ball", "x": 4, "y": -2}]),
     fr(P(**legs('lift3', 'lift3'), **arms('up', 'up')), all=[0, -7], props=[{"id": "ball", "x": 4, "y": -9}]),
     fr(P(**legs('lift3', 'lift3'), **arms('up', 'up')), all=[0, -7], props=[{"id": "ball", "x": 4, "y": -13}]),
     fr(P(**legs('lift', 'lift'), **arms('out', 'out')), all=[0, -3], props=[{"id": "ball", "x": 4, "y": -14}]),
     fr(P(**legs('sit', 'sit'), **arms('down', 'down')), upper=[0, 2])]},
 "pingpong_ready": {"fps": 4, "loop": True, "frames": [
     fr(P(**arms('bent', 'bent')), props=[{"id": "paddle", "x": 9, "y": 6}]),
     fr(P(**arms('bent', 'bent')), upper=[0, 1], props=[{"id": "paddle", "x": 9, "y": 7}])]},
 "pingpong_hit": {"fps": 10, "loop": False, "frames": [
     fr(P(**arms('bent', 'bent')), props=[{"id": "paddle", "x": 9, "y": 6}]),
     fr(P(**arms('bent', 'out')), upper=[-1, 0], props=[{"id": "paddle", "x": 14, "y": 6}]),
     fr(P(**arms('bent', 'bent')), upper=[1, 0], props=[{"id": "paddle", "x": 5, "y": 9}, {"id": "pball", "x": 1, "y": 9}]),
     fr(P(**arms('bent', 'fwd')), upper=[1, 0], props=[{"id": "paddle", "x": 2, "y": 8}]),
     fr(P(**arms('bent', 'bent')), props=[{"id": "paddle", "x": 9, "y": 6}])]},
}
json.dump(ANIMS, open(os.path.join(OUT, 'library', 'human.anims.json'), 'w'), indent=1)

# ------------------------------------------------------------------ personnages
HUM = {
 "alex": dict(skin="ffd6aa", hair="2c222b", shirt="3b6ed0", pants="34385a", head="short"),
 "maya": dict(skin="de a070".replace(' ', ''), hair="be4a31", shirt="e6ecfa", pants="4a6496", head="long", extra=["glasses"], glasses="3c405a"),
 "omar": dict(skin="965c3c", hair="1e1e1e", shirt="40a86a", pants="3c3c46", head="cap"),
 "lena": dict(skin="f6c8a0", hair="e9b55d", shirt="9664d2", pants="34385a", head="long"),
 "sam": dict(skin="ffd6aa", hair="733e39", shirt="de5454", pants="a08664", head="short", extra=["glasses"], torso="tie"),
}
for name, c in HUM.items():
    colors = {k: '#' + v for k, v in c.items() if k in ('skin', 'hair', 'shirt', 'pants', 'glasses')}
    d = {"name": name, "library": "res://pixel_chars/library/human.parts.txt",
         "anims": ["res://pixel_chars/library/human.anims.json"],
         "colors": colors, "variants": {"head": c.get('head', 'short'), "torso": c.get('torso', 'default')},
         "extras": c.get('extra', [])}
    json.dump(d, open(os.path.join(OUT, 'characters', f'{name}.character.json'), 'w'), indent=1)
ROB = {"bot_cyan": "5ca8c8", "bot_orange": "e88c46", "bot_purple": "966ed6", "bot_green": "60be78"}
for name, col in ROB.items():
    d = {"name": name, "library": "res://pixel_chars/library/robot.parts.txt",
         "anims": ["res://pixel_chars/library/human.anims.json"],
         "colors": {"primary": '#' + col}, "variants": {"head": "default", "torso": "default"}, "extras": []}
    json.dump(d, open(os.path.join(OUT, 'characters', f'{name}.character.json'), 'w'), indent=1)
print('ok', len(H), len(R))
