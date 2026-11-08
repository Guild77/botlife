"""Bibliotheque de pixel art isometrique 2:1.

Convention : une tuile = 16 x 16 unites au sol (32 x 16 pixels a l'ecran).
Projection : ecran_x = vx + x - y ; ecran_y = vy + (x + y) // 2 - z
"""
from PIL import Image, ImageOps

TILE_W, TILE_H = 32, 16
OUTLINE_K = 0.38


def rgb(c):
    return (c[0], c[1], c[2], 255) if len(c) == 3 else tuple(c)


def clamp(v):
    return max(0, min(255, int(v)))


def shade(c, f):
    c = rgb(c)
    return (clamp(c[0] * f), clamp(c[1] * f), clamp(c[2] * f), c[3])


def mix(a, b, t):
    a, b = rgb(a), rgb(b)
    return tuple(clamp(a[i] + (b[i] - a[i]) * t) for i in range(4))


def hrand(x, y, s=0):
    n = (x * 374761393 + y * 668265263 + s * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


class Spr:
    M = 1  # marge pour le contour

    def __init__(self, tx, ty, zmax, name=""):
        self.name = name
        self.tx, self.ty, self.zmax = tx, ty, zmax
        self.W = 16 * (tx + ty) + 2 * self.M
        self.H = 8 * (tx + ty) + zmax + 2 * self.M
        self.vx = 16 * ty - 1 + self.M
        self.vy = zmax + self.M
        self.im = Image.new("RGBA", (self.W, self.H), (0, 0, 0, 0))
        self.px = self.im.load()
        self.outline_on = True

    # ---------- pixels bruts (coordonnees ecran) ----------
    def put(self, sx, sy, col):
        if 0 <= sx < self.W and 0 <= sy < self.H and col is not None:
            col = rgb(col)
            if col[3] == 255:
                self.px[sx, sy] = col
            elif col[3] > 0:
                d = self.px[sx, sy]
                a = col[3] / 255.0
                da = d[3] / 255.0
                oa = a + da * (1 - a)
                if oa > 0:
                    self.px[sx, sy] = tuple(
                        clamp((col[i] * a + d[i] * da * (1 - a)) / oa) for i in range(3)
                    ) + (clamp(oa * 255),)

    def scr(self, x, y, z=0):
        return self.vx + x - y, self.vy + (x + y) // 2 - z

    def set(self, x, y, z, col):
        sx, sy = self.scr(x, y, z)
        self.put(sx, sy, col)

    # ---------- faces ----------
    def ft(self, x0, x1, y0, y1, z, col):
        """Face du dessus (z constant). col : couleur ou fn(i,j)."""
        for x in range(x0, x1):
            for y in range(y0, y1):
                c = col(x - x0, y - y0) if callable(col) else col
                self.set(x, y, z, c)

    def fy(self, yp, x0, x1, z0, z1, col):
        """Face de normale +y (visible, cote gauche ecran). j=0 en haut."""
        for x in range(x0, x1):
            for z in range(z0, z1):
                c = col(x - x0, (z1 - 1) - z) if callable(col) else col
                self.set(x, yp, z, c)

    def fx(self, xp, y0, y1, z0, z1, col):
        """Face de normale +x (visible, cote droit ecran). j=0 en haut."""
        for y in range(y0, y1):
            for z in range(z0, z1):
                c = col(y - y0, (z1 - 1) - z) if callable(col) else col
                self.set(xp, y, z, c)

    def box(self, x0, y0, z0, a, b, h, base, top=None, left=None, right=None, edge=True):
        top = top or shade(base, 1.18)
        left = left or base
        right = right or shade(base, 0.72)
        zt = z0 + h
        xm, ym = x0 + a - 1, y0 + b - 1
        for x in range(x0, x0 + a):
            for z in range(z0, zt):
                self.set(x, ym, z, left)
        for y in range(y0, y0 + b):
            for z in range(z0, zt):
                self.set(xm, y, z, right)
        edge_c = shade(top, 1.12)
        for x in range(x0, x0 + a):
            for y in range(y0, y0 + b):
                c = edge_c if (edge and (x == xm or y == ym) and h > 0) else top
                self.set(x, y, zt, c)

    # ---------- formes en coordonnees ecran ----------
    def line(self, x0, y0, x1, y1, col):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.put(x0, y0, col)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def blob(self, cx, cy, rx, ry, base, seed=0, dark=0.72, light=1.22, speck=0.0, speck_col=None):
        for yy in range(-ry, ry + 1):
            for xx in range(-rx, rx + 1):
                u, v = xx / (rx + 0.5), yy / (ry + 0.5)
                if u * u + v * v > 1.0:
                    continue
                t = (-u - v) / 2.0
                c = base
                if t > 0.38:
                    c = shade(base, light)
                elif t < -0.38:
                    c = shade(base, dark)
                if speck and hrand(cx + xx, cy + yy, seed) < speck:
                    c = speck_col or shade(base, 1.45)
                self.put(cx + xx, cy + yy, c)

    # ---------- finalisation ----------
    def outline(self):
        src = self.im.load()
        out = self.im.copy()
        o = out.load()
        for y in range(self.H):
            for x in range(self.W):
                if src[x, y][3] < 10:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.W and 0 <= ny < self.H and src[nx, ny][3] >= 230:
                            o[x, y] = shade(src[nx, ny], OUTLINE_K)
                            break
        self.im = out
        self.px = out.load()

    def finish(self):
        if self.outline_on:
            self.outline()
        return self

    def flipped(self, name=None):
        n = Spr.__new__(Spr)
        n.name = name or self.name
        n.tx, n.ty, n.zmax = self.ty, self.tx, self.zmax
        n.W, n.H = self.W, self.H
        n.vx = self.W - 1 - self.vx
        n.vy = self.vy
        n.im = ImageOps.mirror(self.im)
        n.px = n.im.load()
        n.outline_on = self.outline_on
        return n


def blit_rows(spr, rows, pal, x0, y0, flip=False):
    """Pose un sprite ASCII (liste de chaines) sur spr aux coordonnees ecran."""
    w = max(len(r) for r in rows)
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch in ". ":
                continue
            c = pal.get(ch)
            if c is None:
                continue
            xx = x0 + (w - 1 - i if flip else i)
            spr.put(xx, y0 + j, c)
