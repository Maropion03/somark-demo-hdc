/**
 * 全局配色 —— 白橙主题,贴合 HarmonyOS 视觉。
 * 主色沿用品牌橙 #FF8C00;背景走鸿蒙浅灰/白;文字深色。
 */
export class Theme {
  // 品牌色
  static readonly BRAND: string = '#FF8C00';
  static readonly BRAND_PRESSED: string = '#E67E00';
  static readonly BRAND_SOFT: string = 'rgba(255,140,0,0.12)';
  static readonly BRAND_SOFT_BORDER: string = 'rgba(255,140,0,0.35)';

  // 背景
  static readonly BG_PAGE: string = '#F1F3F5';     // 页面底
  static readonly BG_CARD: string = '#FFFFFF';     // 卡片/面板
  static readonly BG_SUBTLE: string = '#F5F5F7';   // 输入框/次级面板
  static readonly BG_MASK: string = 'rgba(0,0,0,0.35)';

  // 文字
  static readonly TEXT_PRIMARY: string = '#1A1A1A';
  static readonly TEXT_SECONDARY: string = '#6B6B70';
  static readonly TEXT_HINT: string = '#A8A8AD';
  static readonly TEXT_ON_BRAND: string = '#FFFFFF';

  // 线/分隔
  static readonly DIVIDER: string = '#E5E5EA';
  static readonly BORDER: string = '#E0E0E5';

  // 气泡
  static readonly BUBBLE_USER: string = '#FF8C00';
  static readonly BUBBLE_USER_TEXT: string = '#FFFFFF';
  static readonly BUBBLE_ASSIST: string = '#FFFFFF';
  static readonly BUBBLE_ASSIST_TEXT: string = '#1A1A1A';

  // 引用标签(浅橙)
  static readonly CHIP_BG: string = 'rgba(255,140,0,0.14)';
  static readonly CHIP_TEXT: string = '#C76A00';

  // 状态色
  static readonly DANGER: string = '#FA5151';
}
