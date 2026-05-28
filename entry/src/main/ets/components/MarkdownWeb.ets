import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'SoScan';

/**
 * 用 somarkdown(UMD)在 ArkWeb 里渲染 Markdown —— 与前端 playground 同一渲染引擎。
 * 资源在 rawfile/md/(somarkdown.umd.min.js + css)。
 */
@Component
export struct MarkdownWeb {
  @Prop @Watch('onMdChange') markdown: string = '';
  controller: webview.WebviewController = new webview.WebviewController();
  private loaded: boolean = false;

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
      .fileAccess(true)
      .domStorageAccess(true)
      .imageAccess(true)
      .onlineImageAccess(true)
      .darkMode(WebDarkMode.Off)
      .backgroundColor('#FFFFFF')
      .verticalScrollBarAccess(true)
      .onControllerAttached(() => {})
      .onPageEnd(() => {
        this.loaded = true;
        this.push();
      })
      .width('100%')
      .height('100%')
  }
}
