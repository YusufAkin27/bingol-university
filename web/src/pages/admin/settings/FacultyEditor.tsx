import { useState, type KeyboardEvent } from 'react';
import { Badge, Button, Icon, IconButton, Input } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { Callout } from '../campaigns/shared';
import {
  FACULTY_MAX,
  FACULTIES_TOTAL_MAX,
  facultiesError,
  moveItem,
  parseFaculties,
  serializeFaculties,
  splitFacultyInput,
} from './lib';
import { isDirty, useSettings, valueOf } from './SettingRow';
import styles from './settings.module.css';

const KEY = 'faculties';

/** `faculties` ayarı için çip düzenleyici: ekle (Enter / yapıştır), sırala (↑ ↓), sil. Değer `;` ile saklanır. */
export function FacultyEditor() {
  const { t, formatNumber } = useI18n();
  const c = useSettings();
  const list = parseFaculties(valueOf(c, KEY));
  const dirty = isDirty(c, KEY);
  const [text, setText] = useState('');
  const err = facultiesError(list);
  const total = serializeFaculties(list).length;

  function commit(next: string[]) {
    c.setEdit(KEY, serializeFaculties(next));
  }
  function addFromText(raw: string) {
    const names = splitFacultyInput(raw);
    if (names.length === 0) return;
    commit([...list, ...names]);
    setText('');
  }
  function onKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'Enter' || e.key === ';') {
      e.preventDefault();
      addFromText(text);
    } else if (e.key === 'Backspace' && !text && list.length > 0) {
      // boş alanda geri tuşu: son çipi sil
      commit(list.slice(0, -1));
    }
  }

  return (
    <div className={`${styles.row} ${dirty ? styles.rowDirty : ''}`} data-dirty={dirty || undefined} data-key={KEY}>
      {dirty && (
        <span className={styles.unsaved}>
          <Badge tone="warning">{t('admin.settings.unsaved')}</Badge>
        </span>
      )}
      <Callout tone="info">{t('admin.settings.faculties.explain')}</Callout>
      <div className={styles.facAdd}>
        <label htmlFor="faculty-add" className={styles.facLabel}>
          {t('admin.settings.faculties.add')}
        </label>
        <div className={styles.facAddRow}>
          <Input
            id="faculty-add"
            value={text}
            maxLength={FACULTY_MAX + 40}
            placeholder={t('admin.settings.faculties.placeholder')}
            onChange={(e) => setText(e.target.value)}
            onKeyDown={onKeyDown}
            onPaste={(e) => {
              const pasted = e.clipboardData.getData('text');
              if (/[;\n\r]/.test(pasted)) {
                e.preventDefault();
                addFromText(text + pasted);
              }
            }}
          />
          <Button variant="secondary" onClick={() => addFromText(text)} disabled={!text.trim()} leftIcon={<Icon name="plus" size={16} />}>
            {t('admin.settings.faculties.addBtn')}
          </Button>
        </div>
      </div>

      {list.length === 0 ? (
        <p className={styles.facEmpty}>{t('admin.settings.faculties.empty')}</p>
      ) : (
        <ol className={styles.facList} aria-label={t('admin.settings.faculties.list')}>
          {list.map((f, i) => (
            <li key={f} className={styles.facChip}>
              <span className={styles.facIndex} aria-hidden="true">
                {formatNumber(i + 1)}
              </span>
              <span className={styles.facName}>{f}</span>
              <span className={styles.facBtns}>
                <IconButton
                  label={t('admin.settings.faculties.up', { name: f })}
                  size="sm"
                  disabled={i === 0}
                  onClick={() => commit(moveItem(list, i, -1))}
                >
                  <Icon name="arrowUp" size={14} />
                </IconButton>
                <IconButton
                  label={t('admin.settings.faculties.down', { name: f })}
                  size="sm"
                  disabled={i === list.length - 1}
                  onClick={() => commit(moveItem(list, i, 1))}
                >
                  <Icon name="arrowDown" size={14} />
                </IconButton>
                <IconButton
                  label={t('admin.settings.faculties.remove', { name: f })}
                  size="sm"
                  onClick={() => commit(list.filter((_, j) => j !== i))}
                >
                  <Icon name="x" size={14} />
                </IconButton>
              </span>
            </li>
          ))}
        </ol>
      )}

      <p className={`${styles.facCount} ${err ? styles.facOver : ''}`} aria-live="polite">
        {t('admin.settings.faculties.count', {
          n: formatNumber(list.length),
          chars: formatNumber(total),
          max: formatNumber(FACULTIES_TOTAL_MAX),
        })}
      </p>
      {err && (
        <p className={styles.errText} role="alert">
          {t(err === 'TOO_LONG' ? 'admin.settings.faculties.err.TOO_LONG' : 'admin.settings.faculties.err.TOTAL_TOO_LONG')}
        </p>
      )}
      {c.errors[KEY] && (
        <p className={styles.errText} role="alert">
          {c.errors[KEY]}
        </p>
      )}
      <div className={styles.rowActions}>
        <Button disabled={!dirty || !!err} loading={c.savingKey === KEY} onClick={() => c.save(KEY)} data-testid="save-faculties">
          {t('admin.settings.faculties.save')}
        </Button>
        {dirty && (
          <Button variant="ghost" onClick={() => c.revert(KEY)}>
            {t('admin.settings.revert')}
          </Button>
        )}
      </div>
    </div>
  );
}
