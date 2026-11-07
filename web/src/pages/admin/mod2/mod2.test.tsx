// İçerik denetimi görselleri (mod2): veri dönüşümleri, boş/dolu durumlar, güvenli gezinme ve arama dizini.
import { fireEvent, render, screen, within } from '@testing-library/react';
import { beforeEach, describe, expect, it } from 'vitest';
import type { PollDetail } from '../../../api/adminPolls';
import type { MessageAccessRow } from '../../../api/audit';
import type { ReportView } from '../../../api/types';
import { translate } from '../../../i18n';
import { buildSearchEntries } from '../../../search/build';
import { createSearcher } from '../../../search/engine';
import { renderWithProviders } from '../../../test/utils';
import { AccessCharts, countBy } from './AccessCharts';
import { nextRowIndex, useSafeView } from './chatNav';
import { ChatMediaCharts, ChatSafeBar } from './ChatParts';
import { leaders, optionShares, pollStateSegments, ratingAverage } from './pollCharts';
import { postStateSegments, PostViewSwitch } from './PostParts2';
import { ReportQueueCharts } from './ReportQueueCharts';
import { AGE_BUCKETS, ageBucket, ageCounts, levelCounts, priorityLevel } from './reportCharts';
import { shareStats, StackedShare } from './StackedShare';
import './dict';

const NOW = Date.parse('2026-11-01T12:00:00Z');
const DAY = 86_400_000;
const ago = (days: number) => new Date(NOW - days * DAY).toISOString();

describe('rapor kuyruğu veri dönüşümü', () => {
  it('öncelik puanı Acil / Yüksek / Normal seviyesine çevrilir', () => {
    expect(priorityLevel(0)).toBe('NORMAL');
    expect(priorityLevel(29)).toBe('NORMAL');
    expect(priorityLevel(30)).toBe('HIGH');
    expect(priorityLevel(99)).toBe('HIGH');
    expect(priorityLevel(100)).toBe('URGENT');
  });

  it('bekleme süresi kovaları sınırlarda doğru ayrılır; geçersiz tarih uyarı üretmez', () => {
    expect(ageBucket(ago(0.5), NOW)).toBe('fresh');
    expect(ageBucket(ago(1), NOW)).toBe('d1_3');
    expect(ageBucket(ago(2.9), NOW)).toBe('d1_3');
    expect(ageBucket(ago(3), NOW)).toBe('d3_7');
    expect(ageBucket(ago(7), NOW)).toBe('old');
    expect(ageBucket('bozuk', NOW)).toBe('fresh');
    expect(ageCounts([{ createdAt: ago(0) }, { createdAt: ago(2) }, { createdAt: ago(30) }, { createdAt: ago(40) }], NOW)).toEqual({
      fresh: 1,
      d1_3: 1,
      d3_7: 0,
      old: 2,
    });
    expect(AGE_BUCKETS).toHaveLength(4);
  });

  it('levelCounts eksik öncelikte hata vermez', () => {
    expect(levelCounts([{ priority: 120 }, { priority: 40 }, { priority: 0 }, { priority: undefined as unknown as number }])).toEqual({
      URGENT: 1,
      HIGH: 1,
      NORMAL: 2,
    });
  });
});

const report = (id: number, over: Partial<ReportView> = {}): ReportView =>
  ({
    id,
    reporterId: 1,
    targetType: 'FEED_POST',
    targetId: id,
    reason: 'SPAM',
    note: null,
    status: 'OPEN',
    resolution: null,
    createdAt: ago(0.2),
    priority: 0,
    reasonCode: null,
    preview: null,
    hidden: false,
    hiddenBy: null,
    openReporters: 1,
    ...over,
  }) as ReportView;

describe('ReportQueueCharts', () => {
  it('eski rapor varsa uyarı cümlesi ve dağılım çubukları çıkar', () => {
    renderWithProviders(
      <ReportQueueCharts
        now={NOW}
        hasMore
        typeLabel={(k) => (k === 'USER' ? 'Kullanıcı' : 'Gönderi')}
        items={[report(1), report(2, { createdAt: ago(10), priority: 120 }), report(3, { targetType: 'USER', createdAt: ago(2) })]}
      />,
    );
    expect(screen.getByText(/1 rapor 7 günden uzun süredir bekliyor/)).toBeInTheDocument();
    expect(screen.getByRole('img', { name: /Ne kadardır bekliyorlar\?.*7 günden eski: 1 \(33%\)/ })).toBeInTheDocument();
    expect(screen.getByRole('img', { name: /Ne kadar acil\?.*Acil: 1/ })).toBeInTheDocument();
    expect(screen.getByText(/Yalnız yüklenen 3 rapora göre/)).toBeInTheDocument();
  });

  it('hepsi yeniyse sakin cümle gösterir ve "daha fazla" notu yoktur', () => {
    renderWithProviders(<ReportQueueCharts now={NOW} hasMore={false} typeLabel={() => 'x'} items={[report(1), report(2)]} />);
    expect(screen.getByText(/son bir haftada geldi/)).toBeInTheDocument();
    expect(screen.queryByText(/Yalnız yüklenen/)).toBeNull();
  });
});

