#!/usr/bin/env python3
"""火ラボ（熱源3段階）用のドット絵スプライト生成器（依存なし）。

tools/gen_sprites.py と同じ流儀：低解像度グリッドを PNG に書き出し、Godot 側は Nearest で整数倍に拡大する。
小物（薪・石・うちわ）は手描きグリッド、炎・煙・炉・ふいごは決定的な手続きで描く（フレーム数や
サイズ違いを量産するため）。乱数は使わない（再生成しても同じ絵になる）。

実行: python3 tools/gen_fire_sprites.py
出力: assets/sprites/fire_*.png ／ docs/prototypes/fire-sprites-preview.png
"""
import math
import os

from gen_sprites import h, render, scale, write_png

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "assets", "sprites")
PREVIEW = os.path.join(ROOT, "docs", "prototypes", "fire-sprites-preview.png")

PALETTE = {
    ".": (0, 0, 0, 0),
    " ": (0, 0, 0, 0),
    "o": h("241b22"),                      # 輪郭
    # 炎（外側→芯）
    "1": h("c9321a"), "2": h("f07a22"), "3": h("f6c43a"), "4": h("fff1b8"),
    # 熾火
    "E": h("7a2410"), "e": h("d9552a"),
    # 木
    "d": h("5e3a1c"), "D": h("8f5a2d"), "L": h("c58a4a"),
    # 石
    "r": h("8a8f96"), "R": h("5f656d"), "q": h("b3b7bd"),
    # 粘土・土
    "t": h("9a6a3f"), "T": h("6e4a2a"), "u": h("b8865a"), "x": h("2a1c14"), "X": h("1a110c"),
    # 金属（羽口）
    "m": h("7b7f88"), "M": h("4d5159"),
    # うちわ
    "f": h("e9c98f"), "F": h("c9a46c"),
    # 革（ふいご）
    "v": h("8a4a2e"), "V": h("5e3220"),
    # 煙・空気（半透明）
    "z": h("b0b0b0", 150), "Z": h("8c8c8c", 110),
    "a": h("d6ecff", 220), "A": h("9fcfff", 140),
}


