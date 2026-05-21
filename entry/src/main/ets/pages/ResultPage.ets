import { DocumentRecord } from '../model/Document';
import { StructureRenderer } from '../components/StructureRenderer';
import { fileUri } from '@kit.CoreFileKit';

/**
 * 结果页 —— 「原图 ↔ 解析结构」对比展示。
 * 这是 demo 的王牌页:歪斜照片 → 干净的结构化解析结果。
 */
@Component
export struct ResultPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @StorageLink('documents') documents: DocumentRecord[] = [];
  docId: string = '';
  @State tab: number = 1;   // 0=原图,1=解析结构

  currentDoc(): DocumentRecord | undefined {
    return this.documents.find((d: DocumentRecord) => d.id === this.docId);
  }

  @Builder
  hint(text: string) {
    Column() {
      Text(text)
        .fontSize(15)
        .fontColor('rgba(255,255,255,0.6)')
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  tabBtn(label: string, idx: number) {
    Text(label)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .padding(9)
      .fontSize(14)
      .fontColor(this.tab === idx ? '#000000' : 'rgba(255,255,255,0.8)')
      .fontWeight(this.tab === idx ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.tab === idx ? '#FF8C00' : 'transparent')
      .borderRadius(6)
      .onClick(() => {
        this.tab = idx;
      })
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
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: 12 })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ bottom: 12 })

        if (this.currentDoc() === undefined) {
          this.hint('文档不存在')
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
          this.hint('解析失败')
        } else {
          Row() {
            this.tabBtn('原图', 0)
            this.tabBtn('解析结构', 1)
          }
          .width('100%')
          .padding(3)
          .backgroundColor('#151517')
          .borderRadius(8)
          .margin({ bottom: 12 })

          if (this.tab === 0) {
            Scroll() {
              Column() {
                ForEach(this.currentDoc()!.originalImageUris, (uri: string) => {
                  Image(fileUri.getUriFromPath(uri))
                    .width('100%')
                    .objectFit(ImageFit.Contain)
                    .margin({ bottom: 8 })
                }, (uri: string) => uri)
              }
              .width('100%')
            }
            .layoutWeight(1)
            .width('100%')
            .align(Alignment.TopStart)
          } else {
            StructureRenderer({
              parsedJson: this.currentDoc()!.parsedJson,
              parsedMarkdown: this.currentDoc()!.parsedMarkdown
            })
              .layoutWeight(1)
              .width('100%')
          }
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
