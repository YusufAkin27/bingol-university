/**
 * Birleştirici: sayfa grubu başına AYRI dosyalardaki girdileri tek listede toplar (paralel çalışan ajanlar çakışmasın).
 * Yeni grup dosyası = buraya bir `import` + yayılım satırı.
 */
import { entries as academic } from './index/academic';
import { entries as academicians } from './index/academicians';
import { entries as ayarYetki } from './index/ayarYetki';
import { entries as community } from './index/community';
import { entries as content } from './index/content';
import { entries as forum } from './index/forum';
import { entries as moderation } from './index/moderation';
import { entries as notifications } from './index/notifications';
import { entries as overview } from './index/overview';
import { entries as people } from './index/people';
import { entries as shell } from './index/shell';
import { entries as support } from './index/support';
import { entries as system } from './index/system';
import type { SearchEntry } from './types';

export const registeredEntries: SearchEntry[] = [
  ...overview,
  ...people,
  ...moderation,
  ...forum,
  ...community,
  ...academic,
  ...academicians,
  ...support,
  ...content,
  ...notifications,
  ...system,
  ...ayarYetki,
  ...shell,
];
