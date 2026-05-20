/**
 * 结果页 —— NavDestination。阶段 1 Task 1 为占位空壳。
 * Task 6 会做成「原图 ↔ 还原结构」对比展示。
 */
@Component
export struct ResultPage {
  @Consume('pathStack') pathStack: NavPathStack;

  build() {
    NavDestination() {
      Column() {
        Text('结果页')
          .fontSize(20)
          .fontColor('#FFFFFF')
        Text('(占位 —— Task 6 做原图↔结构对比)')
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.5)')
          .margin({ top: 8 })
        Button('返回')
          .margin({ top: 24 })
          .backgroundColor('#FF8C00')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.pathStack.pop();
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .hideTitleBar(true)
    .backgroundColor('#000000')
  }
}
