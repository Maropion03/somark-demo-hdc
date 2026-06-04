import { DocumentRecord } from '../model/Document';
import { DraggableDocCard } from './DraggableDocCard';
import { Theme } from '../common/Theme';
import { display } from '@kit.ArkUI';

/**
 * Chat 页底部文档抽屉。
 * 收起:只露顶部把手 + 计数。展开:搜索栏 + 两列可拖拽卡片网格。
 * 上/下滑跟手拖动,松手吸附展开/收起。
 */
@Component
export struct DocDrawer {
  @Link @Watch('onExpandedChange') expanded: boolean;
  @Prop documents: DocumentRecord[] = [];
  @Prop dropHover: boolean = false;
  onPick: (doc: DocumentRecord) => void = () => {};
  onOpen: (doc: DocumentRecord) => void = () => {};
  onPickBegin: (doc: DocumentRecord, x: number, y: number) => void = () => {};
  onPickMove: (x: number, y: number) => void = () => {};
  onPickRelease: (x: number, y: number) => void = () => {};
  @State query: string = '';
  @State searching: boolean = false;
  @State t: number = 0;
  @State panelH: number = 36;
  @State dragging: boolean = false;
  /** 收起态可视高度(略增高,便于抓取)。 */
  private readonly collapsedH: number = 48;
  private readonly expandedRatio: number = 0.55;
  private maxPanelH: number = 400;
  private panStartH: number = 48;
  private panWasExpanded: boolean = false;

  aboutToAppear(): void {
    this.refreshMaxHeight();
    this.syncPanelHFromExpanded();
  }

  refreshMaxHeight(): void {
    try {
      const hPx: number = display.getDefaultDisplaySync().height;
      this.maxPanelH = this.getUIContext().px2vp(hPx) * this.expandedRatio;
    } catch (e) {
      this.maxPanelH = 400;
    }
  }

  clampPanelH(h: number): number {
    if (h < this.collapsedH) return this.collapsedH;
    if (h > this.maxPanelH) return this.maxPanelH;
    return h;
  }

  syncPanelHFromExpanded(): void {
    if (this.dragging) return;
    this.panelH = this.expanded ? this.maxPanelH : this.collapsedH;
    this.t = this.expanded ? 1 : 0;
  }

  onExpandedChange(): void {
    this.syncPanelHFromExpanded();
  }

  rgbaWhite(alpha: number): string {
    return 'rgba(255,255,255,' + alpha + ')';
  }

  rgbaDark(alpha: number): string {
    return 'rgba(11,23,48,' + alpha + ')';
  }

  glassAlpha(): number {
    return 0.70 + 0.18 * this.t;
  }

  shadowAlpha(): number {
    return 0.10 + 0.06 * this.t;
  }

  /** 松手吸附:上滑/展开偏松,下滑/收起偏松(带速度意图)。 */
  resolveExpandedAfterPan(offsetY: number): boolean {
    const span: number = this.maxPanelH - this.collapsedH;
    const progress: number = span > 0 ? (this.panelH - this.collapsedH) / span : 0;
    const upLift: number = -offsetY;
    if (this.panWasExpanded) {
      if (upLift < -14) {
        return false;
      }
      if (progress < 0.36) {
        return false;
      }
      return true;
    }
    if (upLift > 14) {
      return true;
    }
    if (progress > 0.16) {
      return true;
    }
    return false;
  }

  filtered(): DocumentRecord[] {
    const q: string = this.query.trim().toLowerCase();
    if (q.length === 0) return this.documents;
    return this.documents.filter((d: DocumentRecord) => {
      if (d.name.toLowerCase().indexOf(q) >= 0) return true;
      if (d.parsedMarkdown.toLowerCase().indexOf(q) >= 0) return true;
      return false;
    });
  }

