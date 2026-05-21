import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SOMARK_API_KEY } from './config';

const TAG: string = 'SoScan';
const API_URL: string = 'https://somark.tech/api/v1/parse/sync';

/** SoMark 解析结果。 */
export interface ParseResult {
  markdown: string;   // Markdown 全文
  json: string;       // 结构化 JSON 原文(逐页 blocks)
}

interface ParseOutputs {
  markdown?: string;
  json?: object;
}
interface ParseResultData {
  outputs?: ParseOutputs;
}
interface ParseRespData {
  result?: ParseResultData;
  error?: string;
}
interface ParseResp {
  code?: number;
  message?: string;
  data?: ParseRespData;
}

/**
 * SoMark 文档解析 API 客户端。
 * POST multipart/form-data 到 /parse/sync,返回 Markdown + 结构化 JSON。
 */
export class SoMarkApi {
  /** 上传文件(JPG/PDF)解析,返回 { markdown, json }。失败抛错。 */
  static async parse(filePath: string, contentType: string, remoteFileName: string): Promise<ParseResult> {
    const req = http.createHttp();
    try {
      const res = await req.request(API_URL, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'multipart/form-data' },
        connectTimeout: 15000,
        readTimeout: 120000,   // 同步解析可能耗时数十秒
        multiFormDataList: [
          {
            name: 'file',
            contentType: contentType,
            remoteFileName: remoteFileName,
            filePath: filePath
          },
          {
            name: 'api_key',
            contentType: 'text/plain',
            data: SOMARK_API_KEY
          },
          {
            name: 'element_formats',
            contentType: 'text/plain',
            data: '{"table":"markdown"}'
          }
        ]
      });
      hilog.info(0x0000, TAG, `SoMark API responseCode=${res.responseCode}`);
      if (res.responseCode !== 200) {
        throw new Error(`SoMark API HTTP ${res.responseCode}`);
      }
      const resp = JSON.parse(res.result as string) as ParseResp;
      if (resp.code !== 0) {
        throw new Error(`SoMark API code=${resp.code}: ${resp.message ?? ''}`);
      }
      const outputs: ParseOutputs | undefined = resp.data?.result?.outputs;
      const markdown: string = outputs?.markdown ?? '';
      const jsonObj: object | undefined = outputs?.json;
      const result: ParseResult = {
        markdown: markdown,
        json: jsonObj !== undefined ? JSON.stringify(jsonObj) : ''
      };
      hilog.info(0x0000, TAG, `SoMark parse OK: markdown ${markdown.length} 字`);
      return result;
    } catch (e) {
      hilog.error(0x0000, TAG, 'SoMarkApi.parse failed: ' + JSON.stringify(e));
      throw e as Error;
    } finally {
      req.destroy();
    }
  }
}
