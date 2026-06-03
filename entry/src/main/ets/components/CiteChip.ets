import { Citation, DocRef, BlockRef } from '../model/Chat';

/** 引用标签 —— 用在消息体和输入栏上方。 */
@Component
export struct CiteChip {
  cite: Citation = { kind: 'doc', docId: '', docName: '' } as DocRef;
  removable: boolean = false;
  bg: string = 'rgba(10,89,247,0.14)';
  fg: string = '#0A59F7';
  onRemove: (cite: Citation) => void = () => {};

  label(): string {
    if (this.cite.kind === 'doc') {
      return `${(this.cite as DocRef).docName}`;
    }
    const b = this.cite as BlockRef;
    const preview: string = b.previewText.length > 18 ? b.previewText.substring(0, 18) + '…' : b.previewText;
    return `“${preview}”`;
  }

  build() {
    Row() {
      if (this.cite.kind === 'doc') {
        Image($r('app.media.ic_file_hint'))
          .width(14)
          .height(14)
          .objectFit(ImageFit.Contain)
          .margin({ right: 6 })
      }
      Text(this.label())
        .fontSize(12)
        .fontColor(this.fg)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      if (this.removable) {
        Button() {
          Image($r('app.media.ic_close_dark'))
            .width(14)
            .height(14)
            .objectFit(ImageFit.Contain)
        }
        .type(ButtonType.Circle)
        .width(24)
        .height(24)
        .padding(0)
        .margin({ left: 6 })
        .backgroundColor('rgba(0,0,0,0.18)')
        .onClick(() => this.onRemove(this.cite))
      }
    }
    .padding({ left: 10, right: this.removable ? 4 : 10, top: 4, bottom: 4 })
    .backgroundColor(this.bg)
    .borderRadius(14)
    .constraintSize({ maxWidth: 240 })
  }
}
