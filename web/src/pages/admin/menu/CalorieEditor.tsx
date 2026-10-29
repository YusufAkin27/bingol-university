// Bir günün yemek listesi + satır içi kalori düzenleme (PUT /api/admin/menu/{date}/calories).
// Yalnızca değiştirilen yemekler gönderilir; boş alan = kaloriyi sil. İzin: content.write (yetkisizde düğme devre dışı).
import { useMutation } from '@tanstack/react-query';
import { useState } from 'react';
import { adminMenuApi } from '../../../api';
import type { AdminMenuDay } from '../../../api/adminMenu';
import { PermissionButton } from '../../../components/admin/guard/PermissionButton';
import { useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminErrorMessage } from '../campaigns/shared';
import { MAX_KCAL, dishesOf, parseKcal, sumKcal } from './menuLogic';
import styles from './menu.module.css';

export function CalorieEditor({ day, onSaved }: { day: AdminMenuDay; onSaved: () => void }) {
  const i18n = useI18n();
  const { t } = i18n;
  const toast = useToast();
  const dishes = dishesOf(day);
  // Yalnızca dokunulan satırların metni; dokunulmayan satır sunucudaki değeri gösterir
  const [edits, setEdits] = useState<Record<number, string>>({});
  const [problem, setProblem] = useState<string | null>(null);

  const text = (i: number) => edits[i] ?? (dishes[i].kcal === null ? '' : String(dishes[i].kcal));
  const parsed = dishes.map((_, i) => parseKcal(text(i)));
  const invalid = parsed.some((p) => !p.ok);
  const values = parsed.map((p) => (p.ok ? p.value : null));
  const changed = dishes
    .map((d, i) => ({ name: d.name, kcal: values[i], i }))
    .filter((e) => parsed[e.i].ok && edits[e.i] !== undefined && e.kcal !== dishes[e.i].kcal);
  const sum = sumKcal(values);

  const save = useMutation({
    mutationFn: () => adminMenuApi.saveDayCalories(day.date, changed.map(({ name, kcal }) => ({ name, kcal }))),
    onSuccess: () => {
      toast.success(t('admin.menu.kcal.saved'));
      setEdits({});
      setProblem(null);
      onSaved();
    },
    onError: (e) => setProblem(adminErrorMessage(i18n, e)),
  });

  if (dishes.length === 0) return <span className={styles.muted}>{t('admin.menu.noItems')}</span>;

  return (
    <div className={styles.kcal} data-testid="kcal-editor">
      <ul className={styles.dishes}>
        {dishes.map((d, i) => (
          <li key={`${i}-${d.name}`} className={styles.dish}>
            <span className={styles.dishName} dir="auto">
              {d.name}
            </span>
            <span className={styles.kcalField}>
              <input
                className={styles.kcalInput}
                type="number"
                inputMode="numeric"
                min={0}
                max={MAX_KCAL}
                step={1}
                value={text(i)}
                aria-label={t('admin.menu.kcal.input', { dish: d.name })}
                aria-invalid={parsed[i].ok ? undefined : true}
                data-testid="kcal-input"
                onChange={(e) => {
                  setProblem(null);
                  setEdits((m) => ({ ...m, [i]: e.target.value }));
                }}
              />
              <span className={styles.unit} aria-hidden="true">
                {t('admin.menu.kcal.unit')}
              </span>
            </span>
          </li>
        ))}
      </ul>
      <div className={styles.kcalFoot}>
        <span className={styles.total} data-testid="kcal-total">
          {sum.total === null
            ? t('admin.menu.kcal.totalNone')
            : sum.complete
              ? t('admin.menu.kcal.total', { kcal: sum.total })
              : t('admin.menu.kcal.totalPartial', { kcal: sum.total, known: sum.known, count: dishes.length })}
        </span>
        <PermissionButton
          permission="content.write"
          size="sm"
          variant="secondary"
          loading={save.isPending}
          disabled={changed.length === 0 || invalid}
          onClick={() => save.mutate()}
          aria-label={`${t('admin.menu.kcal.save')} — ${day.date}`}
        >
          {save.isPending ? t('admin.menu.kcal.saving') : t('admin.menu.kcal.save')}
        </PermissionButton>
      </div>
      {invalid && (
        <p className={styles.error} role="alert">
          {t('admin.menu.kcal.range', { max: MAX_KCAL })}
        </p>
      )}
      {problem && (
        <p className={styles.error} role="alert">
          {problem}
        </p>
      )}
    </div>
  );
}
