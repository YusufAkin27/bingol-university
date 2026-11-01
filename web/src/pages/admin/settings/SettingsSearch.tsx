// Ayarlar: sayfa içi arama kutusu. "bakıma al", "banner", "ınstagram" gibi günlük/yanlış yazımlarla ilgili ayarı bulur;
// sonuçta ayarın şu anki değeri görünür, "Git" ilgili sekmeyi açıp alana kaydırır ve vurgular.
import { useMemo, useState } from 'react';
import { Badge, SearchInput } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { registeredEntries } from '../../../search/registry';
import type { SettingGroup } from './lib';
import { createSettingsSearcher, searchSettings, settingsItems, valueExcerpt } from './searchLogic';
import { useGt } from '../sys2Dict';
import styles from './settingsSearch.module.css';

export function SettingsSearch({
  server,
  groupOf,
  onPick,
}: {
  server: Record<string, string>;
  groupOf: (anchor: string) => SettingGroup | null;
  onPick: (anchor: string) => void;
}) {
  const { t } = useI18n();
  const gt = useGt();
  const [query, setQuery] = useState('');
  const searcher = useMemo(() => createSettingsSearcher(settingsItems(registeredEntries)), []);
  const results = useMemo(() => searchSettings(searcher, query), [searcher, query]);

  const show = (v: string | undefined) => {
    const s = (v ?? '').trim();
    if (s === 'true') return t('admin.v2n.set.on');
    if (s === 'false') return t('admin.v2n.set.off');
    return valueExcerpt(s) || gt('admin.sys2.settings.search.empty');
  };

  return (
    <div className={styles.box} data-search-anchor="settings-search">
      <SearchInput
        label={gt('admin.sys2.settings.search.label')}
        placeholder={gt('admin.sys2.settings.search.placeholder')}
        delay={200}
        onSearch={setQuery}
      />
      {query && (
        <div className={styles.results} role="region" aria-label={gt('admin.sys2.settings.search.results')} data-testid="settings-search-results">
          {results.length === 0 ? (
            <p className={styles.none}>{gt('admin.sys2.settings.search.none', { q: query })}</p>
          ) : (
            <ul className={styles.list}>
              {results.map((r) => {
                const g = groupOf(r.anchor);
                const isField = r.kind === 'setting' || r.kind === 'field';
                return (
                  <li key={r.id}>
                    <button
                      type="button"
                      className={styles.item}
                      onClick={() => {
                        setQuery('');
                        onPick(r.anchor);
                      }}
                      data-testid={`settings-hit-${r.anchor}`}
                    >
                      <span className={styles.itemMain}>
                        <span className={styles.itemTitle}>{r.title}</span>
                        {r.description && <span className={styles.itemDesc}>{r.description}</span>}
                      </span>
                      <span className={styles.itemSide}>
                        {g && <Badge tone="neutral">{t(`admin.settings.group.${g}`)}</Badge>}
                        {isField && <span className={styles.itemValue} dir="auto">{show(server[r.anchor])}</span>}
                      </span>
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}
