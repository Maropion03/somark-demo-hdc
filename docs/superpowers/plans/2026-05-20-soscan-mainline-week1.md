# SoScan 主线闭环(阶段 0 + 阶段 1)实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 打通「拍照/相册 → 华为 DocumentScanner 矫正 → SoMark API 解析 → 原图↔结构对比展示 → 文档列表」端到端主线,产出 HDC2026 可演示的成品。

**Architecture:** ArkTS + ArkUI Stage 模型,单 entry 模块。DocumentScanner 控件负责扫描与矫正;ArkTS HTTP 以 multipart 调 SoMark 解析 API;ArkUI Web 组件渲染结构化结果;应用沙箱文件 + JSON 索引做持久化。

**Tech Stack:** HarmonyOS NEXT、ArkTS/ArkUI、DevEco Studio、hvigorw、hdc、`@kit.VisionKit`、SoMark Parse API

---

## 执行说明(本计划相对标准 writing-plans 的适配)

- **验证方式**:本项目是相机/UI/网络 app,无自动化测试框架 —— 每个任务的验证是「构建安装到真机 + 开发者在手机上操作确认」,对应设计文档第 8 节。计划中的「验证」步骤即真机手测。
- **代码产出**:HarmonyOS ArkTS API 的精确签名需在执行时对照实时官方文档确认,故各任务给出**文件、职责、关键 API 入口、验证标准、提交点**;完整代码在执行该任务时编写。
- **协作**:Claude Code 写 `.ets` 代码并用 hvigorw/hdc 构建部署;开发者做 DevEco GUI 一次性操作 + 真机操作并反馈。带 **👤** 标记的步骤需要开发者动手。
- **执行方式**:建议 inline(在对话中逐任务执行 + checkpoint),因为每个任务都依赖真机反馈闭环。

**环境实况(2026-05-20 探测):** DevEco 在 `/Applications/DevEco-Studio.app`;hvigorw 在 `Contents/tools/hvigor/bin/hvigorw`;SDK 在 `Contents/sdk/default`。

---

## 阶段 0 — 准备

### Task 0.1: 命令行环境

**Files:** `~/.zshrc`

- [ ] 确认 `hdc` 路径(预期 `Contents/sdk/default/openharmony/toolchains/hdc`)
- [ ] 把 `hvigorw`、`hdc` 所在目录加入 PATH,配置 `DEVECO_SDK_HOME`,写入 `~/.zshrc`
- [ ] 验证:新终端 `hvigorw -v`、`hdc -v` 输出版本号
- [ ] 验证:`hdc list targets` 列出已连接的手机

### Task 0.2: 👤 DevEco 新建工程

**Files:** 创建 `08-HDC/SoScan/`(整个鸿蒙工程)

- [ ] 👤 DevEco Studio → Create Project → Empty Ability 模板
- [ ] 👤 工程名 `SoScan`、保存到 `08-HDC/` 下、语言 ArkTS、Stage 模型、API 取默认
- [ ] 👤 等待 DevEco 完成 Sync(首次会下载依赖)
- [ ] 验证:工程结构正常、无报错(执行时 Claude Code 提供逐步图文)

### Task 0.3: 👤 自动签名

**Files:** `SoScan/build-profile.json5`(DevEco 自动写入)

- [ ] 👤 DevEco → File → Project Structure → Signing Configs → 勾选 Automatically generate signature,华为账号登录
- [ ] 验证:`build-profile.json5` 出现 `signingConfigs`,无签名报错

### Task 0.4: 工具链穿刺

**Files:** `SoScan/entry/src/main/ets/pages/Index.ets`(改一行文字)

- [ ] 在 Index 页改一处可见文字
- [ ] 命令行构建:`hvigorw assembleHap`,确认产出 signed `.hap`
- [ ] `hdc install <hap 路径>` 装到真机
- [ ] 验证:👤 手机上打开 app 看到改动 —— 证明「改代码 → 命令行构建 → 上手机」整条链路打通
- [ ] 排查并解决此过程中的环境问题(若有)

