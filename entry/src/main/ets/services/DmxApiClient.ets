import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DMX_API_URL, DMX_API_KEY, DMX_MODEL } from './config';

const TAG: string = 'SoScan';

export interface DmxMessage {
  role: string;
  content: string;
}

interface DmxRequestBody {
  model: string;
  messages: DmxMessage[];
  stream: boolean;
}

interface DmxChoice {
  message?: DmxMessage;
  delta?: DmxMessage;
}

interface DmxResp {
  choices?: DmxChoice[];
  error?: object;
}

export interface StreamHandle {
  abort: () => void;
}

/** DMXAPI 兼容 OpenAI 协议的对话客户端 —— 流式 + 非流式两种。 */
export class DmxApiClient {
  /** 非流式调用(用于自动起标题等短任务)。 */
  static async chat(messages: DmxMessage[]): Promise<string> {
    const req = http.createHttp();
    try {
      const body: DmxRequestBody = { model: DMX_MODEL, messages: messages, stream: false };
      const res = await req.request(DMX_API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${DMX_API_KEY}`
        },
        connectTimeout: 15000,
        readTimeout: 120000,
        extraData: JSON.stringify(body)
      });
      if (res.responseCode !== 200) {
        throw new Error(`DMX HTTP ${res.responseCode}`);
      }
      const resp = JSON.parse(res.result as string) as DmxResp;
      const choices: DmxChoice[] = resp.choices ?? [];
      if (choices.length === 0 || choices[0].message === undefined) {
        throw new Error('DMX empty response');
      }
      return choices[0].message!.content ?? '';
    } finally {
      req.destroy();
    }
  }

  /**
   * 流式调用 —— OpenAI SSE 协议:每行以 "data: {json}" 开头, 末尾 "data: [DONE]"。
   * onDelta 在每个 token 到达时调用; onEnd 在结束(成功或失败)调用。
   * 返回 StreamHandle 让调用方能 abort。
   */
  static chatStream(
    messages: DmxMessage[],
    onDelta: (delta: string) => void,
    onEnd: (err: Error | null) => void
  ): StreamHandle {
    const req = http.createHttp();
    let aborted: boolean = false;
    let buffer: string = '';
    const decoder = util.TextDecoder.create('utf-8');

    req.on('headersReceive', (header: Object) => {
      hilog.info(0x0000, TAG, 'DMX stream headers received');
    });

    req.on('dataReceive', (data: ArrayBuffer) => {
      if (aborted) return;
      try {
        const chunk: string = decoder.decodeToString(new Uint8Array(data));
        buffer += chunk;
        // SSE 按 \n\n 分包,但实际多数实现也按 \n 切分有效
        let nlIdx: number = buffer.indexOf('\n');
        while (nlIdx >= 0) {
          const line: string = buffer.substring(0, nlIdx).trim();
          buffer = buffer.substring(nlIdx + 1);
          if (line.length === 0) {
            nlIdx = buffer.indexOf('\n');
            continue;
          }
          if (line.startsWith('data:')) {
            const payload: string = line.substring(5).trim();
            if (payload === '[DONE]') {
              nlIdx = buffer.indexOf('\n');
              continue;
            }
            try {
              const obj = JSON.parse(payload) as DmxResp;
              const choices: DmxChoice[] = obj.choices ?? [];
              if (choices.length > 0 && choices[0].delta !== undefined) {
                const content: string = choices[0].delta!.content ?? '';
                if (content.length > 0) {
                  onDelta(content);
                }
              }
            } catch (e) {
              hilog.warn(0x0000, TAG, 'DMX SSE parse skip: ' + line.substring(0, 80));
            }
          }
          nlIdx = buffer.indexOf('\n');
        }
      } catch (e) {
        hilog.error(0x0000, TAG, 'dataReceive parse failed: ' + JSON.stringify(e));
      }
    });

    req.on('dataEnd', () => {
      if (aborted) return;
      hilog.info(0x0000, TAG, 'DMX stream end');
      onEnd(null);
      req.destroy();
    });

    const body: DmxRequestBody = { model: DMX_MODEL, messages: messages, stream: true };
    req.requestInStream(DMX_API_URL, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${DMX_API_KEY}`,
        'Accept': 'text/event-stream'
      },
      connectTimeout: 15000,
      readTimeout: 180000,
      extraData: JSON.stringify(body)
    }).then((status: number) => {
      hilog.info(0x0000, TAG, `DMX stream status=${status}`);
      if (status !== 200 && !aborted) {
        onEnd(new Error(`DMX HTTP ${status}`));
        req.destroy();
      }
    }).catch((e: Error) => {
      if (!aborted) {
        hilog.error(0x0000, TAG, 'DMX stream failed: ' + e.message);
        onEnd(e);
        req.destroy();
      }
    });

    return {
      abort: () => {
        if (aborted) return;
        aborted = true;
        try { req.destroy(); } catch (e) {}
        onEnd(null);
      }
    };
  }
}
