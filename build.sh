#!/bin/bash
# Works with macOS's bundled Bash 3.2. Run from any working directory.
set -euo pipefail
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

usage() {
  cat <<'HELP'
用法：./build.sh [ios-sim|ios|macos] [build|run|devices] [选项] [-- Flutter 参数]

默认：ios-sim build（仅编译 iOS 模拟器 Debug 应用）

示例：
  ./build.sh ios-sim run
  ./build.sh ios-sim devices
  ./build.sh ios-sim run --device "iPhone 18 Pro"
  ./build.sh ios-sim run --device DEVICE_UUID
  ./build.sh ios-sim build -- --build-name=1.0.1
  ./build.sh ios devices
  ./build.sh ios run
  ./build.sh ios run --device IPHONE_DEVICE_ID
  ./build.sh ios build
  ./build.sh macos build --mode release
  ./build.sh macos run

选项：
  --device NAME_OR_ID     运行时指定 iOS 模拟器或真机（重名时请使用 ID）
  --mode MODE            debug / profile / release，默认 debug
                         iOS 模拟器仅支持 debug
  -h, --help             显示帮助
  -- ARGS...             透传参数给 flutter build/run

可设置 FLUTTER_BIN=/path/to/flutter 指定 Flutter。
run 会自动启动模拟器并等待就绪；终端 r 热更新、R 重启、q 退出、d 脱离。
ios 表示真机：首次使用请用数据线连接、信任 Mac、启用开发者模式，
并在 Xcode 的 Runner → Signing & Capabilities 中选择自己的 Team。
HELP
}
fail() { echo "错误：$*" >&2; exit 1; }

platform=ios-sim
action=build
mode=debug
device=''
extra=()
if [[ $# -gt 0 && "$1" != -* ]]; then platform="$1"; shift; fi
if [[ $# -gt 0 && "$1" != -* ]]; then action="$1"; shift; fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device|--mode)
      [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || fail "$1 需要参数。"
      if [[ "$1" == --device ]]; then device="$2"; else mode="$2"; fi
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; extra=("$@"); break ;;
    *) fail "未知参数：$1；运行 ./build.sh --help 查看用法。" ;;
  esac
done
case "$platform" in ios-sim|ios|macos) ;; *) fail "平台必须是 ios-sim、ios 或 macos。" ;; esac
case "$action" in build|run|devices) ;; *) fail "操作必须是 build、run 或 devices。" ;; esac
case "$mode" in debug|profile|release) ;; *) fail "模式必须是 debug、profile 或 release。" ;; esac
[[ "$platform" != ios-sim || "$mode" == debug ]] || fail "iOS 模拟器仅支持 debug 模式。"
[[ -z "$device" || ( "$platform" != macos && "$action" == run ) ]] || fail "--device 仅用于 ios-sim run 或 ios run。"
[[ "$(uname -s)" == Darwin ]] || fail "iOS 模拟器和 macOS 编译需要在 Mac 上运行。"
# Include Homebrew CocoaPods when launched from a minimal shell environment.
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
developer_dir="$(xcode-select -p)"
[[ -d "$developer_dir/Platforms" ]] || fail "请选择完整 Xcode：sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"

if [[ "$action" == devices && "$platform" == ios-sim ]]; then
  exec xcrun simctl list devices available
fi
flutter_bin="${FLUTTER_BIN:-$(command -v flutter || true)}"
if [[ -z "$flutter_bin" && -x "$HOME/develop/flutter/bin/flutter" ]]; then
  flutter_bin="$HOME/develop/flutter/bin/flutter"
fi
[[ -n "$flutter_bin" ]] || fail "未找到 Flutter，请加入 PATH 或设置 FLUTTER_BIN。"
command -v "$flutter_bin" >/dev/null 2>&1 || fail "无法执行 Flutter：$flutter_bin"
if [[ "$platform" == ios && ( "$action" == run || "$action" == devices ) ]]; then
  command -v python3 >/dev/null 2>&1 || fail "筛选 iOS 真机需要 python3。"
  selected="$("$flutter_bin" devices --machine | python3 -c '
import json, sys
action, selector = sys.argv[1:]
devices = [d for d in json.load(sys.stdin)
           if d.get("targetPlatform") == "ios" and not d.get("emulator", True)
           and d.get("isSupported", False)]
