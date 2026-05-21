import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { pdfService } from '@kit.PDFKit';

const TAG: string = 'SoScan';

/**
 * 图片合成 PDF —— 把多张扫描图按顺序拼成一个多页 PDF。
 * 仅用于给 SoMark API 提供「整篇文档」载荷(API 有跨页处理逻辑);
 * 生成的 PDF 是临时文件,不入库、不展示,用户看到的「原图」仍是原始 JPG。
 */
export class PdfBuilder {
  /**
   * 把 imagePaths 顺序合成一个多页 PDF,写到 outputPath。
   * 每页尺寸 = 对应图片像素尺寸(铺满、不拉伸)。失败抛错。
   */
  static build(imagePaths: string[], outputPath: string): void {
    if (imagePaths.length === 0) {
      throw new Error('PdfBuilder: imagePaths is empty');
    }
    const doc: pdfService.PdfDocument = new pdfService.PdfDocument();
    try {
      for (let i = 0; i < imagePaths.length; i++) {
        const path: string = imagePaths[i];
        const size: image.Size = PdfBuilder.imageSize(path);
        hilog.info(0x0000, TAG, `PdfBuilder page ${i}: ${size.width}x${size.height}`);
        let page: pdfService.PdfPage;
        if (i === 0) {
          // createDocument 是否自带首页未明确,以 getPageCount 为准。
          if (!doc.createDocument(size.width, size.height)) {
            throw new Error('PdfBuilder: createDocument failed');
          }
          page = doc.getPageCount() >= 1
            ? doc.getPage(0)
            : doc.insertBlankPage(0, size.width, size.height);
        } else {
          page = doc.insertBlankPage(i, size.width, size.height);
        }
        // PDF 坐标原点在左下角;(0,0) + 整页尺寸 = 图片铺满该页。
        page.addImageObject(path, 0, 0, size.width, size.height);
      }
      if (!doc.saveDocument(outputPath)) {
        throw new Error('PdfBuilder: saveDocument failed');
      }
      hilog.info(0x0000, TAG, `PdfBuilder: ${imagePaths.length} 页 -> ${outputPath}`);
    } catch (e) {
      hilog.error(0x0000, TAG, 'PdfBuilder.build failed: ' + JSON.stringify(e));
      throw e as Error;
    } finally {
      doc.releaseDocument();
    }
  }

  /** 读取图片像素尺寸。 */
  private static imageSize(path: string): image.Size {
    const src: image.ImageSource = image.createImageSource(path);
    const info: image.ImageInfo = src.getImageInfoSync();
    return info.size;
  }
}
