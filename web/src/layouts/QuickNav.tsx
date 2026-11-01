import { useEffect, useId, useMemo, useRef, useState, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { useNavigate } from 'react-router-dom';
import { Icon, IconButton } from '../components/ui';
import type { IconName } from '../components/ui';
import { useFocusTrap } from '../components/ui/Overlay';
import { useI18n } from '../i18n/I18nProvider';
import {
  Highlight,
  clearRecent,
  pushRecent,
  readRecent,
  useAdminSearch,
  type ResolvedEntry,
  type SearchClass,
  type SearchKind,
} from '../search';
import { POPULAR_QUERIES } from '../search/popular';
import styles from './QuickNav.module.css';

const KIND_ICON: Record<Exclude<SearchKind, 'page'>, IconName> = {
  section: 'panel',
  setting: 'settings',
  field: 'list',
  action: 'play',
};

type Row =
  | { type: 'hit'; entry: ResolvedEntry; cls: SearchClass }
  | { type: 'query'; text: string; label: ReactNode; hint?: string };

/** Ctrl/Cmd+K ile açılan panel arama penceresi: sayfa + bölüm + ayar/alan + eylem; telefonda tam ekran. */
export function QuickNav({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { t } = useI18n();
  const navigate = useNavigate();
  const search = useAdminSearch();
  const [q, setQ] = useState('');
  const [active, setActive] = useState(0);
  const [recent, setRecent] = useState<string[]>([]);

  const uid = useId();
  const listId = `${uid}-list`;
  const dialogRef = useRef<HTMLDivElement>(null);
  const listRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  useFocusTrap(dialogRef, open, onClose);

  useEffect(() => {
    if (open) {
      setQ('');
      setActive(0);
      setRecent(readRecent());
    }
  }, [open]);

  const trimmed = q.trim();
  const groups = useMemo(() => (trimmed ? search.groups(trimmed) : []), [trimmed, search]);
  const suggestion = useMemo(
    () => (trimmed && groups.length === 0 ? search.suggest(trimmed) : null),
    [trimmed, groups, search],
  );
  // Boş kutuda ve sonuç yokken önerilen sık aramalar: yalnız sonuç verenler (izne göre)
  const popular = useMemo(
    () => POPULAR_QUERIES.filter((p) => search.search(p, 1).length > 0).slice(0, 6),
    [search],
  );

  const rows = useMemo<Row[]>(() => {
    if (trimmed && groups.length > 0) {
      return groups.flatMap((g) => g.hits.map<Row>((h) => ({ type: 'hit', entry: h.item, cls: g.cls })));
    }
    const out: Row[] = [];
    if (trimmed) {
      if (suggestion) {
        out.push({
          type: 'query',
          text: suggestion,
          label: (
            <>
              {t('admin.search.didYouMean')} <strong>{suggestion}</strong>
            </>
          ),
        });
      }
    } else {
      for (const r of recent) out.push({ type: 'query', text: r, label: r, hint: 'recent' });
    }
    for (const p of popular) {
      if (!out.some((o) => o.type === 'query' && o.text.toLocaleLowerCase('tr') === p)) {
        out.push({ type: 'query', text: p, label: p, hint: 'popular' });
      }
    }
    return out;
  }, [trimmed, groups, suggestion, recent, popular, t]);

  // Ok tuşlarıyla seçilen satır görünür kalsın
  useEffect(() => {
    listRef.current?.querySelector<HTMLElement>('[data-active="true"]')?.scrollIntoView?.({ block: 'nearest' });
  }, [active, rows]);

  function applyQuery(text: string) {
    setQ(text);
    setActive(0);
    inputRef.current?.focus();
  }

  function pick(row: Row) {
    if (row.type === 'query') {
      applyQuery(row.text);
      return;
    }
    pushRecent(trimmed);
    onClose();
    navigate(row.entry.to);
  }

  const rowId = (i: number) => `${uid}-opt-${i}`;
  let cursor = -1;

  if (!open) return null;

  const hasHits = groups.length > 0;
  const recentRows = rows.filter((r) => r.type === 'query' && r.hint === 'recent');
  const popularRows = rows.filter((r) => r.type === 'query' && r.hint === 'popular');

  return createPortal(
    <div className={styles.scrim} onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-label={t('admin.search.title')}
        tabIndex={-1}
        className={styles.dialog}
      >
        <div className={styles.head}>
          <div className={styles.inputWrap}>
            <Icon name="search" size={18} className={styles.inputIcon} />
            <input
              ref={inputRef}
              data-autofocus
              className={styles.input}
              type="search"
              role="combobox"
              aria-expanded="true"
              aria-controls={listId}
              aria-autocomplete="list"
              aria-activedescendant={rows[active] ? rowId(active) : undefined}
              autoComplete="off"
              spellCheck={false}
              enterKeyHint="go"
              value={q}
              placeholder={t('admin.search.placeholder')}
              aria-label={t('admin.search.label')}
              onChange={(e) => {
                setQ(e.target.value);
                setActive(0);
              }}
              onKeyDown={(e) => {
                if (e.key === 'ArrowDown') {
                  e.preventDefault();
                  setActive((a) => Math.min(a + 1, rows.length - 1));
                } else if (e.key === 'ArrowUp') {
                  e.preventDefault();
                  setActive((a) => Math.max(a - 1, 0));
                } else if (e.key === 'Enter' && rows[active]) {
                  e.preventDefault();
                  pick(rows[active]);
                }
              }}
            />
            {q && (
              <button
                type="button"
                className={styles.clear}
                aria-label={t('admin.search.clear')}
                onClick={() => applyQuery('')}
              >
                <Icon name="x" size={14} />
              </button>
            )}
          </div>
          <IconButton label={t('admin.search.close')} onClick={onClose} className={styles.closeBtn}>
            <Icon name="x" size={20} />
          </IconButton>
        </div>

        <span className="sr-only" role="status">
          {trimmed ? (hasHits ? t('admin.search.count', { count: rows.length }) : t('admin.search.empty', { q: trimmed })) : ''}
        </span>

        <div className={styles.body} ref={listRef}>
          {!trimmed && <p className={styles.intro}>{t('admin.search.intro')}</p>}

          <div role="listbox" id={listId} aria-label={t('admin.search.label')}>
            {hasHits &&
              groups.map((g) => {
                const headId = `${uid}-g-${g.cls}`;
                return (
                  <div key={g.cls} role="group" aria-labelledby={headId} className={styles.group}>
                    <div id={headId} className={styles.groupTitle}>
                      {t(`admin.search.group.${g.cls}` as 'admin.search.group.pages')}
                      <span className={styles.groupCount}>{g.hits.length}</span>
                    </div>
                    {g.hits.map((h) => {
                      cursor += 1;
                      const idx = cursor;
                      const e = h.item;
                      const on = idx === active;
                      const icon: IconName = e.kind === 'page' ? e.icon : KIND_ICON[e.kind];
                      return (
                        <div
                          key={e.id}
                          id={rowId(idx)}
                          role="option"
                          aria-selected={on}
                          data-active={on}
                          className={`${styles.item} ${on ? styles.on : ''}`}
                          onClick={() => pick(rows[idx])}
                          onMouseMove={() => active !== idx && setActive(idx)}
                        >
                          <span className={styles.iconBox} aria-hidden="true">
                            <Icon name={icon} size={18} />
                          </span>
                          <span className={styles.text}>
                            <span className={styles.title}>
                              <Highlight text={e.title} query={trimmed} />
                            </span>
                            <span className={styles.crumbs}>{e.crumbs.join(' › ')}</span>
                            {e.description && (
                              <span className={styles.desc}>
                                <Highlight text={e.description} query={trimmed} />
                              </span>
                            )}
                          </span>
                          <span className={styles.kind}>{t(`admin.search.kind.${e.kind}` as 'admin.search.kind.page')}</span>
                        </div>
                      );
                    })}
                  </div>
                );
              })}

            {!hasHits && trimmed && (
              <div className={styles.empty}>
                <Icon name="search" size={28} />
                <p className={styles.emptyTitle}>{t('admin.search.empty', { q: trimmed })}</p>
                <p className={styles.emptyHint}>{t('admin.search.emptyHint')}</p>
              </div>
            )}

            {!hasHits && (
              <>
                {rows[0]?.type === 'query' && trimmed && suggestion && (
                  <div role="group" aria-label={t('admin.search.didYouMean')} className={styles.group}>
                    {(() => {
                      cursor += 1;
                      const idx = cursor;
                      const r = rows[idx];
                      const on = idx === active;
                      return (
                        <div
                          id={rowId(idx)}
                          role="option"
                          aria-selected={on}
                          data-active={on}
                          className={`${styles.item} ${styles.suggest} ${on ? styles.on : ''}`}
                          onClick={() => pick(r)}
                          onMouseMove={() => active !== idx && setActive(idx)}
                        >
                          <span className={styles.iconBox} aria-hidden="true">
                            <Icon name="help" size={18} />
                          </span>
                          <span className={styles.text}>
                            <span className={styles.title}>{r.type === 'query' ? r.label : null}</span>
                          </span>
                        </div>
                      );
                    })()}
                  </div>
                )}
                {recentRows.length > 0 && (
                  <QueryGroup
                    title={t('admin.search.recent')}
                    action={
                      <button
                        type="button"
                        className={styles.linkBtn}
                        onClick={() => {
                          clearRecent();
                          setRecent([]);
                          setActive(0);
                        }}
                      >
                        {t('admin.search.recentClear')}
                      </button>
                    }
                  >
                    {recentRows.map((r) => {
                      cursor += 1;
                      return (
                        <QueryRow
                          key={`r-${r.type === 'query' ? r.text : ''}`}
                          id={rowId(cursor)}
                          idx={cursor}
                          row={r}
                          active={active}
                          setActive={setActive}
                          pick={pick}
                          icon="search"
                        />
                      );
                    })}
                  </QueryGroup>
                )}
                {popularRows.length > 0 && (
                  <QueryGroup title={t('admin.search.popular')}>
                    {popularRows.map((r) => {
                      cursor += 1;
                      return (
                        <QueryRow
                          key={`p-${r.type === 'query' ? r.text : ''}`}
                          id={rowId(cursor)}
                          idx={cursor}
                          row={r}
                          active={active}
                          setActive={setActive}
                          pick={pick}
                          icon="chevronRight"
                        />
                      );
                    })}
                  </QueryGroup>
                )}
              </>
            )}
          </div>
        </div>

        <div className={styles.foot} aria-hidden="true">
          <span>
            <kbd>↑</kbd> <kbd>↓</kbd> {t('admin.search.keys.move')}
          </span>
          <span>
            <kbd>Enter</kbd> {t('admin.search.keys.open')}
          </span>
          <span>
            <kbd>Esc</kbd> {t('admin.search.keys.close')}
          </span>
        </div>
      </div>
    </div>,
    document.body,
  );
}

function QueryGroup({ title, action, children }: { title: string; action?: ReactNode; children: ReactNode }) {
  const id = useId();
  return (
    <div role="group" aria-labelledby={id} className={styles.group}>
      <div id={id} className={styles.groupTitle}>
        {title}
        {action && <span className={styles.groupAction}>{action}</span>}
      </div>
      {children}
    </div>
  );
}

function QueryRow({
  id,
  idx,
  row,
  active,
  setActive,
  pick,
  icon,
}: {
  id: string;
  idx: number;
  row: Row;
  active: number;
  setActive: (i: number) => void;
  pick: (r: Row) => void;
  icon: IconName;
}) {
  if (row.type !== 'query') return null;
  const on = idx === active;
  return (
    <div
      id={id}
      role="option"
      aria-selected={on}
      data-active={on}
      className={`${styles.item} ${styles.queryItem} ${on ? styles.on : ''}`}
      onClick={() => pick(row)}
      onMouseMove={() => active !== idx && setActive(idx)}
    >
      <span className={styles.iconBox} aria-hidden="true">
        <Icon name={icon} size={16} />
      </span>
      <span className={styles.text}>
        <span className={styles.title}>{row.label}</span>
      </span>
    </div>
  );
}
