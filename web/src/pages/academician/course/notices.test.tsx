// Duyurular sekmesi: yedi türün alanları, doğrulama, dosya ön kontrolleri, yükleme ilerlemesi/hatası, indirme, silme.
import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { tokensFor } from '../../../auth/tokens';
import { APPROVED_ME, course, err, mockApi, renderAcademician, setAcadTokens } from '../testUtils';
import { ALLOWED_EXTENSIONS, MAX_FILES, MAX_FILE_BYTES, NOTICE_SPECS, checkFile, validateNotice } from './noticeRules';

type XhrBehavior = (xhr: FakeXhr) => void;
let behaviors: XhrBehavior[] = [];
const uploads: FakeXhr[] = [];

class FakeXhr {
  upload: { onprogress: ((e: { lengthComputable: boolean; loaded: number; total: number }) => void) | null } = { onprogress: null };
  onload: (() => void) | null = null;
  onerror: (() => void) | null = null;
  onabort: (() => void) | null = null;
  status = 0;
  responseText = '';
  url = '';
  file: File | null = null;
  headers: Record<string, string> = {};
  open(_m: string, url: string) {
    this.url = url;
  }
  setRequestHeader(k: string, v: string) {
    this.headers[k] = v;
  }
  getResponseHeader() {
    return null;
  }
  abort() {
    this.onabort?.();
  }
  send(form: FormData) {
    this.file = form.get('file') as File;
    uploads.push(this);
    (behaviors.shift() ?? ((x) => x.finish(201, { id: 900 + uploads.length, name: this.file!.name, contentType: 'application/pdf', sizeBytes: this.file!.size })))(this);
  }
  finish(status: number, body: unknown) {
    this.status = status;
    this.responseText = JSON.stringify(body);
    this.onload?.();
  }
}

beforeEach(() => {
  behaviors = [];
  uploads.length = 0;
  vi.stubGlobal('XMLHttpRequest', FakeXhr);
});
afterEach(() => {
  vi.unstubAllGlobals();
  tokensFor('acad').clearTokens();
});

const pdf = (name = 'odev.pdf', size = 1000) => {
  const f = new File(['x'], name, { type: 'application/pdf' });
  Object.defineProperty(f, 'size', { value: size });
  return f;
};

function open(extra: (api: ReturnType<typeof mockApi>) => void = () => undefined) {
  setAcadTokens();
  const api = mockApi()
    .get('/academician/me', APPROVED_ME)
    .get('/academician/courses/7', course())
    .get('/academician/courses/7/notices', { items: [], nextCursor: null })
    .post('/academician/courses/7/notices', { id: 1 });
  extra(api);
  api.install();
  renderAcademician('/akademisyen/dersler/7?sekme=duyurular');
  return api;
}
const typeSelect = () => screen.findByLabelText('Duyuru türü');

