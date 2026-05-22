# SoScan · Stage 2 设计文档 —— EdgeSAM 穿刺 · UI Style A · 集成更新

- 状态:已确认(2026-05-22)
- 关系:补充主设计文档 `2026-05-20-soscan-hdc-demo-design.md`。
- 前置状态:P0 主线闭环已完成(阶段 0+1,git 标记 `b31a169`),工程在 `main` 可构建、可装真机(测试机 HUAWEI Mate 80 Pro / HarmonyOS 6.0.0 / API 22)。
- UI 视觉参考:`docs/superpowers/specs/2026-05-22-soscan-ui-three-styles-mockup.html`(9 轮迭代定稿)。
- 模型转换经验:`_misc/MindSpore Lite (.ms) 模型在 HarmonyOS 上部署的经验小结.md`。

## 0. 2026-05-22 计划调整(重要)

本文档初稿规划「三套 UI 风格并行评测」。当晚领导把 **EdgeSAM 端侧部署** 提前为 06-03 HDC 同档期任务 —— EdgeSAM 属于主文档 P2 的「SAM 特性」,现需提前做技术穿刺。据此调整:

- **EdgeSAM 穿刺** 插为当前最高优先级,独立窗口推进。
- **UI 收敛到 Style A 流光**,用现有 `ai.somark.demo`。B/C 降级为「保留方案」(P2),不再三套并行 —— 因此不启用三 worktree。
- 导出功能范围收窄到 **PDF**。

理由:端侧 SAM 部署有硬技术风险(主文档已点明「不能塞进冲刺,需独立攻关期」)。盘子已满 —— 把确定性的 UI 工作压到最小(只做 A),给 EdgeSAM 留余量。

## 1. 范围

Stage 2 = 两个窗口并行推进:

| 工作 | 窗口 | 优先级 |
|---|---|---|
| EdgeSAM 端侧部署穿刺 | 独立窗口(EdgeSAM) | 最高,先行 |
| UI Style A 流光 + 集成(LLM / 导出)+ 图标命名 | 独立窗口(SoScan) | 次之,在 EdgeSAM 空档推进 |

## 2. UI:Style A 流光(确定方向)

确定**只做 Style A 流光**,在现有 `ai.somark.demo` 上做 —— 不换 bundleName,A 复用已有签名,无需新签名。保留 SoMark 品牌识别:纯黑底、橙色 `#FF8C00`、「SoScan」字标 + 三段 logo mark。

### A · 流光 Aurora

- **气质**:Apple WWDC 风格的金属流光。冷峻、高级、克制。
- **首页**:纯黑底;顶部立体金属质感「SoScan」字标 + 三段 logo mark;副标「文档解析 · 结构还原」;文档列表为半透明微玻璃卡片;底部橙色光泽胶囊按钮「扫描文档」(带橙色辉光)。
- **标志性效果**:一束柔光以 ~13s 慢循环扫过字标 —— 扫到的字母被照到极亮(近全白),同时字母背后浮现一层**与该字母同形**的光晕(模糊的亮字),光晕天然随字母轮廓变化。无缝循环。
- **ArkUI 实现要点**:金属字 = 文字 + 线性渐变(渐变文字,或退到高清字标图);流光 = 一个亮度蒙版沿 X 轴平移的循环动画;光晕 = 同蒙版的模糊副本。mockup 用 CSS `background-clip:text`,ArkUI 无等价 API —— 若渐变文字 + 蒙版动画达不到效果,退到「字标图 + 高光位移层 + 模糊副本」三层叠加。**实现风险:中**(流光精度是成败点,留足调试时间)。
- 精确视觉以 mockup 文件为准。结果页 / 扫描页沿用 A 的主题 token,StructureRenderer 渲染逻辑不变。

### B/C 保留方案(P2)

B 漾 Fluid(整片流动液面)、C 触感 Tactile(实体键盘拟物)的完整设计见 mockup 文件及本文 git 历史(commit `e02a9f4`)。作为 A 之外的备选 —— 若 EdgeSAM 提前跑通有余力、或演示后,再考虑做成对比 app(届时各开一个新 bundleName)。当前不做。

## 3. EdgeSAM 端侧部署穿刺

**是什么**:EdgeSAM 是 SAM(Segment Anything)的端侧加速版 —— 把 SAM 的 ViT 编码器蒸馏成纯 CNN(RepViT),9.6M 参数,iPhone 14 上 38 FPS,已有 iOS App 落地。对应主文档 P2 的「SAM 特性」(精准边缘、多文档选中等)。

**本次目标 —— 穿刺**:`本地跑通 → 华为手机 CPU → 华为手机 NPU`,跑通 + 速度/精度 benchmark。**集成进 SoScan 的方式待跑通后单独设计**,本次不碰 SoScan 代码。

**为什么先穿刺**:模型转换 + NPU 算子适配不确定性高。越早跑、坑越早暴露,才有时间在 06-03 前补救或调整。

**链路**:PyTorch(EdgeSAM)→ ONNX(repo 自带导出脚本)→ ONNX patch → MindSpore Lite `.ms`(`converter_lite`)→ 设备端 `libmindspore_lite_ndk` 加载 → CPU 验证 → NPU 验证。

**执行**:独立窗口,详见 EdgeSAM 穿刺窗口交接 prompt。遇疑似华为平台 bug 的怪报错 —— 不死磕,写清症状同步负责人,由他找华为沟通。

## 4. 工程方案

