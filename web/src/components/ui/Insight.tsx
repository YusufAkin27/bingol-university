import type { ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { Icon, type IconName } from './Icon';
import { percentChange, type FormatCtx } from './kitFormat';
import type { GoodWhen } from './StatTile';
import styles from './Kit.module.css';

export type InsightTone = 'info' | 'good' | 'bad' | 'warn' | 'neutral';

/** Cümlenin bir parçası: düz metin ya da vurgulu değer ("120 kişi", "%22 fazla"). */
export type InsightPart = string | { text: string; bold?: boolean; tone?: 'good' | 'bad' | 'warn' };

export interface InsightProps {
  /** Grafiğin `aria-describedby` ile bağlanacağı kimlik (ChartPanel kendi üretir). */
  id?: string;
  /** Cümle parçaları; ya da düz metin. children da kullanılabilir. */
  parts?: InsightPart[] | string;
  children?: ReactNode;
  tone?: InsightTone;
  className?: string;
}

const ICONS: Record<InsightTone, IconName> = {
  info: 'info',
  good: 'check',
  bad: 'alert',
  warn: 'alert',
  neutral: 'info',
};

const TONE_CLASS: Record<InsightTone, string> = {
  info: '',
  good: styles.insightGood,
  bad: styles.insightBad,
  warn: styles.insightWarn,
  neutral: styles.insightNeutral,
};

const PART_TONE: Record<'good' | 'bad' | 'warn', string> = {
  good: styles.partGood,
  bad: styles.partBad,
  warn: styles.partWarn,
};

/**
 * Grafiğin üstündeki TEK cümlelik düz Türkçe yorum ("Bugün 120 kişi girdi, dün 98 idi: %22 fazla").
 * aria-live DEĞİLDİR (veri her yenilendiğinde okunmasın); grafik bunu aria-describedby ile gösterir.
 * Ton simgesi renge ek işarettir (onay, üçgen, bilgi).
 */
export function Insight({ id, parts, children, tone = 'info', className }: InsightProps) {
  const list: InsightPart[] = typeof parts === 'string' ? [parts] : (parts ?? []);
  return (
    <p id={id} className={`${styles.insight} ${TONE_CLASS[tone]} ${className ?? ''}`} data-tone={tone}>
      <Icon className={styles.insightIcon} name={ICONS[tone]} size={18} aria-hidden="true" />
      <span className={styles.insightText}>
        {list.map((part, i) =>
          typeof part === 'string' ? (
            <span key={i}>{part}</span>
          ) : (
            <span
              key={i}
              className={`${part.bold === false ? '' : styles.partBold} ${part.tone ? PART_TONE[part.tone] : ''}`}
            >
              {part.text}
            </span>
          ),
        )}
        {children}
      </span>
    </p>
  );
}

export interface CompareSentenceInput {
  /** "Bugün" */
  nowLabel: string;
  current: number;
  /** "dün" (cümle ortasında küçük harfle) */
  thenLabel: string;
  previous: number | null | undefined;
  /** Sayıdan sonra yazılan birim: "kişi", "mesaj". */
  unit: string;
  /** Eylem: "girdi", "yazıldı". */
  verb: string;
  goodWhen?: GoodWhen;
}

/**
 * "Bugün 120 kişi girdi, dün 98 idi: %22 fazla" cümlesinin parçalarını üretir.
 * Önceki değer 0 ya da yoksa uydurma yüzde yazılmaz ("dün hiç yoktu").
 */
export function compareSentence(
  ctx: FormatCtx,
  { nowLabel, current, thenLabel, previous, unit, verb, goodWhen = 'up' }: CompareSentenceInput,
): { parts: InsightPart[]; tone: InsightTone } {
  const { t, formatNumber } = ctx;
  const head: InsightPart[] = [`${nowLabel} `, { text: `${formatNumber(current)} ${unit}` }, ` ${verb}`];
  if (previous === null || previous === undefined) return { parts: head, tone: 'info' };
  if (previous === 0) {
    return { parts: [...head, ', ', t('admin.kit.insight.noPrevious', { then: thenLabel })], tone: 'info' };
  }
  const change = percentChange(current, previous) ?? 0;
  const rounded = Math.round(Math.abs(change));
  const dir = rounded === 0 ? 'flat' : change > 0 ? 'up' : 'down';
  const good = dir === 'flat' || goodWhen === 'neutral' ? null : (dir === 'up') === (goodWhen === 'up');
  const verdict = t(
    dir === 'flat' ? 'admin.kit.insight.same' : dir === 'up' ? 'admin.kit.insight.more' : 'admin.kit.insight.less',
    { value: formatNumber(rounded) },
  );
  return {
    parts: [
      ...head,
      ', ',
      t('admin.kit.insight.was', { then: thenLabel, previous: formatNumber(previous) }),
      { text: verdict, tone: good === null ? undefined : good ? 'good' : 'bad' },
    ],
    tone: good === null ? 'info' : good ? 'good' : 'bad',
  };
}

/** compareSentence'ı çalışan dil bağlamıyla kullanmak için kanca. */
export function useCompareSentence() {
  const { t, formatNumber, formatDate } = useI18n();
  return (input: CompareSentenceInput) => compareSentence({ t, formatNumber, formatDate }, input);
}
