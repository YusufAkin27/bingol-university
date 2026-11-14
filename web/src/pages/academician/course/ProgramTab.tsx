// SEKME: Program. Haftalık ders saatleri düzenleyicisi. API: PUT /academician/courses/{id}/slots (liste tamamen yenilenir).
// Doğrulama: bitiş > başlangıç (engeller); aynı gün çakışma yalnız uyarı verir.
import { useMemo, useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { acadKeys, replaceSlots, type Course } from '../../../api/academician';
import { Button, Card, FormField, Icon, Input, Select, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useUnsavedGuard } from '../components/unsavedGuard';
import { useT } from '../dict';
import { acadError } from '../errors';
import styles from '../academician.module.css';
import { MAX_SLOTS, hasErrors, overlaps, slotError, type SlotRow } from './slots';

let seq = 0;
const newKey = () => `s${++seq}`;
const fromCourse = (c: Course): SlotRow[] =>
  c.slots.map((s) => ({ key: newKey(), dayOfWeek: s.dayOfWeek, startTime: s.startTime, endTime: s.endTime, room: s.room ?? '' }));

export function ProgramTab({ course }: { course: Course }) {
  const i18n = useI18n();
  const t = useT();
  const toast = useToast();
  const qc = useQueryClient();
  const [rows, setRows] = useState<SlotRow[]>(() => fromCourse(course));
  const [error, setError] = useState<string | null>(null);
  const [touched, setTouched] = useState(false);

  const clash = useMemo(() => overlaps(rows), [rows]);
  const clashKeys = new Set(clash.flat());
  const dirty = JSON.stringify(rows.map(({ key: _k, ...r }) => r)) !== JSON.stringify(fromCourse(course).map(({ key: _k, ...r }) => r));

  useUnsavedGuard(dirty, t('ac.program.leaveGuard'));

  const save = useMutation({
    mutationFn: () =>
      replaceSlots(
        course.id,
        rows.map((r) => ({ dayOfWeek: r.dayOfWeek, startTime: r.startTime, endTime: r.endTime, room: r.room.trim() || null })),
      ),
    onSuccess: (slots) => {
      void qc.invalidateQueries({ queryKey: acadKeys.course(course.id) });
      void qc.invalidateQueries({ queryKey: acadKeys.courses() });
      setRows(slots.map((s) => ({ key: newKey(), dayOfWeek: s.dayOfWeek, startTime: s.startTime, endTime: s.endTime, room: s.room ?? '' })));
      setTouched(false);
      toast.success(t('ac.program.saved'));
    },
    // hata: satırlar korunur
    onError: (e) => setError(acadError(i18n, e)),
  });

  const update = (key: string, patch: Partial<SlotRow>) => setRows((rs) => rs.map((r) => (r.key === key ? { ...r, ...patch } : r)));

  function submit() {
    setTouched(true);
    setError(null);
    if (hasErrors(rows)) return;
    save.mutate();
  }

  return (
    <Card
      title={t('ac.program.title')}
      actions={
        <Button size="sm" variant="secondary" leftIcon={<Icon name="plus" size={16} />} disabled={rows.length >= MAX_SLOTS} onClick={() => setRows((rs) => [...rs, { key: newKey(), dayOfWeek: 1, startTime: '09:00', endTime: '09:50', room: '' }])}>
          {t('ac.program.add')}
        </Button>
      }
    >
      <p className={styles.muted}>{t('ac.program.intro')}</p>
      {error && (
        <div className={styles.alertBox} role="alert">
          <Icon name="alert" size={18} />
          <span>{error}</span>
        </div>
      )}
      {rows.length === 0 ? (
        <p className={styles.muted}>{t('ac.program.empty')}</p>
      ) : (
        <ul className={styles.slotList}>
          {rows.map((r, i) => {
            const err = slotError(r);
            const shown = touched || err === 'order' ? err : null;
            return (
              <li key={r.key} className={styles.slotRow} data-clash={clashKeys.has(r.key) || undefined}>
                <FormField label={t('ac.program.day')}>
                  <Select aria-label={`${t('ac.program.day')} ${i + 1}`} value={r.dayOfWeek} onChange={(e) => update(r.key, { dayOfWeek: Number(e.target.value) })}>
                    {[1, 2, 3, 4, 5, 6, 7].map((d) => (
                      <option key={d} value={d}>
                        {t(`ac.day.${d}`)}
                      </option>
                    ))}
                  </Select>
                </FormField>
                <FormField label={t('ac.program.start')} error={shown === 'start' ? t('ac.program.err.time') : shown === 'order' ? t('ac.program.err.order') : null}>
                  <Input type="time" value={r.startTime} onChange={(e) => update(r.key, { startTime: e.target.value })} />
                </FormField>
                <FormField label={t('ac.program.end')} error={shown === 'end' ? t('ac.program.err.time') : null}>
                  <Input type="time" value={r.endTime} onChange={(e) => update(r.key, { endTime: e.target.value })} />
                </FormField>
                <FormField label={t('ac.program.room')}>
                  <Input value={r.room} maxLength={100} placeholder={t('ac.program.roomHint')} onChange={(e) => update(r.key, { room: e.target.value })} />
                </FormField>
                <Button variant="dangerOutline" size="sm" aria-label={t('ac.program.removeRow', { n: i + 1 })} onClick={() => setRows((rs) => rs.filter((x) => x.key !== r.key))}>
                  <Icon name="x" size={16} />
                </Button>
              </li>
            );
          })}
        </ul>
      )}
      {clash.length > 0 && (
        <div className={styles.warnBox} role="status">
          <Icon name="alert" size={18} />
          <span>{t('ac.program.overlap')}</span>
        </div>
      )}
      <div className={styles.actionsRow}>
        <Button loading={save.isPending} disabled={!dirty} onClick={submit}>
          {t('ac.program.save')}
        </Button>
        {dirty && (
          <Button variant="ghost" onClick={() => { setRows(fromCourse(course)); setTouched(false); setError(null); }}>
            {t('ac.program.reset')}
          </Button>
        )}
      </div>
    </Card>
  );
}
