# 構築手順

`<...>` で囲まれた値は、自分の環境に合わせて置き換えてください。

## 0. 前提

| ホスト | 環境 |
|---|---|
| Windows デスクトップ | Windows 11、有線 LAN（Realtek 2.5GbE） |
| Raspberry Pi 5 | Raspberry Pi OS（Debian）、自宅 LAN に常時接続 |
| クラウドサーバー | Ubuntu 22.04、Docker、東京リージョン |
| Mac | macOS、VS Code（Remote - SSH 拡張機能） |

---

## 1. Windows：Wake-on-LAN

### BIOS（MSI の場合）

- `Settings > Advanced > Power Management Setup > ErP Ready` → **Disabled**
- `Settings > Advanced > Wake Up Event Setup > Resume By PCI-E/Networking Device` → **Enabled**

### OS

管理者として PowerShell を開き、実行します。

```powershell
Get-NetAdapter                          # 有線 NIC の名前を確認
.\windows\setup-wol.ps1 -AdapterName "<有線NICの名前>"
```

このスクリプトは、リモート作業中に SSH 接続が切れないよう、AC 電源接続時の自動スリープも無効化します。出力された MAC アドレスを控えておきます。

---

## 2. Windows：Tailscale

1. Tailscale をインストールしてログイン
2. ログイン前でも接続できるよう、unattended モードを有効化
3. ネットワーク初期化後に起動するよう、サービスを遅延自動起動に変更

```powershell
tailscale up --unattended=true
sc.exe config Tailscale start= delayed-auto
```

4. 管理画面の Machines で、PC と Raspberry Pi の **Disable key expiry** を有効化（長期不在中の再ログインを防ぐ）

---

## 3. Windows：OpenSSH Server

```powershell
.\windows\setup-openssh.ps1 -PublicKey "<Mac の ~/.ssh/id_ed25519.pub の内容>" -DefaultShellPowerShell
```

---

## 4. Raspberry Pi：起動スクリプト

```bash
scp raspberry-pi/wakepc.py pi:~/
ssh pi python3 wakepc.py <PC_MAC_ADDRESS> --broadcast <LAN_BROADCAST_ADDRESS>
```

`sent` と表示され、PC が起動すれば成功です。

---

## 5. クラウドサーバー：frps

```bash
sudo mkdir -p /etc/frp
sudo cp server/frp/frps.toml.example /etc/frp/frps.toml   # トークンを書き換える
sudo docker run --restart=always --network host -d \
  -v /etc/frp/frps.toml:/etc/frp/frps.toml --name frps snowdreamtech/frps
sudo docker logs frps    # "frps started successfully" を確認
```

ファイアウォールで **TCP 7000** と **TCP 6022** を許可します。

---

## 6. Raspberry Pi：frpc（systemd）

```bash
# arm64 版バイナリを取得
cd /tmp
URL=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep -o 'https://[^"]*linux_arm64.tar.gz')
curl -L -o frp.tar.gz "$URL" && tar xzf frp.tar.gz
sudo cp frp_*_linux_arm64/frpc /usr/local/bin/

# 設定とサービス登録
sudo mkdir -p /etc/frp
sudo cp raspberry-pi/frpc.toml.example /etc/frp/frpc.toml   # IP とトークンを書き換える
sudo cp raspberry-pi/frpc.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now frpc
journalctl -u frpc -n 20 --no-pager    # "start proxy success" を確認
```

### パスワード認証の無効化

公開鍵でログインできることを確認してから適用します。

```bash
ssh -o PasswordAuthentication=no pi echo ok    # "ok" と表示されること
ssh pi
sudo cp raspberry-pi/sshd-no-password.conf /etc/ssh/sshd_config.d/no-password.conf
sudo systemctl restart ssh
sudo sshd -T | grep -i passwordauthentication  # "passwordauthentication no"
```

---

## 7. クラウドサーバー：RustDesk 中継サーバー

```bash
mkdir -p ~/rustdesk && cp server/rustdesk/compose.yml ~/rustdesk/
cd ~/rustdesk && sudo docker compose up -d
cat ~/rustdesk/data/id_ed25519.pub    # クライアントに設定する公開鍵
```

ファイアウォールで **TCP 21115-21117** と **UDP 21116** を許可します。

---

## 8. RustDesk クライアント

### Mac

`設定 > ネットワーク > ID/中継サーバー` に以下を入力し、**サーバー設定をエクスポート**して文字列を控えます。

- ID サーバー / 中継サーバー：`<SERVER_PUBLIC_IP>`
- Key：手順 7 で表示した公開鍵

### Windows（SSH 経由でインストール）

```bash
ssh winpc
```
```powershell
.\install-rustdesk.ps1 -ConfigString "<エクスポートした文字列>"
```

表示された ID と設定したパスワードで、Mac から接続します。

---

## 9. Mac

```bash
cat mac/ssh_config.example >> ~/.ssh/config   # プレースホルダーを書き換える
cat mac/aliases.zsh >> ~/.zshrc               # MAC アドレスなどを書き換える
source ~/.zshrc
```

### 動作確認

```bash
shutpc       # PC をシャットダウン
wakepc2      # frp 経由で起動
pcstatus     # 2〜3 分後にオンラインになることを確認
ssh pi-frp hostname
```
