#!/usr/bin/env python3
"""ドット絵スプライト生成器（依存なし）。

低解像度のピクセルグリッド（1文字=1ピクセル）から PNG を書き出す。
アセットは assets/sprites/ に native 解像度で出力し、Godot 側は Nearest で拡大する。
プレビュー（拡大した確認用の連結画像）も出力する。

実行: python3 tools/gen_sprites.py
"""
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "assets", "sprites")
PREVIEW = os.path.join(ROOT, "docs", "prototypes", "sprites-preview.png")

# --- 共通パレット（温かみのある工房＋自然色） ---
def h(s, a=255):
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)

PALETTE = {
    ".": (0, 0, 0, 0),        # 透明
    " ": (0, 0, 0, 0),        # 透明（スペースも隙間として扱う）
    "o": h("241b22"),         # 濃い輪郭
    # 肌・髪
    "s": h("f4c59a"), "S": h("d99f6e"),
    "k": h("55381f"), "K": h("6e4a2a"),
    "i": h("241b22"),         # 目
    # 服
    "b": h("4785bd"), "B": h("335f88"),
    "p": h("47424f"), "e": h("2f2119"),
    # 水
    "w": h("3a83c0"), "W": h("2a5f92"), "l": h("bfe6f5"),
    # 硫黄（黄）
    "y": h("e8c23a"), "Y": h("b8922a"), "j": h("fff2b0"),
    # 石灰（白灰）
    "c": h("e9e6dc"), "C": h("bcb6a6"),
    # 緑礬（緑結晶）
    "g": h("4f9d5a"), "G": h("357a44"), "n": h("bdf0c2"),
    # 石・敲石（灰）
    "r": h("8a8f96"), "R": h("5f656d"),
}

# --- スプライト定義（各行は同じ長さ） ---
SPRITES = {}

SPRITES["char_down"] = [
    "................",
    ".....oooooo.....",
    "....okkkkkko....",
    "...okkkkkkkko...",
    "...okksssskko...",
    "...okssssssko...",
    "...ossssssso...",
    "...ossisssiso..",
    "...osssssssso..",
    "...ossSssSsso..",
    "....osssssso...",
    "...obbbbbbbbo..",
    "..obbbbbbbbBBo.",
    ".osbbbbbbbbBBso",
    ".osbbbbbbbbBBso",
    ".osobbbbbbBoBso",
    "...obbbbbbBBo..",
    "...opppppppo...",
    "...opppoppp o..",
    "...opppoppo....",
    "...oppo opp o..",
    "..oeeeo oeeeo..",
    "..oeeeo oeeeo..",
    "................",
]

SPRITES["char_up"] = [
    "................",
    ".....oooooo.....",
    "....okkkkkko....",
    "...okkkkkkkko...",
    "...okkkkkkkko...",
    "...okkkkkkkko...",
    "...okkkkkkkko...",
    "...oKkkkkkKko..",
    "...okkkkkkkko..",
    "...osssssssso..",
    "....osssssso...",
    "...obbbbbbbbo..",
    "..oBBbbbbbbbbo.",
    ".osBBbbbbbbbso",
    ".osBBbbbbbbbso",
    ".osoBbbbbboobso",
    "...oBBbbbbbbo..",
    "...opppppppo...",
    "...opppoppp o..",
    "...opppoppo....",
    "...oppo opp o..",
    "..oeeeo oeeeo..",
    "..oeeeo oeeeo..",
    "................",
]

SPRITES["char_side"] = [
    "................",
    ".....oooooo.....",
    "....okkkkkko....",
    "...okkkkkkkko...",
    "...okksssssko...",
    "...okssssssso..",
    "...okssissso...",
    "...oksssssso...",
    "...okssSssso...",
    "....ossssso....",
    ".....ossso.....",
    "...obbbbbbo....",
    "..obbbbbbbbo...",
    "..sbbbbbbbBo...",
    "..sbbbbbbbBo...",
    "..sobbbbbbBo...",
    "...obbbbbBo....",
    "...oppppppo....",
    "...opppppo.....",
    "...oppppo......",
    "...opppo.......",
    "..oeeeeo.......",
    "..oeeeeo.......",
    "................",
]

