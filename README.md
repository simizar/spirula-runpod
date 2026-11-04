# 追加機能の使い方（2026-11-04）

- GUIブラウザ: Mozilla公式APTのFirefox DEB版（日本語パック・日本語フォント）。snap不要。XFCEのアプリ一覧からFirefoxを開くか、studio端末で `firefox` を実行。
- Driveコピー: イメージに `/usr/local/bin/download-gdrive.sh` を配置。起動時の自動ダウンロードは行わない。
- 起動時に `/workspace` と `/workspace/Spirula_Input` をstudioが書き込めるよう準備。既存フォルダ内部のファイル所有者は再帰変更しない。以前rootが作った既存ファイルは個別の権限修正が必要な場合がある。
- CUDAベースイメージ、NVIDIA環境変数、SpirulaのコミットとVulkanビルド、KasmVNC 1.5.0、XFCE起動方法は維持。

## 1. ビルドする

mainへ反映するとGitHub Actionsが自動ビルド。手動の場合は Actions → Build Spirula RunPod → Run workflow。
完了後、Summaryの `ghcr.io/simizar/spirula-runpod@sha256:...` を控える。
バージョンを特定できる `sha-コミットID` タグも付く。ビルドにはGoogle認証情報を渡さない。
最後のsmoke testはブラウザ・コマンドの存在と秘密ファイルがないことを確認する。GPU/GUIの実動作はPodで確認する。

## 2. 次のPodを起動する

1. 現Podのrclone設定を安全に退避する（下記の既存手順を参照）。
2. 新Podのイメージに上記digestを指定する。
3. GPU、HTTPポート8444、VNC_PASSWORDは現在と同じ設定を使用する。起動コマンドはイメージ既定を使い、root起動を維持する。
4. 永続ボリュームを `/workspace` にマウントする。
5. 新しいボリュームなら `RCLONE_CONF_B64` にRunPod Secretを参照させる。既存の永続rclone設定があればそちらを優先する。
6. デスクトップへ接続し、studio端末を開く。

## 3. Driveから取得する

まずコピー予定を確認:

```sh
download-gdrive.sh --dry-run
```

次に実行:

```sh
download-gdrive.sh
```

`gdrive:runpod_workspace/input` の中身を `/workspace/Spirula_Input` にコピーする。
同一ファイルはスキップし、コピー先にしかないファイルは削除しない。再実行も可能。
remote名は `gdrive` が必要。認証内容をコマンドへ直接書かない。

## 4. 新Podで動作確認する

```sh
firefox
nvidia-smi
vulkaninfo --summary
```

Firefoxでページを開く。Spirula Studioは従来の方法で起動し、入力を開いて既知のGPU処理を試す。
Podを再起動し、再びDriveコピーとSpirulaを確認してから旧Podを終了する。
イメージのビルドだけでは既存Podは更新されない。

参考: [Mozilla公式DEB導入](https://support.mozilla.org/en-US/kb/install-firefox-linux)、[rclone copy](https://rclone.org/commands/rclone_copy/)。

---

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

Secretはビルド引数・DockerfileのENV・GitHub Actionsへ渡さない。`.dockerignore` はビルドに必要なファイルのみ許可する。Gitの除外設定だけでは漏えいを防げないため、秘密ファイルは最初からリポジトリ外に置く。

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
