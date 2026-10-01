#!/usr/bin/env python3
"""プレイヤーキャラクターのスプライト生成器（依存なし）。

16×28 の体を「部位（髪・顔・胴・腕・脚）」に分けて Python で組み立て、
3 方向（下・上・横）× 4 フレームの歩行サイクルと、まばたき差分を書き出す。
手描きの ASCII と違い、部位ごとのオフセットでフレームを作るので動きが崩れない。

出力:
  assets/sprites/char_{down,up,side}_{0..3}.png   … 0=待機/接地, 1=左足前, 2=通過, 3=右足前
  assets/sprites/char_{down,side}_blink.png         … まばたき（目を閉じた待機）
  docs/prototypes/character-sheet.png               … 確認用シート（×6）
横向きは右向きで描き、左向きは Godot 側で flip_h する。

実行: python3 tools/gen_character.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gen_sprites import Canvas, h, write_png  # noqa: E402

ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "assets", "sprites")
SHEET = os.path.join(ROOT, "docs", "prototypes", "character-sheet.png")

# キャンバスは 18×30（16×28 の体＋輪郭 1px）。描画は (1, 1) を原点にする。
W, H = 18, 30
OX, OY = 1, 1

C = {
    "outline": h("2a1f1e"),
    "skin": h("f1c7a0"), "skin_sh": h("d9a177"), "blush": h("e9a0a8"),
    "hair": h("5a3a22"), "hair_hi": h("8a5f3a"), "hair_dk": h("3d2615"),
    "eye": h("2a1f1e"), "mouth": h("c98a6a"),
    "tunic": h("3b7f86"), "tunic_dk": h("2c5f66"), "tunic_hi": h("58a0a6"),
    "collar": h("efe6d2"), "belt": h("5a3b24"), "buckle": h("d9b35a"),
    "bag": h("8c6239"), "bag_dk": h("5e3f23"), "strap": h("6b4a2c"),
    "pants": h("4a4452"), "pants_dk": h("353040"),
    "boot": h("4c3222"), "boot_hi": h("6b4a30"),
    "frame": h("c99a4a"), "lens": h("7fd0d8"), "lens_hi": h("d9f6f8"), "lens_dk": h("4fa0aa"), "band": h("3d2615"),
}


class Body:
    """部位を描くヘルパ。dy は上半身の弾み（負で上）。"""

    def __init__(self):
        self.cv = Canvas(W, H)

    def px(self, x, y, c):
        self.cv.put(OX + x, OY + y, c)

    def rect(self, x, y, w, hgt, c):
        self.cv.rect(OX + x, OY + y, w, hgt, c)

    def row(self, y, xs, c):
        for x in xs:
            self.px(x, y, c)


# --- 頭 -------------------------------------------------------------------------

def head_down(b, dy, blink):
    y = dy
    # 髪のシルエット（後ろ髪 → 顔 → 前髪の順）。
    b.row(1 + y, range(5, 11), C["hair"])
    b.row(2 + y, range(4, 12), C["hair"])
    b.rect(3, 3 + y, 10, 2, C["hair"])
    b.rect(3, 5 + y, 1, 5, C["hair"])      # 左の横髪
    b.rect(12, 5 + y, 1, 5, C["hair"])     # 右の横髪
    b.px(3, 9 + y, C["hair_dk"])
    b.px(12, 9 + y, C["hair_dk"])
    b.row(2 + y, (5, 6), C["hair_hi"])
    # 顔。
    b.rect(4, 5 + y, 8, 7, C["skin"])
    b.row(11 + y, range(4, 12), C["skin_sh"])
    b.row(5 + y, (4, 5, 6, 9, 10, 11), C["hair"])  # 前髪（真ん中分け）
    b.row(6 + y, (4, 11), C["hair"])
    b.px(6, 5 + y, C["hair_hi"])
    # ゴーグル（額に上げている）。
    b.row(3 + y, (4, 7, 8, 11), C["frame"])
    b.row(3 + y, (5, 9), C["lens_hi"])
    b.row(3 + y, (6, 10), C["lens"])
    b.row(4 + y, range(3, 13), C["band"])
    b.row(4 + y, (5, 6, 9, 10), C["lens_dk"])
    # 目・頬・口。
    if blink:
        b.row(9 + y, (5, 10), C["eye"])
    else:
        b.rect(5, 8 + y, 1, 2, C["eye"])
        b.rect(10, 8 + y, 1, 2, C["eye"])
    b.row(10 + y, (4, 11), C["blush"])
    b.row(11 + y, (7, 8), C["mouth"])
    # あご下の影と首。
    b.row(12 + y, (7, 8), C["skin_sh"])
    # 角を落として丸みを出す。
    for (x, yy) in ((3, 3), (12, 3), (4, 11), (11, 11)):
        b.px(x, yy + y, (0, 0, 0, 0))


def head_up(b, dy):
    y = dy
    b.row(1 + y, range(5, 11), C["hair"])
    b.row(2 + y, range(4, 12), C["hair"])
    b.rect(3, 3 + y, 10, 9, C["hair"])
    b.row(2 + y, (5, 6), C["hair_hi"])
    b.rect(5, 5 + y, 1, 4, C["hair_hi"])
    b.rect(8, 6 + y, 1, 3, C["hair_hi"])
    b.row(11 + y, range(4, 12), C["hair_dk"])
    b.row(4 + y, range(3, 13), C["band"])   # ゴーグルのバンド（後頭部）
    b.px(7, 4 + y, C["frame"])
    b.px(8, 4 + y, C["frame"])
    b.row(12 + y, (7, 8), C["skin_sh"])     # 首
    for (x, yy) in ((3, 3), (12, 3), (3, 11), (12, 11), (4, 11), (11, 11)):
        b.px(x, yy + y, (0, 0, 0, 0))
    b.row(11 + y, range(5, 11), C["hair_dk"])


def head_side(b, dy, blink):
    y = dy
    # 後ろ髪は左、顔は右向き。
    b.row(1 + y, range(4, 10), C["hair"])
    b.row(2 + y, range(3, 11), C["hair"])
    b.rect(3, 3 + y, 9, 2, C["hair"])
    b.rect(3, 5 + y, 4, 6, C["hair"])      # 後頭部
    b.px(3, 10 + y, C["hair_dk"])
    b.row(2 + y, (4, 5), C["hair_hi"])
    b.rect(4, 6 + y, 1, 3, C["hair_hi"])
    # 顔。
    b.rect(7, 5 + y, 5, 7, C["skin"])
    b.row(11 + y, range(7, 12), C["skin_sh"])
    b.row(5 + y, (7, 8, 9), C["hair"])      # 前髪
    b.px(7, 6 + y, C["hair"])
    b.px(12, 8 + y, C["skin_sh"])           # 鼻
    # ゴーグル（片側のレンズが見える）。
    b.row(3 + y, (7, 10), C["frame"])
    b.px(8, 3 + y, C["lens_hi"])
    b.px(9, 3 + y, C["lens"])
    b.row(4 + y, range(3, 11), C["band"])
    b.row(4 + y, (8, 9), C["lens_dk"])
    # 目・頬・口。
    if blink:
        b.px(10, 9 + y, C["eye"])
    else:
        b.rect(10, 8 + y, 1, 2, C["eye"])
    b.px(11, 10 + y, C["blush"])
    b.px(11, 11 + y, C["mouth"])
    b.row(12 + y, (8, 9), C["skin_sh"])
    for (x, yy) in ((3, 3), (11, 3), (7, 11)):
        b.px(x, yy + y, (0, 0, 0, 0))


# --- 胴と腕 -----------------------------------------------------------------------

def torso_front(b, dy, back=False):
    y = dy
    b.rect(4, 13 + y, 8, 8, C["tunic"])
    b.rect(4, 13 + y, 1, 7, C["tunic_hi"])
    b.rect(10, 13 + y, 2, 7, C["tunic_dk"])
    b.row(20 + y, range(4, 12), C["tunic_dk"])   # 裾
    if back:
        # 背中: 肩掛けの帯と鞄。
        for i, (x, yy) in enumerate(((11, 13), (10, 14), (9, 15), (8, 16), (7, 17), (6, 18))):
            b.px(x, yy + y, C["strap"])
        b.rect(3, 17 + y, 3, 4, C["bag"])
        b.rect(3, 17 + y, 3, 1, C["bag_dk"])
        b.px(4, 19 + y, C["bag_dk"])
    else:
        # 前: 襟、帯、ベルトとバックル、腰の鞄。
        b.row(13 + y, (6, 9), C["collar"])
        b.row(13 + y, (7, 8), C["skin_sh"])
        b.row(14 + y, (7, 8), C["collar"])
        for (x, yy) in ((4, 14), (5, 15), (6, 16), (7, 17), (8, 18)):
            b.px(x, yy + y, C["strap"])
        b.rect(10, 18 + y, 3, 4, C["bag"])
        b.rect(10, 18 + y, 3, 1, C["bag_dk"])
        b.px(11, 20 + y, C["bag_dk"])
    b.row(19 + y, range(4, 10), C["belt"])
    b.row(19 + y, (7, 8), C["buckle"])


def arms_front(b, dy, swing):
    """swing: 左腕の上下（+1 で下がる）。右腕は逆。"""
    for x, s in ((3, swing), (12, -swing)):
        y = dy + s
        b.rect(x, 14 + y, 1, 3, C["tunic_dk"] if x == 12 else C["tunic"])
        b.rect(x, 17 + y, 1, 2, C["skin"])
        b.px(x, 18 + y, C["skin_sh"])


def torso_side(b, dy):
    y = dy
    b.rect(5, 13 + y, 6, 8, C["tunic"])
    b.rect(5, 13 + y, 1, 7, C["tunic_dk"])
    b.rect(10, 13 + y, 1, 7, C["tunic_hi"])
    b.row(20 + y, range(5, 11), C["tunic_dk"])
    b.row(13 + y, (9, 10), C["collar"])
    for (x, yy) in ((9, 14), (8, 15), (7, 16), (6, 17)):
        b.px(x, yy + y, C["strap"])
    b.rect(3, 17 + y, 3, 4, C["bag"])     # 腰の鞄（後ろ側）
    b.rect(3, 17 + y, 3, 1, C["bag_dk"])
    b.row(19 + y, range(5, 11), C["belt"])
    b.px(9, 19 + y, C["buckle"])


def arm_side(b, dy, forward):
    """forward: 腕の前後（+ で前＝右）。"""
    x = 7 + forward
    y = dy
    b.rect(x, 14 + y, 2, 3, C["tunic"])
    b.px(x + 1, 14 + y, C["tunic_hi"])
    b.rect(x, 17 + y, 2, 2, C["skin"])
    b.px(x, 18 + y, C["skin_sh"])


# --- 脚 -------------------------------------------------------------------------

def leg_front(b, x, top, lifted):
    """x: 脚の左端（3px 幅）。lifted なら足を 1px 持ち上げる（短くなる）。"""
    bottom = 27 - (1 if lifted else 0)
    boot_top = bottom - 2
    b.rect(x, top, 3, boot_top - top, C["pants"])
    b.rect(x + 2, top, 1, boot_top - top, C["pants_dk"])
    b.rect(x, boot_top, 3, 3, C["boot"])
    b.row(boot_top, (x, x + 1), C["boot_hi"])


def legs_front(b, dy, frame):
    hip = 21 + dy
    if frame == 1:
        leg_front(b, 5, hip, True)
        leg_front(b, 9, hip, False)
    elif frame == 3:
        leg_front(b, 5, hip, False)
        leg_front(b, 9, hip, True)
    else:
        leg_front(b, 5, hip, False)
        leg_front(b, 9, hip, False)


def leg_side(b, x, top, toe_dir):
    b.rect(x, top, 2, 25 - top, C["pants"])
    b.px(x, top, C["pants_dk"])
    b.rect(x, 25, 2, 3, C["boot"])
    b.px(x + 1, 25, C["boot_hi"])
    if toe_dir > 0:
        b.rect(x + 2, 26, 1, 2, C["boot"])
    elif toe_dir < 0:
        b.px(x - 1, 27, C["boot"])


def legs_side(b, dy, frame):
    hip = 21 + dy
    if frame == 1:
        leg_side(b, 5, hip, -1)   # 後ろ脚
        leg_side(b, 9, hip, 1)    # 前脚
    elif frame == 3:
        leg_side(b, 9, hip, 1)
        leg_side(b, 5, hip, -1)
        # 逆位相: 前後を入れ替えて、奥の脚を少し暗くする。
        b.rect(10, hip, 1, 25 - hip, C["pants_dk"])
    else:
        leg_side(b, 6, hip, 0)
        leg_side(b, 8, hip, 1)


# --- 組み立て ---------------------------------------------------------------------

def body_lift(frame):
    """接地フレーム（1, 3）で上半身を 1px 持ち上げる。"""
    return -1 if frame in (1, 3) else 0


def make_down(frame, blink=False):
    b = Body()
    dy = body_lift(frame)
    legs_front(b, dy, frame)
    torso_front(b, dy)
    arms_front(b, dy, {1: 1, 3: -1}.get(frame, 0))
    head_down(b, dy, blink)
    b.cv.outline(C["outline"])
    return b.cv.result()


def make_up(frame):
    b = Body()
    dy = body_lift(frame)
    legs_front(b, dy, frame)
    torso_front(b, dy, back=True)
    arms_front(b, dy, {1: -1, 3: 1}.get(frame, 0))
    head_up(b, dy)
    b.cv.outline(C["outline"])
    return b.cv.result()


def make_side(frame, blink=False):
    b = Body()
    dy = body_lift(frame)
    legs_side(b, dy, frame)
    torso_side(b, dy)
    arm_side(b, dy, {1: 2, 3: -2}.get(frame, 0))
    head_side(b, dy, blink)
    b.cv.outline(C["outline"])
    return b.cv.result()


def main():
    os.makedirs(OUT, exist_ok=True)
    frames = {}
    for f in range(4):
        frames["char_down_%d" % f] = make_down(f)
        frames["char_up_%d" % f] = make_up(f)
        frames["char_side_%d" % f] = make_side(f)
    frames["char_down_blink"] = make_down(0, blink=True)
    frames["char_side_blink"] = make_side(0, blink=True)
    for name, (w, hh, px) in frames.items():
        write_png(os.path.join(OUT, name + ".png"), w, hh, px)
        print("wrote %s.png (%dx%d)" % (name, w, hh))

    # 確認用シート: 行 = 下 / 上 / 横 / 横（左向き）、列 = フレーム 0..3 + まばたき。
    S = 6
    cols = 5
    rows = [
        [("char_down_%d" % f, False) for f in range(4)] + [("char_down_blink", False)],
        [("char_up_%d" % f, False) for f in range(4)] + [("char_up_0", False)],
        [("char_side_%d" % f, False) for f in range(4)] + [("char_side_blink", False)],
        [("char_side_%d" % f, True) for f in range(4)] + [("char_side_blink", True)],
    ]
    cell_w = W * S + 12
    cell_h = H * S + 12
    pw, ph = cell_w * cols, cell_h * len(rows)
    out = [(231, 225, 211, 255)] * (pw * ph)
    for r, row in enumerate(rows):
        for c, (name, flip) in enumerate(row):
            w, hh, px = frames[name]
            for y in range(hh):
                for x in range(w):
                    sx = (w - 1 - x) if flip else x
                    col = px[y * w + sx]
                    if col[3] == 0:
                        continue
                    for j in range(S):
                        for i in range(S):
                            out[(r * cell_h + 6 + y * S + j) * pw + (c * cell_w + 6 + x * S + i)] = (col[0], col[1], col[2], 255)
    write_png(SHEET, pw, ph, out)
    print("wrote sheet %s (%dx%d)" % (SHEET, pw, ph))


if __name__ == "__main__":
    main()