SPRITES["item_water"] = [
    "................",
    ".......o........",
    ".......oo.......",
    "......owo.......",
    "......owWo......",
    ".....owwWo......",
    ".....owwWo......",
    "....owwwWWo.....",
    "....owlwWWo.....",
    "...owlwwWWo.....",
    "...owwwwWWWo....",
    "...owwwwwWWo....",
    "....owwwWWo.....",
    "....owwWWo......",
    ".....oooo.......",
    "................",
]

SPRITES["item_sulfur"] = [
    "................",
    "................",
    "......oooo......",
    ".....oyyjyo.....",
    "....oyjyyyYo....",
    "...oyyyyyyYYo...",
    "...oyjyyyyyYo...",
    "..oyyyyyyyyYYo..",
    "..oyyyyyyyyYYo..",
    "..oyYyyyyyYYYo..",
    "...oyyyyYYYYo...",
    "...oYYYYYYYo....",
    "....oooooo......",
    "................",
    "................",
    "................",
]

SPRITES["item_lime"] = [
    "................",
    "................",
    ".....oo.........",
    "....occo........",
    "...occcco..o....",
    "..occcccoocco...",
    "..occcccccccCo..",
    ".occccccccccCo..",
    ".occcccccccCCo..",
    ".occcccccCCCo...",
    "..occccCCCCo....",
    "..oCCCCCCCo.....",
    "...ooooooo......",
    "................",
    "................",
    "................",
]

SPRITES["item_vitriol"] = [
    "................",
    ".......o........",
    "......ono.......",
    "......ogo.......",
    ".....ogngo......",
    ".....ogggo......",
    "....ogngggo.....",
    "....ogggGGo.....",
    "...ogngggGGo....",
    "...ogggggGGo....",
    "....ogggGGo.....",
    ".....oggGo......",
    ".....ogGo.......",
    "......oo........",
    "................",
    "................",
]


# --- 歩行フレーム（idle の上半身に、脚を開いた/踏み出した脚部を合成） ---
FRONT_WALK_LEGS = [
    "...opppppppo...",
    "..oppo..oppo...",
    "..oppo..oppo...",
    ".oeeeo..oeeeo..",
    ".oeeeo..oeeeo..",
    "...............",
    "...............",
]
SIDE_WALK_LEGS = [
    "...oppppo......",
    "..oppppppo.....",
    ".oppo..oppo....",
    ".oeeo..oeeeo...",
    "........oeeeo..",
    "...............",
    "...............",
]
SPRITES["char_down_walk"] = SPRITES["char_down"][:17] + FRONT_WALK_LEGS
SPRITES["char_up_walk"] = SPRITES["char_up"][:17] + FRONT_WALK_LEGS
SPRITES["char_side_walk"] = SPRITES["char_side"][:17] + SIDE_WALK_LEGS


# =============================================================================
# フィールド装飾の手続きピクセルアート
#
# 木・岩・茂みなどは「低解像度の円の和集合」を光源方向で 3 段階に塗り分け、
# 1px の輪郭を付けて作る。手描きの ASCII と同じ PNG パイプラインで書き出し、
# Godot 側では Nearest の 2 倍で描く（キャラクターと解像感を揃える）。
# =============================================================================
import math
import random

