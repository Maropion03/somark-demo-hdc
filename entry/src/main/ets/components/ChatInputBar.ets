import { Citation } from '../model/Chat';
import { CiteChip } from './CiteChip';
import { Theme } from '../common/Theme';

/** 底部输入栏 —— 引用标签 + TextArea(多行) + 发送/停止。 */
@Component
export struct ChatInputBar {
  @Prop citations: Citation[] = [];
  @Prop sending: boolean = false;
  @Prop dropHover: boolean = false;
  onRemoveCite: (cite: Citation) => void = () => {};
  onSend: (text: string) => void = () => {};
  onStop: () => void = () => {};
  @State text: string = '';
  controller: TextAreaController = new TextAreaController();

  send(): void {
    const t: string = this.text.trim();
    if (t.length === 0) return;
    this.text = '';
    this.controller.stopEditing();
    this.onSend(t);
  }

  build() {
    Column() {
      Row() {
        // 输入框容器:引用标签(浅蓝)在框内顶部 + 多行输入
        Column() {
          if (this.citations.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.citations, (c: Citation, idx: number) => {
                Row() {
                  CiteChip({
                    cite: c, removable: true,
                    bg: Theme.CHIP_BG, fg: Theme.CHIP_TEXT,
                    onRemove: (rc: Citation) => this.onRemoveCite(rc)
                  })
                }
                .margin({ right: 6, bottom: 6 })
              }, (c: Citation, idx: number) => `inp_cite_${idx}_${c.kind}`)
            }
            .width('100%')
            .padding({ top: 8, left: 10, right: 10 })
          }
          TextArea({ placeholder: '说点什么…', text: this.text, controller: this.controller })
            .width('100%')
            .placeholderColor(Theme.TEXT_HINT)
            .placeholderFont({ size: 14 })
            .fontSize(15)
            .fontColor(Theme.TEXT_PRIMARY)
            .backgroundColor(Color.Transparent)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .constraintSize({ minHeight: 40, maxHeight: 140 })
            .onChange((v: string) => { this.text = v; })
        }
        .layoutWeight(1)
        .backgroundColor(Theme.BG_SUBTLE)
        .borderRadius(Theme.RADIUS_LG)
        .border({ width: 1, color: Theme.BORDER })

        if (this.sending) {
          Button() {
            Image($r('app.media.ic_stop_white'))
              .width(18)
              .height(18)
              .objectFit(ImageFit.Contain)
          }
          .type(ButtonType.Circle)
          .width(40).height(40)
          .backgroundColor(Theme.DANGER)
          .margin({ left: 8 })
          .shadow(Theme.SHADOW_SOFT)
          .onClick(() => this.onStop())
        } else {
          Button() {
            Image($r('app.media.ic_send_white'))
              .width(18)
              .height(18)
              .objectFit(ImageFit.Contain)
          }
          .type(ButtonType.Circle)
          .width(40).height(40)
          .backgroundColor(this.text.trim().length > 0 ? Theme.BRAND : Theme.BORDER)
          .margin({ left: 8 })
          .shadow(Theme.SHADOW_SOFT)
          .enabled(this.text.trim().length > 0)
          .onClick(() => this.send())
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    // InputBar 回归实体分区，更像 App
    .backgroundColor(Theme.BG_CARD)
    .border({
      width: this.dropHover ? { top: 2 } : { top: 0.5 },
      color: this.dropHover ? Theme.BRAND : Theme.DIVIDER
    })
  }
}
