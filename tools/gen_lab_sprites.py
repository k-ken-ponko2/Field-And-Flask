#!/usr/bin/env python3
"""錬金ラボ用ドット絵（ポーションクラフト寄せ・依存なし）。

画風の約束（Potion Craft ＝ 中世写本／木版画の雰囲気をドット絵で）:
  - 輪郭は黒ではなく濃いセピアのインク（"o"）。太さ 1px、角は落とす
  - 陰影はグラデーションではなく **ハッチング（市松・斜線の点打ち）**
  - 色は羊皮紙・木・鉄・銅・革の土色に絞り、彩度は低め。液体と炎だけ少し鮮やか
  - 物は少し大きめ（24〜48px）に描き、Godot 側で Nearest 拡大（3〜4×）
gen_sprites.py の流儀（1文字=1ピクセル）。乱数は使わない。

実行: python3 tools/gen_lab_sprites.py
出力: assets/sprites/lab_*.png ／ docs/prototypes/lab-sprites-preview.png
"""
import math
import os

from gen_sprites import h, render, scale, write_png

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "assets", "sprites")
PREVIEW = os.path.join(ROOT, "docs", "prototypes", "lab-sprites-preview.png")

PALETTE = {
    ".": (0, 0, 0, 0), " ": (0, 0, 0, 0),
    "o": h("2b1d14"),                                   # インク（輪郭・ハッチ）
    "p": h("e8d7ae"), "P": h("dcc99e"), "n": h("cbb37f"),  # 羊皮紙
    "d": h("5c3a1b"), "D": h("8a5a2b"), "L": h("b8864f"),  # 木
    "i": h("3a3a40"), "I": h("5b5b63"), "s": h("8c8c94"),  # 鉄
    "c": h("b87333"), "C": h("7d4a1f"), "k": h("e0a060"),  # 銅
    "g": h("cfe3e8", 210), "G": h("8fb3bd"),               # ガラス
    "w": h("5a8fb0"), "W": h("3b6a8a"), "b": h("7fb08a"),  # 液体（水・釜の中身）
    "v": h("8a4a2e"), "V": h("5e3220"),                    # 革
    "1": h("b8321c"), "2": h("e2742a"), "3": h("f0b53a"), "4": h("f8e3a0"),  # 炎
    "h": h("5f7a3a"), "H": h("3f5526"), "e": h("8fb05a"),  # 緑（緑礬・薬草）
    "r": h("a63a2b"), "R": h("6e2419"),                    # 赤
    "y": h("d9b43a"), "Y": h("9a7a22"),                    # 黄・金
    "x": h("f5efe0"), "X": h("d9d2c0"),                    # 白（石灰・ハイライト）
}


