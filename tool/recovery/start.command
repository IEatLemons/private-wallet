#!/bin/zsh
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
BIN="$SCRIPT_DIR/recover-address"
if [[ ! -x "$BIN" ]]; then
  print -u2 '缺少 recover-address 可执行文件，请使用完整恢复工具文件夹。'
  exit 2
fi
if [[ "${1:-}" == '--help' || "${1:-}" == '--self-test' ]]; then
  exec "$BIN" "$@"
fi
CONFIG="${RECOVERY_CONFIG:-}"
if [[ -z "$CONFIG" && -f "$SCRIPT_DIR/config.env" ]]; then
  CONFIG="$SCRIPT_DIR/config.env"
fi
if [[ -z "$CONFIG" && -f "$SCRIPT_DIR/input.path" ]]; then
  IFS= read -r CONFIG < "$SCRIPT_DIR/input.path"
fi
if [[ -z "$CONFIG" || ! -f "$CONFIG" ]]; then
  print '请输入本地配置文件的绝对路径（不要输入助记词内容）：'
  IFS= read -r CONFIG
fi
if [[ ! -f "$CONFIG" ]]; then
  print -u2 '配置文件不存在。'
  exit 2
fi
STATE_DIR="$SCRIPT_DIR/state"
if [[ -f "$SCRIPT_DIR/state.path" ]]; then
  IFS= read -r STATE_DIR < "$SCRIPT_DIR/state.path"
fi
print '单线程低负载运行。按 Ctrl+C 保存退出，重新双击会自动续跑。'
print "续跑目录：$STATE_DIR"
/usr/bin/nice -n 10 "$BIN" --config "$CONFIG" --state-dir "$STATE_DIR" \
  --cpu-percent "${RECOVERY_CPU_PERCENT:-25}" --max-rss-mb "${RECOVERY_MAX_RSS_MB:-256}" "$@"
RECOVERY_RESULT=$?
print "已结束，状态码 $RECOVERY_RESULT。0=匹配标准地址或已暂停；3=仅旧版错误哈希匹配；4=设定范围已遍历；5=内存限制。"
if [[ -t 0 ]]; then
  print '按回车关闭此窗口。'
  IFS= read -r recovery_close_answer
fi
exit "$RECOVERY_RESULT"
