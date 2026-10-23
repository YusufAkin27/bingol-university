import { useLayoutEffect, useRef, type KeyboardEvent, type ReactNode } from 'react';
import { Icon } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { applyFormat, type MdFormat } from './markdownFormat';
import styles from './MarkdownEditor.module.css';

interface Props {
  id?: string;
  value: string;
  onChange: (value: string) => void;
  dir?: 'ltr' | 'rtl';
  placeholder?: string;
  maxLength?: number;
  'aria-label'?: string;
}

const TOOLS: { fmt: MdFormat; key: 'heading' | 'bold' | 'italic' | 'list' | 'link'; glyph: ReactNode }[] = [
  { fmt: 'heading', key: 'heading', glyph: <span className={styles.glyph}>H</span> },
  { fmt: 'bold', key: 'bold', glyph: <strong className={styles.glyph}>B</strong> },
  { fmt: 'italic', key: 'italic', glyph: <em className={styles.glyph}>I</em> },
  { fmt: 'list', key: 'list', glyph: <Icon name="list" size={16} /> },
  { fmt: 'link', key: 'link', glyph: <Icon name="external" size={16} /> },
];

/** Araç çubuklu Markdown metin alanı. Dönüşüm mantığı markdownFormat.ts'te; burada yalnızca seçim yönetimi var. */
export function MarkdownEditor({ id, value, onChange, dir, placeholder, maxLength, ...rest }: Props) {
  const { t } = useI18n();
  const ref = useRef<HTMLTextAreaElement>(null);
  const pending = useRef<{ start: number; end: number } | null>(null);

  useLayoutEffect(() => {
    const sel = pending.current;
    if (sel && ref.current) {
      ref.current.focus();
      ref.current.setSelectionRange(sel.start, sel.end);
      pending.current = null;
    }
  }, [value]);

  function run(fmt: MdFormat) {
    const el = ref.current;
    if (!el) return;
    const r = applyFormat(el.value, el.selectionStart, el.selectionEnd, fmt);
    pending.current = { start: r.selStart, end: r.selEnd };
    onChange(r.value);
  }

  function onKeyDown(e: KeyboardEvent<HTMLTextAreaElement>) {
    if (!(e.ctrlKey || e.metaKey) || e.shiftKey || e.altKey) return;
    const map: Record<string, MdFormat> = { b: 'bold', i: 'italic', k: 'link' };
    const fmt = map[e.key.toLowerCase()];
    if (fmt) {
      e.preventDefault();
      run(fmt);
    }
  }

  return (
    <div className={styles.editor}>
      <div className={styles.toolbar} role="toolbar" aria-label={t('admin.legal.tb.label')}>
        {TOOLS.map((tool) => {
          const label = t(`admin.legal.tb.${tool.key}`);
          return (
            <button
              key={tool.fmt}
              type="button"
              className={styles.tool}
              aria-label={label}
              title={label}
              data-tool={tool.fmt}
              onMouseDown={(e) => e.preventDefault()}
              onClick={() => run(tool.fmt)}
            >
              {tool.glyph}
            </button>
          );
        })}
      </div>
      <textarea
        ref={ref}
        id={id}
        className={styles.area}
        value={value}
        dir={dir}
        placeholder={placeholder}
        maxLength={maxLength}
        spellCheck
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={onKeyDown}
        aria-label={rest['aria-label']}
      />
    </div>
  );
}
