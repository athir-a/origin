#!/usr/bin/env python3
"""Origin art pipeline.

Takes the AI-generated source art (transparent PNGs) from RAW and turns it into
crisp, small, palette-limited pixel sprites in assets/origin/. Also generates the
procedural ground tile atlas. Re-runnable; missing sources are skipped.
"""
import os, sys, random, math
import numpy as np
from PIL import Image, ImageDraw

RAW = os.environ.get("ORIGIN_RAW", "/home/ubuntu/art_raw")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "origin")
OUT = os.path.abspath(OUT)


def load(name):
    p = os.path.join(RAW, name + ".png")
    if not os.path.exists(p):
        print("  (missing)", name)
        return None
    return Image.open(p).convert("RGBA")


def tight_bbox(im, thr=40):
    a = np.array(im)[:, :, 3] > thr
    ys, xs = np.nonzero(a)
    if len(xs) == 0:
        return im.getbbox()
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def harden(im, colors=40):
    """Quantize colours and binarize alpha so the sprite reads as clean pixel art."""
    a = np.array(im)[:, :, 3]
    rgb = im.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = np.array(rgb)
    res = np.dstack([out, np.where(a > 110, 255, 0).astype(np.uint8)])
    return Image.fromarray(res, "RGBA")


def fit(im, width=None, height=None, colors=40):
    bb = tight_bbox(im)
    im = im.crop(bb)
    if width:
        s = width / im.width
    else:
        s = height / im.height
    w, h = max(1, round(im.width * s)), max(1, round(im.height * s))
    im = im.resize((w, h), Image.BOX)
    return harden(im, colors)


def save(im, sub, name):
    d = os.path.join(OUT, sub)
    os.makedirs(d, exist_ok=True)
    im.save(os.path.join(d, name + ".png"))
    print("  wrote", sub, name, im.size)


