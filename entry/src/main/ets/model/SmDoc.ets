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


/** block 实体识别(电话/网址/地址) —— 用于操作卡显示对应动作按钮。 */
export interface BlockEntity {
  kind: string;     // 'phone' | 'url' | 'address'
  value: string;    // 用于跳转的值(手机号/URL/地址文本)
}

// block 级搜索(不锚定首尾,直接在 content 里找匹配片段)
const PHONE_RE: RegExp = /(?:\+?86[-\s]?)?(?:1[3-9]\d{9}|0\d{2,3}[-\s]?\d{7,8}|[48]00[-\s]?\d{3,4}[-\s]?\d{3,4})/;
const URL_RE: RegExp = /(?:https?:\/\/\S+|www\.[\w\-]+\.[\w\-.]+(?:[\/?#]\S*)?)/i;

// 宽松地址识别:一段「连续的行政区划链 + 可选详细地址尾巴」。
// 链 = 省/市/区(及自治州/地区/盟/县/旗 等同级别后缀)的连续片段;命中后再校验
// 「省 / 市 / 区」三级里**至少出现两级**才算地址(只命中一级如单独「朝阳区」不算)。
const ADDR_CHAIN_RE: RegExp =
  /[一-龥]{2,8}?(?:省|自治区|特别行政区|市|自治州|地区|盟|区|县|旗)(?:[一-龥]{2,8}?(?:市|自治州|地区|盟|区|县|旗))*(?:[一-龥\dA-Za-z]{0,40}(?:路|街|巷|大道|大街|道|村|里|号|弄|室|栋|幢|楼|单元|座|大厦|广场|公寓|花园|小区|社区|中心|镇|乡))*/;

// 统计地址片段覆盖的行政级别数(省/市/区 三级;先剥掉「自治区/特别行政区/地区」避免其尾字误计为区级)。
function adminLevelCount(s: string): number {
  let n: number = 0;
  if (/省|自治区|特别行政区/.test(s)) n++;
  if (/市|自治州|地区|盟/.test(s)) n++;
  const distOnly: string = s.replace(/自治区|特别行政区|地区/g, '');
  if (/区|县|旗/.test(distOnly)) n++;
  return n;
}

/** 只有当 block 内**正好命中一类、且该类只出现一次**时才返回实体,其他情况返回 null。 */
export function classifyBlock(content: string): BlockEntity | null {
  if (content.length === 0) return null;

  // 全局扫描三类的所有匹配
  const urls: string[] = [];
  const reU: RegExp = new RegExp(URL_RE.source, 'gi');
  let m: RegExpExecArray | null = reU.exec(content);
  while (m !== null) { urls.push(m[0]); m = reU.exec(content); }

  const phones: string[] = [];
  const reP: RegExp = new RegExp(PHONE_RE.source, 'g');
  m = reP.exec(content);
  while (m !== null) { phones.push(m[0]); m = reP.exec(content); }

  const addrs: string[] = [];
  const reA: RegExp = new RegExp(ADDR_CHAIN_RE.source, 'g');
  m = reA.exec(content);
  while (m !== null) {
    if (m[0].length > 0 && adminLevelCount(m[0]) >= 2) addrs.push(m[0]);
    if (m[0].length === 0) reA.lastIndex++;   // 防零宽匹配死循环(理论上不会,保险)
    m = reA.exec(content);
  }

  // 严格判定:恰好一类有命中且数量为 1
  const cats: number = (urls.length > 0 ? 1 : 0) + (phones.length > 0 ? 1 : 0) + (addrs.length > 0 ? 1 : 0);
  if (cats !== 1) return null;
  if (urls.length === 1) {
    const v: string = urls[0].startsWith('http') ? urls[0] : 'http://' + urls[0];
    return { kind: 'url', value: v };
  }
  if (phones.length === 1) {
    return { kind: 'phone', value: phones[0].replace(/\s|-/g, '') };
  }
  if (addrs.length >= 1) {
    return { kind: 'address', value: addrs[0] };
  }
  return null;
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
