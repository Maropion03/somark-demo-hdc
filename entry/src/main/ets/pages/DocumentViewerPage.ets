import { DocumentRecord } from '../model/Document';
import { PageMarkdownSheet } from '../components/PageMarkdownSheet';
import { ParsingIndicator } from '../components/ParsingIndicator';
import { BboxImagePage } from '../components/BboxImagePage';
import { DocumentThumbRail } from '../components/DocumentThumbRail';
import { MarkdownWeb } from '../components/MarkdownWeb';
import { BlockRef, Citation } from '../model/Chat';
import {
  SmPageInfo, SmBlock, parseSmDoc, classifyBlock, BlockEntity, EntityRange,
  findEntityRangeInText, markEntityInText
} from '../model/SmDoc';
import { DocumentStore } from '../services/DocumentStore';
import { DocumentParseService } from '../services/DocumentParseService';
import { ShareHelper } from '../services/ShareHelper';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { call } from '@kit.TelephonyKit';
import { promptAction, display } from '@kit.ArkUI';
import { common, Want, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { geoLocationManager } from '@kit.LocationKit';
import { mapCommon, map, MapComponent, petalMaps } from '@kit.MapKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { webview } from '@kit.ArkWeb';
import { Theme } from '../common/Theme';

const TAG: string = 'SoScan';

interface ChatPageParam {
  sessionId?: string;
  drawerOpen?: boolean;
}

interface Hit {
  page: number;
  idx: number;
}

/**
 * PRD §6/§7:文档查看页。多页竖向无缝瀑布流 + bbox 选区(支持**跨页多选**) + 左滑/解析看 Markdown。
 * 选区状态集中在本页:各 BboxImagePage 上报全局坐标,这里跨页 hit-test、算选区、统一出操作卡。
 */
@Component
export struct DocumentViewerPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @StorageLink('documents') @Watch('onDocsUpdate') documents: DocumentRecord[] = [];
  private lastParsedJson: string = '';
  docId: string = '';
  @State currentPage: number = 0;
  @State mdVisible: boolean = false;
  @State mdFullDoc: boolean = false;
  @State pages: SmPageInfo[] = [];
  @State screenW: number = 360;
  @State imgAspect: number[] = [];   // 各页图片真实 高/宽 比
  // 跨页选区(flat 位置 = 页号 + 该页 block 数组下标)
  @State anchorPage: number = -1;
  @State anchorIdx: number = -1;
  @State curPage: number = -1;
  @State curIdx: number = -1;
  @State pressing: boolean = false;   // 长按框选中
  @State carding: boolean = false;    // 操作卡显示
  @State cardIn: boolean = false;     // 操作卡入场动效
  /** 避免「点开操作卡」与「点背景关闭」同一次触摸串联。 */
  @State private ignoreCardBackdropOnce: boolean = false;
  @State pageEnter: boolean = false;
  @State contentViewportH: number = 640;
  @State thumbRailVisible: boolean = false;
  @State thumbRailIn: boolean = false;
  private pageTopY: number[] = [];    // 各页图片全局 Y(onGeometry 上报)
  scroller: Scroller = new Scroller();
  /** 多页时页间距。 */
  private readonly pageGapV: number = 12;
  private readonly pageSideMargin: number = 16;
  private readonly previewBg: string = '#FFFFFF';
  private readonly pageFrameBorder: string = '#000000';

  // ===== 地址 → 原生地图预览(Map Kit)=====
  @State geoLoading: boolean = false;   // 地理编码进行中
  @State geoFailed: boolean = false;    // 地理编码失败 → 卡片里给「在地图打开」兜底
  @State mapLat: number = 0;            // 0 表示尚未拿到坐标
  @State mapLng: number = 0;
  @State mapAddr: string = '';
  private mapOptions: mapCommon.MapOptions = {
    position: { target: { latitude: 39.9042, longitude: 116.4074 }, zoom: 10 }
  };
  private mapController?: map.MapComponentController;
  private urlController: webview.WebviewController = new webview.WebviewController();
  private parsingPollTimer: number = -1;

  aboutToAppear(): void {
    this.pageEnter = false;
    try {
      this.screenW = this.getUIContext().px2vp(display.getDefaultDisplaySync().width);
    } catch (e) {
      this.screenW = 360;
    }
    const doc = this.currentDoc();
    if (doc !== undefined) {
      this.pages = parseSmDoc(doc.parsedJson);
      this.lastParsedJson = doc.parsedJson;
      // 读取各页图片真实像素比例(解析前也能正确定高,避免横图被拉伸)
      const aspects: number[] = [];
      for (const uri of doc.originalImageUris) {
        let r: number = 1.414;
        try {
          const sz: image.Size = image.createImageSource(uri).getImageInfoSync().size;
          if (sz.width > 0) r = sz.height / sz.width;
        } catch (e) { r = 1.414; }
        aspects.push(r);
      }
      this.imgAspect = aspects;
    }
    this.startParsingPoll();
  }

  aboutToDisappear(): void {
    this.stopParsingPoll();
  }

  startParsingPoll(): void {
    this.stopParsingPoll();
    const tick = () => {
      const doc = this.currentDoc();
      if (doc !== undefined && doc.status === 'parsing') {
        try {
          const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
          DocumentParseService.parseDocument(doc.id, context.cacheDir);
        } catch (e) {}
      }
      this.parsingPollTimer = setTimeout(tick, 2500);
    };
    this.parsingPollTimer = setTimeout(tick, 600);
  }

  stopParsingPoll(): void {
    if (this.parsingPollTimer >= 0) {
      clearTimeout(this.parsingPollTimer);
      this.parsingPollTimer = -1;
    }
  }

  // documents 更新时(解析完成 status:parsing→done,parsedJson 由空变满)重算 pages,
  // 避免"先进页面再等解析"时点击/长按无反应。
  onDocsUpdate(): void {
    const doc = this.currentDoc();
    if (doc === undefined) return;
    if (doc.parsedJson !== this.lastParsedJson) {
      this.lastParsedJson = doc.parsedJson;
      this.pages = parseSmDoc(doc.parsedJson);
    }
  }

  currentDoc(): DocumentRecord | undefined {
    return this.documents.find((d: DocumentRecord) => d.id === this.docId);
  }

  isMultiPageDoc(): boolean {
    const doc = this.currentDoc();
    return doc !== undefined && doc.originalImageUris.length > 1;
  }

  pageContentWidth(): number {
    const w: number = this.screenW - this.pageSideMargin * 2;
    return w > 120 ? w : 120;
  }

  openThumbRail(): void {
    if (!this.isMultiPageDoc()) {
      return;
    }
    this.thumbRailVisible = true;
    this.thumbRailIn = false;
    setTimeout(() => {
      if (this.thumbRailVisible) {
        this.thumbRailIn = true;
      }
    }, 16);
  }

  closeThumbRail(): void {
    if (!this.thumbRailVisible) {
      return;
    }
    this.thumbRailIn = false;
    this.thumbRailVisible = false;
  }

  onThumbPageSelect(idx: number): void {
    this.scrollToPageIndex(idx);
  }

  pageHeight(idx: number): number {
    const cw: number = this.pageContentWidth();
    if (idx < this.imgAspect.length && this.imgAspect[idx] > 0) {
      return cw * this.imgAspect[idx];
    }
    if (idx < this.pages.length) {
      const p: SmPageInfo = this.pages[idx];
      if (p.w > 0 && p.h > 0) {
        return cw * (p.h / p.w);
      }
    }
    return cw * 1.414;
  }

  pageSlotHeight(idx: number): number {
    return this.pageHeight(idx) + this.pageGapV;
  }

  pageScrollTop(p: number): number {
    let acc: number = 0;
    for (let i = 0; i < p; i++) {
      acc += this.pageSlotHeight(i);
    }
    return acc;
  }

  scrollToPageIndex(p: number): void {
    const doc = this.currentDoc();
    if (doc === undefined || p < 0 || p >= doc.originalImageUris.length) {
      return;
    }
    try {
      this.scroller.scrollTo({ xOffset: 0, yOffset: this.pageScrollTop(p), animation: true });
    } catch (e) {
      // ignore
    }
    this.currentPage = p;
  }

  emptyPage(): SmPageInfo {
    return { pageNum: 0, w: 0, h: 0, blocks: [] };
  }

  pageInfo(idx: number): SmPageInfo {
    return idx < this.pages.length ? this.pages[idx] : this.emptyPage();
  }

  pageScale(p: number): number {
    const pi: SmPageInfo = this.pageInfo(p);
    const cw: number = this.pageContentWidth();
    return pi.w > 0 ? cw / pi.w : 1;
  }

  // 容器框(包住别的 block)→ 不可选
  isContainer(p: number, i: number): boolean {
    const blocks: SmBlock[] = this.pageInfo(p).blocks;
    const b: SmBlock = blocks[i];
    for (let j = 0; j < blocks.length; j++) {
      if (j === i) continue;
      const o: SmBlock = blocks[j];
      const cx: number = (o.x1 + o.x2) / 2;
      const cy: number = (o.y1 + o.y2) / 2;
      if (cx > b.x1 && cx < b.x2 && cy > b.y1 && cy < b.y2) return true;
    }
    return false;
  }

  // 全局坐标 → 命中页与最内层非容器 block
  hitGlobal(gx: number, gy: number): Hit {
    for (let p = 0; p < this.pages.length; p++) {
      const top: number = this.pageTopY[p] !== undefined ? this.pageTopY[p] : -99999;
      const h: number = this.pageHeight(p);
      if (gy >= top && gy < top + h) {
        const s: number = this.pageScale(p);
        const lx: number = gx;
        const ly: number = gy - top;
        const blocks: SmBlock[] = this.pageInfo(p).blocks;
        let best: number = -1;
        let bestArea: number = Number.MAX_VALUE;
        for (let i = 0; i < blocks.length; i++) {
          if (this.isContainer(p, i)) continue;
          const b: SmBlock = blocks[i];
          if (lx >= b.x1 * s && lx <= b.x2 * s && ly >= b.y1 * s && ly <= b.y2 * s) {
            const area: number = (b.x2 - b.x1) * (b.y2 - b.y1);
            if (area < bestArea) { bestArea = area; best = i; }
          }
        }
        return { page: p, idx: best };
      }
    }
    return { page: -1, idx: -1 };
  }

  // flat 位置比较:a 是否 <= b
  private leq(ap: number, ai: number, bp: number, bi: number): boolean {
    if (ap !== bp) return ap < bp;
    return ai <= bi;
  }

  // 本页被选中的 block 数组下标(供高亮)
  selectedPerPage(p: number): number[] {
    if (this.anchorPage < 0 || this.curPage < 0) return [];
    let loP: number = this.anchorPage; let loI: number = this.anchorIdx;
    let hiP: number = this.curPage; let hiI: number = this.curIdx;
    if (!this.leq(loP, loI, hiP, hiI)) { loP = this.curPage; loI = this.curIdx; hiP = this.anchorPage; hiI = this.anchorIdx; }
    if (p < loP || p > hiP) return [];
    const blocks: SmBlock[] = this.pageInfo(p).blocks;
    const start: number = (p === loP) ? loI : 0;
    const end: number = (p === hiP) ? hiI : blocks.length - 1;
    const out: number[] = [];
    for (let i = start; i <= end; i++) {
      if (i >= 0 && i < blocks.length && !this.isContainer(p, i)) out.push(i);
    }
    return out;
  }

  /** 本页所有命中电话/网址/地址的 block(解析完成后常态展示底边虚线,不依赖选区)。 */
  entityIdxsPerPage(p: number): number[] {
    const blocks: SmBlock[] = this.pageInfo(p).blocks;
    const out: number[] = [];
    for (let i = 0; i < blocks.length; i++) {
      if (this.isContainer(p, i)) {
        continue;
      }
      if (classifyBlock(blocks[i].content) !== null) {
        out.push(i);
      }
    }
    return out;
  }

  selectedMarkdown(): string {
    if (this.anchorPage < 0) return '';
    let loP: number = this.anchorPage; let hiP: number = this.curPage;
    if (!this.leq(this.anchorPage, this.anchorIdx, this.curPage, this.curIdx)) { loP = this.curPage; hiP = this.anchorPage; }
    const parts: string[] = [];

    // 先输出解析内容(文本/图片块)
    for (let p = loP; p <= hiP; p++) {
      const sel: number[] = this.selectedPerPage(p);
      const blocks: SmBlock[] = this.pageInfo(p).blocks;
      for (const i of sel) {
        const b: SmBlock = blocks[i];
        if (b.type === 'figure' && b.imgUrl.length > 0) {
          // img-frame:图片在前,图片理解在后(都在框内,somarkdown.css 的 ::before 加"图片理解"标签)
          const desc: string = b.content.length > 0 ? `<p>${b.content}</p>` : '';
          parts.push(`<figure class="img-frame"><img src="${b.imgUrl}" />${desc}</figure>`);
        } else if (b.content.length > 0) {
          let chunk: string = b.content;
          if (p === this.anchorPage && i === this.anchorIdx && this.anchorPage === this.curPage) {
            const ent: BlockEntity | null = classifyBlock(b.content);
            if (ent !== null) {
              chunk = markEntityInText(chunk, ent);
            }
          }
          parts.push(chunk);
        }
      }
    }

    // 网址/地址预览都不再走 iframe:
    //  - iframe 会被站点的 X-Frame-Options / CSP frame-ancestors 拦截而白屏(政府站常见);
    //  - 改在操作卡内用**原生 Web(顶层加载,非 frame)** 预览网址、用 MapComponent 预览地址。
    return parts.join('\n\n');
  }

  /** 操作卡预览是否需要 Web 渲染;纯文本走原生 Text,避免 WebView 冷启动白屏。 */
  selectedNeedsWebPreview(): boolean {
    if (this.anchorPage < 0) return false;
    let loP: number = this.anchorPage;
    let hiP: number = this.curPage;
    if (!this.leq(this.anchorPage, this.anchorIdx, this.curPage, this.curIdx)) {
      loP = this.curPage;
      hiP = this.anchorPage;
    }
    for (let p = loP; p <= hiP; p++) {
      const blocks: SmBlock[] = this.pageInfo(p).blocks;
      for (const i of this.selectedPerPage(p)) {
        const b: SmBlock = blocks[i];
        if (b.type === 'figure' && b.imgUrl.length > 0) return true;
        if (b.type === 'table' || b.type === 'tcaption') return true;
        const c: string = b.content;
        if (c.indexOf('<table') >= 0 || c.indexOf('<img') >= 0 || c.indexOf('$$') >= 0) return true;
      }
    }
    return false;
  }

  private stripHtmlToPlain(html: string): string {
    if (html.length === 0) return '';
    let s: string = html.replace(/<br\s*\/?>/gi, '\n');
    s = s.replace(/<\/p>/gi, '\n').replace(/<\/div>/gi, '\n');
    s = s.replace(/<[^>]+>/g, '');
    s = s.replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>');
    return s.trim();
  }

  /** 原生预览文案(与 selectedMarkdown 同源,去掉 HTML 标签)。 */
  selectedPreviewPlain(): string {
    if (this.anchorPage < 0) return '';
    let loP: number = this.anchorPage;
    let hiP: number = this.curPage;
    if (!this.leq(this.anchorPage, this.anchorIdx, this.curPage, this.curIdx)) {
      loP = this.curPage;
      hiP = this.anchorPage;
    }
    const parts: string[] = [];
    for (let p = loP; p <= hiP; p++) {
      const blocks: SmBlock[] = this.pageInfo(p).blocks;
      for (const i of this.selectedPerPage(p)) {
        const b: SmBlock = blocks[i];
        if (b.type === 'figure' && b.imgUrl.length > 0) {
          const desc: string = this.stripHtmlToPlain(b.content);
          parts.push(desc.length > 0 ? `[图片] ${desc}` : '[图片]');
        } else if (b.content.length > 0) {
          const plain: string = this.stripHtmlToPlain(b.content);
          if (plain.length > 0) parts.push(plain);
        }
      }
    }
    return parts.join('\n\n');
  }

  findPreviewEntityRange(): EntityRange | null {
    const entity: BlockEntity | null = this.selectedEntity();
    if (entity === null) {
      return null;
    }
    return findEntityRangeInText(this.selectedPreviewPlain(), entity);
  }

  previewTextBefore(): string {
    const plain: string = this.selectedPreviewPlain();
    const range: EntityRange | null = this.findPreviewEntityRange();
    if (range === null) {
      return plain;
    }
    return plain.substring(0, range.start);
  }

  previewTextEntity(): string {
    const range: EntityRange | null = this.findPreviewEntityRange();
    if (range === null) {
      return '';
    }
    const plain: string = this.selectedPreviewPlain();
    return plain.substring(range.start, range.end);
  }

  previewTextAfter(): string {
    const plain: string = this.selectedPreviewPlain();
    const range: EntityRange | null = this.findPreviewEntityRange();
    if (range === null) {
      return '';
    }
    return plain.substring(range.end);
  }

  @Builder
  selectionPreviewPlainMarked(before: string, entityPart: string, after: string) {
    Text() {
      if (before.length > 0) {
        Span(before)
          .fontSize(15)
          .fontColor(Theme.TEXT_PRIMARY)
      }
      Span(entityPart)
        .fontSize(15)
        .fontColor(Theme.BRAND)
        .decoration({
          type: TextDecorationType.Underline,
          style: TextDecorationStyle.DASHED,
          color: Theme.BRAND
        })
      if (after.length > 0) {
        Span(after)
          .fontSize(15)
          .fontColor(Theme.TEXT_PRIMARY)
      }
    }
    .lineHeight(24)
    .width('100%')
  }

  @Builder
  selectionPreview() {
    if (this.selectedNeedsWebPreview()) {
      MarkdownWeb({
        markdown: this.selectedMarkdown(),
        autoHeight: true,
        showLoading: true
      })
        .width('100%')
    } else if (this.findPreviewEntityRange() === null) {
      Text(this.selectedPreviewPlain())
        .fontSize(15)
        .fontColor(Theme.TEXT_PRIMARY)
        .lineHeight(24)
        .width('100%')
        .textAlign(TextAlign.Start)
    } else {
      this.selectionPreviewPlainMarked(
        this.previewTextBefore(),
        this.previewTextEntity(),
        this.previewTextAfter()
      )
    }
  }

  // ===== 手势(子组件转发全局坐标) =====
  private openSelectionCard(): void {
    this.ignoreCardBackdropOnce = true;
    this.closeThumbRail();
    this.mdVisible = false;
    this.carding = true;
    this.cardIn = true;
    this.prepareEntityPreview();
    setTimeout(() => {
      this.ignoreCardBackdropOnce = false;
    }, 80);
  }

  onTapAt(gx: number, gy: number): void {
    const hit: Hit = this.hitGlobal(gx, gy);
    if (hit.idx < 0) {
      return;
    }
    this.anchorPage = hit.page;
    this.anchorIdx = hit.idx;
    this.curPage = hit.page;
    this.curIdx = hit.idx;
    // 抽屉开着时:第一次点原文只收起抽屉,第二次再出操作卡
    if (this.mdVisible) {
      this.mdVisible = false;
      return;
    }
    this.openSelectionCard();
  }

  onPressStart(gx: number, gy: number): void {
    const hit: Hit = this.hitGlobal(gx, gy);
    if (hit.idx < 0) return;
    this.anchorPage = hit.page; this.anchorIdx = hit.idx;
    this.curPage = hit.page; this.curIdx = hit.idx;
    this.pressing = true;
    this.carding = false;
  }

  onPressMove(gx: number, gy: number): void {
    if (!this.pressing) return;
    const hit: Hit = this.hitGlobal(gx, gy);
    if (hit.idx >= 0) { this.curPage = hit.page; this.curIdx = hit.idx; }
  }

  onPressEnd(): void {
    if (!this.pressing) return;
    this.pressing = false;
    if (this.anchorPage >= 0) {
      this.openSelectionCard();
    }
  }

  closeCard(): void {
    this.carding = false;
    this.cardIn = false;
    this.pressing = false;
    this.anchorPage = -1; this.anchorIdx = -1;
    this.curPage = -1; this.curIdx = -1;
    this.resetMapState();
  }

  doAdd(): void {
    const md: string = this.selectedMarkdown();
    if (md.length === 0) { this.closeCard(); return; }
    const ref: BlockRef = {
      kind: 'block',
      docId: this.docId,
      docName: this.currentDoc()?.name ?? '文档',
      pageIndex: this.anchorPage >= 0 ? this.anchorPage : 0,
      blockIndices: [],
      previewText: md
    };
    this.closeCard();
    const pending: Citation[] = AppStorage.get<Citation[]>('pendingCitations') ?? [];
    AppStorage.setOrCreate<Citation[]>('pendingCitations', [...pending, ref]);
    const param: ChatPageParam = { drawerOpen: false };
    this.pathStack.pushPath({ name: 'ChatPage', param: param });
  }

  /** 单 block 选区 + 该 block 命中电话/网址/地址 → 返回实体,否则 null。 */
  selectedEntity(): BlockEntity | null {
    if (this.anchorPage < 0 || this.curPage < 0) return null;
    if (this.anchorPage !== this.curPage || this.anchorIdx !== this.curIdx) return null;
    const blocks: SmBlock[] = this.pageInfo(this.anchorPage).blocks;
    if (this.anchorIdx < 0 || this.anchorIdx >= blocks.length) return null;
    return classifyBlock(blocks[this.anchorIdx].content);
  }

  /** 命中网址或地址 → 卡内有大块预览(网址 Web / 地址地图),此时卡片定高为最大。 */
  hasEntityPreview(): boolean {
    const e: BlockEntity | null = this.selectedEntity();
    return e !== null && (e.kind === 'url' || e.kind === 'address');
  }

  // ===== 三种实体动作 =====
  dialPhone(num: string): void {
    try {
      call.makeCall(num, (err: Object) => {
        if (err) {
          hilog.error(0x0000, TAG, 'dial failed: ' + JSON.stringify(err));
          promptAction.showToast({ message: '拨号失败' });
        }
      });
    } catch (e) {
      promptAction.showToast({ message: '拨号失败' });
    }
  }

  abilityCb(action: string): common.AbilityStartCallback {
    return {
      onError: (code: number, name: string, msg: string) => {
        hilog.error(0x0000, TAG, `${action} err: ${code} ${name} ${msg}`);
        promptAction.showToast({ message: action + '失败' });
      }
    };
  }

  openUrl(url: string): void {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      // 通用 ViewData + browsable entity:任何注册了浏览能力的 app(系统浏览器/华为浏览器)都接得住
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url
      };
      ctx.startAbility(want).catch((e: Error) => {
        hilog.error(0x0000, TAG, 'openUrl failed: ' + e.message);
        promptAction.showToast({ message: '打开网址失败' });
      });
    } catch (e) {
      promptAction.showToast({ message: '打开网址失败' });
    }
  }

  /** 拉起华为 Petal 地图:有坐标走 POI 详情(更准),无坐标退回关键字搜索。 */
  openMap(addr: string): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (this.mapLat !== 0 || this.mapLng !== 0) {
      const params: petalMaps.PoiDetailParams = {
        destinationPosition: { latitude: this.mapLat, longitude: this.mapLng },
        destinationName: addr,
        zoom: 16,
        coordinateType: mapCommon.CoordinateType.GCJ02   // geocode 返回国测局坐标系
      };
      petalMaps.openMapPoiDetail(ctx, params).catch((e: BusinessError) => {
        hilog.error(0x0000, TAG, `openMapPoiDetail failed ${e.code}: ${e.message}`);
        this.openMapSearch(ctx, addr);
      });
    } else {
      this.openMapSearch(ctx, addr);
    }
  }

  /** 无坐标时:用地址文字在 Petal 地图里搜索。 */
  openMapSearch(ctx: common.UIAbilityContext, addr: string): void {
    petalMaps.openMapTextSearch(ctx, { destinationName: addr }).catch((e: BusinessError) => {
      hilog.error(0x0000, TAG, `openMapTextSearch failed ${e.code}: ${e.message}`);
      promptAction.showToast({ message: '打开地图失败' });
    });
  }

  // ===== 地址 → 原生地图预览 =====
  /** 选区变化后调用:命中地址则地理编码(地址文本→经纬度),供操作卡内 MapComponent 定位打点。 */
  prepareEntityPreview(): void {
    this.resetMapState();
    const e: BlockEntity | null = this.selectedEntity();
    if (e === null || e.kind !== 'address') return;
    this.mapAddr = e.value;
    this.geoLoading = true;
    this.ensureLocationPerm().then(() => this.geocode(e.value));
  }

  resetMapState(): void {
    this.geoLoading = false;
    this.geoFailed = false;
    this.mapLat = 0;
    this.mapLng = 0;
    this.mapAddr = '';
    try { this.mapController?.clear(); } catch (e) { }
  }

  /** 地理编码用到定位服务,先申请模糊定位权限(失败也继续尝试,部分机型无需授权即可编码)。 */
  async ensureLocationPerm(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const perms: Permissions[] = ['ohos.permission.APPROXIMATELY_LOCATION'];
      await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(ctx, perms);
    } catch (e) {
      hilog.warn(0x0000, TAG, 'request location perm failed: ' + JSON.stringify(e));
    }
  }

  geocode(addr: string): void {
    geoLocationManager.getAddressesFromLocationName({ description: addr, maxItems: 1 })
      .then((arr: geoLocationManager.GeoAddress[]) => {
        this.geoLoading = false;
        const a: geoLocationManager.GeoAddress | undefined = arr.length > 0 ? arr[0] : undefined;
        if (a !== undefined && a.latitude !== undefined && a.longitude !== undefined) {
          this.mapLat = a.latitude;
          this.mapLng = a.longitude;
          this.applyMapCamera();
        } else {
          this.geoFailed = true;
          hilog.warn(0x0000, TAG, 'geocode empty for: ' + addr);
        }
      })
      .catch((err: BusinessError) => {
        this.geoLoading = false;
        this.geoFailed = true;
        hilog.error(0x0000, TAG, `geocode failed ${err.code}: ${err.message}`);
      });
  }

  /** 坐标和 controller 都就绪时:移动相机 + 打点。两边任一后到都会回调到这里。 */
  applyMapCamera(): void {
    const c: map.MapComponentController | undefined = this.mapController;
    if (c === undefined || (this.mapLat === 0 && this.mapLng === 0)) return;
    const target: mapCommon.LatLng = { latitude: this.mapLat, longitude: this.mapLng };
    try {
      c.animateCamera(map.newCameraPosition({ target: target, zoom: 16 }), 300);
      c.clear();
      c.addMarker({ position: target, title: this.mapAddr });
    } catch (e) {
      hilog.error(0x0000, TAG, 'applyMapCamera failed: ' + JSON.stringify(e));
    }
  }

  doEntityAction(): void {
    const e: BlockEntity | null = this.selectedEntity();
    if (e === null) return;
    this.closeCard();
    if (e.kind === 'phone') this.dialPhone(e.value);
    else if (e.kind === 'url') this.openUrl(e.value);
    else if (e.kind === 'address') this.openMap(e.value);
  }

  entityIcon(e: BlockEntity): ResourceStr {
    if (e.kind === 'phone') return $r('app.media.ic_phone_brand');
    if (e.kind === 'url') return $r('app.media.ic_web_brand');
    return $r('app.media.ic_map_brand');
  }

  entityLabel(e: BlockEntity): string {
    if (e.kind === 'phone') return '拨打 ' + e.value;
    if (e.kind === 'url') return '在浏览器打开';
    if (e.kind === 'address') return '在地图打开';
    return '';
  }

  centerPageFromScroll(): number {
    const doc = this.currentDoc();
    if (doc === undefined) {
      return 0;
    }
    let yOff: number = 0;
    try {
      yOff = this.scroller.currentOffset().yOffset;
    } catch (e) {
      yOff = 0;
    }
    const viewCenter: number = yOff + this.contentViewportH * 0.5;
    let acc: number = 0;
    for (let i = 0; i < doc.originalImageUris.length; i++) {
      const slot: number = this.pageSlotHeight(i);
      if (viewCenter < acc + slot) {
        return i;
      }
      acc += slot;
    }
    return doc.originalImageUris.length - 1;
  }

  openSheet(fullDoc: boolean): void {
    if (this.currentDoc() === undefined) {
      return;
    }
    this.closeCard();
    this.closeThumbRail();
    this.mdFullDoc = fullDoc;
    this.mdVisible = true;
  }

  toggleParseSheet(fullDoc: boolean): void {
    if (this.currentDoc() === undefined) {
      return;
    }
    if (this.currentDoc()!.status === 'parsing') {
      return;
    }
    if (this.mdVisible) {
      this.mdVisible = false;
      return;
    }
    this.openSheet(fullDoc);
  }

  sharePdf(): void {
    const doc = this.currentDoc();
    if (doc === undefined) return;
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ShareHelper.sharePdf(ctx, doc.id, doc.name, doc.originalImageUris)
      .catch((e: Error) => {
        hilog.error(0x0000, TAG, 'sharePdf failed: ' + e.message);
        promptAction.showToast({ message: '分享失败: ' + e.message });
      });
  }

  deleteDoc(): void {
    const doc = this.currentDoc();
    if (doc === undefined) return;
    DocumentStore.removeDocument(doc.id);
    promptAction.showToast({ message: '已删除' });
    this.pathStack.pop();
  }

  @Builder
  moreMenu() {
    Menu() {
      MenuItem({ content: '以 PDF 分享' }).onClick(() => this.sharePdf())
      MenuItem({ content: '删除文档' }).onClick(() => this.deleteDoc())
    }
  }

  /** 居中两段式操作卡:上白色圆角 Markdown 窗 + 下独立 Add to Chat 小窗;外部毛玻璃虚化。 */
  @Builder
  optionCard() {
    Stack() {
      // 外部仅轻微虚化,不遮挡背后文档内容;点外部关闭
      Column()
        .width('100%').height('100%')
        .backgroundColor(Color.Transparent)
        .backdropBlur(8)
        .onClick(() => {
          if (this.ignoreCardBackdropOnce) {
            return;
          }
          this.closeCard();
        })

      Column() {
        Column() {
          if (this.hasEntityPreview()) {
            // 网址/地址:文案区自适应高度 + 地图/网页固定预览高度,整体可滚动
            Scroll() {
              Column() {
                Column() {
                  this.selectionPreview()
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding({ left: 16, right: 16, top: 14, bottom: 12 })

                if (this.selectedEntity()?.kind === 'address') {
                  Stack({ alignContent: Alignment.Center }) {
                    MapComponent({
                      mapOptions: this.mapOptions,
                      mapCallback: (err: BusinessError, controller: map.MapComponentController) => {
                        if (!err) {
                          this.mapController = controller;
                          try { controller.setZoomControlsEnabled(false); } catch (e) { }
                          this.applyMapCamera();
                        } else {
                          hilog.error(0x0000, TAG, 'map init err: ' + JSON.stringify(err));
                        }
                      }
                    })
                      .width('100%').height('100%')

                    if (this.geoLoading) {
                      Text('正在定位地址…').fontSize(13).fontColor(Theme.TEXT_SECONDARY)
                    } else if (this.geoFailed) {
                      Text('无法定位该地址,可点下方在地图中打开')
                        .fontSize(13).fontColor(Theme.TEXT_SECONDARY)
                        .padding(8).backgroundColor(Theme.BG_GLASS).borderRadius(Theme.RADIUS_SM)
                    }
                  }
                  .width('100%')
                  .height(200)
                  .margin({ left: 12, right: 12, bottom: 12 })
                  .borderRadius(Theme.RADIUS_MD)
                  .clip(true)
                  .backgroundColor(Theme.BG_CARD)
                } else {
                  Web({ src: this.selectedEntity()!.value, controller: this.urlController })
                    .javaScriptAccess(true)
                    .domStorageAccess(true)
                    .darkMode(WebDarkMode.Off)
                    .width('100%')
                    .height(200)
                    .margin({ left: 12, right: 12, bottom: 12 })
                    .borderRadius(Theme.RADIUS_MD)
                    .clip(true)
                    .backgroundColor(Theme.BG_CARD)
                }
              }
              .width('100%')
            }
            .width('100%')
            .constraintSize({ maxHeight: '68%' })
            .scrollBar(BarState.Auto)
            .edgeEffect(EdgeEffect.Spring)
          } else {
            // 纯文本:保证预览区有足够阅读面积,长文再在卡内滚动
            Scroll() {
              Column() {
                this.selectionPreview()
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
            }
            .width('100%')
            .constraintSize({ maxHeight: '56%' })
            .scrollBar(BarState.Auto)
            .edgeEffect(EdgeEffect.Spring)
          }
        }
        .width('86%')
        .backgroundColor(Theme.BG_CARD)
        .borderRadius(Theme.RADIUS_LG)
        .clip(true)
        .shadow(Theme.SHADOW_FLOAT)
        // 底部滑入：更明显的“sheet 弹出”手感
        .opacity(this.cardIn ? 1.0 : 0.0)
        .translate({ x: 0, y: this.cardIn ? 0 : 120 })
        .scale({ x: this.cardIn ? 1 : 0.985, y: this.cardIn ? 1 : 0.985 })
        .animation({ duration: 260, curve: Curve.EaseInOut })

        // 命中电话/网址/地址时:在 Add to Chat 上方多出一个次级动作按钮
        if (this.selectedEntity() !== null) {
          Button() {
            Row() {
              Image(this.entityIcon(this.selectedEntity()!))
                .width(18)
                .height(18)
                .objectFit(ImageFit.Contain)
                .margin({ right: 8 })
              Text(this.entityLabel(this.selectedEntity()!))
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.BRAND)
            }
          }
          .width('86%')
          .height(46)
          .backgroundColor(Theme.BG_CARD)
          .borderRadius(Theme.RADIUS_LG)
          .margin({ top: 12 })
          .border({ width: 1.5, color: Theme.BRAND })
          .onClick(() => this.doEntityAction())
        }

        Button('Add to Chat')
          .width('86%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_ON_BRAND)
          .backgroundColor(Theme.BRAND)
          .borderRadius(Theme.RADIUS_LG)
          .margin({ top: 12 })
          .shadow(Theme.SHADOW_SOFT)
          .onClick(() => this.doAdd())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  previewTopBar() {
    Row() {
      Row() {
        Image($r('app.media.ic_back_brand'))
          .width(22)
          .height(22)
          .objectFit(ImageFit.Contain)
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => this.pathStack.pop())
      Text(this.currentDoc()?.name ?? '文档')
        .fontSize(17)
        .fontColor(Theme.TEXT_PRIMARY)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row() {
        if (this.currentDoc()?.status === 'parsing') {
          LoadingProgress()
            .width(14)
            .height(14)
            .color(Theme.BRAND)
            .margin({ right: 4 })
        }
        Text(this.currentDoc()?.status === 'parsing'
          ? '解析中'
          : (this.mdVisible ? '收起' : '解析'))
          .fontSize(14)
          .fontColor(this.currentDoc()?.status === 'parsing' ? Theme.TEXT_SECONDARY : Theme.BRAND)
      }
      .padding({ left: 6, right: 6 })
      .onClick(() => this.toggleParseSheet(true))
      Row() {
        Image($r('app.media.ic_more_dark'))
          .width(20)
          .height(20)
          .objectFit(ImageFit.Contain)
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .bindMenu(this.moreMenu())
    }
    .width('100%')
    .padding({ left: 12, right: 8, top: 12, bottom: 8 })
    .backgroundColor(this.previewBg)
    .border({ width: { bottom: 0.5 }, color: Theme.DIVIDER })
  }

  @Builder
  pageIndicatorPill() {
    Row() {
      Image($r('app.media.ic_file_hint'))
        .width(13)
        .height(13)
        .objectFit(ImageFit.Contain)
        .margin({ right: 5 })
      Text(`${this.currentPage + 1} / ${this.currentDoc()!.originalImageUris.length}`)
        .fontSize(13)
        .fontColor(Theme.TEXT_PRIMARY)
        .fontWeight(FontWeight.Medium)
      if (this.isMultiPageDoc()) {
        Text('缩略图')
          .fontSize(11)
          .fontColor(Theme.TEXT_SECONDARY)
          .margin({ left: 6 })
      }
    }
    .padding({ left: 11, right: 11, top: 5, bottom: 5 })
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .border({ width: 2, color: Theme.BRAND })
    .shadow(Theme.SHADOW_SOFT)
    .onClick(() => {
      if (this.isMultiPageDoc() && !this.thumbRailVisible) {
        this.openThumbRail();
      }
    })
  }

  @Builder
  thumbRailOverlay() {
    if (this.isMultiPageDoc() && this.thumbRailVisible) {
      Stack({ alignContent: Alignment.TopStart }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.28)')
          .opacity(this.thumbRailIn ? 1 : 0)
          .animation({ duration: 220, curve: Curve.EaseOut })
          .onClick(() => this.closeThumbRail())

        Column() {
          DocumentThumbRail({
            uris: this.currentDoc()!.originalImageUris,
            aspects: this.imgAspect,
            currentPage: this.currentPage,
            onSelectPage: (idx: number) => this.onThumbPageSelect(idx)
          })
        }
        .width(88)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 8 })
        .translate({ x: this.thumbRailIn ? 0 : -88 })
        .opacity(this.thumbRailIn ? 1 : 0)
        .animation({ duration: 220, curve: Curve.EaseOut })
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Default)
      .zIndex(10)
    }
  }

  @Builder
  documentScrollStack() {
    Stack({ alignContent: Alignment.TopStart }) {
      List({ scroller: this.scroller }) {
        ForEach(this.currentDoc()!.originalImageUris, (uri: string, idx: number) => {
          ListItem() {
            Row() {
              Column() {
                BboxImagePage({
                  filePath: uri,
                  page: this.pageInfo(idx),
                  pageIndex: idx,
                  selectedIdxs: this.selectedPerPage(idx),
                  entityIdxs: this.entityIdxsPerPage(idx),
                  onGeometry: (pi: number, gy: number, w: number, h: number) => { this.pageTopY[pi] = gy; },
                  onTapAt: (gx: number, gy: number) => this.onTapAt(gx, gy),
                  onPressStart: (gx: number, gy: number) => this.onPressStart(gx, gy),
                  onPressMove: (gx: number, gy: number) => this.onPressMove(gx, gy),
                  onPressEnd: () => this.onPressEnd()
                })
                  .width(this.pageContentWidth())
                  .height(this.pageHeight(idx))
              }
              .width(this.pageContentWidth())
              .borderRadius(4)
              .clip(true)
              .border({
                width: this.isMultiPageDoc() ? 1 : 0.5,
                color: this.isMultiPageDoc() ? this.pageFrameBorder : Theme.DIVIDER
              })
              .shadow(Theme.SHADOW_SOFT)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .padding({
            top: this.isMultiPageDoc() ? this.pageGapV / 2 : 0,
            bottom: this.isMultiPageDoc() ? this.pageGapV / 2 : 0
          })
        }, (uri: string, idx: number) => `${this.docId}_${idx}_${this.pages.length}`)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.previewBg)
      .scrollBar(BarState.Off)
      .enableScrollInteraction(!this.pressing && this.currentDoc()!.status !== 'parsing' && !this.thumbRailVisible)
      .onDidScroll(() => {
        const cp: number = this.centerPageFromScroll();
        if (cp !== this.currentPage) {
          this.currentPage = cp;
        }
      })
      .priorityGesture(
        PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 24 })
          .onActionEnd((e: GestureEvent) => {
            if (this.pressing) {
              return;
            }
            if (e.offsetX < -36) {
              if (this.mdVisible) {
                this.mdVisible = false;
              } else {
                this.openSheet(false);
              }
            }
          })
      )

      Column() {
        this.pageIndicatorPill()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 8 })
      .zIndex(2)

      this.thumbRailOverlay()

      if (this.currentDoc()!.status === 'parsing') {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(Theme.BG_MASK)
        Column() {
          ParsingIndicator({
            message: '文档解析中…',
            hint: '完成后可框选内容并加入对话'
          })
        }
        .padding({ left: 24, right: 24, top: 20, bottom: 20 })
        .backgroundColor(Theme.BG_CARD)
        .borderRadius(Theme.RADIUS_LG)
        .shadow(Theme.SHADOW_FLOAT)
      }
    }
    .layoutWeight(1)
    .width('100%')
    .backgroundColor(this.previewBg)
    .onAreaChange((_o: Area, n: Area) => {
      const h: number = n.height as number;
      if (h > 0) {
        this.contentViewportH = h;
      }
    })
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          this.previewTopBar()

          if (this.currentDoc() === undefined) {
            Column() {
              Text('文档不存在').fontSize(15).fontColor(Theme.TEXT_SECONDARY)
            }
            .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
            .backgroundColor(this.previewBg)
          } else {
            this.documentScrollStack()

            Row() {
              Text(this.mdVisible
                ? '上下滚动对照 · 顶栏收起'
                : (this.isMultiPageDoc()
                  ? '点击页码打开缩略图 · 点击原文弹窗 · 长按框选 · 左滑解析'
                  : '点击原文弹窗 · 长按框选 · 左滑本页解析'))
                .fontSize(11)
                .fontColor(Theme.TEXT_HINT)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 6, bottom: 12 })
            .backgroundColor(this.previewBg)
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.previewBg)

        if (this.currentDoc() !== undefined) {
          PageMarkdownSheet({
            visible: this.mdVisible,
            parsedJson: this.currentDoc()!.parsedJson,
            pageIndex: this.currentPage,
            parsing: this.currentDoc()!.status === 'parsing',
            fullDoc: this.mdFullDoc,
            fullMarkdown: this.currentDoc()!.parsedMarkdown,
            totalPages: this.currentDoc()!.originalImageUris.length,
            docName: this.currentDoc()!.name,
            onClose: () => { this.mdVisible = false; },
            onPrevPage: () => { if (this.currentPage > 0) this.currentPage -= 1; },
            onNextPage: () => {
              if (this.currentPage < this.currentDoc()!.originalImageUris.length - 1) this.currentPage += 1;
            }
          })
        }

        // 菜单卡:页面内同层浮层(非模态),外部仅轻微虚化,背后文档仍可见
        if (this.carding) {
          this.optionCard()
        }
      }
      .width('100%')
      .height('100%')
      .opacity(this.pageEnter ? 1 : 0.92)
      .translate({ x: this.pageEnter ? 0 : 12, y: 0 })
      .animation({ duration: 200, curve: Curve.EaseOut })
    }
    .hideTitleBar(true)
    .backgroundColor(this.previewBg)
    .onShown(() => { this.pageEnter = true; })
  }
}
