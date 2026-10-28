// CSV indirme düğmesi (P11/P12): yetkili çağrı + blob indirme. Sunucu en çok 50.000 satır verir, isteğin kendisi denetlenir.
import { useState } from 'react';
import { Button, Icon, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { downloadBlob } from '../users/filters';

export function CsvButton({
  fetcher,
  filename,
  size = 'md',
}: {
  fetcher: () => Promise<Blob>;
  filename: string;
  size?: 'sm' | 'md';
}) {
  const i18n = useI18n();
  const toast = useToast();
  const [busy, setBusy] = useState(false);

  async function run() {
    if (busy) return;
    setBusy(true);
    try {
      downloadBlob(await fetcher(), filename);
    } catch (e) {
      toast.error(adminError(i18n, e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Button variant="secondary" size={size} loading={busy} leftIcon={<Icon name="download" size={16} />} onClick={() => void run()}>
      {i18n.t('admin.p11.csv')}
    </Button>
  );
}
