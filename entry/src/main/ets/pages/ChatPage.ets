import { hilog } from '@kit.PerformanceAnalysisKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction, display } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { fileUri } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
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
import { DocumentParseService } from '../services/DocumentParseService';
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
  @State historyVisible: boolean = false;   // 控制挂载
  @State historyOpen: boolean = false;      // 控制开/关动画态
  @State pageEnter: boolean = false;
  @State sessionSwitching: boolean = false;
  @State dropHover: boolean = false;
  // 自绘拖拽
  @State dragActive: boolean = false;
  @State dragX: number = 0;
  @State dragY: number = 0;
  @State dragDoc: DocumentRecord | null = null;
  // 磁吸反馈：进入可投放区时更明显
  @State dropReady: boolean = false;
  // 实测投放区边界(全局 vp):抽屉顶 / 输入栏顶
  private drawerTopY: number = 99999;
  private inputTopY: number = 99999;
  private streamHandle: StreamHandle | null = null;
  private scrollKey: number = 0;
  private parsingPollTimer: number = -1;

  debugLog(hypothesisId: string, location: string, message: string, data: string): void {
    const req = http.createHttp();
    const payload: string = JSON.stringify({
      sessionId: '546962',
      runId: 'investigate-middle-state',
      hypothesisId: hypothesisId,
      location: location,
      message: message,
      data: data,
      timestamp: Date.now()
    });
    req.request('http://127.0.0.1:7553/ingest/ab900cb5-5ffc-44a9-b4ee-9d5b39d582b9', {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'X-Debug-Session-Id': '546962'
      },
      extraData: payload
    }).catch(() => {}).finally(() => req.destroy());
  }

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
    this.dropReady = (y < this.drawerTopY || y >= this.inputTopY);
    // #region agent log
    this.debugLog('H1', 'ChatPage.ets:onPickBegin', 'drag state begin',
      `docId=${doc.id},x=${x},y=${y},dragActive=${this.dragActive},drawerTopY=${this.drawerTopY},inputTopY=${this.inputTopY}`);
    // #endregion
  }

  onPickMove(x: number, y: number): void {
    this.dragX = x;
    this.dragY = y;
    this.dropReady = (y < this.drawerTopY || y >= this.inputTopY);
  }

  /** 落在聊天区(抽屉顶边以上)或输入框(输入栏顶边以下)才加入引用;落在抽屉内(含搜索栏)不加。 */
  onPickRelease(x: number, y: number): void {
    const doc = this.dragDoc;
    this.dragActive = false;
    this.dragDoc = null;
    this.dropReady = false;
    // #region agent log
    this.debugLog('H3', 'ChatPage.ets:onPickRelease', 'drag release evaluated',
      `docId=${doc !== null ? doc.id : ''},x=${x},y=${y},dragActive=${this.dragActive},drawerTopY=${this.drawerTopY},inputTopY=${this.inputTopY},shouldPick=${doc !== null && (y < this.drawerTopY || y >= this.inputTopY)}`);
    // #endregion
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
    this.pageEnter = false;
    this.startParsingPoll();
  }

  aboutToDisappear(): void {
    this.stopParsingPoll();
  }

  hasParsingDocs(): boolean {
    return this.documents.some((d: DocumentRecord) => d.status === 'parsing' && d.originalImageUris.length > 0);
  }

  startParsingPoll(): void {
    this.stopParsingPoll();
    const tick = () => {
      if (this.hasParsingDocs()) {
        try {
          const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
          DocumentParseService.reconcileParsingDocuments(context.cacheDir);
        } catch (e) {}
      }
      this.parsingPollTimer = setTimeout(tick, 2500);
    };
    this.parsingPollTimer = setTimeout(tick, 600);
  }

  stopParsingPoll(): void {
    if (this.parsingPollTimer >= 0) {
      clearTimeout(this.parsingPollTimer);
      this.parsingPollTimer = -1;
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
    // #region agent log
    this.debugLog('H4', 'ChatPage.ets:onOpenDoc', 'open document from drawer',
      `docId=${doc.id},drawerExpanded=${this.drawerExpanded},dragActive=${this.dragActive}`);
    // #endregion
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
    this.debugLog('H9', 'ChatPage.ets:switchSession', 'switchSession invoked', `sessionId=${s.id},title=${s.title},prevSessionId=${this.session.id}`);
    this.sessionSwitching = true;
    this.closeHistorySheet();
    this.session = s;
    this.pendingCitations = [];
    setTimeout(() => { this.sessionSwitching = false; }, 140);
  }

  deleteSession(s: ChatSession): void {
    const wasCurrent: boolean = s.id === this.session.id;
    ChatSessionStore.remove(s.id);
    promptAction.showToast({ message: '已删除' });
    if (wasCurrent) {
      // 删的是当前会话 → 退出到一个干净的新会话
      this.closeHistorySheet();
      this.session = newChatSession();
      this.pendingCitations = [];
    }
  }

  newSession(): void {
    this.closeHistorySheet();
    this.session = newChatSession();
    this.pendingCitations = [];
  }

  openHistorySheet(): void {
    this.historyVisible = true;
    this.historyOpen = false;
    // 给组件一帧时间完成挂载，避免首帧直接跳到终态
    setTimeout(() => { this.historyOpen = true; }, 16);
  }

  closeHistorySheet(): void {
    this.historyOpen = false;
    // 与抽屉离场动画时长对齐，避免提前卸载造成“硬切”
    setTimeout(() => { this.historyVisible = false; }, 260);
  }

  build() {
    NavDestination() {
      Stack() {
        // 消费级轻氛围底色（弱渐变，避免网页纯白大留白）
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(Theme.BG_PAGE)

        Column() {
          // TopBar
          Row() {
            Row() {
              Image($r('app.media.ic_back_brand'))
                .width(22)
                .height(22)
                .objectFit(ImageFit.Contain)
            }
            .width(40)
            .height(40)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.pathStack.pop())
            Text(this.session.title)
              .fontSize(16)
              .fontColor(Theme.TEXT_PRIMARY)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Row() {
              Image($r('app.media.ic_history_dark'))
                .width(22)
                .height(22)
                .objectFit(ImageFit.Contain)
            }
            .width(40)
            .height(40)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.openHistorySheet())
          }
          .width('100%')
          .padding({ left: 10, right: 10, top: 8, bottom: 8 })
          // TopBar 回归实体分区，更像 App 框架
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
            .opacity(this.sessionSwitching ? 0.88 : 1)
            .translate({ x: this.sessionSwitching ? 6 : 0, y: 0 })
            .animation({ duration: 150, curve: Curve.EaseOut })
            // 空态引导模块按你要求先移除
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
        .opacity(this.pageEnter ? 1 : 0.92)
        .translate({ x: this.pageEnter ? 0 : 12, y: 0 })
        .animation({ duration: 200, curve: Curve.EaseOut })

        // 拖拽时:顶部聊天区提示条
        if (this.dragActive) {
          Text('拖到聊天区或输入框 · 松手引用')
            .fontSize(13)
            .fontColor(Theme.BRAND)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor(this.dropReady ? 'rgba(10,89,247,0.22)' : Theme.BRAND_SOFT)
            .borderRadius(14)
            .position({ x: '18%', y: 60 })
            .scale({ x: this.dropReady ? 1.03 : 1.0, y: this.dropReady ? 1.03 : 1.0 })
            .opacity(this.dropReady ? 1.0 : 0.92)
            .hitTestBehavior(HitTestMode.None)
            .animation({ duration: 150, curve: Curve.EaseOut })
        }

        // 跟手浮层
        if (this.dragActive && this.dragDoc !== null) {
          Row() {
            if (this.dragDoc!.originalImageUris.length > 0) {
              Image(fileUri.getUriFromPath(this.dragDoc!.originalImageUris[0]))
                .width(28).height(28).borderRadius(4).objectFit(ImageFit.Cover)
                .margin({ right: 6 })
            } else {
              Image($r('app.media.ic_file_hint'))
                .width(18)
                .height(18)
                .objectFit(ImageFit.Contain)
                .margin({ right: 6 })
            }
            Text(this.dragDoc!.name)
              .fontSize(13).fontColor(Theme.TEXT_ON_BRAND)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: 140 })
          }
          .padding({ left: 8, right: 10, top: 6, bottom: 6 })
          .backgroundColor(Theme.BRAND)
          .borderRadius(Theme.RADIUS_SM)
          .border({ width: this.dropReady ? 1.2 : 0, color: this.dropReady ? Theme.BRAND_SOFT_BORDER : 'transparent' })
          .position({ x: this.dragX - 60, y: this.dragY - 24 })
          .hitTestBehavior(HitTestMode.None)
          .shadow({
            radius: this.dropReady ? 14 : 10,
            color: this.dropReady ? 'rgba(11,23,48,0.18)' : 'rgba(11,23,48,0.10)',
            offsetX: 0,
            offsetY: this.dropReady ? 4 : 2
          })
          .scale({ x: this.dropReady ? 1.02 : 1.0, y: this.dropReady ? 1.02 : 1.0 })
          .animation({ duration: 140, curve: Curve.EaseOut })
        }

        // History session sheet (full-overlay)
        if (this.historyVisible) {
          SessionHistorySheet({
            sessions: this.sessions,
            open: this.historyOpen,
            currentId: this.session.id,
            onClose: () => this.closeHistorySheet(),
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
    .onShown(() => { this.pageEnter = true; })
  }
}
