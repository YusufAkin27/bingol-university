// uploadForm: XMLHttpRequest ile multipart yükleme (ilerleme, hata gövdesi, 401'de tek refresh ile yeniden deneme, iptal).
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { clearTokens, setTokens } from '../auth/tokens';
import { ApiError, setRefreshRetryDelays, uploadForm } from './client';
import { jsonResponse, mockFetch } from '../test/fetchMock';

class FakeXHR {
  static all: FakeXHR[] = [];
  upload: { onprogress: ((e: { lengthComputable: boolean; loaded: number; total: number }) => void) | null } = { onprogress: null };
  onload: (() => void) | null = null;
  onerror: (() => void) | null = null;
  onabort: (() => void) | null = null;
  status = 0;
  responseText = '';
  headers: Record<string, string> = {};
  url = '';
  aborted = false;
  constructor() {
    FakeXHR.all.push(this);
  }
  open(_m: string, url: string) {
    this.url = url;
  }
  setRequestHeader(k: string, v: string) {
    this.headers[k] = v;
  }
  getResponseHeader() {
    return null;
  }
  send() {}
  abort() {
    this.aborted = true;
    this.onabort?.();
  }
  respond(status: number, body?: unknown) {
    this.status = status;
    this.responseText = body === undefined ? '' : JSON.stringify(body);
    this.onload?.();
  }
}

const form = () => {
  const f = new FormData();
  f.append('file', new File(['x'], 'a.png', { type: 'image/png' }));
  return f;
};
const tick = () => new Promise((r) => setTimeout(r, 0));

beforeEach(() => {
  FakeXHR.all = [];
  vi.stubGlobal('XMLHttpRequest', FakeXHR);
  setRefreshRetryDelays([0, 0]);
  setTokens('a1', 'r1');
});
afterEach(() => {
  vi.unstubAllGlobals();
  clearTokens();
});

describe('uploadForm', () => {
  it('Bearer ile gönderir, ilerlemeyi 0..1 olarak bildirir, JSON gövdeyi döner', async () => {
    const seen: number[] = [];
    const p = uploadForm<{ id: number }>('/admin/support/attachments', form(), { onProgress: (f) => seen.push(f) });
    const x = FakeXHR.all[0];
    expect(x.url).toBe('/api/admin/support/attachments');
    expect(x.headers.Authorization).toBe('Bearer a1');
    x.upload.onprogress?.({ lengthComputable: true, loaded: 25, total: 100 });
    x.upload.onprogress?.({ lengthComputable: false, loaded: 0, total: 0 });
    x.respond(201, { id: 5 });
    await expect(p).resolves.toEqual({ id: 5 });
    expect(seen).toEqual([0.25]);
  });

  it('hata gövdesindeki kodu ApiError olarak fırlatır', async () => {
    const p = uploadForm('/x', form());
    FakeXHR.all[0].respond(413, { code: 'ATTACHMENT_TOO_LARGE', message: 'çok büyük' });
    await expect(p).rejects.toMatchObject({ status: 413, code: 'ATTACHMENT_TOO_LARGE' });
    await p.catch((e) => expect(e).toBeInstanceOf(ApiError));
  });

  it('401 olunca tek refresh yapar ve yeni jetonla yeniden dener', async () => {
    mockFetch((url) =>
      url.endsWith('/auth/refresh')
        ? jsonResponse(200, { accessToken: 'a2', refreshToken: 'r2', tokenType: 'Bearer', expiresIn: 900 })
        : jsonResponse(404, { code: 'NOT_FOUND', message: 'x' }),
    );
    const p = uploadForm<{ id: number }>('/x', form());
    FakeXHR.all[0].respond(401, { code: 'UNAUTHORIZED', message: 'x' });
    await vi.waitFor(() => expect(FakeXHR.all).toHaveLength(2));
    expect(FakeXHR.all[1].headers.Authorization).toBe('Bearer a2');
    FakeXHR.all[1].respond(201, { id: 9 });
    await expect(p).resolves.toEqual({ id: 9 });
  });

  it('ağ hatası NETWORK_ERROR; iptal AbortError verir', async () => {
    const a = uploadForm('/x', form());
    FakeXHR.all[0].onerror?.();
    await expect(a).rejects.toMatchObject({ status: 0, code: 'NETWORK_ERROR' });

    const ctl = new AbortController();
    const b = uploadForm('/x', form(), { signal: ctl.signal });
    ctl.abort();
    await tick();
    await expect(b).rejects.toMatchObject({ name: 'AbortError' });
    expect(FakeXHR.all[1].aborted).toBe(true);
  });
});
