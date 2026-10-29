// Toplu kalori yapıştırma (PUT /api/admin/menu/calories): "tarih;yemek;kcal" satırları (ya da Excel'den sekmeli).
// Sunucu gevşek çalışır: menüde olmayan gün/yemek atlanır ve raporlanır. İzin: content.write.
import { useState } from 'react';
import { adminMenuApi } from '../../../api';
import type { KcalBulkResult } from '../../../api/adminMenu';
import { GuardedAction } from '../../../components/admin/guard/GuardedAction';
import { Textarea } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminErrorMessage } from '../campaigns/shared';
import { parseCalorieText } from './menuLogic';
import styles from './menu.module.css';

export function CalorieBulkImport({ onDone }: { onDone: () => void }) {
  const i18n = useI18n();
  const { t } = i18n;
  const [text, setText] = useState('');
  const [result, setResult] = useState<KcalBulkResult | null>(null);
  const parsed = parseCalorieText(text);

  return (
    <details className={styles.bulk}>
      <summary>{t('admin.menu.kcal.bulk.title')}</summary>
      <p className={styles.muted}>{t('admin.menu.kcal.bulk.help')}</p>
      <Textarea
        rows={6}
        value={text}
        onChange={(e) => {
          setText(e.target.value);
          setResult(null);
        }}
        placeholder="2026-10-05;MERCİMEK ÇORBASI;180"
        aria-label={t('admin.menu.kcal.bulk.title')}
        data-testid="kcal-bulk-text"
        spellCheck={false}
      />
      {text.trim() !== '' && (
        <p className={styles.muted} data-testid="kcal-bulk-summary">
          {t('admin.menu.kcal.bulk.parsed', { ok: parsed.count, bad: parsed.errors.length })}
        </p>
      )}
      {parsed.errors.length > 0 && (
        <ul className={styles.errors}>
          {parsed.errors.slice(0, 10).map((e) => (
            <li key={e.line}>
              {t('admin.menu.kcal.bulk.badLine', {
                line: e.line,
                reason: t(`admin.menu.kcal.bulk.err.${e.reason}` as 'admin.menu.kcal.bulk.err.format'),
              })}
            </li>
          ))}
        </ul>
      )}
      <GuardedAction
        permission="content.write"
        size="sm"
        variant="secondary"
        disabled={parsed.count === 0 || parsed.days.length > 62}
        title={t('admin.menu.kcal.bulk.confirmTitle', { n: parsed.count })}
        message={t('admin.menu.kcal.bulk.confirmMsg')}
        confirmLabel={t('admin.menu.kcal.bulk.apply')}
        successMessage={false}
        errorMessage={(e) => adminErrorMessage(i18n, e)}
        invalidateKeys={[['adminMenu']]}
        onConfirm={async () => {
          const r = await adminMenuApi.saveBulkCalories(parsed.days);
          setResult(r);
          onDone();
          return r;
        }}
      >
        {t('admin.menu.kcal.bulk.apply')}
      </GuardedAction>
      {parsed.days.length > 62 && (
        <p className={styles.error} role="alert">
          {t('admin.menu.kcal.bulk.tooManyDays')}
        </p>
      )}
      {result && (
        <div role="status" data-testid="kcal-bulk-result">
          <p>
            {t('admin.menu.kcal.bulk.result', {
              updated: result.updated,
              cleared: result.cleared,
              unchanged: result.unchanged,
              skipped: result.skipped.length,
            })}
          </p>
          {result.skipped.length > 0 && (
            <ul className={styles.errors}>
              {result.skipped.slice(0, 20).map((s, i) => (
                <li key={`${s.date}-${i}`}>
                  {s.date} {s.name ?? ''} —{' '}
                  {t(`admin.menu.kcal.bulk.skip.${s.reason}` as 'admin.menu.kcal.bulk.skip.ITEM_NOT_FOUND')}
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </details>
  );
}
