#!/usr/bin/env python3
"""地形タイルのアトラス生成器（依存なし）。

16×16 のタイルを 1 枚のアトラス（assets/tiles/terrain.png）に並べる。Godot 側は
TileMapLayer を 2 倍で描く（スプライトと同じ解像感）。

行の構成（1 行 = 16 タイル = 256px）:
  0: 草のバリエーション（明るい組 6 種 + 暗い組 6 種）
  1: 土      のデュアルグリッド遷移 16 種（草の上に重ねる。草側は透明）
  2: 石畳    のデュアルグリッド遷移 16 種
  3: 砂      のデュアルグリッド遷移 16 種
  4: 水      のデュアルグリッド遷移 16 種（砂の上に重ねる）
  5: 全面タイルのバリエーション（土・石畳・砂・水 × 4 種。繰り返しを目立たなくする）

デュアルグリッド: 表示タイルは、ワールド格子の 4 隅（TL, TR, BL, BR）がその種別かどうかの
4 ビット（index = TL + TR*2 + BL*4 + BR*8）で決まる。隅の値を双一次補間した場に
しきい値を切ると、隅を抱き込む角丸の境界が自動で出る。境界がタイルの辺の中点を通るよう、
辺の近くでは揺らぎを 0 に落としてある（隣のタイルと必ず繋がる）。

実行: python3 tools/gen_tiles.py
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gen_sprites import Canvas, h, write_png  # noqa: E402

ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "assets", "tiles", "terrain.png")
PREVIEW = os.path.join(ROOT, "docs", "prototypes", "tiles-preview.png")

T = 16
COLS = 16
ROWS = 6
FULL_VARIANTS = 4

# くすんだ春の草地のパレット（Stardew 風に彩度を抑え、輪郭は暗いオリーブ）。
PAL = {
    "g_dark": h("456e3a"), "g_base": h("578b47"), "g_mid": h("649a52"), "g_light": h("7fb466"),
    "g_edge": h("3b5f33"), "clover": h("3e6b3a"),
    "fl_pink": h("e9a0b8"), "fl_white": h("f4efe3"), "fl_yellow": h("f0d35e"), "fl_blue": h("9fb9e6"),
    "d_dark": h("7a5f40"), "d_base": h("a4845c"), "d_light": h("bd9c6e"), "d_edge": h("63482f"),
    "c_dark": h("6f6a60"), "c_base": h("928c80"), "c_light": h("aea89a"), "c_gap": h("6b5740"), "c_edge": h("4f473d"),
    "s_dark": h("b9a071"), "s_base": h("d4c18f"), "s_light": h("e6d7a9"), "s_edge": h("9c8456"),
    "w_dark": h("4a7fb1"), "w_base": h("5e97c9"), "w_light": h("7fb3dc"), "w_glint": h("b9dcf1"), "w_edge": h("38689a"),
    "stone": h("8d8d85"), "stone_hi": h("b4b2a8"),
}


def speckle(cv, rng, base, alt, density, only_if=None):
    """base 色のピクセルを一定確率で alt 色に置き換える。"""
    for y in range(cv.h):
        for x in range(cv.w):
            c = cv.get(x, y)
            if c != base:
                continue
            if only_if is not None and not only_if(x, y):
                continue
            if rng.random() < density:
                cv.put(x, y, alt)


# --- 草 ---------------------------------------------------------------------

GRASS_DARK_SET = {
    "g_dark": h("3d6333"), "g_base": h("4d7f3f"), "g_mid": h("598e49"), "g_light": h("72a85b"),
}


def paint_grass(cv, rng, variant, dark=False):
    global PAL
    saved = PAL
    if dark:
        PAL = dict(PAL)
        PAL.update(GRASS_DARK_SET)
    try:
        _paint_grass(cv, rng, variant)
    finally:
        PAL = saved


def _paint_grass(cv, rng, variant):
    cv.rect(0, 0, T, T, PAL["g_base"])
    speckle(cv, rng, PAL["g_base"], PAL["g_mid"], 0.10)
    speckle(cv, rng, PAL["g_base"], PAL["g_dark"], 0.05)
    if variant == 1:  # 葉の束
        for _ in range(3):
            x = rng.randrange(1, T - 2)
            y = rng.randrange(2, T - 3)
            cv.rect(x, y, 1, 3, PAL["g_light"])
            cv.put(x + 1, y + 1, PAL["g_mid"])
            cv.put(x - 1, y + 2, PAL["g_dark"])
    elif variant == 2:  # クローバー
        for _ in range(2):
            x = rng.randrange(2, T - 2)
            y = rng.randrange(2, T - 2)
            for dx, dy in ((0, 0), (-1, 1), (1, 1), (0, 2)):
                cv.put(x + dx, y + dy, PAL["clover"])
            cv.put(x, y + 1, PAL["g_light"])
    elif variant == 3:  # 小さな花
        for col in (PAL["fl_pink"], PAL["fl_white"], PAL["fl_yellow"]):
            x = rng.randrange(2, T - 2)
            y = rng.randrange(2, T - 2)
            cv.put(x, y, col)
            cv.put(x - 1, y + 1, PAL["g_dark"])
            cv.put(x, y + 1, PAL["clover"])
    elif variant == 4:  # 小石
        x = rng.randrange(3, T - 5)
        y = rng.randrange(4, T - 4)
        cv.rect(x, y, 3, 2, PAL["stone"])
        cv.put(x + 1, y, PAL["stone_hi"])
        cv.rect(x, y + 2, 3, 1, PAL["g_dark"])
    elif variant == 5:  # 暗い草むら
        x = rng.randrange(2, T - 6)
        y = rng.randrange(3, T - 5)
        for i in range(5):
            cv.rect(x + i, y + (i % 2), 1, 3 - (i % 2), PAL["g_dark"])
        cv.put(x + 2, y - 1, PAL["g_dark"])


# --- 各地形の塗り（デュアルグリッドの A 側） --------------------------------------

def fill_dirt(cv, rng, mask):
    for y in range(T):
        for x in range(T):
            if mask[y][x]:
                cv.put(x, y, PAL["d_base"])
    speckle(cv, rng, PAL["d_base"], PAL["d_light"], 0.09)
    speckle(cv, rng, PAL["d_base"], PAL["d_dark"], 0.04)
    # 小石をひとつ。
    if rng.random() < 0.5:
        x = rng.randrange(2, T - 4)
        y = rng.randrange(2, T - 3)
        if all(mask[y + j][x + i] for i in range(3) for j in range(2)):
            cv.rect(x, y, 2, 1, PAL["d_light"])
            cv.rect(x, y + 1, 2, 1, PAL["d_dark"])


def fill_cobble(cv, rng, mask):
    for y in range(T):
        for x in range(T):
            if mask[y][x]:
                cv.put(x, y, PAL["c_gap"])
    # 石の配置は全タイル共通（隣と繋がるよう、石は辺をまたがない）。明暗はタイルごとに変える。
    stones = [
        (1, 1, 5, 3), (7, 1, 4, 3), (12, 1, 3, 3),
        (1, 5, 3, 3), (5, 5, 6, 3), (12, 5, 3, 3),
        (1, 9, 6, 3), (8, 9, 3, 3), (12, 9, 3, 3),
        (1, 13, 4, 2), (6, 13, 5, 2), (12, 13, 3, 2),
    ]
    for (sx, sy, sw, sh) in stones:
        shade = rng.random()
        base = PAL["c_base"] if shade < 0.6 else (PAL["c_light"] if shade < 0.8 else PAL["c_dark"])
        for y in range(sy, sy + sh):
            for x in range(sx, sx + sw):
                if not mask[y][x]:
                    continue
                corner = (x in (sx, sx + sw - 1)) and (y in (sy, sy + sh - 1))
                if corner:
                    continue
                c = base
                if y == sy and x > sx:
                    c = PAL["c_light"] if base != PAL["c_light"] else base
                elif y == sy + sh - 1 or x == sx + sw - 1:
                    c = PAL["c_dark"] if base != PAL["c_dark"] else PAL["c_edge"]
                cv.put(x, y, c)
    speckle(cv, rng, PAL["c_gap"], PAL["d_dark"], 0.25)
    speckle(cv, rng, PAL["c_gap"], PAL["g_dark"], 0.08)


def fill_sand(cv, rng, mask):
    for y in range(T):
        for x in range(T):
            if mask[y][x]:
                cv.put(x, y, PAL["s_base"])
    speckle(cv, rng, PAL["s_base"], PAL["s_light"], 0.12)
    speckle(cv, rng, PAL["s_base"], PAL["s_dark"], 0.08)
    if rng.random() < 0.4:
        x = rng.randrange(2, T - 3)
        y = rng.randrange(2, T - 3)
        if mask[y][x] and mask[y][x + 1]:
            cv.rect(x, y, 2, 1, PAL["stone"])
            cv.put(x, y + 1, PAL["s_dark"])


def fill_water(cv, rng, mask):
    for y in range(T):
        for x in range(T):
            if mask[y][x]:
                cv.put(x, y, PAL["w_base"])
    speckle(cv, rng, PAL["w_base"], PAL["w_dark"], 0.10)
    # 静的なきらめき（アニメの筋はシェーダ側）。
    for _ in range(2):
        x = rng.randrange(1, T - 3)
        y = rng.randrange(1, T - 1)
        if mask[y][x] and mask[y][x + 1] and mask[y][x + 2]:
            cv.rect(x, y, 3, 1, PAL["w_light"])
            cv.put(x + 1, y, PAL["w_glint"])


FILLS = {
    "dirt": (fill_dirt, PAL["d_edge"], None),
    "cobble": (fill_cobble, PAL["c_edge"], None),
    "sand": (fill_sand, PAL["s_edge"], None),
    "water": (fill_water, PAL["w_edge"], PAL["w_light"]),
}


def hash01(x, y, salt):
    v = math.sin(x * 12.9898 + y * 78.233 + salt * 37.719) * 43758.5453
    return v - math.floor(v)


def vnoise(px, py, salt, period=5.0):
    """滑らかな値ノイズ（period px の格子を滑らかに補間）。境界のうねりに使う。"""
    gx = px / period
    gy = py / period
    x0 = math.floor(gx)
    y0 = math.floor(gy)
    fx = gx - x0
    fy = gy - y0
    sx = fx * fx * (3 - 2 * fx)
    sy = fy * fy * (3 - 2 * fy)
    a = hash01(x0, y0, salt)
    b = hash01(x0 + 1, y0, salt)
    c = hash01(x0, y0 + 1, salt)
    d = hash01(x0 + 1, y0 + 1, salt)
    return (a * (1 - sx) + b * sx) * (1 - sy) + (c * (1 - sx) + d * sx) * sy


def dual_mask(index, salt):
    """4 隅の種別ビットから、16×16（＋1px の縁）の A 側マスクを作る。"""
    tl = index & 1
    tr = (index >> 1) & 1
    bl = (index >> 2) & 1
    br = (index >> 3) & 1

    def field(px, py, jitter):
        u = min(max((px + 0.5) / T, 0.0), 1.0)
        v = min(max((py + 0.5) / T, 0.0), 1.0)
        f = (1 - u) * (1 - v) * tl + u * (1 - v) * tr + (1 - u) * v * bl + u * v * br
        if jitter:
            # 辺の近くでは揺らぎを消して、境界が辺の中点を必ず通るようにする。
            edge = min(px, py, T - 1 - px, T - 1 - py)
            fade = min(1.0, edge / 3.0)
            f += (vnoise(px, py, salt) - 0.5) * 0.3 * fade
        return f

    inner = [[field(x, y, True) >= 0.5 for x in range(T)] for y in range(T)]
    # 輪郭判定用に 1px 外側（揺らぎなし＝隣タイルの辺の値）を持つ。
    outer = {}
    for y in range(-1, T + 1):
        for x in range(-1, T + 1):
            if 0 <= x < T and 0 <= y < T:
                outer[(x, y)] = inner[y][x]
            else:
                outer[(x, y)] = field(x, y, False) >= 0.5
    return inner, outer


def paint_dual(cv, rng, kind, index):
    fill, edge_color, hi_color = FILLS[kind]
    inner, outer = dual_mask(index, salt=index + {"dirt": 1, "cobble": 2, "sand": 3, "water": 4}[kind] * 100)
    fill(cv, rng, inner)
    # A 側の縁取り。B（透明）に接する A ピクセルを暗くする。
    for y in range(T):
        for x in range(T):
            if not inner[y][x]:
                continue
            if any(not outer[(x + dx, y + dy)] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                cv.put(x, y, edge_color)
            elif hi_color is not None and outer[(x, y - 1)] and not outer.get((x, y - 2), True):
                # 水は上側の縁の 1px 内側を明るくして、岸の泡を出す。
                cv.put(x, y, hi_color)


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    W = COLS * T
    H = ROWS * T
    atlas = Canvas(W, H)

    def blit(tile, col, row):
        for y in range(T):
            for x in range(T):
                c = tile.get(x, y)
                if c[3] != 0:
                    atlas.put(col * T + x, row * T + y, c)

    for v in range(6):
        cv = Canvas(T, T)
        paint_grass(cv, random.Random(500 + v), v)
        blit(cv, v, 0)
        cv = Canvas(T, T)
        paint_grass(cv, random.Random(600 + v), v, dark=True)
        blit(cv, 6 + v, 0)
    kinds = ["dirt", "cobble", "sand", "water"]
    for row, kind in enumerate(kinds, start=1):
        for index in range(16):
            cv = Canvas(T, T)
            paint_dual(cv, random.Random(1000 * row + index), kind, index)
            blit(cv, index, row)
    for k, kind in enumerate(kinds):
        for v in range(FULL_VARIANTS):
            cv = Canvas(T, T)
            paint_dual(cv, random.Random(9000 + k * 10 + v), kind, 15)
            blit(cv, k * FULL_VARIANTS + v, 5)

    w, hh, px = atlas.result()
    write_png(OUT, w, hh, px)
    print("wrote %s (%dx%d)" % (OUT, w, hh))

    # プレビュー: ×4 に拡大して市松背景に。
    S = 4
    pw, ph = w * S, hh * S
    out = []
    for y in range(ph):
        for x in range(pw):
            c = 60 if ((x // 16 + y // 16) % 2) else 74
            out.append((c, c, c + 4, 255))
    for y in range(hh):
        for x in range(w):
            c = px[y * w + x]
            if c[3] == 0:
                continue
            for j in range(S):
                for i in range(S):
                    out[(y * S + j) * pw + (x * S + i)] = (c[0], c[1], c[2], 255)
    write_png(PREVIEW, pw, ph, out)
    print("wrote preview %s (%dx%d)" % (PREVIEW, pw, ph))


if __name__ == "__main__":
    main()
