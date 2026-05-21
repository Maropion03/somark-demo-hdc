#!/bin/bash
# SoScan 构建/部署封装 —— 内联 DevEco 工具链环境,不污染全局 shell。
# 用法: ./dev.sh {build|install|launch|run|log|devices}
set -e

DEVECO="/Applications/DevEco-Studio.app"
export DEVECO_SDK_HOME="$DEVECO/Contents/sdk"
HVIGORW="$DEVECO/Contents/tools/hvigor/bin/hvigorw"
HDC="$DEVECO/Contents/sdk/default/openharmony/toolchains/hdc"
NODE_BIN="$DEVECO/Contents/tools/node/bin"

PROJ="$(cd "$(dirname "$0")" && pwd)"
HAP="$PROJ/entry/build/default/outputs/default/entry-default-signed.hap"
BUNDLE="ai.somark.demo"
ABILITY="EntryAbility"

build()   { cd "$PROJ" && PATH="$NODE_BIN:$PATH" "$HVIGORW" assembleHap; }
install() { "$HDC" install "$HAP"; }
launch()  { "$HDC" shell aa start -a "$ABILITY" -b "$BUNDLE"; }

case "${1:-}" in
  build)   build ;;
  install) install ;;
  launch)  launch ;;
  run)     build && install && launch ;;        # 构建 + 装机 + 启动
  log)     shift; "$HDC" hilog "$@" ;;           # 流式日志,可接过滤参数
  devices) "$HDC" list targets ;;
  *) echo "用法: ./dev.sh {build|install|launch|run|log|devices}"; exit 1 ;;
esac
