# DLServer2 Übersicht widget

Mac 側で trainer (DL-SERVER2) の GPU/CPU をリアルタイム監視するデスクトップウィジェット。Rainmeter 版と同じデータソース (`ssh trainer /usr/local/bin/trainer-stats`) を直接ポーリングする方式。

## セットアップ手順 (Mac)

### 1. Übersicht インストール

```bash
brew install --cask ubersicht
open -a Übersicht
```

メニューバーにアイコンが出る。

### 2. SSH 鍵を trainer に登録

Mac から trainer に鍵で繋げるようにする:

```bash
# 既に鍵があれば skip
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# 公開鍵を trainer の authorized_keys に追加 (パスワード一度だけ要求される)
ssh-copy-id -i ~/.ssh/id_ed25519.pub adstec@100.98.36.61

# SSH config に host alias 追加
cat >> ~/.ssh/config <<'EOF'

Host trainer
  HostName 100.98.36.61
  User adstec
  IdentityFile ~/.ssh/id_ed25519
  ServerAliveInterval 30
EOF
chmod 600 ~/.ssh/config

# テスト
ssh trainer /usr/local/bin/trainer-stats
# 期待出力例: 38,67,0,6080,99.84,41,78,0,11328,106.84,75,76
```

Tailscale 経由なので家からも社からも繋がる (VPN不要)。

### 3. ウィジェット配置

```bash
# このフォルダ全体を Übersicht のウィジェット dir にコピー
cp -r ~/Desktop/DLServer2.widget "$HOME/Library/Application Support/Übersicht/widgets/"

# Übersicht を refresh (メニューバーアイコン → Refresh All)
osascript -e 'tell application "Übersicht" to refresh'
```

デスクトップ右上に GPU0/GPU1/CPU パネルが出る。3 秒ごとに SSH 取得 → bar (現在値) + sparkline (3 分履歴) で表示。

## カスタマイズ

`index.coffee` 編集後、Übersicht メニュー → Refresh で反映。

| 項目 | 場所 |
|---|---|
| 配置位置 | `style:` の `top` `right` |
| 幅 | `width 540px` |
| 更新間隔 | `refreshFrequency: 3000` (ms) |
| 履歴長 | `HISTORY_LEN = 60` (× 3秒 = 3分) |
| 色 | `metrics` 配列の `color` (各メトリック) |

## トラブル

| 症状 | 原因 / 対処 |
|---|---|
| `fetch failed` の赤帯 | SSH 通らない。Mac から `ssh trainer trainer-stats` 単体で動くか確認 |
| 値 0 のまま | `trainer-stats` スクリプトが trainer 側に無い (要 `/usr/local/bin/trainer-stats`) |
| ウィジェットが消える | Übersicht が落ちた。再起動: `killall Übersicht && open -a Übersicht` |

## trainer 側必要スクリプト

`/usr/local/bin/trainer-stats` (実行権限あり):

```bash
#!/bin/bash
# Output all monitoring stats as CSV (one line):
# gpu0_temp,gpu0_fan,gpu0_util,gpu0_mem,gpu0_power,gpu1_temp,gpu1_fan,gpu1_util,gpu1_mem,gpu1_power,cpu_pkg,cpu_max
g=$(nvidia-smi --query-gpu=temperature.gpu,fan.speed,utilization.gpu,memory.used,power.draw --format=csv,noheader,nounits 2>/dev/null | tr -d ' %W' | tr '\n' ',' | sed 's/,$//')
cpu_pkg=$(/usr/local/bin/cpu-stat pkg)
cpu_max=$(/usr/local/bin/cpu-stat max)
echo "$g,$cpu_pkg,$cpu_max"
```

`/usr/local/bin/cpu-stat`:

```bash
#!/bin/bash
case "${1:-pkg}" in
    pkg)  sensors -u coretemp-isa-0000 2>/dev/null | awk '/Package id 0/{getline; printf "%d", $2; exit}' ;;
    max)  sensors -u coretemp-isa-0000 2>/dev/null | awk '/_input/{if($2>m)m=$2}END{printf "%d", m}' ;;
    cores) sensors 2>/dev/null | awk '/^Core [0-9]+:/{gsub("[+]","",$3); printf "%s ", $3}' ;;
esac
```

`lm-sensors` インストール: `sudo apt install lm-sensors && sudo sensors-detect --auto`

trainer に既にあるので Mac から動かすだけなら追加作業なし。
