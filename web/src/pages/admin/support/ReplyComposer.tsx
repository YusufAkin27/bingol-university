// Yanıt kutusu: metin + ek ekleme (seçici, sürükle-bırak, yapıştır). Ön kontrol ve yükleme durumu useAttachmentUploads'tadır.
import { useEffect, useRef, useState, type ClipboardEvent, type DragEvent, type KeyboardEvent, type RefObject } from 'react';
import { Button, Icon, IconButton, PermissionButton, Textarea } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { formatBytes } from '../chat/chatLogic';
import {
  ACCEPT,
  MAX_ATTACHMENTS,
  MAX_IMAGE_BYTES,
  MAX_VIDEO_BYTES,
  isUploading,
  type UploadItem,
} from './attachmentLogic';
import type { useAttachmentUploads } from './useAttachmentUploads';
import att from './Attachments.module.css';
import styles from './Support.module.css';

type Uploads = ReturnType<typeof useAttachmentUploads>;

function LocalPreview({ item }: { item: UploadItem }) {
  const [url, setUrl] = useState<string | null>(null);
  const [broken, setBroken] = useState(false);
  useEffect(() => {
    if (item.kind !== 'IMAGE' || typeof URL.createObjectURL !== 'function') return;
    const u = URL.createObjectURL(item.file);
    setUrl(u);
    return () => URL.revokeObjectURL(u);
  }, [item.file, item.kind]);
  if (url && !broken) return <img src={url} alt="" onError={() => setBroken(true)} />;
  return <Icon name={item.kind === 'VIDEO' ? 'video' : 'image'} size={22} />;
}

interface Props {
  text: string;
  onText: (v: string) => void;
  maxLength: number;
  textRef: RefObject<HTMLTextAreaElement>;
  onKeyDown: (e: KeyboardEvent<HTMLTextAreaElement>) => void;
  uploads: Uploads;
  canSend: boolean;
  sending: boolean;
  onSend: () => void;
  hint: string;
}

