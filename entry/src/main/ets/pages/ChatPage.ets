import { hilog } from '@kit.PerformanceAnalysisKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction, display } from '@kit.ArkUI';
import { fileUri } from '@kit.CoreFileKit';
import { ChatMessageList } from '../components/ChatMessageList';
import { ChatInputBar } from '../components/ChatInputBar';
import { DocDrawer } from '../components/DocDrawer';
import { SessionHistorySheet } from '../components/SessionHistorySheet';
import {
  ChatSession, ChatMessage, Citation, DocRef, BlockRef,
  newUserMessage, newAssistantMessage, newChatSession
} from '../model/Chat';
import { DocumentRecord } from '../model/Document';
import { ChatSessionStore } from '../services/ChatSessionStore';
import { DocumentStore } from '../services/DocumentStore';
import { DmxApiClient, DmxMessage, StreamHandle } from '../services/DmxApiClient';
import { Theme } from '../common/Theme';

const TAG: string = 'SoScan';

interface ChatPageParam {
  sessionId?: string;
  drawerOpen?: boolean;
}

/**
 * Chat 页 —— DeepSeek 风格 + 强化文档拖入。
 * 布局(从上到下): TopBar / Messages / DocDrawer / InputBar
 * 抽屉在输入框上方;点击消息区可以收抽屉 + 收键盘;右上角进历史会话。
 */
