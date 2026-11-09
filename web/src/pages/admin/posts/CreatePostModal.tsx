// Yönetici "Gönderi oluştur" penceresi: gönderi yöneticinin KENDİ hesabıyla Keşfet'te paylaşılır (1 fotoğraf VEYA 1 video).
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { createPost, uploadPostMedia } from '../../../api/adminCreate';
import { Button, FormField, Modal, Textarea, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { errorMessage } from '../../../lib/errors';

const MAX_BYTES = 50 * 1024 * 1024;
const ACCEPT = 'image/jpeg,image/png,image/webp,video/mp4,video/quicktime,video/webm';

export function CreatePostModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const i18n = useI18n();
  const toast = useToast();
  const qc = useQueryClient();
  const [text, setText] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [touched, setTouched] = useState(false);

  const preview = useMemo(() => (file ? URL.createObjectURL(file) : null), [file]);
  useEffect(() => () => (preview ? URL.revokeObjectURL(preview) : undefined), [preview]);

  const fileError = !file
    ? 'Bir fotoğraf ya da video seçin.'
    : file.size > MAX_BYTES
      ? 'Dosya 50 MB sınırını aşıyor.'
      : null;

  const mut = useMutation({
    mutationFn: async () => {
      const media = await uploadPostMedia(file as File);
      return createPost(text, [media.id]);
    },
    onSuccess: () => {
      toast.success('Gönderi paylaşıldı.');
      void qc.invalidateQueries({ queryKey: ['adminPosts'] });
      setText('');
      setFile(null);
      setTouched(false);
      onClose();
    },
    onError: (e) => toast.error(errorMessage(i18n, e)),
  });

  const submit = (ev: FormEvent) => {
    ev.preventDefault();
    setTouched(true);
    if (!fileError && !mut.isPending) mut.mutate();
  };

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Gönderi oluştur"
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Vazgeç
          </Button>
          <Button type="submit" form="create-post-form" loading={mut.isPending}>
            Paylaş
          </Button>
        </>
      }
    >
      <form id="create-post-form" onSubmit={submit} noValidate data-testid="create-post-form">
        <p>Gönderi, giriş yaptığınız yönetici hesabıyla paylaşılır.</p>
        <FormField
          label="Fotoğraf veya video"
          required
          error={touched ? (fileError ?? undefined) : undefined}
          hint="En çok 50 MB; video en çok 60 sn."
        >
          <input type="file" accept={ACCEPT} onChange={(e) => setFile(e.target.files?.[0] ?? null)} />
        </FormField>
        {preview && file && (
          <div>
            {file.type.startsWith('video/') ? (
              <video src={preview} controls style={{ maxWidth: '100%', maxHeight: 240 }} />
            ) : (
              <img
                src={preview}
                alt="Seçilen görsel önizlemesi"
                style={{ maxWidth: '100%', maxHeight: 240 }}
              />
            )}
          </div>
        )}
        <FormField label="Metin (isteğe bağlı)">
          <Textarea rows={4} value={text} onChange={(e) => setText(e.target.value)} />
        </FormField>
      </form>
    </Modal>
  );
}
