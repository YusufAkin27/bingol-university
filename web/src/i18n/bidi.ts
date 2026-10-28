/**
 * Arapça (RTL) cümle içindeki Latin kimlikler (alan adı, e-posta, URL) soldan sağa okunmalı ve çevre metnin
 * noktalama/parantezleriyle karışmamalı. Unicode LRI...PDI (U+2066/U+2069) çevresel yönü etkilemeden yalıtır;
 * böylece her çeviri anahtarında elle işaretleme gerekmez. Yalnız `ar` için uygulanır.
 */
const LRI = '\u2066';
const PDI = '\u2069';

const LATIN_IDENTIFIER =
  /https?:\/\/[^\s)\]»"]*[^\s)\]»".,;:!؟،]|[a-z0-9._%+-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+|\b[a-z0-9-]+(?:\.[a-z0-9-]+)*\.(?:edu\.tr|com\.tr|com|org|net|tr|edu)\b/gi;

export function isolateLatinIdentifiers(text: string): string {
  if (!text.includes('.')) return text;
  return text.replace(LATIN_IDENTIFIER, (m, offset: number, whole: string) =>
    whole.charAt(offset - 1) === LRI ? m : `${LRI}${m}${PDI}`,
  );
}
