import { screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import { FEATURES } from './components/features';
import { buildNewFaq, NEW_FAQ_IDS } from './components/newFaq';
import FaqPage from './FaqPage';
import FeaturesPage from './FeaturesPage';
import LegalListPage from './LegalListPage';
import { dictionaries } from '../../i18n';
import { translate } from '../../i18n';

describe('Tanıtım sitesi: yeni özellikler', () => {
  it('özellikler listesi yeni başlıkları içerir', () => {
    mockFetch(() => jsonResponse(200, {}));
    renderWithProviders(<FeaturesPage />);
    for (const title of [
      'Etkinlik başvurusu ve kabul',
      'Kulüp yetkileri',
      'Sohbette görsel paylaşımı',
      'Gizlilik ayarları',
      'Şifreli iletim ve saklama',
    ]) {
      expect(screen.getByRole('heading', { name: title })).toBeInTheDocument();
    }
  });

  it('her özelliğin başlık ve metni üç dilde vardır', () => {
    for (const f of FEATURES) {
      for (const lang of ['tr', 'en', 'ar'] as const) {
        expect(dictionaries[lang][f.title].trim()).not.toBe('');
        expect(dictionaries[lang][f.text].trim()).not.toBe('');
      }
    }
  });

  it('SSS sunucu yanıtından bağımsız olarak yeni özellik sorularını gösterir', async () => {
    mockFetch(() => jsonResponse(200, []));
    renderWithProviders(<FaqPage />);
    expect(await screen.findByRole('button', { name: 'Etkinliğe nasıl başvururum?' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Yöneticiler mesajlarımı okuyabilir mi?' })).toBeInTheDocument();
    expect(screen.getByTestId('faq-new').textContent?.toLowerCase()).not.toContain('uçtan uca');
  });

  it('yeni SSS kimlikleri negatif ve benzersizdir', () => {
    const items = buildNewFaq((k) => translate('tr', k));
    expect(items).toHaveLength(NEW_FAQ_IDS.length);
    expect(new Set(items.map((i) => i.id)).size).toBe(items.length);
    expect(items.every((i) => i.id < 0 && i.question && i.answer)).toBe(true);
  });

  it('yasal sayfada yönetici erişim bildirimi taslak ve hukuki inceleme notuyla görünür', async () => {
    mockFetch(() => jsonResponse(200, []));
    renderWithProviders(<LegalListPage />);
    const notice = await screen.findByTestId('admin-access-notice');
    expect(notice).toHaveTextContent('Yönetici gerekçeli ve denetimli erişimi');
    expect(notice).toHaveTextContent('taslaktır');
    expect(notice).toHaveTextContent('hukuki inceleme');
  });
});
