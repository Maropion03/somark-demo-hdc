/**
 * Chat 数据模型 —— Session / Message / 引用片段。
 */

/** 整篇文档引用(从文档抽屉拖入)。 */
export interface DocRef {
  kind: 'doc';
  docId: string;
  docName: string;
}

/** 块级引用(从文档查看页长按选块产生)。 */
export interface BlockRef {
  kind: 'block';
  docId: string;
  docName: string;
  pageIndex: number;
  blockIndices: number[];   // 选中的块序号(支持多块)
  previewText: string;      // 引用预览(取前 N 字)
}

export type Citation = DocRef | BlockRef;

/** ForEach / 去重 / 删除引用时的稳定 key。 */
export function citeKey(c: Citation): string {
  if (c.kind === 'doc') {
    return 'doc_' + (c as DocRef).docId;
  }
  const b = c as BlockRef;
  const previewKey: string = b.previewText.length > 0
    ? b.previewText.substring(0, 48)
    : 'empty';
  return `block_${b.docId}_${b.pageIndex}_${b.blockIndices.join(',')}_${previewKey}`;
}

export interface ChatMessage {
  id: string;
  role: string;             // 'user' | 'assistant'
  content: string;          // markdown
  citations: Citation[];    // 用户消息附带的引用
  createdAt: number;
  pending: boolean;         // assistant 流式中
}

export interface ChatSession {
  id: string;
  title: string;
  createdAt: number;
  updatedAt: number;
  messages: ChatMessage[];
  pinned: boolean;
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

export function newChatSession(): ChatSession {
  const now: number = Date.now();
  const d: Date = new Date(now);
  const title: string = `对话 ${d.getMonth() + 1}月${d.getDate()}日 ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
  return {
    id: `chat_${now}`,
    title: title,
    createdAt: now,
    updatedAt: now,
    messages: [],
    pinned: false
  };
}

export function newUserMessage(content: string, citations: Citation[]): ChatMessage {
  return {
    id: `msg_${Date.now()}_u`,
    role: 'user',
    content: content,
    citations: citations,
    createdAt: Date.now(),
    pending: false
  };
}

export function newAssistantMessage(): ChatMessage {
  return {
    id: `msg_${Date.now()}_a`,
    role: 'assistant',
    content: '',
    citations: [],
    createdAt: Date.now(),
    pending: true
  };
}