### Task 0.5: git 接管 + 工作流速查

**Files:** `08-HDC/.gitignore`(补充)、`08-HDC/工作流速查.md`(创建)

- [ ] `SoScan/` 工程纳入 08-HDC git 仓库;`.gitignore` 已含 build 产物/oh_modules/签名材料,按需补充
- [ ] 创建 `工作流速查.md`:环境变量、常用 hvigorw/hdc 命令、真机连接步骤
- [ ] 提交:`git commit -m "chore: 接入 SoScan 鸿蒙工程脚手架"`

---

## 阶段 1 — 主线闭环

### Task 1: app 骨架与导航

**Files:**
- Modify: `SoScan/entry/src/main/ets/pages/Index.ets`
- Create: `SoScan/entry/src/main/ets/pages/ResultPage.ets`
- Create: `SoScan/entry/src/main/ets/model/Document.ets`
- Modify: `SoScan/entry/src/main/module.json5`

- [ ] 定义 `Document` 模型:`id`、`name`、`createdAt`、`originalImageUris: string[]`、`parsedMarkdown?`、`parsedJson?`、`summary?`(P1 用)
- [ ] Index 首页:醒目的「扫描」按钮 + 文档列表区(先放空态占位)
- [ ] ResultPage 结果页空壳 + 配置页面路由
- [ ] `module.json5` 声明权限:`ohos.permission.CAMERA`、`ohos.permission.INTERNET`
- [ ] 构建安装到真机
- [ ] 验证:👤 打开 app 看到首页与「扫描」按钮,点按钮能跳到空结果页
- [ ] 提交:`git commit -m "feat: app 骨架与首页/结果页导航"`

### Task 2: DocumentScanner 接入

**Files:**
- Create: `SoScan/entry/src/main/ets/pages/ScannerPage.ets`
- Modify: `Index.ets`(「扫描」按钮接上)

关键 API:`import { DocumentScanner, DocumentScannerConfig, DocType, FilterId, SaveOption } from '@kit.VisionKit'`。配置:`supportType:[DocType.DOC]`、`maxShotCount:10`、`isGallerySupported:true`、`defaultFilterId:FilterId.STRENGTHEN`、`saveOptions:[SaveOption.JPG]`。回调:`onResult(code, saveType, uris)`——code 200 成功、-1 取消。

- [ ] 实现 ScannerPage:嵌入 `DocumentScanner` 控件 + 上述配置
- [ ] `onResult` 拿 `uris`,先用 hilog 打印;200 跳转、-1 返回、其他码提示
- [ ] Index 的「扫描」按钮跳转 ScannerPage
- [ ] 构建安装到真机
- [ ] 验证(= 华为矫正 SDK 效果验证):👤 拍一份文档走完扫描流程,hilog 出现结果 URI;一起评估矫正质量(歪斜、边缘、反光)
- [ ] 提交:`git commit -m "feat: 接入华为 DocumentScanner 扫描矫正"`

### Task 3: 数据持久化 DocumentStore

**Files:** Create `SoScan/entry/src/main/ets/services/DocumentStore.ets`

关键 API:`getContext(this).filesDir` 拿沙箱目录;`@ohos.file.fs` 做文件读写复制;文档列表存为一个 JSON 索引文件。

- [ ] 实现 DocumentStore:`saveDocument(doc)`、`listDocuments()`、`getDocument(id)`;把扫描结果文件从临时 URI 复制进沙箱
- [ ] app 启动处跑一次「存一条 → 读出来」自检,hilog 验证
- [ ] 构建安装到真机
- [ ] 验证:hilog 显示存取成功,重启 app 后数据仍在
- [ ] 提交:`git commit -m "feat: 文档本地持久化 DocumentStore"`

### Task 4: SoMark API 接入

