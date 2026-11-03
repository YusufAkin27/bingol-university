import { describe, expect, it } from 'vitest';
import {
  MAX_IMAGE_BYTES,
  MAX_VIDEO_BYTES,
  flattenAttachments,
  isUploading,
  kindOf,
  readyIds,
  screenFiles,
  type UploadItem,
} from './attachmentLogic';

const file = (name: string, type: string, size = 1000) => new File([new Uint8Array(size)], name, { type });
// File boyutu içeriğe bağlıdır; büyük dosyayı gerçekten üretmeden boyutu taklit et.
const sized = (name: string, type: string, size: number) => {
  const f = file(name, type, 1);
  Object.defineProperty(f, 'size', { value: size });
  return f;
};

describe('kindOf', () => {
  it('MIME ile tanır', () => {
    expect(kindOf(file('a.jpg', 'image/jpeg'))).toBe('IMAGE');
    expect(kindOf(file('a.mov', 'video/quicktime'))).toBe('VIDEO');
    expect(kindOf(file('a.webm', 'video/webm'))).toBe('VIDEO');
  });
  it('MIME boşsa (HEIC gibi) uzantıya bakar', () => {
    expect(kindOf(file('IMG_1.HEIC', ''))).toBe('IMAGE');
    expect(kindOf(file('klip.MP4', ''))).toBe('VIDEO');
  });
  it('desteklenmeyeni reddeder; yanlış MIME uzantıyla kurtarılmaz', () => {
    expect(kindOf(file('a.gif', 'image/gif'))).toBeNull();
    expect(kindOf(file('a.pdf', 'application/pdf'))).toBeNull();
    expect(kindOf(file('a.jpg', 'application/pdf'))).toBeNull();
    expect(kindOf(file('a.svg', 'image/svg+xml'))).toBeNull();
  });
});

describe('screenFiles', () => {
  it('geçerli görsel ve videoyu kabul eder', () => {
    const r = screenFiles([file('a.png', 'image/png'), file('b.mp4', 'video/mp4')], []);
    expect(r.accepted.map((c) => c.kind)).toEqual(['IMAGE', 'VIDEO']);
    expect(r.rejected).toEqual([]);
  });

  it('boyut sınırları: görsel 8 MB, video 50 MB (sınırın kendisi geçerli)', () => {
    const r = screenFiles(
      [
        sized('tam.jpg', 'image/jpeg', MAX_IMAGE_BYTES),
        sized('buyuk.jpg', 'image/jpeg', MAX_IMAGE_BYTES + 1),
        sized('tam.mp4', 'video/mp4', MAX_VIDEO_BYTES),
        sized('buyuk.webm', 'video/webm', MAX_VIDEO_BYTES + 1),
      ],
      [],
    );
    expect(r.accepted.map((c) => c.file.name)).toEqual(['tam.jpg', 'tam.mp4']);
    expect(r.rejected.map((x) => [x.file.name, x.problem])).toEqual([
      ['buyuk.jpg', 'imageTooLarge'],
      ['buyuk.webm', 'videoTooLarge'],
    ]);
  });

  it('türü desteklenmeyen ve boş dosyayı gerekçesiyle reddeder', () => {
    const r = screenFiles([file('a.gif', 'image/gif'), sized('bos.png', 'image/png', 0)], []);
    expect(r.rejected.map((x) => x.problem)).toEqual(['unsupported', 'empty']);
  });

  it('en çok 4 ek: mevcutlar sayılır, fazlası tooMany', () => {
    const five = Array.from({ length: 5 }, (_, i) => file(`${i}.png`, 'image/png'));
    const r = screenFiles(five, []);
    expect(r.accepted).toHaveLength(4);
    expect(r.rejected.map((x) => x.problem)).toEqual(['tooMany']);
    const again = screenFiles([file('x.png', 'image/png')], ['IMAGE', 'IMAGE', 'IMAGE', 'VIDEO']);
    expect(again.accepted).toHaveLength(0);
    expect(again.rejected[0].problem).toBe('tooMany');
  });

  it('en çok 1 video: ikincisi (aynı seçimde ya da sonradan) tooManyVideos', () => {
    const r = screenFiles([file('1.mp4', 'video/mp4'), file('2.mov', 'video/quicktime'), file('3.png', 'image/png')], []);
    expect(r.accepted.map((c) => c.file.name)).toEqual(['1.mp4', '3.png']);
    expect(r.rejected.map((x) => x.problem)).toEqual(['tooManyVideos']);
    expect(screenFiles([file('v.mp4', 'video/mp4')], ['VIDEO']).rejected[0].problem).toBe('tooManyVideos');
  });
});

describe('yükleme listesi yardımcıları', () => {
  const item = (key: string, status: UploadItem['status'], id?: number): UploadItem => ({
    key,
    file: file('a.png', 'image/png'),
    kind: 'IMAGE',
    status,
    progress: status === 'done' ? 1 : 0,
    attachment: id
      ? { id, kind: 'IMAGE', url: '/x', thumbUrl: null, mime: 'image/png', bytes: 1, name: 'a.png', width: null, height: null, durationMs: null }
      : undefined,
  });
  it('readyIds yalnız tamamlananları sırayla verir; isUploading sürenleri bulur', () => {
    const list = [item('a', 'done', 7), item('b', 'uploading'), item('c', 'error'), item('d', 'done', 9)];
    expect(readyIds(list)).toEqual([7, 9]);
    expect(isUploading(list)).toBe(true);
    expect(isUploading([item('a', 'done', 1), item('c', 'error')])).toBe(false);
  });
  it('flattenAttachments mesajlardaki ekleri sırayla düzleştirir (eki olmayanı atlar)', () => {
    const a = { id: 1 } as never;
    const b = { id: 2 } as never;
    expect(flattenAttachments([{ attachments: [a] }, {}, { attachments: [b] }])).toEqual([a, b]);
  });
});
