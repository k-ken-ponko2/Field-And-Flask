#!/usr/bin/env bash
# Web エクスポートを作ってローカルで配信する（ブラウザでの動作確認用）。
#
# 使い方:
#   tools/serve_web.sh            # エクスポート → http://localhost:8123/ で配信
#   tools/serve_web.sh --no-export # 既存の build/web をそのまま配信
#
# 前提:
#   - godot（4.7）が PATH にあるか、GODOT 環境変数で実行ファイルを指す
#   - Web 用エクスポートテンプレートが入っている。無ければ下記で Web 用だけ取り出せる:
#       curl -fsSL -o /tmp/templates.tpz \
#         https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_export_templates.tpz
#       dest=~/.local/share/godot/export_templates/4.7.stable && mkdir -p "$dest"
#       unzip -o -q -j /tmp/templates.tpz 'templates/web_nothreads_release.zip' \
#         'templates/web_nothreads_debug.zip' 'templates/web_release.zip' 'templates/web_debug.zip' \
#         'templates/version.txt' -d "$dest"
#   （Thread Support を切ってあるので、COOP/COEP ヘッダ無しの素朴な静的サーバで動く）
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PORT="${PORT:-8123}"

if [[ "${1:-}" != "--no-export" ]]; then
  mkdir -p build/web
  "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
  "$GODOT" --headless --path . --export-release "Web" build/web/index.html
fi

echo "serving build/web at http://localhost:${PORT}/  (Ctrl+C で終了)"
python3 -m http.server "$PORT" -d build/web
