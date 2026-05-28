import { ChatSession } from '../model/Chat';
import { ChatSessionStore } from '../services/ChatSessionStore';
import { Theme } from '../common/Theme';

/**
 * 历史会话抽屉 —— 从屏幕右侧滑入,展示所有会话(置顶在前,按更新时间倒序)。
 * 长按会话条 → 重命名 / 置顶/取消置顶 / 删除。
 */
@Component
export struct SessionHistorySheet {
  @Prop sessions: ChatSession[] = [];
  currentId: string = '';
  onClose: () => void = () => {};
  onSwitch: (s: ChatSession) => void = () => {};
  onNew: () => void = () => {};
  onDelete: (s: ChatSession) => void = () => {};
  @State renaming: ChatSession | null = null;
  @State renameText: string = '';

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
        .backgroundColor('rgba(0,0,0,0.5)')
        .onClick(() => { this.renaming = null; })
      Column() {
        Text('重命名会话')
          .fontSize(16).fontColor(Theme.TEXT_PRIMARY).fontWeight(FontWeight.Medium)
          .width('100%').padding({ bottom: 12 })
        TextInput({ text: this.renameText })
          .fontSize(15).fontColor(Theme.TEXT_PRIMARY)
          .backgroundColor(Theme.BG_SUBTLE).borderRadius(8)
          .padding(10)
          .onChange((v: string) => { this.renameText = v; })
        Row() {
          Button('取消')
            .layoutWeight(1).height(40)
            .backgroundColor(Theme.BG_SUBTLE).fontColor(Theme.TEXT_PRIMARY).fontSize(14)
            .onClick(() => { this.renaming = null; })
          Button('确定')
            .layoutWeight(1).height(40)
            .backgroundColor(Theme.BRAND).fontColor(Theme.TEXT_ON_BRAND).fontSize(14)
            .margin({ left: 10 })
            .onClick(() => this.commitRename())
        }
        .width('100%').margin({ top: 14 })
      }
      .width('80%')
      .padding(18)
      .backgroundColor(Theme.BG_CARD)
      .borderRadius(14)
      .position({ x: '10%', y: '34%' })
    }
    .width('100%').height('100%')
    .position({ x: 0, y: 0 })
  }

  @Builder
  sessionRow(s: ChatSession) {
    Row() {
      if (s.pinned) {
        Text('📌').fontSize(13).margin({ right: 6 })
      }
      Column() {
        Text(s.title)
          .fontSize(15)
          .fontColor(Theme.TEXT_PRIMARY)
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
          .borderRadius(8)
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(s.id === this.currentId ? Theme.BRAND_SOFT : Color.Transparent)
    .onClick(() => this.onSwitch(s))
    .gesture(LongPressGesture({ duration: 350 }).onAction(() => this.showLongPressMenu(s)))
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      // 半透明遮罩,点外部关闭
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .onClick(() => this.onClose())

      // 右侧抽屉
      Column() {
        Row() {
          Text('历史会话')
            .fontSize(17)
            .fontColor(Theme.TEXT_PRIMARY)
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
          Text('×')
            .fontSize(22)
            .fontColor(Theme.TEXT_SECONDARY)
            .width(36).height(36)
            .textAlign(TextAlign.Center)
            .onClick(() => this.onClose())
        }
        .width('100%')
        .padding({ left: 14, right: 8, top: 12, bottom: 8 })

        Button() {
          Row() {
            Text('+').fontSize(20).fontColor(Theme.TEXT_ON_BRAND).margin({ right: 6 })
            Text('新建对话').fontSize(14).fontColor(Theme.TEXT_ON_BRAND)
          }
        }
        .width('92%')
        .height(40)
        .backgroundColor(Theme.BRAND)
        .borderRadius(8)
        .margin({ bottom: 8 })
        .onClick(() => this.onNew())

        Divider().color(Theme.DIVIDER)

        List() {
          ForEach(this.sortedSessions(), (s: ChatSession) => {
            ListItem() {
              this.sessionRow(s)
            }
          }, (s: ChatSession) => s.id + '_' + s.title + '_' + (s.pinned ? '1' : '0') + '_' + s.messages.length)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 0.5, color: Theme.DIVIDER })

        Text('长按会话条进行重命名 / 置顶 / 删除')
          .fontSize(11)
          .fontColor(Theme.TEXT_HINT)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 6, bottom: 12 })
      }
      .width('82%')
      .height('100%')
      .backgroundColor(Theme.BG_CARD)
      .border({ width: { left: 0.5 }, color: Theme.DIVIDER })

      if (this.renaming !== null) {
        this.renameDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}
