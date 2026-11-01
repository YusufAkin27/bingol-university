import { useId, useState, type ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { Icon } from './Icon';
import { useIsNarrow } from './useIsNarrow';
import styles from './FilterPanel.module.css';

export interface FilterChip {
  key: string;
  /** Çipte görünen düz cümle: "Durum: Açık". */
  label: string;
  onRemove: () => void;
}

export interface FilterPanelProps {
  /** Süzgeç alanları (Select, Input, DateRangePicker...). Her zaman bağlı kalır: gizliyken bile değerleri korunur. */
  children: ReactNode;
  /** Etkin süzgeç sayısı ("Süzgeçler (2)" düğmesinde görünür). */
  activeCount?: number;
  /** Etkin süzgeçler; telefonda panel kapalıyken çip olarak listelenir, çipe dokununca o süzgeç kalkar. */
  chips?: FilterChip[];
  /** "Süzgeçleri temizle" düğmesi (verilmezse görünmez). */
  onClear?: () => void;
  /** Telefonda panel açık başlasın. */
  defaultOpen?: boolean;
  /** Katlanmaya geçiş genişliği (px, varsayılan 640). */
  breakpoint?: number;
  className?: string;
}

/**
 * Süzgeç duvarı çözümü (AUD2 X-3, AUD3 G5, AUD4 G2): geniş ekranda alanlar olduğu gibi yan yana durur; telefonda
 * "Süzgeçler (2)" düğmesinin arkasına katlanır, etkin süzgeçler çip olarak görünür ve liste ilk ekranda başlar.
 */
export function FilterPanel({ children, activeCount = 0, chips, onClear, defaultOpen, breakpoint = 640, className }: FilterPanelProps) {
  const { t } = useI18n();
  const narrow = useIsNarrow(breakpoint);
  const [open, setOpen] = useState(!!defaultOpen);
  const panelId = useId();
  const collapsed = narrow && !open;
  return (
    <div className={`${styles.root} ${className ?? ''}`} data-narrow={narrow || undefined}>
      {narrow && (
        <div className={styles.head}>
          <button
            type="button"
            className={styles.toggle}
            aria-expanded={open}
            aria-controls={panelId}
            onClick={() => setOpen((o) => !o)}
          >
            <Icon name="filter" size={18} />
            <span>{activeCount > 0 ? t('admin.kit.filter.count', { count: String(activeCount) }) : t('admin.kit.filter.title')}</span>
            <Icon name={open ? 'chevronUp' : 'chevronDown'} size={16} />
          </button>
          {onClear && activeCount > 0 && (
            <button type="button" className={styles.clear} onClick={onClear}>
              {t('admin.kit.filter.clear')}
            </button>
          )}
        </div>
      )}
      {collapsed && chips && chips.length > 0 && (
        <ul className={styles.chips} aria-label={t('admin.kit.filter.active')}>
          {chips.map((c) => (
            <li key={c.key}>
              <button
                type="button"
                className={styles.chip}
                aria-label={t('admin.kit.filter.remove', { label: c.label })}
                onClick={c.onRemove}
              >
                <span>{c.label}</span>
                <Icon name="x" size={14} />
              </button>
            </li>
          ))}
        </ul>
      )}
      <div id={panelId} className={styles.fields} hidden={collapsed}>
        {children}
        {!narrow && onClear && activeCount > 0 && (
          <button type="button" className={styles.clear} onClick={onClear}>
            {t('admin.kit.filter.clear')}
          </button>
        )}
      </div>
    </div>
  );
}
