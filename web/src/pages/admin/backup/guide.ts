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

/** Sunucuda kullanılan yollar (docs/BACKUP_GDRIVE.md "Yol ve komut kuralları" ile birebir). */
export const SERVER_DIR = '/opt/bukampus/current';
export const ENV_FILE = '/opt/bukampus/.env.prod';
/** rclone.conf KALICI dizini: her dağıtım yeni releases/<sha> açar, depo içi deploy/rclone sürümle birlikte kaybolur. */
export const RCLONE_DIR = '/opt/bukampus-data/rclone';
export const RCLONE_CONF = `${RCLONE_DIR}/rclone.conf`;

/** Her `docker compose` komutu SERVER_DIR içinden bu kısayolla çalışır. */
export const DC_DEF = `cd ${SERVER_DIR}\nDC="docker compose -p bu -f docker-compose.prod.yml -f deploy/compose.bukampus.yml --env-file ${ENV_FILE}"`;
const EXEC = '$DC exec -u postgres backup';

/** Kendi OAuth istemcinizle (önerilir) ve yalnız drive.file kapsamıyla. */
export const RCLONE_AUTH_CMD =
  'rclone authorize "drive" --drive-client-id "<CLIENT_ID>" --drive-client-secret "<CLIENT_SECRET>" --drive-scope drive.file';
/** Kendi istemcisi olmayanlar için (rclone'un paylaşılan yerleşik kimliği; hız sınırı riski). */
export const RCLONE_AUTH_CMD_BUILTIN = 'rclone authorize "drive" --drive-scope drive.file';

export const RCLONE_CONF_TEMPLATE = [
  '[gdrive]',
  'type = drive',
  'client_id = <CLIENT_ID>',
  'client_secret = <CLIENT_SECRET>',
  'scope = drive.file',
  'token = <3. ADIMDA KOPYALADIGINIZ JSON BELIRECI>',
].join('\n');

/** .env.prod'a eklenecek satırlar (adlar docs/BACKUP_GDRIVE.md bölüm 6 ve .env.prod.example ile aynı). */
export const ENV_VARS = [
  `RCLONE_CONF_DIR=${RCLONE_DIR}`,
  'BACKUP_REMOTE=gdrive:BU-Kampus-Yedek',
  'BACKUP_REMOTE_SCHEDULE=daily',
  'BACKUP_REMOTE_KEEP_DAILY=7',
  'BACKUP_REMOTE_KEEP_WEEKLY=4',
  'BACKUP_REMOTE_KEEP_MONTHLY=6',
].join('\n');

/** Doğrulanınca sunucudaki saatlik yedek penceresini küçültür (bölüm 8, 1. kademe). */
export const ENV_LOCAL_KEEP = ['BACKUP_KEEP_DAILY=3', 'BACKUP_KEEP_WEEKLY=0', 'BACKUP_KEEP_MONTHLY=0'].join('\n');

