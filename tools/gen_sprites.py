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

    # プレビュー（各スプライトを ×8 で市松背景に並べる）
    S = 8
    pad = 8
    names = list(rendered.keys())
    cell_w = max(w for w, _, _ in rendered.values()) * S + pad * 2
    cell_h = max(hh for _, hh, _ in rendered.values()) * S + pad * 2 + 12
    cols = 4
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
