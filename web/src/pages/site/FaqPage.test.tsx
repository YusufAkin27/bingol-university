import { screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import { filterFaq } from './components/faqFilter';
import FaqPage from './FaqPage';

const GROUPS = [
  {
    category: 'Hesap',
    items: [
      { id: 1, question: 'Şifremi unuttum, ne yapmalıyım?', answer: 'Giriş ekranından **şifre sıfırlama** isteyin.' },
      { id: 2, question: 'Kimler kayıt olabilir?', answer: 'Yalnızca bingol.edu.tr hesapları.' },
    ],
  },
  { category: 'Bildirimler', items: [{ id: 3, question: 'Bildirimleri nasıl kapatırım?', answer: 'Profil ayarlarından.' }] },
];

describe('filterFaq', () => {
  it('aksan ve büyük/küçük harf farkını yok sayar, tüm sözcükleri arar', () => {
    expect(filterFaq(GROUPS, 'SIFRE')[0].items.map((i) => i.id)).toEqual([1]);
    expect(filterFaq(GROUPS, 'bildirim kapat')).toHaveLength(1);
    expect(filterFaq(GROUPS, 'yokböyle')).toEqual([]);
    expect(filterFaq(GROUPS, '  ')).toBe(GROUPS);
  });
});

describe('FaqPage', () => {
  it('listeler, süzer, boş durumu gösterir', async () => {
    mockFetch(() => jsonResponse(200, GROUPS));
    renderWithProviders(<FaqPage />);
    const user = userEvent.setup();
    expect(await screen.findByRole('button', { name: /Şifremi unuttum/ })).toBeInTheDocument();
    expect(screen.getByText('3 soru')).toBeInTheDocument();

    const search = screen.getByRole('searchbox', { name: 'Sorularda ara' });
    await user.type(search, 'bildirim');
    expect(screen.getByText('1 soru')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Şifremi unuttum/ })).toBeNull();

    await user.clear(search);
    await user.type(search, 'xyzxyz');
    expect(screen.getByText('Aramanızla eşleşen soru yok')).toBeInTheDocument();
  });

  it('akordeon klavye ile açılır/kapanır ve oklarla gezilir', async () => {
    mockFetch(() => jsonResponse(200, GROUPS));
    renderWithProviders(<FaqPage />);
    const user = userEvent.setup();
    const first = await screen.findByRole('button', { name: /Şifremi unuttum/ });
    const second = screen.getByRole('button', { name: /Kimler kayıt/ });
    expect(first).toHaveAttribute('aria-expanded', 'false');

    first.focus();
    await user.keyboard('{Enter}');
    expect(first).toHaveAttribute('aria-expanded', 'true');
    const panel = document.getElementById(first.getAttribute('aria-controls')!)!;
    expect(panel).not.toHaveAttribute('hidden');
    expect(panel.querySelector('strong')?.textContent).toBe('şifre sıfırlama');

    await user.keyboard('{ArrowDown}');
    expect(second).toHaveFocus();
    await user.keyboard('{Home}');
    expect(first).toHaveFocus();
    await user.keyboard(' ');
    expect(first).toHaveAttribute('aria-expanded', 'false');
    expect(panel).toHaveAttribute('hidden');
  });

  it('hata durumunda yeniden dene sunar', async () => {
    mockFetch(() => jsonResponse(500, { code: 'INTERNAL', message: 'x' }));
    renderWithProviders(<FaqPage />);
    expect(await screen.findByRole('button', { name: 'Tekrar dene' })).toBeInTheDocument();
  });

  it('soru yoksa boş durum', async () => {
    mockFetch(() => jsonResponse(200, []));
    renderWithProviders(<FaqPage />);
    expect(await screen.findByText('Henüz soru eklenmedi')).toBeInTheDocument();
  });
});
