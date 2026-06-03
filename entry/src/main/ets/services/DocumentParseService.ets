import { hilog } from '@kit.PerformanceAnalysisKit';
import { DocumentRecord } from '../model/Document';
import { DocumentStore } from './DocumentStore';
import { SoMarkApi, ParseResult } from './SoMarkApi';
import { PdfBuilder } from './PdfBuilder';

const TAG: string = 'SoScan';

/**
 * 文档解析服务:
 * - 扫描完成后触发首次解析
 * - 前台页面可定时触发补偿轮询,避免状态卡在 parsing
 */
export class DocumentParseService {
  private static readonly inFlightDocIds: Set<string> = new Set<string>();

  static parseDocument(docId: string, cacheDir: string): void {
    const latest: DocumentRecord | undefined = DocumentStore.getDocument(docId);
    if (latest === undefined) return;
    if (latest.status !== 'parsing') return;
    if (latest.originalImageUris.length === 0) return;
    if (DocumentParseService.inFlightDocIds.has(docId)) return;

    DocumentParseService.inFlightDocIds.add(docId);
    let filePath: string = '';
    let contentType: string = '';
    let remoteFileName: string = '';

    try {
      if (latest.originalImageUris.length === 1) {
        filePath = latest.originalImageUris[0];
        contentType = 'image/jpeg';
        remoteFileName = 'scan.jpg';
      } else {
        filePath = `${cacheDir}/parse_${latest.id}.pdf`;
        PdfBuilder.build(latest.originalImageUris, filePath);
        contentType = 'application/pdf';
        remoteFileName = 'scan.pdf';
      }
    } catch (e) {
      hilog.error(0x0000, TAG, 'parseDocument prepare failed: ' + JSON.stringify(e));
      latest.status = 'failed';
      DocumentStore.updateDocument(latest);
      DocumentParseService.inFlightDocIds.delete(docId);
      return;
    }

    SoMarkApi.parse(filePath, contentType, remoteFileName)
      .then((result: ParseResult) => {
        const cur: DocumentRecord | undefined = DocumentStore.getDocument(docId);
        if (cur === undefined) return;
        cur.parsedMarkdown = result.markdown;
        cur.parsedJson = result.json;
        cur.status = 'done';
        DocumentStore.updateDocument(cur);
      })
      .catch((e: Error) => {
        hilog.error(0x0000, TAG, `parseDocument failed ${docId}: ${e.message}`);
        const cur: DocumentRecord | undefined = DocumentStore.getDocument(docId);
        if (cur !== undefined && cur.status === 'parsing') {
          cur.status = 'failed';
          DocumentStore.updateDocument(cur);
        }
      })
      .finally(() => {
        DocumentParseService.inFlightDocIds.delete(docId);
      });
  }

  /** 轮询补偿:把仍在 parsing 的文档重新触发解析。 */
  static reconcileParsingDocuments(cacheDir: string): void {
    const parsingDocs: DocumentRecord[] = DocumentStore.list()
      .filter((d: DocumentRecord) => d.status === 'parsing' && d.originalImageUris.length > 0);
    for (const d of parsingDocs) {
      DocumentParseService.parseDocument(d.id, cacheDir);
    }
  }
}
