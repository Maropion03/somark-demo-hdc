import { MarkdownWeb } from './MarkdownWeb';
import { ParsingIndicator } from './ParsingIndicator';
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

/** 半屏对照抽屉:高度封顶 50%,仅可往下调低;原文与解析各自滚动。 */
@Component
export struct PageMarkdownSheet {
  @Prop @Watch('onVisibleChange') visible: boolean = false;
  @Prop parsedJson: string = '';
  @Prop pageIndex: number = 0;
  @Prop parsing: boolean = false;
  @Prop fullDoc: boolean = false;
  @Prop fullMarkdown: string = '';
  @Prop totalPages: number = 1;
  docName: string = '';

  onClose: () => void = () => {};
  onPrevPage: () => void = () => {};
  onNextPage: () => void = () => {};

  @State private shown: boolean = false;
  @State private containerH: number = 0;
  @State private panelH: number = 280;
  @State private panStartH: number = 0;

  onVisibleChange(): void {
    if (this.visible) {
      this.shown = true;
      this.applyDefaultHeight();
    } else {
      this.shown = false;
    }
  }

  sheetMarkdown(): string {
    if (this.fullDoc) {
      return this.fullMarkdown;
    }
    return pageMarkdown(this.parsedJson, this.pageIndex);
  }

  sheetTitle(): string {
    if (this.fullDoc) {
      return '全文解析';
    }
    return `第 ${this.pageIndex + 1} 页结构`;
  }

  /** 半屏上限(不可拉高)。 */
  maxPanelH(): number {
    return this.containerH > 0 ? this.containerH * 0.50 : 360;
  }

  minPanelH(): number {
    return this.containerH > 0 ? this.containerH * 0.22 : 160;
  }

  defaultPanelH(): number {
    return this.maxPanelH();
  }

  clampPanelH(h: number): number {
    return Math.min(this.maxPanelH(), Math.max(this.minPanelH(), h));
  }

  applyDefaultHeight(): void {
    this.panelH = this.defaultPanelH();
  }

  snapPanelH(): void {
    if (this.containerH <= 0) {
      return;
    }
    const closeLine: number = this.containerH * 0.18;
    if (this.panelH < closeLine) {
      this.onClose();
      return;
    }
    const detents: number[] = [
      this.containerH * 0.50,
      this.containerH * 0.36,
      this.containerH * 0.24
    ];
    let best: number = detents[0];
    let bestD: number = Math.abs(this.panelH - detents[0]);
    for (let i = 0; i < detents.length; i++) {
      const d: number = Math.abs(this.panelH - detents[i]);
      if (d < bestD) {
        bestD = d;
        best = detents[i];
      }
    }
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.panelH = this.clampPanelH(best);
    });
  }

  canPrevPage(): boolean {
    return !this.fullDoc && this.pageIndex > 0;
  }

  canNextPage(): boolean {
    return !this.fullDoc && this.pageIndex < this.totalPages - 1;
  }

  @Builder
  dragHandle() {
    Column() {
      Row()
        .width(40)
        .height(4)
        .borderRadius(2)
        .backgroundColor(Theme.DIVIDER)
        .margin({ top: 10, bottom: 6 })
      Text('下拉调低 · 上方滚动看原图')
        .fontSize(11)
        .fontColor(Theme.TEXT_HINT)
        .margin({ bottom: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 1 })
        .onActionStart(() => {
          this.panStartH = this.panelH;
        })
        .onActionUpdate((e: GestureEvent) => {
          const next: number = this.panStartH - e.offsetY;
          this.panelH = this.clampPanelH(next);
        })
        .onActionEnd(() => {
          this.snapPanelH();
        })
    )
  }

  @Builder
  pageSwitcher() {
    Row() {
      Text('上一页')
        .fontSize(13)
        .fontColor(this.canPrevPage() ? Theme.BRAND : Theme.TEXT_HINT)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor(this.canPrevPage() ? Theme.BRAND_SOFT : Theme.BG_SUBTLE)
        .borderRadius(Theme.RADIUS_SM)
        .onClick(() => {
          if (this.canPrevPage()) {
            this.onPrevPage();
          }
        })
      Text(`${this.pageIndex + 1} / ${this.totalPages}`)
        .fontSize(13)
        .fontColor(Theme.TEXT_SECONDARY)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('下一页')
        .fontSize(13)
        .fontColor(this.canNextPage() ? Theme.BRAND : Theme.TEXT_HINT)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor(this.canNextPage() ? Theme.BRAND_SOFT : Theme.BG_SUBTLE)
        .borderRadius(Theme.RADIUS_SM)
        .onClick(() => {
          if (this.canNextPage()) {
            this.onNextPage();
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 6 })
  }

  build() {
    if (this.shown) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          this.dragHandle()

          Row() {
            Column() {
              Text(this.sheetTitle())
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.TEXT_PRIMARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (this.fullDoc && this.docName.length > 0) {
                Text(this.docName)
                  .fontSize(12)
                  .fontColor(Theme.TEXT_SECONDARY)
                  .margin({ top: 2 })
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              } else {
                Text('对照时上下分别滚动')
                  .fontSize(12)
                  .fontColor(Theme.TEXT_SECONDARY)
                  .margin({ top: 2 })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 18, right: 18, bottom: 4 })

          if (!this.fullDoc && this.totalPages > 1 && !this.parsing) {
            this.pageSwitcher()
          }

          Divider()
            .strokeWidth(0.5)
            .color(Theme.DIVIDER)
            .margin({ left: 16, right: 16 })

          if (this.parsing) {
            ParsingIndicator({
              message: '正在解析文档…',
              hint: '完成后将自动展示 Markdown',
              fill: true
            })
              .layoutWeight(1)
              .width('100%')
              .padding({ left: 16, right: 16 })
          } else {
            Scroll() {
              MarkdownWeb({
                markdown: this.sheetMarkdown(),
                showLoading: true
              })
                .width('100%')
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ left: 10, right: 10, top: 6, bottom: 10 })
            .scrollBar(BarState.Auto)
            .edgeEffect(EdgeEffect.Spring)
          }
        }
        .width('100%')
        .height(this.panelH)
        .backgroundColor(Theme.BG_CARD)
        .borderRadius({ topLeft: Theme.RADIUS_XL, topRight: Theme.RADIUS_XL })
        .border({ width: { top: 1 }, color: Theme.BRAND_SOFT_BORDER })
        .shadow(Theme.SHADOW_FLOAT)
        .clip(true)
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)
      .onAreaChange((_o: Area, n: Area) => {
        const h: number = n.height as number;
        if (h > 0 && Math.abs(h - this.containerH) > 1) {
          this.containerH = h;
          if (this.visible) {
            if (this.panelH > this.maxPanelH()) {
              this.panelH = this.maxPanelH();
            } else if (this.panelH < this.minPanelH()) {
              this.applyDefaultHeight();
            }
          }
        }
      })
    }
  }
}