describe('StackedShare', () => {
  it('yüzdeleri ve toplamı hesaplar; negatif değer sayılmaz', () => {
    expect(shareStats([{ value: 3 }, { value: 1 }])).toEqual({ total: 4, pct: [75, 25] });
    expect(shareStats([{ value: -2 }, { value: 0 }])).toEqual({ total: 0, pct: [0, 0] });
  });

  it('boşken anlaşılır yazı, doluyken etiket + sayı + yüzde (renk tek başına değil)', () => {
    const { rerender } = renderWithProviders(<StackedShare ariaLabel="Durum" segments={[{ key: 'a', label: 'Açık', value: 0, tone: 'success' }]} />);
    expect(screen.getByText('Gösterilecek veri yok.')).toBeInTheDocument();
    rerender(
      <StackedShare
        ariaLabel="Durum"
        segments={[
          { key: 'a', label: 'Açık', value: 3, tone: 'success' },
          { key: 'b', label: 'Kapalı', value: 1, tone: 'neutral' },
        ]}
      />,
    );
    const list = screen.getByRole('list', { name: 'Durum' });
    expect(within(list).getByText('Açık')).toBeInTheDocument();
    expect(within(list).getByText('75%')).toBeInTheDocument();
  });
});

describe('anket verisi', () => {
  const poll = {
    type: 'SINGLE',
    options: [
      { id: 1, text: 'Evet', position: 1 },
      { id: 2, text: 'Hayır', position: 2 },
      { id: 3, text: 'Çekimser', position: 3 },
    ],
    results: [
      { optionId: 1, count: 5, percent: 50, score: null },
      { optionId: 2, count: 5, percent: 50, score: null },
    ],
    average: null,
  } as unknown as PollDetail;

  it('durum payı dört dilim üretir', () => {
    const segs = pollStateSegments({ open: 3, closed: 4, draft: 1, cancelled: 2 }, (k) => k);
    expect(segs.map((s) => [s.key, s.value])).toEqual([
      ['open', 3],
      ['closed', 4],
      ['draft', 1],
      ['cancelled', 2],
    ]);
  });

  it('sonucu olmayan seçenek 0 oy sayılır; beraberlikte hepsi lider, oy yoksa lider yok', () => {
    const shares = optionShares(poll, (n) => `${n} yıldız`);
    expect(shares.map((s) => s.count)).toEqual([5, 5, 0]);
    expect(leaders(shares).map((s) => s.name)).toEqual(['Evet', 'Hayır']);
    expect(leaders(shares.map((s) => ({ ...s, count: 0 })))).toEqual([]);
  });

  it('puanlamada ortalama sunucudan yoksa oy sayılarından hesaplanır', () => {
    const rating = {
      type: 'RATING',
      options: [1, 2, 3, 4, 5].map((n) => ({ id: n, text: String(n), position: n })),
      results: [
        { optionId: 5, count: 3, percent: 75, score: null },
        { optionId: 1, count: 1, percent: 25, score: null },
      ],
      average: null,
    } as unknown as PollDetail;
    expect(ratingAverage(rating)).toBeCloseTo(4.0);
    expect(ratingAverage({ ...rating, average: 3.5 })).toBe(3.5);
    expect(ratingAverage({ ...rating, results: [] })).toBeNull();
    expect(optionShares(rating, (n) => `${n} yıldız`)[0].name).toBe('1 yıldız');
  });
});

describe('gönderi durum payı', () => {
  it('postCount silinmişleri içermez, gizlileri içerir', () => {
    const segs = postStateSegments({ postCount: 10, hiddenCount: 3, deletedCount: 2 }, (k) => k);
    expect(segs.map((s) => s.value)).toEqual([7, 3, 2]);
    expect(postStateSegments({ postCount: 1, hiddenCount: 5, deletedCount: 0 }, (k) => k)[0].value).toBe(0);
  });

  it('görünüm anahtarı basılı durumu bildirir ve değişiklik çağırır', () => {
    let v = 'list';
    renderWithProviders(<PostViewSwitch value="list" onChange={(x) => (v = x)} />);
    expect(screen.getByRole('button', { name: 'Liste' })).toHaveAttribute('aria-pressed', 'true');
    fireEvent.click(screen.getByRole('button', { name: 'Izgara' }));
    expect(v).toBe('grid');
  });
});

