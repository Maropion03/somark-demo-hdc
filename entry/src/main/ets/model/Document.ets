/**
 * 文档记录 —— 一次扫描会话产生一个文档。
 * 由 DocumentStore 持久化(沙箱 index.json + doc_images/)。
 */
export interface DocumentRecord {
  id: string;                  // 唯一 id
  name: string;                // 文档名(默认按时间;P1 可由 LLM 智能命名)
  createdAt: number;           // 创建时间戳(ms)
  originalImageUris: string[]; // 扫描原图在沙箱内的路径
  status: string;              // 'parsing' 解析中 | 'done' 已完成 | 'failed' 解析失败
  parsedMarkdown: string;      // SoMark 解析得到的 Markdown(未解析为空)
  parsedJson: string;          // SoMark 解析得到的结构化 JSON 原文(未解析为空)
  summary: string;             // 一句话总结(P1;未生成为空)
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/** 新建一个空文档记录(图片路径由调用方在导入沙箱后填入)。 */
export function newDocument(): DocumentRecord {
  const now: number = Date.now();
  const d: Date = new Date(now);
  const name: string = `扫描 ${d.getMonth() + 1}月${d.getDate()}日 ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
  return {
    id: `doc_${now}`,
    name: name,
    createdAt: now,
    originalImageUris: [],
    status: 'parsing',
    parsedMarkdown: '',
    parsedJson: '',
    summary: ''
  };
}
