// QR paneli: şu an geçerli kodu (sunucu saatine göre) çizer, bir sonrakini önceden hesaplar, değişime kalan süreyi gösterir ve
// taze kod yoksa QR'ı GİZLER ("bağlantı bekleniyor"). Zaman durumu bu bileşende durur: yalnız bu panel 10 Hz yeniden çizilir.
import { useEffect, useState } from 'react';
import type { LiveCode } from '../../../api/academician';
import { Button, Icon, Spinner } from '../../../components/ui';
import { useT } from '../dict';
import { qrState } from './liveCode';
import { QrCode, qrPath } from './QrCode';
import styles from './live.module.css';

const TICK_MS = 100;

export function useNow(intervalMs = TICK_MS): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), intervalMs);
    return () => window.clearInterval(id);
  }, [intervalMs]);
  return now;
}

interface Props {
  status: 'OPEN' | 'CLOSED' | null;
  codes: LiveCode[];
  offsetMs: number;
  lastFreshAt: number | null;
  /** Projeksiyon kipi: en büyük QR, yüksek karşıtlık. */
  large?: boolean;
  onReopen?: () => void;
  reopening?: boolean;
  /** Kalıcı yoklama hatasının Türkçe metni (bekleme durumunda gösterilir). */
  errorText?: string | null;
  /** 'unexpected': oturum bu ekran açıkken kullanıcı kapatmadan kapandı. */
  closedReason?: 'unexpected' | null;
}

export function QrPanel({ status, codes, offsetMs, lastFreshAt, large, onReopen, reopening, errorText, closedReason }: Props) {
  const t = useT();
  const now = useNow();
  const q = qrState({ status, nowLocalMs: now, lastFreshLocalMs: lastFreshAt, offsetMs, codes });

  // bir sonraki kodu önceden hesapla (önbelleğe girer): geçişte yeniden çizim anında olur
  const nextCode = q.next?.code;
  useEffect(() => {
    if (nextCode) qrPath(nextCode);
  }, [nextCode]);

  const remainingMs = q.code ? Math.max(0, q.code.untilMs - q.serverNowMs) : 0;
  const windowMs = q.code ? q.code.untilMs - q.code.fromMs : 5000;
  const fraction = q.code ? Math.min(1, remainingMs / windowMs) : 0;

  return (
    <div className={styles.qrArea} data-large={large || undefined} data-state={q.state}>
      <div className={styles.qrBox}>
        {q.state === 'code' && q.code ? (
          <QrCode value={q.code.code} label={t('ac.live.qrAria')} />
        ) : (
          <div className={styles.qrBlank} role="status">
            {q.state === 'closed' ? (
              <>
                <Icon name="lock" size={large ? 56 : 36} aria-hidden="true" />
                <strong>{t('ac.live.closedTitle')}</strong>
                <span>{closedReason === 'unexpected' ? t('ac.live.closedUnexpected') : t('ac.live.closedText')}</span>
                {onReopen && (
                  <Button loading={reopening} onClick={onReopen} leftIcon={<Icon name="play" size={16} />}>
                    {t('ac.session.reopen')}
                  </Button>
                )}
              </>
            ) : q.state === 'waiting' ? (
              <>
                <Spinner size={large ? 'lg' : 'md'} />
                <strong>{t('ac.live.waitingTitle')}</strong>
                <span>{t('ac.live.waitingText')}</span>
                {errorText && <span role="alert">{errorText}</span>}
              </>
            ) : (
              <>
                <Spinner />
                <strong>{t('ac.live.nocodeTitle')}</strong>
                <span>{t('ac.live.nocodeText')}</span>
              </>
            )}
          </div>
        )}
      </div>
      {q.state === 'code' && (
        <div className={styles.countdown} aria-hidden="true">
          <div className={styles.countdownFill} style={{ transform: `scaleX(${fraction})` }} />
        </div>
      )}
      {q.state === 'code' && <p className={styles.countdownText}>{t('ac.live.changesIn', { n: Math.ceil(remainingMs / 1000) })}</p>}
    </div>
  );
}
