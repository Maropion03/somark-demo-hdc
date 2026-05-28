import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatSession } from '../model/Chat';

const TAG: string = 'SoScan';
const INDEX_FILE: string = 'chat_index.json';

/**
 * Chat 会话持久化 —— 沙箱 chat_index.json + AppStorage('chatSessions')。
 */
export class ChatSessionStore {
  private static filesDir: string = '';

  static init(context: common.Context): void {
    ChatSessionStore.filesDir = context.filesDir;
    const list: ChatSession[] = ChatSessionStore.readIndex();
    AppStorage.setOrCreate<ChatSession[]>('chatSessions', list);
    hilog.info(0x0000, TAG, `ChatSessionStore init: ${list.length} sessions`);
  }

  static list(): ChatSession[] {
    const arr: ChatSession[] | undefined = AppStorage.get<ChatSession[]>('chatSessions');
    return arr ?? [];
  }

  static getSession(id: string): ChatSession | undefined {
    return ChatSessionStore.list().find((s: ChatSession) => s.id === id);
  }

  static upsert(session: ChatSession): void {
    session.updatedAt = Date.now();
    const list: ChatSession[] = ChatSessionStore.list();
    const idx: number = list.findIndex((s: ChatSession) => s.id === session.id);
    let next: ChatSession[];
    if (idx >= 0) {
      next = list.map((s: ChatSession) => s.id === session.id ? session : s);
    } else {
      next = [session, ...list];
    }
    ChatSessionStore.writeIndex(next);
    AppStorage.setOrCreate<ChatSession[]>('chatSessions', next);
    hilog.info(0x0000, TAG, `ChatSessionStore upsert ${session.id} (${session.messages.length} msgs)`);
  }

  static remove(id: string): void {
    const next: ChatSession[] = ChatSessionStore.list().filter((s: ChatSession) => s.id !== id);
    ChatSessionStore.writeIndex(next);
    AppStorage.setOrCreate<ChatSession[]>('chatSessions', next);
  }

  private static readIndex(): ChatSession[] {
    const path: string = `${ChatSessionStore.filesDir}/${INDEX_FILE}`;
    try {
      if (!fs.accessSync(path)) {
        return [];
      }
      const stat = fs.statSync(path);
      if (stat.size === 0) {
        return [];
      }
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const buf: ArrayBuffer = new ArrayBuffer(stat.size);
      const len: number = fs.readSync(file.fd, buf);
      fs.closeSync(file);
      const text: string = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf.slice(0, len)));
      const parsed = JSON.parse(text) as ChatSession[];
      // 兼容旧数据缺失字段
      for (const s of parsed) {
        if (s.pinned === undefined) s.pinned = false;
      }
      return parsed;
    } catch (e) {
      hilog.error(0x0000, TAG, 'chat readIndex failed: ' + JSON.stringify(e));
      return [];
    }
  }

  private static writeIndex(list: ChatSession[]): void {
    const path: string = `${ChatSessionStore.filesDir}/${INDEX_FILE}`;
    try {
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, JSON.stringify(list));
      fs.closeSync(file);
    } catch (e) {
      hilog.error(0x0000, TAG, 'chat writeIndex failed: ' + JSON.stringify(e));
    }
  }
}
