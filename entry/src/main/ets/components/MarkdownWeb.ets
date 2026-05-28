import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'SoScan';

/** JS → ArkTS 高度回传桥。 */
class SmHost {
  private cb: (h: number) => void;
  constructor(cb: (h: number) => void) { this.cb = cb; }
  setHeight(h: string): void { this.cb(Number(h)); }
}

/**
 * 用 somarkdown(UMD)在 ArkWeb 里渲染 Markdown —— 与前端 playground 同一渲染引擎。
 * autoHeight=true:按内容自适应高度(用于聊天气泡);false:填满父容器(用于抽屉/卡片)。
 */
@Component
export struct MarkdownWeb {
  @Prop @Watch('onMdChange') markdown: string = '';
  @Prop autoHeight: boolean = false;
  controller: webview.WebviewController = new webview.WebviewController();
  @State private webHeight: number = 36;
  private loaded: boolean = false;
  private host: SmHost = new SmHost((h: number) => {
    if (h > 0) this.webHeight = h + 4;
  });

  onMdChange(): void {
    this.push();
  }

  push(): void {
    if (!this.loaded) return;
    try {
      this.controller.runJavaScript(`smRender(${JSON.stringify(this.markdown)})`);
    } catch (e) {
      hilog.error(0x0000, TAG, 'MarkdownWeb push failed: ' + JSON.stringify(e));
    }
  }

  build() {
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
      .backgroundColor('#FFFFFF')
      .verticalScrollBarAccess(!this.autoHeight)
      .onPageEnd(() => {
        this.loaded = true;
        this.push();
      })
      .width('100%')
      .height(this.autoHeight ? this.webHeight : '100%')
  }
}
