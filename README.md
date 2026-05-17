# QEMU_sync_guests_time
QEMU Guest Agent (qemu-ga)がインストールされている仮想マシンのシステムクロックをホストマシンのそれに同期する。

## 運用前提
- スクリプト本体は `/usr/local/sbin/sync_gusts_time.sh` に配置する。
- `root` で実行する。

## 導入手順
1. スクリプトを配置して実行権限を付与する。

	```bash
	install -m 755 sync_gusts_time.sh /usr/local/sbin/sync_gusts_time.sh
	```

2. 以下のどちらかの運用方針で cron を設定する。

### 1. 15分周期で実行する（仮想マシン側ではNTPクライアントで時刻合わせを行わない前提）
`root` の crontab に以下を追加する。

```cron
*/15 * * * * /usr/local/sbin/sync_gusts_time.sh
```

### 2. 毎日1回実行する（仮想マシン側でもNTPクライアントで時刻補正を行う前提）
`root` の crontab に以下を追加する。

```cron
0 3 * * * /usr/local/sbin/sync_gusts_time.sh
```
