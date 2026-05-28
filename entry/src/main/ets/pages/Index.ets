import { ResultPage } from './ResultPage';
import { ScannerPage } from './ScannerPage';
import { ChatPage } from './ChatPage';
import { DocumentViewerPage } from './DocumentViewerPage';

interface ChatPageParam {
  sessionId?: string;
  drawerOpen?: boolean;
}

/**
 * App 入口 —— 纯 Navigation 容器,栈底永远是 ScannerPage(PRD §3.1)。
 * 自身没有 UI 内容,只承载 NavPathStack + pageMap。
 */
@Entry
@Component
struct Index {
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    // 启动后立即把 Scanner 作为栈底页推进去,等同于"打开 App 默认进入全屏相机"
    this.pathStack.pushPath({ name: 'ScannerPage' });
  }

  @Builder
  pageMap(name: string, param: Object) {
    if (name === 'ScannerPage') {
      ScannerPage()
    } else if (name === 'ResultPage') {
      ResultPage({ docId: param as string })
    } else if (name === 'ChatPage') {
      ChatPage({ param: param as ChatPageParam })
    } else if (name === 'DocumentViewerPage') {
      DocumentViewerPage({ docId: param as string })
    }
  }

  build() {
    Navigation(this.pathStack) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
    }
    .navDestination(this.pageMap)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
