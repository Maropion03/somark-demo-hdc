import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../common/Theme';

const TAG: string = 'SoScan';
const LOADING_MIN_HEIGHT: number = 72;
const REVEAL_DURATION: number = 320;

/** JS → ArkTS 高度回传桥。 */
class SmHost {
  private cb: (h: number) => void;
  constructor(cb: (h: number) => void) { this.cb = cb; }
  setHeight(h: string): void { this.cb(Number(h)); }
}

/**
 * 用 somarkdown(UMD)在 ArkWeb 里渲染 Markdown —— 与前端 playground 同一渲染引擎。
 * autoHeight=true:按内容自适应高度(用于聊天气泡);false:填满父容器(用于抽屉/卡片)。
 * showLoading=true:渲染完成前显示加载中间态,完成后柔和淡入。
 */
@Component
export struct MarkdownWeb {
  @Prop @Watch('onMdChange') markdown: string = '';
  @Prop autoHeight: boolean = false;
  @Prop showLoading: boolean = false;
  controller: webview.WebviewController = new webview.WebviewController();
  @State private webHeight: number = LOADING_MIN_HEIGHT;
  @State private awaitingReveal: boolean = false;
  @State private overlayOpacity: number = 0;
  @State private contentOpacity: number = 1;
  @State private contentOffsetY: number = 0;
  private loaded: boolean = false;
  private loadFallbackTimer: number = -1;
  private host: SmHost = new SmHost((h: number) => {
    if (h > 0) {
      this.webHeight = h + 4;
      this.finishLoading();
    }
  });

  aboutToAppear(): void {
    if (this.showLoading) {
      this.beginLoading();
    }
  }

  aboutToDisappear(): void {
    this.clearLoadFallback();
  }

  onMdChange(): void {
    if (!this.loaded) return;
    if (this.showLoading) {
      this.beginLoading();
    }
    this.push();
  }

  beginLoading(): void {
    this.awaitingReveal = true;
    this.overlayOpacity = 1;
    this.contentOpacity = 0;
    this.contentOffsetY = 8;
    this.webHeight = LOADING_MIN_HEIGHT;
  }

  finishLoading(): void {
    if (!this.showLoading) return;
    this.clearLoadFallback();
    if (!this.awaitingReveal) return;
    this.awaitingReveal = false;
    animateTo({ duration: REVEAL_DURATION, curve: Curve.EaseOut }, () => {
      this.overlayOpacity = 0;
      this.contentOpacity = 1;
      this.contentOffsetY = 0;
    });
  }

  clearLoadFallback(): void {
    if (this.loadFallbackTimer >= 0) {
      clearTimeout(this.loadFallbackTimer);
      this.loadFallbackTimer = -1;
    }
  }

  scheduleLoadFallback(): void {
    this.clearLoadFallback();
    if (!this.showLoading) return;
    this.loadFallbackTimer = setTimeout(() => {
      if (this.awaitingReveal) {
        this.finishLoading();
      }
      this.loadFallbackTimer = -1;
    }, 6000);
  }

  push(): void {
    if (!this.loaded) return;
    try {
      this.controller.runJavaScript(`smRender(${JSON.stringify(this.markdown)})`);
    } catch (e) {
      hilog.error(0x0000, TAG, 'MarkdownWeb push failed: ' + JSON.stringify(e));
      this.finishLoading();
    }
  }

  boxHeight(): number | string {
    if (!this.autoHeight) return '100%';
    if (this.showLoading && this.awaitingReveal) return LOADING_MIN_HEIGHT;
    return this.webHeight;
  }

  @Builder
  loadingHint() {
    Column() {
      LoadingProgress()
        .width(28)
        .height(28)
        .color(Theme.BRAND)
      Text('加载预览…')
        .fontSize(13)
        .fontColor(Theme.TEXT_HINT)
        .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Theme.BG_CARD)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Web({ src: $rawfile('md/index.html'), controller: this.controller })
        .javaScriptProxy({
          object: this.host,
          name: 'smHost',
          methodList: ['setHeight'],
          controller: this.controller
        })
        .fileAccess(true)
        .domStorageAccess(true)
        .imageAccess(true)
        .onlineImageAccess(true)
        .darkMode(WebDarkMode.Off)
        .backgroundColor(Theme.BG_CARD)
        .verticalScrollBarAccess(!this.autoHeight)
        .opacity(this.showLoading ? this.contentOpacity : 1)
        .translate({ x: 0, y: this.showLoading ? this.contentOffsetY : 0 })
        .onPageEnd(() => {
          this.loaded = true;
          if (this.showLoading) {
            this.beginLoading();
            this.scheduleLoadFallback();
          }
          this.push();
        })
        .width('100%')
        .height(this.autoHeight ? this.webHeight : '100%')

      if (this.showLoading && this.overlayOpacity > 0) {
        Column() {
          this.loadingHint()
        }
        .width('100%')
        .height('100%')
        .opacity(this.overlayOpacity)
      }
    }
    .width('100%')
    .height(this.boxHeight())
    .clip(true)
    .animation({ duration: REVEAL_DURATION, curve: Curve.EaseOut })
  }
}
