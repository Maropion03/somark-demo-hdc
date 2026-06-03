/**
 * 全局设计 token —— HarmonyOS 风格(系统蓝 + 轻玻璃)。
 * 只承载视觉常量,不包含业务逻辑。
 */
export class Theme {
  // 品牌/强调色（系统蓝）
  static readonly BRAND: string = '#0A59F7';
  static readonly BRAND_PRESSED: string = '#0846C7';
  static readonly BRAND_SOFT: string = 'rgba(10,89,247,0.12)';
  static readonly BRAND_SOFT_BORDER: string = 'rgba(10,89,247,0.30)';

  // 背景层级
  static readonly BG_PAGE: string = '#F3F5FA';
  static readonly BG_CARD: string = '#FFFFFF';
  static readonly BG_SUBTLE: string = '#EEF2FB';
  static readonly BG_GLASS: string = 'rgba(255,255,255,0.78)';
  static readonly BG_MASK: string = 'rgba(10,18,40,0.26)';

  // 文字层级
  static readonly TEXT_PRIMARY: string = '#111827';
  static readonly TEXT_SECONDARY: string = '#5A6475';
  static readonly TEXT_HINT: string = '#93A0B8';
  static readonly TEXT_ON_BRAND: string = '#FFFFFF';

  // 线/分隔
  static readonly DIVIDER: string = '#E6EBF5';
  static readonly BORDER: string = '#D8E1F0';

  // 气泡
  static readonly BUBBLE_USER: string = '#0A59F7';
  static readonly BUBBLE_USER_TEXT: string = '#FFFFFF';
  static readonly BUBBLE_ASSIST: string = '#FFFFFF';
  static readonly BUBBLE_ASSIST_TEXT: string = '#111827';

  // 引用标签(浅蓝)
  static readonly CHIP_BG: string = 'rgba(10,89,247,0.12)';
  static readonly CHIP_TEXT: string = '#0A59F7';

  // 状态色
  static readonly DANGER: string = '#FA5151';

  // 圆角 token（Harmony 轻圆角）
  static readonly RADIUS_SM: number = 10;
  static readonly RADIUS_MD: number = 14;
  static readonly RADIUS_LG: number = 18;
  static readonly RADIUS_XL: number = 22;

  // 阴影 token（柔和层次）
  static readonly SHADOW_SOFT: ShadowOptions = {
    radius: 10,
    color: 'rgba(11,23,48,0.10)',
    offsetX: 0,
    offsetY: 2
  };
  static readonly SHADOW_FLOAT: ShadowOptions = {
    radius: 20,
    color: 'rgba(11,23,48,0.14)',
    offsetX: 0,
    offsetY: 6
  };
}
