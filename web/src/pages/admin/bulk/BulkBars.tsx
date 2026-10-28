// P15: haber / akademik / menü / bekleyen kayıt toplu işlem çubukları (GuardedAction: sebep + etki + yazarak onay).
import { useState } from 'react';
import {
  bulkAcademic,
  bulkCancelPending,
  bulkDeleteMenu,
  bulkNews,
  type AcademicBulkAction,
  type AcademicBulkEntity,
  type BulkReport,
  type NewsBulkAction,
} from '../../../api/adminBulk';
import { acdKeys } from '../../../api/academic';
import { pendingKeys } from '../../../api/pendingUsers';
import { qk } from '../../../api';
import { BulkBar, GuardedAction } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { BulkReportModal, bulkError } from './BulkParts';

interface BarProps {
  onClear: () => void;
  /** İşlem bitince (rapor gösterilmeden önce) liste yenilemesi vb. */
  onDone?: () => void;
}

/** Haber: toplu gizle / göster. */
export function NewsBulkBar({ ids, onClear, onDone }: BarProps & { ids: number[] }) {
  const i18n = useI18n();
  const { t } = i18n;
  const [report, setReport] = useState<BulkReport | null>(null);
  const run = (action: NewsBulkAction) => async ({ reason, idempotencyKey }: { reason: string; idempotencyKey: string }) => {
    const r = await bulkNews(action, ids, reason, { idempotencyKey });
    setReport(r);
    onClear();
    onDone?.();
    return r;
  };
  return (
    <>
      <BulkBar count={ids.length} onClear={onClear}>
        <GuardedAction
          size="sm"
          variant="secondary"
          title={t('admin.p15.news.hide.title', { n: ids.length })}
          consequence={t('admin.p15.news.hide.consequence')}
          irreversible={false}
          requireReason
          impact={{ count: ids.length, noun: t('admin.p15.news.noun') }}
          confirmLabel={t('admin.p15.news.hide')}
          errorMessage={(e) => bulkError(i18n, e)}
          successMessage={false}
          invalidateKeys={[[...qk.news.all]]}
          onConfirm={run('HIDE')}
        >
          {t('admin.p15.news.hide')}
        </GuardedAction>
        <GuardedAction
          size="sm"
          variant="secondary"
          title={t('admin.p15.news.show.title', { n: ids.length })}
          consequence={t('admin.p15.news.show.consequence')}
          irreversible={false}
          requireReason
          impact={{ count: ids.length, noun: t('admin.p15.news.noun') }}
          confirmLabel={t('admin.p15.news.show')}
          errorMessage={(e) => bulkError(i18n, e)}
          successMessage={false}
          invalidateKeys={[[...qk.news.all]]}
          onConfirm={run('UNHIDE')}
        >
          {t('admin.p15.news.show')}
        </GuardedAction>
      </BulkBar>
      <BulkReportModal report={report} onClose={() => setReport(null)} />
    </>
  );
}

