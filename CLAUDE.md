# SoScan · 项目说明(Claude Code)

> HarmonyOS NEXT 文档扫描 app,SoMark HDC2026 演示项目。
> 设计与计划见 `docs/superpowers/specs/` 与 `docs/superpowers/plans/`。

## 协作模式

- **构建 + 装机走命令行**:用仓库根的 `./dev.sh`(`build` / `install` / `launch` / `run` / `log` / `devices`)。它内联了 DevEco 工具链环境,不污染全局 shell。已验证 hvigorw 可独立构建 —— DevEco **不是**构建的唯一入口。
- **DevEco Studio 的职责**:① 一次性建工程 + 自动签名;② UI 实时预览(Previewer);③ 断点调试;④ Profiler;⑤ 模拟器。
- ⚠️ **不要在终端部署的同时跑 DevEco 的 ▶️ Run** —— 两边抢同一台设备会冲突(已踩坑:手机上 app 界面会突然消失)。需要 DevEco 时别让它的 Run 会话挂着。
- **屏幕与摄像头 Claude 看不到** —— UI 渲染、布局、相机效果由开发者在真机上确认并反馈(截图)。

## 构建反馈循环

- 改完代码先 `./dev.sh build` 拿编译器反馈再迭代,不要凭空写一大块。鸿蒙编译错误信息较详细,以构建输出为准。
- 需要时跑 codelinter(工程内已有 `code-linter.json5`)。

## 上下文卫生

- **`.claudeignore` 不是 Claude Code 的真实特性**(已查证),不要创建。
- `oh_modules/`、`.hvigor/`、`build/` 已被 `.gitignore` 忽略,不要扫描它们(Grep 默认遵循 .gitignore)。
- `oh-package-lock.json5`、`hvigor-config.json5` **不忽略** —— 它们是依赖锁与构建版本配置,体积小、偶尔要看,已纳入 git。

## HarmonyOS 领域知识

- `.claude/skills/harmonyos-development/` 装有第三方鸿蒙知识技能(ArkTS / ArkUI / Stage 模型 / 各 Kit)。具体语法以它为准,不要把领域教程堆进本文件。

## 关键事实

- 测试机:HUAWEI Mate 80 Pro,HarmonyOS 6.0.0 / API 22,设备号 `5JV0225A17000048`。
- 工程:`SoScan/`,`compatibleSdkVersion` 6.0.0(22),bundle `tech.somark.soscan`,入口 `EntryAbility`。
- 开发分支:`nwk/feat/soscan-mainline`。
