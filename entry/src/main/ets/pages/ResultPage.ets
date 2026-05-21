import { DocumentRecord } from '../model/Document';

/**
 * 结果页 —— 显示一个文档的解析结果。
 * Task 5:展示解析状态 + Markdown 文本。
 * Task 6 会做成「原图 ↔ 还原结构」对比展示。
 */
@Component
export struct ResultPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @StorageLink('documents') documents: DocumentRecord[] = [];
  docId: string = '';

  currentDoc(): DocumentRecord | undefined {
    return this.documents.find((d: DocumentRecord) => d.id === this.docId);
  }

  @Builder
  centerHint(text: string) {
    Column() {
      Text(text)
        .fontSize(15)
        .fontColor('rgba(255,255,255,0.7)')
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Text('‹ 返回')
            .fontSize(16)
            .fontColor('#FF8C00')
            .onClick(() => {
              this.pathStack.pop();
            })
          Text(this.currentDoc()?.name ?? '文档')
            .fontSize(18)
            .fontColor('#FFFFFF')
            .margin({ left: 12 })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ bottom: 12 })

        if (this.currentDoc() === undefined) {
          this.centerHint('文档不存在')
        } else if (this.currentDoc()!.status === 'parsing') {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color('#FF8C00')
            Text('解析中…')
              .fontSize(15)
              .fontColor('rgba(255,255,255,0.7)')
              .margin({ top: 12 })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.currentDoc()!.status === 'failed') {
          this.centerHint('解析失败')
        } else {
          Scroll() {
            Text(this.currentDoc()!.parsedMarkdown.length > 0
              ? this.currentDoc()!.parsedMarkdown
              : '(解析结果为空)')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .width('100%')
              .textAlign(TextAlign.Start)
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.TopStart)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#000000')
      .padding({ left: 16, right: 16, top: 44, bottom: 16 })
    }
    .hideTitleBar(true)
  }
}
