import { ChatMessage, Citation } from '../model/Chat';
import { CiteChip } from './CiteChip';
import { MarkdownView } from './MarkdownView';
import { Theme } from '../common/Theme';

/** Chat 消息流(用户右浮、助手左浮 + Markdown 渲染 + 长按操作 + 重试 + 自动滚底)。 */
@Component
export struct ChatMessageList {
  @Prop messages: ChatMessage[] = [];
  @Prop @Watch('onScrollKeyChange') scrollKey: number = 0;
  onLongPressMsg: (m: ChatMessage) => void = () => {};
  onRetry: (m: ChatMessage) => void = () => {};
  scroller: Scroller = new Scroller();

  onScrollKeyChange(): void {
    // 流式 / 新消息时自动滚到底
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 30);
  }

  isLastFailed(m: ChatMessage): boolean {
    if (m.role !== 'assistant' || m.pending) return false;
    if (m.content.startsWith('[调用失败]')) return true;
    return false;
  }

  @Builder
  citeRow(citations: Citation[], inUserBubble: boolean) {
    if (citations.length > 0) {
      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Start }) {
        ForEach(citations, (c: Citation, idx: number) => {
          Row() {
            CiteChip({
              cite: c,
              removable: false,
              bg: inUserBubble ? 'rgba(255,255,255,0.22)' : Theme.CHIP_BG,
              fg: inUserBubble ? Theme.BUBBLE_USER_TEXT : Theme.CHIP_TEXT
            })
          }
          .margin({ right: 6, bottom: 6 })
        }, (c: Citation, idx: number) => `cite_${idx}`)
      }
    }
  }

  @Builder
  userBubble(m: ChatMessage) {
    Column() {
      Column() {
        this.citeRow(m.citations, true)
        if (m.content.length > 0) {
          Text(m.content)
            .fontSize(15)
            .fontColor(Theme.BUBBLE_USER_TEXT)
            .lineHeight(22)
            .margin({ top: m.citations.length > 0 ? 4 : 0 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(Theme.BUBBLE_USER)
      .borderRadius(Theme.RADIUS_MD)
      .shadow(Theme.SHADOW_SOFT)
      .gesture(LongPressGesture({ duration: 350 }).onAction(() => this.onLongPressMsg(m)))
    }
    .alignItems(HorizontalAlign.End)
    .constraintSize({ maxWidth: '85%' })
    .alignSelf(ItemAlign.End)
  }

  @Builder
  assistantBubble(m: ChatMessage) {
    Column() {
      if (m.pending && m.content.length === 0) {
        Row() {
          LoadingProgress().width(20).height(20).color(Theme.BRAND)
          Text('思考中…').fontSize(13).fontColor(Theme.TEXT_SECONDARY).margin({ left: 8 })
        }
        .padding(12)
        .backgroundColor(Theme.BUBBLE_ASSIST)
        .borderRadius(Theme.RADIUS_MD)
        .border({ width: 0.5, color: Theme.BORDER })
        .shadow(Theme.SHADOW_SOFT)
        .alignSelf(ItemAlign.Start)
      } else if (m.pending) {
        // 流式中:纯文本逐字更新,不走 Web(避免每 token 重渲闪烁)
        Text(m.content)
          .fontSize(15)
          .fontColor(Theme.BUBBLE_ASSIST_TEXT)
          .lineHeight(22)
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .backgroundColor(Theme.BUBBLE_ASSIST)
          .borderRadius(Theme.RADIUS_MD)
          .border({ width: 0.5, color: Theme.BORDER })
          .shadow(Theme.SHADOW_SOFT)
          .constraintSize({ maxWidth: '84%' })
          .alignSelf(ItemAlign.Start)
      } else {
        // 生成完成:自研 Markdown 渲染(原生自然撑高,不闪不卡)
        Column() {
          MarkdownView({ text: m.content, baseColor: Theme.BUBBLE_ASSIST_TEXT })
        }
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: '84%' })
        .alignSelf(ItemAlign.Start)
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor(Theme.BUBBLE_ASSIST)
        .borderRadius(Theme.RADIUS_MD)
        .border({ width: 0.5, color: Theme.BORDER })
        .shadow(Theme.SHADOW_SOFT)
        .gesture(LongPressGesture({ duration: 350 }).onAction(() => this.onLongPressMsg(m)))

        if (this.isLastFailed(m)) {
          Row() {
            Row() {
              Image($r('app.media.ic_retry_brand'))
                .width(14)
                .height(14)
                .objectFit(ImageFit.Contain)
                .margin({ right: 6 })
              Text('重试')
                .fontSize(12)
                .fontColor(Theme.BRAND)
            }
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(Theme.BRAND_SOFT)
            .borderRadius(999)
            .onClick(() => this.onRetry(m))
          }
          .margin({ top: 4 })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 12 }) {
        if (this.messages.length === 0) {
          Column() {
            Text('从底部抽屉拖入文档,或直接提问')
              .fontSize(14)
              .fontColor(Theme.TEXT_HINT)
          }
          .width('100%')
          .padding({ top: 80 })
        } else {
          ForEach(this.messages, (m: ChatMessage) => {
            if (m.role === 'user') {
              Row() {
                Column().layoutWeight(1)
                this.userBubble(m)
              }
              .width('100%')
            } else {
              Row() {
                this.assistantBubble(m)
                Column().layoutWeight(1)
              }
              .width('100%')
            }
          }, (m: ChatMessage) => m.pending
              ? m.id + '_p_' + m.content.length   // 流式中:含长度,逐字刷新纯文本(轻量)
              : m.id + '_d')                       // 完成:稳定 key,somarkdown 只渲染一次
        }
      }
      .width('100%')
      .padding({ top: 8, bottom: 12 })
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
  }
}
