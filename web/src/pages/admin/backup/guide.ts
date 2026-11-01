// Google Drive yedek kurulum rehberi: adımlar ve komut blokları TEK yerde. Komutlar dilden bağımsızdır (kodda);
// başlık/açıklama/uyarı metinleri `admin.gd1.*` çevirisindedir (i18n/tr/admin-gd1.ts; test her anahtarın varlığını denetler).
// SIR YOK: belirteç, parola ve anahtar yalnız yer tutucudur (<...>); sayfa hiçbir sır toplamaz.

export type GuideTone = 'info' | 'warning' | 'danger';

export type GuideItem =
  | { kind: 'text'; key: string }
  | { kind: 'code'; key: string; code: string }
  | { kind: 'callout'; key: string; tone: GuideTone; titleKey?: string };

export interface GuideStep {
  id: string;
  items: GuideItem[];
}

const P = (id: string, k: string) => `admin.gd1.step.${id}.${k}`;

/** Sunucuda kullanılan ortak başlangıç (docker compose kısayolu). */
export const SERVER_DIR = '/opt/bukampus/current';
export const RCLONE_CONF = `${SERVER_DIR}/deploy/rclone/rclone.conf`;

export const RCLONE_AUTH_CMD = 'rclone authorize "drive" "eyJzY29wZSI6ImRyaXZlLmZpbGUifQ"';

export const RCLONE_CONF_TEMPLATE = [
  '[gdrive]',
  'type = drive',
  'scope = drive.file',
  'token = <2. ADIMDA KOPYALADIGINIZ JSON BELIRECI>',
].join('\n');

export const GUIDE_STEPS: GuideStep[] = [
  {
    id: 'why',
    items: [
      { kind: 'text', key: P('why', 'lead') },
      { kind: 'text', key: P('why', 'enc') },
      { kind: 'callout', tone: 'danger', titleKey: 'admin.gd1.warn.keyTitle', key: 'admin.gd1.warn.key' },
      { kind: 'callout', tone: 'warning', titleKey: 'admin.gd1.warn.twoFaTitle', key: 'admin.gd1.warn.twoFa' },
    ],
  },
  {
    id: 'install',
    items: [
      { kind: 'text', key: P('install', 'lead') },
      { kind: 'code', key: P('install', 'win'), code: 'winget install Rclone.Rclone' },
      { kind: 'code', key: P('install', 'mac'), code: 'brew install rclone' },
      { kind: 'code', key: P('install', 'check'), code: 'rclone version' },
      { kind: 'text', key: P('install', 'alt') },
    ],
  },
  {
    id: 'authorize',
    items: [
      { kind: 'text', key: P('authorize', 'lead') },
      { kind: 'code', key: P('authorize', 'cmd'), code: RCLONE_AUTH_CMD },
      { kind: 'text', key: P('authorize', 'after') },
      { kind: 'callout', tone: 'danger', titleKey: 'admin.gd1.warn.tokenTitle', key: 'admin.gd1.warn.token' },
    ],
  },
  {
    id: 'conf',
    items: [
      { kind: 'text', key: P('conf', 'lead') },
      { kind: 'code', key: P('conf', 'ssh'), code: 'ssh -i ~/.ssh/bu_deploy_ed25519 deploy@<SUNUCU_ADRESI>' },
      { kind: 'code', key: P('conf', 'edit'), code: `nano ${RCLONE_CONF}` },
      { kind: 'code', key: P('conf', 'template'), code: RCLONE_CONF_TEMPLATE },
      { kind: 'code', key: P('conf', 'perm'), code: `sudo chown 70:70 ${RCLONE_CONF}\nsudo chmod 400 ${RCLONE_CONF}` },
      { kind: 'text', key: P('conf', 'permWhy') },
    ],
  },
  {
    id: 'env',
    items: [
      { kind: 'text', key: P('env', 'lead') },
      { kind: 'code', key: P('env', 'edit'), code: `cd ${SERVER_DIR}\nnano .env.prod` },
      {
        kind: 'code',
        key: P('env', 'vars'),
        code: 'BACKUP_REMOTE=gdrive:BU-Kampus-Yedek\nBACKUP_KEEP_DAILY=7\nBACKUP_KEEP_WEEKLY=4\nBACKUP_KEEP_MONTHLY=3',
      },
      {
        kind: 'code',
        key: P('env', 'up'),
        code: 'DC="docker compose -f docker-compose.prod.yml --env-file .env.prod"\n$DC up -d backup',
      },
      { kind: 'text', key: P('env', 'keep') },
    ],
  },
  {
    id: 'verify',
    items: [
      { kind: 'text', key: P('verify', 'lead') },
      { kind: 'code', key: P('verify', 'dry'), code: '$DC exec -u postgres backup /opt/backup/backup.sh --dry-run' },
      { kind: 'code', key: P('verify', 'run'), code: '$DC exec -u postgres backup /opt/backup/backup.sh' },
      { kind: 'code', key: P('verify', 'ls'), code: '$DC exec -u postgres backup rclone lsf gdrive:BU-Kampus-Yedek' },
      { kind: 'text', key: P('verify', 'page') },
    ],
  },
  {
    id: 'prune',
    items: [
      { kind: 'text', key: P('prune', 'lead') },
      { kind: 'callout', tone: 'danger', titleKey: 'admin.gd1.warn.deleteTitle', key: 'admin.gd1.warn.delete' },
      { kind: 'code', key: P('prune', 'dry'), code: `cd ${SERVER_DIR}\nbash scripts/backup/prune-local-after-remote.sh` },
      { kind: 'code', key: P('prune', 'apply'), code: 'bash scripts/backup/prune-local-after-remote.sh --apply' },
      { kind: 'text', key: P('prune', 'rule') },
    ],
  },
  {
    id: 'restore',
    items: [
      { kind: 'text', key: P('restore', 'lead') },
      {
        kind: 'code',
        key: P('restore', 'download'),
        code: 'rclone copy gdrive:BU-Kampus-Yedek/<DAMGA> ./restore-in/ --checksum\ncd restore-in && sha256sum -c SHA256SUMS',
      },
      {
        kind: 'code',
        key: P('restore', 'apply'),
        code: `cd ${SERVER_DIR}\nbash scripts/backup/restore-live.sh <YEDEK_DIZINI> <kurtarma.age.key>`,
      },
      { kind: 'callout', tone: 'danger', titleKey: 'admin.gd1.warn.keyTitle', key: 'admin.gd1.warn.keyRestore' },
      { kind: 'text', key: P('restore', 'docs') },
    ],
  },
];

/** Sık sorunlar: her biri başlık + neden + çözüm (çeviri anahtarları `admin.gd1.faq.<id>.*`). */
export const FAQ_IDS = ['grant', 'rate', 'quota', 'perm', 'folder', 'tz'] as const;
export type FaqId = (typeof FAQ_IDS)[number];

/** Tüm çeviri anahtarları (test: her biri tr sözlüğünde var olmalı). */
export function allGuideKeys(): string[] {
  const keys: string[] = [];
  for (const s of GUIDE_STEPS) {
    keys.push(`admin.gd1.step.${s.id}.title`);
    for (const it of s.items) {
      keys.push(it.key);
      if (it.kind === 'callout' && it.titleKey) keys.push(it.titleKey);
    }
  }
  for (const f of FAQ_IDS) keys.push(`admin.gd1.faq.${f}.q`, `admin.gd1.faq.${f}.a`);
  return keys;
}
