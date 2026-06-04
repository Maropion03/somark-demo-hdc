import { ChatSession } from '../model/Chat';
import { ChatSessionStore } from '../services/ChatSessionStore';
import { Theme } from '../common/Theme';
import { http } from '@kit.NetworkKit';

/**
 * 历史会话抽屉 —— 从屏幕右侧滑入,展示所有会话(置顶在前,按更新时间倒序)。
 * 长按会话条 → 重命名 / 置顶/取消置顶 / 删除。
 */
@Component
export struct SessionHistorySheet {
  @Prop sessions: ChatSession[] = [];
  @Prop open: boolean = true;
  currentId: string = '';
  onClose: () => void = () => {};
  onSwitch: (s: ChatSession) => void = () => {};
  onNew: () => void = () => {};
  onDelete: (s: ChatSession) => void = () => {};
  @State renaming: ChatSession | null = null;
  @State renameText: string = '';

  debugLog(hypothesisId: string, location: string, message: string, data: string): void {
    const req = http.createHttp();
    const payload: string = JSON.stringify({
      sessionId: '546962',
      runId: 'history-switch',
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

  sortedSessions(): ChatSession[] {
    const copy = [...this.sessions];
    copy.sort((a: ChatSession, b: ChatSession) => {
      if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt - a.updatedAt;
    });
    return copy;
  }

  showLongPressMenu(s: ChatSession): void {
    AlertDialog.show({
      title: s.title,
      message: '选择操作',
      buttons: [
        {
          value: s.pinned ? '取消置顶' : '置顶',
          action: () => {
            s.pinned = !s.pinned;
            ChatSessionStore.upsert(s);
          }
        },
        {
          value: '重命名',
          action: () => {
            this.renameText = s.title;
            this.renaming = s;
          }
        },
        {
          value: '删除',
          fontColor: '#FA5151',
          action: () => {
            this.onDelete(s);
          }
        }
      ]
    });
  }

  commitRename(): void {
    const s = this.renaming;
    if (s !== null) {
      const t: string = this.renameText.trim();
      if (t.length > 0) {
        s.title = t;
        ChatSessionStore.upsert(s);
      }
    }
    this.renaming = null;
  }

  @Builder
  renameDialog() {
    Column() {
      Column()
        .width('100%').height('100%')
        .backgroundColor(Theme.BG_MASK)
        .backdropBlur(10)
        .onClick(() => { this.renaming = null; })
      Column() {
        Text('重命名会话')
          .fontSize(16).fontColor(Theme.TEXT_PRIMARY).fontWeight(FontWeight.Medium)
          .width('100%').padding({ bottom: 12 })
        TextInput({ text: this.renameText })
          .fontSize(15).fontColor(Theme.TEXT_PRIMARY)
          .backgroundColor(Theme.BG_CARD).borderRadius(Theme.RADIUS_SM)
          .border({ width: 1, color: Theme.BORDER })
          .padding(10)
          .onChange((v: string) => { this.renameText = v; })
        Row() {
          Button('取消')
            .layoutWeight(1).height(40)
            .backgroundColor(Theme.BG_SUBTLE).fontColor(Theme.TEXT_PRIMARY).fontSize(14)
            .borderRadius(Theme.RADIUS_SM)
            .onClick(() => { this.renaming = null; })
          Button('确定')
            .layoutWeight(1).height(40)
            .backgroundColor(Theme.BRAND).fontColor(Theme.TEXT_ON_BRAND).fontSize(14)
            .borderRadius(Theme.RADIUS_SM)
            .margin({ left: 10 })
            .onClick(() => this.commitRename())
        }
        .width('100%').margin({ top: 14 })
      }
      .width('80%')
      .padding(18)
      .backgroundColor(Theme.BG_CARD)
      .borderRadius(Theme.RADIUS_LG)
      .shadow(Theme.SHADOW_FLOAT)
      .position({ x: '10%', y: '34%' })
    }
    .width('100%').height('100%')
    .position({ x: 0, y: 0 })
  }

  @Builder
  newSessionRow() {
    Row() {
      Text('+')
        .fontSize(18)
        .fontColor(Theme.TEXT_ON_BRAND)
        .margin({ right: 8 })
      Text('新建对话')
        .fontSize(15)
        .fontColor(Theme.TEXT_ON_BRAND)
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .height(44)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.BRAND)
    .borderRadius(Theme.RADIUS_LG)
    .margin({ bottom: 10 })
    .onClick(() => this.onNew())
  }

  @Builder
  sessionRow(s: ChatSession) {
    Row() {
      if (s.pinned) {
        Image($r('app.media.ic_pin_hint'))
          .width(16)
          .height(16)
          .objectFit(ImageFit.Contain)
          .margin({ right: 6 })
      }
      Column() {
        Text(s.title)
          .fontSize(15)
          .fontColor(s.id === this.currentId ? Theme.BRAND : Theme.TEXT_PRIMARY)
          .fontWeight(s.id === this.currentId ? FontWeight.Medium : FontWeight.Normal)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${s.messages.length} 条消息`)
          .fontSize(11)
          .fontColor(Theme.TEXT_HINT)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (s.id === this.currentId) {
        Text('当前')
          .fontSize(11)
          .fontColor(Theme.BRAND)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(Theme.BRAND_SOFT)
          .borderRadius(999)
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .backgroundColor(s.id === this.currentId ? 'rgba(10,89,247,0.10)' : Color.Transparent)
    .borderRadius(Theme.RADIUS_LG)
    .onClick(() => {
      // #region agent log
      this.debugLog('H8', 'SessionHistorySheet.sessionRow:onClick', 'row click', `sessionId=${s.id},title=${s.title},currentId=${this.currentId}`);
      // #endregion
      this.onSwitch(s);
    })
    .gesture(LongPressGesture({ duration: 350 }).onAction(() => this.showLongPressMenu(s)))
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      // 半透明遮罩,点外部关闭
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Theme.BG_MASK)
        .opacity(this.open ? 1 : 0)
        .backdropBlur(10)
        .animation({ duration: 240, curve: Curve.EaseInOut })
        .onClick(() => this.onClose())

      // 右侧抽屉
      Column() {
        Row() {
          Text('历史会话')
            .fontSize(17)
            .fontColor(Theme.TEXT_PRIMARY)
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
          Image($r('app.media.ic_close_dark'))
            .width(18)
            .height(18)
            .width(36).height(36)
            .objectFit(ImageFit.Contain)
            .onClick(() => this.onClose())
        }
        .width('100%')
        .padding({ left: 14, right: 10, top: 12, bottom: 8 })

        // 统一左右留白,避免按钮/选中态铺满侧栏
        Column() {
          this.newSessionRow()

          List() {
            ForEach(this.sortedSessions(), (s: ChatSession) => {
              ListItem() {
                this.sessionRow(s)
              }
              .margin({ top: 3, bottom: 3 })
            }, (s: ChatSession) => s.id + '_' + s.title + '_' + (s.pinned ? '1' : '0') + '_' + s.messages.length)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ top: 4, bottom: 4 })
          .scrollBar(BarState.Off)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 12, right: 12 })

        Text('长按会话条进行重命名 / 置顶 / 删除')
          .fontSize(11)
          .fontColor(Theme.TEXT_HINT)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ left: 12, right: 12, top: 6, bottom: 12 })
      }
      .width('82%')
      .height('100%')
      .backgroundColor(Theme.BG_GLASS)
      .backdropBlur(24)
      .border({ width: { left: 0.5 }, color: Theme.DIVIDER })
      // 再加大一档圆角，让侧边更柔和
      .borderRadius({ topLeft: 30, bottomLeft: 30 })
      .clip(true)
      .shadow(Theme.SHADOW_FLOAT)
      .translate({ x: this.open ? 0 : 32, y: 0 })
      .opacity(this.open ? 1 : 0)
      .scale({ x: this.open ? 1 : 0.985, y: this.open ? 1 : 0.985 })
      .animation({ duration: 240, curve: Curve.EaseInOut })

      if (this.renaming !== null) {
        this.renameDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}
