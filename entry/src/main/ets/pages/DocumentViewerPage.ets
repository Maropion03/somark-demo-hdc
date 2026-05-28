import { DocumentRecord } from '../model/Document';
import { PageMarkdownSheet } from '../components/PageMarkdownSheet';
import { BboxImagePage } from '../components/BboxImagePage';
import { BlockRef, Citation } from '../model/Chat';
import { SmPageInfo, parseSmDoc } from '../model/SmDoc';
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

/**
 * PRD §6/§7:文档查看页。
 * 多页竖向无缝瀑布流 + bbox 长按选区 + 中间态左滑出当前页 Markdown 抽屉 + ⋯ 菜单(删除/分享PDF)。
 */
@Component
export struct DocumentViewerPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @StorageLink('documents') documents: DocumentRecord[] = [];
  docId: string = '';
  @State currentPage: number = 0;
  @State mdVisible: boolean = false;
  @State mdFullDoc: boolean = false;
  @State selecting: boolean = false;
  @State pages: SmPageInfo[] = [];
  @State screenW: number = 360;
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

  /** 第 idx 页的显示高度(vp):按 page_size 比例,无解析数据时退化为 A4。 */
  pageHeight(idx: number): number {
    if (idx < this.pages.length) {
      const p: SmPageInfo = this.pages[idx];
      if (p.w > 0 && p.h > 0) {
        return this.screenW * (p.h / p.w);
      }
    }
    return this.screenW * 1.414;
  }

  emptyPage(): SmPageInfo {
    return { pageNum: 0, w: 0, h: 0, blocks: [] };
  }

  pageInfo(idx: number): SmPageInfo {
    return idx < this.pages.length ? this.pages[idx] : this.emptyPage();
  }


  /** 视口中心所在页(用于页码 + 抽屉默认页),用滚动偏移实时算。 */
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

  // fullDoc=true:解析按钮,看整篇;false:左滑,看当前页
  openSheet(fullDoc: boolean): void {
    if (this.currentDoc() === undefined) return;
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

  onAddCitation(ref: BlockRef): void {
    hilog.info(0x0000, TAG, `Add to Chat: ${ref.previewText.substring(0, 30)}`);
    this.selecting = false;
    this.mdVisible = false;
    const pending: Citation[] = AppStorage.get<Citation[]>('pendingCitations') ?? [];
    AppStorage.setOrCreate<Citation[]>('pendingCitations', [...pending, ref]);
    const param: ChatPageParam = { drawerOpen: false };
    this.pathStack.pushPath({ name: 'ChatPage', param: param });
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
                    docId: this.docId,
                    docName: this.currentDoc()!.name,
                    pageIndex: idx,
                    onSelStart: () => { this.selecting = true; },
                    onSelEnd: () => { this.selecting = false; },
                    onAddCitation: (ref: BlockRef) => this.onAddCitation(ref)
                  })
                    .height(this.pageHeight(idx))
                }
              }, (uri: string, idx: number) => `${this.docId}_${idx}`)
            }
            .layoutWeight(1)
            .width('100%')
            .scrollBar(BarState.Off)
            .enableScrollInteraction(!this.selecting)
            .onDidScroll(() => {
              const cp: number = this.centerPageFromScroll();
              if (cp !== this.currentPage) this.currentPage = cp;
            })
            .priorityGesture(
              SwipeGesture({ direction: SwipeDirection.Horizontal })
                .onAction((e: GestureEvent) => {
                  if (!this.selecting && (e.angle > 135 || e.angle < -135)) {
                    this.openSheet(false);
                  }
                })
            )

            Row() {
              Text(`${this.currentPage + 1} / ${this.currentDoc()!.originalImageUris.length}`)
                .fontSize(12).fontColor(Theme.TEXT_SECONDARY)
              Text('  ·  长按选内容 · 左滑看解析')
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
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(Theme.BG_PAGE)
  }
}
