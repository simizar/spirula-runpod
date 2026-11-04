#!/usr/bin/env bash
set -euo pipefail

# Always use the desktop user's runtime credentials and file ownership.
if [[ $(id -u) -eq 0 ]]; then
  exec runuser -u studio -- /usr/local/bin/download-gdrive.sh "$@"
fi
if [[ $(id -un) != studio ]]; then
  echo 'studioユーザーの端末で実行してください。' >&2
  exit 1
fi
export HOME=/home/studio
export XDG_CONFIG_HOME=/home/studio/.config
# Use the runtime-restored configuration, never a root config or baked-in token.
export RCLONE_CONFIG=/home/studio/.config/rclone/rclone.conf
if [[ ! -r "$RCLONE_CONFIG" ]]; then
  echo 'rclone設定がありません。RunPod Secretを設定してPodを起動してください。' >&2
  exit 1
fi
if ! rclone listremotes | grep -Fxq 'gdrive:'; then
  echo 'rclone設定に gdrive: がありません。remote名を確認してください。' >&2
  exit 1
fi
if [[ -L /workspace/Spirula_Input ]]; then
  echo 'Spirula_Input must be a real directory, not a symlink.' >&2
  exit 1
fi
mkdir -p /workspace/Spirula_Input
if [[ ! -w /workspace/Spirula_Input ]]; then
  echo '/workspace/Spirula_Input に書き込めません。所有者・権限を確認してください。' >&2
  exit 1
fi
# copy preserves destination-only files. Extra flags allow --dry-run, for example.
exec rclone copy 'gdrive:runpod_workspace/input' /workspace/Spirula_Input --progress "$@"