PROP_COLORS = {
    "leaf_light": h("7ab85a"), "leaf_mid": h("4a8a3c"), "leaf_dark": h("2f5f2a"),
    "leaf_outline": h("1f3f1e"),
    "trunk": h("6b4a2c"), "trunk_hi": h("8a6540"), "trunk_lo": h("4a3220"),
    "rock_light": h("b8bcc2"), "rock_mid": h("8a8f96"), "rock_dark": h("5f656d"),
    "rock_outline": h("3c4047"),
    "grass_a": h("3f7a35"), "grass_b": h("5c9a46"), "grass_c": h("7ab85a"),
    "pink": h("e98fb0"), "pink_lo": h("c9648c"), "white": h("f7f3e8"), "yellow": h("f3d35a"),
    "blue": h("8fb5e9"), "center": h("f0b429"),
    "pad": h("4f9d4a"), "pad_hi": h("6fbf63"), "pad_lo": h("357a3a"),
    "reed": h("6d8f3a"), "reed_hi": h("9ab35a"), "reed_head": h("7a5a3a"),
    "wood": h("8c6239"), "wood_hi": h("b08457"), "wood_lo": h("5e3f23"),
    "glass": h("c7e3ec"), "glass_hi": h("f4fbfd"), "liquid": h("4f9d5a"),
    "cork": h("a67c52"), "bottle": h("3a83c0"),
}


