import { fileUri } from '@kit.CoreFileKit';

/** 文档预览左侧液态玻璃缩略图轨(类 Apple 预览)。 */
@Component
export struct DocumentThumbRail {
  @Prop uris: string[] = [];
  @Prop aspects: number[] = [];
  @Prop currentPage: number = 0;
  onSelectPage: (index: number) => void = () => {};

  private readonly thumbW: number = 54;

  thumbHeight(idx: number): number {
    const aspect: number = (idx < this.aspects.length && this.aspects[idx] > 0)
      ? this.aspects[idx] : 1.414;
    return Math.min(92, Math.max(40, this.thumbW * aspect));
  }

  build() {
    Scroll() {
      Column() {
        ForEach(this.uris, (uri: string, idx: number) => {
          Column() {
            Image(fileUri.getUriFromPath(uri))
              .width(this.thumbW)
              .height(this.thumbHeight(idx))
              .objectFit(ImageFit.Cover)
              .borderRadius(6)
              .backgroundColor('#FFFFFF')
          }
          .padding(4)
          .borderRadius(10)
          .border({
            width: this.currentPage === idx ? 2 : 0,
            color: '#FFFFFF'
          })
          .backgroundColor(this.currentPage === idx ? 'rgba(255,255,255,0.14)' : Color.Transparent)
          .onClick(() => {
            this.onSelectPage(idx);
          })
        }, (uri: string, idx: number) => `thumb_${idx}_${uri}`)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 6, bottom: 6 })
    }
    .width(76)
    .constraintSize({ maxHeight: '72%' })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor('rgba(46, 46, 50, 0.52)')
    .backdropBlur(36, { grayscale: [0.15, 0.65] })
    .borderRadius(24)
    .border({ width: 0.5, color: 'rgba(255,255,255,0.16)' })
    .shadow({
      radius: 24,
      color: 'rgba(0,0,0,0.35)',
      offsetX: 0,
      offsetY: 8
    })
    .padding({ left: 4, right: 4 })
  }
}
