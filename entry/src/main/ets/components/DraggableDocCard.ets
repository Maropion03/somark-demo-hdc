import { DocumentRecord } from '../model/Document';
import { fileUri } from '@kit.CoreFileKit';
import { Theme } from '../common/Theme';

/**
 * 可拖拽文档卡片 —— 自绘拖拽(不用系统 draggable,避免小艺弹出,且整卡含图片都能拖)。
 * 手势:LongPress(长按) 触发 → Pan(跟手) 上报坐标 → 松手判定。坐标交父级渲染浮层 + 落点判定。
 */
@Component
export struct DraggableDocCard {
  doc: DocumentRecord = {
    id: '', name: '', createdAt: 0, originalImageUris: [], status: '',
    parsedMarkdown: '', parsedJson: '', summary: ''
  };
  onOpen: (doc: DocumentRecord) => void = () => {};
  onPickBegin: (doc: DocumentRecord, x: number, y: number) => void = () => {};
  onPickMove: (x: number, y: number) => void = () => {};
  onPickRelease: (x: number, y: number) => void = () => {};
  @State pressing: boolean = false;

  build() {
    Column() {
      if (this.doc.originalImageUris.length > 0) {
        Image(fileUri.getUriFromPath(this.doc.originalImageUris[0]))
          .width('100%')
          .height(110)
          .objectFit(ImageFit.Cover)
          .borderRadius({ topLeft: 10, topRight: 10 })
          .backgroundColor('#EDEDF0')
          .draggable(false)
      } else {
        Column()
          .width('100%')
          .height(110)
          .backgroundColor('#EDEDF0')
          .borderRadius({ topLeft: 10, topRight: 10 })
      }
      Column() {
        Text(this.doc.name)
          .fontSize(13)
          .fontColor(Theme.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.doc.status === 'parsing' ? '解析中…' :
             (this.doc.status === 'failed' ? '失败' : `${this.doc.originalImageUris.length} 页`))
          .fontSize(11)
          .fontColor(this.doc.status === 'parsing' ? Theme.BRAND : Theme.TEXT_HINT)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(8)
    }
    .width('100%')
    .backgroundColor(Theme.BG_CARD)
    .borderRadius(10)
    .border({ width: this.pressing ? 2 : 0.5, color: this.pressing ? Theme.BRAND : Theme.BORDER })
    .opacity(this.pressing ? 0.5 : 1.0)
    .onClick(() => this.onOpen(this.doc))
    .gesture(
      GestureGroup(GestureMode.Sequence,
        LongPressGesture({ repeat: false, duration: 300 })
          .onAction((e: GestureEvent) => {
            this.pressing = true;
            const f = e.fingerList.length > 0 ? e.fingerList[0] : undefined;
            const x: number = f !== undefined ? f.globalX : 0;
            const y: number = f !== undefined ? f.globalY : 0;
            this.onPickBegin(this.doc, x, y);
          }),
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1 })
          .onActionUpdate((e: GestureEvent) => {
            const f = e.fingerList.length > 0 ? e.fingerList[0] : undefined;
            if (f !== undefined) this.onPickMove(f.globalX, f.globalY);
          })
          .onActionEnd((e: GestureEvent) => {
            const f = e.fingerList.length > 0 ? e.fingerList[0] : undefined;
            const x: number = f !== undefined ? f.globalX : 0;
            const y: number = f !== undefined ? f.globalY : 0;
            this.pressing = false;
            this.onPickRelease(x, y);
          })
      )
    )
  }
}
