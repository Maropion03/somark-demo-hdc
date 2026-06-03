import { Theme } from '../common/Theme';

/** 统一的「解析中」加载态。fill=true 时铺满父容器并居中(用于解析抽屉等)。 */
@Component
export struct ParsingIndicator {
  message: string = '正在解析…';
  hint: string = '';
  compact: boolean = false;
  fill: boolean = false;

  build() {
    Column() {
      LoadingProgress()
        .width(this.compact ? 20 : 30)
        .height(this.compact ? 20 : 30)
        .color(Theme.BRAND)
      Text(this.message)
        .fontSize(this.compact ? 12 : 14)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ top: this.compact ? 6 : 10 })
      if (this.hint.length > 0 && !this.compact) {
        Text(this.hint)
          .fontSize(12)
          .fontColor(Theme.TEXT_HINT)
          .margin({ top: 4 })
          .textAlign(TextAlign.Center)
      }
    }
    .width(this.fill ? '100%' : 'auto')
    .height(this.fill ? '100%' : 'auto')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
