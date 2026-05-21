import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DocumentRecord } from '../model/Document';

const TAG: string = 'SoScan';
const INDEX_FILE: string = 'index.json';
const IMAGES_DIR: string = 'doc_images';

/**
 * 文档持久化 —— 沙箱 index.json 存元数据,doc_images/ 存扫描原图。
 * 文档列表同步到 AppStorage('documents'),页面用 @StorageLink 响应式读取。
 */
export class DocumentStore {
  private static filesDir: string = '';

  /** 应用启动时调用一次:建目录、读索引、灌入 AppStorage。 */
  static init(context: common.Context): void {
    DocumentStore.filesDir = context.filesDir;
    const imgDir: string = `${DocumentStore.filesDir}/${IMAGES_DIR}`;
    try {
      if (!fs.accessSync(imgDir)) {
        fs.mkdirSync(imgDir);
      }
      hilog.info(0x0000, TAG, `images dir ready: ${imgDir}`);
    } catch (e) {
      hilog.error(0x0000, TAG, 'images dir setup failed: ' + JSON.stringify(e));
    }
    const list: DocumentRecord[] = DocumentStore.readIndex();
    AppStorage.setOrCreate<DocumentRecord[]>('documents', list);
    hilog.info(0x0000, TAG, `DocumentStore init: filesDir=${DocumentStore.filesDir}, ${list.length} docs`);
  }

  /** 当前文档列表(从 AppStorage)。 */
  static list(): DocumentRecord[] {
    const arr: DocumentRecord[] | undefined = AppStorage.get<DocumentRecord[]>('documents');
    return arr ?? [];
  }

  /** 按 id 取文档。 */
  static getDocument(id: string): DocumentRecord | undefined {
    return DocumentStore.list().find((d: DocumentRecord) => d.id === id);
  }

  /** 新增文档:写索引 + 更新 AppStorage(新文档置顶)。 */
  static addDocument(doc: DocumentRecord): void {
    const list: DocumentRecord[] = [doc, ...DocumentStore.list()];
    DocumentStore.writeIndex(list);
    AppStorage.setOrCreate<DocumentRecord[]>('documents', list);
    hilog.info(0x0000, TAG, `addDocument ${doc.id}, total ${list.length}`);
  }

  /** 把扫描结果文件复制进沙箱,返回沙箱内路径。复制失败抛错。 */
  static importImage(srcUri: string, docId: string, index: number): string {
    const dest: string = `${DocumentStore.filesDir}/${IMAGES_DIR}/${docId}_${index}.jpg`;
    hilog.info(0x0000, TAG, `importImage: src=${srcUri} dest=${dest}`);
    // DocumentScanner 返回的是跨应用 file:// URI(文件在华为 HiAI 的沙箱里),
    // 不能当普通路径直接 copyFileSync —— 必须 openSync 打开 URI(走授权)再读写。
    try {
      const srcFile = fs.openSync(srcUri, fs.OpenMode.READ_ONLY);
      const size: number = fs.statSync(srcFile.fd).size;
      const buf: ArrayBuffer = new ArrayBuffer(size);
      fs.readSync(srcFile.fd, buf);
      fs.closeSync(srcFile);
      const destFile = fs.openSync(dest, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(destFile.fd, buf);
      fs.closeSync(destFile);
    } catch (e) {
      hilog.error(0x0000, TAG, 'importImage failed: ' + JSON.stringify(e));
      throw new Error('importImage failed');
    }
    return dest;
  }

  private static readIndex(): DocumentRecord[] {
    const path: string = `${DocumentStore.filesDir}/${INDEX_FILE}`;
    try {
      if (!fs.accessSync(path)) {
        return [];
      }
      const stat = fs.statSync(path);
      if (stat.size === 0) {
        return [];
      }
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const buf: ArrayBuffer = new ArrayBuffer(stat.size);
      const len: number = fs.readSync(file.fd, buf);
      fs.closeSync(file);
      const text: string = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf.slice(0, len)));
      return JSON.parse(text) as DocumentRecord[];
    } catch (e) {
      hilog.error(0x0000, TAG, 'readIndex failed: ' + JSON.stringify(e));
      return [];
    }
  }

  private static writeIndex(list: DocumentRecord[]): void {
    const path: string = `${DocumentStore.filesDir}/${INDEX_FILE}`;
    try {
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, JSON.stringify(list));
      fs.closeSync(file);
    } catch (e) {
      hilog.error(0x0000, TAG, 'writeIndex failed: ' + JSON.stringify(e));
      throw new Error('writeIndex failed');
    }
  }
}
