import { act, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { I18nProvider, useI18n } from './I18nProvider';
import {
  __resetDictionariesForTests,
  __setDictionaryLoaderForTests,
  isLoaded,
  loadDictionary,
  translate,
} from './registry';

/** Dışarıdan çözülebilen söz: ağ gecikmesini taklit eder. */
function deferred<T>() {
  let resolve!: (v: T) => void;
  let reject!: (e: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

const dicts = {
  tr: { 'common.appName': 'BÜ Kampüs (tr)' },
  en: { 'common.appName': 'BU Campus (en)' },
  ar: { 'common.appName': 'حرم (ar)' },
};

function Probe() {
  const { t, lang, setLang } = useI18n();
  return (
    <div>
      <span data-testid="name">{t('common.appName')}</span>
      <span data-testid="lang">{lang}</span>
      <button onClick={() => setLang('en')}>to-en</button>
      <button onClick={() => setLang('ar')}>to-ar</button>
    </div>
  );
}

let restore: Array<() => void> = [];
function stubLoader(key: string, lang: keyof typeof dicts, gate?: Promise<unknown>) {
  restore.push(
    __setDictionaryLoaderForTests(key, async () => {
      if (gate) await gate;
      return { default: dicts[lang] };
    }),
  );
}

beforeEach(() => {
  __resetDictionariesForTests();
});
afterEach(() => {
  restore.forEach((r) => r());
  restore = [];
});

describe('sözlük lazy yükleme', () => {
  it('ilk açılışta sözlük inene dek hiçbir şey çizilmez, inince kendi dilinin metni görünür', async () => {
    const gate = deferred<void>();
    stubLoader('site.en', 'en', gate.promise);
    const { container } = render(
      <I18nProvider initialLang="en">
        <Probe />
      </I18nProvider>,
    );
    expect(container).toBeEmptyDOMElement();
    expect(isLoaded('en')).toBe(false);
    await act(async () => gate.resolve());
    expect(await screen.findByTestId('name')).toHaveTextContent('BU Campus (en)');
    expect(screen.getByTestId('lang')).toHaveTextContent('en');
    expect(isLoaded('en')).toBe(true);
    // yalnız istenen dil yüklendi: diğer dillerin metni bellekte yok
    expect(translate('ar', 'common.appName')).toBe('common.appName');
    expect(isLoaded('ar')).toBe(false);
  });

  it('dil değişince yeni sözlük yüklenir; yüklenene dek önceki dil kalır, sonra html lang/dir güncellenir', async () => {
    stubLoader('site.tr', 'tr');
    const gate = deferred<void>();
    stubLoader('site.ar', 'ar', gate.promise);
    render(
      <I18nProvider initialLang="tr">
        <Probe />
      </I18nProvider>,
    );
    expect(await screen.findByTestId('name')).toHaveTextContent('BÜ Kampüs (tr)');
    await userEvent.click(screen.getByText('to-ar'));
    // yükleme sürerken boş ekran yok, Türkçe kalır
    expect(screen.getByTestId('name')).toHaveTextContent('BÜ Kampüs (tr)');
    expect(screen.getByTestId('lang')).toHaveTextContent('tr');
    await act(async () => gate.resolve());
    await waitFor(() => expect(screen.getByTestId('name')).toHaveTextContent('حرم (ar)'));
    expect(screen.getByTestId('lang')).toHaveTextContent('ar');
    expect(document.documentElement.dir).toBe('rtl');
  });

  it('ilk yüklemede sözlük hatası: Türkçe yedek dile düşer (lang/dir tutarlı)', async () => {
    restore.push(
      __setDictionaryLoaderForTests('site.en', async () => {
        throw new Error('Failed to fetch dynamically imported module');
      }),
    );
    stubLoader('site.tr', 'tr');
    render(
      <I18nProvider initialLang="en">
        <Probe />
      </I18nProvider>,
    );
    expect(await screen.findByTestId('name')).toHaveTextContent('BÜ Kampüs (tr)');
    expect(screen.getByTestId('lang')).toHaveTextContent('tr');
    expect(document.documentElement.lang).toBe('tr');
  });

  it('görünen dil varken yeni dilin yüklenmesi başarısız olursa görünen dil korunur', async () => {
    stubLoader('site.tr', 'tr');
    restore.push(
      __setDictionaryLoaderForTests('site.ar', async () => {
        throw new Error('Failed to fetch');
      }),
    );
    render(
      <I18nProvider initialLang="tr">
        <Probe />
      </I18nProvider>,
    );
    await screen.findByTestId('name');
    await userEvent.click(screen.getByText('to-ar'));
    await new Promise((r) => setTimeout(r, 20));
    expect(screen.getByTestId('name')).toHaveTextContent('BÜ Kampüs (tr)');
    expect(screen.getByTestId('lang')).toHaveTextContent('tr');
  });

  it('yönetim kapsamı site + admin sözlüğünü ister ve yalnız Türkçe yüklenir', async () => {
    stubLoader('site.tr', 'tr');
    restore.push(__setDictionaryLoaderForTests('admin.tr', async () => ({ default: { 'admin.x': 'Yönetim' } })));
    function Admin() {
      const { t } = useI18n();
      return (
        <span data-testid="x">
          {t('common.appName')} / {t('admin.x' as never)}
        </span>
      );
    }
    render(
      <I18nProvider forcedLang="tr" scope="admin">
        <Admin />
      </I18nProvider>,
    );
    expect(await screen.findByTestId('x')).toHaveTextContent('BÜ Kampüs (tr) / Yönetim');
    expect(isLoaded('en')).toBe(false);
  });
});

describe('registry.loadDictionary', () => {
  it('eşzamanlı çağrılar tek istek yapar ve yüklü parça tekrar istenmez', async () => {
    let calls = 0;
    restore.push(
      __setDictionaryLoaderForTests('site.en', async () => {
        calls++;
        return { default: dicts.en };
      }),
    );
    await Promise.all([loadDictionary('en'), loadDictionary('en')]);
    await loadDictionary('en');
    expect(calls).toBe(1);
  });

  it('hata sonrası bir sonraki çağrı yeniden dener', async () => {
    let calls = 0;
    restore.push(
      __setDictionaryLoaderForTests('site.en', async () => {
        calls++;
        if (calls === 1) throw new Error('boom');
        return { default: dicts.en };
      }),
    );
    await expect(loadDictionary('en')).rejects.toThrow('boom');
    await loadDictionary('en');
    expect(isLoaded('en')).toBe(true);
    expect(translate('en', 'common.appName')).toBe('BU Campus (en)');
  });

  it('eksik anahtarda yüklü Türkçeye, o da yoksa anahtarın kendisine düşer', async () => {
    stubLoader('site.tr', 'tr');
    stubLoader('site.en', 'en');
    await Promise.all([loadDictionary('tr'), loadDictionary('en')]);
    expect(translate('en', 'yok.boyle.anahtar')).toBe('yok.boyle.anahtar');
  });
});
