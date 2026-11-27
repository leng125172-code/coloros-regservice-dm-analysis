#!/usr/bin/env bash
# 设备重连后重新采样 fxltsbl 相关证据
set -e
D="${1:-3B15CS007JA00000}"
OUT="$(dirname "$0")"

echo "[*] 检查设备"
adb -s "$D" get-state

echo "[*] 1. 接口缓存里的域名与路径"
adb -s "$D" shell "su -c 'strings /data/data/com.coloros.regservice/cache/volley/* 2>/dev/null | grep -oE \"https://[ab]\\.fxltsbl\\.com[^\\\"\\x27[:space:]]*\" | sort -u'" \
  | tr -d '\r' | sed -E 's/(imei|imei2|token)=[0-9a-f]+/\1=<REDACTED>/g' \
  > "$OUT/endpoints_live.txt" || true

echo "[*] 2. 当前网络连接（是否正在上报）"
adb -s "$D" shell "su -c 'netstat -tunp 2>/dev/null | grep -i fxltsbl || echo none'" | tr -d '\r' \
  > "$OUT/conn_live.txt" || true

echo "[*] 3. 配置快照（脱敏）"
adb -s "$D" shell "su -c 'cat /data/data/com.coloros.regservice/shared_prefs/config_dm.xml'" \
  | tr -d '\r' | sed -E 's/[0-9]{15}/<REDACTED-ICCID>/g; s/86[0-9]{13}/<REDACTED-IMEI>/g; s/4600[0-9]{11}/<REDACTED-IMSI>/g' \
  > "$OUT/config_live.xml" || true

echo "[*] 4. 数据库导出"
adb -s "$D" shell "su -c 'cp /data/data/com.coloros.regservice/databases/cmcc_dm.db /sdcard/cmcc_dm_new.db; chmod 644 /sdcard/cmcc_dm_new.db'"
adb -s "$D" pull /sdcard/cmcc_dm_new.db "$OUT/cmcc_dm_new.db" >/dev/null

echo "[*] 完成，输出在 $OUT"
