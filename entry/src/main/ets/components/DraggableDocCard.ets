import { DocumentRecord } from '../model/Document';
import { fileUri } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
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
  // 长按进入拖拽后,抬手会伴随一次 click 事件;用该标记吞掉这次 click,避免误进详情页。
  @State suppressNextClick: boolean = false;
  @State lastX: number = 0;
  @State lastY: number = 0;

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

  build() {
    // 恢复为原来的卡片式文档缩略图
    Column() {
      if (this.doc.originalImageUris.length > 0) {
        Image(fileUri.getUriFromPath(this.doc.originalImageUris[0]))
          .width('100%')
          .height(110)
          .objectFit(ImageFit.Cover)
          .borderRadius({ topLeft: Theme.RADIUS_SM, topRight: Theme.RADIUS_SM })
          .backgroundColor(Theme.BG_SUBTLE)
          .draggable(false)
      } else {
        Column()
          .width('100%')
          .height(110)
          .backgroundColor(Theme.BG_SUBTLE)
          .borderRadius({ topLeft: Theme.RADIUS_SM, topRight: Theme.RADIUS_SM })
      }
      Column() {
        Text(this.doc.name)
          .fontSize(13)
          .fontColor(Theme.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.doc.status === 'parsing') {
          Row() {
            LoadingProgress()
              .width(12)
              .height(12)
              .color(Theme.BRAND)
            Text('解析中…')
              .fontSize(11)
              .fontColor(Theme.BRAND)
              .margin({ left: 4 })
          }
          .margin({ top: 3 })
        } else {
          Text(this.doc.status === 'failed' ? '失败' : `${this.doc.originalImageUris.length} 页`)
            .fontSize(11)
            .fontColor(Theme.TEXT_HINT)
            .margin({ top: 3 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(8)
    }
    .width('100%')
    .backgroundColor(Theme.BG_CARD)
    .borderRadius(Theme.RADIUS_SM)
    .border({ width: this.pressing ? 2 : 0.5, color: this.pressing ? Theme.BRAND : Theme.BORDER })
    .opacity(this.pressing ? 0.5 : 1.0)
    .shadow(Theme.SHADOW_SOFT)
    .onClick(() => {
      // #region agent log
      this.debugLog('H2', 'DraggableDocCard.ets:onClick', 'card click fired',
        `docId=${this.doc.id},suppressNextClick=${this.suppressNextClick},pressing=${this.pressing}`);
      // #endregion
      if (this.suppressNextClick) {
        // 运行证据表明某些长按链路不会触发 Pan.onActionEnd，但会直接触发 click。
        // 在吞 click 时补一条 release，确保父层 dragActive 被清理。
        if (this.pressing) {
          // #region agent log
          this.debugLog('H5', 'DraggableDocCard.ets:onClick', 'fallback release from suppressed click',
            `docId=${this.doc.id},x=${this.lastX},y=${this.lastY}`);
          // #endregion
          this.pressing = false;
          this.onPickRelease(this.lastX, this.lastY);
        }
        this.suppressNextClick = false;
        return;
      }
      this.onOpen(this.doc);
    })
    .gesture(
      GestureGroup(GestureMode.Sequence,
        LongPressGesture({ repeat: false, duration: 300 })
          .onAction((e: GestureEvent) => {
            this.pressing = true;
            this.suppressNextClick = true;
            const f = e.fingerList.length > 0 ? e.fingerList[0] : undefined;
            const x: number = f !== undefined ? f.globalX : 0;
            const y: number = f !== undefined ? f.globalY : 0;
            this.lastX = x;
            this.lastY = y;
            // #region agent log
            this.debugLog('H1', 'DraggableDocCard.ets:LongPress.onAction', 'long press begin drag',
              `docId=${this.doc.id},x=${x},y=${y},suppressNextClick=${this.suppressNextClick}`);
            // #endregion
            this.onPickBegin(this.doc, x, y);
          }),
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1 })
          .onActionUpdate((e: GestureEvent) => {
            const f = e.fingerList.length > 0 ? e.fingerList[0] : undefined;
            if (f !== undefined) {
              this.lastX = f.globalX;
              this.lastY = f.globalY;
              // #region agent log
              this.debugLog('H1', 'DraggableDocCard.ets:Pan.onActionUpdate', 'pan update',
                `docId=${this.doc.id},x=${f.globalX},y=${f.globalY}`);
              // #endregion
              this.onPickMove(f.globalX, f.globalY);
            }
          })
          .onActionEnd((e: GestureEvent) => {
            const f = e.fingerList.length > 0 ? e.fingerList[0] : undefined;
            const x: number = f !== undefined ? f.globalX : 0;
            const y: number = f !== undefined ? f.globalY : 0;
            this.pressing = false;
            // #region agent log
            this.debugLog('H1', 'DraggableDocCard.ets:Pan.onActionEnd', 'pan end release',
              `docId=${this.doc.id},x=${x},y=${y},suppressNextClick=${this.suppressNextClick}`);
            // #endregion
            this.onPickRelease(x, y);
          })
      )
    )
  }
}