describe('noticeRules', () => {
  it('izin listesi sunucuyla aynı; makro/html/svg/arşiv yok', () => {
    expect([...ALLOWED_EXTENSIONS]).toEqual(['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'png', 'jpg', 'jpeg']);
    for (const bad of ['a.docm', 'a.xlsm', 'a.pptm', 'a.exe', 'a.html', 'a.svg', 'a.zip', 'a.js', 'evil']) expect(checkFile({ name: bad, size: 10 }, 0)).toBe('type');
  });
  it('boyut ve sayı sınırı', () => {
    expect(checkFile({ name: 'a.pdf', size: MAX_FILE_BYTES }, 0)).toBeNull();
    expect(checkFile({ name: 'a.pdf', size: MAX_FILE_BYTES + 1 }, 0)).toBe('size');
    expect(checkFile({ name: 'a.PDF', size: 5 }, MAX_FILES - 1)).toBeNull();
    expect(checkFile({ name: 'a.pdf', size: 5 }, MAX_FILES)).toBe('limit');
  });
  it('türlere göre zorunlu alanlar', () => {
    expect(validateNotice('LESSON_STARTED', { title: '', note: '', eventAt: '' })).toEqual([]);
    expect(validateNotice('EXAM', { title: '', note: '', eventAt: '' })).toEqual(['title', 'eventAt']);
    expect(validateNotice('ASSIGNMENT', { title: 'x', note: 'n'.repeat(1001), eventAt: '2026-11-20T10:00' })).toEqual(['note']);
    expect(validateNotice('MATERIAL', { title: 'x', note: '', eventAt: '' })).toEqual([]);
    expect(validateNotice('LESSON_CANCELLED', { title: '', note: '', eventAt: '' })).toEqual(['eventAt']);
    expect(validateNotice('ROOM_CHANGED', { title: '', note: '', eventAt: '' })).toEqual(['title']);
  });
});

describe('her duyuru türü yalnız kendi alanlarını gösterir', () => {
  const cases: [string, { title: boolean; event: boolean; note: boolean; files: boolean }][] = [
    ['LESSON_STARTED', { title: false, event: false, note: false, files: false }],
    ['ATTENDANCE_STARTED', { title: false, event: false, note: false, files: false }],
    ['EXAM', { title: true, event: true, note: true, files: true }],
    ['ASSIGNMENT', { title: true, event: true, note: true, files: true }],
    ['MATERIAL', { title: true, event: false, note: true, files: true }],
    ['LESSON_CANCELLED', { title: false, event: true, note: true, files: false }],
    ['ROOM_CHANGED', { title: true, event: true, note: true, files: false }],
  ];
  it('alan tablosu sunucu kuralıyla tutarlı', () => {
    for (const [t, c] of cases) {
      const s = NOTICE_SPECS[t as keyof typeof NOTICE_SPECS];
      expect({ title: !!s.title, event: s.event !== 'none', note: !!s.note, files: s.files }).toEqual(c);
    }
  });
  it.each(cases)('%s', async (type, want) => {
    open();
    const user = userEvent.setup();
    await user.selectOptions(await typeSelect(), type);
    const has = (re: RegExp) => screen.queryAllByLabelText(re).length > 0;
    expect(has(/^(Başlık|Yeni derslik)/)).toBe(want.title);
    expect(has(/(Sınav zamanı|Son teslim zamanı|İptal edilen ders|Geçerli olduğu ders)/)).toBe(want.event);
    expect(has(/^Not \(isteğe bağlı\)/)).toBe(want.note);
    expect(screen.queryByText('Dosyaları buraya sürükleyin ya da seçin') !== null).toBe(want.files);
  });
});

describe('gönderme', () => {
  it('zorunlu alan eksikse göndermez; doldurunca gövdeyi doğru gönderir', async () => {
    const api = open();
    const user = userEvent.setup();
    await user.selectOptions(await typeSelect(), 'EXAM');
    await user.click(screen.getByRole('button', { name: 'Duyuruyu gönder' }));
    expect(screen.getAllByText('Bu alan zorunlu.').length).toBe(2);
    expect(api.callsTo('POST', '/academician/courses/7/notices')).toHaveLength(0);
    await user.type(screen.getByLabelText(/^Başlık/), 'Vize');
    fireEvent.change(screen.getByLabelText(/Sınav zamanı/), { target: { value: '2026-12-01T10:30' } });
    await user.click(screen.getByRole('button', { name: 'Duyuruyu gönder' }));
    await waitFor(() => expect(api.callsTo('POST', '/academician/courses/7/notices')).toHaveLength(1));
    const body = api.callsTo('POST', '/academician/courses/7/notices')[0].body as Record<string, unknown>;
    expect(body).toMatchObject({ type: 'EXAM', title: 'Vize' });
    expect(typeof body.eventAt).toBe('string');
    expect(body).not.toHaveProperty('note');
  });

  it('alan gerektirmeyen tür yalnız type gönderir; NOTICE_TOO_FREQUENT özel mesaj verir ve form korunur', async () => {
    const api = open((a) => a.post('/academician/courses/7/notices', () => err(429, 'NOTICE_TOO_FREQUENT')));
    const user = userEvent.setup();
    await user.selectOptions(await typeSelect(), 'LESSON_STARTED');
    await user.click(screen.getByRole('button', { name: 'Duyuruyu gönder' }));
    expect(await screen.findByRole('alert')).toHaveTextContent(/en çok 10 dakikada bir/);
    expect(api.callsTo('POST', '/academician/courses/7/notices')[0].body).toEqual({ type: 'LESSON_STARTED' });
  });
});

describe('dosyalar', () => {
  async function pick(files: File[]) {
    const input = (await screen.findAllByLabelText('Dosya seç')).find((e) => e.tagName === 'INPUT')!;
    fireEvent.change(input, { target: { files } });
  }

  it('kötü uzantı ve 20 MB üstü yüklenmeden dosya başına hatayla reddedilir', async () => {
    open();
    await userEvent.setup().selectOptions(await typeSelect(), 'ASSIGNMENT');
    await pick([pdf('makro.docm'), pdf('dev.pdf', MAX_FILE_BYTES + 1)]);
    expect(await screen.findByText(/Bu dosya türü kabul edilmiyor/)).toBeInTheDocument();
    expect(screen.getByText(/20 MB sınırını aşıyor/)).toBeInTheDocument();
    expect(uploads).toHaveLength(0);
  });

  it('6. dosya reddedilir (en çok 5)', async () => {
    behaviors = Array.from({ length: 5 }, () => (x) => x.finish(201, { id: 1, name: 'a.pdf', contentType: 'application/pdf', sizeBytes: 1 }));
    open();
    await userEvent.setup().selectOptions(await typeSelect(), 'MATERIAL');
    await pick([1, 2, 3, 4, 5, 6].map((i) => pdf(`d${i}.pdf`)));
    await screen.findByText(/En çok 5 dosya eklenebilir/);
    expect(uploads).toHaveLength(5);
  });

  it('yükleme ilerlemesi gösterilir, bitince dosya kimliği duyuruya fileIds olarak bağlanır', async () => {
    let hold: FakeXhr | null = null;
    behaviors = [(x) => (hold = x)];
    const api = open();
    const user = userEvent.setup();
    await user.selectOptions(await typeSelect(), 'ASSIGNMENT');
    await user.type(screen.getByLabelText(/^Başlık/), 'Ödev 1');
    fireEvent.change(screen.getByLabelText(/Son teslim zamanı/), { target: { value: '2026-12-01T10:30' } });
    await pick([pdf('odev.pdf')]);
    await waitFor(() => expect(hold).not.toBeNull());
    expect(hold!.url).toContain('/academician/courses/7/notice-files');
    expect(hold!.headers.Authorization).toBe('Bearer acad-access');
    hold!.upload.onprogress?.({ lengthComputable: true, loaded: 50, total: 100 });
    expect(await screen.findByRole('progressbar', { name: 'odev.pdf yükleniyor' })).toBeInTheDocument();
    // yükleme bitmeden gönderilemez
    await user.click(screen.getByRole('button', { name: 'Duyuruyu gönder' }));
    expect(await screen.findByText(/yüklenmesi bitmeden/)).toBeInTheDocument();
    hold!.finish(201, { id: 555, name: 'odev.pdf', contentType: 'application/pdf', sizeBytes: 1000 });
    await screen.findByText('Yüklendi');
    await user.click(screen.getByRole('button', { name: 'Duyuruyu gönder' }));
    await waitFor(() => expect(api.callsTo('POST', '/academician/courses/7/notices')).toHaveLength(1));
    expect((api.callsTo('POST', '/academician/courses/7/notices')[0].body as { fileIds: number[] }).fileIds).toEqual([555]);
  });

  it('sunucu NOTICE_FILE_TYPE_NOT_ALLOWED derse dosya başına özel hata + yeniden dene; gönderimi engeller', async () => {
    behaviors = [(x) => x.finish(422, { code: 'NOTICE_FILE_TYPE_NOT_ALLOWED', message: 'x' })];
    const api = open();
    const user = userEvent.setup();
    await user.selectOptions(await typeSelect(), 'MATERIAL');
    await user.type(screen.getByLabelText(/^Başlık/), 'Slaytlar');
    await pick([pdf('sahte.pdf')]);
    expect(await screen.findByText(/içeriği uzantısıyla uyuşmuyor/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Duyuruyu gönder' }));
    expect(await screen.findByText(/Yüklenemeyen dosyalar var/)).toBeInTheDocument();
    expect(api.callsTo('POST', '/academician/courses/7/notices')).toHaveLength(0);
    await user.click(screen.getByRole('button', { name: 'Tekrar dene' }));
    await screen.findByText('Yüklendi');
  });

  it('listeden kaldırılan yüklenmiş dosya sunucuda da silinir', async () => {
    const api = open((a) => a.del('/academician/notice-files/:id', undefined));
    await userEvent.setup().selectOptions(await typeSelect(), 'MATERIAL');
    await pick([pdf('a.pdf')]);
    await screen.findByText('Yüklendi');
    await userEvent.setup().click(screen.getByRole('button', { name: 'a.pdf dosyasını kaldır' }));
    await waitFor(() => expect(api.callsTo('DELETE', '/academician/notice-files/901')).toHaveLength(1));
  });
});

describe('liste: indirme ve silme', () => {
  const notice = { id: 31, type: 'ASSIGNMENT', title: 'Ödev 2', note: 'Not metni', eventAt: '2026-12-01T10:00:00Z', createdAt: '2026-11-14T08:00:00Z', files: [{ id: 8, name: 'soru.pdf', contentType: 'application/pdf', sizeBytes: 2048 }] };

  it('ekler listelenir ve indirme kimlik doğrulamalı uçtan yapılır', async () => {
    const names: string[] = [];
    URL.createObjectURL = vi.fn(() => 'blob:x');
    URL.revokeObjectURL = vi.fn();
    vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (this: HTMLAnchorElement) {
      names.push(this.download);
    });
    const api = open((a) =>
      a.get('/academician/courses/7/notices', { items: [notice], nextCursor: null }).get('/academician/notices/31/files/8', () => new Response('PDF', { status: 200, headers: { 'Content-Type': 'application/pdf' } })),
    );
    await userEvent.setup().click(await screen.findByRole('button', { name: 'soru.pdf dosyasını indir' }));
    await waitFor(() => expect(names).toEqual(['soru.pdf']));
    expect(api.callsTo('GET', '/academician/notices/31/files/8')[0].headers.Authorization).toBe('Bearer acad-access');
  });

  it('silme onay ister, sonra DELETE gönderir', async () => {
    const api = open((a) => a.get('/academician/courses/7/notices', { items: [notice], nextCursor: null }).del('/academician/notices/31', undefined));
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Ödev 2 duyurusunu sil' }));
    const dlg = await screen.findByRole('alertdialog');
    expect(api.callsTo('DELETE', '/academician/notices/31')).toHaveLength(0);
    await user.click(within(dlg).getByRole('button', { name: 'Sil' }));
    await waitFor(() => expect(api.callsTo('DELETE', '/academician/notices/31')).toHaveLength(1));
  });

  it('boş durum açıklayıcıdır', async () => {
    open();
    expect(await screen.findByText('Henüz duyuru yok')).toBeInTheDocument();
  });
});
