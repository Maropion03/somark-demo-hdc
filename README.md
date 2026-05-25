# 扫描王中王 · 智能文档扫描

> 应用市场名「扫描王中王」;仓库 / 工程名沿用 SoScan,bundle `ai.somark.demo`。

SoMark HDC2026 演示用 HarmonyOS NEXT 文档扫描 app。手机对准文档,瞬间得到精准还原的结构化解析结果 —— 华为 DocumentScanner 负责扫描矫正,SoMark 解析 API 负责结构化解析。

## 功能

- 拍照 / 相册导入,华为 DocumentScanner 自动矫正(支持多页、滤镜)
- SoMark API 解析单页 / 多页文档,还原标题层级、正文、表格
- 「原图 ↔ 解析结构」对比展示
- 文档列表 + 本地持久化

## 路线图

- **Now**:主线闭环(扫描 / 解析 / 列表 / 持久化)+ Style A 流光 UI(P0 已完成)
- **Next**:LLM 智能命名 + 一句话总结(P1,百炼 Qwen)、PDF 导出(P2)
- **Later**:EdgeSAM 长按选内容(端侧 NPU 已穿刺验证,接力模式集成)

## 构建运行

仓库根的 `dev.sh` 内联了 DevEco 工具链环境:

```bash
./dev.sh build      # 构建 HAP
./dev.sh install    # 装到真机
./dev.sh launch     # 启动
./dev.sh run        # build + install + launch
./dev.sh log        # 流式日志
./dev.sh devices    # 列出已连接设备
```

工程需先用 DevEco Studio 建好并配置自动签名(一次性 GUI 操作)。

## 工程结构

```
entry/src/main/ets/
├── pages/         首页 / 扫描页 / 结果页
├── components/    StructureRenderer —— 结构化结果渲染
├── services/      SoMarkApi / DocumentStore / PdfBuilder
├── model/         Document 数据模型
└── entryability/  应用入口
```

## 技术栈

HarmonyOS NEXT · ArkTS / ArkUI(Stage 模型)· DevEco Studio · `@kit.VisionKit` · `@kit.PDFKit` · SoMark Parse API

## 说明

- `entry/src/main/ets/services/config.ets`(SoMark API key)不纳入 git,需本地创建。
- 协作约定与构建细节见 `CLAUDE.md`;设计文档与计划见 `docs/superpowers/`。
