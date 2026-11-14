// Panel genelinde ortak küçük bileşenler: bağlantı düğmesi, ders adı, yoklama başlatma penceresi, durum bloklar.
import { useState, type ReactNode } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Link, useNavigate } from 'react-router-dom';
import { acadKeys, openSession, type Course } from '../../../api/academician';
import {
  Button,
  Checkbox,
  EmptyState,
  ErrorState,
  FormField,
  Icon,
  Input,
  Modal,
  Select,
  Skeleton,
  type ButtonSize,
  type ButtonVariant,
} from '../../../components/ui';
import buttons from '../../../components/ui/Button.module.css';
import { useI18n } from '../../../i18n/I18nProvider';
import { useT } from '../dict';
import { acadError } from '../errors';
import { todayLocal } from '../format';
import { acadPaths } from '../paths';
import styles from '../academician.module.css';

/** Router bağlantısı, düğme görünümlü. Kit'in `ButtonLink`i site dil önekini ekler; panel yolları için bu kullanılır. */
export function LinkButton({
  to,
  variant = 'primary',
  size = 'md',
  leftIcon,
  children,
  className,
}: {
  to: string;
  variant?: ButtonVariant;
  size?: ButtonSize;
  leftIcon?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <Link to={to} className={[buttons.btn, buttons[variant], buttons[size], className ?? ''].filter(Boolean).join(' ')}>
      {leftIcon}
      {children}
    </Link>
  );
}

/** Liste/sayfa yüklenirken sabit yükseklikli iskelet (zıplama yok). */
export function LoadingBlock({ rows = 3, height = '4rem' }: { rows?: number; height?: string }) {
  const t = useT();
  return (
    <div className={styles.skelStack} role="status" aria-busy="true" aria-label={t('ac.loading')}>
      {Array.from({ length: rows }, (_, i) => (
        <Skeleton key={i} height={height} radius="var(--radius-lg)" />
      ))}
    </div>
  );
}

/** Sorgu hatası: nedene göre metin + "Tekrar dene". */
export function QueryError({ subject, error, onRetry }: { subject: string; error: unknown; onRetry: () => void }) {
  return <ErrorState subject={subject} error={error} onRetry={onRetry} compact />;
}

export function EmptyBlock({
  title,
  description,
  action,
  icon = 'inbox',
}: {
  title: string;
  description?: ReactNode;
  action?: ReactNode;
  icon?: 'inbox' | 'search' | 'users' | 'calendar' | 'clipboard' | 'megaphone' | 'file' | 'graduation';
}) {
  return <EmptyState title={title} description={description} icon={icon} action={action} compact />;
}

/** Ders başlığı: "BIL101 · Veri Yapıları". */
export const courseTitle = (c: Pick<Course, 'code' | 'name'>): string => (c.code ? `${c.code} · ${c.name}` : c.name);

/**
 * Yoklama başlatma penceresi: tarih (varsayılan bugün), program saati (isteğe bağlı) ve "öğrencilere bildirim gönder".
 * Aynı gün + aynı saat için oturum zaten varsa sunucu onu yeniden açar. Başarıda canlı ekrana gidilir.
 */
export function StartSessionDialog({
  course,
  slotId,
  open,
  onClose,
}: {
  course: Course;
  slotId?: number;
  open: boolean;
  onClose: () => void;
}) {
  const i18n = useI18n();
  const t = useT();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [notify, setNotify] = useState(false);
  const [date, setDate] = useState(todayLocal());
  const [slot, setSlot] = useState(slotId ? String(slotId) : '');
  const [error, setError] = useState<string | null>(null);

  const start = useMutation({
    mutationFn: () => openSession(course.id, { lessonDate: date || undefined, slotId: slot ? Number(slot) : undefined, notify }),
    onSuccess: (s) => {
      void qc.invalidateQueries({ queryKey: acadKeys.sessions(course.id) });
      onClose();
      navigate(acadPaths.live(s.id));
    },
    onError: (e) => setError(acadError(i18n, e)),
  });

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={t('ac.start.title', { course: courseTitle(course) })}
      size="sm"
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            {t('ac.cancel')}
          </Button>
          <Button loading={start.isPending} onClick={() => start.mutate()} leftIcon={<Icon name="play" size={16} />}>
            {t('ac.start.confirm')}
          </Button>
        </>
      }
    >
      <div className={styles.formStack}>
        <p className={styles.muted}>{t('ac.start.intro')}</p>
        {error && (
          <div className={styles.alertBox} role="alert">
            <Icon name="alert" size={18} />
            <span>{error}</span>
          </div>
        )}
        <FormField label={t('ac.start.date')}>
          <Input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
        </FormField>
        {course.slots.length > 0 && (
          <FormField label={t('ac.start.slot')} hint={t('ac.start.slotHint')}>
            <Select value={slot} onChange={(e) => setSlot(e.target.value)}>
              <option value="">{t('ac.start.noSlot')}</option>
              {course.slots.map((s) => (
                <option key={s.id} value={s.id}>
                  {t(`ac.day.${s.dayOfWeek}`)} {s.startTime}–{s.endTime}
                  {s.room ? ` · ${s.room}` : ''}
                </option>
              ))}
            </Select>
          </FormField>
        )}
        <Checkbox checked={notify} onChange={(e) => setNotify(e.target.checked)} label={t('ac.start.notify')} />
        <p className={styles.muted}>{t('ac.start.notifyHint')}</p>
      </div>
    </Modal>
  );
}
