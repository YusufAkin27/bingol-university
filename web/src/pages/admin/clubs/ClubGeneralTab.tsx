// Kulüp çekmecesi: Genel sekmesi (özet + düzenleme formu). Kaydedilmemiş değişiklik uyarısı çekmece tarafında
// (`useUnsavedGuard`), burada yalnız `onDirtyChange` ile bildirilir. Küfür süzgeci yönetici düzenlemesinde atlanır.
import { useQuery } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';
import { updateClub, type ClubDetail } from '../../../api/adminCommunities';
import { communityCategoryKeys, listCommunityCategories } from '../../../api/communityCategories';
import { useGuardedMutation } from '../../../components/admin/guard/useGuardedMutation';
import { Badge, Button, FormField, Input, Select, Textarea } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { DetailList } from '../community/ReviewParts';
import { diffToUpdate, formFrom, isDirty, isKnownAction, nameError, type ClubForm } from './clubsLogic';
import styles from './clubs.module.css';

interface Props {
  detail: ClubDetail;
  onDirtyChange: (dirty: boolean) => void;
}

export function ClubGeneralTab({ detail, onDirtyChange }: Props) {
  const { t, td, formatDateTime, formatNumber } = useI18n();
  const base = useMemo(() => formFrom(detail), [detail]);
  const [form, setForm] = useState<ClubForm>(base);
  const set = (p: Partial<ClubForm>) => setForm((f) => ({ ...f, ...p }));
  const dirty = isDirty(form, base);
  const nameErr = nameError(form.name);
  const editable = detail.capabilities.canEdit;

  // Sunucudan yeni ayrıntı gelince (kayıttan sonra) form yeniden temellenir.
  useEffect(() => setForm(base), [base]);
  useEffect(() => {
    onDirtyChange(dirty);
    return () => onDirtyChange(false);
  }, [dirty, onDirtyChange]);

  const cats = useQuery({ queryKey: communityCategoryKeys.list(), queryFn: listCommunityCategories, staleTime: 60_000 });
  const categoryOptions = useMemo(() => {
    const items = (cats.data?.items ?? []).filter((c) => c.active || c.key === base.category);
    const keys = new Set(items.map((c) => c.key));
    const opts = items.map((c) => ({ key: c.key, label: c.nameTr }));
    if (base.category && !keys.has(base.category)) opts.push({ key: base.category, label: base.category });
    return opts;
  }, [cats.data, base.category]);

  const save = useGuardedMutation({
    mutationFn: (_: void, ctx) => updateClub(detail.club.id, diffToUpdate(base, form), { idempotencyKey: ctx.idempotencyKey }),
    successMessage: t('admin.p06.general.saved'),
    invalidateKeys: [['communities']],
  });

  const c = detail.club;
  return (
    <div className={styles.panel}>
      <DetailList
        items={[
          { label: t('admin.p06.general.slug'), value: <span className="ltr">{c.slug}</span> },
          {
            label: t('admin.p06.general.owner'),
            value: (
              <span>
                {c.ownerName ?? `#${c.ownerId}`} <span className="ltr">{c.ownerEmail}</span>
              </span>
            ),
          },
          { label: t('admin.p06.general.members'), value: formatNumber(c.memberCount) },
          { label: t('admin.p06.general.pending'), value: formatNumber(c.pendingCount) },
          { label: t('admin.p06.general.banned'), value: formatNumber(detail.bannedCount) },
          { label: t('admin.p06.general.events'), value: formatNumber(c.eventCount) },
          { label: t('admin.p06.general.reports'), value: formatNumber(c.openReportCount) },
          { label: t('admin.p06.general.created'), value: formatDateTime(c.createdAt) },
        ]}
      />
      {detail.reviewNote && (
        <p className={styles.reason} data-testid="review-note">
          {t('admin.p06.general.reviewNote', { note: detail.reviewNote })}
        </p>
      )}

      {detail.openReports.length > 0 && (
        <section aria-label={t('admin.p06.general.openReports')}>
          <h3 className={styles.zoneTitle}>{t('admin.p06.general.openReports')}</h3>
          <ul className={styles.history}>
            {detail.openReports.map((r) => (
              <li key={r.id} className={styles.historyItem}>
                <span>
                  <Badge tone="warning">{r.reason}</Badge> {r.note}
                </span>
                <span className={styles.muted}>{formatDateTime(r.createdAt)}</span>
              </li>
            ))}
          </ul>
        </section>
      )}

      {detail.statusHistory.length > 0 && (
        <section aria-label={t('admin.p06.general.history')}>
          <h3 className={styles.zoneTitle}>{t('admin.p06.general.history')}</h3>
          <ul className={styles.history}>
            {detail.statusHistory.map((h) => (
              <li key={h.id} className={styles.historyItem}>
                <span>{isKnownAction(h.action) ? t(`admin.p06.audit.action.${h.action}`) : h.action}</span>
                <span className={styles.muted}>
                  {h.actorName ?? t('admin.p06.audit.system')} · {formatDateTime(h.at)}
                </span>
                {h.detail && <span className={styles.muted}>{h.detail}</span>}
              </li>
            ))}
          </ul>
        </section>
      )}

      <form
        className={styles.form}
        aria-label={t('admin.p06.general.formLabel')}
        onSubmit={(e) => {
          e.preventDefault();
          if (dirty && !nameErr) void save.run();
        }}
      >
        <FormField
          label={t('admin.p06.general.name')}
          error={nameErr ? t(nameErr === 'short' ? 'admin.p06.general.nameShort' : 'admin.p06.general.nameLong') : undefined}
          hint={t('admin.p06.general.nameHint')}
        >
          <Input value={form.name} maxLength={90} disabled={!editable} onChange={(e) => set({ name: e.target.value })} />
        </FormField>
        <FormField label={t('admin.p06.general.description')}>
          <Textarea
            rows={4}
            value={form.description}
            maxLength={1000}
            disabled={!editable}
            onChange={(e) => set({ description: e.target.value })}
          />
        </FormField>
        <FormField label={t('admin.p06.general.category')} hint={t('admin.p06.general.categoryHint')}>
          <Select value={form.category} disabled={!editable} onChange={(e) => set({ category: e.target.value })}>
            <option value="">{t('admin.p06.general.noCategory')}</option>
            {categoryOptions.map((o) => (
              <option key={o.key} value={o.key}>
                {o.label}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.p06.general.joinPolicy')}>
          <Select
            value={form.joinPolicy}
            disabled={!editable}
            onChange={(e) => set({ joinPolicy: e.target.value as ClubForm['joinPolicy'] })}
          >
            {(['OPEN', 'APPROVAL'] as const).map((p) => (
              <option key={p} value={p}>
                {td(`admin.communities.policy.${p}`, p)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.p06.general.visibility')}>
          <Select
            value={form.visibility}
            disabled={!editable}
            onChange={(e) => set({ visibility: e.target.value as ClubForm['visibility'] })}
          >
            {(['PUBLIC', 'PRIVATE'] as const).map((v) => (
              <option key={v} value={v}>
                {td(`admin.communities.visibility.${v}`, v)}
              </option>
            ))}
          </Select>
        </FormField>
        <p className={styles.muted}>{t('admin.p06.general.guardNote')}</p>
        {editable && (
          <div className={styles.formActions}>
            <Button type="button" variant="secondary" disabled={!dirty || save.isPending} onClick={() => setForm(base)}>
              {t('admin.p06.general.revert')}
            </Button>
            <Button type="submit" loading={save.isPending} disabled={!dirty || Boolean(nameErr)}>
              {t('admin.p06.general.save')}
            </Button>
          </div>
        )}
      </form>
    </div>
  );
}
