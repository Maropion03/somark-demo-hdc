import { DocumentRecord } from '../model/Document';
import { PageMarkdownSheet } from '../components/PageMarkdownSheet';
import { BboxImagePage } from '../components/BboxImagePage';
import { MarkdownWeb } from '../components/MarkdownWeb';
import { BlockRef, Citation } from '../model/Chat';
import { SmPageInfo, SmBlock, parseSmDoc } from '../model/SmDoc';
import { DocumentStore } from '../services/DocumentStore';
import { ShareHelper } from '../services/ShareHelper';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction, display } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Theme } from '../common/Theme';

const TAG: string = 'SoScan';

interface ChatPageParam {
  sessionId?: string;
  drawerOpen?: boolean;
}

interface Hit {
  page: number;
  idx: number;
}

/**
 * PRD §6/§7:文档查看页。多页竖向无缝瀑布流 + bbox 选区(支持**跨页多选**) + 左滑/解析看 Markdown。
 * 选区状态集中在本页:各 BboxImagePage 上报全局坐标,这里跨页 hit-test、算选区、统一出操作卡。
 */
@Component
export struct DocumentViewerPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @StorageLink('documents') documents: DocumentRecord[] = [];
  docId: string = '';
  @State currentPage: number = 0;
  @State mdVisible: boolean = false;
  @State mdFullDoc: boolean = false;
  @State pages: SmPageInfo[] = [];
  @State screenW: number = 360;
  // 跨页选区(flat 位置 = 页号 + 该页 block 数组下标)
  @State anchorPage: number = -1;
  @State anchorIdx: number = -1;
  @State curPage: number = -1;
  @State curIdx: number = -1;
  @State pressing: boolean = false;   // 长按框选中
  @State carding: boolean = false;    // 操作卡显示
  private pageTopY: number[] = [];    // 各页图片全局 Y(onGeometry 上报)
  scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    try {
      this.screenW = this.getUIContext().px2vp(display.getDefaultDisplaySync().width);
    } catch (e) {
      this.screenW = 360;
    }
    const doc = this.currentDoc();
    if (doc !== undefined) {
      this.pages = parseSmDoc(doc.parsedJson);
    }
  }

  currentDoc(): DocumentRecord | undefined {
    return this.documents.find((d: DocumentRecord) => d.id === this.docId);
  }

  pageHeight(idx: number): number {
    if (idx < this.pages.length) {
      const p: SmPageInfo = this.pages[idx];
      if (p.w > 0 && p.h > 0) return this.screenW * (p.h / p.w);
    }
    return this.screenW * 1.414;
  }

  emptyPage(): SmPageInfo {
    return { pageNum: 0, w: 0, h: 0, blocks: [] };
  }

  pageInfo(idx: number): SmPageInfo {
    return idx < this.pages.length ? this.pages[idx] : this.emptyPage();
  }

  pageScale(p: number): number {
    const pi: SmPageInfo = this.pageInfo(p);
    return pi.w > 0 ? this.screenW / pi.w : 1;
  }

  // 容器框(包住别的 block)→ 不可选
  isContainer(p: number, i: number): boolean {
    const blocks: SmBlock[] = this.pageInfo(p).blocks;
    const b: SmBlock = blocks[i];
    for (let j = 0; j < blocks.length; j++) {
      if (j === i) continue;
      const o: SmBlock = blocks[j];
      const cx: number = (o.x1 + o.x2) / 2;
      const cy: number = (o.y1 + o.y2) / 2;
      if (cx > b.x1 && cx < b.x2 && cy > b.y1 && cy < b.y2) return true;
    }
    return false;
  }

  // 全局坐标 → 命中页与最内层非容器 block
  hitGlobal(gx: number, gy: number): Hit {
    for (let p = 0; p < this.pages.length; p++) {
      const top: number = this.pageTopY[p] !== undefined ? this.pageTopY[p] : -99999;
      const h: number = this.pageHeight(p);
      if (gy >= top && gy < top + h) {
        const s: number = this.pageScale(p);
        const lx: number = gx;
        const ly: number = gy - top;
        const blocks: SmBlock[] = this.pageInfo(p).blocks;
        let best: number = -1;
        let bestArea: number = Number.MAX_VALUE;
        for (let i = 0; i < blocks.length; i++) {
          if (this.isContainer(p, i)) continue;
          const b: SmBlock = blocks[i];
          if (lx >= b.x1 * s && lx <= b.x2 * s && ly >= b.y1 * s && ly <= b.y2 * s) {
            const area: number = (b.x2 - b.x1) * (b.y2 - b.y1);
            if (area < bestArea) { bestArea = area; best = i; }
          }
        }
        return { page: p, idx: best };
      }
    }
    return { page: -1, idx: -1 };
  }

  // flat 位置比较:a 是否 <= b
  private leq(ap: number, ai: number, bp: number, bi: number): boolean {
    if (ap !== bp) return ap < bp;
    return ai <= bi;
  }

  // 本页被选中的 block 数组下标(供高亮)
  selectedPerPage(p: number): number[] {
    if (this.anchorPage < 0 || this.curPage < 0) return [];
    let loP: number = this.anchorPage; let loI: number = this.anchorIdx;
    let hiP: number = this.curPage; let hiI: number = this.curIdx;
    if (!this.leq(loP, loI, hiP, hiI)) { loP = this.curPage; loI = this.curIdx; hiP = this.anchorPage; hiI = this.anchorIdx; }
    if (p < loP || p > hiP) return [];
    const blocks: SmBlock[] = this.pageInfo(p).blocks;
    const start: number = (p === loP) ? loI : 0;
    const end: number = (p === hiP) ? hiI : blocks.length - 1;
    const out: number[] = [];
    for (let i = start; i <= end; i++) {
      if (i >= 0 && i < blocks.length && !this.isContainer(p, i)) out.push(i);
    }
    return out;
  }

  selectedMarkdown(): string {
    if (this.anchorPage < 0) return '';
    let loP: number = this.anchorPage; let hiP: number = this.curPage;
    if (!this.leq(this.anchorPage, this.anchorIdx, this.curPage, this.curIdx)) { loP = this.curPage; hiP = this.anchorPage; }
    const parts: string[] = [];
    for (let p = loP; p <= hiP; p++) {
      const sel: number[] = this.selectedPerPage(p);
      const blocks: SmBlock[] = this.pageInfo(p).blocks;
      for (const i of sel) {
        const b: SmBlock = blocks[i];
        if (b.type === 'figure' && b.imgUrl.length > 0) {
          parts.push(`![](${b.imgUrl})`);
          if (b.content.length > 0) parts.push(b.content);
        } else if (b.content.length > 0) {
          parts.push(b.content);
        }
      }
    }
    return parts.join('\n\n');
  }

  // ===== 手势(子组件转发全局坐标) =====
  onTapAt(gx: number, gy: number): void {
    const hit: Hit = this.hitGlobal(gx, gy);
    if (hit.idx < 0) return;
    this.anchorPage = hit.page; this.anchorIdx = hit.idx;
    this.curPage = hit.page; this.curIdx = hit.idx;
    this.mdVisible = false;
    this.carding = true;
  }

  onPressStart(gx: number, gy: number): void {
    const hit: Hit = this.hitGlobal(gx, gy);
    if (hit.idx < 0) return;
    this.anchorPage = hit.page; this.anchorIdx = hit.idx;
    this.curPage = hit.page; this.curIdx = hit.idx;
    this.pressing = true;
    this.carding = false;
  }

  onPressMove(gx: number, gy: number): void {
    if (!this.pressing) return;
    const hit: Hit = this.hitGlobal(gx, gy);
    if (hit.idx >= 0) { this.curPage = hit.page; this.curIdx = hit.idx; }
  }

  onPressEnd(): void {
    if (!this.pressing) return;
    this.pressing = false;
    if (this.anchorPage >= 0) { this.mdVisible = false; this.carding = true; }
  }

  closeCard(): void {
    this.carding = false;
    this.pressing = false;
    this.anchorPage = -1; this.anchorIdx = -1;
    this.curPage = -1; this.curIdx = -1;
  }

  doAdd(): void {
    const md: string = this.selectedMarkdown();
    if (md.length === 0) { this.closeCard(); return; }
    const ref: BlockRef = {
      kind: 'block',
      docId: this.docId,
      docName: this.currentDoc()?.name ?? '文档',
      pageIndex: this.anchorPage >= 0 ? this.anchorPage : 0,
      blockIndices: [],
      previewText: md
    };
    this.closeCard();
    const pending: Citation[] = AppStorage.get<Citation[]>('pendingCitations') ?? [];
    AppStorage.setOrCreate<Citation[]>('pendingCitations', [...pending, ref]);
    const param: ChatPageParam = { drawerOpen: false };
    this.pathStack.pushPath({ name: 'ChatPage', param: param });
  }

  centerPageFromScroll(): number {
    const doc = this.currentDoc();
    if (doc === undefined) return 0;
    let yOff: number = 0;
    try { yOff = this.scroller.currentOffset().yOffset; } catch (e) { yOff = 0; }
    const viewCenter: number = yOff + (this.pageHeight(0) * 0.5);
    let acc: number = 0;
    for (let i = 0; i < doc.originalImageUris.length; i++) {
      const h: number = this.pageHeight(i);
      if (viewCenter < acc + h) return i;
      acc += h;
    }
    return doc.originalImageUris.length - 1;
  }

  openSheet(fullDoc: boolean): void {
    if (this.currentDoc() === undefined) return;
    this.closeCard();   // 互斥:打开 markdown 抽屉时收起菜单卡
    this.mdFullDoc = fullDoc;
    this.mdVisible = true;
  }

  sharePdf(): void {
    const doc = this.currentDoc();
    if (doc === undefined) return;
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ShareHelper.sharePdf(ctx, doc.id, doc.name, doc.originalImageUris)
      .catch((e: Error) => {
        hilog.error(0x0000, TAG, 'sharePdf failed: ' + e.message);
        promptAction.showToast({ message: '分享失败: ' + e.message });
      });
  }

  deleteDoc(): void {
    const doc = this.currentDoc();
    if (doc === undefined) return;
    DocumentStore.removeDocument(doc.id);
    promptAction.showToast({ message: '已删除' });
    this.pathStack.pop();
  }

  @Builder
  moreMenu() {
    Menu() {
      MenuItem({ content: '以 PDF 分享' }).onClick(() => this.sharePdf())
      MenuItem({ content: '删除文档' }).onClick(() => this.deleteDoc())
    }
  }

  /** 居中两段式操作卡:上白色圆角 Markdown 窗 + 下独立 Add to Chat 小窗;外部毛玻璃虚化。 */
  @Builder
  optionCard() {
    Stack() {
      // 外部仅轻微虚化,不遮挡背后文档内容;点外部关闭
      Column()
        .width('100%').height('100%')
        .backgroundColor(Color.Transparent)
        .backdropBlur(6)
        .onClick(() => this.closeCard())

      Column() {
        Column() {
          Row() {
            Text('选中内容 · 长按拖动可跨页多选')
              .fontSize(12).fontColor(Theme.TEXT_SECONDARY).layoutWeight(1)
            Text('取消')
              .fontSize(13).fontColor(Theme.BRAND)
              .onClick(() => this.closeCard())
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 6 })

          MarkdownWeb({ markdown: this.selectedMarkdown() })
            .layoutWeight(1)
            .width('100%')
        }
        .width('86%')
        .constraintSize({ maxHeight: '52%' })
        .backgroundColor(Theme.BG_CARD)
        .borderRadius(16)
        .clip(true)
        .shadow({ radius: 18, color: 'rgba(0,0,0,0.18)', offsetX: 0, offsetY: 4 })

        Button('Add to Chat')
          .width('86%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_ON_BRAND)
          .backgroundColor(Theme.BRAND)
          .borderRadius(16)
          .margin({ top: 12 })
          .shadow({ radius: 12, color: 'rgba(255,140,0,0.25)', offsetX: 0, offsetY: 3 })
          .onClick(() => this.doAdd())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          Row() {
            Text('‹ 返回')
              .fontSize(16).fontColor(Theme.BRAND)
              .onClick(() => this.pathStack.pop())
            Text(this.currentDoc()?.name ?? '文档')
              .fontSize(17).fontColor(Theme.TEXT_PRIMARY)
              .layoutWeight(1).textAlign(TextAlign.Center)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('解析')
              .fontSize(14).fontColor(Theme.BRAND).padding({ left: 6, right: 6 })
              .onClick(() => this.openSheet(true))
            Text('⋯')
              .fontSize(20).fontColor(Theme.TEXT_PRIMARY).width(32).textAlign(TextAlign.Center)
              .bindMenu(this.moreMenu())
          }
          .width('100%')
          .padding({ left: 12, right: 8, top: 12, bottom: 8 })
          .backgroundColor(Theme.BG_CARD)
          .border({ width: { bottom: 0.5 }, color: Theme.DIVIDER })

          if (this.currentDoc() === undefined) {
            Column() {
              Text('文档不存在').fontSize(15).fontColor(Theme.TEXT_SECONDARY)
            }
            .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
          } else {
            List({ scroller: this.scroller }) {
              ForEach(this.currentDoc()!.originalImageUris, (uri: string, idx: number) => {
                ListItem() {
                  BboxImagePage({
                    filePath: uri,
                    page: this.pageInfo(idx),
                    pageIndex: idx,
                    selectedIdxs: this.selectedPerPage(idx),
                    onGeometry: (pi: number, gy: number, w: number, h: number) => { this.pageTopY[pi] = gy; },
                    onTapAt: (gx: number, gy: number) => this.onTapAt(gx, gy),
                    onPressStart: (gx: number, gy: number) => this.onPressStart(gx, gy),
                    onPressMove: (gx: number, gy: number) => this.onPressMove(gx, gy),
                    onPressEnd: () => this.onPressEnd()
                  })
                    .height(this.pageHeight(idx))
                }
              }, (uri: string, idx: number) => `${this.docId}_${idx}`)
            }
            .layoutWeight(1)
            .width('100%')
            .scrollBar(BarState.Off)
            .enableScrollInteraction(!this.pressing)
            .onDidScroll(() => {
              const cp: number = this.centerPageFromScroll();
              if (cp !== this.currentPage) this.currentPage = cp;
            })
            .priorityGesture(
              SwipeGesture({ direction: SwipeDirection.Horizontal })
                .onAction((e: GestureEvent) => {
                  if (!this.pressing && (e.angle > 135 || e.angle < -135)) {
                    this.openSheet(false);
                  }
                })
            )

            Row() {
              Text(`${this.currentPage + 1} / ${this.currentDoc()!.originalImageUris.length}`)
                .fontSize(12).fontColor(Theme.TEXT_SECONDARY)
              Text('  ·  长按选内容(可跨页) · 左滑看解析')
                .fontSize(11).fontColor(Theme.TEXT_HINT)
            }
            .width('100%').justifyContent(FlexAlign.Center)
            .padding({ top: 6, bottom: 12 })
            .backgroundColor(Theme.BG_CARD)
          }
        }
        .width('100%')
        .height('100%')

        if (this.currentDoc() !== undefined) {
          PageMarkdownSheet({
            visible: this.mdVisible,
            parsedJson: this.currentDoc()!.parsedJson,
            pageIndex: this.currentPage,
            parsing: this.currentDoc()!.status === 'parsing',
            fullDoc: this.mdFullDoc,
            fullMarkdown: this.currentDoc()!.parsedMarkdown,
            docName: this.currentDoc()!.name,
            onClose: () => { this.mdVisible = false; }
          })
        }

        // 菜单卡:页面内同层浮层(非模态),外部仅轻微虚化,背后文档仍可见
        if (this.carding) {
          this.optionCard()
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(Theme.BG_PAGE)
  }
}