/** Akademik takvim / sınav programı / bölüm duyurusu: toplu yayınla / kaldır / sil. */
export function AcademicBulkBar({
  entity,
  ids,
  onClear,
  onDone,
}: BarProps & { entity: AcademicBulkEntity; ids: number[] }) {
  const i18n = useI18n();
  const { t } = i18n;
  const [report, setReport] = useState<BulkReport | null>(null);
  const noun = t(`admin.p15.acd.noun.${entity}`);
  const run =
    (action: AcademicBulkAction) =>
    async ({ reason, idempotencyKey }: { reason: string; idempotencyKey: string }) => {
      const r = await bulkAcademic(entity, action, ids, reason, { idempotencyKey });
      setReport(r);
      onClear();
      onDone?.();
      return r;
    };
  const common = {
    size: 'sm' as const,
    requireReason: true,
    impact: { count: ids.length, noun },
    errorMessage: (e: unknown) => bulkError(i18n, e),
    successMessage: false as const,
    invalidateKeys: [[...acdKeys.all]],
  };
  return (
    <>
      <BulkBar count={ids.length} onClear={onClear}>
        <GuardedAction
          {...common}
          variant="secondary"
          title={t('admin.p15.acd.publish.title', { n: ids.length })}
          message={noun}
          consequence={t(entity === 'ANNOUNCEMENT' ? 'admin.p15.acd.publish.consequenceAnn' : 'admin.p15.acd.publish.consequence')}
          irreversible={false}
          confirmLabel={t('admin.p15.acd.publish')}
          onConfirm={run('PUBLISH')}
        >
          {t('admin.p15.acd.publish')}
        </GuardedAction>
        <GuardedAction
          {...common}
          variant="secondary"
          title={t('admin.p15.acd.unpublish.title', { n: ids.length })}
          message={noun}
          consequence={t('admin.p15.acd.unpublish.consequence')}
          irreversible={false}
          confirmLabel={t('admin.p15.acd.unpublish')}
          onConfirm={run('UNPUBLISH')}
        >
          {t('admin.p15.acd.unpublish')}
        </GuardedAction>
        <GuardedAction
          {...common}
          variant="danger"
          danger
          title={t('admin.p15.acd.delete.title', { n: ids.length })}
          message={noun}
          consequence={t('admin.p15.acd.delete.consequence')}
          irreversible
          typeToConfirm={t('admin.p15.typeDelete')}
          confirmLabel={t('admin.p15.acd.delete')}
          onConfirm={run('DELETE')}
        >
          {t('admin.p15.acd.delete')}
        </GuardedAction>
      </BulkBar>
      <BulkReportModal report={report} onClose={() => setReport(null)} />
    </>
  );
}

/** Menü: seçili günleri sil (gün satırı + fotoğraf dosyası). */
export function MenuBulkBar({ dates, onClear, onDone }: BarProps & { dates: string[] }) {
  const i18n = useI18n();
  const { t } = i18n;
  const [report, setReport] = useState<BulkReport | null>(null);
  return (
    <>
      <BulkBar count={dates.length} onClear={onClear}>
        <GuardedAction
          size="sm"
          variant="danger"
          danger
          title={t('admin.p15.menu.delete.title', { n: dates.length })}
          message={t('admin.p15.menu.delete.message')}
          consequence={t('admin.p15.menu.delete.consequence')}
          irreversible
          requireReason
          typeToConfirm={t('admin.p15.typeDelete')}
          impact={{ count: dates.length, noun: t('admin.p15.menu.noun') }}
          confirmLabel={t('admin.p15.menu.delete')}
          errorMessage={(e) => bulkError(i18n, e)}
          successMessage={false}
          invalidateKeys={[['adminMenu']]}
          onConfirm={async ({ reason, idempotencyKey }) => {
            const r = await bulkDeleteMenu(dates, reason, { idempotencyKey });
            setReport(r);
            onClear();
            onDone?.();
            return r;
          }}
        >
          {t('admin.p15.menu.delete')}
        </GuardedAction>
      </BulkBar>
      <BulkReportModal report={report} onClose={() => setReport(null)} />
    </>
  );
}

/** Bekleyen kayıtlar: seçilenleri toplu iptal et (hesap oluşmadığı için kullanıcı yeniden kayıt olabilir). */
export function PendingBulkCancel({ emails, onDone }: { emails: string[]; onDone: () => void }) {
  const i18n = useI18n();
  const { t } = i18n;
  const [report, setReport] = useState<BulkReport | null>(null);
  return (
    <>
      <GuardedAction
        variant="danger"
        danger
        title={t('admin.p15.pending.cancel.title', { n: emails.length })}
        consequence={t('admin.p15.pending.cancel.consequence')}
        irreversible
        requireReason
        impact={{ count: emails.length, noun: t('admin.p15.pending.noun') }}
        confirmLabel={t('admin.p15.pending.cancel')}
        errorMessage={(e) => bulkError(i18n, e)}
        successMessage={false}
        invalidateKeys={[[...pendingKeys.all]]}
        onConfirm={async ({ reason, idempotencyKey }) => {
          const r = await bulkCancelPending(emails, reason, { idempotencyKey });
          setReport(r);
          onDone();
          return r;
        }}
      >
        {t('admin.p15.pending.cancel')}
      </GuardedAction>
      <BulkReportModal report={report} onClose={() => setReport(null)} />
    </>
  );
}