class Canvas:
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

    def rect(self, x, y, w, hgt, fill):
        for yy in range(y, y + hgt):
            for xx in range(x, x + w):
                self.put(xx, yy, fill)

    def ellipse(self, cx, cy, rx, ry, fill):
        for yy in range(self.h):
            for xx in range(self.w):
                if ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.put(xx, yy, fill)

    def hatch(self, pred, ch="o", step=3, phase=0):
        """pred(x,y,current) が真の画素に斜線ハッチを打つ。"""
        for yy in range(self.h):
            for xx in range(self.w):
                cur = self.get(xx, yy)
                if cur != "." and pred(xx, yy, cur) and (xx + yy + phase) % step == 0:
                    self.put(xx, yy, ch)

    def outline(self, ch="o"):
        marks = [
            (xx, yy)
            for yy in range(self.h)
            for xx in range(self.w)
            if self.get(xx, yy) == "."
            and any(self.get(xx + dx, yy + dy) not in (".", ch) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        ]
        for xx, yy in marks:
            self.put(xx, yy, ch)

    def rows(self):
        return ["".join(r) for r in self.g]


SPRITES = {}


def put_sprite(name, canvas):
    SPRITES[name] = canvas.rows()


# --- 羊皮紙タイル（マップ背景、32x32 でシームレスに並ぶ） --------------------------


def parchment():
    c = Canvas(32, 32)
    c.rect(0, 0, 32, 32, "p")
    # 紙の繊維：ごく薄い斑を決定的に散らす（並べても継ぎ目が出ないよう周期的に）
    for yy in range(32):
        for xx in range(32):
            v = (xx * 7 + yy * 13) % 37
            u = (xx * 11 + yy * 5) % 23
            if v == 0 or (u == 0 and v % 2 == 0):
                c.put(xx, yy, "P")
            if v == 19 and u == 7:
                c.put(xx, yy, "n")
    put_sprite("lab_parchment", c)


parchment()

# --- 大釜（鉄・三脚・中身） ---------------------------------------------------------


def cauldron():
    c = Canvas(44, 34)
    # 胴（下すぼまりの楕円）
    c.ellipse(22, 17, 19, 12, "I")
    c.rect(3, 6, 38, 10, "I")
    # 縁（厚い）
    c.rect(1, 4, 42, 4, "s")
    c.rect(1, 4, 42, 1, "x")
    # 中身（液面）
    c.ellipse(22, 7.5, 17, 2.6, "b")
    c.rect(5, 7, 34, 1, "w")
    # 脚
    for x in (6, 21, 36):
        c.rect(x, 27, 3, 7, "i")
    # 取っ手
    c.rect(0, 9, 2, 5, "i")
    c.rect(42, 9, 2, 5, "i")
    # 陰影：右下にハッチ、左上にハイライト
    c.hatch(lambda x, y, ch: ch == "I" and x > 28 and y > 12, "i", 3)
    c.hatch(lambda x, y, ch: ch == "I" and x < 12 and 9 < y < 18, "s", 3)
    c.outline()
    put_sprite("lab_cauldron", c)


cauldron()

# --- ふいご（革の蛇腹＋木の柄）：開 / 閉 -----------------------------------------------


def teardrop(c, cx, cy, r, tip_x, fill):
    """左が丸く右が尖る涙滴（上から見たふいご）。"""
    for xx in range(int(cx - r), int(tip_x) + 1):
        if xx <= cx:
            half = math.sqrt(max(0.0, r * r - (xx - cx) ** 2))
        else:
            u = (xx - cx) / float(tip_x - cx)
            half = r * max(0.0, 1.0 - u) ** 0.75
        for yy in range(int(round(cy - half)), int(round(cy + half)) + 1):
            c.put(xx, yy, fill)


def bellows(frame):
    c = Canvas(44, 26)
    cy = 13
    # 革の袋（下）。閉じると板に隠れて細い縁だけ見える
    teardrop(c, 14, cy, 11, 37, "v")
    c.hatch(lambda x, y, ch: ch == "v", "V", 2)
    # 木の板（上）。開いているときは小さく見え、革の縁が広く出る
    board_r = [8.0, 10.0][frame]
    teardrop(c, 14, cy, board_r, 35 - (0 if frame else 1), "D")
    # 板の木目とハイライト
    for xx in range(5, 32, 1):
        if c.get(xx, cy - 2) == "D" and xx % 5 in (0, 1):
            c.put(xx, cy - 2, "d")
        if c.get(xx, cy + 3) == "D" and xx % 6 in (2, 3):
            c.put(xx, cy + 3, "d")
        if c.get(xx, cy - int(board_r) + 1) == "D":
            c.put(xx, cy - int(board_r) + 1, "L")
    # 取っ手（左）と送風口（右・銅）
    c.rect(0, cy - 2, 4, 5, "D")
    c.rect(0, cy - 2, 4, 1, "L")
    c.rect(37, cy - 2, 7, 5, "c")
    c.rect(37, cy - 2, 7, 1, "k")
    c.hatch(lambda x, y, ch: ch == "c" and y > cy, "C", 2)
    c.outline()
    put_sprite("lab_bellows_%d" % frame, c)


bellows(0)
bellows(1)

# --- 道具（手描き） ------------------------------------------------------------------

# かき混ぜ棒（長い木べら）。
SPRITES["lab_spoon"] = [
    "........oo",
    ".......oLo",
    ".......oLo",
    "......oLDo",
    "......oLDo",
    "......oLDo",
    ".....oLDo.",
    ".....oLDo.",
    ".....oLDo.",
    "....oLDo..",
    "....oLDo..",
    "....oLDo..",
    "...oLDo...",
    "...oLDo...",
    "...oLDo...",
    "..oLDo....",
    "..oLDo....",
    ".oLDDDo...",
    "oLDDDDDo..",
    "oLDdDDDo..",
    "oDDDdDDo..",
    "oDDDDdo...",
    ".oDDDo....",
    "..ooo.....",
]

# ひしゃく（木の柄＋銅の椀、水入り）。
SPRITES["lab_ladle"] = [
    "..............oo",
    ".............oLo",
    ".............oLo",
    "............oLDo",
    "............oLDo",
    "...........oLDo.",
    "...........oLDo.",
    "..........oLDo..",
    "..........oLDo..",
    ".........oLDo...",
    ".........oLDo...",
    "........oLDo....",
    "..oooooooooo....",
    ".okwwwwwwwwco...",
    "ocwwwwwwwwwwco..",
    "ocwwwwwwwwwwco..",
    ".oCcccccccCCo...",
    "..oCCCCCCCCo....",
    "...oooooooo.....",
]

# 蒸留器（銅のアランビック＋ガラスの受け器）。
SPRITES["lab_alembic"] = [
    "........oooo..........",
    ".......okkcco.........",
    "......okccccco........",
    "......occcccCoooooo...",
    "......occcccCocccccoo.",
    ".......occcCo.oooooco.",
    "........oooo.......co.",
    ".........oco.......co.",
    ".........oco.......co.",
    "........occco......co.",
    ".......ocCCCCo.....co.",
    "......occCCCCCo....co.",
    ".....ocCCCCCCCCo..ogo.",
    ".....ocCCCCCCCCo.oggo.",
    "......ooCCCCCoo.ogggGo",
    "........ooooo...ogwwGo",
    "................ogwwGo",
    ".................oGGo.",
    "..................oo..",
]

# 瓶（丸底フラスコ＋コルク）。
SPRITES["lab_bottle"] = [
    ".....oooo.....",
    ".....oLDo.....",
    ".....oLDo.....",
    "....ogggGo....",
    "....ogggGo....",
    "....ogggGo....",
    "...ogggggGo...",
    "..oggggggGGo..",
    ".ogxggggggGGo.",
    ".ogxggggggGGo.",
    "ogxgggggggGGGo",
    "oggggggggggGGo",
    "ogwwwwwwwwwWGo",
    "ogwwwwwwwwwWGo",
    ".oWwwwwwwwWGo.",
    "..oWWwwwwWWo..",
    "...ooWWWWoo...",
    ".....oooo.....",
]

# --- マップ用アイコン（インク描き） ------------------------------------------------------

# マーカー（インクの泡／しずく）。
SPRITES["lab_marker"] = [
    "...oooo...",
    "..oyyyyo..",
    ".oyxxyyyo.",
    "oyxyyyyyyo",
    "oyyyyyyYyo",
    "oyyyyyYYyo",
    "oyyyyYYYyo",
    ".oyyYYYYo.",
    "..oYYYYo..",
    "...oooo...",
]

# 目標（インクの八芒星、羊皮紙の上に置く）。
SPRITES["lab_target"] = [
    "......oo......",
    "......oo......",
    "..o...oo...o..",
    "...o.oyyo.o...",
    "....oyyyyo....",
    "....oyyyyo....",
    "oooyyyyyyyyooo",
    "oooyyyyyyyyooo",
    "....oyyyyo....",
    "....oyyyyo....",
    "...o.oyyo.o...",
    "..o...oo...o..",
    "......oo......",
    "......oo......",
]

# 暴走域（インクのドクロ）。
SPRITES["lab_hazard"] = [
    "....oooooo....",
    "..oorrrrrroo..",
    ".orrrrrrrrrro.",
    ".orrrrrrrrrro.",
    "orrookrrrookro",
    "orrokkrrrokkro",
    "orrrrrrrrrrrro",
    ".orrrrorrrrro.",
    ".orrrrrrrrrro.",
    "..oorrrrrroo..",
    "...orroorro...",
    "...orroorro...",
    "....oooooo....",
    "..............",
]

# 棚板（素材棚）。横に並べて使う。
SPRITES["lab_shelf"] = [
    "oooooooooooooooooooooooooooooooooooooooooooooooo",
    "oLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLo",
    "oDDDDDDDdDDDDDDDDDDDDdDDDDDDDDDDDDdDDDDDDDDDDDDDo",
    "oDDdDDDDDDDDDDdDDDDDDDDDDDDdDDDDDDDDDDDDDdDDDDDDo",
    "odddddddddddddddddddddddddddddddddddddddddddddddo",
    "oooooooooooooooooooooooooooooooooooooooooooooooo",
    "..oddo..................................oddo....",
    "..oddo..................................oddo....",
]

# --- 素材アイコン（木版画風、20x20） ----------------------------------------------------

# 緑礬（緑の結晶の房）。
SPRITES["lab_ing_vitriol"] = [
    "........o...........",
    ".......oeo..........",
    "......oeeho.........",
    "......oehho....o....",
    ".....oeehhho..oeo...",
    ".....oehhhHo.oeeho..",
    "....oeehhhHHoehhho..",
    "....oehhhhHHohhhHo..",
    "...oeehhhhHHHhhhHo..",
    "...oehhhhHHHHhhHHo..",
    "...oehhhHHHHHhHHHo..",
    "..oeehhhHHHHHHHHHo..",
    "..oehhhHHHHHHHHHo...",
    "..oehhHHHHHHHHHHo...",
    "..ohhHHHHHHHHHHo....",
    "...oHHHHHHHHHHo.....",
    "....oHHHHHHHHo......",
    ".....oooooooo.......",
    "....................",
    "....................",
]

# 石灰（白い塊、ひびのインク）。
SPRITES["lab_ing_lime"] = [
    "....................",
    "......ooooooo.......",
    "....ooxxxxxxxoo.....",
    "...oxxxxxxxxxxxo....",
    "..oxxxxxoxxxxxxxo...",
    "..oxxxxoxxxxxxxxxo..",
    ".oxxxxoxxxxxxXxxxo..",
    ".oxxxxxxxxxxXXxxxxo.",
    ".oxxxxxxxxxXXXxxxxo.",
    ".oxxxxxxxxxXXXXxxxo.",
    ".oxXxxxxxxXXXXXxxxo.",
    ".oxXXxxxxXXXXXXxxxo.",
    "..oXXXxxXXXXXXXxxo..",
    "..oXXXXXXXXXXXXXxo..",
    "...oXXXXXXXXXXXXo...",
    "....ooXXXXXXXXoo....",
    "......oooooooo......",
    "....................",
    "....................",
    "....................",
]

# 水（ガラスの小瓶）。
SPRITES["lab_ing_water"] = [
    "........oooo........",
    "........oLDo........",
    "........oLDo........",
    ".......ogggGo.......",
    ".......ogggGo.......",
    "......ogggggGo......",
    ".....ogxggggGGo.....",
    "....ogxgggggGGGo....",
    "....ogxggggggGGo....",
    "....ogggggggggGo....",
    "....ogwwwwwwwWGo....",
    "....ogwwwwwwwWGo....",
    "....ogwwwwwwwWGo....",
    "....ogwwwwwwwWGo....",
    ".....oWwwwwwWGo.....",
    "......oWWWWWWo......",
    ".......oooooo.......",
    "....................",
    "....................",
    "....................",
]

# 硫黄（黄色の塊）。
SPRITES["lab_ing_sulfur"] = [
    "....................",
    "....................",
    ".......ooooo........",
    ".....ooyyyyyoo......",
    "....oyyyyyyyyyo.....",
    "...oyyyyyyyyyyyo....",
    "..oyyyyyyyyyyyyyo...",
    "..oyyyyyyyYyyyyyo...",
    ".oyyyyyyyYYyyyyyyo..",
    ".oyyyyyyYYYYyyyyyo..",
    ".oyyyyyYYYYYYyyyyo..",
    ".oyyyyYYYYYYYYyyyo..",
    "..oyyYYYYYYYYYYyo...",
    "..oyYYYYYYYYYYYYo...",
    "...oYYYYYYYYYYYo....",
    "....ooYYYYYYYoo.....",
    "......ooooooo.......",
    "....................",
    "....................",
    "....................",
]

# --- 炎（釜の下、インク輪郭つき・2コマ） ----------------------------------------------


def flame(frame):
    w, hgt = 28, 18
    c = Canvas(w, hgt)
    cx = (w - 1) / 2.0
    phase = frame * math.pi * 0.7
    for yy in range(hgt):
        t = 1.0 - yy / float(hgt - 1)
        half = (w * 0.5 - 1.0) * (1.0 - t) ** 0.7
        wob = math.sin(t * 6.0 + phase) * 1.5 * t
        for xx in range(w):
            dx = xx - cx - wob
            if abs(dx) > half:
                continue
            core = abs(dx) / max(half, 0.01)
            heat = (1.0 - core) * (1.0 - t * 0.5)
            c.put(xx, yy, "1" if heat < 0.3 else "2" if heat < 0.6 else "3" if heat < 0.85 else "4")
    c.outline()
    put_sprite("lab_flame_%d" % frame, c)


flame(0)
flame(1)


def main():
    os.makedirs(OUT, exist_ok=True)
    rendered = {}
    for name, rows in SPRITES.items():
        w, hh, px = render(name, rows, PALETTE)
        write_png(os.path.join(OUT, name + ".png"), w, hh, px)
        rendered[name] = (w, hh, px)
        print("wrote %s.png (%dx%d)" % (name, w, hh))
    # プレビュー：羊皮紙の上に ×4 で並べる（実際の見え方に近づける）
    S = 4
    pad = 12
    names = list(rendered.keys())
    cell_w = max(w for w, _, _ in rendered.values()) * S + pad * 2
    cell_h = max(hh for _, hh, _ in rendered.values()) * S + pad * 2
    cols = 5
    rows_n = (len(names) + cols - 1) // cols
    PW, PH = cell_w * cols, cell_h * rows_n
    pw, ph, ppx = rendered["lab_parchment"]
    canvas = [ppx[(y // S % ph) * pw + (x // S % pw)][:3] + (255,) for y in range(PH) for x in range(PW)]
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
                canvas[(cy + yy) * PW + (cx + xx)] = (int(r * k + bg[0] * (1 - k)), int(g * k + bg[1] * (1 - k)), int(b * k + bg[2] * (1 - k)), 255)
    write_png(PREVIEW, PW, PH, canvas)
    print("wrote preview %s (%dx%d)" % (PREVIEW, PW, PH))


if __name__ == "__main__":
    main()