export function ReplyComposer({ text, onText, maxLength, textRef, onKeyDown, uploads, canSend, sending, onSend, hint }: Props) {
  const { t, formatNumber } = useI18n();
  const fileRef = useRef<HTMLInputElement>(null);
  const [dragging, setDragging] = useState(false);
  const depth = useRef(0);
  const { items, problems } = uploads;
  const busy = isUploading(items);
  const full = items.length >= MAX_ATTACHMENTS;

  const hasFiles = (e: DragEvent) => Array.from(e.dataTransfer?.types ?? []).includes('Files');
  function onDragEnter(e: DragEvent) {
    if (!hasFiles(e)) return;
    e.preventDefault();
    depth.current += 1;
    setDragging(true);
  }
  function onDragLeave(e: DragEvent) {
    if (!hasFiles(e)) return;
    depth.current = Math.max(0, depth.current - 1);
    if (depth.current === 0) setDragging(false);
  }
  function onDrop(e: DragEvent) {
    if (!hasFiles(e)) return;
    e.preventDefault();
    depth.current = 0;
    setDragging(false);
    uploads.add(Array.from(e.dataTransfer.files));
  }
  function onPaste(e: ClipboardEvent<HTMLTextAreaElement>) {
    const files = Array.from(e.clipboardData?.files ?? []);
    if (files.length) {
      e.preventDefault();
      uploads.add(files);
    }
  }

  return (
    <div className={styles.compose}>
      <label htmlFor="ticket-reply" className={styles.composeLabel}>
        {t('admin.tickets.reply.label')}
      </label>
      <Textarea
        id="ticket-reply"
        ref={textRef}
        rows={5}
        dir="auto"
        value={text}
        maxLength={maxLength}
        placeholder={t('admin.tickets.reply.placeholder')}
        onChange={(e) => onText(e.target.value)}
        onKeyDown={onKeyDown}
        onPaste={onPaste}
      />

      <div
        className={`${att.drop} ${dragging ? att.dropActive : ''}`}
        onDragEnter={onDragEnter}
        onDragOver={(e) => hasFiles(e) && e.preventDefault()}
        onDragLeave={onDragLeave}
        onDrop={onDrop}
        data-testid="attach-drop"
      >
        <div className={att.dropHead}>
          <input
            ref={fileRef}
            type="file"
            multiple
            accept={ACCEPT}
            className={att.visuallyHidden}
            tabIndex={-1}
            aria-label={t('admin.support.att.pick')}
            data-testid="attach-input"
            onChange={(e) => {
              uploads.add(Array.from(e.target.files ?? []));
              e.target.value = '';
            }}
          />
          <Button
            size="sm"
            variant="secondary"
            disabled={full}
            leftIcon={<Icon name="paperclip" size={16} />}
            onClick={() => fileRef.current?.click()}
          >
            {t('admin.support.att.add')}
          </Button>
          <p className={att.dropHint}>
            {dragging
              ? t('admin.support.att.dropNow')
              : t('admin.support.att.rules', {
                  n: String(MAX_ATTACHMENTS),
                  img: `${MAX_IMAGE_BYTES / 1048576} MB`,
                  vid: `${MAX_VIDEO_BYTES / 1048576} MB`,
                })}
          </p>
        </div>

        {problems.length > 0 && (
          <ul className={att.problems} role="alert">
            {problems.map((p, i) => (
              <li key={`${i}-${p}`}>{p}</li>
            ))}
          </ul>
        )}

        {items.length > 0 && (
          <ul className={att.queue} aria-label={t('admin.support.att.queue')}>
            {items.map((it) => (
              <li key={it.key} className={`${att.qItem} ${it.status === 'error' ? att.qItemError : ''}`}>
                <span className={att.qPreview}>
                  <LocalPreview item={it} />
                </span>
                <span className={att.qBody}>
                  <span className={att.qName} dir="auto" title={it.file.name}>
                    {it.file.name}
                  </span>
                  <span className={`${att.qMeta} ${it.status === 'error' ? att.qMetaError : ''}`}>
                    {it.status === 'uploading'
                      ? t('admin.support.att.uploading', { p: formatNumber(Math.round(it.progress * 100)) })
                      : it.status === 'done'
                        ? `${t('admin.support.att.ready')} · ${formatBytes(it.file.size)}`
                        : it.error}
                  </span>
                  {it.status === 'uploading' && (
                    <span
                      className={att.qBar}
                      role="progressbar"
                      aria-label={it.file.name}
                      aria-valuemin={0}
                      aria-valuemax={100}
                      aria-valuenow={Math.round(it.progress * 100)}
                    >
                      <span style={{ inlineSize: `${Math.round(it.progress * 100)}%` }} />
                    </span>
                  )}
                </span>
                <span className={att.qActions}>
                  {it.status === 'error' && (
                    <Button size="sm" variant="ghost" onClick={() => uploads.retry(it.key)}>
                      {t('admin.support.att.retry')}
                    </Button>
                  )}
                  <IconButton
                    size="sm"
                    label={t('admin.support.att.remove', { name: it.file.name })}
                    onClick={() => uploads.remove(it.key)}
                  >
                    <Icon name="x" size={16} />
                  </IconButton>
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className={styles.composeFoot}>
        <span className={styles.hint}>{hint}</span>
        <span className={`${styles.counter} ${text.length > maxLength - 100 ? styles.counterWarn : ''} ltr`} aria-live="polite">
          {t('admin.tickets.reply.counter', { n: text.length, max: maxLength })}
        </span>
        <PermissionButton permission="support.write" onClick={onSend} disabled={!canSend || busy} loading={sending}>
          {t('admin.tickets.reply.send')}
        </PermissionButton>
        {busy && <span className={styles.hint}>{t('admin.support.att.waitUpload')}</span>}
      </div>
    </div>
  );
}
