# somark文档智能app

HarmonyOS NEXT 上的智能文档扫描与对话演示应用，为 **SoMark HDC 2026** 打造。

应用市场展示名：**somark文档智能**
工程 / Bundle / 日志 TAG：**SoMark** · `cn.somark.demo`

---

## 这是什么？

用手机对准纸质文档或照片，完成**扫描矫正 → 结构化解析 → 阅读与引用 → AI 对话**的完整闭环：

1. **扫描**：调用华为 DocumentScanner，多页拍摄、透视矫正、滤镜。
2. **解析**：SoMark Parse API 将文档转为 Markdown + 逐页 block 结构（标题、正文、表格、图片等）。
3. **阅读**：文档详情页以类「预览」方式浏览多页原图，支持半屏解析对照、框选与实体识别（电话 / 网址 / 地址）。
4. **对话**：将文档或选区拖入聊天，基于引用内容与 LLM 问答（OpenAI 兼容接口）。

本仓库是**可构建运行的 HarmonyOS 工程**，不是设计稿或静态 Demo。

---

## 主要功能

| 模块 | 说明 |
|------|------|
| 首页 | 文档列表，进入扫描或已有文档 |
| 扫描页 | DocumentScanner 多页采集 |
| 结果页 | 解析进度与结果预览 |
| 文档详情 | 多页竖滑原图、block 高亮、长按跨页框选、解析抽屉、加入对话 |
| 聊天页 | 多轮会话、引用 chip、底部文档抽屉（搜索 / 拖拽引用） |
| 持久化 | 文档与聊天会话本地存储 |

### 文档详情页亮点

- **多页预览**：白底、页间间距、多页细黑边框；顶栏橙色页码胶囊。
- **缩略图轨**（仅多页）：点击页码胶囊打开左侧液态玻璃缩略图，点空白关闭，点击缩略图跳转页面。
- **解析抽屉**：半屏高度可调低，顶栏「解析 / 收起」切换；原文与解析分区滚动。
- **选区交互**：点击原文弹出操作卡；解析抽屉打开时先收起抽屉再点原文出卡；支持网址 Web 预览、地址地图预览。

---

## 技术栈

- **平台**：HarmonyOS NEXT 6.0（API 22）· Stage 模型
- **语言 / UI**：ArkTS · ArkUI
- **工具链**：DevEco Studio · Hvigor · `./dev.sh` 命令行构建
- **系统能力**：`@kit.VisionKit`（扫描）、`@kit.MapKit`（地址）、`@kit.ArkWeb`、网络与本地存储
- **云端**： [SoMark Parse API](https://somark.tech) · OpenAI 兼容 Chat API（DMX 等网关）

---

## 环境要求

- macOS（推荐，与 DevEco / `dev.sh` 脚本一致）
- [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/)（首次签名、预览、调试）
- HarmonyOS 真机或模拟器（API 22）
- 有效的 **SoMark API Key** 与 **LLM API**（聊天功能）

---

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/Maropion03/somark-demo-hdc.git
cd somark-demo-hdc
```

### 2. 配置 API 密钥

`config.ets` 不入库。复制示例并填写：

```bash
cp entry/src/main/ets/services/config.ets.example entry/src/main/ets/services/config.ets
```

编辑 `config.ets`，填入 `SOMARK_API_KEY` 以及聊天用的 `DMX_API_URL` / `DMX_API_KEY` / `DMX_MODEL`（或你使用的兼容端点）。

### 3. 签名（一次性）

在 DevEco Studio 中打开工程 → **Signing Configs** → 配置自动调试签名。  
本地签名路径会写入 `build-profile.json5`，该文件请保持在本机、勿提交含个人路径的变更。

### 4. 构建与安装

仓库根目录的 `dev.sh` 已内联 DevEco 工具链环境：

```bash
./dev.sh build      # 编译 HAP
./dev.sh devices    # 查看已连接设备
./dev.sh install    # 安装到真机
./dev.sh launch     # 启动应用
./dev.sh run        # build + install + launch
./dev.sh log        # 查看 hilog（可跟过滤参数）
```

> 请勿在终端 `./dev.sh run` 的同时用 DevEco 点 Run，避免争抢同一设备导致应用被踢掉。

---

## 工程结构

```
somark-demo-hdc/
├── dev.sh                          # 构建 / 部署脚本
├── entry/src/main/ets/
│   ├── entryability/               # EntryAbility
│   ├── pages/
│   │   ├── Index.ets               # 首页 / 文档列表
│   │   ├── ScannerPage.ets         # 扫描
│   │   ├── ResultPage.ets          # 解析结果
│   │   ├── DocumentViewerPage.ets  # 文档阅读与选区
│   │   └── ChatPage.ets            # AI 对话
│   ├── components/                 # UI 组件（抽屉、消息列表、Markdown Web 等）
│   ├── services/                   # API、存储、解析轮询、PDF 等
│   └── model/                      # 数据模型
├── entry/src/main/resources/
│   └── rawfile/md/                 # 文档内嵌 Markdown 渲染资源
└── docs/superpowers/               # 产品与实现设计文档（可选阅读）
```

---

## 协作与分支

内部开发默认分支策略：`nwk/<type>/<topic>` → Merge Request 合入 `main`。  
GitLab 上游：`gitlab.soulcode.cn/somark/edge_infer/somark-demo-hdc`  
本 GitHub 仓库为**公开镜像**，便于展示与 Fork。

更细的构建约定见仓库内 [`CLAUDE.md`](./CLAUDE.md)。

---

## 路线图（摘要）

- **当前**：扫描 → 解析 → 列表持久化 → 文档阅读 / 框选 / 聊天引用
- **近期**：智能命名、一句话摘要、PDF 导出增强
- **后续**：端侧选区（EdgeSAM 等）与更深度的结构编辑

---

## 许可证与声明

本项目为 SoMark HDC 演示工程。API 密钥、签名材料由使用者自行申请与保管，勿提交到公开仓库。

如有问题或合作意向，请通过 GitHub Issues 反馈。