class Canvas:
    """RGBA のピクセルキャンバス（行優先）。"""

    def __init__(self, w, hgt):
        self.w = w
        self.h = hgt
        self.px = [(0, 0, 0, 0)] * (w * hgt)

    def inside(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def get(self, x, y):
        return self.px[y * self.w + x] if self.inside(x, y) else (0, 0, 0, 0)

    def put(self, x, y, c):
        if self.inside(x, y):
            self.px[y * self.w + x] = c

    def rect(self, x, y, w, hgt, c):
        for j in range(y, y + hgt):
            for i in range(x, x + w):
                self.put(i, j, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for j in range(cy - ry, cy + ry + 1):
            for i in range(cx - rx, cx + rx + 1):
                dx = (i - cx) / rx
                dy = (j - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    self.put(i, j, c)

    def shaded_blobs(self, circles, light, mid, dark, rng, speck=0.07):
        """円の和集合を、左上からの光で 3 段階に塗る。"""
        for j in range(self.h):
            for i in range(self.w):
                best = None
                for (cx, cy, r) in circles:
                    dx = i + 0.5 - cx
                    dy = j + 0.5 - cy
                    d = math.hypot(dx, dy)
                    if d > r:
                        continue
                    s = (dy / r) * 0.75 + (dx / r) * 0.3
                    best = s if best is None else min(best, s)
                if best is None:
                    continue
                if best < -0.28:
                    c = light
                elif best > 0.32:
                    c = dark
                else:
                    c = mid
                roll = rng.random()
                if roll < speck:
                    c = light if c == mid else (mid if c == dark else c)
                self.put(i, j, c)

    def outline(self, c):
        """不透明ピクセルに隣接する透明ピクセルを輪郭色で埋める。"""
        targets = []
        for j in range(self.h):
            for i in range(self.w):
                if self.get(i, j)[3] != 0:
                    continue
                for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if self.get(i + dx, j + dy)[3] != 0:
                        targets.append((i, j))
                        break
        for (i, j) in targets:
            self.put(i, j, c)

    def result(self):
        return self.w, self.h, self.px


def prop_tree(variant):
    C = PROP_COLORS
    rng = random.Random(100 + variant)
    cv = Canvas(34, 46)
    # 幹（根元を少し広げる）。
    cv.rect(14, 28, 6, 16, C["trunk"])
    cv.rect(14, 28, 2, 16, C["trunk_hi"])
    cv.rect(18, 28, 2, 16, C["trunk_lo"])
    cv.rect(12, 42, 10, 2, C["trunk_lo"])
    cv.rect(12, 42, 3, 2, C["trunk_hi"])
    if variant == 0:
        circles = [(17, 17, 11), (10, 20, 8), (24, 20, 8), (17, 10, 8), (12, 13, 6), (22, 13, 6)]
    elif variant == 1:
        circles = [(17, 15, 12), (9, 21, 7), (25, 21, 7), (17, 8, 7), (17, 24, 9)]
    else:
        circles = [(17, 18, 10), (11, 22, 7), (23, 22, 7), (17, 11, 7)]
    cv.shaded_blobs(circles, C["leaf_light"], C["leaf_mid"], C["leaf_dark"], rng)
    cv.outline(C["leaf_outline"])
    return cv.result()


def prop_bush():
    C = PROP_COLORS
    rng = random.Random(7)
    cv = Canvas(22, 16)
    cv.shaded_blobs([(7, 9, 5), (14, 9, 5), (11, 7, 5), (11, 10, 4)],
                    C["leaf_light"], C["leaf_mid"], C["leaf_dark"], rng)
    for (x, y) in ((6, 8), (13, 10), (10, 6)):
        cv.put(x, y, C["pink_lo"])
    cv.outline(C["leaf_outline"])
    return cv.result()


def prop_rock(big):
    C = PROP_COLORS
    rng = random.Random(3 if big else 4)
    if big:
        cv = Canvas(22, 16)
        circles = [(11, 9, 7), (6, 10, 4), (16, 10, 4), (10, 7, 5)]
    else:
        cv = Canvas(12, 9)
        circles = [(6, 5, 4), (3, 6, 2), (9, 6, 2)]
    cv.shaded_blobs(circles, C["rock_light"], C["rock_mid"], C["rock_dark"], rng, speck=0.04)
    cv.outline(C["rock_outline"])
    return cv.result()


def prop_tuft():
    C = PROP_COLORS
    cv = Canvas(10, 8)
    blades = [(1, 3, "grass_a"), (3, 1, "grass_b"), (5, 2, "grass_c"), (7, 1, "grass_b"), (8, 4, "grass_a")]
    for (x, top, col) in blades:
        cv.rect(x, top, 1, 8 - top, C[col])
    cv.put(2, 2, C["grass_b"])
    cv.put(6, 1, C["grass_c"])
    return cv.result()


def prop_flower(color):
    C = PROP_COLORS
    cv = Canvas(7, 9)
    cv.rect(3, 4, 1, 5, C["grass_a"])
    cv.put(2, 6, C["grass_b"])
    cv.put(4, 7, C["grass_b"])
    petal = C[color]
    for (x, y) in ((3, 1), (2, 2), (4, 2), (3, 3)):
        cv.put(x, y, petal)
    cv.put(3, 2, C["center"] if color != "yellow" else C["pink_lo"])
    return cv.result()


def prop_lilypad():
    C = PROP_COLORS
    cv = Canvas(12, 8)
    cv.ellipse(6, 4, 5, 3, C["pad"])
    cv.ellipse(5, 3, 3, 1, C["pad_hi"])
    cv.rect(6, 1, 1, 3, (0, 0, 0, 0))
    cv.rect(7, 1, 1, 2, (0, 0, 0, 0))
    cv.rect(2, 6, 8, 1, C["pad_lo"])
    cv.put(3, 4, C["pink"])
    return cv.result()


def prop_reed():
    C = PROP_COLORS
    cv = Canvas(7, 18)
    cv.rect(3, 4, 1, 14, C["reed"])
    cv.rect(2, 10, 1, 7, C["reed_hi"])
    cv.rect(4, 12, 1, 6, C["reed"])
    cv.rect(1, 14, 1, 4, C["reed_hi"])
    cv.rect(2, 0, 3, 5, C["reed_head"])
    cv.put(2, 0, (0, 0, 0, 0))
    cv.put(4, 0, (0, 0, 0, 0))
    return cv.result()


def prop_pebble():
    C = PROP_COLORS
    cv = Canvas(4, 3)
    cv.rect(0, 1, 4, 2, C["rock_mid"])
    cv.rect(1, 0, 2, 1, C["rock_light"])
    cv.rect(0, 2, 4, 1, C["rock_dark"])
    return cv.result()


def prop_station():
    C = PROP_COLORS
    cv = Canvas(38, 30)
    # 脚と横木。
    cv.rect(6, 19, 3, 10, C["wood_lo"])
    cv.rect(29, 19, 3, 10, C["wood_lo"])
    cv.rect(6, 25, 26, 1, C["wood_lo"])
    # 天板。
    cv.rect(3, 15, 32, 5, C["wood"])
    cv.rect(3, 15, 32, 1, C["wood_hi"])
    cv.rect(3, 19, 32, 1, C["wood_lo"])
    # フラスコ。
    cv.rect(16, 1, 5, 2, C["cork"])
    cv.rect(17, 3, 3, 5, C["glass"])
    cv.ellipse(18, 11, 5, 4, C["glass"])
    cv.ellipse(18, 12, 4, 2, C["liquid"])
    cv.put(15, 9, C["glass_hi"])
    cv.put(15, 10, C["glass_hi"])
    # 小瓶。
    cv.rect(8, 7, 4, 8, C["bottle"])
    cv.rect(9, 5, 2, 2, C["cork"])
    cv.put(8, 8, C["glass_hi"])
    # 乳鉢と乳棒。
    cv.ellipse(29, 12, 4, 2, C["rock_mid"])
    cv.ellipse(29, 11, 3, 1, C["rock_dark"])
    cv.rect(31, 6, 1, 5, C["rock_light"])
    cv.rect(32, 5, 1, 2, C["rock_light"])
    cv.outline(C["wood_lo"])
    return cv.result()


def prop_mushroom():
    C = PROP_COLORS
    cap = h("c9643c")
    cap_hi = h("e8906a")
    stem = h("efe6d2")
    stem_lo = h("c9bda2")
    cv = Canvas(11, 9)
    # 大きいキノコ。
    cv.rect(1, 2, 6, 3, cap)
    cv.rect(2, 1, 4, 1, cap)
    cv.rect(2, 2, 2, 1, cap_hi)
    cv.put(5, 3, C["white"])
    cv.rect(3, 5, 2, 4, stem)
    cv.rect(4, 6, 1, 3, stem_lo)
    # 小さいキノコ。
    cv.rect(7, 5, 3, 2, cap)
    cv.put(7, 5, cap_hi)
    cv.rect(8, 7, 1, 2, stem)
    cv.outline(h("5e3f23"))
    return cv.result()


def prop_twig():
    C = PROP_COLORS
    cv = Canvas(12, 5)
    cv.rect(1, 2, 9, 1, C["wood_lo"])
    cv.rect(3, 1, 3, 1, C["wood"])
    cv.rect(7, 3, 2, 1, C["wood_lo"])
    cv.put(9, 1, C["wood"])
    cv.put(10, 2, C["wood"])
    cv.put(0, 2, C["wood"])
    return cv.result()


# --- 構造物・小物（構図用） ---------------------------------------------------

STRUCT_COLORS = {
    "post": h("7a5a36"), "post_hi": h("9c7a4e"), "post_lo": h("54391f"), "outline": h("3a2a18"),
    "iron": h("3c3c42"), "iron_hi": h("6a6a72"), "lamp": h("f6e2a0"), "lamp_hi": h("fff7d6"),
    "blossom_light": h("f6c9d9"), "blossom_mid": h("e9a0b8"), "blossom_dark": h("c97a97"), "blossom_edge": h("8f4f6a"),
    "barrel": h("8c6239"), "barrel_hi": h("b08457"), "barrel_lo": h("5e3f23"), "hoop": h("4a4a50"),
    "plank": h("b08457"), "plank_lo": h("8c6239"), "plank_hi": h("c99a66"),
    "grass_tall": h("5f9a4c"), "grass_tall_hi": h("8bc06d"), "grass_tall_lo": h("3f6b3a"),
    "ring": h("c9a06a"), "ring_lo": h("8a6a3e"),
}


def prop_fence_h():
    C = STRUCT_COLORS
    cv = Canvas(16, 16)
    cv.rect(0, 2, 3, 14, C["post"])
    cv.rect(0, 2, 1, 14, C["post_hi"])
    cv.rect(2, 2, 1, 14, C["post_lo"])
    cv.rect(0, 1, 3, 1, C["post_hi"])
    for y in (6, 11):
        cv.rect(3, y, 13, 2, C["post"])
        cv.rect(3, y, 13, 1, C["post_hi"])
    cv.outline(C["outline"])
    return cv.result()


def prop_fence_post():
    C = STRUCT_COLORS
    cv = Canvas(5, 16)
    cv.rect(1, 2, 3, 14, C["post"])
    cv.rect(1, 2, 1, 14, C["post_hi"])
    cv.rect(3, 2, 1, 14, C["post_lo"])
    cv.rect(1, 1, 3, 1, C["post_hi"])
    cv.outline(C["outline"])
    return cv.result()


def prop_lamp_post():
    C = STRUCT_COLORS
    cv = Canvas(11, 34)
    cv.rect(4, 8, 3, 26, C["iron"])
    cv.rect(4, 8, 1, 26, C["iron_hi"])
    cv.rect(2, 32, 7, 2, C["iron"])
    cv.rect(1, 1, 9, 1, C["iron"])
    cv.rect(2, 2, 7, 6, C["lamp"])
    cv.rect(3, 3, 2, 2, C["lamp_hi"])
    cv.rect(2, 7, 7, 1, C["iron"])
    cv.rect(4, 0, 3, 1, C["iron"])
    cv.outline(C["outline"])
    return cv.result()


def prop_stump():
    C = PROP_COLORS
    S = STRUCT_COLORS
    cv = Canvas(18, 14)
    cv.ellipse(9, 10, 8, 3, C["trunk_lo"])
    cv.rect(2, 5, 14, 5, C["trunk"])
    cv.rect(2, 5, 3, 5, C["trunk_hi"])
    cv.ellipse(9, 5, 7, 3, C["trunk_hi"])
    cv.ellipse(9, 5, 5, 2, h("d9b68a"))
    cv.ellipse(9, 5, 3, 1, C["trunk_hi"])
    cv.put(9, 5, h("d9b68a"))
    cv.outline(S["outline"])
    return cv.result()


def prop_tree_blossom():
    C = PROP_COLORS
    S = STRUCT_COLORS
    rng = random.Random(77)
    cv = Canvas(34, 46)
    cv.rect(14, 28, 6, 16, C["trunk"])
    cv.rect(14, 28, 2, 16, C["trunk_hi"])
    cv.rect(18, 28, 2, 16, C["trunk_lo"])
    cv.rect(12, 42, 10, 2, C["trunk_lo"])
    circles = [(17, 16, 12), (9, 20, 8), (25, 20, 8), (17, 9, 8), (13, 24, 7), (22, 24, 7)]
    cv.shaded_blobs(circles, S["blossom_light"], S["blossom_mid"], S["blossom_dark"], rng, speck=0.12)
    cv.outline(S["blossom_edge"])
    return cv.result()


def prop_barrel():
    C = STRUCT_COLORS
    cv = Canvas(12, 16)
    cv.rect(1, 1, 10, 14, C["barrel"])
    cv.rect(1, 1, 3, 14, C["barrel_hi"])
    cv.rect(8, 1, 3, 14, C["barrel_lo"])
    cv.rect(0, 3, 12, 10, C["barrel"])
    cv.rect(0, 3, 3, 10, C["barrel_hi"])
    cv.rect(9, 3, 3, 10, C["barrel_lo"])
    for y in (4, 11):
        cv.rect(0, y, 12, 1, C["hoop"])
    cv.rect(2, 1, 8, 1, C["plank_hi"])
    cv.outline(C["outline"])
    return cv.result()


def prop_crate():
    C = STRUCT_COLORS
    cv = Canvas(14, 13)
    cv.rect(0, 1, 14, 12, C["plank"])
    cv.rect(0, 1, 14, 1, C["plank_hi"])
    cv.rect(0, 12, 14, 1, C["plank_lo"])
    cv.rect(0, 1, 1, 12, C["plank_hi"])
    cv.rect(13, 1, 1, 12, C["plank_lo"])
    for i in range(12):
        cv.put(1 + i, 2 + (i * 10) // 12, C["plank_lo"])
    cv.rect(0, 6, 14, 1, C["plank_lo"])
    cv.outline(C["outline"])
    return cv.result()


def prop_sign():
    C = STRUCT_COLORS
    cv = Canvas(14, 16)
    cv.rect(6, 8, 2, 8, C["post"])
    cv.rect(0, 1, 14, 8, C["plank"])
    cv.rect(0, 1, 14, 1, C["plank_hi"])
    cv.rect(0, 8, 14, 1, C["plank_lo"])
    cv.rect(2, 3, 10, 1, C["plank_lo"])
    cv.rect(2, 5, 7, 1, C["plank_lo"])
    cv.outline(C["outline"])
    return cv.result()


def prop_bench():
    C = STRUCT_COLORS
    cv = Canvas(22, 13)
    cv.rect(1, 1, 20, 3, C["plank"])
    cv.rect(1, 1, 20, 1, C["plank_hi"])
    cv.rect(0, 6, 22, 3, C["plank"])
    cv.rect(0, 6, 22, 1, C["plank_hi"])
    cv.rect(0, 8, 22, 1, C["plank_lo"])
    cv.rect(2, 4, 2, 2, C["post_lo"])
    cv.rect(18, 4, 2, 2, C["post_lo"])
    cv.rect(2, 9, 2, 4, C["post_lo"])
    cv.rect(18, 9, 2, 4, C["post_lo"])
    cv.outline(C["outline"])
    return cv.result()


def prop_tall_grass():
    C = STRUCT_COLORS
    cv = Canvas(14, 13)
    blades = [(1, 5), (3, 2), (5, 4), (7, 1), (9, 3), (11, 5), (12, 7)]
    for i, (x, top) in enumerate(blades):
        col = C["grass_tall_hi"] if i % 3 == 1 else (C["grass_tall_lo"] if i % 3 == 2 else C["grass_tall"])
        cv.rect(x, top, 1, 13 - top, col)
        cv.put(x + 1, top + 2, C["grass_tall"])
        if i % 2 == 0:
            cv.put(x - 1, top + 1, col)
    return cv.result()


def prop_bush_flower():
    C = PROP_COLORS
    S = STRUCT_COLORS
    rng = random.Random(8)
    cv = Canvas(22, 16)
    cv.shaded_blobs([(7, 9, 5), (14, 9, 5), (11, 7, 5), (11, 10, 4)],
                    C["leaf_light"], C["leaf_mid"], C["leaf_dark"], rng)
    for (x, y) in ((5, 7), (8, 10), (11, 5), (14, 8), (16, 11), (12, 12), (7, 12)):
        cv.put(x, y, S["blossom_mid"])
        cv.put(x + 1, y, S["blossom_light"])
    cv.outline(C["leaf_outline"])
    return cv.result()


def prop_flowerbed():
    C = PROP_COLORS
    S = STRUCT_COLORS
    cv = Canvas(16, 10)
    cv.rect(0, 4, 16, 6, C["wood_lo"])
    cv.rect(1, 5, 14, 4, h("7a5f40"))
    for i, x in enumerate((2, 5, 8, 11, 13)):
        col = [S["blossom_mid"], C["white"], C["yellow"], S["blossom_light"], C["blue"]][i % 5]
        cv.rect(x, 2, 1, 4, C["grass_a"])
        cv.put(x - 1, 1, col)
        cv.put(x + 1, 1, col)
        cv.put(x, 0, col)
        cv.put(x, 2, col)
        cv.put(x, 1, C["center"])
    cv.outline(S["outline"])
    return cv.result()


def generate_props():
    """名前 → (w, h, px)。Godot 側のファイル名（prop_*.png）と一致させる。"""
    out = {}
    for v in range(3):
        out["prop_tree_%s" % "abc"[v]] = prop_tree(v)
    out["prop_bush"] = prop_bush()
    out["prop_rock_a"] = prop_rock(True)
    out["prop_rock_b"] = prop_rock(False)
    out["prop_tuft"] = prop_tuft()
    for color in ("pink", "white", "yellow", "blue"):
        out["prop_flower_%s" % color] = prop_flower(color)
    out["prop_lilypad"] = prop_lilypad()
    out["prop_reed"] = prop_reed()
    out["prop_pebble"] = prop_pebble()
    out["prop_station"] = prop_station()
    out["prop_mushroom"] = prop_mushroom()
    out["prop_twig"] = prop_twig()
    out["prop_fence_h"] = prop_fence_h()
    out["prop_fence_post"] = prop_fence_post()
    out["prop_lamp_post"] = prop_lamp_post()
    out["prop_stump"] = prop_stump()
    out["prop_tree_blossom"] = prop_tree_blossom()
    out["prop_barrel"] = prop_barrel()
    out["prop_crate"] = prop_crate()
    out["prop_sign"] = prop_sign()
    out["prop_bench"] = prop_bench()
    out["prop_tall_grass"] = prop_tall_grass()
    out["prop_bush_flower"] = prop_bush_flower()
    out["prop_flowerbed"] = prop_flowerbed()
    return out


def render(name, rows, pal):
    hgt = len(rows)
    wid = max(len(r) for r in rows)
    padded = [i for i, r in enumerate(rows) if len(r) != wid]
    if padded:
        print("  [pad] %s: 右側を '.' で幅%dに補完した行 %s" % (name, wid, padded))
    rows = [r.ljust(wid, ".") for r in rows]
    px = []
    for r in rows:
        for ch in r:
            px.append(pal.get(ch, (255, 0, 255, 255)))
    return wid, hgt, px


def write_png(path, wid, hgt, px):
    def chunk(typ, data):
        c = typ + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    raw = bytearray()
    idx = 0
    for _y in range(hgt):
        raw.append(0)
        for _x in range(wid):
            r, g, b, a = px[idx]; idx += 1
            raw += bytes((r, g, b, a))
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", wid, hgt, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def scale(wid, hgt, px, s):
    out = []
    for y in range(hgt * s):
        for x in range(wid * s):
            out.append(px[(y // s) * wid + (x // s)])
    return wid * s, hgt * s, out


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    rendered = {}
    for name, rows in SPRITES.items():
        w, hh, px = render(name, rows, PALETTE)
        write_png(os.path.join(OUT, name + ".png"), w, hh, px)
        rendered[name] = (w, hh, px)
        print("wrote %s.png (%dx%d)" % (name, w, hh))
    for name, (w, hh, px) in generate_props().items():
        write_png(os.path.join(OUT, name + ".png"), w, hh, px)
        rendered[name] = (w, hh, px)
        print("wrote %s.png (%dx%d)" % (name, w, hh))

    # プレビュー（各スプライトを拡大して市松背景に並べる）
    S = 4
    pad = 8
    names = list(rendered.keys())
    cell_w = max(w for w, _, _ in rendered.values()) * S + pad * 2
    cell_h = max(hh for _, hh, _ in rendered.values()) * S + pad * 2 + 12
    cols = 6
    rows_n = (len(names) + cols - 1) // cols
    PW, PH = cell_w * cols, cell_h * rows_n
    canvas = []
    for y in range(PH):
        for x in range(PW):
            c = 60 if ((x // 8 + y // 8) % 2) else 74
            canvas.append((c, c, c + 4, 255))
    for i, name in enumerate(names):
        w, hh, px = rendered[name]
        sw, sh, spx = scale(w, hh, px, S)
        cx = (i % cols) * cell_w + (cell_w - sw) // 2
        cy = (i // cols) * cell_h + pad
        for yy in range(sh):
            for xx in range(sw):
                r, g, b, a = spx[yy * sw + xx]
                if a == 0:
                    continue
                canvas[(cy + yy) * PW + (cx + xx)] = (r, g, b, 255)
    write_png(PREVIEW, PW, PH, canvas)
    print("wrote preview %s (%dx%d)" % (PREVIEW, PW, PH))


if __name__ == "__main__":
    main()
