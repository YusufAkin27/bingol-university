import { useEffect, useRef, useState } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { IconButton } from './Button';
import { Icon } from './Icon';

/** Metni panoya kopyalar; başarıda kısa süre onay simgesi ve `aria-live` duyurusu gösterir. */
export function CopyButton({ value, label }: { value: string; label?: string }) {
  const { t } = useI18n();
  const [done, setDone] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout>>();
  useEffect(() => () => clearTimeout(timer.current), []);

  async function copy() {
    try {
      await navigator.clipboard.writeText(value);
    } catch {
      // Pano API'si yoksa (http, eski tarayıcı) geçici textarea ile dene
      const ta = document.createElement('textarea');
      ta.value = value;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      try {
        document.execCommand('copy');
      } catch {
        /* sessizce geç */
      }
      ta.remove();
    }
    setDone(true);
    clearTimeout(timer.current);
    timer.current = setTimeout(() => setDone(false), 1800);
  }

  return (
    <>
      <IconButton label={done ? t('common.copied') : (label ?? t('common.copy'))} size="sm" onClick={copy}>
        <Icon name={done ? 'check' : 'copy'} size={16} />
      </IconButton>
      <span className="sr-only" role="status">
        {done ? t('common.copied') : ''}
      </span>
    </>
  );
}
