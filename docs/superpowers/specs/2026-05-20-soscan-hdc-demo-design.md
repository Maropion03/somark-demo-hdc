# SoScan · HDC2026 演示 Demo 设计文档

- 状态:已确认(2026-05-20)
- 项目:SoMark HDC2026 HarmonyOS NEXT 文档扫描 app(工作名「SoScan 智能扫描」)
- 工期:2 周冲刺 —— 第 1 周(~2026-05-27)出成品,第 2 周(~2026-06-03)打磨

## 1. 背景与目标

SoMark 是一家文档解析公司,需要一个 HarmonyOS NEXT 手机 app 在 HDC2026 华为开发者大会上演示,代表公司展示文档解析实力。

核心演示价值:**把手机对准一份文档,瞬间得到精准还原的结构化解析结果。** 华为 DocumentScanner 负责扫描与矫正,SoMark API 负责解析,二者结合就是 demo 的主线。

约束:开发者第一次做移动 app 开发;开发机为 MacBook M2 + DevEco Studio;测试机为一台纯血鸿蒙手机。

## 2. 范围与优先级

需求文档 `Software Requirements.md` 是完整产品愿景。本次 2 周演示按优先级分层交付。**下列功能均在路线图内;P2+ 为演示后的后续阶段,是排期,不是取消。**

### P0 — 2 周演示必达(主线闭环)
- 拍照 + 相册导入 → DocumentScanner 自动矫正(自带多页、滤镜、单次扫描会话内的重拍/裁剪编辑)
- 上传 SoMark API → 拿到 Markdown + 结构化 JSON
- 结果页:「原图 ↔ 还原结构」对比展示
- 首页文档列表 + 本地持久化
- SoMark 暗色品牌 UI + 关键动效

### P1 — 2 周内有条件(05-27 gate 通过则做)
- LLM 智能命名 + 一句话总结
- 文档类型自动归类(若 P1 顺利可顺带)

### P2 及以后 — 演示后继续(完整愿景,按优先级)
- 小艺追问对话(文档内追问、预设问题)—— 可用 Agent Framework Kit 嵌入小艺对话组件
- 文档事后重拍 / 追加图片 / 拖拽排序 → 重走解析流程
- SAM 特性:精准边缘、多文档选中跟踪、拍前防抖/畸变/反光多帧合成
- 需求文档其余特色

### 关键说明
- **2 周实际可交付 P0(+ 视 gate 情况 P1)。** P2+ 落在演示之后。
- **SAM 特性**额外标注:不只是优先级低 —— 端侧 SAM 部署(模型转换、算子兼容、NPU 适配)有硬技术风险,真正做时需安排独立攻关期,不能塞进冲刺。
- **LLM 来源**:华为没有面向第三方 app 的「传文本 → 返回摘要」LLM 接口(小艺 Agent Framework 只能嵌对话界面、拿不到可处理文本;华为云盘古 API 面向企业、申请流程不透明)。P1 的 LLM 命名/总结使用**公司自有 LLM 接口**(HTTP 调用)。小艺更适合 P2 的「对话式追问」。

## 3. 路线图与逐日计划

### 阶段 0 — 准备(Day 1,~0.5–1 天)
- 环境:`hvigorw` / `hdc` 加入 PATH,配置 `DEVECO_SDK_HOME`
- 建工程:DevEco Studio 新建 ArkTS / Stage 模型工程(开发者操作,提供图文步骤)
- 自动签名:DevEco 一次性配置(GUI 必需)
- **工具链穿刺**:改一行代码 → `hvigorw` 构建 → `hdc` 装到真机 → 运行,证明「改代码 → 上手机」整条链路打通
- git 仓库与目录结构就绪

### 阶段 1 — 主线闭环(Week 1,= 成品)

| 模块 | 估时 | 产出 |
|---|---|---|
| DocumentScanner 接入 | ~1.5 天 | 嵌控件、配多页/相册/滤镜、拿到扫描结果 URI;真机验证矫正效果 |
| SoMark API 接入 | ~1 天 | multipart 上传、拿 markdown+json、loading/超时/错误处理 |
| 结果页「原图↔结构」 | ~2 天 | 结构渲染(表格/公式/图片/版式);技术不确定性最高,留时间最多 |
| 首页列表 + 持久化 + 联调 | ~1.5 天 | 文档列表首页、本地存取、导航串联、真机回归 |

**05-27 Gate**:主线稳 → 进 P1;不稳 → 砍 P1,全力打磨。

### 阶段 2 — 打磨(Week 2)

| 模块 | 估时 | 产出 |
|---|---|---|
| UI 品牌化 + 动效 | ~2 天 | SoMark 暗色品牌、原图→结构转场动画、图标、空态 |
| P1 LLM 特性(gate 通过才做) | ~1.5 天 | 智能命名 + 一句话总结 |
| 演示彩排 + 兜底 | ~2 天 | 示例文档、弱网/失败兜底 UI、完整录屏备份、真机回归 |
| buffer | 余量 | 修 bug |

周末按开发者实际工作节奏算作 buffer 或工作日。

## 4. 技术架构