def components(im, dilate=24):
    """Return bounding boxes of separated objects, ordered row-major."""
    a = np.array(im)[:, :, 3] > 40
    h, w = a.shape
    step = 8
    small = a[: h // step * step, : w // step * step].reshape(h // step, step, w // step, step).max(axis=(1, 3))
    d = max(1, dilate // step)
    big = np.zeros_like(small)
    ys, xs = np.nonzero(small)
    for y, x in zip(ys, xs):
        big[max(0, y - d): y + d + 1, max(0, x - d): x + d + 1] = True
    lab = np.zeros(big.shape, dtype=np.int32)
    n = 0
    for y, x in zip(*np.nonzero(big)):
        if lab[y, x]:
            continue
        n += 1
        stack = [(y, x)]
        lab[y, x] = n
        while stack:
            cy, cx = stack.pop()
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < big.shape[0] and 0 <= nx < big.shape[1] and big[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = n
                    stack.append((ny, nx))
    boxes = []
    for k in range(1, n + 1):
        m = (lab == k) & small
        if m.sum() < 6:
            continue
        yy, xx = np.nonzero(m)
        boxes.append((xx.min() * step, yy.min() * step, (xx.max() + 1) * step, (yy.max() + 1) * step))
    return boxes


def split_sheet(im, cols_hint=None, dilate=24):
    boxes = components(im, dilate)
    if not boxes:
        return []
    # cluster into rows by vertical centre
    boxes.sort(key=lambda b: (b[1] + b[3]) / 2)
    rows, cur = [], [boxes[0]]
    for b in boxes[1:]:
        c0 = sum((x[1] + x[3]) / 2 for x in cur) / len(cur)
        if abs((b[1] + b[3]) / 2 - c0) < im.height * 0.18:
            cur.append(b)
        else:
            rows.append(cur)
            cur = [b]
    rows.append(cur)
    out = []
    for r in rows:
        r.sort(key=lambda b: b[0])
        out.extend(r)
    return [im.crop(b) for b in out]


def building(src, name, width=None, height=None, sub="buildings"):
    im = load(src)
    if im is None:
        return
    save(fit(im, width, height), sub, name)


def character(src, name, height, sub="chars"):
    """Split a three-pose sheet (front, back, side) at equal thirds; shared scale, shared feet line."""
    im = load(src)
    if im is None:
        return
    W, H = im.size
    parts = []
    for i in range(3):
        seg = im.crop((i * W // 3, 0, (i + 1) * W // 3, H))
        bb = tight_bbox(seg)
        parts.append(seg.crop(bb))
    tallest = max(p.height for p in parts)
    s = height / tallest
    for p, tag in zip(parts, ["front", "back", "side"]):
        w, h = max(1, round(p.width * s)), max(1, round(p.height * s))
        p = harden(p.resize((w, h), Image.BOX), 36)
        save(p, sub, f"{name}_{tag}")


def sheet(src, names, sizes, sub="props", cols=0):
    im = load(src)
    if im is None:
        return
    if cols:
        W = im.width
        parts = []
        for i in range(cols):
            seg = im.crop((i * W // cols, 0, (i + 1) * W // cols, im.height))
            parts.append(seg)
    else:
        parts = split_sheet(im)
    if len(parts) != len(names):
        print("  WARN %s: expected %d parts, found %d" % (src, len(names), len(parts)))
    for part, name, size in zip(parts, names, sizes):
        kw = {"width": size[0]} if size[0] else {"height": size[1]}
        save(fit(part, **kw), sub, name)


# ----------------------------------------------------------------------------------------------
# Ground tiles
# ----------------------------------------------------------------------------------------------

def hnoise(x, y, seed=0):
    n = (x * 374761393 + y * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


GRASS = {
    "spring": [(118, 182, 88), (108, 172, 80), (128, 192, 96), (100, 164, 76)],
    "summer": [(96, 160, 72), (88, 150, 66), (104, 170, 78), (80, 142, 62)],
    "autumn": [(150, 150, 72), (140, 140, 64), (160, 156, 78), (128, 132, 58)],
    "winter": [(226, 236, 246), (214, 227, 240), (236, 244, 252), (204, 220, 236)],
}
BLADE = {
    "spring": (78, 140, 62), "summer": (66, 122, 54), "autumn": (176, 118, 50), "winter": (170, 192, 218),
}


def grass_tile(season, variant):
    cols = GRASS[season]
    base = cols[variant % 4]
    img = Image.new("RGBA", (16, 16), base + (255,))
    px = img.load()
    seed = hash((season, variant)) & 0xFFFF
    for y in range(16):
        for x in range(16):
            r = hnoise(x, y, seed)
            if r < 0.16:
                c = cols[(variant + 1) % 4]
                px[x, y] = c + (255,)
            elif r < 0.24:
                c = cols[(variant + 2) % 4]
                px[x, y] = c + (255,)
    rnd = random.Random(seed)
    for _ in range(3):
        x, y = rnd.randrange(1, 15), rnd.randrange(2, 15)
        px[x, y] = BLADE[season] + (255,)
        px[x, y - 1] = BLADE[season] + (255,)
    return img


def decor_tile(kind, season):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = img.load()
    rnd = random.Random(kind * 7 + len(season))
    if kind == 0:  # grass tuft
        c = BLADE[season]
        dark = tuple(max(0, v - 28) for v in c)
        for bx in (5, 8, 10):
            h = rnd.randrange(3, 6)
            for k in range(h):
                d[bx + (k // 3), 12 - k] = (c if k > 0 else dark) + (255,)
    elif kind in (1, 2):  # flowers
        pal = {"spring": [(255, 224, 120), (255, 255, 255), (250, 150, 190)],
               "summer": [(255, 214, 90), (255, 255, 255), (170, 150, 250)],
               "autumn": [(220, 130, 60), (200, 90, 50), (240, 200, 90)],
               "winter": [(255, 255, 255), (200, 220, 245), (255, 255, 255)]}[season]
        for _ in range(3 if kind == 1 else 4):
            x, y = rnd.randrange(2, 14), rnd.randrange(3, 14)
            c = pal[rnd.randrange(3)]
            d[x, y] = c + (255,)
            if season != "winter":
                d[x, y + 1] = (60, 120, 50, 255)
    elif kind == 3:  # pebbles
        for _ in range(3):
            x, y = rnd.randrange(2, 13), rnd.randrange(3, 13)
            d[x, y] = (150, 146, 140, 255)
            d[x + 1, y] = (176, 172, 164, 255)
            d[x, y + 1] = (110, 106, 100, 255)
    return img


ROADS = {
    "dirt": dict(base=[(158, 116, 74), (148, 106, 66), (166, 124, 82), (138, 98, 60)], edge=(112, 78, 48), speck=(120, 86, 52), hi=(184, 144, 100)),
    "gravel": dict(base=[(158, 150, 138), (148, 140, 128), (168, 160, 148), (138, 130, 118)], edge=(104, 98, 90), speck=(120, 114, 104), hi=(196, 190, 178)),
    "paved": dict(base=[(170, 166, 160), (160, 156, 150), (178, 174, 168), (150, 146, 140)], edge=(96, 92, 90), speck=(130, 126, 122), hi=(208, 204, 196)),
}


def road_tile(kind, mask, tx, ty):
    spec = ROADS[kind]
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    N, E, S, W = mask & 1, mask & 2, mask & 4, mask & 8
    for y in range(16):
        for x in range(16):
            # distance to the nearest exposed side
            dist = 99.0
            if not N: dist = min(dist, y)
            if not S: dist = min(dist, 15 - y)
            if not W: dist = min(dist, x)
            if not E: dist = min(dist, 15 - x)
            # rounded exposed corners
            for (ex, ey, cx, cy) in ((not W and not N, 0, 0, 0), (not E and not N, 0, 15, 0), (not W and not S, 0, 0, 15), (not E and not S, 0, 15, 15)):
                if ex:
                    dd = math.hypot(x - cx, y - cy)
                    dist = min(dist, max(0.0, 3.4 - (4.6 - dd)) + 0.0) if dd < 4.6 else dist
            j = hnoise(x + tx * 16, y + ty * 16, 11) * 1.6
            d = dist - j
            if d < 0.2:
                continue
            if d < 1.4:
                px[x, y] = spec["edge"] + (255,)
                continue
            gx, gy = x + tx * 16, y + ty * 16
            r = hnoise(gx, gy, 5)
            col = spec["base"][int(hnoise(gx // 3, gy // 3, 9) * 4) % 4]
            if kind == "paved":
                # cobble pattern
                row = (gy // 4)
                off = 4 if row % 2 else 0
                if gy % 4 == 3 or (gx + off) % 8 == 7:
                    col = spec["speck"]
                elif r > 0.9:
                    col = spec["hi"]
            else:
                if r < 0.08:
                    col = spec["speck"]
                elif r > 0.95:
                    col = spec["hi"]
            px[x, y] = col + (255,)
    return img


def build_ground():
    seasons = ["spring", "summer", "autumn", "winter"]
    cols = 16
    rows = 4 + 4 + 3  # grass (4 seasons) / decor (4 seasons) / roads
    atlas = Image.new("RGBA", (cols * 16, rows * 16), (0, 0, 0, 0))
    for si, s in enumerate(seasons):
        for v in range(4):
            atlas.paste(grass_tile(s, v), (v * 16, si * 16))
        for k in range(4):
            atlas.paste(decor_tile(k, s), (k * 16, (4 + si) * 16))
    for ri, kind in enumerate(["dirt", "gravel", "paved"]):
        for m in range(16):
            atlas.paste(road_tile(kind, m, m, ri), (m * 16, (8 + ri) * 16))
    d = os.path.join(OUT, "ground")
    os.makedirs(d, exist_ok=True)
    atlas.save(os.path.join(d, "ground_atlas.png"))
    print("  wrote ground atlas", atlas.size)


# ----------------------------------------------------------------------------------------------

def scenes():
    for src, name in (("test_keyart", "keyart"), ("s_finale", "finale")):
        im = load(src)
        if im is None:
            continue
        im = im.convert("RGB").resize((1280, 720), Image.LANCZOS)
        os.makedirs(os.path.join(OUT, "scenes"), exist_ok=True)
        im.save(os.path.join(OUT, "scenes", name + ".png"))
        print("  wrote scene", name)
    og = load("s_og")
    if og is not None:
        og = og.convert("RGB")
        w, h = og.size
        target = 1200 / 630
        nh = int(w / target)
        top = (h - nh) // 2
        og = og.crop((0, top, w, top + nh)).resize((1200, 630), Image.LANCZOS)
        os.makedirs(os.path.join(os.path.dirname(OUT), "share"), exist_ok=True)
        og.save(os.path.join(os.path.dirname(OUT), "share", "og.png"))
        print("  wrote og cover")


def favicon():
    lamp = load("p_oillamp")
    if lamp is None:
        return
    lamp = fit(lamp, height=84)
    size = 128
    bg = Image.new("RGBA", (size, size), (22, 30, 58, 255))
    d = ImageDraw.Draw(bg)
    # warm glow
    for r in range(60, 0, -4):
        a = int(90 * (1 - r / 60))
        glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse((64 - r, 40 - r, 64 + r, 40 + r), fill=(255, 190, 90, a))
        bg.alpha_composite(glow)
    # ground
    d = ImageDraw.Draw(bg)
    d.rectangle((0, 104, size, size), fill=(60, 104, 66, 255))
    bg.alpha_composite(lamp, ((size - lamp.width) // 2, 112 - lamp.height))
    # snap to pixel look
    bg = bg.resize((64, 64), Image.NEAREST).resize((128, 128), Image.NEAREST)
    d = os.path.join(os.path.dirname(OUT), "share")
    os.makedirs(d, exist_ok=True)
    bg.save(os.path.join(d, "favicon.png"))
    print("  wrote favicon")


def main():
    print("Buildings")
    building("b_smallhouse", "home", width=100)
    building("test_house", "cottage", width=112)
    building("b_shop", "shop", width=128)
    building("b_lib0", "library_0", width=40)
    building("b_lib1", "library_1", width=88)
    building("test_library", "library_2", width=120)
    building("b_lib3", "library_3", width=176)
    building("b_school1", "school_1", width=84)
    building("test_school", "school_2", width=136)
    building("test_clinic", "clinic", width=110)
    building("b_comp1", "computer_1", width=112)
    building("b_comp2", "computer_2", width=150)
    building("b_tower", "tower", height=150)
    building("b_market", "market", width=150)
    building("b_construction", "plot", width=76)
    print("Props")
    building("p_oillamp", "oil_lamp", height=66, sub="props")
    building("p_elamp", "electric_lamp", height=60, sub="props")
    building("p_pole", "power_pole", height=74, sub="props")
    building("p_well", "well", width=46, sub="props")
    sheet("p_sheetA", ["bench", "hay", "crates", "cart", "signpost", "barrier"],
          [(36, 0), (38, 0), (40, 0), (48, 0), (28, 0), (58, 0)])
    sheet("t_trees", ["tree_spring", "tree_summer", "tree_autumn", "tree_winter"],
          [(0, 104), (0, 104), (0, 104), (0, 104)], cols=4)
    sheet("t_misc", ["bush", "pine", "rocks", "flowers", "scarecrow", "mailbox"],
          [(30, 0), (0, 96), (40, 0), (30, 0), (0, 46), (0, 28)])
    sheet("t_animals", ["hen", "hen_peck", "chick", "cat", "dog", "goat"],
          [(14, 0), (14, 0), (8, 0), (14, 0), (18, 0), (24, 0)])
    sheet("f_plots", ["plot_0", "plot_1", "plot_2", "plot_3"], [(62, 0)] * 4, cols=4)
    print("Characters")
    for src, name, h in (("c_hero", "hero", 32), ("c_grandma", "grandma", 29), ("c_mother", "mother", 32),
                         ("c_shop", "shopkeeper", 32), ("c_child", "child", 23), ("c_farmer", "farmer", 33),
                         ("c_teacher", "teacher", 32), ("c_nurse", "doctor", 32), ("c_tech", "tech", 33),
                         ("c_asha", "asha", 27), ("c_hero_grown", "hero_grown", 34)):
        character(src, name, h)
    for src, name, h in (("c_hero_study", "hero_study", 30), ("c_asha_study", "asha_study", 26)):
        im = load(src)
        if im is not None:
            save(fit(im, height=h), "chars", name)
    print("Ground")
    build_ground()
    print("Scenes")
    scenes()
    favicon()


if __name__ == "__main__":
    main()
