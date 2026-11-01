// COMM: ada göre seçici, telefonda ajanda, doluluk çubuğu, sınav çakışması, haber kartları.
import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import AcademicCalendarPage from '../academic/AcademicCalendarPage';
import ClubAuditPage from '../ClubAuditPage';
import EventApplicationsPage from '../EventApplicationsPage';
import EventsAdminPage from '../EventsAdminPage';
import NewsAdminPage from '../NewsAdminPage';
import { FillBar, StackedBar } from './Summary';

afterEach(() => vi.restoreAllMocks());

function narrow(on: boolean) {
  vi.spyOn(window, 'matchMedia').mockImplementation(
    (query: string) =>
      ({
        matches: on && /max-width/.test(query),
        media: query,
        onchange: null,
        addEventListener: () => {},
        removeEventListener: () => {},
        addListener: () => {},
        removeListener: () => {},
        dispatchEvent: () => false,
      }) as unknown as MediaQueryList,
  );
}

describe('FillBar ve StackedBar', () => {
  it('doluluk çubuğu yüzdeyi yazı ve erişilebilir değer olarak taşır', () => {
    renderWithProviders(<FillBar value={187} max={200} label="187 / 200 kişi (%94 dolu)" />);
    expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '94');
    expect(screen.getByText('187 / 200 kişi (%94 dolu)')).toBeInTheDocument();
  });

  it('yığın çubuk yalnız dolu parçaları etiketler', () => {
    renderWithProviders(
      <StackedBar
        ariaLabel="dağılım"
        parts={[
          { key: 'a', label: 'Bekleyen', value: 3, tone: 'warning' },
          { key: 'b', label: 'Reddedilen', value: 0, tone: 'danger' },
        ]}
      />,
    );
    expect(screen.getByText(/Bekleyen/)).toBeInTheDocument();
    expect(screen.queryByText(/Reddedilen/)).toBeNull();
  });
});

describe('Etkinlik başvuruları: ada göre seçici', () => {
  it('2 harften önce istek atmaz; yazınca etkinlikleri listeler ve seçimi adrese yazar', async () => {
    const urls: string[] = [];
    mockFetch((url) => {
      urls.push(url);
      return jsonResponse(200, {
        items: [
          {
            id: 7,
            title: 'Bahar Şenliği',
            startsAt: '2026-11-20T10:00:00Z',
            communityName: 'Müzik Kulübü',
            status: 'ACTIVE',
          },
        ],
        nextCursor: null,
      });
    });
    renderWithProviders(<EventApplicationsPage />, { route: '/admin/events/applications' });
    expect(urls).toHaveLength(0);
    await userEvent.type(screen.getByRole('searchbox', { name: 'Etkinliği seçin' }), 'Ba');
    const option = await screen.findByRole('button', { name: /Bahar Şenliği/ });
    expect(urls.some((u) => u.includes('q=Ba'))).toBe(true);
    await userEvent.click(option);
    expect(await screen.findByText('Bahar Şenliği')).toBeInTheDocument();
  });
});

describe('Kulüp denetimi: ada göre seçici', () => {
  it('kulüp adı yazılınca sonuçları gösterir', async () => {
    mockFetch(() =>
      jsonResponse(200, {
        items: [{ id: 3, name: 'Satranç Kulübü', memberCount: 12, ownerName: 'Ayşe', ownerEmail: 'a@bingol.edu.tr' }],
        page: 0,
        size: 8,
        total: 1,
        totalPages: 1,
      }),
    );
    renderWithProviders(<ClubAuditPage />, { route: '/admin/communities/audit' });
    await userEvent.type(screen.getByRole('searchbox', { name: 'Kulübü seçin' }), 'Sat');
    expect(await screen.findByRole('button', { name: /Satranç Kulübü/ })).toBeInTheDocument();
  });
});

describe('Etkinlikler: doluluk', () => {
  it('kontenjanlı etkinlikte kişi sayısı ve yüzde yazılır', async () => {
    mockFetch(() =>
      jsonResponse(200, {
        items: [
          {
            id: 1,
            title: 'Kariyer Günü',
            description: null,
            startsAt: '2030-11-20T10:00:00Z',
            endsAt: '2030-11-20T12:00:00Z',
            location: 'Salon',
            coverUrl: null,
            capacity: 200,
            goingCount: 187,
            interestedCount: null,
            communityId: 2,
            communityName: 'Kariyer Kulübü',
            createdBy: 5,
            organizerName: 'Ali',
            status: 'ACTIVE',
            createdAt: '2026-10-01T10:00:00Z',
            pendingCount: 14,
          },
        ],
        nextCursor: null,
      }),
    );
    renderWithProviders(<EventsAdminPage />, { route: '/admin/events?status=ACTIVE' });
    expect(await screen.findByText('187 / 200 kişi (%94 dolu)')).toBeInTheDocument();
    expect(screen.getByText(/14 başvuru karar bekliyor/)).toBeInTheDocument();
  });
});

describe('Akademik takvim: telefonda ajanda', () => {
  it('dar ekranda ay görünümü 7 sütunlu ızgara yerine gün gün liste verir', async () => {
    narrow(true);
    const d = new Date();
    const day = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-15`;
    mockFetch(() =>
      jsonResponse(200, {
        items: [
          {
            id: 9,
            kind: 'VIZE',
            title: 'Ara sınav haftası',
            startsAt: `${day}T00:00:00`,
            endsAt: null,
            allDay: true,
            note: null,
            scopeDepartment: null,
            published: true,
          },
        ],
        total: 1,
        page: 0,
        size: 100,
      }),
    );
    renderWithProviders(<AcademicCalendarPage />, { route: '/admin/academic/calendar?view=month' });
    const agenda = await screen.findByTestId('agenda');
    expect(within(agenda).getByText('Ara sınav haftası')).toBeInTheDocument();
    expect(screen.queryByRole('grid')).toBeNull();
  });
});

describe('Haberler: telefonda kart görünümü', () => {
  it('dar ekranda tablo yerine kart yığını çizer ve gizle düğmesi etiketli kalır', async () => {
    narrow(true);
    mockFetch((url) => {
      if (url.includes('/admin/news')) {
        return jsonResponse(200, {
          items: [
            { id: 1, type: 'HABER', title: 'Üniversitemizde yeni dönem', summary: null, url: 'https://x/1', imageUrl: null, publishedDate: '2026-10-01', hidden: false },
          ],
          page: 0,
          totalPages: 1,
          totalItems: 1,
        });
      }
      return jsonResponse(200, {});
    });
    renderWithProviders(<NewsAdminPage />);
    expect(await screen.findByText('Üniversitemizde yeni dönem')).toBeInTheDocument();
    expect(screen.queryByRole('table')).toBeNull();
    expect(screen.getByRole('button', { name: /^Gizle: Üniversitemizde/ })).toBeInTheDocument();
  });
});
