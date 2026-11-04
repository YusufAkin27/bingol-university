// Yer fotoğrafı (yalnız KAYITLI yerde: yükleme ucu yer kimliği ister). Sunucu yeniden kodlar ve EXIF'i siler;
// istemci yalnız tür/boyutu önceden denetler (menü fotoğrafı ile aynı kural).
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useRef, useState } from 'react';
import { campusKeys, deleteCampusPhoto, uploadCampusPhoto } from '../../../api/adminCampus';
import { Button, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { validateMenuImage } from '../menu/menuLogic';
import { gt } from './dict';
import styles from './campus.module.css';

interface Props {
  placeId: number;
  name: string;
  url: string | null;
  onChange: (url: string | null) => void;
}

export function PlacePhoto({ placeId, name, url, onChange }: Props) {
  const i18n = useI18n();
  const t = gt(i18n);
  const toast = useToast();
  const qc = useQueryClient();
  const fileRef = useRef<HTMLInputElement>(null);
  const [problem, setProblem] = useState<string | null>(null);

  const upload = useMutation({
    mutationFn: (file: File) => uploadCampusPhoto(placeId, file),
    onSuccess: (res) => {
      toast.success(t('admin.campus.photo.uploaded'));
      onChange(res?.photoUrl ?? null);
      void qc.invalidateQueries({ queryKey: campusKeys.all });
    },
    onError: (e) => setProblem(adminError(i18n, e, 'admin.campus.err', 'admin.err')),
  });
  const remove = useMutation({
    mutationFn: () => deleteCampusPhoto(placeId),
    onSuccess: () => {
      toast.success(t('admin.campus.photo.removed'));
      onChange(null);
      void qc.invalidateQueries({ queryKey: campusKeys.all });
    },
    onError: (e) => setProblem(adminError(i18n, e, 'admin.campus.err', 'admin.err')),
  });

  const pick = (file: File | undefined) => {
    setProblem(null);
    if (!file) return;
    const p = validateMenuImage(file);
    if (p) return setProblem(t(`admin.campus.photo.err.${p}`));
    upload.mutate(file);
  };

  return (
    <div className={styles.photoBox} data-search-anchor="campus-photo">
      <span className={styles.photoLabel}>{t('admin.campus.photo.label')}</span>
      {url ? (
        <img className={styles.photoThumb} src={url} alt={t('admin.campus.photo.alt', { name })} loading="lazy" />
      ) : (
        <p className={styles.muted}>{t('admin.campus.photo.none')}</p>
      )}
      <div className={styles.coordActions}>
        <input
          ref={fileRef}
          className="sr-only"
          type="file"
          accept="image/jpeg,image/png,image/webp"
          aria-label={t('admin.campus.photo.input')}
          data-testid="campus-photo-file"
          onChange={(e) => {
            pick(e.target.files?.[0]);
            e.target.value = '';
          }}
        />
        <Button type="button" size="sm" variant="secondary" loading={upload.isPending} onClick={() => fileRef.current?.click()}>
          {t(url ? 'admin.campus.photo.replace' : 'admin.campus.photo.upload')}
        </Button>
        {url && (
          <Button type="button" size="sm" variant="dangerOutline" loading={remove.isPending} onClick={() => remove.mutate()}>
            {t('admin.campus.photo.remove')}
          </Button>
        )}
      </div>
      <p className={styles.muted}>{t('admin.campus.photo.hint')}</p>
      {problem && (
        <p className={styles.formInvalid} role="alert">
          {problem}
        </p>
      )}
    </div>
  );
}
