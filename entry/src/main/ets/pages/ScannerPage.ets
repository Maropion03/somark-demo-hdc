import { DocumentScanner, DocType, FilterId, SaveOption, ShootingMode } from '@kit.VisionKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DocumentStore } from '../services/DocumentStore';
import { newDocument, DocumentRecord } from '../model/Document';

const TAG: string = 'SoScan';

/**
 * 扫描页 —— 承载华为 Vision Kit 的 DocumentScanner 控件(拍照 + 自动矫正)。
 * 扫描成功后把结果图导入沙箱并存为一个文档。
 */
@Component
export struct ScannerPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State permChecked: boolean = false;
  @State permGranted: boolean = false;

  aboutToAppear(): void {
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

  /** 扫描成功:把结果图复制进沙箱,存为一个新文档。 */
  saveScan(uris: string[]): void {
    try {
      const doc: DocumentRecord = newDocument();
      const sandboxPaths: string[] = [];
      for (let i = 0; i < uris.length; i++) {
        sandboxPaths.push(DocumentStore.importImage(uris[i], doc.id, i));
      }
      doc.originalImageUris = sandboxPaths;
      DocumentStore.addDocument(doc);
      hilog.info(0x0000, TAG, `saved doc ${doc.id} with ${sandboxPaths.length} images`);
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
            .fontColor('rgba(255,255,255,0.7)')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.permGranted) {
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
            if (code === 200 && uris.length > 0) {
              this.saveScan(uris);
            } else {
              hilog.warn(0x0000, TAG, `scan NOT saved: code=${code}, uris count=${uris.length}`);
            }
            this.pathStack.pop();
          }
        })
          .width('100%')
          .height('100%')
      } else {
        Column() {
          Text('需要相机权限才能扫描文档')
            .fontSize(16)
            .fontColor('#FFFFFF')
          Text('请在系统设置中允许 SoScan 使用相机')
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
    }
    .hideTitleBar(true)
    .backgroundColor('#000000')
  }
}
