import { describe, expect, it } from 'vitest';
import { translate } from '../i18n';
import { paths } from '../paths';
import { buildSearchEntries } from './build';
import { createSearcher } from './engine';

type Key = Parameters<typeof buildSearchEntries>[0] extends (k: infer K) => string ? K : never;
const searcher = createSearcher(buildSearchEntries((k: Key) => translate('tr', k)));
const ids = (q: string, n = 8) => searcher.search(q).slice(0, n).map((h) => h.item.id);

describe('INSAN: insanlar grubu derin arama girdileri', () => {
  it('"mesajlar", "mesaj", "yazışma" ve yazım hatalı "mesjlar" kullanıcı mesajlarını getirir', () => {
    expect(ids('mesajlar')).toContain('users.detail.messages');
    expect(ids('mesaj')).toContain('users.detail.messages');
    expect(ids('yazışma')).toContain('users.detail.messages');
    expect(ids('mesjlar', 12)).toContain('users.detail.messages');
    expect(ids('sohbetler')).toContain('users.detail.messages');
  });
  it('dikkat gerektirenler (yazım hatasıyla da), risk ve zaman çizelgesi bulunur', () => {
    expect(ids('askıdaki hesaplar')).toContain('users.attention');
    expect(ids('dikat gerektirenler')).toContain('users.attention');
    expect(ids('riskli mi')).toContain('users.detail.risk');
    expect(ids('hesap geçmişi')).toContain('users.detail.timeline');
  });
  it('2FA halkası/eğilimi ve bekleyen süre dağılımı', () => {
    expect(ids('benimseme oranı')).toContain('twoFactor.ring');
    expect(ids('koruma trendi')).toContain('twoFactor.trend');
    expect(ids('süresi dolmak üzere')).toContain('pending.urgency');
  });
  it('derin bağlantı bölüm anchor\'ını taşır', () => {
    const e = searcher.search('fakültelere göre kişi')[0]?.item;
    expect(e?.to).toBe(`${paths.admin.users}#users-chart-faculty`);
  });
});
