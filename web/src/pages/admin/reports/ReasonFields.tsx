// Karar nedeni (reasonCode) seçimi + hazır neden şablonları. Şablon seçimi kodu ve (istenirse) mesajı doldurur.
// API: GET /api/admin/reports/reason-templates (ReportsPage yükler, buraya geçirir).
import type { ReasonTemplate, ReportReasonCode } from '../../../api/types';
import { FormField, Select } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { REASON_CODES, cleanReasonCode } from '../moderation/modLogic';
import styles from '../moderation/moderation.module.css';

export function ReasonFields({
  value,
  onChange,
  templates,
  onTemplateText,
}: {
  value: ReportReasonCode | '';
  onChange: (v: ReportReasonCode | '') => void;
  templates: ReasonTemplate[];
  /** Verilirse şablon düğmeleri görünür ve seçilen şablonun metnini iletir (WARN/SUSPEND_USER mesajı için). */
  onTemplateText?: (text: string) => void;
}) {
  const { t, lang } = useI18n();
  return (
    <>
      <FormField label={t('admin.reports.reasonCode.label')}>
        <Select value={value} onChange={(e) => onChange(cleanReasonCode(e.target.value) ?? '')}>
          <option value="">{t('admin.reports.reasonCode.none')}</option>
          {REASON_CODES.map((c) => (
            <option key={c} value={c}>
              {t(`admin.reports.reasonCode.${c}`)}
            </option>
          ))}
        </Select>
      </FormField>
      {onTemplateText && templates.length > 0 && (
        <div>
          <p className={styles.muted}>{t('admin.reports.templates.title')}</p>
          <div className={styles.chips}>
            {templates.map((tpl) => (
              <button
                key={tpl.code}
                type="button"
                className={styles.chip}
                title={tpl.texts?.[lang] ?? tpl.text}
                onClick={() => {
                  onChange(tpl.code);
                  onTemplateText(tpl.texts?.[lang] ?? tpl.text);
                }}
              >
                {t(`admin.reports.reasonCode.${tpl.code}`)}
              </button>
            ))}
          </div>
        </div>
      )}
    </>
  );
}
