/**
 * 轻量 Markdown 渲染器(只支持必要语法:标题/列表/代码块/行内代码/粗体/表格)。
 * 用于 Chat 消息体 + 块选择层共用。
 */

interface MdNode {
  kind: string;     // 'h' | 'p' | 'code' | 'li' | 'table' | 'rule'
  text: string;
  level: number;
  rows: string[][];
}

function isSepRow(cells: string[]): boolean {
  let h = false;
  for (const c of cells) {
    const t = c.trim();
    if (t.length === 0) continue;
    h = true;
    for (let i = 0; i < t.length; i++) {
      const ch = t.charAt(i);
      if (ch !== '-' && ch !== ':' && ch !== ' ') return false;
    }
  }
  return h;
}

function splitRow(line: string): string[] {
  let cells: string[] = line.split('|').map((c: string) => c.trim());
  if (cells.length > 0 && cells[0].length === 0) cells = cells.slice(1);
  if (cells.length > 0 && cells[cells.length - 1].length === 0) cells = cells.slice(0, cells.length - 1);
  return cells;
}

export function parseMarkdown(md: string): MdNode[] {
  const out: MdNode[] = [];
  const lines: string[] = md.split('\n');
  let i = 0;
  while (i < lines.length) {
    const raw: string = lines[i];
    const line: string = raw.trim();

    if (line.length === 0) { i++; continue; }

    // Fenced code block
    if (line.startsWith('```')) {
      const codeLines: string[] = [];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        codeLines.push(lines[i]);
        i++;
      }
      i++;
      out.push({ kind: 'code', text: codeLines.join('\n'), level: 0, rows: [] });
      continue;
    }

    // Image: ![alt](url)
    if (line.startsWith('![') && line.indexOf('](') > 0 && line.endsWith(')')) {
      const lp: number = line.indexOf('](');
      const url: string = line.substring(lp + 2, line.length - 1);
      if (url.length > 0) {
        out.push({ kind: 'img', text: url, level: 0, rows: [] });
        i++;
        continue;
      }
    }

    // Heading
    if (line.startsWith('#')) {
      let lvl = 0;
      while (lvl < line.length && line.charAt(lvl) === '#') lvl++;
      if (lvl >= 1 && lvl <= 6 && lvl < line.length && line.charAt(lvl) === ' ') {
        out.push({ kind: 'h', text: line.substring(lvl + 1), level: lvl, rows: [] });
        i++;
        continue;
      }
    }

    // Horizontal rule
    if (line === '---' || line === '***') {
      out.push({ kind: 'rule', text: '', level: 0, rows: [] });
      i++;
      continue;
    }

    // List item
    if (line.startsWith('- ') || line.startsWith('* ') || line.startsWith('+ ')) {
      out.push({ kind: 'li', text: line.substring(2), level: 0, rows: [] });
      i++;
      continue;
    }
    // Numbered list e.g. "1. xxx"
    let dotIdx = line.indexOf('. ');
    if (dotIdx > 0 && dotIdx <= 3) {
      let allDigits = true;
      for (let k = 0; k < dotIdx; k++) {
        const ch = line.charAt(k);
        if (ch < '0' || ch > '9') { allDigits = false; break; }
      }
      if (allDigits) {
        out.push({ kind: 'li', text: line.substring(dotIdx + 2), level: 1, rows: [] });
        i++;
        continue;
      }
    }

    // Table block (line with | and next line is separator)
    if (line.indexOf('|') >= 0 && i + 1 < lines.length && isSepRow(splitRow(lines[i + 1].trim()))) {
      const rows: string[][] = [];
      rows.push(splitRow(line));
      i += 2;
      while (i < lines.length) {
        const t = lines[i].trim();
        if (t.length === 0 || t.indexOf('|') < 0) break;
        const cells = splitRow(t);
        if (isSepRow(cells)) { i++; continue; }
        rows.push(cells);
        i++;
      }
      out.push({ kind: 'table', text: '', level: 0, rows: rows });
      continue;
    }

    // Default paragraph(可能跨多行,合并到下一空行)
    const buf: string[] = [line];
    i++;
    while (i < lines.length) {
      const t = lines[i].trim();
      if (t.length === 0 || t.startsWith('#') || t.startsWith('- ') || t.startsWith('* ')
          || t.startsWith('```') || t === '---' || t === '***'
          || (t.indexOf('|') >= 0 && i + 1 < lines.length && isSepRow(splitRow(lines[i + 1].trim())))) {
        break;
      }
      buf.push(t);
      i++;
    }
    out.push({ kind: 'p', text: buf.join(' '), level: 0, rows: [] });
  }
  return out;
}

@Component
export struct MarkdownView {
  @Prop text: string = '';
  @Prop baseColor: string = '#FFFFFF';
  private nodes: MdNode[] = [];

  aboutToAppear(): void { this.nodes = parseMarkdown(this.text); }

  // 当 text 更新(流式增量)时重新解析。aboutToReuse 不一定触发,改用 build 期重算。
  build() {
    Column({ space: 4 }) {
      ForEach(parseMarkdown(this.text), (n: MdNode, idx: number) => {
        if (n.kind === 'h') {
          Text(n.text)
            .fontSize(n.level <= 1 ? 19 : (n.level === 2 ? 17 : 15))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.baseColor)
            .margin({ top: 6, bottom: 2 })
        } else if (n.kind === 'code') {
          Text(n.text)
            .fontSize(12)
            .fontColor('#2E7D32')
            .fontFamily('monospace')
            .padding(8)
            .backgroundColor('rgba(0,0,0,0.05)')
            .borderRadius(6)
        } else if (n.kind === 'li') {
          Text('•  ' + n.text)
            .fontSize(14)
            .fontColor(this.baseColor)
            .lineHeight(20)
        } else if (n.kind === 'table') {
          Scroll() {
            Column() {
              ForEach(n.rows, (row: string[], r: number) => {
                Row() {
                  ForEach(row, (cell: string, c: number) => {
                    Text(cell)
                      .fontSize(12)
                      .fontColor(this.baseColor)
                      .fontWeight(r === 0 ? FontWeight.Medium : FontWeight.Normal)
                      .padding(6)
                      .width(96)
                      .backgroundColor(r === 0 ? 'rgba(0,0,0,0.05)' : 'rgba(0,0,0,0.02)')
                      .border({ width: 0.5, color: 'rgba(0,0,0,0.12)' })
                  }, (cell: string, c: number) => `${r}_${c}`)
                }
              }, (row: string[], r: number) => `r${r}`)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .margin({ top: 4, bottom: 4 })
        } else if (n.kind === 'img') {
          Image(n.text)
            .width(220)
            .objectFit(ImageFit.Contain)
            .borderRadius(6)
            .margin({ top: 6, bottom: 6 })
        } else if (n.kind === 'rule') {
          Divider().color('rgba(255,255,255,0.15)').margin({ top: 6, bottom: 6 })
        } else {
          Text(n.text)
            .fontSize(14)
            .fontColor(this.baseColor)
            .lineHeight(22)
        }
      }, (n: MdNode, idx: number) => `mdn_${idx}_${n.kind}_${n.text.length}`)
    }
    .alignItems(HorizontalAlign.Start)
  }
}
