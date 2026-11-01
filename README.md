# Spirula Studio GPU desktop for RunPod

## 変更内容

- ビルド時: rcloneをUbuntuパッケージから導入。既存のSpirulaコミット、Vulkan、CUDA、KasmVNC 1.5.0、XFCEは維持。
- 起動時（root必須）: マウント後の `/workspace` 自体だけをstudio所有・書込可能にする。既存データを再帰chownしない。
- KasmVNCは `-select-de manual` と明示的なXFCE xstartupを使用。
- rclone設定は `/workspace/.private/rclone/rclone.conf`（ディレクトリ700、ファイル600）に保存し、studioの標準設定ディレクトリからリンクする。
- 設定がなければ `RCLONE_CONF_B64` から復元。既存の設定は常に優先し、トークン更新を再起動で巻き戻さない。復元用環境変数はデスクトップ起動前に解除。

設定はrcloneがトークンを書き戻せる必要がある。base64は暗号化ではない。rootやPod管理権限を持つ人から隠すものではない。

## 1. 現在のPodから安全に退避（Podを削除する前に）

現在のPodのstudio端末で `rclone config file` を実行し、使用中のパスだけを確認する。
rootで設定していた場合はroot端末でも確認する。`rclone config show` や `cat` で内容を表示しない。

Macの端末で、リポジトリ外の秘密保管先へSSHで転送する。以下の接続先・ポート・パスはRunPodのSSH接続情報と上記結果で置き換える。

```sh
mkdir -p "$HOME/.config/spirula-secrets"
chmod 700 "$HOME/.config/spirula-secrets"
(umask 077; scp -P SSH_PORT SSH_USER@SSH_HOST:/actual/path/rclone.conf "$HOME/.config/spirula-secrets/rclone.conf")
chmod 600 "$HOME/.config/spirula-secrets/rclone.conf"
```

SSHの接続先鍵を確認する。Web Terminalの出力をコピーして退避しない。ファイルもチャットへ貼らない。
暗号化済みrclone設定の場合は、暗号化パスワードも別の秘密保管先で保持する。

## 2. RunPod Secretsへ登録

Macで次を実行するとbase64値が画面に出ず、クリップボードに入る。

```sh
base64 < "$HOME/.config/spirula-secrets/rclone.conf" | tr -d '\n' | pbcopy
```

RunPodのSecrets画面で `spirula_rclone_b64` を作成し、値を貼り付ける。貼り付け後は `printf '' | pbcopy` でクリップボードを消す。
Podの環境変数を次のように設定する（実値をテンプレートに保存しない）。

```text
RCLONE_CONF_B64={{ RUNPOD_SECRET_spirula_rclone_b64 }}
VNC_PASSWORD={{ RUNPOD_SECRET_spirula_vnc_password }}
```

`spirula_vnc_password` も別途作成する。rclone設定が暗号化されている場合だけ `RCLONE_CONFIG_PASS` に別のRunPod Secretを参照させる。これはrclone実行にも必要なので解除しない。

Secretはビルド引数・DockerfileのENV・GitHub Actionsへ渡さない。`.dockerignore` はビルドに必要な3ファイルのみ許可する。Gitの除外設定だけでは漏えいを防げないため、秘密ファイルは最初からリポジトリ外に置く。

## 3. ビルドと新しいPod

1. 修正コードだけをGitHubに反映する。
2. GitHub Actionsの「Build Spirula RunPod」をRun workflowで実行する。
3. 成功したビルドのGHCR digestを控え、`ghcr.io/simizar/spirula-runpod@sha256:...` を新Podのイメージに指定する。latestのキャッシュを避ける。
4. 同じ永続ボリュームを `/workspace` に接続するか、新規ボリュームと上記Secretsを使用する。HTTPポート8444とGPUの設定は現在のPodと同じにする。
5. 現在のPodは検証完了まで保持する。イメージ再ビルドだけでは既存Podのファイルは更新されない。

`/workspace` が永続化されるのは使用するRunPodストレージの寿命の範囲内だけ。Pod削除後も必要ならNetwork Volume等とローカルバックアップを使う。Secretは更新されたトークンを自動保存しないので、終了前に最新設定を再退避し、必要に応じてSecretも更新する。

既存Podでこの起動スクリプトを使う場合、既存の `/home/studio/.config/rclone` が通常ディレクトリだと安全のため起動を中断する。まずローカルへ退避し、rclone処理を停止してから設定を移行する。動作中のPodでは起動スクリプトを再実行しない。

## 4. 新Podで検証（studio端末）

```sh
id
mkdir /workspace/.studio-write-check && rmdir /workspace/.studio-write-check
rclone version
rclone config file
rclone listremotes
```

上記のremote名を使って `rclone lsd 'REMOTE:'` を実行する（フォルダ名はチャットや公開ログに貼らない）。次にSpirula Studioを従来と同じ方法で起動し、既知の処理でGPU動作を確認する。必要なら `vulkaninfo --summary` でGPUを確認する。最後に新Podを再起動して同じ確認を行う。

公開イメージから独立したクリーンな新Podでも、SecretsなしならDrive設定が存在しないことを確認する。現在のPodを `docker commit` して公開しない。