export const GUIDE_STEPS: GuideStep[] = [
  {
    id: 'why',
    items: [
      { kind: 'text', key: P('why', 'lead') },
      { kind: 'text', key: P('why', 'enc') },
      { kind: 'text', key: P('why', 'rpo') },
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
    id: 'client',
    items: [
      { kind: 'text', key: P('client', 'lead') },
      { kind: 'text', key: P('client', 'steps') },
      { kind: 'callout', tone: 'danger', titleKey: 'admin.gd1.warn.testingTitle', key: 'admin.gd1.warn.testing' },
      { kind: 'text', key: P('client', 'creds') },
      { kind: 'text', key: P('client', 'skip') },
    ],
  },
  {
    id: 'authorize',
    items: [
      { kind: 'text', key: P('authorize', 'lead') },
      { kind: 'code', key: P('authorize', 'cmd'), code: RCLONE_AUTH_CMD },
      { kind: 'code', key: P('authorize', 'cmdBuiltin'), code: RCLONE_AUTH_CMD_BUILTIN },
      { kind: 'text', key: P('authorize', 'after') },
      { kind: 'callout', tone: 'danger', titleKey: 'admin.gd1.warn.tokenTitle', key: 'admin.gd1.warn.token' },
    ],
  },
  {
    id: 'conf',
    items: [
      { kind: 'text', key: P('conf', 'lead') },
      { kind: 'code', key: P('conf', 'ssh'), code: 'ssh -i ~/.ssh/bu_deploy_ed25519 deploy@<SUNUCU_ADRESI>' },
      { kind: 'code', key: P('conf', 'mkdir'), code: `sudo install -d -m 700 ${RCLONE_DIR}` },
      { kind: 'code', key: P('conf', 'edit'), code: `sudo nano ${RCLONE_CONF}` },
      { kind: 'code', key: P('conf', 'template'), code: RCLONE_CONF_TEMPLATE },
      { kind: 'text', key: P('conf', 'permWhy') },
    ],
  },
  {
    id: 'env',
    items: [
      { kind: 'text', key: P('env', 'lead') },
      { kind: 'code', key: P('env', 'edit'), code: `nano ${ENV_FILE}` },
      { kind: 'code', key: P('env', 'vars'), code: ENV_VARS },
      { kind: 'code', key: P('env', 'up'), code: `${DC_DEF}\n$DC up -d --build backup backend` },
      { kind: 'text', key: P('env', 'keep') },
    ],
  },
  {
    id: 'verify',
    items: [
      { kind: 'text', key: P('verify', 'lead') },
      { kind: 'code', key: P('verify', 'access'), code: `${DC_DEF}\n${EXEC} rclone lsd gdrive:\n${EXEC} rclone about gdrive:` },
      { kind: 'code', key: P('verify', 'dry'), code: `${EXEC} /opt/backup/remote-sync.sh --dry-run` },
      { kind: 'code', key: P('verify', 'run'), code: `${EXEC} /opt/backup/remote-sync.sh\n$DC logs --tail 50 backup` },
      { kind: 'code', key: P('verify', 'ls'), code: `${EXEC} rclone lsf gdrive:BU-Kampus-Yedek --dirs-only` },
      { kind: 'text', key: P('verify', 'page') },
    ],
  },
  {
    id: 'prune',
    items: [
      { kind: 'text', key: P('prune', 'lead') },
      { kind: 'callout', tone: 'danger', titleKey: 'admin.gd1.warn.deleteTitle', key: 'admin.gd1.warn.delete' },
      { kind: 'code', key: P('prune', 'keep'), code: `# ${ENV_FILE}\n${ENV_LOCAL_KEEP}\n\n${DC_DEF}\n$DC up -d backup` },
      { kind: 'code', key: P('prune', 'dry'), code: `${EXEC} /opt/backup/prune-local-after-remote.sh --keep 2` },
      { kind: 'code', key: P('prune', 'apply'), code: `${EXEC} /opt/backup/prune-local-after-remote.sh --keep 2 --apply` },
      { kind: 'code', key: P('prune', 'auto'), code: `# ${ENV_FILE}\nBACKUP_LOCAL_KEEP_WHEN_REMOTE_OK=2` },
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
        code: 'rclone lsf gdrive:BU-Kampus-Yedek --dirs-only\nmkdir restore-in\nrclone copy gdrive:BU-Kampus-Yedek/<DAMGA> ./restore-in/ --progress\ncd restore-in && sha256sum -c SHA256SUMS',
      },
      {
        kind: 'code',
        key: P('restore', 'apply'),
        code: `cd ${SERVER_DIR}\nENV_FILE=${ENV_FILE} COMPOSE_FILES="-f docker-compose.prod.yml -f deploy/compose.bukampus.yml" \\\n  bash scripts/backup/restore-live.sh <YEDEK_DIZINI> <kurtarma.age.key>`,
      },
      { kind: 'callout', tone: 'danger', titleKey: 'admin.gd1.warn.keyTitle', key: 'admin.gd1.warn.keyRestore' },
      { kind: 'text', key: P('restore', 'docs') },
    ],
  },
];

/** Sık sorunlar: her biri başlık + neden + çözüm (çeviri anahtarları `admin.gd1.faq.<id>.*`). */
export const FAQ_IDS = ['grant', 'rate', 'quota', 'perm', 'folder', 'tz', 'lost'] as const;
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
