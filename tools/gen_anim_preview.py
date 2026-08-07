#!/usr/bin/env python3
"""歩行アニメの確認用プレビューを生成する（Pillow 使用）。

player.gd と同じ「idle↔walk 切替＋上下の弾み(bob)」を合成して、
- docs/prototypes/walk-preview.gif  … アニメ（再生用）
- docs/prototypes/walk-filmstrip.png … 静止のフレーム一覧（ポーズ確認用）
を出力する。実行: python3 tools/gen_anim_preview.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
OUT = os.path.join(ROOT, "docs", "prototypes")
GROUND = (231, 225, 211)
SCALE = 6
BOB = 8  # 弾み（プレビュー用の見やすい量）

# (ラベル, ベース名, 左右反転)
DIRS = [("下", "char_down", False), ("右", "char_side", False),
        ("上", "char_up", False), ("左", "char_side", True)]


def load(name, flip):
    im = Image.open(os.path.join(SPR, name + ".png")).convert("RGBA")
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    return im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST)


def frame(step):
    cw, ch = 16 * SCALE + 12, 24 * SCALE + 16
    canvas = Image.new("RGB", (cw * len(DIRS), ch), GROUND)
    for i, (_lab, base, flip) in enumerate(DIRS):
        name = base if step == 0 else base + "_walk"
        spr = load(name, flip)
        bob = 0 if step == 0 else -BOB
        x = i * cw + (cw - spr.width) // 2
        y = 8 + bob
        canvas.paste(spr, (x, y), spr)
    return canvas


def main():
    os.makedirs(OUT, exist_ok=True)
    f0, f1 = frame(0), frame(1)
    # アニメ GIF（idle→walk を往復）
    f0.save(os.path.join(OUT, "walk-preview.gif"), save_all=True,
            append_images=[f1], duration=170, loop=0)
    # フィルムストリップ（上段=idle / 下段=walk）
    strip = Image.new("RGB", (f0.width, f0.height * 2 + 6), (40, 42, 44))
    strip.paste(f0, (0, 0))
    strip.paste(f1, (0, f0.height + 6))
    strip.save(os.path.join(OUT, "walk-filmstrip.png"))
    print("wrote walk-preview.gif and walk-filmstrip.png")


if __name__ == "__main__":
    main()
