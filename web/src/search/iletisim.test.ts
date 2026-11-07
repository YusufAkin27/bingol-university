// İletişim grubu (destek + bildirimler) arama girdileri: günlük dil, eş anlamlı ve yazım hatalı sorgular doğru sayfayı getirir.
import { describe, expect, it } from 'vitest';
import { translate } from '../i18n';
import { buildSearchEntries } from './build';
import { createSearcher } from './engine';

type Key = Parameters<typeof buildSearchEntries>[0] extends (k: infer K) => string ? K : never;
const searcher = createSearcher(buildSearchEntries((k: Key) => translate('tr', k)));
const pages = (q: string, n = 8) =>
  searcher
    .search(q)
    .slice(0, n)
    .map((h) => h.item.pageId);
const ids = (q: string, n = 8) =>
  searcher
    .search(q)
    .slice(0, n)
    .map((h) => h.item.id);

describe('destek: talepler ve geri bildirim', () => {
  it('"talep" ve "yardım" destek taleplerini getirir', () => {
    expect(pages('talep')).toContain('tickets');
    expect(pages('yardım')).toContain('tickets');
  });
  it('yazım hatası: "tlep" ve "destk" yine talepleri bulur', () => {
    expect(pages('tlep')).toContain('tickets');
    expect(pages('destk')).toContain('tickets');
  });
  it('"kaç saatte cevap veriyoruz" ilk yanıt süresi bölümüne gider', () => {
    expect(ids('cevap hızı')).toContain('tickets.first-response');
    expect(ids('yanıt süresi')).toContain('tickets.first-response');
  });
  it('"geciken talepler" bekleyenlerin yaşı bölümüne gider', () => {
    expect(ids('geciken talepler')).toContain('tickets.age');
    expect(ids('unutulan talep')).toContain('tickets.age');
  });
  it('"öneri" ve "geri bildirim" geri bildirim sayfasını getirir; "oneri" aksansız yazım da', () => {
    expect(pages('öneri')).toContain('feedback');
    expect(pages('oneri')).toContain('feedback');
    expect(pages('geri bildirm')).toContain('feedback');
  });
  it('"en çok oy alan" öneri sıralamasına gider', () => {
    expect(ids('en çok oy alan')).toContain('feedback.top-voted');
  });
});

describe('bildirimler: kampanya, e-posta, kuyruk', () => {
  it('"gitmeyen mail" ve yazım hatalı "gitmyen mail" mail kuyruğunu getirir', () => {
    expect(pages('gitmeyen mail')).toContain('mailQueue');
    expect(pages('gitmyen mail')).toContain('mailQueue');
    expect(ids('gitmeyen mail')).toContain('mailQueue.health');
  });
  it('"bildirim gitmiyor" bildirim altyapısı kuyruğuna gider', () => {
    expect(pages('bildirim gitmiyor')).toContain('pushOps');
    expect(ids('bildirim gitmiyor')).toContain('pushOps.queue-health');
  });
  it('"kaç kişiye ulaştık" kampanya özetine gider', () => {
    expect(ids('kaç kişiye ulaştık')).toContain('campaigns.summary');
    expect(ids('kac kisiye ulastik')).toContain('campaigns.summary');
  });
  it('"abonelikten çıkanlar" ve "spam diyenler" engel listesi özetine gider', () => {
    expect(ids('abonelikten çıkanlar')).toContain('mailSuppressions.summary');
    expect(ids('spam diyenler')).toContain('mailSuppressions.summary');
  });
  it('"eksik dil" şablon özetine gider', () => {
    expect(ids('eksik dil')).toContain('mailTemplates.summary');
  });
  it('"açılma oranı" e-posta kampanya halkasına gider', () => {
    expect(ids('açılma oranı')).toContain('mailCampaigns.ring');
  });
  it('"mail", "bildirim", "e-posta" tek başına ilgili sayfaları getirir', () => {
    expect(pages('mail', 12)).toEqual(
      expect.arrayContaining(['mailQueue', 'mailTemplates', 'mailCampaigns']),
    );
    expect(pages('bildirim', 12)).toEqual(expect.arrayContaining(['campaigns', 'pushOps']));
    expect(pages('e-posta', 12)).toEqual(expect.arrayContaining(['mailQueue']));
  });
  it('kampanya oluşturucudaki kitle oranı yeni kampanya sayfasının yolunu kullanır', () => {
    const hit = searcher.search('herkese mi gidiyor')[0]?.item;
    expect(hit?.id).toBe('campaigns.compose-audience-share');
    expect(hit?.to).toContain('/campaigns/new');
    expect(hit?.to).toContain('#compose-audience-share');
  });
});
