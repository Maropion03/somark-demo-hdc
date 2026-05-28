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
  @Link expanded: boolean;
  @Prop documents: DocumentRecord[] = [];
  @Prop dropHover: boolean = false;
  onPick: (doc: DocumentRecord) => void = () => {};
  onOpen: (doc: DocumentRecord) => void = () => {};
  onPickBegin: (doc: DocumentRecord, x: number, y: number) => void = () => {};
  onPickMove: (x: number, y: number) => void = () => {};
  onPickRelease: (x: number, y: number) => void = () => {};
  @State query: string = '';
  @State searching: boolean = false;

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
        .backgroundColor('rgba(0,0,0,0.2)')
        .borderRadius(2)
        .margin({ top: 8, bottom: 6 })
      Text(this.expanded ? '下滑收起 · 长按文档拖入对话' : `上滑展开 · ${this.documents.length} 篇文档`)
        .fontSize(12)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ bottom: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onClick(() => { this.expanded = !this.expanded; })
    .gesture(
      PanGesture({ direction: PanDirection.Vertical })
        .onActionEnd((e: GestureEvent) => {
          if (e.offsetY < -20) this.expanded = true;
          else if (e.offsetY > 20) this.expanded = false;
        })
    )
  }

  @Builder
  searchBar() {
    Row() {
      Text('🔍').fontSize(15).margin({ right: 8 })
      TextInput({ placeholder: '搜索文档内容…', text: this.query })
        .layoutWeight(1)
        .fontSize(14)
        .fontColor(Theme.TEXT_PRIMARY)
        .placeholderColor(Theme.TEXT_HINT)
        .backgroundColor(Theme.BG_SUBTLE)
        .borderRadius(10)
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
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
    .backgroundColor(Theme.BG_CARD)
    .borderRadius({ topLeft: 16, topRight: 16 })
    .border({
      width: this.dropHover ? 2 : 0.5,
      color: this.dropHover ? Theme.BRAND : Theme.DIVIDER
    })
    .shadow({ radius: 12, color: 'rgba(0,0,0,0.08)', offsetX: 0, offsetY: -2 })
    .animation({ duration: 220, curve: Curve.EaseOut })
  }
}
