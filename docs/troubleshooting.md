# 構築中に発生した問題と対応

構築中に実際に発生した問題と、原因の切り分け・対応の記録です。

---

## 1. NIC の設定変更で「アクセスが拒否されました」

**現象**

`Set-NetAdapterAdvancedProperty` を実行すると `Windows System Error 5`（アクセス拒否）になった。

**原因**

PowerShell を管理者権限なしで起動していた。カレントディレクトリが `C:\Windows\system32` でも、管理者権限があるとは限らない。

**対応**

「ターミナル（管理者）」から起動し直した。権限は次のコマンドで確認できる。

```powershell
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

---

## 2. 起動直後に Tailscale がオフラインのまま

**現象**

Magic Packet を送信して PC は起動したが、`tailscale ping` がタイムアウトし、`tailscale status` でも PC が offline のままだった。

**原因**

Tailscale のサービスを遅延自動起動に設定しているため、OS 起動から接続まで 1〜2 分かかる。故障ではなく、待ち時間が足りなかった。

**対応**

起動から 2〜3 分待ってから `tailscale status` で確認する運用にした。あわせて、PC が起動しているかを Tailscale とは独立に確認する方法も用意した。

```bash
ssh pi "ping -c 2 -W 1 <PC_LAN_IP>; ip neigh show <PC_LAN_IP>"
```

ARP テーブルに `REACHABLE` / `STALE` で載っていれば、PC 自体は起動している。

---

## 3. タスクトレイに Tailscale のアイコンが表示されない

**現象**

起動後、タスクトレイに Tailscale のアイコンがなかったが、接続はできていた。

**原因**

Windows 版 Tailscale は、接続を担うバックグラウンドサービスと、トレイアイコンの GUI に分かれている。unattended モードではサービス単体で接続するため、GUI が起動していなくても通信には影響しない。

**確認方法**

```powershell
Get-Service Tailscale
tailscale debug prefs | findstr "ForceDaemon WantRunning"
```

---

## 4. Raspberry Pi で `wakeonlan` パッケージが見つからない

**現象**

`sudo apt update` 後も `apt install wakeonlan` でパッケージが見つからなかった。

**対応**

外部パッケージに依存せず、標準ライブラリだけで Magic Packet を送信する Python スクリプト（[`raspberry-pi/wakepc.py`](../raspberry-pi/wakepc.py)）を作成した。Magic Packet は `0xFF × 6` に続けて MAC アドレスを 16 回繰り返した 102 バイトのデータで、UDP でブロードキャストすればよい。

---

## 5. Raspberry Pi で `docker` コマンドが見つからない

**現象**

frpc を Docker で起動しようとしたところ、`docker: command not found` になった。

**原因**

以前に別のサービスを削除した際、Docker も一緒にアンインストールしていた。

**対応**

frpc は予備経路の要なので、Docker を入れ直すのではなく、単一バイナリを systemd サービスとして登録した（[`raspberry-pi/frpc.service`](../raspberry-pi/frpc.service)）。依存するコンポーネントが減り、OS 起動時の自動起動も systemd で管理できる。

---

## 6. 外出先から接続しようとしたら PC がオフラインになっていた

**現象**

リモートデスクトップでの検証を終えてしばらくしてから SSH で接続しようとしたところ、応答がなく、`tailscale status` でも PC が offline だった。

**切り分け**

自動スリープ・停電・意図したシャットダウンのどれなのかを、Windows のイベントログで確認した。

```bash
ssh winpc 'chcp 65001 >nul & powershell -Command "Get-EventLog System -After (Get-Date).AddHours(-3) | Where-Object EventID -In 1074,6006,6008,41,42,1,12,13 | Select-Object TimeGenerated,EventID,Source | Format-Table -AutoSize"'
```

| EventID | 意味 |
|---|---|
| 1074 | ユーザーまたはプログラムによるシャットダウン・再起動 |
| 6006 | 正常なシャットダウン |
| 41 / 6008 | 予期しない電源断 |
| 42 | スリープへの移行 |
| 12 | OS の起動 |

**結果**

`1074` → `6006` が記録されており、その後しばらく起動の記録がなかったため、スリープや電源断ではなく**正常なシャットダウン**だったと判断できた。電源が切れていた PC は、そのまま `wakepc` で外出先から起動できた。

**あわせて行った対策**

リモート開発中に PC がスリープすると SSH 接続が切れるため、AC 電源接続時の自動スリープを無効化した。

```bash
ssh winpc "powercfg /change standby-timeout-ac 0"
```

---

## 7. SSH 経由で実行したコマンドの日本語・中国語出力が文字化けする

**現象**

`ssh winpc "powershell ..."` で実行した結果のうち、日付やエディション名などの非 ASCII 文字が `??` に化けた。

**原因**

Windows のコンソールのコードページ（中国語環境では 936）で出力されたバイト列を、Mac 側が UTF-8 として表示していた。

**対応**

コマンドの先頭でコードページを UTF-8（65001）に切り替える。

```bash
ssh winpc "chcp 65001 >nul & powershell (Get-CimInstance Win32_OperatingSystem).Caption"
```

文字列そのものが不要な場合は、`EditionID` のように ASCII で返る値を参照する方法もある。

---

## 8. 設定ファイルに書く値と端末をまたぐ操作

**現象**

複数の端末（Mac / Raspberry Pi / Windows）をまたいで作業する中で、別の端末で実行すべきコマンドを誤って実行してしまうことがあった。

**対応**

プロンプトの表示（`~ %` / `user@raspberrypi:~ $` / `PS C:\>`）で実行先を確認する運用にした。また、Mac から `ssh <host> <command>` の形で 1 行で実行できるようにし、ログインして操作する場面を減らした。
