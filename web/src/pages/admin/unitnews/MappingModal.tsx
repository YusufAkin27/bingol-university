import { useEffect, useState } from 'react';
import type { UnitSource } from '../../../api/adminUnitNews';
import { Button, FormField, Input, Modal } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { gt } from './dict';
import styles from './unitNews.module.css';

/** Virgüllü girişi temiz, tekrarsız anahtar listesine çevirir (büyük/küçük harf korunur). */
export function parseKeys(raw: string, existing: string[]): string[] {
  const out = [...existing];
  for (const part of raw.split(',')) {
    const k = part.trim();
    if (k && !out.some((x) => x.toLocaleLowerCase('tr') === k.toLocaleLowerCase('tr'))) out.push(k);
  }
  return out;
}

/** Eşleme: kaynağın hizmet verdiği katalog fakülte adı anahtarları (çipli giriş). */
export function MappingModal({
  source,
  saving,
  onClose,
  onSave,
}: {
  source: UnitSource | null;
  saving: boolean;
  onClose: () => void;
  onSave: (keys: string[]) => void;
}) {
  const i18n = useI18n();
  const t = gt(i18n);
  const [keys, setKeys] = useState<string[]>([]);
  const [draft, setDraft] = useState('');

  useEffect(() => {
    if (source) {
      setKeys(source.facultyKeys);
      setDraft('');
    }
  }, [source]);

  function commit(): string[] {
    const next = parseKeys(draft, keys);
    setKeys(next);
    setDraft('');
    return next;
  }

  return (
    <Modal
      open={!!source}
      onClose={onClose}
      title={t('admin.unitNews.mapping.title', { name: source?.name ?? '' })}
      footer={
        <Button loading={saving} onClick={() => onSave(parseKeys(draft, keys))}>
          {t('admin.unitNews.mapping.save')}
        </Button>
      }
    >
      <div className={styles.formStack}>
        <p className={styles.muted}>{t('admin.unitNews.mapping.help')}</p>
        <FormField label={t('admin.unitNews.mapping.field')}>
          <Input
            value={draft}
            placeholder={t('admin.unitNews.mapping.placeholder')}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                commit();
              }
            }}
          />
        </FormField>
        <div>
          <Button size="sm" variant="secondary" onClick={commit} disabled={!draft.trim()}>
            {t('admin.unitNews.mapping.add')}
          </Button>
        </div>
        {keys.length === 0 ? (
          <p className={styles.muted}>{t('admin.unitNews.mapping.none')}</p>
        ) : (
          <ul className={styles.chips}>
            {keys.map((k) => (
              <li key={k} className={styles.chip}>
                <span dir="auto">{k}</span>
                <button
                  type="button"
                  className={styles.chipBtn}
                  aria-label={t('admin.unitNews.mapping.remove', { key: k })}
                  onClick={() => setKeys(keys.filter((x) => x !== k))}
                >
                  ×
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </Modal>
  );
}
