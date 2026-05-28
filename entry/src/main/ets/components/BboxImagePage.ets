import { fileUri } from '@kit.CoreFileKit';
import { SmPageInfo, SmBlock, blockTypeColor } from '../model/SmDoc';
import { BlockRef } from '../model/Chat';
import { MarkdownWeb } from './MarkdownWeb';
import { Theme } from '../common/Theme';

/**
 * 单页扫描图 + bbox 选区(PRD §7)。
 * 交互(#7):
 *  - 点按某 block → 直接选中该 block 并弹操作卡;
 *  - 长按按住不松 → 进入框选,手指下滑可多选(锚点 block → 当前 block 区间),松手才弹操作卡。
 * 选区高亮按 block 类型着色(#5)。操作卡:Markdown 预览占主体 + 右侧半透明 Add to Chat(#3)。
 */
@Component
export struct BboxImagePage {
  filePath: string = '';
  page: SmPageInfo = { pageNum: 0, w: 0, h: 0, blocks: [] };
  docId: string = '';
  docName: string = '';
  pageIndex: number = 0;
  onSelStart: () => void = () => {};
  onSelEnd: () => void = () => {};
  onAddCitation: (ref: BlockRef) => void = () => {};

  @State boxW: number = 0;
  @State boxH: number = 0;
  @State anchorIdx: number = -1;
  @State curIdx: number = -1;
  @State pressing: boolean = false;   // 长按框选进行中(不弹卡)
  @State carding: boolean = false;    // 操作卡显示中

  fitScale(): number {
    return this.page.w > 0 && this.boxW > 0 ? this.boxW / this.page.w : 1;
  }

  // 容器框:其 bbox 包住了其它 block 的中心点 → 视为大框,不可选
  isContainer(i: number): boolean {
    const b: SmBlock = this.page.blocks[i];
    for (let j = 0; j < this.page.blocks.length; j++) {
      if (j === i) continue;
      const o: SmBlock = this.page.blocks[j];
      const cx: number = (o.x1 + o.x2) / 2;
      const cy: number = (o.y1 + o.y2) / 2;
      if (cx > b.x1 && cx < b.x2 && cy > b.y1 && cy < b.y2) return true;
    }
    return false;
  }

  // 命中"最内层"且非容器的 block;纯大框区域返回 -1(不选、不闪)
  hitBlock(x: number, y: number): number {
    const s: number = this.fitScale();
    let best: number = -1;
    let bestArea: number = Number.MAX_VALUE;
    for (let i = 0; i < this.page.blocks.length; i++) {
      if (this.isContainer(i)) continue;
      const b: SmBlock = this.page.blocks[i];
      if (x >= b.x1 * s && x <= b.x2 * s && y >= b.y1 * s && y <= b.y2 * s) {
        const area: number = (b.x2 - b.x1) * (b.y2 - b.y1);
        if (area < bestArea) { bestArea = area; best = i; }
      }
    }
    return best;
  }

  /** 当前选区数组下标范围(anchor..cur)。 */
  selRange(): number[] {
    if (this.anchorIdx < 0 || this.curIdx < 0) return [];
    const lo: number = Math.min(this.anchorIdx, this.curIdx);
    const hi: number = Math.max(this.anchorIdx, this.curIdx);
    const arr: number[] = [];
    for (let i = lo; i <= hi; i++) arr.push(i);
    return arr;
  }

  selectedBlocks(): SmBlock[] {
    return this.selRange().map((i: number) => this.page.blocks[i]);
  }

  selectedMarkdown(): string {
    const parts: string[] = [];
    for (const b of this.selectedBlocks()) {
      if (b.type === 'figure' && b.imgUrl.length > 0) parts.push(`![](${b.imgUrl})`);
      else if (b.content.length > 0) parts.push(b.content);
    }
    return parts.join('\n\n');
  }

  // 点按:单 block 选中 + 弹卡
  onTap(x: number, y: number): void {
    const idx: number = this.hitBlock(x, y);
    if (idx < 0) return;
    this.anchorIdx = idx;
    this.curIdx = idx;
    this.carding = true;
    this.onSelStart();
  }

  // 长按按住:进入框选,记录锚点(不弹卡)
  onLongStart(x: number, y: number): void {
    const idx: number = this.hitBlock(x, y);
    if (idx < 0) return;
    this.anchorIdx = idx;
    this.curIdx = idx;
    this.pressing = true;
    this.carding = false;
    this.onSelStart();
  }

  // 长按移动:扩展到当前 block
  onLongMove(x: number, y: number): void {
    if (!this.pressing) return;
    const idx: number = this.hitBlock(x, y);
    if (idx >= 0) this.curIdx = idx;
  }

