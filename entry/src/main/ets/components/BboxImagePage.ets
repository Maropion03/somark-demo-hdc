import { fileUri } from '@kit.CoreFileKit';
import { SmPageInfo, SmBlock, blockTypeColor } from '../model/SmDoc';
import { Theme } from '../common/Theme';

/**
 * 单页扫描图 + bbox 选区高亮层(PRD §7)。
 */
@Component
export struct BboxImagePage {
  filePath: string = '';
  page: SmPageInfo = { pageNum: 0, w: 0, h: 0, blocks: [] };
  pageIndex: number = 0;
  @Prop selectedIdxs: number[] = [];
  @Prop entityIdxs: number[] = [];
  onGeometry: (pageIndex: number, globalY: number, w: number, h: number) => void = () => {};
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

  @Builder
  entityBottomMarks() {
    ForEach(this.entityIdxs, (arrIdx: number) => {
      if (this.blockByIdx(arrIdx) !== undefined) {
        Row()
          .position({
            x: this.blockByIdx(arrIdx)!.x1 * this.fitScale(),
            y: (this.blockByIdx(arrIdx)!.y2 * this.fitScale()) - 2
          })
          .width((this.blockByIdx(arrIdx)!.x2 - this.blockByIdx(arrIdx)!.x1) * this.fitScale())
          .height(0)
          .border({ width: { top: 2 }, color: Theme.BRAND, style: BorderStyle.Dashed })
          .hitTestBehavior(HitTestMode.None)
      }
    }, (arrIdx: number) => `ent_${this.pageIndex}_${arrIdx}`)
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
      this.entityBottomMarks()
    }
    .width('100%')
    .height('100%')
  }
}
