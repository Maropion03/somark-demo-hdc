import { DocumentRecord } from '../model/Document';
import { DraggableDocCard } from './DraggableDocCard';
import { Theme } from '../common/Theme';

/**
 * Chat 页底部文档抽屉。
 * 收起:只露顶部把手 + 计数。展开:搜索栏 + 两列可拖拽卡片网格。
 * 搜索:对文档名 + 解析全文(parsedMarkdown)做 full-text 匹配。
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
  // 0=收起,1=展开:统一驱动材质/层级动效
  @State t: number = 0;

  onExpandedChange(): void {
    this.t = this.expanded ? 1 : 0;
  }

  rgbaWhite(alpha: number): string {
    // 避免在样式属性里使用模板字符串导致构建器解析异常
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
        .margin({ top: 8, bottom: 6 })
      Text(this.expanded ? '下滑收起 · 长按文档拖入对话' : `上滑展开 · ${this.documents.length} 篇文档`)
        .fontSize(12)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ bottom: 8 })
        .opacity(0.68 + 0.32 * this.t)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.expanded = !this.expanded;
    })
    .gesture(
      PanGesture({ direction: PanDirection.Vertical })
        .onActionEnd((e: GestureEvent) => {
          if (e.offsetY < -20) {
            this.expanded = true;
          } else if (e.offsetY > 20) {
            this.expanded = false;
          }
        })
    )
    .animation({ duration: 260, curve: Curve.EaseOut })
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
        .backgroundColor(Theme.BG_SUBTLE)
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
      this.handle()
      if (this.expanded) {
        this.searchBar()
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
          // 恢复为原来的两列卡片网格排布
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
    .height(this.expanded ? '55%' : 36)
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
    .animation({ duration: 220, curve: Curve.EaseOut })
  }
}