### 工程结构
```
SoScan/                          项目目录(08-HDC/SoScan,DevEco 新建)
├── AppScope/app.json5           应用级:包名、版本
├── entry/src/main/
│   ├── ets/
│   │   ├── entryability/EntryAbility.ets   应用入口
│   │   ├── pages/
│   │   │   ├── Index.ets         首页:文档列表
│   │   │   └── ResultPage.ets    结果页:原图↔结构
│   │   ├── services/
│   │   │   ├── SoMarkApi.ets     解析 API 客户端
│   │   │   ├── DocumentStore.ets 本地持久化
│   │   │   └── LlmService.ets    LLM(P1)
│   │   ├── components/
│   │   │   └── StructureRenderer.ets  结构渲染
│   │   └── model/Document.ets    数据模型
│   ├── resources/                图片/颜色/字符串
│   └── module.json5              模块配置 + 相机/网络权限
└── (hvigor / oh-package 等构建配置,DevEco 自动生成)
```

### 模块职责(每个一个职责)
- **DocumentScanner 接入** — 薄封装华为 `@kit.VisionKit` 控件:给配置、收扫描结果 URI
- **SoMarkApi** — 文件 → 解析 API → markdown + json
- **StructureRenderer** — 解析结果渲成结构(Web 组件 + 公式渲染 + API 自带 HTML 表格 + 品牌 CSS)
- **DocumentStore** — 文档记录存取(应用沙箱文件存原图/结果,JSON 索引存列表)
- **LlmService** — P1:命名 + 总结
- **页面** — Index 列表页、ResultPage 对比页

### 技术选型
| 项 | 选型 |
|---|---|
| 语言 / 框架 | ArkTS + ArkUI 声明式,Stage 模型 |
| API level | 以 DevEco 当前默认为目标,最低 API 12(DocumentScanner 要求) |
| 华为扫描 | Vision Kit DocumentScanner(`@kit.VisionKit`),可嵌入控件,真机限定 |
| 网络 | ArkTS HTTP(multipart),调 `https://somark.tech/api/v1/parse/sync` |
| 结构渲染 | ArkUI Web 组件渲染 HTML |
| 持久化 | 应用沙箱文件存资产,JSON 索引存文档列表 |
| 权限 | 相机、网络 |

## 5. 数据流
```
点「扫描」
 → DocumentScanner(拍照/相册 → 自动矫正 → 多页编辑)
 → onResult 回调:JPG/PDF 的 URI 列表
 → SoMarkApi.parse(file):multipart 上传 → { markdown, json: pages→blocks }
 → StructureRenderer 渲染「还原结构」
 → DocumentStore.save:原图 + 解析结果 + 元数据
 → 首页列表出现新文档
 → (P1) LlmService:命名 + 一句话总结 → 更新卡片
```

## 6. 错误处理
- **DocumentScanner** `onResult`:200 成功 / -1 用户取消(静默返回) / 其他错误码 → 提示并允许重试
- **SoMark API**:网络失败、HTTP 非 200、响应 `code≠0`、超时 → 明确错误态 + 重试入口
- **LLM(P1)**:失败则跳过命名/总结,用默认名,不阻断主流程
- **持久化**:文件缺失时优雅降级,不崩溃

## 7. 关键风险与兜底
| # | 风险 | 兜底 |
|---|---|---|
| 1 | **结构渲染**(最大未知)—— ArkUI 无内置 markdown 渲染 | Web 组件渲 HTML;再不行退到纯文本 + API 自带 HTML 表格。预留最多时间 |
| 2 | SoMark 同步解析多页文档可能耗时数十秒 | 大方超时设置 + 好看 loading + 演示用页数适中的文档 |
| 3 | HDC 现场网络 / 真机不稳 | 第 2 周录完整演示录屏作备份;失败有兜底 UI |
| 4 | 2 周工期偏紧 | 降级兜底:砍掉「原图↔结构」对比页,退到纯主线(拍照→解析→Markdown 渲染→列表);设 05-27 gate;P1 可砍 |

## 8. 协作与测试

### 协作模式
- **Claude Code**:在仓库读写 `.ets` 代码;用 `hvigorw` 构建、`hdc` 装机、`hdc hilog` 看日志。「改代码 → 构建 → 上机 → 看日志」循环自主完成。
- **开发者**:① 一次性在 DevEco 建工程 + 自动签名;② 手机连 Mac;③ 当「眼睛」—— 在手机上操作摄像头、点按,反馈所见 / 截图。屏幕与摄像头 Claude Code 不可见。
- 每个需开发者动手的环节提供具体步骤;仓库内维护 `工作流速查.md`。

### 测试
- 主战场为真机(DocumentScanner 仅真机可用)。
- 华为 SDK 效果验证 = 手机上扫多种文档(表格、公式、多栏、歪斜、反光),共同评估矫正质量。
- API 联调 = 真实文档走真实 SoMark API。
- 2 周 demo 不做自动化测试,靠真机手测 + 开发者反馈闭环。

## 9. 演示前确认项
- DocumentScanner 计费政策:开发前在华为开发者控制台确认一次(端侧能力,大概率免费)。
- 演示机型:确保 HarmonyOS 5/6 真机;若演示表格识别,提前确认机型支持 DocumentScanner 的 SHEET 类型。