if action == "devices":
    if not devices:
        print("未检测到可用 iPhone/iPad 真机。请连接并解锁手机、信任此 Mac，检查开发者模式及 Xcode 配对状态。")
    for d in devices:
        print("{} · {} · {}".format(d["name"], d["id"], d.get("sdk", "iOS")))
    sys.exit(0)
if selector:
    matches = [d for d in devices if d["id"].lower() == selector.lower()]
    if not matches:
        matches = [d for d in devices if d["name"] == selector]
else:
    matches = devices
if len(matches) != 1:
    sys.exit("找不到唯一可用的 iOS 真机。请连接并解锁手机、完成信任和开发者模式设置；执行 ./build.sh ios devices 查看 ID，再用 --device 指定。")
print(matches[0]["id"])
' "$action" "$device")"
  if [[ "$action" == devices ]]; then echo "$selected"; exit 0; fi
  device="$selected"
  echo "使用 iOS 真机：$device"
elif [[ "$action" == devices ]]; then
  exec "$flutter_bin" devices
fi

if [[ "$action" == run && "$platform" == ios-sim ]]; then
  command -v python3 >/dev/null 2>&1 || fail "自动选择模拟器需要 python3。"
  # Filter out watchOS/tvOS/visionOS. Never pass a platform alias to flutter -d.
  selected="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
selector = sys.argv[1]
devices = [d for runtime, items in json.load(sys.stdin)["devices"].items()
           if ".iOS-" in runtime for d in items if d.get("isAvailable", False)]
if selector:
    matches = [d for d in devices if d["udid"].lower() == selector.lower()]
    if not matches:
        matches = [d for d in devices if d["name"] == selector]
    if len(matches) != 1:
        sys.exit("找不到唯一匹配的 iOS 模拟器，请执行 ./build.sh ios-sim devices 并指定 UUID。")
    selected = matches[0]
else:
    iphones = [d for d in devices if d["name"].startswith("iPhone")]
    candidates = iphones or devices
    if not candidates:
        sys.exit("没有可用 iOS 模拟器，请在 Xcode 安装 iOS runtime 并创建模拟器。")
    selected = next((d for d in candidates if d["state"] == "Booted"), candidates[0])
print(selected["udid"])
print(selected["state"])
print(selected["name"])
' "$device")"
  device="$(echo "$selected" | sed -n '1p')"
  state="$(echo "$selected" | sed -n '2p')"
  echo "使用模拟器：$(echo "$selected" | sed -n '3p') ($device)"
  if [[ "$state" != Booted ]]; then xcrun simctl boot "$device"; fi
  xcrun simctl bootstatus "$device" -b
  # Xcode versions may ship Simulator.app or DeviceHub.app.
  for app in "$developer_dir/Applications/Simulator.app" "$developer_dir/../Applications/DeviceHub.app"; do
    if [[ -d "$app" ]]; then
      open "$app" || echo "可手动在 Xcode 中打开模拟器窗口。" >&2
      break
    fi
  done
fi

# Bash 3.2 treats an empty array as unset under nounset; expand conditionally.
if [[ "$action" == run ]]; then
  if [[ "$platform" == macos ]]; then device=macos; fi
  exec "$flutter_bin" run -d "$device" "--$mode" ${extra[@]+"${extra[@]}"}
elif [[ "$platform" == ios-sim ]]; then
  "$flutter_bin" build ios --simulator "--$mode" ${extra[@]+"${extra[@]}"}
  echo "模拟器应用：$PWD/build/ios/iphonesimulator/Runner.app"
elif [[ "$platform" == ios ]]; then
  "$flutter_bin" build ios "--$mode" ${extra[@]+"${extra[@]}"}
  echo "真机应用：$PWD/build/ios/iphoneos/Runner.app"
  echo "安装并调试请执行：./build.sh ios run（需要有效的开发签名及已配对的真机）"
else
  "$flutter_bin" build macos "--$mode" ${extra[@]+"${extra[@]}"}
  case "$mode" in debug) mode_directory=Debug ;; profile) mode_directory=Profile ;; release) mode_directory=Release ;; esac
  echo "macOS 应用：$PWD/build/macos/Build/Products/$mode_directory/Asterkeel Wallet.app"
fi
