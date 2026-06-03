import { DocumentScanner, DocType, FilterId, SaveOption, ShootingMode } from '@kit.VisionKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DocumentStore } from '../services/DocumentStore';
import { newDocument, DocumentRecord } from '../model/Document';
import { DocumentParseService } from '../services/DocumentParseService';
import { Theme } from '../common/Theme';

const TAG: string = 'SoScan';

interface ChatPageParam {
  sessionId?: string;
  drawerOpen?: boolean;
}

/**
 * 扫描页 —— 承载华为 Vision Kit 的 DocumentScanner 控件(拍照 + 自动矫正)。
 * 扫描成功后把结果图导入沙箱并存为一个文档。
 */
@Component
export struct ScannerPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State permChecked: boolean = false;
  @State permGranted: boolean = false;
  @State scannerVisible: boolean = true;
  @State pageEnter: boolean = false;

  aboutToAppear(): void {
    this.pageEnter = false;
    this.requestCameraPermission().then((granted: boolean) => {
      this.permGranted = granted;
      this.permChecked = true;
    });
  }

  async requestCameraPermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const perms: Permissions[] = ['ohos.permission.CAMERA'];
      const result = await atManager.requestPermissionsFromUser(context, perms);
      const authResults: number[] = result.authResults;
      const granted: boolean = authResults.length > 0 && authResults[0] === 0;
      hilog.info(0x0000, TAG, 'camera permission granted=' + granted);
      return granted;
    } catch (err) {
      hilog.error(0x0000, TAG, 'requestCameraPermission failed: ' + JSON.stringify(err));
      return false;
    }
  }

  /** 扫描成功:把结果图复制进沙箱,存为新文档,并异步发起解析。 */
  saveScan(uris: string[]): void {
    try {
      const doc: DocumentRecord = newDocument();
      const sandboxPaths: string[] = [];
      for (let i = 0; i < uris.length; i++) {
        sandboxPaths.push(DocumentStore.importImage(uris[i], doc.id, i));
      }
      doc.originalImageUris = sandboxPaths;
      DocumentStore.addDocument(doc);
      hilog.info(0x0000, TAG, `saved doc ${doc.id}, ${sandboxPaths.length} images, start parsing`);
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      DocumentParseService.parseDocument(doc.id, context.cacheDir);
    } catch (e) {
      hilog.error(0x0000, TAG, 'saveScan failed: ' + JSON.stringify(e));
    }
  }

  build() {
    NavDestination() {
      if (!this.permChecked) {
        Column() {
          Text('正在准备相机…')
            .fontSize(15)
            .fontColor(Theme.TEXT_SECONDARY)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Theme.BG_PAGE)
      } else if (this.permGranted) {
        if (this.scannerVisible) {
          DocumentScanner({
            scannerConfig: {
              supportType: [DocType.DOC],
              maxShotCount: 10,
              isGallerySupported: true,
              defaultFilterId: FilterId.STRENGTHEN,
              defaultShootingMode: ShootingMode.MANUAL,
              saveOptions: [SaveOption.JPG],
              isShareable: false
            },
            onResult: (code: number, saveType: SaveOption, uris: string[]) => {
              hilog.info(0x0000, TAG, `scan result: code=${code}, saveType=${saveType}, count=${uris.length}, uris=${JSON.stringify(uris)}`);
              this.scannerVisible = false;
              if (code === 200 && uris.length > 0) {
                this.saveScan(uris);
                // PRD §4: 扫描完成后进入 Chat 并弹出文档抽屉。Scanner 留在栈底,从 Chat 返回会重挂控件。
                const chatParam: ChatPageParam = { drawerOpen: true };
                this.pathStack.pushPath({ name: 'ChatPage', param: chatParam });
              } else {
                hilog.warn(0x0000, TAG, `scan cancelled: code=${code}`);
                // 取消时不能 pop(栈底),延迟一帧重挂控件让相机重新打开
                setTimeout(() => { this.scannerVisible = true; }, 50);
              }
            }
          })
            .width('100%')
            .height('100%')
        } else {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(Theme.BG_PAGE)
        }
      } else {
        Column() {
          Text('需要相机权限才能扫描文档')
            .fontSize(16)
            .fontColor(Theme.TEXT_PRIMARY)
          Text('请在系统设置中允许扫描王中王使用相机')
            .fontSize(13)
            .fontColor(Theme.TEXT_SECONDARY)
            .margin({ top: 8 })
          Button('返回')
            .margin({ top: 24 })
            .backgroundColor(Theme.BRAND)
            .fontColor(Theme.TEXT_ON_BRAND)
            .borderRadius(Theme.RADIUS_LG)
            .shadow(Theme.SHADOW_SOFT)
            .onClick(() => {
              this.pathStack.pop();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Theme.BG_PAGE)
      }
    }
    .hideTitleBar(true)
    .backgroundColor(Theme.BG_PAGE)
    .onShown(() => {
      this.pageEnter = true;
      // 从 ChatPage 返回到栈底 Scanner 时,重新挂载 DocumentScanner 控件
      if (this.permGranted && !this.scannerVisible) {
        this.scannerVisible = true;
      }
    })
    .opacity(this.pageEnter ? 1 : 0.92)
    .translate({ x: this.pageEnter ? 0 : 12, y: 0 })
    .animation({ duration: 200, curve: Curve.EaseOut })
  }
}
