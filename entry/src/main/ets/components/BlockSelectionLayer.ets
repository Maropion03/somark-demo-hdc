import { BlockRef } from '../model/Chat';

export interface SelectableBlock {
  index: number;
  kind: string;        // 'title' | 'text' | 'table' | 'image'
  text: string;
  imageUrl: string;
  titleLevel: number;
}

interface TableRow {
  cells: string[];
}

function isSeparatorRow(cells: string[]): boolean {
  let hasContent: boolean = false;
  for (const c of cells) {
    const t: string = c.trim();
    if (t.length === 0) continue;
    hasContent = true;
    for (let i = 0; i < t.length; i++) {
      const ch: string = t.charAt(i);
      if (ch !== '-' && ch !== ':' && ch !== ' ') return false;
    }
  }
  return hasContent;
}

function parseTable(md: string): TableRow[] {
  const rows: TableRow[] = [];
  const lines: string[] = md.split('\n');
  for (const line of lines) {
    const t: string = line.trim();
    if (t.length === 0 || t.indexOf('|') < 0) continue;
    let cells: string[] = t.split('|').map((c: string) => c.trim());
    if (cells.length > 0 && cells[0].length === 0) cells = cells.slice(1);
    if (cells.length > 0 && cells[cells.length - 1].length === 0) cells = cells.slice(0, cells.length - 1);
    if (cells.length === 0 || isSeparatorRow(cells)) continue;
    rows.push({ cells: cells });
  }
  return rows;
}

/**
 * PRD §7:长按选块 + 选项卡片(预览 + Add to Chat)。
 * V1 颗粒度:按 SoMark 返回的 block(标题/段落/表格/图片)单选,不做跨块的细颗粒选区。
 */
@Component
export struct BlockSelectionLayer {
  @Prop blocks: SelectableBlock[] = [];
  docId: string = '';
  docName: string = '';
  pageIndex: number = 0;
  @Prop @Watch('scrollToFocus') focusIdx: number = -1;
  onAddCitation: (ref: BlockRef) => void = () => {};
  @State selectedIdx: number = -1;
  @State cardVisible: boolean = false;
  private listScroller: Scroller = new Scroller();

  scrollToFocus(): void {
    if (this.focusIdx >= 0) {
      setTimeout(() => { this.listScroller.scrollToIndex(this.focusIdx); }, 50);
    }
  }

  aboutToAppear(): void {
    this.scrollToFocus();
  }

  selectedBlock(): SelectableBlock | undefined {
    return this.blocks.find((b: SelectableBlock) => b.index === this.selectedIdx);
  }

  previewText(b: SelectableBlock): string {
    if (b.kind === 'image') return '[图片]';
    return b.text;
  }

  doAdd(): void {
    const b = this.selectedBlock();
    if (b === undefined) return;
    const ref: BlockRef = {
      kind: 'block',
      docId: this.docId,
      docName: this.docName,
      pageIndex: this.pageIndex,
      blockIndices: [b.index],
      previewText: this.previewText(b)
    };
    this.onAddCitation(ref);
    this.cardVisible = false;
    this.selectedIdx = -1;
  }

  @Builder
  blockView(b: SelectableBlock) {
    Column() {
      if (b.kind === 'title') {
        Text(b.text)
          .fontSize(b.titleLevel <= 1 ? 21 : (b.titleLevel === 2 ? 18 : 16))
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width('100%')
      } else if (b.kind === 'image' || b.kind === 'figure') {
        if (b.imageUrl.length > 0) {
          Image(b.imageUrl)
            .width('100%')
            .objectFit(ImageFit.Contain)
            .borderRadius(6)
        } else if (b.text.length > 0) {
          Text(b.text).fontSize(14).fontColor('rgba(255,255,255,0.88)').lineHeight(22).width('100%')
        }
      } else if (b.kind === 'table') {
        Scroll() {
          Column() {
            ForEach(parseTable(b.text), (row: TableRow, rIdx: number) => {
              Row() {
                ForEach(row.cells, (cell: string, cIdx: number) => {
                  Text(cell)
                    .fontSize(12)
                    .fontColor(rIdx === 0 ? '#FFFFFF' : 'rgba(255,255,255,0.85)')
                    .padding(6)
                    .width(110)
                    .backgroundColor(rIdx === 0 ? '#151517' : '#0C0C0C')
                    .border({ width: 0.5, color: '#2A2C2E' })
                }, (cell: string, cIdx: number) => `c${rIdx}_${cIdx}`)
              }
            }, (row: TableRow, rIdx: number) => `r${rIdx}`)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .width('100%')
      } else {
        Text(b.text)
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.88)')
          .lineHeight(22)
          .width('100%')
      }
    }
    .width('100%')
    .padding(8)
    .backgroundColor(this.selectedIdx === b.index ? 'rgba(255,140,0,0.2)' : 'transparent')
    .borderRadius(6)
    .gesture(
      LongPressGesture({ duration: 350 })
        .onAction(() => {
          this.selectedIdx = b.index;
          this.cardVisible = true;
        })
    )
  }

  @Builder
  optionCard() {
    if (this.cardVisible && this.selectedBlock() !== undefined) {
      Column() {
        Column() {
          Text('已选中:')
            .fontSize(11)
            .fontColor('rgba(255,255,255,0.5)')
          Text(this.previewText(this.selectedBlock()!))
            .fontSize(13)
            .fontColor('#FFFFFF')
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
        }
        .width('100%')
        .padding(10)
        .alignItems(HorizontalAlign.Start)

        Row() {
          Button('取消')
            .layoutWeight(1)
            .height(38)
            .backgroundColor('#2A2C2E')
            .fontColor('#FFFFFF')
            .fontSize(13)
            .onClick(() => {
              this.cardVisible = false;
              this.selectedIdx = -1;
            })
          Button('Add to Chat')
            .layoutWeight(1)
            .height(38)
            .backgroundColor('#FF8C00')
            .fontColor('#FFFFFF')
            .fontSize(13)
            .margin({ left: 8 })
            .onClick(() => this.doAdd())
        }
        .width('100%')
        .padding({ left: 10, right: 10, bottom: 10 })
      }
      .width('86%')
      .backgroundColor('#151517')
      .borderRadius(10)
      .border({ width: 0.5, color: '#2A2C2E' })
      .position({ x: '7%', y: '70%' })
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      List({ scroller: this.listScroller, space: 8 }) {
        ForEach(this.blocks, (b: SelectableBlock) => {
          ListItem() {
            this.blockView(b)
          }
        }, (b: SelectableBlock) => `blk_${b.index}`)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .padding({ left: 10, right: 10, top: 6, bottom: 12 })

      this.optionCard()
    }
    .width('100%')
    .height('100%')
  }
}