  // 长按松手:弹卡
  onLongEnd(): void {
    if (!this.pressing) return;
    this.pressing = false;
    if (this.anchorIdx >= 0) this.carding = true;
  }

  closeSelection(): void {
    this.pressing = false;
    this.carding = false;
    this.anchorIdx = -1;
    this.curIdx = -1;
    this.onSelEnd();
  }

  doAdd(): void {
    const blocks: SmBlock[] = this.selectedBlocks();
    if (blocks.length === 0) { this.closeSelection(); return; }
    const ref: BlockRef = {
      kind: 'block',
      docId: this.docId,
      docName: this.docName,
      pageIndex: this.pageIndex,
      blockIndices: blocks.map((b: SmBlock) => b.idx),
      previewText: this.selectedMarkdown()
    };
    this.onAddCitation(ref);
    this.closeSelection();
  }

  /** #RRGGBB → #AARRGGBB(ArkUI alpha 前置)。 */
  fillColor(type: string): string {
    const c: string = blockTypeColor(type);
    // 图片块不填充(避免遮住图),仅描边
    if (type === 'figure' || type === 'qr-code') return '#00000000';
    return '#33' + c.substring(1);
  }

  @Builder
  selectionHighlight() {
    ForEach(this.selectedBlocks(), (b: SmBlock) => {
      Column()
        .position({ x: b.x1 * this.fitScale(), y: b.y1 * this.fitScale() })
        .width((b.x2 - b.x1) * this.fitScale())
        .height((b.y2 - b.y1) * this.fitScale())
        .backgroundColor(this.fillColor(b.type))
        .border({ width: 2, color: blockTypeColor(b.type) })
        .borderRadius(2)
        .hitTestBehavior(HitTestMode.None)
    }, (b: SmBlock) => `sel_${b.idx}`)
  }

  /** 操作卡(#3):Markdown 预览主体 + 右侧半透明 Add to Chat。 */
  @Builder
  optionCard() {
    Column() {
      Row() {
        Text('选中内容 · 长按拖动可多选')
          .fontSize(12).fontColor(Theme.TEXT_SECONDARY).layoutWeight(1)
        Text('取消')
          .fontSize(13).fontColor(Theme.TEXT_SECONDARY)
          .onClick(() => this.closeSelection())
      }
      .width('100%')
      .padding({ top: 12, bottom: 6 })

      MarkdownWeb({ markdown: this.selectedMarkdown() })
        .layoutWeight(1)
        .width('100%')

      // Add to Chat:独立框,左边缘略过中线,靠右
      Row() {
        Column().layoutWeight(1)
        Button('Add to Chat')
          .width('54%')
          .height(44)
          .fontSize(15)
          .fontColor(Theme.TEXT_ON_BRAND)
          .backgroundColor(Theme.BRAND)
          .borderRadius(22)
          .onClick(() => this.doAdd())
      }
      .width('100%')
      .padding({ top: 8, bottom: 10 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
  }

  build() {
    Stack() {
      Image(fileUri.getUriFromPath(this.filePath))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill)
        .draggable(false)
        .onAreaChange((_o: Area, n: Area) => {
          this.boxW = n.width as number;
          this.boxH = n.height as number;
        })
        .gesture(
          GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 1 })
              .onAction((e: GestureEvent) => {
                const f = e.fingerList.length > 0 ? e.fingerList[0] : undefined;
                if (f !== undefined) this.onTap(f.localX, f.localY);
              }),
            // 长按 → 拖动多选;松手弹卡
            GestureGroup(GestureMode.Sequence,
              LongPressGesture({ fingers: 1, repeat: false, duration: 250 })
                .onAction((e: GestureEvent) => {
                  const f = e.fingerList.length > 0 ? e.fingerList[0] : undefined;
                  if (f !== undefined) this.onLongStart(f.localX, f.localY);
                })
                .onActionEnd(() => this.onLongEnd()),
              PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5 })
                .onActionUpdate((e: GestureEvent) => {
                  const f = e.fingerList.length > 0 ? e.fingerList[0] : undefined;
                  if (f !== undefined) this.onLongMove(f.localX, f.localY);
                })
                .onActionEnd(() => this.onLongEnd())
            )
          )
        )

      if (this.anchorIdx >= 0) {
        this.selectionHighlight()
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet(this.carding, this.optionCard(), {
      detents: [240, 420],
      preferType: SheetType.BOTTOM,
      enableOutsideInteractive: true,
      showClose: false,
      backgroundColor: Theme.BG_CARD,
      onWillDismiss: () => { this.closeSelection(); }
    })
  }
}
