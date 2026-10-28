import { useId } from 'react';
import { useI18n } from '../../../i18n/I18nProvider';
import { Icon } from '../../ui/Icon';
import { TypeToConfirm } from './TypeToConfirm';
import { DEFAULT_BULK_THRESHOLD, bulkNeedsConfirm, matchesTarget } from './match';
import styles from './guard.module.css';

export interface BulkImpactNoticeProps {
  /** Etkilenecek kayıt sayısı. */
  count: number;
  /** Bu sayıdan BÜYÜK ise etkilenen sayıyı yazarak onay zorunlu olur. Varsayılan 50. */
  threshold?: number;
  /** "kayıt", "kullanıcı", "alıcı" gibi isim. */
  noun?: string;
  /** Yazılan onay metni (eşik aşıldığında kullanılır). */
  value: string;
  onChange: (value: string, confirmed: boolean) => void;
  /** Eşik aşıldığında yazma alanı diyalog açılınca odak alsın. */
  focusOnMount?: boolean;
}

/** Toplu işlemde bir kez doğrulama: eşik aşılmadıysa true, aşıldıysa yazılan sayı doğruysa true. */
export function isBulkConfirmed(count: number, threshold: number, typed: string): boolean {
  return !bulkNeedsConfirm(count, threshold) || matchesTarget(typed, String(count));
}

/** "N kayıt etkilenecek" şeridi; N eşiği aşarsa TypeToConfirm (N'yi yazdırır) gösterir. */
export function BulkImpactNotice({
  count,
  threshold = DEFAULT_BULK_THRESHOLD,
  noun,
  value,
  onChange,
  focusOnMount,
}: BulkImpactNoticeProps) {
  const { t, formatNumber } = useI18n();
  const uid = useId();
  const needs = bulkNeedsConfirm(count, threshold);
  const shown = formatNumber(count);
  return (
    <div className={`${styles.bulk} ${needs ? styles.bulkHigh : ''}`}>
      <p id={`${uid}-notice`} className={styles.bulkLine} role="status">
        <Icon name="alert" size={16} aria-hidden="true" />
        <strong>
          {t('admin.guard.bulk.notice', { count: shown, noun: noun ?? t('admin.guard.bulk.noun') })}
        </strong>
      </p>
      {needs && (
        <>
          <p className={styles.hint}>{t('admin.guard.bulk.confirmPrompt', { count })}</p>
          <TypeToConfirm
            target={String(count)}
            value={value}
            focusOnMount={focusOnMount}
            onChange={(v) => onChange(v, matchesTarget(v, String(count)))}
          />
        </>
      )}
    </div>
  );
}
