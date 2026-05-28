import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { fileUri } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PdfBuilder } from './PdfBuilder';

const TAG: string = 'SoScan';

/** 把文档原图拼成 PDF 并调系统分享面板。 */
export class ShareHelper {
  static async sharePdf(context: common.UIAbilityContext, docId: string, docName: string,
                        imagePaths: string[]): Promise<void> {
    if (imagePaths.length === 0) {
      throw new Error('无可分享的页面');
    }
    const pdfPath: string = `${context.cacheDir}/share_${docId}.pdf`;
    PdfBuilder.build(imagePaths, pdfPath);
    const uri: string = fileUri.getUriFromPath(pdfPath);
    const record: systemShare.SharedRecord = {
      utd: uniformTypeDescriptor.UniformDataType.PDF,
      uri: uri,
      title: `${docName}.pdf`
    };
    const data: systemShare.SharedData = new systemShare.SharedData(record);
    const controller: systemShare.ShareController = new systemShare.ShareController(data);
    hilog.info(0x0000, TAG, `share pdf: ${pdfPath}`);
    await controller.show(context, {
      previewMode: systemShare.SharePreviewMode.DETAIL,
      selectionMode: systemShare.SelectionMode.SINGLE
    });
  }
}
