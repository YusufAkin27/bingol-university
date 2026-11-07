// PANEL-topluluk: grafik veri dönüşümleri, özet bileşenleri, kulüp durum dağılımı ve arama dizini.
import { screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { translate } from '../../../i18n';
import { buildSearchEntries } from '../../../search/build';
import { createSearcher } from '../../../search/engine';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import ClubAuditPage from '../ClubAuditPage';
import ClubsManagePage from '../ClubsManagePage';
import CommunitiesAdminPage from '../CommunitiesAdminPage';
import CommunityCategoriesPage from '../CommunityCategoriesPage';
import EventsAdminPage from '../EventsAdminPage';
import { ApplicationsSummary, AttendanceSummaryView } from '../events/ops/OpsSummaries';
import {
  ALMOST_FULL_PCT,
  attendanceNotStarted,
  attendanceRatio,
  occupancyRows,
  oldestWaitDays,
  tally,
  waitDays,
} from './tpLogic';

afterEach(() => vi.restoreAllMocks());

const NOW = new Date('2030-06-10T12:00:00Z');

describe('tpLogic: bekleme süresi', () => {
  it('tam gün sayar; gelecek ve bozuk tarih 0', () => {
    expect(waitDays('2030-06-07T12:00:00Z', NOW)).toBe(3);
    expect(waitDays('2030-06-10T01:00:00Z', NOW)).toBe(0);
    expect(waitDays('2031-01-01T00:00:00Z', NOW)).toBe(0);
    expect(waitDays('bozuk', NOW)).toBe(0);
  });
  it('en eski kaydın gününü verir; boş liste null', () => {
    expect(oldestWaitDays([], NOW)).toBeNull();
    expect(oldestWaitDays([{ createdAt: '2030-06-09T12:00:00Z' }, { createdAt: '2030-06-02T12:00:00Z' }], NOW)).toBe(8);
  });
});

describe('tpLogic: etkinlik doluluğu', () => {
  const ev = (id: number, capacity: number | null, going: number) => ({ id, title: `E${id}`, capacity, goingCount: going });
  it('kontenjansız/0 kontenjanlıları dışlar, doluluğa göre azalan sıralar, aşımı 100 üstü yazar', () => {
    const rows = occupancyRows([ev(1, null, 40), ev(2, 0, 5), ev(3, 100, 50), ev(4, 50, 60), ev(5, 10, 9)]);
    expect(rows.map((r) => r.id)).toEqual([4, 5, 3]);
    expect(rows[0]?.pct).toBe(120);
    expect(rows.filter((r) => r.pct >= ALMOST_FULL_PCT).map((r) => r.id)).toEqual([4, 5]);
  });
});

describe('tpLogic: yoklama ve sayım', () => {
  it('gelme oranı katılacak sayısına bölünür; katılacak yoksa null', () => {
    expect(attendanceRatio({ going: 10, present: 4, absent: 1, unmarked: 5, walkIns: 0 })).toBe(0.4);
    expect(attendanceRatio({ going: 0, present: 0, absent: 0, unmarked: 0, walkIns: 2 })).toBeNull();
    expect(attendanceRatio({ going: 2, present: 5, absent: 0, unmarked: 0, walkIns: 0 })).toBe(1);
    expect(attendanceNotStarted({ going: 3, present: 0, absent: 0, unmarked: 3, walkIns: 0 })).toBe(true);
  });
  it('tally çoktan aza sıralar, boş anahtarı atlar', () => {
    const rows = [{ k: 'a' }, { k: 'b' }, { k: 'a' }, { k: null }];
    const out = tally(rows, (r) => r.k, (k) => k.toUpperCase());
    expect(out.map((o) => [o.label, o.count])).toEqual([
      ['A', 2],
      ['B', 1],
    ]);
  });
});

describe('Başvuru ve yoklama özetleri', () => {
  it('başvuru özeti: kapasiteli etkinlikte halka + cümle + boş yer', () => {
    renderWithProviders(
      <ApplicationsSummary
        s={{ mode: 'APPROVAL', capacity: 20, goingCount: 15, seatsLeft: 5, pending: 3, accepted: 15, waitlisted: 0, rejected: 1, cancelled: 0 }}
      />,
    );
    const box = screen.getByTestId('app-summary');
    expect(within(box).getByRole('progressbar', { name: /15 \/ 20 kişi katılıyor/ })).toHaveAttribute('aria-valuenow', '75');
    expect(box).toHaveTextContent('3 başvuru karar bekliyor');
    expect(box).toHaveTextContent('Boş yer');
    expect(box).toHaveTextContent('5');
  });
  it('başvuru özeti: sınırsız etkinlikte halka çizilmez, "Sınırsız" yazar', () => {
    renderWithProviders(
      <ApplicationsSummary
        s={{ mode: 'OPEN', capacity: null, goingCount: 4, seatsLeft: null, pending: 0, accepted: 0, waitlisted: 0, rejected: 0, cancelled: 0 }}
      />,
    );
    const box = screen.getByTestId('app-summary');
    expect(within(box).queryByRole('progressbar')).toBeNull();
    expect(box).toHaveTextContent('kontenjan sınırsız');
    expect(box).toHaveTextContent('Sınırsız');
  });
  it('yoklama özeti: oran cümlesi ve halka; yoklama başlamadıysa bunu söyler', () => {
    const { unmount } = renderWithProviders(
      <AttendanceSummaryView sm={{ going: 10, present: 7, absent: 1, unmarked: 2, walkIns: 1 }} />,
    );
    let box = screen.getByTestId('att-summary');
    expect(box).toHaveTextContent('10 kişiden 7 kişi geldi (%70)');
    expect(box).toHaveTextContent('1 kişi kapıdan geldi');
    expect(within(box).getByRole('progressbar')).toHaveAttribute('aria-valuenow', '70');
    unmount();
    renderWithProviders(<AttendanceSummaryView sm={{ going: 6, present: 0, absent: 0, unmarked: 6, walkIns: 0 }} />);
    box = screen.getByTestId('att-summary');
    expect(box).toHaveTextContent('Yoklama alınmaya başlanmadı');
  });
});

const club = (id: number, status: string, over: Record<string, unknown> = {}) => ({
  id,
  name: `Kulup ${id}`,
  slug: `k-${id}`,
  category: null,
  status,
  visibility: 'PUBLIC',
  joinPolicy: 'OPEN',
  ownerId: 1,
  ownerName: 'S',
  ownerEmail: 's@bingol.edu.tr',
  coverUrl: null,
  logoUrl: null,
  memberCount: 10,
  pendingCount: 0,
  openReportCount: 0,
  eventCount: 0,
  createdAt: '2030-06-01T10:00:00Z',
  updatedAt: '2030-06-01T10:00:00Z',
  ...over,
});

describe('Kulüp listesi: durum dağılımı tüm sayfaları kapsar', () => {
  it('her durum için toplam sayısı okunur ve cümle ile onay kuyruğu düğmesi çıkar', async () => {
    const urls: string[] = [];
    mockFetch((url) => {
      urls.push(url);
      const m = /status=([A-Z_]+)/.exec(url);
      const st = m?.[1];
      const total = st === 'ACTIVE' ? 40 : st === 'PENDING_REVIEW' ? 7 : st === 'HIDDEN' ? 2 : st === 'REJECTED' ? 1 : 50;
      const size = Number(/size=(\d+)/.exec(url)?.[1] ?? 20);
      const items = Array.from({ length: Math.min(size, 3) }, (_, i) => club(i + 1, st ?? 'ACTIVE'));
      return jsonResponse(200, { items, page: 0, size, total, totalPages: Math.ceil(total / size) });
    });
    renderWithProviders(<ClubsManagePage />, { route: '/admin/communities' });
    expect(await screen.findByText(/Süzgece uyan 50 kulüpten 40 tanesi yayında, 7 tanesi onay bekliyor/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Onay kuyruğunu aç (7)' })).toBeInTheDocument();
    for (const st of ['ACTIVE', 'PENDING_REVIEW', 'HIDDEN', 'REJECTED']) {
      expect(urls.some((u) => u.includes(`status=${st}`) && u.includes('size=1'))).toBe(true);
    }
  });
});

describe('Onay kuyruğu: bekleme süresi', () => {
  it('en eski başvurunun kaç gündür beklediğini söyler ve 3 günü aşanı uyarır', async () => {
    const old = new Date(Date.now() - 5 * 24 * 3600 * 1000).toISOString();
    mockFetch(() =>
      jsonResponse(200, {
        items: [
          {
            id: 1,
            name: 'Satranç',
            slug: 'satranc',
            description: null,
            category: null,
            ownerId: 3,
            joinPolicy: 'OPEN',
            visibility: 'PUBLIC',
            status: 'PENDING_REVIEW',
            memberCount: 1,
            createdAt: old,
          },
        ],
        nextCursor: null,
      }),
    );
    renderWithProviders(<CommunitiesAdminPage />, { route: '/admin/communities' });
    expect(await screen.findByText(/en eski başvuru 5 gündür bekliyor/)).toBeInTheDocument();
    expect(screen.getByText('Yavaşladı: 5 gündür bekliyor')).toBeInTheDocument();
  });
});

describe('Etkinlik listesi: doluluk sıralaması', () => {
  it('kontenjanı %85 ve üstü dolan etkinlikleri yüzde ile sıralar', async () => {
    const ev = (id: number, title: string, capacity: number | null, going: number) => ({
      id,
      title,
      description: null,
      startsAt: '2030-11-20T10:00:00Z',
      endsAt: '2030-11-20T12:00:00Z',
      location: 'Salon',
      coverUrl: null,
      capacity,
      goingCount: going,
      interestedCount: null,
      communityId: 1,
      communityName: 'Kulüp',
      createdBy: 2,
      organizerName: 'Ali',
      status: 'ACTIVE',
      createdAt: '2030-01-01T00:00:00Z',
    });
    mockFetch(() =>
      jsonResponse(200, {
        items: [ev(1, 'Rahat Etkinlik', 100, 10), ev(2, 'Dolu Etkinlik', 50, 49), ev(3, 'Taşan Etkinlik', 20, 25), ev(4, 'Sınırsız', null, 9)],
        nextCursor: null,
      }),
    );
    renderWithProviders(<EventsAdminPage />, { route: '/admin/events?status=ACTIVE' });
    const list = await screen.findByRole('list', { name: 'Etkinlik doluluk sıralaması' });
    const rows = within(list).getAllByRole('listitem');
    expect(rows).toHaveLength(2);
    expect(rows[0]).toHaveTextContent('Taşan Etkinlik');
    expect(rows[0]).toHaveTextContent('%125');
    expect(rows[1]).toHaveTextContent('Dolu Etkinlik');
    expect(rows[1]).toHaveTextContent('%98');
  });
});

describe('Kulüp denetimi: grafikler', () => {
  it('tür dağılımı çubuğu ve en çok işlem yapanlar sıralaması çizilir', async () => {
    const row = (id: number, action: string, actorId: number, actorName: string) => ({
      id,
      action,
      actorId,
      actorName,
      targetUserId: null,
      targetName: null,
      detail: null,
      createdAt: '2030-06-10T10:00:00Z',
    });
    mockFetch(() =>
      jsonResponse(200, {
        items: [
          row(1, 'MEMBER_APPROVED', 7, 'Ayşe'),
          row(2, 'MEMBER_REMOVED', 7, 'Ayşe'),
          row(3, 'INVITE_CREATED', 8, 'Mehmet'),
          row(4, 'ALIEN_ACTION', 7, 'Ayşe'),
        ],
        nextCursor: null,
      }),
    );
    renderWithProviders(<ClubAuditPage />, { route: '/admin/communities/audit?communityId=3&name=Satran%C3%A7' });
    const list = await screen.findByRole('list', { name: 'İşlem sayısına göre yöneticiler' });
    const rows = within(list).getAllByRole('listitem');
    expect(rows[0]).toHaveTextContent('Ayşe');
    expect(rows[0]).toHaveTextContent('3 işlem');
    expect(rows[1]).toHaveTextContent('Mehmet');
    expect(screen.getByRole('img', { name: 'Denetim kayıtlarının tür dağılımı' })).toBeInTheDocument();
    expect(screen.getByText(/Diğer/)).toBeInTheDocument();
  });
});

describe('Kulüp kategorileri: özet cümlesi', () => {
  it('aktif/pasif/kullanılmayan sayısını ve en çok kullanılanı söyler', async () => {
    const cat = (id: number, nameTr: string, active: boolean, usageCount: number) => ({
      id,
      key: `k${id}`,
      nameTr,
      nameEn: '',
      nameAr: '',
      icon: null,
      active,
      sortOrder: id,
      usageCount,
    });
    mockFetch(() =>
      jsonResponse(200, {
        items: [cat(1, 'Spor', true, 9), cat(2, 'Sanat', true, 0), cat(3, 'Eski', false, 0)],
        activeCount: 2,
        maxActive: 8,
      }),
    );
    renderWithProviders(<CommunityCategoriesPage />, { route: '/admin/community-categories' });
    expect(await screen.findByText(/2 kategori aktif, 1 kategori pasif\. 2 kategoriyi hiçbir kulüp kullanmıyor/)).toBeInTheDocument();
    expect(screen.getByText(/En çok kullanılan: Spor \(9 kulüp\)/)).toBeInTheDocument();
  });
});

describe('Arama dizini: topluluk ve etkinlik', () => {
  const entries = buildSearchEntries((k) => translate('tr', k));
  const searcher = createSearcher(entries);
  const pagesOf = (q: string) => searcher.search(q).slice(0, 8).map((h) => h.item.pageId);
  const idsOf = (q: string) => searcher.search(q).slice(0, 8).map((h) => h.item.id);

  it('"yoklama" etkinlikler sayfasını getirir; yazım hatalı "yoklma" da', () => {
    expect(pagesOf('yoklama')).toContain('events');
    expect(pagesOf('yoklma')).toContain('events');
    expect(idsOf('yoklama')).toContain('events.attendanceTab');
  });
  it('"kontenjan" doluluk sıralamasını, "kontenjn" (hatalı) da', () => {
    expect(idsOf('kontenjan')).toContain('events.occupancy');
    expect(idsOf('kontenjn')).toContain('events.occupancy');
  });
  it('"kulüp üyeleri" ve eş anlamlı "topluluk üyesi" kulüpler sayfasını getirir', () => {
    expect(idsOf('kulüp üyeleri')).toContain('communities.members');
    expect(pagesOf('başkanlık devri')).toContain('communities');
    expect(pagesOf('kulubu sil')).toContain('communities');
  });
  it('"sertifika" ve "yedek liste" etkinlik çekmece sekmelerini bulur', () => {
    expect(idsOf('sertifika')).toContain('events.certificatesTab');
    expect(idsOf('yedek liste')).toContain('events.applicationsTab');
  });
  it('"kim ne yaptı" kulüp denetimine götürür', () => {
    expect(pagesOf('kim ne yaptı')).toContain('clubAudit');
  });
  it('derin bağlantılar anchor taşır', () => {
    const occ = entries.find((e) => e.id === 'events.occupancy');
    expect(occ?.to).toContain('#ev-occupancy');
    const dist = entries.find((e) => e.id === 'communities.dist');
    expect(dist?.to).toContain('#club-dist');
  });
});

describe('Ek sözlük', () => {
  it('modül yüklenince ek sözlük kayıtlıdır', async () => {
    renderWithProviders(<ApplicationsSummary s={{ mode: 'OPEN', capacity: null, goingCount: 1, seatsLeft: null, pending: 0, accepted: 0, waitlisted: 0, rejected: 0, cancelled: 0 }} />);
    await waitFor(() => expect(screen.getByTestId('app-summary')).not.toHaveTextContent('admin.tp.'));
  });
});
