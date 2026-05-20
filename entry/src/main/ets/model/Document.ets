/**
 * 文档记录 —— 一次扫描会话产生一个文档。
 * 由 DocumentStore 持久化(沙箱文件 + JSON 索引)。
 */
export interface DocumentRecord {
  id: string;                  // 唯一 id
  name: string;                // 文档名(默认按时间;P1 可由 LLM 智能命名)
  createdAt: number;           // 创建时间戳(ms)
  originalImageUris: string[]; // 扫描原图在沙箱内的路径
  parsedMarkdown: string;      // SoMark 解析得到的 Markdown(未解析为空)
  parsedJson: string;          // SoMark 解析得到的结构化 JSON 原文(未解析为空)
  summary: string;             // 一句话总结(P1;未生成为空)
}
