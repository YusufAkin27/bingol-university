// AuditTrail gerçek veriyle (W-P02): hedefe göre süzülmüş P02 satırları, özet, "tümünü aç" bağlantısı.
import { screen, waitFor } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import { AuditTrail } from './AuditTrail';

describe('AuditTrail (P02 verisi)', () => {
  it('targetType/targetId ile istenir; sebep ve özet gösterilir; tüm kayıtlara bağlanır', async () => {
    const calls: string[] = [];
    mockFetch((url) => {
      calls.push(url);
      return jsonResponse(200, {
        items: [
          {
            id: 981,
            adminId: 5,
            adminEmail: 'root@bingol.edu.tr',
            method: 'PATCH',
            path: '/api/admin/users/3/role',
            status: 204,
            at: '2026-10-28T09:12:44Z',
            ip: '10.0.0.7',
            targetType: 'USER',
            targetId: '3',
            reason: 'yetki düzeltme talebi',
            summary: 'rol -> USER',
            requestId: 'abc',
          },
        ],
        page: 0,
        totalPages: 1,
        totalItems: 1,
      });
    });
    renderWithProviders(<AuditTrail targetType="USER" targetId={3} />);
    expect(await screen.findByText('root@bingol.edu.tr')).toBeInTheDocument();
    const url = new URL(calls[0], 'http://x');
    expect(url.pathname).toBe('/api/admin/audit');
    expect(url.searchParams.get('targetType')).toBe('USER');
    expect(url.searchParams.get('targetId')).toBe('3');
    expect(screen.getByText('PATCH /api/admin/users/3/role')).toBeInTheDocument();
    expect(screen.getByText('Sebep: yetki düzeltme talebi')).toBeInTheDocument();
    expect(screen.getByText('Özet: rol -> USER')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Tüm denetim kayıtlarını aç' })).toHaveAttribute(
      'href',
      '/admin/audit?targetType=USER&targetId=3',
    );
  });

  it('kayıt yoksa boş durum, hata varsa hata durumu', async () => {
    mockFetch(() => jsonResponse(200, { items: [], page: 0, totalPages: 0, totalItems: 0 }));
    const first = renderWithProviders(<AuditTrail targetType="EVENT" targetId="5" />);
    expect(await screen.findByText('Denetim kaydı henüz yok')).toBeInTheDocument();
    first.unmount();

    mockFetch(() => jsonResponse(500, { code: 'X', message: 'x' }));
    renderWithProviders(<AuditTrail targetType="EVENT" targetId="5" />);
    await waitFor(() => expect(screen.getByText('Denetim kaydı yüklenemedi')).toBeInTheDocument());
  });
});
