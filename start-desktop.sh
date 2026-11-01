
#!/usr/bin/env bash
set -euo pipefail

# RunPodで設定するパスワードを確認
: "${VNC_PASSWORD:?VNC_PASSWORD is required}"

# studioユーザーのホームを準備
mkdir -p /home/studio/.vnc
chown -R studio:studio /home/studio

# XFCEの起動設定
cat > /home/studio/.vnc/xstartup <<'EOF'
#!/bin/sh
exec dbus-launch --exit-with-session startxfce4
EOF

chmod +x /home/studio/.vnc/xstartup
chown studio:studio /home/studio/.vnc/xstartup

# KasmVNCのログインユーザーを登録
printf '%s\n%s\n' "$VNC_PASSWORD" "$VNC_PASSWORD" |
  runuser -u studio -- \
  kasmvncpasswd -u studio -wo

# 仮想デスクトップを起動
exec runuser -u studio -- \
  vncserver :1 -fg
