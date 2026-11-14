// SEKME: Dışa aktar. Devamsızlık tablosu CSV olarak iner (UTF-8, Excel uyumlu). API: GET /academician/courses/{id}/attendance.csv
// (Authorization başlığı gerektiğinden `<a href>` değil `apiBlob` + `downloadBlob`).
import { useState } from 'react';
import { attendanceCsv, type Course } from '../../../api/academician';
import { Button, Card, Icon, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { downloadBlob } from '../../admin/users/filters';
import { useT } from '../dict';
import { acadError } from '../errors';
import styles from '../academician.module.css';

export const csvFileName = (c: Pick<Course, 'id' | 'code' | 'name'>): string => {
  const slug = (c.code || c.name).normalize('NFKD').replace(/[^\w]+/g, '-').replace(/^-+|-+$/g, '').toLowerCase();
  return `devamsizlik-${slug || c.id}.csv`;
};

export function ExportTab({ course }: { course: Course }) {
  const i18n = useI18n();
  const t = useT();
  const toast = useToast();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function download() {
    setBusy(true);
    setError(null);
    try {
      const blob = await attendanceCsv(course.id);
      downloadBlob(blob, csvFileName(course));
      toast.success(t('ac.export.done'));
    } catch (e) {
      setError(acadError(i18n, e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card title={t('ac.export.title')}>
      <p className={styles.muted}>{t('ac.export.text')}</p>
      <ul className={styles.bullets}>
        <li>{t('ac.export.b1')}</li>
        <li>{t('ac.export.b2')}</li>
        <li>{t('ac.export.b3')}</li>
      </ul>
      {error && (
        <div className={styles.alertBox} role="alert">
          <Icon name="alert" size={18} />
          <span>{error}</span>
        </div>
      )}
      <div className={styles.actionsRow}>
        <Button loading={busy} leftIcon={<Icon name="download" size={18} />} onClick={() => void download()}>
          {t('ac.export.button')}
        </Button>
      </div>
    </Card>
  );
}
