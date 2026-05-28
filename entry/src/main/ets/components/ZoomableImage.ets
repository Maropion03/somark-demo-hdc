import { fileUri } from '@kit.CoreFileKit';

/**
 * 单页可缩放图片 —— PinchGesture 双指缩放 + PanGesture 平移 + 双击复位。
 * onZoomChange 让父级知道当前是否处于缩放态(用于禁用 Swiper 翻页)。
 */
@Component
export struct ZoomableImage {
  filePath: string = '';
  onZoomChange: (zoomed: boolean) => void = () => {};
  @State zoomFactor: number = 1.0;
  @State panX: number = 0;
  @State panY: number = 0;
  private baseZoom: number = 1.0;
  private basePanX: number = 0;
  private basePanY: number = 0;

  resetZoom(): void {
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.zoomFactor = 1.0;
      this.panX = 0;
      this.panY = 0;
    });
    this.onZoomChange(false);
  }

  build() {
    Column() {
      Image(fileUri.getUriFromPath(this.filePath))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Contain)
        .scale({ x: this.zoomFactor, y: this.zoomFactor })
        .translate({ x: this.panX, y: this.panY })
        .gesture(
          GestureGroup(GestureMode.Parallel,
            PinchGesture({ fingers: 2 })
              .onActionStart(() => { this.baseZoom = this.zoomFactor; })
              .onActionUpdate((e: GestureEvent) => {
                let next: number = this.baseZoom * e.scale;
                if (next < 1.0) next = 1.0;
                if (next > 4.0) next = 4.0;
                this.zoomFactor = next;
                this.onZoomChange(this.zoomFactor > 1.01);
              }),
            PanGesture({ fingers: 1, direction: PanDirection.All })
              .onActionStart(() => {
                this.basePanX = this.panX;
                this.basePanY = this.panY;
              })
              .onActionUpdate((e: GestureEvent) => {
                if (this.zoomFactor > 1.01) {
                  this.panX = this.basePanX + e.offsetX;
                  this.panY = this.basePanY + e.offsetY;
                }
              }),
            TapGesture({ count: 2 })
              .onAction(() => {
                if (this.zoomFactor > 1.01) {
                  this.resetZoom();
                } else {
                  animateTo({ duration: 200 }, () => { this.zoomFactor = 2.0; });
                  this.onZoomChange(true);
                }
              })
          )
        )
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}
