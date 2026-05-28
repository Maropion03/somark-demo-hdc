import { fileUri } from '@kit.CoreFileKit';
import { SmPageInfo, SmBlock, blockTypeColor } from '../model/SmDoc';

/**
 * 单页扫描图 + bbox 选区高亮层(PRD §7)。
 * 本组件只负责:① 渲染图片;② 按父级下发的 selectedIdxs 画高亮;③ 把点按/长按手势的**全局坐标**转给父级。
 * 选区状态、跨页 hit-test、操作卡都在父级(DocumentViewerPage)统一处理 —— 以支持跨页多选。
 */
@Component
export struct BboxImagePage {
  filePath: string = '';
  page: SmPageInfo = { pageNum: 0, w: 0, h: 0, blocks: [] };
  pageIndex: number = 0;
  @Prop selectedIdxs: number[] = [];   // 本页被选中的 block 数组下标(父级下发)
  // 几何上报:本页图片显示宽/高 + 全局 Y
  onGeometry: (pageIndex: number, globalY: number, w: number, h: number) => void = () => {};
  // 手势转发(全局坐标)
  onTapAt: (gx: number, gy: number) => void = () => {};
  onPressStart: (gx: number, gy: number) => void = () => {};
  onPressMove: (gx: number, gy: number) => void = () => {};
  onPressEnd: () => void = () => {};

  @State private boxW: number = 0;

  fitScale(): number {
    return this.page.w > 0 && this.boxW > 0 ? this.boxW / this.page.w : 1;
  }

  blockByIdx(arrIdx: number): SmBlock | undefined {
    return arrIdx >= 0 && arrIdx < this.page.blocks.length ? this.page.blocks[arrIdx] : undefined;
  }

  fillColor(type: string): string {
    if (type === 'figure' || type === 'qr-code') return '#00000000';
    return '#33' + blockTypeColor(type).substring(1);
  }

  @Builder
  highlights() {
    ForEach(this.selectedIdxs, (arrIdx: number) => {
      if (this.blockByIdx(arrIdx) !== undefined) {
        Column()
          .position({ x: this.blockByIdx(arrIdx)!.x1 * this.fitScale(), y: this.blockByIdx(arrIdx)!.y1 * this.fitScale() })
          .width((this.blockByIdx(arrIdx)!.x2 - this.blockByIdx(arrIdx)!.x1) * this.fitScale())
          .height((this.blockByIdx(arrIdx)!.y2 - this.blockByIdx(arrIdx)!.y1) * this.fitScale())
          .backgroundColor(this.fillColor(this.blockByIdx(arrIdx)!.type))
          .border({ width: 2, color: blockTypeColor(this.blockByIdx(arrIdx)!.type) })
          .borderRadius(2)
          .hitTestBehavior(HitTestMode.None)
      }
    }, (arrIdx: number) => `sel_${this.pageIndex}_${arrIdx}`)
  }

  build() {
    Stack() {
      Image(fileUri.getUriFromPath(this.filePath))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill)
        .draggable(false)
        .onAreaChange((_o: Area, n: Area) => {
          this.boxW = n.width as number;
          this.onGeometry(this.pageIndex, n.globalPosition.y as number, n.width as number, n.height as number);
        })
        .gesture(
          GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 1 })
              .onAction((e: GestureEvent) => {
                const f = e.fingerList.length > 0 ? e.fingerList[0] : undefined;
                if (f !== undefined) this.onTapAt(f.globalX, f.globalY);
              }),
            GestureGroup(GestureMode.Sequence,
              LongPressGesture({ fingers: 1, repeat: false, duration: 250 })
                .onAction((e: GestureEvent) => {
                  const f = e.fingerList.length > 0 ? e.fingerList[0] : undefined;
                  if (f !== undefined) this.onPressStart(f.globalX, f.globalY);
                })
                .onActionEnd(() => this.onPressEnd()),
              PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5 })
                .onActionUpdate((e: GestureEvent) => {
                  const f = e.fingerList.length > 0 ? e.fingerList[0] : undefined;
                  if (f !== undefined) this.onPressMove(f.globalX, f.globalY);
                })
                .onActionEnd(() => this.onPressEnd())
            )
          )
        )

      this.highlights()
    }
    .width('100%')
    .height('100%')
  }
}
