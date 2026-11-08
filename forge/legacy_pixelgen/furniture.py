"""Sols, murs et mobilier de l'open space (pixel art isometrique)."""
from pxlib import Spr, shade, mix, hrand

# ---------------------------------------------------------------- palette
WOOD = (184, 128, 76)
WOOD_TOP = (226, 174, 112)
METAL = (96, 102, 128)
DARK = (40, 44, 66)
WHITE = (240, 242, 250)

WALL_TOP = (250, 246, 238)
WALL_L = (238, 230, 214)   # face visible des murs "x" (normale +y)
WALL_R = (206, 198, 186)   # face visible des murs "y" (normale +x)
SKIRT = (120, 112, 128)


# ---------------------------------------------------------------- sols
def floor_carpet(variant=0):
    s = Spr(1, 1, 0, f"floor_carpet_{variant}")
    A, B, D = (96, 112, 148), (104, 121, 158), (86, 101, 136)
    if variant == 1:
        A, B, D = (110, 100, 140), (118, 108, 150), (98, 88, 126)

    def f(x, y):
        c = A if ((x // 8) + (y // 8)) % 2 == 0 else B
        if hrand(x, y, variant) < 0.09:
            c = D
        return c

    s.ft(0, 16, 0, 16, 0, lambda i, j: f(i, j))
    s.outline_on = False
    return s


def floor_wood():
    s = Spr(1, 1, 0, "floor_wood")
    cols = [(198, 150, 100), (188, 140, 92), (206, 158, 106)]
    seam = (150, 104, 66)

    def f(x, y):
        band = y // 4
        off = (band * 5) % 16
        xx = (x + off) % 16
        if y % 4 == 3:
            return seam
        if xx == 0:
            return seam
        c = cols[(band + (x + off) // 16) % 3]
        if hrand(x, y, 7) < 0.06:
            c = shade(c, 0.9)
        return c

    s.ft(0, 16, 0, 16, 0, f)
    s.outline_on = False
    return s


def floor_tile():
    s = Spr(1, 1, 0, "floor_tile_lounge")
    A, B, L = (228, 226, 234), (216, 216, 228), (190, 192, 210)

    def f(x, y):
        if x == 0 or y == 0:
            return L
        c = A if ((x // 8) + (y // 8)) % 2 == 0 else B
        if hrand(x, y, 3) < 0.05:
            c = shade(c, 0.94)
        return c

    s.ft(0, 16, 0, 16, 0, f)
    s.outline_on = False
    return s


# ---------------------------------------------------------------- murs
def _window(s, plane, u0, u1, z0, z1):
    frame = (84, 78, 98)

    def glass(i, j):
        h = z1 - z0
        t = j / max(1, h - 1)
        c = mix((176, 218, 244), (118, 170, 220), t)
        if (i + j) % 9 in (0, 1) and j < h - 4:
            c = mix(c, (255, 255, 255), 0.45)
        if i == (u1 - u0) // 2 or j == h // 2:
            c = frame
        if i in (0, u1 - u0 - 1) or j in (0, h - 1):
            c = frame
        return c

    if plane == "x":
        s.fx(1, u0, u1, z0, z1, glass)
    else:
        s.fy(1, u0, u1, z0, z1, glass)
    # appui
    if plane == "x":
        s.fx(1, u0 - 1, u1 + 1, z0 - 1, z0, (236, 232, 240))
    else:
        s.fy(1, u0 - 1, u1 + 1, z0 - 1, z0, (246, 242, 250))


def wall(side="y", window=False):
    """side='y' : mur le long de l'axe y (bord haut-gauche), face +x visible.
    side='x' : mur le long de l'axe x (bord haut-droit), face +y visible."""
    s = Spr(1, 1, 56, f"wall_{side}{'_window' if window else ''}")
    if side == "y":
        s.box(0, 0, 0, 2, 16, 56, WALL_R, top=WALL_TOP, right=WALL_R)
        s.fx(1, 0, 16, 0, 4, SKIRT)
        s.fx(1, 0, 16, 4, 5, shade(SKIRT, 1.25))
        s.fx(1, 0, 16, 52, 54, (190, 182, 172))
        if window:
            _window(s, "x", 3, 13, 22, 46)
    else:
        s.box(0, 0, 0, 16, 2, 56, WALL_L, top=WALL_TOP, left=WALL_L)
        s.fy(1, 0, 16, 0, 4, shade(SKIRT, 1.1))
        s.fy(1, 0, 16, 4, 5, shade(SKIRT, 1.35))
        s.fy(1, 0, 16, 52, 54, (214, 206, 194))
        if window:
            _window(s, "y", 3, 13, 22, 46)
    return s.finish()


# ---------------------------------------------------------------- bureau
SCREEN_COLS = [(120, 222, 255), (255, 204, 96), (150, 255, 150), (255, 138, 176), (200, 170, 255)]


def screen_fn(w, h, kind="code", seed=0, frame=0):
    """Retourne fn(i,j) -> couleur pour un ecran w x h."""
    rows = []
    for r in range(h):
        segs = []
        if kind == "code":
            n = 1 + int(hrand(r, seed, 1) * 3)
            x = int(hrand(r, seed, 2) * 3)
            for k in range(n):
                ln = 2 + int(hrand(r, k + seed, 3 + frame) * 5)
                segs.append((x, x + ln, SCREEN_COLS[int(hrand(r, k, seed + 4) * 5)]))
                x += ln + 1
        rows.append(segs)

    def f(i, j):
        if kind == "term":
            bg = (10, 30, 24)
            jj = (j + frame) % h
            if jj % 2 == 0 and i < 2 + int(hrand(jj, seed, 5) * (w - 3)):
                return (90, 255, 150)
            return bg
        if kind == "chart":
            bg = (28, 38, 72)
            col = i // 3
            hh = 2 + int(hrand(col, seed + frame // 2, 9) * (h - 3))
            if (i % 3) < 2 and j >= h - hh:
                return SCREEN_COLS[col % 5]
            return bg
        if kind == "chat":
            bg = (236, 240, 250)
            jj = (j + frame) % h
            if jj % 3 == 0:
                right = hrand(jj, seed, 8) < 0.5
                ln = 3 + int(hrand(jj, seed, 6) * (w - 6))
                if right and i >= w - ln - 1 and i < w - 1:
                    return (90, 140, 240)
                if not right and 1 <= i < ln + 1:
                    return (190, 198, 214)
            return bg
        # code
        bg = (26, 32, 66)
        jj = (j + frame) % h
        if jj % 2 == 0:
            for a, b, c in rows[jj]:
                if a <= i < b:
                    return c
        return bg

    return f


def draw_desk(s):
    leg = METAL
    s.box(2, 2, 2, 28, 2, 9, shade(WOOD, 0.8))      # panneau arriere
    s.box(1, 1, 0, 2, 2, 11, leg)
    s.box(29, 1, 0, 2, 2, 11, leg)
    s.box(1, 13, 0, 2, 2, 11, leg)
    # caisson a tiroirs
    s.box(21, 1, 0, 10, 14, 11, shade(WOOD, 1.0), left=shade(WOOD, 1.05))
    dr = (150, 100, 58)
    s.fy(14, 22, 30, 8, 9, dr)
    s.fy(14, 22, 30, 4, 5, dr)
    s.fy(14, 25, 27, 9, 10, (230, 220, 200))
    s.fy(14, 25, 27, 5, 6, (230, 220, 200))
    s.box(0, 0, 11, 32, 16, 2, WOOD, top=WOOD_TOP)


def draw_desk_items(s, screen="code", seed=1, frame=0, mug=True):
    # ecran
    s.box(10, 3, 13, 6, 4, 1, (70, 74, 96))
    s.box(12, 4, 14, 2, 2, 3, (70, 74, 96))
    s.box(4, 4, 16, 16, 2, 10, (44, 46, 64))
    s.fy(5, 5, 19, 17, 25, screen_fn(14, 8, screen, seed, frame))
    # clavier + souris
    s.ft(6, 18, 8, 12, 13, lambda i, j: (214, 218, 230) if (i + j) % 2 else (180, 186, 204))
    s.box(20, 9, 13, 2, 3, 1, (230, 232, 240))
    if mug:
        s.box(24, 4, 13, 3, 3, 3, (250, 250, 255), top=(110, 70, 50))
    # feuilles
    s.box(23, 9, 13, 5, 4, 1, (246, 244, 236), top=(252, 252, 248))


def desk():
    s = Spr(2, 1, 28, "desk")
    draw_desk(s)
    return s.finish()


def desk_full(screen="code", seed=1):
    s = Spr(2, 1, 28, "desk_computer")
    draw_desk(s)
    draw_desk_items(s, screen, seed)
    return s.finish()


def draw_chair(s, cx, cy, color=(200, 70, 70), back=False):
    if not back:
        s.box(cx - 4, cy - 1, 1, 8, 2, 1, (80, 84, 104))
        s.box(cx - 1, cy - 4, 1, 2, 8, 1, (80, 84, 104))
        for (dx, dy) in [(-4, -1), (3, -1), (-1, -4), (-1, 3)]:
            s.box(cx + dx, cy + dy, 0, 2, 2, 1, DARK)
        s.box(cx - 1, cy - 1, 2, 2, 2, 5, (80, 84, 104))
        s.box(cx - 5, cy - 5, 7, 10, 10, 3, color)
    else:
        s.box(cx - 5, cy + 3, 8, 10, 2, 7, shade(color, 0.95), top=shade(color, 1.25))


def chair(color=(200, 70, 70)):
    s = Spr(1, 1, 24, "chair")
    draw_chair(s, 8, 8, color)
    draw_chair(s, 8, 8, color, back=True)
    return s.finish()


# ---------------------------------------------------------------- plantes
def _pot(s, cx, cy, size, h, col=(193, 105, 59)):
    s.box(cx - size, cy - size, 0, 2 * size, 2 * size, h, col)
    s.box(cx - size - 1, cy - size - 1, h, 2 * size + 2, 2 * size + 2, 2, shade(col, 1.12))
    s.ft(cx - size, cx + size, cy - size, cy + size, h + 2, (76, 52, 40))


def plant_small():
    s = Spr(1, 1, 30, "plant_small")
    _pot(s, 8, 8, 4, 6)
    x, y = s.scr(8, 8, 10)
    g = (72, 164, 76)
    s.blob(x - 5, y - 4, 4, 3, shade(g, 0.85), 1)
    s.blob(x + 5, y - 5, 4, 3, shade(g, 0.9), 2)
    s.blob(x, y - 8, 5, 4, g, 3, speck=0.06)
    s.blob(x - 2, y - 13, 3, 3, shade(g, 1.1), 4)
    s.blob(x + 3, y - 12, 3, 3, shade(g, 1.05), 5)
    return s.finish()


def plant_big():
    s = Spr(1, 1, 52, "plant_big")
    _pot(s, 8, 8, 5, 8, (170, 176, 196))
    x, y = s.scr(8, 8, 12)
    for yy in range(0, 14):
        s.put(x, y - yy, (110, 76, 52))
        s.put(x + 1, y - yy, (92, 62, 44))
    g = (58, 148, 80)
    blobs = [(-8, -14, 6, 5), (8, -15, 6, 5), (0, -20, 8, 6), (-9, -24, 6, 5),
             (9, -25, 6, 5), (0, -30, 7, 6), (-4, -36, 5, 4), (5, -35, 5, 4)]
    for k, (dx, dy, rx, ry) in enumerate(blobs):
        s.blob(x + dx, y + dy, rx, ry, shade(g, 0.82 + 0.1 * (k % 3)), k, speck=0.05)
    return s.finish()


def plant_snake():
    s = Spr(1, 1, 40, "plant_snake")
    _pot(s, 8, 8, 4, 7, (230, 230, 240))
    x, y = s.scr(8, 8, 10)
    blades = [(-5, 20), (-3, 28), (-1, 24), (1, 30), (3, 22), (5, 26), (0, 17)]
    for dx, ln in blades:
        sh = 1 if dx > 0 else (-1 if dx < 0 else 0)
        for k in range(ln):
            ox = dx + (k // 9) * sh
            tip = k > ln - 4
            s.put(x + ox, y - k, (60, 142, 78))
            if not tip:
                s.put(x + ox + 1, y - k, (36, 100, 58))
        s.put(x + dx, y - 3, (150, 210, 96))
        s.put(x + dx, y - 4, (150, 210, 96))
    return s.finish()


# ---------------------------------------------------------------- ping pong
def pingpong():
    s = Spr(3, 2, 26, "pingpong")
    for (lx, ly) in [(3, 3), (43, 3)]:
        s.box(lx, ly, 0, 2, 2, 12, METAL)
    s.box(3, 6, 5, 2, 22, 2, METAL)
    s.box(43, 6, 5, 2, 22, 2, METAL)
    for (lx, ly) in [(3, 27), (43, 27)]:
        s.box(lx, ly, 0, 2, 2, 12, METAL)

    blue, dkb = (34, 98, 170), (22, 66, 124)

    def top(i, j):
        if i in (1, 46) or j in (1, 26) or j in (13, 14):
            return (240, 244, 252)
        return blue

    s.box(0, 2, 12, 48, 28, 2, dkb, top=blue)
    s.ft(0, 48, 2, 30, 14, top)
    # raquettes + balle
    s.ft(9, 13, 8, 12, 14, (214, 60, 60))
    s.ft(13, 15, 9, 11, 14, (160, 110, 70))
    s.ft(34, 38, 18, 22, 14, (60, 60, 70))
    s.ft(30, 31, 14, 15, 14, (255, 255, 255))
    s.set(30, 14, 15, (255, 255, 255))
    # filet
    s.box(23, 1, 14, 2, 1, 7, (230, 230, 240))
    s.box(23, 30, 14, 2, 1, 7, (230, 230, 240))
    s.fx(24, 2, 30, 14, 20, lambda i, j: (252, 252, 255) if j == 0 else ((226, 228, 240) if (i + j) % 2 == 0 else None))
    return s.finish()


# ---------------------------------------------------------------- arcade
def arcade_screen(w, h, frame=0):
    sprites = [
        ["0.0.0", ".000.", "00000", "0.0.0"],
        ["..0..", ".000.", "00000", "0...0"],
    ]
    cols = [(120, 255, 130), (255, 120, 220), (120, 220, 255)]

    def f(i, j):
        if hrand(i, j, 11) < 0.06:
            return (200, 200, 255)
        for k in range(2):
            for m in range(2):
                ox, oy = 1 + m * 5 - (frame % 2), 1 + k * 3
                sp = sprites[(k + frame) % 2]
                a, b = i - ox, j - oy
                if 0 <= a < 5 and 0 <= b < 3 and sp[b][a] == "0":
                    return cols[(k + m) % 3]
        if j == h - 2 and 2 <= i <= 5:
            return (255, 230, 90)
        if j == h - 3 and i == 3 + (frame % 2):
            return (255, 255, 255)
        return (10, 10, 30)

    return f


def arcade(frame=0, body=(52, 60, 150)):
    s = Spr(1, 1, 38, "arcade")
    s.box(2, 3, 0, 12, 9, 14, body)
    s.box(2, 3, 14, 12, 6, 14, shade(body, 0.8))
    s.box(3, 11, 11, 10, 3, 3, (86, 94, 190))
    s.box(2, 3, 28, 12, 6, 5, (240, 80, 140))
    # ecran
    s.fy(8, 3, 13, 16, 27, (24, 24, 40))
    s.fy(8, 4, 12, 17, 26, arcade_screen(8, 9, frame))
    # marquee
    s.fy(8, 3, 13, 29, 32, lambda i, j: (255, 244, 170) if (i % 3 != 2 and j in (1,)) else (255, 130, 170))
    # coin door
    s.fy(11, 5, 11, 2, 7, (30, 30, 46))
    s.fy(11, 6, 8, 4, 6, (255, 220, 80))
    s.fy(11, 9, 11, 4, 6, (255, 220, 80))
    # art laterale
    s.fx(13, 3, 12, 1, 14, lambda i, j: (255, 210, 80) if (i + j) % 7 in (0, 1) else None)
    s.fx(13, 3, 9, 15, 28, lambda i, j: (120, 230, 255) if (i + j) % 8 in (0, 1) else None)
    # commandes
    s.set(11, 12, 15, (230, 40, 50))
    s.set(11, 12, 16, (230, 40, 50))
    s.set(11, 12, 17, (255, 120, 120))
    s.set(11, 12, 14, (220, 220, 230))
    for k, c in enumerate([(255, 80, 80), (80, 200, 255), (255, 220, 80)]):
        s.set(5 + k * 2, 12, 14, c)
    return s.finish()


# ---------------------------------------------------------------- canape
def sofa(c=(214, 128, 72)):
    s = Spr(2, 1, 22, "sofa")
    s.box(0, 0, 0, 32, 5, 17, shade(c, 0.9), top=shade(c, 1.15))
    s.box(0, 0, 0, 4, 16, 11, shade(c, 0.85), top=shade(c, 1.1))
    s.box(4, 4, 0, 24, 12, 6, shade(c, 0.95))
    s.box(4, 5, 6, 12, 11, 3, shade(c, 1.05), top=shade(c, 1.22))
    s.box(16, 5, 6, 12, 11, 3, shade(c, 1.05), top=shade(c, 1.22))
    s.box(28, 0, 0, 4, 16, 11, shade(c, 0.85), top=shade(c, 1.1))
    return s.finish()


# ---------------------------------------------------------------- cafe & co
def coffee_bar():
    s = Spr(1, 1, 34, "coffee_bar")
    s.box(1, 2, 0, 14, 12, 13, (226, 228, 238), top=(150, 156, 176))
    s.fy(13, 2, 14, 4, 5, (190, 194, 208))
    s.fy(13, 7, 9, 6, 8, (130, 136, 156))
    s.box(3, 4, 13, 8, 7, 14, (52, 56, 78))
    s.fy(10, 4, 10, 17, 22, (30, 34, 50))
    s.fy(10, 5, 7, 20, 21, (90, 255, 150))
    s.fy(10, 8, 9, 20, 21, (255, 120, 90))
    s.fy(10, 5, 9, 14, 16, (20, 20, 30))
    s.box(12, 8, 13, 2, 2, 3, (250, 250, 255), top=(110, 70, 50))
    s.box(12, 4, 13, 2, 2, 2, (250, 220, 90), top=(110, 70, 50))
    return s.finish()


def water_cooler():
    s = Spr(1, 1, 38, "water_cooler")
    s.box(4, 4, 0, 8, 8, 15, (236, 238, 246))
    s.fy(11, 5, 11, 8, 11, (60, 64, 90))
    s.set(6, 11, 10, (80, 170, 255))
    s.set(9, 11, 10, (255, 90, 90))
    s.box(5, 5, 15, 6, 6, 13, (150, 214, 255))
    s.fy(10, 6, 9, 16, 26, (200, 238, 255))
    s.box(6, 6, 28, 4, 4, 2, (120, 190, 240))
    return s.finish()


def bookshelf():
    s = Spr(1, 1, 44, "bookshelf")
    s.box(1, 3, 0, 14, 8, 42, (122, 82, 52), top=(168, 120, 78))
    s.fy(10, 2, 14, 2, 40, (62, 42, 32))
    for z in (2, 12, 22, 32):
        s.fy(10, 1, 15, z, z + 1, (160, 108, 68))
    cols = [(200, 70, 70), (70, 120, 200), (240, 200, 80), (90, 170, 100), (160, 90, 190), (230, 230, 240), (240, 140, 70)]
    for row, z0 in enumerate((3, 13, 23, 33)):
        x = 2
        while x < 13:
            hgt = 5 + int(hrand(x, row, 1) * 4)
            w = 1 + int(hrand(x, row, 2) * 2)
            c = cols[int(hrand(x, row, 3) * len(cols))]
            if hrand(x, row, 4) < 0.12:
                x += 2
                continue
            for xx in range(x, min(x + w, 13)):
                s.fy(10, xx, xx + 1, z0, z0 + hgt, shade(c, 1.0 if xx == x else 0.85))
            x += w
    return s.finish()


def printer():
    s = Spr(1, 1, 24, "printer")
    s.box(2, 3, 0, 12, 10, 10, (208, 212, 224))
    s.box(2, 3, 10, 12, 10, 3, (150, 158, 178))
    s.box(3, 12, 6, 10, 3, 1, (250, 250, 255))
    s.fy(12, 3, 7, 6, 8, (60, 64, 90))
    s.fy(12, 8, 12, 3, 5, (40, 44, 60))
    s.set(5, 12, 7, (90, 255, 150))
    s.ft(5, 11, 4, 9, 13, (246, 246, 252))
    return s.finish()


def whiteboard(side="y"):
    s = Spr(1, 1, 44, f"whiteboard_{side}")
    s.box(2, 1, 16, 2, 14, 18, (176, 184, 202))
    s.fx(3, 2, 14, 17, 33, lambda i, j: (252, 252, 255))
    marks = [(2, 3, 9, (60, 100, 220)), (2, 6, 7, (60, 100, 220)), (2, 9, 8, (220, 70, 70)),
             (2, 12, 6, (60, 100, 220))]
    for (u, rr, ln, c) in marks:
        s.fx(3, 2 + u, 2 + u + ln, 28 - rr, 29 - rr, c)
    s.fx(3, 9, 12, 19, 22, (255, 220, 90))
    s.fx(3, 4, 7, 19, 22, (255, 150, 190))
    s.box(2, 4, 15, 2, 7, 1, (140, 148, 166))
    if side == "x":
        return s.finish().flipped("whiteboard_x")
    return s.finish()


def server_rack(frame=0):
    s = Spr(1, 1, 44, "server_rack")
    s.box(3, 3, 0, 10, 10, 40, (40, 44, 66))
    s.fy(12, 4, 12, 2, 38, (24, 26, 42))
    for k in range(9):
        z = 3 + k * 4
        s.fy(12, 4, 12, z, z + 3, (56, 62, 90))
        led = (90, 255, 150) if hrand(k, frame, 5) > 0.35 else (255, 160, 60)
        s.set(5, 12, z + 1, led)
        s.set(6, 12, z + 1, (90, 255, 150) if hrand(k, frame + 7, 5) > 0.5 else (60, 70, 100))
        for xx in range(8, 11):
            s.set(xx, 12, z + 1, (30, 34, 52))
    return s.finish()


def partition(color=(150, 170, 204)):
    s = Spr(2, 1, 32, "partition")
    s.box(2, 6, 0, 4, 4, 1, DARK)
    s.box(26, 6, 0, 4, 4, 1, DARK)
    s.box(0, 6, 1, 32, 2, 26, color, top=shade(color, 1.25))
    for (x, z, c) in [(4, 16, (255, 220, 90)), (9, 18, (255, 150, 190)), (24, 15, (130, 230, 170))]:
        s.fy(7, x, x + 4, z, z + 4, c)
    s.fy(7, 14, 22, 12, 21, (246, 246, 250))
    s.fy(7, 15, 21, 18, 19, (150, 156, 176))
    s.fy(7, 15, 19, 16, 17, (150, 156, 176))
    return s.finish()


def lamp():
    s = Spr(1, 1, 44, "lamp_floor")
    s.box(6, 6, 0, 4, 4, 1, DARK)
    s.box(7, 7, 1, 2, 2, 30, (90, 94, 116))
    s.box(4, 4, 31, 8, 8, 7, (255, 232, 150), top=(255, 248, 200))
    return s.finish()


def trash():
    s = Spr(1, 1, 14, "trash")
    s.box(5, 5, 0, 6, 6, 9, (92, 104, 134), top=(40, 44, 60))
    s.ft(6, 10, 6, 10, 9, (40, 44, 60))
    s.set(8, 8, 10, (240, 240, 250))
    return s.finish()


def rug():
    s = Spr(2, 2, 0, "rug_lounge")
    base, edge = (222, 120, 96), (246, 196, 120)

    def f(i, j):
        if i < 2 or j < 2 or i >= 30 or j >= 30:
            return edge
        if i < 4 or j < 4 or i >= 28 or j >= 28:
            return shade(base, 0.82)
        return base if (i + j) % 8 else shade(base, 1.12)

    s.ft(0, 32, 0, 32, 0, f)
    s.outline_on = False
    return s
