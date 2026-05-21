import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'SoScan';

/** SoMark 解析 JSON 的内容块。 */
interface SmBlock {
  type?: string;
  content?: string;
  format?: string;
  img_url?: string;
  title_level?: number;
}
interface SmPage {
  blocks?: SmBlock[];
}
interface SmJson {
  pages?: SmPage[];
}

/** 渲染用的内容块。 */
interface RenderBlock {
  kind: string;       // 'title' | 'text' | 'table' | 'image'
  text: string;
  level: number;
  rows: string[][];
  imageUrl: string;
}

/** 判断一行是不是 Markdown 表格的分隔行(如 |---|:--:|)。 */
function isSeparatorRow(cells: string[]): boolean {
  let hasContent: boolean = false;
  for (const c of cells) {
    const t: string = c.trim();
    if (t.length === 0) {
      continue;
    }
    hasContent = true;
    for (let i = 0; i < t.length; i++) {
      const ch: string = t.charAt(i);
      if (ch !== '-' && ch !== ':' && ch !== ' ') {
        return false;
      }
    }
  }
  return hasContent;
}

/** 把 Markdown 表格文本解析成行/列二维数组。 */
function parseTable(md: string): string[][] {
  const rows: string[][] = [];
  const lines: string[] = md.split('\n');
  for (const line of lines) {
    const t: string = line.trim();
    if (t.length === 0 || t.indexOf('|') < 0) {
      continue;
    }
    let cells: string[] = t.split('|').map((c: string) => c.trim());
    if (cells.length > 0 && cells[0].length === 0) {
      cells = cells.slice(1);
    }
    if (cells.length > 0 && cells[cells.length - 1].length === 0) {
      cells = cells.slice(0, cells.length - 1);
    }
    if (cells.length === 0 || isSeparatorRow(cells)) {
      continue;
    }
    rows.push(cells);
  }
  return rows;
}

/**
 * 结构渲染器 —— 用原生 ArkUI 组件渲染 SoMark 解析结果。
 * (放弃 ArkWeb 方案:Web 组件在本场景加载不可靠。)
 */
@Component
export struct StructureRenderer {
  parsedJson: string = '';
  parsedMarkdown: string = '';
  private blocks: RenderBlock[] = [];

  aboutToAppear(): void {
    this.blocks = this.parseBlocks();
    hilog.info(0x0000, TAG, `StructureRenderer: ${this.blocks.length} render blocks`);
  }

  private parseBlocks(): RenderBlock[] {
    const result: RenderBlock[] = [];
    try {
      const data = JSON.parse(this.parsedJson) as SmJson;
      const pages: SmPage[] = data.pages ?? [];
      for (const page of pages) {
        const blocks: SmBlock[] = page.blocks ?? [];
        for (const b of blocks) {
          const type: string = b.type ?? 'text';
          const content: string = b.content ?? '';
          if (type === 'title') {
            const lv: number = (b.title_level !== undefined && b.title_level >= 1 && b.title_level <= 4)
              ? b.title_level : 2;
            result.push({ kind: 'title', text: content, level: lv, rows: [], imageUrl: '' });
          } else if (type === 'table') {
            const rows: string[][] = parseTable(content);
            if (rows.length > 0) {
              result.push({ kind: 'table', text: '', level: 0, rows: rows, imageUrl: '' });
            } else if (content.length > 0) {
              result.push({ kind: 'text', text: content, level: 0, rows: [], imageUrl: '' });
            }
          } else if (type === 'image') {
            const url: string = b.img_url ?? '';
            if (url.length > 0) {
              result.push({ kind: 'image', text: '', level: 0, rows: [], imageUrl: url });
            }
          } else if (content.length > 0) {
            result.push({ kind: 'text', text: content, level: 0, rows: [], imageUrl: '' });
          }
        }
      }
    } catch (e) {
      hilog.error(0x0000, TAG, 'parseBlocks failed: ' + JSON.stringify(e));
    }
    return result;
  }

  @Builder
  titleView(rb: RenderBlock) {
    Text(rb.text)
      .fontSize(rb.level <= 1 ? 21 : (rb.level === 2 ? 18 : 16))
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .width('100%')
      .margin({ top: 14, bottom: 4 })
  }

  @Builder
  textView(rb: RenderBlock) {
    Text(rb.text)
      .fontSize(14)
      .fontColor('rgba(255,255,255,0.85)')
      .lineHeight(22)
      .width('100%')
      .margin({ top: 4, bottom: 4 })
  }

  @Builder
  tableView(rb: RenderBlock) {
    Scroll() {
      Column() {
        ForEach(rb.rows, (row: string[], rIdx: number) => {
          Row() {
            ForEach(row, (cell: string, cIdx: number) => {
              Text(cell)
                .fontSize(12)
                .fontColor(rIdx === 0 ? '#FFFFFF' : 'rgba(255,255,255,0.85)')
                .fontWeight(rIdx === 0 ? FontWeight.Medium : FontWeight.Normal)
                .padding(7)
                .width(118)
                .backgroundColor(rIdx === 0 ? '#151517' : '#0C0C0C')
                .border({ width: 0.5, color: '#2A2C2E' })
            }, (cell: string, cIdx: number) => `${rIdx}_${cIdx}`)
          }
        }, (row: string[], rIdx: number) => `r${rIdx}`)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .width('100%')
    .margin({ top: 8, bottom: 8 })
  }

  build() {
    Scroll() {
      Column() {
        if (this.blocks.length === 0) {
          Text(this.parsedMarkdown.length > 0 ? this.parsedMarkdown : '(无结构化内容)')
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.6)')
            .width('100%')
        } else {
          ForEach(this.blocks, (rb: RenderBlock, idx: number) => {
            if (rb.kind === 'title') {
              this.titleView(rb)
            } else if (rb.kind === 'table') {
              this.tableView(rb)
            } else if (rb.kind === 'image') {
              Image(rb.imageUrl)
                .width('100%')
                .objectFit(ImageFit.Contain)
                .margin({ top: 8, bottom: 8 })
            } else {
              this.textView(rb)
            }
          }, (rb: RenderBlock, idx: number) => `b${idx}`)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
  }
}
