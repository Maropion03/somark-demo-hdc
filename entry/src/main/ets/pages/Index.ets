import { DocumentRecord } from '../model/Document';
import { ResultPage } from './ResultPage';
import { ScannerPage } from './ScannerPage';
import { fileUri } from '@kit.CoreFileKit';

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

  /** 文档卡片:左缩略图 + 右名称/状态。 */
  @Builder
  docCard(doc: DocumentRecord) {
    Row() {
      if (doc.originalImageUris.length > 0) {
        Image(fileUri.getUriFromPath(doc.originalImageUris[0]))
          .width(54)
          .height(54)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
          .backgroundColor('#1C1E1F')
      } else {
        Column()
          .width(54)
          .height(54)
          .borderRadius(8)
          .backgroundColor('#1C1E1F')
      }
      Column() {
        Text(doc.name)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.statusText(doc))
          .fontSize(12)
          .fontColor(this.statusColor(doc))
          .margin({ top: 5 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(12)
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#101112')
    .borderRadius(10)
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
                this.docCard(doc)
              }
              .onClick(() => {
                this.pathStack.pushPath({ name: 'ResultPage', param: doc.id });
              })
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
