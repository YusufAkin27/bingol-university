// Destek eki istemci tarafı ön kontrolü (Sözleşme B). Sunucu gerçek içeriği (magic bytes) yine doğrular;
// buradaki amaç gereksiz yüklemeyi önlemek ve açıklayıcı hata vermektir.
import type { AttachmentView } from '../../../api/types';

export const MAX_ATTACHMENTS = 4;
export const MAX_VIDEOS = 1;
export const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
export const MAX_VIDEO_BYTES = 50 * 1024 * 1024;

const IMAGE_MIME = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']);
const VIDEO_MIME = new Set(['video/mp4', 'video/quicktime', 'video/webm']);
const IMAGE_EXT = new Set(['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif']);
const VIDEO_EXT = new Set(['mp4', 'mov', 'webm']);

/** Dosya seçici/sürükle-bırak için kabul listesi. */
export const ACCEPT = '.jpg,.jpeg,.png,.webp,.heic,.heif,.mp4,.mov,.webm,image/jpeg,image/png,image/webp,image/heic,video/mp4,video/quicktime,video/webm';

export type AttachmentKind = 'IMAGE' | 'VIDEO';

export type AttachmentProblem = 'unsupported' | 'empty' | 'imageTooLarge' | 'videoTooLarge' | 'tooMany' | 'tooManyVideos';

function extOf(name: string): string {
  const i = name.lastIndexOf('.');
  return i < 0 ? '' : name.slice(i + 1).toLowerCase();
}

/** Tür: MIME önceliklidir; HEIC gibi tarayıcının MIME vermediği dosyalarda uzantıya bakılır. */
export function kindOf(file: Pick<File, 'name' | 'type'>): AttachmentKind | null {
  const mime = (file.type || '').toLowerCase();
  if (IMAGE_MIME.has(mime)) return 'IMAGE';
  if (VIDEO_MIME.has(mime)) return 'VIDEO';
  if (mime === '' || mime === 'application/octet-stream') {
    const ext = extOf(file.name);
    if (IMAGE_EXT.has(ext)) return 'IMAGE';
    if (VIDEO_EXT.has(ext)) return 'VIDEO';
  }
  return null;
}

export interface Candidate {
  file: File;
  kind: AttachmentKind;
}
export interface Rejected {
  file: File;
  problem: AttachmentProblem;
}

/**
 * Seçilen dosyaları sırayla denetler. `existing`: şu an listede olan (yüklenen/yüklenmekte) dosyaların türleri.
 * Tek dosya hataları listeyi bozmaz; kabul edilenler yüklenir, reddedilenler gerekçesiyle döner.
 */
export function screenFiles(
  incoming: File[],
  existing: AttachmentKind[],
): { accepted: Candidate[]; rejected: Rejected[] } {
  const accepted: Candidate[] = [];
  const rejected: Rejected[] = [];
  let count = existing.length;
  let videos = existing.filter((k) => k === 'VIDEO').length;
  for (const file of incoming) {
    const kind = kindOf(file);
    if (!kind) rejected.push({ file, problem: 'unsupported' });
    else if (file.size <= 0) rejected.push({ file, problem: 'empty' });
    else if (kind === 'IMAGE' && file.size > MAX_IMAGE_BYTES) rejected.push({ file, problem: 'imageTooLarge' });
    else if (kind === 'VIDEO' && file.size > MAX_VIDEO_BYTES) rejected.push({ file, problem: 'videoTooLarge' });
    else if (count >= MAX_ATTACHMENTS) rejected.push({ file, problem: 'tooMany' });
    else if (kind === 'VIDEO' && videos >= MAX_VIDEOS) rejected.push({ file, problem: 'tooManyVideos' });
    else {
      accepted.push({ file, kind });
      count += 1;
      if (kind === 'VIDEO') videos += 1;
    }
  }
  return { accepted, rejected };
}

/** Yükleme listesindeki öğe (kompozer durumu). */
export interface UploadItem {
  key: string;
  file: File;
  kind: AttachmentKind;
  status: 'uploading' | 'done' | 'error';
  /** 0..1 */
  progress: number;
  attachment?: AttachmentView;
  /** Hata durumunda gösterilecek çevrilmiş metin. */
  error?: string;
}

/** Yanıta bağlanacak kimlikler: yalnız başarıyla yüklenenler, sırayla. */
export const readyIds = (items: UploadItem[]): number[] =>
  items.filter((i) => i.status === 'done' && i.attachment).map((i) => i.attachment!.id);

export const isUploading = (items: UploadItem[]) => items.some((i) => i.status === 'uploading');

/** Mesajdaki ekleri sırayla düz listeye çevirir (büyük görüntüleyicide yan yana gezinme). */
export const flattenAttachments = (messages: { attachments?: AttachmentView[] }[]): AttachmentView[] =>
  messages.flatMap((m) => m.attachments ?? []);

/** Küçük resim oranı: bilinmiyorsa 4:3. */
export function aspectOf(a: Pick<AttachmentView, 'width' | 'height'>): number {
  return a.width && a.height && a.width > 0 && a.height > 0 ? a.width / a.height : 4 / 3;
}