  @Builder
  handle() {
    Column() {
      Row()
        .width(40)
        .height(4)
        .backgroundColor(Theme.BORDER)
        .borderRadius(2)
        .margin({ top: 10, bottom: 6 })
      Text(this.expanded ? '下滑收起 · 长按文档拖入对话' : `上滑展开 · ${this.documents.length} 篇文档`)
        .fontSize(12)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ bottom: 10 })
        .opacity(0.68 + 0.32 * this.t)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 4, bottom: 2 })
    .onClick(() => {
      this.expanded = !this.expanded;
    })
  }

  /** 把手 + 搜索栏均可拖动,避免只能捏窄条把手。 */
  @Builder
  dragChrome() {
    Column() {
      this.handle()
      if (this.expanded || this.t > 0.08) {
        this.searchBar()
      }
    }
    .width('100%')
    // 向上延伸触控区,收起态也更容易从边缘上滑
    .margin({ top: -18 })
    .padding({ top: 18 })
    .gesture(
      PanGesture({ direction: PanDirection.Vertical, distance: 1 })
        .onActionStart(() => {
          this.dragging = true;
          this.panStartH = this.panelH;
          this.panWasExpanded = this.expanded;
        })
        .onActionUpdate((e: GestureEvent) => {
          const next: number = this.clampPanelH(this.panStartH - e.offsetY);
          this.panelH = next;
          const span: number = this.maxPanelH - this.collapsedH;
          this.t = span > 0 ? (next - this.collapsedH) / span : 0;
        })
        .onActionEnd((e: GestureEvent) => {
          this.dragging = false;
          this.expanded = this.resolveExpandedAfterPan(e.offsetY);
          this.syncPanelHFromExpanded();
        })
    )
  }

  @Builder
  searchBar() {
    Row() {
      Image($r('app.media.ic_search_hint'))
        .width(18)
        .height(18)
        .objectFit(ImageFit.Contain)
        .margin({ right: 8 })
      TextInput({ placeholder: '搜索文档内容…', text: this.query })
        .layoutWeight(1)
        .fontSize(14)
        .fontColor(Theme.TEXT_PRIMARY)
        .placeholderColor(Theme.TEXT_HINT)
        .backgroundColor(Theme.BG_CARD)
        .borderRadius(Theme.RADIUS_SM)
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .border({ width: 1, color: Theme.BORDER })
        .onChange((v: string) => { this.query = v; })
      if (this.query.length > 0) {
        Text('清除')
          .fontSize(13)
          .fontColor(Theme.BRAND)
          .margin({ left: 10 })
          .onClick(() => { this.query = ''; })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      this.dragChrome()
      if (this.expanded || this.t > 0.08) {
        if (this.filtered().length === 0) {
          Column() {
            Text(this.query.length > 0 ? `没有匹配「${this.query}」的文档` : '还没有扫描文档')
              .fontSize(14)
              .fontColor(Theme.TEXT_SECONDARY)
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          Grid() {
            ForEach(this.filtered(), (doc: DocumentRecord) => {
              GridItem() {
                DraggableDocCard({
                  doc: doc,
                  onOpen: this.onOpen,
                  onPickBegin: (d: DocumentRecord, x: number, y: number) => this.onPickBegin(d, x, y),
                  onPickMove: (x: number, y: number) => this.onPickMove(x, y),
                  onPickRelease: (x: number, y: number) => this.onPickRelease(x, y)
                })
              }
            }, (doc: DocumentRecord) => doc.id + '_' + doc.status)
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(10)
          .rowsGap(10)
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 12 })
        }
      }
    }
    .width('100%')
    .height(this.panelH)
    .clip(false)
    .backgroundColor(this.rgbaWhite(this.glassAlpha()))
    .backdropBlur(16 + 14 * this.t)
    .borderRadius({ topLeft: Theme.RADIUS_XL, topRight: Theme.RADIUS_XL })
    .border({
      width: this.dropHover ? 2 : 0.5,
      color: this.dropHover ? Theme.BRAND : Theme.DIVIDER
    })
    .shadow({
      radius: 16 + 10 * this.t,
      color: this.rgbaDark(this.shadowAlpha()),
      offsetX: 0,
      offsetY: -2 - 3 * this.t
    })
    .animation(this.dragging ? { duration: 0 } : { duration: 220, curve: Curve.EaseOut })
  }
}