**Files:**
- Create: `SoScan/entry/src/main/ets/services/SoMarkApi.ets`
- Create: `SoScan/entry/src/main/ets/services/config.ets`(API key,**加入 .gitignore**)

关键:`@ohos.net.http`,multipart/form-data POST `https://somark.tech/api/v1/parse/sync`。字段:`file`、`api_key`、`output_formats=['markdown','json']`、`element_formats`、`feature_config`。响应:`data.result.outputs.markdown` / `.json`。超时设大(解析可能数十秒)。

- [ ] `config.ets` 放 API key 并加入 `.gitignore`(key 不进 git)
- [ ] 实现 `SoMarkApi.parse(filePath)`:multipart 上传 → 解析响应 → 返回 `{markdown, json}`
- [ ] 错误处理:网络失败、HTTP 非 200、响应 `code≠0`、超时 → 抛明确错误
- [ ] 用一个固定本地文件先测一次,hilog 打印返回 markdown
- [ ] 构建安装到真机
- [ ] 验证:hilog 出现真实解析返回的 markdown 文本
- [ ] 提交:`git commit -m "feat: 接入 SoMark 解析 API"`

### Task 5: 主流程串联

**Files:** Modify `Index.ets`、`ScannerPage.ets`

- [ ] 扫描成功 → 调 `SoMarkApi.parse` → 存 `DocumentStore` → 刷新首页列表
- [ ] loading 态:解析期间显示进度/提示
- [ ] error 态:失败显示错误 + 重试入口
- [ ] 构建安装到真机
- [ ] 验证:👤 拍文档 → 等解析 → 首页出现新文档;断网测一次错误态
- [ ] 提交:`git commit -m "feat: 打通扫描-解析-存储主流程"`

### Task 6: 结果页「原图↔结构」对比

**Files:**
- Create: `SoScan/entry/src/main/ets/components/StructureRenderer.ets`
- Create: `SoScan/entry/src/main/resources/rawfile/render.html`(渲染模板,含公式渲染库)
- Modify: `ResultPage.ets`

关键:ArkUI `Web` 组件加载本地 HTML 模板;markdown / json blocks 转 HTML 注入(表格用 API 返回的 HTML,公式用 KaTeX/MathJax),套 SoMark 品牌 CSS。ResultPage 用分段控件切换「原图 | 解析结构」,原图侧用 `Image`(多页可滑)。

- [ ] 准备 `render.html` 模板:基础 HTML + 公式渲染库 + SoMark 暗色品牌 CSS
- [ ] 实现 StructureRenderer:Web 组件 + 解析结果转 HTML 注入
- [ ] 实现 ResultPage:分段控件「原图 / 解析结构」对比布局
- [ ] 首页列表项点击 → 进 ResultPage 并传文档 id
- [ ] 构建安装到真机
- [ ] 验证:👤 点一个文档,看到原图与还原结构,表格/公式/版式正常,可切换
- [ ] 提交:`git commit -m "feat: 结果页原图↔结构对比展示"`

### Task 7: 首页文档列表打磨

**Files:** Modify `Index.ets`

- [ ] 列表卡片:缩略图(原图首图)、文档名、日期
- [ ] 空态:无文档时的引导文案 + 扫描按钮
- [ ] 构建安装到真机
- [ ] 验证:👤 确认列表卡片、缩略图、空态显示正常
- [ ] 提交:`git commit -m "feat: 首页文档列表卡片"`

### Task 8: 阶段 1 真机回归

**Files:** 无新增,按需修 bug

- [ ] 👤 用多种文档跑全链路:表格、公式、多栏、歪斜、反光、多页
- [ ] 记录问题,逐一修复并提交
- [ ] 确认整条主线在真机上稳定 —— 这是 05-27 Gate 的输入

---

## Gate(~05-27)

阶段 1 真机回归通过 → 主线成品达成 → 进入阶段 2,并决定是否做 P1(LLM 智能命名/总结)。阶段 2 的详细计划在 Gate 后另写。
