import { screen, within } from '@testing-library/react';
import { Route, Routes } from 'react-router-dom';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import { prepareLegal } from './components/legalDoc';
import LegalPage from './LegalPage';

const CONTENT = [
  'TASLAK — Yayımlanmadan önce hukuk birimi tarafından incelenmelidir.',
  '',
  '1. Topladığımız Veriler',
  '- Hesap: e-posta adresi',
  '- Kullanım: tercihler',
  '',
  '2. Paylaşım',
  'Verileriniz **satılmaz**. Ayrıntı için [iletişim](/contact) sayfasına bakın.',
  '',
  '<script>alert(1)</script>',
].join('\n');

function setup(lang: 'tr' | 'en', docLang: string) {
  mockFetch((url) => {
    if (url.includes('/versions'))
      return jsonResponse(200, [
        { type: 'PRIVACY', version: 2, title: 'Gizlilik', lang: 'tr', publishedAt: '2026-10-02T10:00:00Z' },
        { type: 'PRIVACY', version: 1, title: 'Gizlilik', lang: 'tr', publishedAt: '2026-09-01T10:00:00Z' },
      ]);
    if (url.includes('/legal/PRIVACY'))
      return jsonResponse(200, {
        type: 'PRIVACY',
        version: 2,
        title: 'Gizlilik Politikası',
        lang: docLang,
        content: CONTENT,
        publishedAt: '2026-10-02T10:00:00Z',
      });
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'yok' });
  });
  return renderWithProviders(
    <Routes>
      <Route path="legal/:type" element={<LegalPage />} />
    </Routes>,
    { route: '/legal/privacy', lang },
  );
}

describe('prepareLegal', () => {
  it('numaralı satırları başlığa çevirir, TASLAK paragrafını ayıklar', () => {
    const d = prepareLegal(CONTENT);
    expect(d.draft).toBe(true);
    expect(d.toc.map((e) => e.title)).toEqual(['1. Topladığımız Veriler', '2. Paylaşım']);
    expect(d.sections[0].body).toContain('- Hesap');
    expect(d.sections.some((s) => s.body.includes('TASLAK'))).toBe(false);
  });

  it('gerçek # başlıklarını kullanır; numaralı liste başlık sayılmaz', () => {
    const d = prepareLegal('# Giriş\nmetin\n\n## Kapsam\nmetin\n\n1. bir\n2. iki');
    expect(d.toc.map((e) => e.id)).toEqual(['giris', 'kapsam']);
    expect(d.draft).toBe(false);
  });
});

describe('LegalPage', () => {
  it('markdown içeriği, içindekiler ve taslak notunu gösterir; HTML enjekte etmez', async () => {
    const { container } = setup('tr', 'tr');
    expect(await screen.findByRole('heading', { level: 2, name: '1. Topladığımız Veriler' })).toBeInTheDocument();
    const toc = screen.getByRole('navigation', { name: 'İçindekiler' });
    expect(within(toc).getAllByRole('link')).toHaveLength(2);
    expect(within(toc).getByRole('link', { name: '2. Paylaşım' })).toHaveAttribute('href', '#2-paylasim');
    expect(screen.getByText('Bu metin taslaktır')).toBeInTheDocument();
    expect(screen.getByText('satılmaz').tagName).toBe('STRONG');
    expect(screen.getByRole('link', { name: 'iletişim' })).toHaveAttribute('href', '/contact');
    expect(container.querySelector('script')).toBeNull();
    expect(screen.queryByText(/dili/)).toBeNull();
    // önceki sürümler: yalnızca güncelden küçükler
    expect(await screen.findByText(/Sürüm 1,/)).toBeInTheDocument();
    expect(screen.queryByText(/Sürüm 2, 2/)).toBeNull();
  });

  it('seçili dilde belge yoksa Türkçe gösterildiğini söyler', async () => {
    setup('en', 'tr');
    expect(await screen.findByText(/Turkish version is shown/)).toBeInTheDocument();
  });

  it('geçersiz tür için 404 sayfası', () => {
    mockFetch(() => jsonResponse(404, {}));
    renderWithProviders(
      <Routes>
        <Route path="legal/:type" element={<LegalPage />} />
      </Routes>,
      { route: '/legal/bilinmeyen' },
    );
    expect(screen.getByText('Sayfa bulunamadı')).toBeInTheDocument();
  });
});
