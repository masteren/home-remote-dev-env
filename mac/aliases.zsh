# ~/.zshrc に追記する
# PC_MAC と PC_TS_NAME は自分の環境に合わせて変更する

export PC_MAC="<PC_MAC_ADDRESS>"      # 例: AA:BB:CC:DD:EE:FF
export PC_TS_NAME="<PC_TAILSCALE_NAME>" # tailscale status に表示される PC 名
TAILSCALE_CLI="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

# 遠隔起動（Raspberry Pi が LAN 内に Magic Packet を送信）
alias wakepc='ssh pi python3 wakepc.py "$PC_MAC"'      # Tailscale 経由
alias wakepc2='ssh pi-frp python3 wakepc.py "$PC_MAC"' # frp 経由（予備）

# 状態確認（起動後、Tailscale がつながるまで 2〜3 分かかる）
alias pcstatus='"$TAILSCALE_CLI" status | grep "$PC_TS_NAME"'

# シャットダウン・スリープ
alias shutpc='ssh winpc shutdown /s /t 0'
alias sleeppc='ssh winpc rundll32.exe powrprof.dll,SetSuspendState 0,1,0'
