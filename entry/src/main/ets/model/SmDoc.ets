/**
 * SoMark 解析 JSON 的结构化模型(含 bbox 坐标)。
 * 每个 block 的 bbox = [x1,y1,x2,y2],坐标系为该页 page_size(w×h)像素。
 */

interface RawBlock {
  idx?: number;
  type?: string;
  bbox?: number[];
  content?: string;
  format?: string;
  img_url?: string;
  title_level?: number;
}
interface RawPageSize {
  w?: number;
  h?: number;
}
interface RawPage {
  page_num?: number;
  page_size?: RawPageSize;
  blocks?: RawBlock[];
}
interface RawDoc {
  pages?: RawPage[];
}

export interface SmBlock {
  idx: number;
  type: string;        // header | title | text | figure | table ...
  x1: number;
  y1: number;
  x2: number;
  y2: number;
  content: string;
  imgUrl: string;
  titleLevel: number;
}

export interface SmPageInfo {
  pageNum: number;
  w: number;
  h: number;
  blocks: SmBlock[];
}

/** block 类型 → 选区高亮代表色。 */
export function blockTypeColor(type: string): string {
  switch (type) {
    case 'text': return '#02E7F7';
    case 'title': return '#1E90FF';
    case 'cate': return '#00BFFF';
    case 'cate-item': return '#ADD8E6';
    case 'table': return '#32CD32';
    case 'tcaption': return '#008080';
    case 'footer': return '#2E8B57';
    case 'formula': return '#006400';
    case 'code': return '#9370DB';
    case 'choice': return '#8A2BE2';
    case 'stamp': return '#483D8B';
    case 'reference': return '#4B0082';
    case 'equation': return '#FF14E0';
    case 'figure': return '#FFA500';
    case 'fcaption': return '#FFD700';
    case 'header': return '#2F4F4F';
    case 'sider': return '#8B4513';
    case 'footenote': return '#A9A9A9';
    case 'blank': return '#C0C0C0';
    case 'qr-code': return '#000000';
    default: return '#C71585';
  }
}

/** 解析 parsedJson 成带 bbox 的页数组。失败返回空。 */
export function parseSmDoc(parsedJson: string): SmPageInfo[] {
  const result: SmPageInfo[] = [];
  if (parsedJson.length === 0) return result;
  try {
    const doc = JSON.parse(parsedJson) as RawDoc;
    const pages: RawPage[] = doc.pages ?? [];
    for (let pi = 0; pi < pages.length; pi++) {
      const p: RawPage = pages[pi];
      const ps: RawPageSize = p.page_size ?? {};
      const blocks: SmBlock[] = [];
      const rawBlocks: RawBlock[] = p.blocks ?? [];
      for (const b of rawBlocks) {
        const bb: number[] = b.bbox ?? [0, 0, 0, 0];
        blocks.push({
          idx: b.idx ?? 0,
          type: b.type ?? 'text',
          x1: bb.length > 0 ? bb[0] : 0,
          y1: bb.length > 1 ? bb[1] : 0,
          x2: bb.length > 2 ? bb[2] : 0,
          y2: bb.length > 3 ? bb[3] : 0,
          content: b.content ?? '',
          imgUrl: b.img_url ?? '',
          titleLevel: b.title_level ?? 0
        });
      }
      result.push({
        pageNum: p.page_num ?? pi,
        w: ps.w ?? 0,
        h: ps.h ?? 0,
        blocks: blocks
      });
    }
  } catch (e) {
    // ignore
  }
  return result;
}
