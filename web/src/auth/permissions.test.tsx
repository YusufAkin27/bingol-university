import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { RbacMe } from '../api/rbac';
import { GuardedAction, PermissionButton } from '../components/ui';
import { jsonResponse, mockFetch } from '../test/fetchMock';
import { renderWithProviders } from '../test/utils';
import { NoPermissionPage, RequirePerm, useCan } from './permissions';

afterEach(() => vi.unstubAllGlobals());

const support: RbacMe = {
  userId: 7,
  email: 's@bingol.edu.tr',
  displayName: 'Destek',
  profile: 'SUPPORT',
  pinned: false,
  permissions: ['dashboard.read', 'users.read', 'support.read', 'support.write', 'comms.single'],
};

function serve(me: RbacMe | null) {
  return mockFetch((url) => {
    if (url.endsWith('/admin/rbac/me')) {
      return me ? jsonResponse(200, me) : jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    }
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
}

function Probe({ perm }: { perm?: string }) {
  return <span data-testid="can">{String(useCan(perm))}</span>;
}

describe('useCan', () => {
  it('izin varsa true, yoksa false', async () => {
    serve(support);
    renderWithProviders(
      <>
        <Probe perm="support.write" />
      </>,
    );
    await waitFor(() => expect(screen.getByTestId('can')).toHaveTextContent('true'));
  });

  it('olmayan izin için false olur (veri geldikten sonra)', async () => {
    const fetchFn = serve(support);
    renderWithProviders(<Probe perm="users.delete" />);
    // veri gelene dek serbest (bilinmeyen = izin var), sonra false
    await waitFor(() => expect(screen.getByTestId('can')).toHaveTextContent('false'));
    expect(fetchFn).toHaveBeenCalled();
  });

  it('izin verilmezse (undefined) istek atmaz ve true döner', () => {
    const fetchFn = serve(support);
    renderWithProviders(<Probe />);
    expect(screen.getByTestId('can')).toHaveTextContent('true');
    expect(fetchFn).not.toHaveBeenCalled();
  });

  it('izin bilgisi alınamazsa arayüz serbesttir (sunucu asıl denetimi yapar)', async () => {
    const fetchFn = serve(null);
    renderWithProviders(<Probe perm="users.delete" />);
    await waitFor(() => expect(fetchFn).toHaveBeenCalled());
    expect(screen.getByTestId('can')).toHaveTextContent('true');
  });
});

describe('RequirePerm', () => {
  it('yetkisizse "yetkiniz yok" sayfasını gösterir, çocuğu göstermez', async () => {
    serve(support);
    renderWithProviders(
      <RequirePerm perm="audit.read">
        <p>GİZLİ SAYFA</p>
      </RequirePerm>,
    );
    expect(await screen.findByText('Bu sayfa için yetkiniz yok')).toBeInTheDocument();
    expect(screen.getByText('Gereken izin: audit.read')).toBeInTheDocument();
    expect(screen.queryByText('GİZLİ SAYFA')).toBeNull();
  });

  it('yetkiliyse çocuğu gösterir', async () => {
    serve(support);
    renderWithProviders(
      <RequirePerm perm="support.read">
        <p>DESTEK SAYFASI</p>
      </RequirePerm>,
    );
    expect(await screen.findByText('DESTEK SAYFASI')).toBeInTheDocument();
    expect(screen.queryByTestId('no-permission')).toBeNull();
  });

  it('NoPermissionPage tek başına render edilir', () => {
    renderWithProviders(<NoPermissionPage perm="x.y" />);
    expect(screen.getByTestId('no-permission')).toBeInTheDocument();
  });
});

describe('düğme yetkileri', () => {
  it('GuardedAction: yetkisizse devre dışı + açıklama ipucu; tıklayınca diyalog açılmaz', async () => {
    serve(support);
    const onConfirm = vi.fn(async () => undefined);
    renderWithProviders(
      <GuardedAction permission="users.delete" title="Sil" onConfirm={onConfirm}>
        Hesabı sil
      </GuardedAction>,
    );
    await screen.findByRole('button', { name: 'Hesabı sil' });
    await waitFor(() => expect(screen.getByRole('button', { name: 'Hesabı sil' })).toBeDisabled());
    const btn = screen.getByRole('button', { name: 'Hesabı sil' });
    expect(screen.getByRole('tooltip')).toHaveTextContent('Bu işlem için yetkiniz yok (gereken izin: users.delete).');
    await userEvent.click(btn);
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(onConfirm).not.toHaveBeenCalled();
  });

  it('GuardedAction: yetkiliyse tıklayınca onay diyaloğu açılır', async () => {
    serve(support);
    renderWithProviders(
      <GuardedAction permission="support.write" title="Kapat" onConfirm={async () => undefined}>
        Talebi kapat
      </GuardedAction>,
    );
    await screen.findByRole('button', { name: 'Talebi kapat' });
    await waitFor(() => expect(screen.getByRole('button', { name: 'Talebi kapat' })).toBeEnabled());
    await userEvent.click(screen.getByRole('button', { name: 'Talebi kapat' }));
    expect(await screen.findByRole('dialog')).toBeInTheDocument();
  });

  it('GuardedAction: permission verilmezse davranış değişmez (istek atılmaz)', async () => {
    const fetchFn = serve(support);
    renderWithProviders(
      <GuardedAction title="Kapat" onConfirm={async () => undefined}>
        Serbest
      </GuardedAction>,
    );
    expect(screen.getByRole('button', { name: 'Serbest' })).toBeEnabled();
    expect(fetchFn).not.toHaveBeenCalled();
  });

  it('PermissionButton: yetkisizse devre dışı, yetkiliyse tıklanabilir', async () => {
    serve(support);
    const onClick = vi.fn();
    renderWithProviders(
      <>
        <PermissionButton permission="settings.write" onClick={onClick}>
          Kaydet
        </PermissionButton>
        <PermissionButton permission="support.write" onClick={onClick}>
          Yanıtla
        </PermissionButton>
      </>,
    );
    await waitFor(() => expect(screen.getByRole('button', { name: 'Kaydet' })).toBeDisabled());
    const ok = screen.getByRole('button', { name: 'Yanıtla' });
    expect(ok).toBeEnabled();
    await userEvent.click(ok);
    expect(onClick).toHaveBeenCalledTimes(1);
  });
});
