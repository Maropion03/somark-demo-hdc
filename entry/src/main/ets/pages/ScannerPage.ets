import { DocumentScanner, DocType, FilterId, SaveOption, ShootingMode } from '@kit.VisionKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'SoScan';

/**
 * 扫描页 —— 承载华为 Vision Kit 的 DocumentScanner 控件(拍照 + 自动矫正)。
 * Task 2:跑通扫描,onResult 拿到结果 URI 并打日志。
 * Task 5 会把结果 URI 接到 SoMark API + 持久化。
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
            hilog.info(0x0000, TAG,
              `scan result: code=${code}, saveType=${saveType}, count=${uris.length}, uris=${JSON.stringify(uris)}`);
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