- **UI Style A**:在 SoScan 仓库一个分支(`nwk/feat/ui-style-a`)上做,bundleName 维持 `ai.somark.demo`,完成合回 `main`。**无需 worktree**(worktree 原为三套并行准备)。
- **EdgeSAM 穿刺**:在 SoScan 仓库**之外**的独立目录推进(EdgeSAM 上游 clone + 转换产物 + 端侧测试 HAP),不污染 app 仓库。
- **签名**:A 复用 `ai.somark.demo` 现有签名,零新增。EdgeSAM 端侧测试 HAP 需一个自己的 bundleName + 一次签名(到「手机 CPU」阶段时 ping 负责人)。
- `dev.sh` 的 `BUNDLE` 维持 `ai.somark.demo`,不动。

## 5. LLM 集成更新(P1)

主文档原写「P1 LLM 命名/总结使用公司自有 LLM 接口」。**现更新为:阿里云百炼(Bailian / Model Studio)。**

- **模型**:`Qwen3.6-Flash`(暂定)。⚠️ 接入时以百炼控制台实际可用模型列表为准 —— 模型 ID 是一行配置,不影响架构。
- **调用**:百炼 OpenAI 兼容 HTTP 接口或原生 DashScope 接口,ArkTS `http` 直接调。
- **密钥**:`DASHSCOPE_API_KEY`,开发者已放 `~/.zshrc`。同 `SOMARK_API_KEY` 模式 —— 写进 `config.ets`(已 gitignore)。
- **功能不变**:P1 = 智能命名 + 一句话总结。输入是 SoMark 已解析的 markdown 文本,纯文本任务,Flash 档够用。由 `LlmService.ets` 实现。
- **优先级**:仍 P1,05-27 gate 通过才做。
- 附带观察:百炼通用 LLM 既就绪,P2「对话式追问」其实也可不靠小艺直接做 —— 但按用户「小艺后面再说」,仍留 P2。

## 6. API key 安全方案

**问题**:客户端 app 无法安全保存密钥,HAP 可反编译,`SOMARK_API_KEY` / `DASHSCOPE_API_KEY` 都能被提取。

- **阶段一(测试期,现在)**:key 放 `config.ets`(已 gitignore)、编进包 —— 受控演示环境,可接受。
- **阶段二(上线)**:**后端代理**。app 不带任何密钥,只调 `somark.tech`;SoMark 后端加 LLM 代理端点,服务端附加百炼密钥转发。收益:密钥永不进客户端、可随时轮换、可加限流防滥用;同时修掉 `SOMARK_API_KEY` 的同类暴露。属上线前工作,本次只入路线图。

## 7. 导出功能(P2,收窄到 PDF)

按 2026-05-22 决定,范围收窄:

- **做**:解析结果导出为 **PDF** —— 导出到系统文件目录、分享给其他 app。
- **不做**:图片导出 / 存相册。
- **华为 SDK**(原生可直接用):PDF 生成 = `@kit.PDFKit`(已是工程依赖,`PdfBuilder.ets` 有现成模式);存文件 = Core File Kit `DocumentViewPicker`;分享 = Share Kit。无需第三方库。
- 优先级 **P2(演示后)**。

## 8. 图标、应用名、资源清理

- **图标**:DevEco 模板分层图标(`background.png` / `foreground.png`)是脚手架默认,换成 SoScan 品牌图标(即 Style A 的图标)。
- **启动图**:`startIcon.png` 被 `module.json5` 的 `startWindowIcon` 引用 —— 不能删,替换成品牌版。
- **应用名**:`app_name` 设为「SoScan 智能扫描」(或「SoScan」),确认手机桌面正确显示。
- **资源清理**:只清 DevEco 模板里确实无引用的默认资源;被 `module.json5`/`app.json5` 引用的一律替换、不删。
- 并入 SoScan 窗口、随 Style A 一起做(name 是分钟级配置,开头随手清)。

## 9. 优先级路线图

- **P0(已完成)**:主线闭环 + 持久化。
- **当前 / 06-03 前**:
  - EdgeSAM 端侧部署穿刺(最高,独立窗口)。
  - UI Style A 流光 + 图标/名称/清理。
  - P1:LLM 智能命名 + 一句话总结(百炼 Qwen,05-27 gate 通过则做)。
- **P2(演示后 / 有余力)**:
  - SAM 特性集成进 SoScan(跑通后单独 brainstorm 整合方式)。
  - UI Style B/C 对比 app。
  - 导出功能(PDF)。
  - API key 后端代理(上线前必做)。
  - 小艺对话式追问、事后重拍等(主文档原 P2)。

(范围表述原则:低优先级 = 排期靠后,不是砍掉。)

## 10. 推进方式

- **双窗口**:EdgeSAM 窗口(穿刺,先行专注)+ SoScan 窗口(UI Style A + 集成 + 图标命名)。两者目录不重叠、互不冲突。
- **不真并行**:负责人一人一台手机,EdgeSAM 先坐前排;UI 在 EdgeSAM 的等待空档(等转换、等华为回复)推进。UI 设计已固化在本文档 + mockup,等得起;EdgeSAM 是研究性的,需连续专注。
- EdgeSAM 跑通后:① 出 benchmark;② 单独 brainstorm「SAM 如何整合进 SoScan 扫描流程」。
- **诚实排期**:EdgeSAM 不确定性高,可能数天、也可能卡在平台问题。这正是把 UI 砍到只做 A 的原因 —— 留余量。
