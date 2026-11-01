
#!/usr/bin/env bash
set -euo pipefail

# RunPodで設定するパスワードを確認
: "${VNC_PASSWORD:?VNC_PASSWORD is required}"

# Mounted volumes must be fixed at runtime, not only during image build.
mkdir -p /workspace
chown studio:studio /workspace
chmod u+rwx /workspace
python3 /usr/local/bin/init-rclone.py
unset RCLONE_CONF_B64

# studioユーザーのホームを準備
mkdir -p /home/studio/.vnc
chown -R studio:studio /home/studio

# XFCEの起動設定
cat > /home/studio/.vnc/xstartup <<'EOF'
#!/bin/sh
exec dbus-launch --exit-with-session startxfce4
EOF

touch /home/studio/.vnc/.de-was-selected
chmod +x /home/studio/.vnc/xstartup
chown studio:studio /home/studio/.vnc/xstartup

# KasmVNCのログインユーザーを登録
printf '%s\n%s\n' "$VNC_PASSWORD" "$VNC_PASSWORD" |
  runuser -u studio -- \
  kasmvncpasswd -u studio -wo

# 仮想デスクトップを起動
exec runuser -u studio -- \
  vncserver :1 -fg -select-de manual
