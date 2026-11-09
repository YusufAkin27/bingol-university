// Yönetici "Kullanıcı ekle" penceresi: e-posta kodu istemeden doğrulanmış USER hesabı açar (sunucuda yalnız FULL yönetici).
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';
import { qk } from '../../../api';
import { createUser } from '../../../api/adminCreate';
import { Button, FormField, Input, Modal, PasswordInput, Select, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { errorMessage } from '../../../lib/errors';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MIN_PASSWORD = 6;

export function CreateUserModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const i18n = useI18n();
  const toast = useToast();
  const qc = useQueryClient();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [language, setLanguage] = useState<'tr' | 'en' | 'ar'>('tr');
  const [touched, setTouched] = useState(false);

  const emailOk = EMAIL_RE.test(email.trim());
  const passOk = password.length >= MIN_PASSWORD;

  const mut = useMutation({
    mutationFn: () =>
      createUser({ email: email.trim(), password, displayName: displayName.trim() || undefined, language }),
    onSuccess: (u) => {
      toast.success(`Kullanıcı eklendi: ${u.email}`);
      void qc.invalidateQueries({ queryKey: [...qk.users.all] });
      setEmail('');
      setPassword('');
      setDisplayName('');
      setTouched(false);
      onClose();
    },
    onError: (e) => toast.error(errorMessage(i18n, e)),
  });

  const submit = (ev: FormEvent) => {
    ev.preventDefault();
    setTouched(true);
    if (emailOk && passOk && !mut.isPending) mut.mutate();
  };

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Kullanıcı ekle"
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Vazgeç
          </Button>
          <Button type="submit" form="create-user-form" loading={mut.isPending}>
            Kullanıcıyı oluştur
          </Button>
        </>
      }
    >
      <form id="create-user-form" onSubmit={submit} noValidate data-testid="create-user-form">
        <p>
          Hesap e-posta kodu istenmeden doğrulanmış olarak açılır. Şifreyi kullanıcıya güvenli bir yolla
          iletin.
        </p>
        <FormField
          label="E-posta"
          required
          error={touched && !emailOk ? 'Geçerli bir e-posta yazın.' : undefined}
        >
          <Input type="email" autoComplete="off" value={email} onChange={(e) => setEmail(e.target.value)} />
        </FormField>
        <FormField label="Ad soyad (isteğe bağlı)">
          <Input value={displayName} maxLength={100} onChange={(e) => setDisplayName(e.target.value)} />
        </FormField>
        <FormField
          label="Şifre"
          required
          hint={`En az ${MIN_PASSWORD} karakter`}
          error={touched && !passOk ? `Şifre en az ${MIN_PASSWORD} karakter olmalı.` : undefined}
        >
          <PasswordInput
            autoComplete="new-password"
            maxLength={64}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            showLabel="Göster"
            hideLabel="Gizle"
          />
        </FormField>
        <FormField label="Dil">
          <Select value={language} onChange={(e) => setLanguage(e.target.value as 'tr' | 'en' | 'ar')}>
            <option value="tr">Türkçe</option>
            <option value="en">English</option>
            <option value="ar">العربية</option>
          </Select>
        </FormField>
      </form>
    </Modal>
  );
}