describe('sohbet medyası: güvenli gezinme', () => {
  beforeEach(() => {
    try {
      window.localStorage.removeItem('bu.admin.chatSafeView');
    } catch {
      /* yoksay */
    }
  });

  it('J/K satır gezinmesi sınırda durur; satır yoksa -1', () => {
    expect(nextRowIndex(-1, 1, 3)).toBe(0);
    expect(nextRowIndex(-1, -1, 3)).toBe(2);
    expect(nextRowIndex(2, 1, 3)).toBe(2);
    expect(nextRowIndex(0, -1, 3)).toBe(0);
    expect(nextRowIndex(0, 1, 0)).toBe(-1);
  });

  it('bulanık gösterim varsayılan açıktır, kapatılınca hatırlanır', () => {
    function Probe() {
      const [safe, setSafe] = useSafeView();
      return (
        <button type="button" onClick={() => setSafe(!safe)}>
          {safe ? 'açık' : 'kapalı'}
        </button>
      );
    }
    const first = render(<Probe />);
    expect(screen.getByRole('button')).toHaveTextContent('açık');
    fireEvent.click(screen.getByRole('button'));
    expect(screen.getByRole('button')).toHaveTextContent('kapalı');
    first.unmount();
    render(<Probe />);
    expect(screen.getByRole('button')).toHaveTextContent('kapalı');
  });

  it('güvenli gezinme çubuğu onay kutusunu ve klavye ipucunu gösterir', () => {
    let v: boolean | null = null;
    renderWithProviders(<ChatSafeBar safe onChange={(x) => (v = x)} />);
    const box = screen.getByRole('checkbox', { name: 'Görselleri bulanık göster' });
    expect(box).toBeChecked();
    fireEvent.click(box);
    expect(v).toBe(false);
    expect(screen.getByText(/sonraki ve önceki mesaja geçin/)).toBeInTheDocument();
  });

  it('medya grafiği dikkat edilecek medya yoksa bunu söyler', () => {
    renderWithProviders(
      <ChatMediaCharts stats={{ imageCount: 8, videoCount: 2, viewOnceCount: 0, deletedMessageMediaCount: 0, purgedCount: 0 }} />,
    );
    expect(screen.getByText('Dikkat edilecek medya yok.')).toBeInTheDocument();
    expect(screen.getByRole('img', { name: /Fotoğraf mı video mu\?.*Fotoğraf: 8 \(80%\)/ })).toBeInTheDocument();
  });
});

describe('mesaj erişim grafikleri', () => {
  const row = (id: number, over: Partial<MessageAccessRow> = {}) =>
    ({ id, at: ago(1), adminEmail: 'a@bingol.edu.tr', targetUserId: 5, conversationId: 9, kind: 'CONVERSATION', reason: 'Şikâyet incelemesi', ...over }) as MessageAccessRow;

  it('countBy büyükten küçüğe sayar', () => {
    expect(countBy([1, 2, 2, 3, 3, 3], (n) => String(n))).toEqual([
      { key: '3', value: 3 },
      { key: '2', value: 2 },
      { key: '1', value: 1 },
    ]);
  });

  it('kayıt yoksa hiçbir şey çizmez; sebepsiz kayıtları ayrı sayar', () => {
    const { container, rerender } = renderWithProviders(<AccessCharts rows={[]} />);
    expect(container).toBeEmptyDOMElement();
    rerender(<AccessCharts rows={[row(1), row(2, { reason: null }), row(3, { adminEmail: null })]} />);
    expect(screen.getByRole('img', { name: /Sebep yazılmış mı\?.*Sebepsiz: 1/ })).toBeInTheDocument();
    expect(screen.getByText('Bilinmeyen yönetici')).toBeInTheDocument();
  });
});

describe('arama dizini: içerik denetimi', () => {
  const entries = buildSearchEntries((k) => translate('tr', k as never));
  const s = createSearcher(entries);
  const ids = (q: string) => s.search(q).map((h) => h.item.id);

  it('"mesaj" sohbet medyası sayfasını ve mesaj erişim kayıtlarını getirir', () => {
    const r = ids('mesaj');
    expect(r).toContain('page.chatFeed');
    expect(r).toContain('page.messageAccess');
  });

  it('yazım hatası ("meaj", "sohbte") yine de sohbet sayfasını getirir', () => {
    expect(ids('meaj')).toContain('page.chatFeed');
    expect(ids('sohbte')).toContain('page.chatFeed');
  });

  it('eş anlamlılar: "yazışma" sohbet sayfasını, "bulanık" güvenli gezinmeyi bulur', () => {
    expect(ids('yazisma')).toContain('page.chatFeed');
    expect(ids('bulanik')).toContain('chatFeed.safeView');
  });

  it('rapor grafikleri, gönderi ızgarası ve anket grafiği aranabilir (yazım hatasıyla da)', () => {
    expect(ids('bekleme süresi')).toContain('reports.ageChart');
    expect(ids('aciliyet')).toContain('reports.levelChart');
    expect(ids('izgara')).toContain('posts.grid');
    expect(ids('ızgra')).toContain('posts.grid');
    expect(ids('anket grafiği')).toContain('polls.stateChart');
    expect(ids('sebepsiz erişim')).toContain('messageAccess.reasonChart');
  });
});
