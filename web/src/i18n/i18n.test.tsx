import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { dictionaries, hasKey, translate } from './index';
import { I18nProvider, useI18n } from './I18nProvider';
import { getCurrentLang, getStoredLang } from './lang';

describe('sözlükler', () => {
  const keys = (l: 'tr' | 'en' | 'ar') => Object.keys(dictionaries[l]).sort();

  it('tr, en ve ar anahtar kümeleri birebir aynı', () => {
    expect(keys('en')).toEqual(keys('tr'));
    expect(keys('ar')).toEqual(keys('tr'));
  });

  it('hiçbir çeviri boş değil ve yer tutucular üç dilde aynı', () => {
    const ph = (s: string) => (s.match(/\{\w+\}/g) ?? []).sort().join(',');
    for (const k of Object.keys(dictionaries.tr) as (keyof typeof dictionaries.tr)[]) {
      for (const l of ['tr', 'en', 'ar'] as const) {
        expect(dictionaries[l][k].trim(), `${l}:${k}`).not.toBe('');
      }
      expect(ph(dictionaries.en[k]), k).toBe(ph(dictionaries.tr[k]));
      expect(ph(dictionaries.ar[k]), k).toBe(ph(dictionaries.tr[k]));
    }
  });

  it('anahtarlar ad alanı önekleriyle başlar', () => {
    for (const k of Object.keys(dictionaries.tr)) expect(k).toMatch(/^(common|site|admin|legal)\./);
  });

  it('yer tutucuları doldurur, eksik anahtarda anahtarı döner', () => {
    expect(translate('en', 'common.pagination.page', { page: 2, total: 9 })).toBe('Page 2 of 9');
    expect(translate('tr', 'yok.boyle.anahtar')).toBe('yok.boyle.anahtar');
    expect(hasKey('common.save')).toBe(true);
    expect(hasKey('nope')).toBe(false);
  });
});

function Probe() {
  const { t, lang, setLang, td } = useI18n();
  return (
    <div>
      <p data-testid="save">{t('common.save')}</p>
      <p data-testid="dyn">{td('admin.users.status.SUSPENDED', 'x')}</p>
      <p data-testid="dynmiss">{td('admin.users.status.NOPE', 'fallback')}</p>
      <p data-testid="lang">{lang}</p>
      <button onClick={() => setLang('ar')}>ar</button>
      <button onClick={() => setLang('en')}>en</button>
    </div>
  );
}

describe('I18nProvider', () => {
  it('varsayılan dil Türkçe ve ltr', () => {
    render(
      <I18nProvider>
        <Probe />
      </I18nProvider>,
    );
    expect(screen.getByTestId('save')).toHaveTextContent('Kaydet');
    expect(document.documentElement.lang).toBe('tr');
    expect(document.documentElement.dir).toBe('ltr');
  });

  it('Arapça seçilince <html dir="rtl" lang="ar"> olur ve seçim saklanır', async () => {
    const user = userEvent.setup();
    render(
      <I18nProvider>
        <Probe />
      </I18nProvider>,
    );
    await user.click(screen.getByText('ar'));
    expect(document.documentElement.dir).toBe('rtl');
    expect(document.documentElement.lang).toBe('ar');
    expect(screen.getByTestId('save')).toHaveTextContent('حفظ');
    expect(getCurrentLang()).toBe('ar');
    expect(getStoredLang()).toBe('ar');
    await user.click(screen.getByText('en'));
    expect(document.documentElement.dir).toBe('ltr');
    expect(screen.getByTestId('save')).toHaveTextContent('Save');
  });

  it('dinamik anahtar bulunamazsa fallback kullanır', () => {
    render(
      <I18nProvider initialLang="en">
        <Probe />
      </I18nProvider>,
    );
    expect(screen.getByTestId('dyn')).toHaveTextContent('Suspended');
    expect(screen.getByTestId('dynmiss')).toHaveTextContent('fallback');
  });
});
