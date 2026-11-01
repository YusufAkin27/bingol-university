// Sistem durumu kahramanı: "Her şey yolunda mı?" sorusuna renk + simge + cümleyle tek bakışta cevap.
import { levelOf, type SystemIndicator, type SystemLevel } from '../../../api/system';
import { Icon } from '../../../components/ui';
import type { I18n } from '../../../i18n/I18nProvider';
import { LEVEL_ICON } from './IndicatorViews';
import { LEVEL_ORDER, nameOf, valueText } from './indicators';
import styles from './systemstatus.module.css';

export interface Problem {
  id: string;
  level: SystemLevel;
  text: string;
}

/** Sorunlu göstergeler (kritik önce); her biri için backend cümlesi, yoksa "ad: değer". */
export function problemsOf(i18n: I18n, entries: [string, SystemIndicator][]): Problem[] {
  return entries
    .map(([id, ind]) => ({ id, ind, level: levelOf(ind.status) }))
    .filter((e) => e.level === 'CRIT' || e.level === 'WARN')
    .sort((a, b) => LEVEL_ORDER[a.level] - LEVEL_ORDER[b.level])
    .map((e) => ({
      id: e.id,
      level: e.level,
      text: e.ind.message ?? `${nameOf(i18n, e.id)}: ${valueText(i18n, e.id, e.ind)}`,
    }));
}

function jumpTo(id: string) {
  const el = document.getElementById(`ind-${id}`);
  if (!el) return;
  el.scrollIntoView({ block: 'center', behavior: window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' });
  el.focus({ preventScroll: true });
}

export function StatusHero({
  i18n,
  overall,
  entries,
}: {
  i18n: I18n;
  overall: SystemLevel;
  entries: [string, SystemIndicator][];
}) {
  const problems = problemsOf(i18n, entries);
  const count = (lv: SystemLevel) => entries.filter(([, v]) => levelOf(v.status) === lv).length;
  const total = entries.length;
  const bad = problems.length;
  const vars =
    overall === 'OK'
      ? { n: String(total) }
      : { n: String(overall === 'UNKNOWN' ? count('UNKNOWN') : bad) };
  const unknown = count('UNKNOWN');
  return (
    <section
      className={styles.hero}
      data-status={overall}
      data-search-anchor="overall"
      aria-labelledby="sys-hero-title"
      data-testid="sys-hero"
    >
      <span className={styles.heroIcon} aria-hidden="true">
        <Icon name={LEVEL_ICON[overall]} size={34} strokeWidth={2.4} />
      </span>
      <div className={styles.heroBody}>
        <p className={styles.heroKicker}>{i18n.t('admin.v2n.sys.hero.question')}</p>
        <h2 id="sys-hero-title" className={styles.heroTitle}>
          {i18n.t(`admin.v2n.sys.hero.${overall}.title` as 'admin.v2n.sys.hero.OK.title', vars)}
        </h2>
        <p className={styles.heroText}>
          {i18n.t(`admin.v2n.sys.hero.${overall}.text` as 'admin.v2n.sys.hero.OK.text', vars)}
        </p>
        {problems.length > 0 && (
          <ul className={styles.problems} aria-label={i18n.t('admin.v2n.sys.hero.problems')}>
            {problems.slice(0, 5).map((p) => (
              <li key={p.id} data-status={p.level}>
                <Icon name={LEVEL_ICON[p.level]} size={16} aria-hidden="true" />
                <span className={styles.problemText}>
                  <span className="sr-only">{i18n.t(`admin.system.status.${p.level}` as 'admin.system.status.OK')}: </span>
                  {p.text}
                </span>
                <button type="button" className={styles.jump} onClick={() => jumpTo(p.id)}>
                  {i18n.t('admin.v2n.sys.hero.jump')}
                </button>
              </li>
            ))}
          </ul>
        )}
        <p className={styles.heroCounts}>
          {i18n.t('admin.v2n.sys.hero.counts', {
            total: String(total),
            ok: String(count('OK')),
            warn: String(count('WARN')),
            crit: String(count('CRIT')),
            unknown: String(unknown),
          })}
        </p>
      </div>
    </section>
  );
}
