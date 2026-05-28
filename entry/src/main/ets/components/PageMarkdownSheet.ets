import { MarkdownWeb } from './MarkdownWeb';
import { Theme } from '../common/Theme';

interface SmBlock {
  type?: string;
  content?: string;
  img_url?: string;
}
interface SmPage {
  blocks?: SmBlock[];
}
interface SmJson {
  pages?: SmPage[];
}

function pageMarkdown(parsedJson: string, pageIndex: number): string {
  try {
    const data = JSON.parse(parsedJson) as SmJson;
    const pages: SmPage[] = data.pages ?? [];
    if (pageIndex < 0 || pageIndex >= pages.length) return '';
    const blocks: SmBlock[] = pages[pageIndex].blocks ?? [];
    const parts: string[] = [];
    for (const b of blocks) {
      const type: string = b.type ?? 'text';
      const content: string = b.content ?? '';
      const url: string = b.img_url ?? '';
      if (type === 'figure' && url.length > 0) {
        parts.push(`![](${url})`);
        if (content.length > 0) parts.push(content);
      } else if (content.length > 0) {
        parts.push(content);
      }
    }
    return parts.join('\n\n');
  } catch (e) {
    return '';
  }
}

/**
 * PRD §6.3:左滑文档页时右上角悬浮的 Markdown 抽屉(只展示**当前页**)。
 * 渲染走 somarkdown(MarkdownWeb),与前端 playground 同一引擎。
 */
@Component
export struct PageMarkdownSheet {
  @Prop visible: boolean = false;
  @Prop parsedJson: string = '';
  @Prop pageIndex: number = 0;
  @Prop parsing: boolean = false;
  @Prop fullDoc: boolean = false;       // true=整篇文档 markdown(解析按钮);false=当前页(左滑)
  @Prop fullMarkdown: string = '';      // 整篇 markdown(fullDoc 时用)
  @Prop totalPages: number = 1;
  docName: string = '';

  onClose: () => void = () => {};
  onPrevPage: () => void = () => {};
  onNextPage: () => void = () => {};

  sheetMarkdown(): string {
    if (this.fullDoc) return this.fullMarkdown;
    return pageMarkdown(this.parsedJson, this.pageIndex);
  }

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column()
          .width('100%')
          .height('100%')
          .onClick(() => this.onClose())

        Column() {
          Row() {
            if (!this.fullDoc && this.totalPages > 1) {
              Text('‹')
                .fontSize(20).fontColor(this.pageIndex > 0 ? Theme.BRAND : Theme.TEXT_HINT)
                .width(28).textAlign(TextAlign.Center)
                .onClick(() => { if (this.pageIndex > 0) this.onPrevPage(); })
            }
            Text(this.fullDoc ? '全文 · Markdown' : `第 ${this.pageIndex + 1} / ${this.totalPages} 页`)
              .fontSize(14)
              .fontColor(Theme.TEXT_PRIMARY)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
            if (!this.fullDoc && this.totalPages > 1) {
              Text('›')
                .fontSize(20).fontColor(this.pageIndex < this.totalPages - 1 ? Theme.BRAND : Theme.TEXT_HINT)
                .width(28).textAlign(TextAlign.Center)
                .onClick(() => { if (this.pageIndex < this.totalPages - 1) this.onNextPage(); })
            }
            Text('收起')
              .fontSize(14)
              .fontColor(Theme.BRAND)
              .padding({ left: 6 })
              .onClick(() => this.onClose())
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 8 })
          .border({ width: { bottom: 0.5 }, color: Theme.DIVIDER })

          if (this.parsing) {
            Column() {
              LoadingProgress().width(36).height(36).color(Theme.BRAND)
              Text('正在解析…').fontSize(13).fontColor(Theme.TEXT_SECONDARY).margin({ top: 10 })
            }
            .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
          } else {
            MarkdownWeb({ markdown: this.sheetMarkdown() })
              .layoutWeight(1)
              .width('100%')
          }
        }
        .width(this.fullDoc ? '92%' : '82%')
        .height(this.fullDoc ? '82%' : '64%')
        .margin({ top: this.fullDoc ? 60 : 78, right: this.fullDoc ? 0 : 8 })
        .backgroundColor(Theme.BG_CARD)
        .borderRadius(16)
        .clip(true)
        .shadow({ radius: 16, color: 'rgba(0,0,0,0.18)', offsetX: 0, offsetY: 4 })
        .parallelGesture(
          SwipeGesture({ direction: SwipeDirection.Horizontal })
            .onAction((e: GestureEvent) => {
              if (e.angle > -45 && e.angle < 45) this.onClose();
            })
        )
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
    }
  }
}
