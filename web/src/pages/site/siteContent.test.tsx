// SITE-ICERIK: genel SSS (15 soru, 3 dil), kanca ile açılış, JSON-LD birebirliği ve iç bağlantılar.
import { screen, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { dictionaries } from '../../i18n/all';
import type { TranslationKey } from '../../i18n';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import AboutPage from './AboutPage';
import FaqPage from './FaqPage';
import FeaturesPage from './FeaturesPage';
import { faqLd, plainAnswer } from './components/jsonLd';
import { buildGeneralFaq, GENERAL_FAQ_IDS } from './components/newFaq';
import MenuPage from './MenuPage';
import NewsListPage from './NewsListPage';

const LANGS = ['tr', 'en', 'ar'] as const;
const LINK_RE = /\]\((\/[a-z-]*(?:#[a-z-]+)?)\)/g;
const KNOWN = new Set(['/about', '/download', '/contact', '/menu', '/news', '/features', '/privacy', '/data-request', '/delete-account']);

describe('Genel SSS içeriği', () => {
  it('15 soru; her biri üç dilde dolu, cevap <= 3 cümle, bağlantılar bilinen rotalara gider', () => {
    expect(GENERAL_FAQ_IDS).toHaveLength(15);
    for (const lang of LANGS) {
      const dict = dictionaries[lang] as Record<string, string>;
      for (const item of buildGeneralFaq((k: TranslationKey) => dict[k])) {
        expect(item.question.trim(), `${lang} ${item.anchor} q`).not.toBe('');
        expect(item.answer.trim(), `${lang} ${item.anchor} a`).not.toBe('');
        const plain = plainAnswer(item.answer);
        // kısaltmalar (SKS, bingol.edu.tr, Profil > ...) cümle saymayı bozmasın: yalnız ". " / "。" sonrası büyük harf ya da Arapça soru işareti
        const sentences = plain.split(/(?<=[.!?؟])\s+/).filter(Boolean);
        expect(sentences.length, `${lang} ${item.anchor}: ${plain}`).toBeLessThanOrEqual(3);
        for (const m of item.answer.matchAll(LINK_RE)) expect(KNOWN.has(m[1].split('#')[0]), `${lang} ${m[1]}`).toBe(true);
      }
    }
  });

  it('JSON-LD yanıtı bağlantı sözdizimi içermez, görünen düz metne eşittir', () => {
    const items = buildGeneralFaq((k: TranslationKey) => (dictionaries.tr as Record<string, string>)[k]);
    const ld = faqLd(items) as { mainEntity: { acceptedAnswer: { text: string } }[] };
    ld.mainEntity.forEach((q, i) => {
      expect(q.acceptedAnswer.text).toBe(plainAnswer(items[i].answer));
      expect(q.acceptedAnswer.text).not.toMatch(/\]\(|\[/);
    });
  });

  it('SSS sayfası genel soruları gösterir; yanıttaki bağlantı dil önekli; kalori kancası soruyu açar', async () => {
    mockFetch(() => jsonResponse(200, []));
    renderWithProviders(<FaqPage />, { route: '/tr/faq#faq-calorie' });
    const general = await screen.findByTestId('faq-general');
    const q = within(general).getByRole('button', { name: 'Yemek kalorileri nasıl hesaplanıyor?' });
    expect(q).toHaveAttribute('aria-expanded', 'true');
    expect(general.querySelector('#faq-calorie')).toBeTruthy();
    // kapalı soruların yanıtındaki bağlantılar da dil önekli (hidden olsa da DOM'dadır)
    const del = general.querySelector('a[href="/tr/delete-account"]');
    expect(del?.textContent).toBe('hesap silme sayfasına');
  });
});

describe('İç bağlantılar', () => {
  const hrefs = () => [...document.querySelectorAll('a')].map((a) => a.getAttribute('href'));

  it('Özellikler: indirme ve yemek listesi', () => {
    mockFetch(() => jsonResponse(200, {}));
    renderWithProviders(<FeaturesPage />, { route: '/tr/features' });
    expect(hrefs()).toEqual(expect.arrayContaining(['/tr/download', '/tr/menu']));
  });

  it('Haberler: yemek listesi ve indirme', async () => {
    mockFetch(() => jsonResponse(200, { items: [], page: 0, totalPages: 0, totalItems: 0 }));
    renderWithProviders(<NewsListPage />, { route: '/tr/news' });
    expect(await screen.findByText('Bingöl Üniversitesi yemek listesi')).toBeInTheDocument();
    expect(hrefs()).toEqual(expect.arrayContaining(['/tr/menu', '/tr/download']));
  });

  it('Yemek listesi: kalori açıklaması görünür; SSS kancası ve haberler bağlantısı', async () => {
    mockFetch(() => jsonResponse(200, []));
    renderWithProviders(<MenuPage />, { route: '/tr/menu' });
    expect(screen.getByRole('heading', { name: 'Kalori ve veriler nereden geliyor?' })).toBeInTheDocument();
    expect(screen.getByText(/kalori değerlerini yönetici yemek başına girer/i)).toBeInTheDocument();
    expect(hrefs()).toEqual(expect.arrayContaining(['/tr/faq#faq-calorie', '/tr/news']));
  });

  it('Hakkımızda: iletişim sayfasına bağlantı (iletişim bilgisi olmasa da)', () => {
    mockFetch(() => jsonResponse(200, {}));
    renderWithProviders(<AboutPage />, { route: '/tr/about' });
    expect(screen.getByRole('link', { name: 'İletişim sayfasından bize ulaşın' })).toHaveAttribute('href', '/tr/contact');
  });
});