@Component
export struct ChatPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @StorageLink('documents') documents: DocumentRecord[] = [];
  @StorageLink('chatSessions') sessions: ChatSession[] = [];
  param: ChatPageParam = {};
  @State session: ChatSession = newChatSession();
  @State pendingCitations: Citation[] = [];
  @State sending: boolean = false;
  @State drawerExpanded: boolean = false;
  @State historyVisible: boolean = false;
  @State dropHover: boolean = false;
  // 自绘拖拽
  @State dragActive: boolean = false;
  @State dragX: number = 0;
  @State dragY: number = 0;
  @State dragDoc: DocumentRecord | null = null;
  // 实测投放区边界(全局 vp):抽屉顶 / 输入栏顶
  private drawerTopY: number = 99999;
  private inputTopY: number = 99999;
  private streamHandle: StreamHandle | null = null;
  private scrollKey: number = 0;

  screenHeightVp(): number {
    try {
      return this.getUIContext().px2vp(display.getDefaultDisplaySync().height);
    } catch (e) {
      return 800;
    }
  }

  onPickBegin(doc: DocumentRecord, x: number, y: number): void {
    this.dragDoc = doc;
    this.dragX = x;
    this.dragY = y;
    this.dragActive = true;
  }

  onPickMove(x: number, y: number): void {
    this.dragX = x;
    this.dragY = y;
  }

  /** 落在聊天区(抽屉顶边以上)或输入框(输入栏顶边以下)才加入引用;落在抽屉内(含搜索栏)不加。 */
  onPickRelease(x: number, y: number): void {
    const doc = this.dragDoc;
    this.dragActive = false;
    this.dragDoc = null;
    if (doc === null) return;
    if (y < this.drawerTopY || y >= this.inputTopY) {
      this.onPickDoc(doc);
    }
  }

  aboutToAppear(): void {
    if (this.param.sessionId !== undefined && this.param.sessionId.length > 0) {
      const found = ChatSessionStore.getSession(this.param.sessionId);
      if (found !== undefined) {
        this.session = found;
      }
    }
    if (this.param.drawerOpen === true) {
      this.drawerExpanded = true;
    }
    const handoff = AppStorage.get<Citation[]>('pendingCitations');
    if (handoff !== undefined && handoff.length > 0) {
      this.pendingCitations = [...this.pendingCitations, ...handoff];
      AppStorage.setOrCreate<Citation[]>('pendingCitations', []);
    }
  }

  buildDmxMessages(userText: string, citations: Citation[]): DmxMessage[] {
    const result: DmxMessage[] = [];
    if (citations.length > 0) {
      const parts: string[] = ['以下是用户引用的文档内容,请基于它回答问题:'];
      for (const c of citations) {
        if (c.kind === 'doc') {
          const dr = c as DocRef;
          const doc = DocumentStore.getDocument(dr.docId);
          if (doc !== undefined && doc.parsedMarkdown.length > 0) {
            parts.push(`\n--- 文档《${doc.name}》 ---\n${doc.parsedMarkdown}`);
          }
        } else {
          const br = c as BlockRef;
          parts.push(`\n--- 摘自《${br.docName}》第${br.pageIndex + 1}页 ---\n${br.previewText}`);
        }
      }
      result.push({ role: 'system', content: parts.join('\n') });
    }
    const hist = this.session.messages.slice(-12).filter((m: ChatMessage) => !m.pending);
    for (const m of hist) {
      result.push({ role: m.role, content: m.content });
    }
    result.push({ role: 'user', content: userText });
    return result;
  }

  /** 第一轮对话完成后,用 LLM 给会话起一个短标题。 */
  autoTitleIfNeeded(): void {
    const userMsgs = this.session.messages.filter((m: ChatMessage) => m.role === 'user');
    if (userMsgs.length !== 1) return;
    if (!this.session.title.startsWith('对话 ')) return;
    const firstUser: string = userMsgs[0].content;
    DmxApiClient.chat([
      { role: 'system', content: '请用 6-12 个汉字概括用户问题的主题,只输出标题本身,不要引号、不要解释。' },
      { role: 'user', content: firstUser }
    ]).then((title: string) => {
      let t: string = title.trim();
      const strip: string = '"\'「『』」';
      while (t.length > 0 && strip.indexOf(t.charAt(0)) >= 0) t = t.substring(1);
      while (t.length > 0 && strip.indexOf(t.charAt(t.length - 1)) >= 0) t = t.substring(0, t.length - 1);
      if (t.length > 0 && t.length <= 30) {
        this.session.title = t;
        ChatSessionStore.upsert(this.session);
      }
    }).catch((e: Error) => {});
  }

  doSend(text: string, citations: Citation[]): void {
    if (text.trim().length === 0 || this.sending) return;
    const userMsg: ChatMessage = newUserMessage(text, citations);
    const assistantMsg: ChatMessage = newAssistantMessage();
    const dmxMsgs: DmxMessage[] = this.buildDmxMessages(text, citations);
    this.session.messages = [...this.session.messages, userMsg, assistantMsg];
    this.pendingCitations = [];
    this.sending = true;
    ChatSessionStore.upsert(this.session);
    this.scrollKey++;

    this.streamHandle = DmxApiClient.chatStream(
      dmxMsgs,
      (delta: string) => {
        assistantMsg.content += delta;
        this.session.messages = [...this.session.messages];
        this.scrollKey++;
      },
      (err: Error | null) => {
        assistantMsg.pending = false;
        if (err !== null) {
          hilog.error(0x0000, TAG, 'stream failed: ' + err.message);
          if (assistantMsg.content.length === 0) {
            assistantMsg.content = `[调用失败] ${err.message}`;
          }
        }
        this.session.messages = [...this.session.messages];
        ChatSessionStore.upsert(this.session);
        this.sending = false;
        this.streamHandle = null;
        this.autoTitleIfNeeded();
      }
    );
  }

  onSend(text: string): void {
    this.doSend(text, this.pendingCitations);
  }

  stopGenerate(): void {
    if (this.streamHandle !== null) {
      this.streamHandle.abort();
    }
  }

  onPickDoc(doc: DocumentRecord): void {
    const exists = this.pendingCitations.find((c: Citation) =>
      c.kind === 'doc' && (c as DocRef).docId === doc.id
    );
    if (exists !== undefined) return;
    const ref: DocRef = { kind: 'doc', docId: doc.id, docName: doc.name };
    this.pendingCitations = [...this.pendingCitations, ref];
    this.drawerExpanded = false;
  }

  onOpenDoc(doc: DocumentRecord): void {
    this.drawerExpanded = false;
    this.pathStack.pushPath({ name: 'DocumentViewerPage', param: doc.id });
  }

  citeKey(c: Citation): string {
    if (c.kind === 'doc') return 'doc_' + (c as DocRef).docId;
    const b = c as BlockRef;
    return 'block_' + b.docId + '_' + b.pageIndex + '_' + b.blockIndices.join(',');
  }

  onRemoveCite(cite: Citation): void {
    // @Prop 把 citations 深拷贝给了子组件,回传的是副本,引用 !== 比不出 —— 按内容 key 比。
    const key: string = this.citeKey(cite);
    this.pendingCitations = this.pendingCitations.filter((c: Citation) => this.citeKey(c) !== key);
  }

  onLongPressMsg(m: ChatMessage): void {
    if (m.content.length === 0) return;
    AlertDialog.show({
      title: '消息操作',
      message: m.content.length > 100 ? m.content.substring(0, 100) + '…' : m.content,
      primaryButton: {
        value: '复制',
        action: () => {
          const pb = pasteboard.getSystemPasteboard();
          const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, m.content);
          pb.setData(data);
          promptAction.showToast({ message: '已复制' });
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#FA5151',
        action: () => {
          this.session.messages = this.session.messages.filter((x: ChatMessage) => x.id !== m.id);
          ChatSessionStore.upsert(this.session);
        }
      }
    });
  }

  onRetryMsg(m: ChatMessage): void {
    if (this.sending) return;
    const idx = this.session.messages.findIndex((x: ChatMessage) => x.id === m.id);
    if (idx <= 0) return;
    const prevUser = this.session.messages[idx - 1];
    if (prevUser.role !== 'user') return;
    this.session.messages = this.session.messages.slice(0, idx);
    ChatSessionStore.upsert(this.session);
    this.doSend(prevUser.content, prevUser.citations);
  }

  switchSession(s: ChatSession): void {
    this.historyVisible = false;
    this.session = s;
    this.pendingCitations = [];
  }

  deleteSession(s: ChatSession): void {
    const wasCurrent: boolean = s.id === this.session.id;
    ChatSessionStore.remove(s.id);
    promptAction.showToast({ message: '已删除' });
    if (wasCurrent) {
      // 删的是当前会话 → 退出到一个干净的新会话
      this.historyVisible = false;
      this.session = newChatSession();
      this.pendingCitations = [];
    }
  }

  newSession(): void {
    this.historyVisible = false;
    this.session = newChatSession();
    this.pendingCitations = [];
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          // TopBar
          Row() {
            Text('‹')
              .fontSize(22)
              .fontColor(Theme.BRAND)
              .width(40)
              .height(40)
              .textAlign(TextAlign.Center)
              .onClick(() => this.pathStack.pop())
            Text(this.session.title)
              .fontSize(16)
              .fontColor(Theme.TEXT_PRIMARY)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('☰')
              .fontSize(20)
              .fontColor(Theme.TEXT_PRIMARY)
              .width(40)
              .height(40)
              .textAlign(TextAlign.Center)
              .onClick(() => { this.historyVisible = true; })
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 6, bottom: 6 })
          .backgroundColor(Theme.BG_CARD)
          .border({ width: { bottom: 0.5 }, color: Theme.DIVIDER })

          // Messages (drop target for doc drag)
          Stack() {
            ChatMessageList({
              messages: this.session.messages,
              scrollKey: this.scrollKey,
              onLongPressMsg: (m: ChatMessage) => this.onLongPressMsg(m),
              onRetry: (m: ChatMessage) => this.onRetryMsg(m)
            })
            // Mask: 抽屉展开时,点消息区收回(B5)
            if (this.drawerExpanded) {
              Column()
                .width('100%')
                .height('100%')
                .backgroundColor(Color.Transparent)
                .onClick(() => { this.drawerExpanded = false; })
            }
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            // 点消息区收起键盘(C4)
            this.getUIContext().getFocusController().clearFocus();
          })

          // DocDrawer (above input)
          DocDrawer({
            expanded: $drawerExpanded,
            documents: this.documents,
            dropHover: this.dragActive,
            onPick: (d: DocumentRecord) => this.onPickDoc(d),
            onOpen: (d: DocumentRecord) => this.onOpenDoc(d),
            onPickBegin: (d: DocumentRecord, x: number, y: number) => this.onPickBegin(d, x, y),
            onPickMove: (x: number, y: number) => this.onPickMove(x, y),
            onPickRelease: (x: number, y: number) => this.onPickRelease(x, y)
          })
            .onAreaChange((_o: Area, n: Area) => {
              this.drawerTopY = n.globalPosition.y as number;
            })

          // InputBar (very bottom)
          ChatInputBar({
            citations: this.pendingCitations,
            sending: this.sending,
            dropHover: this.dragActive,
            onRemoveCite: (c: Citation) => this.onRemoveCite(c),
            onSend: (t: string) => this.onSend(t),
            onStop: () => this.stopGenerate()
          })
            .onAreaChange((_o: Area, n: Area) => {
              this.inputTopY = n.globalPosition.y as number;
            })
        }
        .width('100%')
        .height('100%')

        // 拖拽时:顶部聊天区提示条
        if (this.dragActive) {
          Text('拖到聊天区或输入框 · 松手引用')
            .fontSize(13)
            .fontColor(Theme.BRAND)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor(Theme.BRAND_SOFT)
            .borderRadius(14)
            .position({ x: '18%', y: 60 })
            .hitTestBehavior(HitTestMode.None)
        }

        // 跟手浮层
        if (this.dragActive && this.dragDoc !== null) {
          Row() {
            if (this.dragDoc!.originalImageUris.length > 0) {
              Image(fileUri.getUriFromPath(this.dragDoc!.originalImageUris[0]))
                .width(28).height(28).borderRadius(4).objectFit(ImageFit.Cover)
                .margin({ right: 6 })
            } else {
              Text('📄').fontSize(18).margin({ right: 6 })
            }
            Text(this.dragDoc!.name)
              .fontSize(13).fontColor('#FFFFFF')
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: 140 })
          }
          .padding({ left: 8, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#FF8C00')
          .borderRadius(10)
          .position({ x: this.dragX - 60, y: this.dragY - 24 })
          .hitTestBehavior(HitTestMode.None)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.4)', offsetX: 0, offsetY: 2 })
        }

        // History session sheet (full-overlay)
        if (this.historyVisible) {
          SessionHistorySheet({
            sessions: this.sessions,
            currentId: this.session.id,
            onClose: () => { this.historyVisible = false; },
            onSwitch: (s: ChatSession) => this.switchSession(s),
            onNew: () => this.newSession(),
            onDelete: (s: ChatSession) => this.deleteSession(s)
          })
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(Theme.BG_PAGE)
  }
}
