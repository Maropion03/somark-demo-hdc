import { DocumentRecord } from '../model/Document';
import { ResultPage } from './ResultPage';
import { ScannerPage } from './ScannerPage';

/**
 * 首页 —— 文档列表 + 扫描入口。
 * 文档列表从 AppStorage('documents') 响应式读取(DocumentStore 维护)。
 */
@Entry
@Component
struct Index {
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack();
  @StorageLink('documents') documents: DocumentRecord[] = [];

  @Builder
  pageMap(name: string, param: Object) {
    if (name === 'ScannerPage') {
      ScannerPage()
    } else if (name === 'ResultPage') {
      ResultPage({ docId: param as string })
    }
  }

  statusText(doc: DocumentRecord): string {
    if (doc.status === 'parsing') {
      return '解析中…';
    }
    if (doc.status === 'failed') {
      return '解析失败';
    }
    return `已解析 · ${doc.originalImageUris.length} 页`;
  }

  statusColor(doc: DocumentRecord): string {
    if (doc.status === 'failed') {
      return '#FA5151';
    }
    if (doc.status === 'parsing') {
      return '#FF8C00';
    }
    return 'rgba(255,255,255,0.5)';
  }

  build() {
    Navigation(this.pathStack) {
      Column() {
        Text('SoScan')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width('100%')
          .padding({ top: 12, bottom: 12 })

        if (this.documents.length === 0) {
          Column() {
            Text('还没有扫描文档')
              .fontSize(16)
              .fontColor('rgba(255,255,255,0.7)')
            Text('点下方按钮开始扫描')
              .fontSize(13)
              .fontColor('rgba(255,255,255,0.5)')
              .margin({ top: 8 })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 10 }) {
            ForEach(this.documents, (doc: DocumentRecord) => {
              ListItem() {
                Column() {
                  Text(doc.name)
                    .fontSize(16)
                    .fontColor('#FFFFFF')
                  Text(this.statusText(doc))
                    .fontSize(12)
                    .fontColor(this.statusColor(doc))
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .width('100%')
                .padding(16)
              }
              .backgroundColor('#101112')
              .borderRadius(10)
              .onClick(() => {
                this.pathStack.pushPath({ name: 'ResultPage', param: doc.id });
              })
              // key 含 status:状态变化时 key 变,ForEach 才会重渲染该卡片
            }, (doc: DocumentRecord) => doc.id + '_' + doc.status)
          }
          .layoutWeight(1)
          .width('100%')
        }

        Button('扫描文档')
          .width('100%')
          .height(50)
          .fontSize(17)
          .fontColor('#FFFFFF')
          .backgroundColor('#FF8C00')
          .margin({ top: 12, bottom: 12 })
          .onClick(() => {
            this.pathStack.pushPath({ name: 'ScannerPage' });
          })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 44, bottom: 0 })
    }
    .navDestination(this.pageMap)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