class Canvas:
    """文字グリッドのキャンバス。手続き描画用。"""

    def __init__(self, w, hgt):
        self.w, self.h = w, hgt
        self.g = [["."] * w for _ in range(hgt)]

    def put(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = ch

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.g[y][x]
        return "."

    def rect(self, x, y, w, hgt, fill, outline=None):
        for yy in range(y, y + hgt):
            for xx in range(x, x + w):
                edge = xx in (x, x + w - 1) or yy in (y, y + hgt - 1)
                self.put(xx, yy, outline if (edge and outline) else fill)

    def ellipse(self, cx, cy, rx, ry, fill, outline=None):
        for yy in range(self.h):
            for xx in range(self.w):
                d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
                if d <= 1.0:
                    self.put(xx, yy, fill)
        if outline:
            # 先に縁を集めてから塗る（走査中に塗ると輪郭が内側へ連鎖する）。
            marks = [
                (xx, yy)
                for yy in range(self.h)
                for xx in range(self.w)
                if self.get(xx, yy) == fill
                and any(self.get(xx + dx, yy + dy) != fill for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            ]
            for xx, yy in marks:
                self.put(xx, yy, outline)

    def outline_all(self, ch="o"):
        """塗られた画素の外周に輪郭を足す。"""
        marks = []
        for yy in range(self.h):
            for xx in range(self.w):
                if self.get(xx, yy) == ".":
                    if any(self.get(xx + dx, yy + dy) not in (".", ch) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                        marks.append((xx, yy))
        for xx, yy in marks:
            self.put(xx, yy, ch)

    def rows(self):
        return ["".join(r) for r in self.g]


SPRITES = {}

# --- 手描きの小物 -------------------------------------------------------------

SPRITES["fire_log"] = [
    ".oooooooooooooo.",
    "oDDDDDDDDDDDDLLo",
    "oDdDDDdDDDdDDLdo",
    "oDDDdDDDdDDDLLLo",
    "oddddddddddddLdo",
    ".oooooooooooooo.",
]

SPRITES["fire_stone"] = [
    "...oooooo...",
    "..oqqqrrro..",
    ".oqqrrrrrro.",
    "oqrrrrrrrRRo",
    "orrrrrrRRRRo",
    "oRrrrRRRRRRo",
    ".oRRRRRRRRo.",
    "..oooooooo..",
]

SPRITES["fire_uchiwa"] = [
    "....oooooooo....",
    "..ooffffffffoo..",
    ".offfffffffffFo.",
    ".offfFffffFffFo.",
    "offffFffffFfffFo",
    "offffFffffFfffFo",
    "offfffFffFffffFo",
    "offfffFffFffffFo",
    ".offfffFFFfffFo.",
    ".oFfffffFffffFo.",
    "..ooFFFFFFFFoo..",
    "....ooooDooo....",
    ".......oDo......",
    ".......oDo......",
    ".......oDo......",
    ".......oDo......",
    ".......oDo......",
    ".......oDo......",
    ".......oDo......",
    ".......oDo......",
    ".......oDo......",
    ".......oDo......",
    "......oDDDo.....",
    "......oDDDo.....",
    ".......ooo......",
]

# --- 炎（手続き）：サイズ3種 × フレーム4 ---------------------------------------


def flame(w, hgt, frame, name):
    c = Canvas(w, hgt)
    cx = (w - 1) / 2.0
    phase = frame * (math.pi / 2.0)
    for yy in range(hgt):
        t = 1.0 - yy / float(hgt - 1)           # 0=根元, 1=先端
        half = (w * 0.5 - 1.0) * (1.0 - t) ** 0.75
        wob = math.sin(t * 7.0 + phase) * (1.2 * t)       # 先端ほど揺れる
        for xx in range(w):
            dx = xx - cx - wob
            if abs(dx) > half:
                continue
            core = abs(dx) / max(half, 0.01)      # 0=中心, 1=縁
            heat = (1.0 - core) * (1.0 - t * 0.6)
            ch = "1" if heat < 0.35 else "2" if heat < 0.62 else "3" if heat < 0.85 else "4"
            c.put(xx, yy, ch)
    c.outline_all("o")
    SPRITES[name] = c.rows()


for fr in range(4):
    flame(16, 14, fr, "fire_flame_s_%d" % fr)
    flame(20, 22, fr, "fire_flame_m_%d" % fr)
    flame(24, 34, fr, "fire_flame_l_%d" % fr)

# 熾火（火が小さいとき／消えかけ）
SPRITES["fire_ember"] = [
    "..oooo..oooo..oo",
    ".oEeEEooEeEEooEo",
    "oEEeEEEEEEeEEEEo",
    ".oooooooooooooo.",
]

# --- 煙・空気（手続き） ----------------------------------------------------------


def puff(size, fill, edge, name):
    c = Canvas(size, size)
    r = size / 2.0
    for yy in range(size):
        for xx in range(size):
            d = math.hypot(xx + 0.5 - r, yy + 0.5 - r)
            if d <= r - 0.4:
                c.put(xx, yy, fill if d < r - 1.6 else edge)
    SPRITES[name] = c.rows()


puff(8, "z", "Z", "fire_smoke_0")
puff(10, "z", "Z", "fire_smoke_1")
puff(12, "Z", "Z", "fire_smoke_2")
puff(6, "a", "A", "fire_air")

# --- 囲い炉（手続き）：土の壁・炉口・煙突 ---------------------------------------


def hearth():
    W, H = 72, 60
    c = Canvas(W, H)
    wall = 7
    # 本体
    c.rect(0, 16, W, H - 16, "t", "o")
    # 内側（炉の中は暗い）
    c.rect(wall, 16 + wall, W - wall * 2, H - 16 - wall, "x")
    c.rect(wall, 16 + wall, W - wall * 2, 1, "X")
    # 炉口の下縁（床）
    c.rect(0, H - 4, W, 4, "T", "o")
    # 煙突
    c.rect(28, 0, 16, 18, "t", "o")
    c.rect(31, 1, 10, 16, "x")
    # 壁のハイライト／陰影と粘土の目地
    for yy in range(17, H - 4):
        c.put(1, yy, "u")
        c.put(W - 2, yy, "T")
    for xx in range(1, W - 1):
        c.put(xx, 17, "u")
    for yy in range(20, H - 6, 6):
        for xx in range(2, wall - 1, 1):
            if (xx + yy // 6) % 3 == 0:
                c.put(xx, yy, "T")
                c.put(W - 1 - xx, yy + 2, "T")
    SPRITES["fire_hearth"] = c.rows()


hearth()

# --- ふいご炉（手続き）：粘土のドームと炉口・羽口の穴 ---------------------------


def furnace():
    W, H = 72, 64
    c = Canvas(W, H)
    c.ellipse(36, 34, 34, 30, "t", "o")
    # ハイライト（左上）
    for yy in range(6, 30):
        for xx in range(8, 30):
            if c.get(xx, yy) == "t" and ((xx - 36) ** 2 / 34.0 ** 2 + (yy - 34) ** 2 / 30.0 ** 2) < 0.8 and (xx + yy) % 5 == 0:
                c.put(xx, yy, "u")
    # 炉口（アーチ）
    c.ellipse(36, 44, 14, 16, "x", "X")
    c.rect(22, 44, 29, 20, "x")
    c.rect(22, 44, 1, 20, "X")
    c.rect(50, 44, 1, 20, "X")
    # 底の床
    c.rect(0, 60, W, 4, "T", "o")
    # 羽口の穴（左）
    c.rect(2, 40, 8, 5, "X", "o")
    SPRITES["fire_furnace"] = c.rows()


furnace()

SPRITES["fire_tuyere"] = [
    "oooooooooooooooooooooooo",
    "ommmmmmmmmmmmmmmmmmmmmmo",
    "oMMMMMMMMMMMMMMMMMMMMMMo",
    "oooooooooooooooooooooooo",
]

# --- ふいご（手続き）：開 / 中 / 閉 の3フレーム ----------------------------------


def bellows(frame):
    W, H = 36, 28
    c = Canvas(W, H)
    gap = [18, 11, 5][frame]             # 板と板の間
    top = H - 6 - gap                    # 上板の y
    # 蛇腹（革）：上下の板の間を台形で埋め、ひだを縦線で
    for yy in range(top + 3, H - 5):
        t = (yy - top) / float(max(gap, 1))
        bulge = int(2 * math.sin(t * math.pi * 3) ** 2)
        x0, x1 = 3 - bulge, 30 + bulge
        for xx in range(x0, x1 + 1):
            c.put(xx, yy, "v")
        c.put(x0, yy, "V")
        c.put(x1, yy, "V")
    for xx in range(6, 30, 6):
        for yy in range(top + 3, H - 5):
            if c.get(xx, yy) == "v":
                c.put(xx, yy, "V")
    # 板（下・上）と取っ手
    c.rect(1, H - 6, 32, 4, "D", "o")
    c.rect(1, top, 32, 4, "L", "o")
    c.rect(15, top - 5, 4, 6, "D", "o")
    # 送風口（右）
    c.rect(32, H - 9, 4, 4, "m", "o")
    c.outline_all("o")
    SPRITES["fire_bellows_%d" % frame] = c.rows()


for fr in range(3):
    bellows(fr)


def main():
    os.makedirs(OUT, exist_ok=True)
    rendered = {}
    for name, rows in SPRITES.items():
        w, hh, px = render(name, rows, PALETTE)
        write_png(os.path.join(OUT, name + ".png"), w, hh, px)
        rendered[name] = (w, hh, px)
        print("wrote %s.png (%dx%d)" % (name, w, hh))

    # プレビュー（×4 で暗い市松に並べる）
    S = 4
    pad = 6
    names = list(rendered.keys())
    cell_w = max(w for w, _, _ in rendered.values()) * S + pad * 2
    cell_h = max(hh for _, hh, _ in rendered.values()) * S + pad * 2
    cols = 6
    rows_n = (len(names) + cols - 1) // cols
    PW, PH = cell_w * cols, cell_h * rows_n
    canvas = []
    for y in range(PH):
        for x in range(PW):
            cc = 40 if ((x // 8 + y // 8) % 2) else 52
            canvas.append((cc, cc, cc + 4, 255))
    for i, name in enumerate(names):
        w, hh, px = rendered[name]
        sw, sh, spx = scale(w, hh, px, S)
        cx = (i % cols) * cell_w + (cell_w - sw) // 2
        cy = (i // cols) * cell_h + (cell_h - sh) // 2
        for yy in range(sh):
            for xx in range(sw):
                r, g, b, a = spx[yy * sw + xx]
                if a == 0:
                    continue
                bg = canvas[(cy + yy) * PW + (cx + xx)]
                k = a / 255.0
                canvas[(cy + yy) * PW + (cx + xx)] = (
                    int(r * k + bg[0] * (1 - k)), int(g * k + bg[1] * (1 - k)), int(b * k + bg[2] * (1 - k)), 255)
    write_png(PREVIEW, PW, PH, canvas)
    print("wrote preview %s (%dx%d)" % (PREVIEW, PW, PH))


if __name__ == "__main__":
    main()
