#!/usr/bin/env node
// LDNOOBW (CC-BY-4.0) kufur listelerini TEK SEFERLIK indirir, temizler ve
// backend/src/main/resources/moderation/profanity-<dil>.txt dosyalarindaki GENERATED blogunu yeniden yazar.
// Calisma zamaninda ag cagrisi YOKTUR; bu betik yalnizca gelistirici tarafindan elle calistirilir.
// Kullanim: node scripts/fetch-profanity-lists.js   (yeniden calistirilabilir; ag yoksa hata verir)
// Elle yazilmis girisler blok disinda kalir ve korunur.
'use strict';
const fs = require('fs');
const path = require('path');

const SRC = 'https://raw.githubusercontent.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/master/';
const OUT = path.join(__dirname, '..', 'backend', 'src', 'main', 'resources', 'moderation');
const BEGIN = '# >>> GENERATED BEGIN (scripts/fetch-profanity-lists.js) - elle degistirmeyin';
const END = '# <<< GENERATED END';

// Yanlis pozitif riski yuksek / klinik / masum anlamli girisler: ayiklanir.
const EXCLUDE = {
  en: new Set(('sex,sexual,sexually,sexuality,sexy,sexo,penis,vagina,vulva,rectum,anus,semen,genitals,urethra play,rape,raping,' +
    'rapist,date rape,daterape,incest,nude,nudity,topless,erotic,erotism,bondage,domination,dominatrix,dommes,intercourse,' +
    'orgasm,orgy,masturbate,masturbating,masturbation,ejaculation,nipple,nipples,panties,panty,butt,buttcheeks,suck,sucks,' +
    'boob,boobs,tit,tits,clit,clitoris,playboy,escort,hooker,swastika,how to kill,how to murder,neonazi,white power,mong,' +
    'nsfw,nsfw images,anal,ass,cum,coon,coons,paki,kinky,horny,strip club,grope,fecal,scat,poof,eunuch,hentai,yaoi,ecchi,' +
    'lolita,milf,vibrator,voyeur,spunk,swinger,sodomy,sodomize,nymphomania,nimphomania,nympho,bastardo,bastinado,negro,' +
    'snatch,twink,twinkie,santorum,big breasts,hot chick,sultry women,undressing,tied up,tight white,taste my,girl on,' +
    'girl on top,huge fat,style doggy,tongue in a,make me come,wrapping men,spread legs,dog style,god damn,mound of venus,' +
    'venus mound,pleasure chest,tainted love,suicide girls,hard core,hardcore,birdlock,hot carl,foot fetish,lovemaking,' +
    'livesex,worldsex,sexcam,gay sex,group sex,phone sex,blonde action,brunette action,beaver cleaver,beaver lips,xx,xxx,' +
    'bondage,dp action,leather restraint,leather straight jacket,jail bait,jailbait,pedobear,cialis,viagra,female squirting,' +
    'male squirting,reverse cowgirl,missionary position,mr hands,kinbaku,shibari,nawashi,pegging,strapon,strap on,' +
    'ponyplay,figging,frotting,fingering,footjob,coprolagnia,coprophilia,dendrophilia,vorarephilia,zoophilia,urophilia,' +
    'omorashi,sadism,smut,erotica,pubes,tushy,upskirt,voyeurweb,voyuer,thumbzilla,tub girl,tubgirl').split(',')),
  tr: new Set(['am', 'amı', 'amlar', 'göt', 'göte', 'götü', 'götte', 'götten', 'sike', 'sikte', 'sikten', 'siker sikmez',
    'sikilir sikilmez', 'siktirir siktirmez', 'sikmemek', 'siki', 'sikin']),
  ar: new Set(['ثدي', 'حلمة', 'بظر', 'فرج', 'شهوة', 'جماع', 'قضيب', 'احتلام', 'خنثي', 'مبادل', 'بيضان', 'مفلقسة', 'اغتصاب',
    'شاذ', 'لحس', 'لعق', 'شرج', 'لبوة']),
};
// Turkce: etnik anma (cingene) ve cok kisa/ambigu kokler; kodda ayiklanir.
const TR_DROP_PREFIX = ['çingene'];

function keep(lang, raw) {
  let w = raw.trim();
  if (!w) return null;
  w = lang === 'tr' ? w.toLocaleLowerCase('tr') : w.toLowerCase();
  if (!/^[\p{L}\p{M}][\p{L}\p{M} \-]*$/u.test(w)) return null; // rakam, emoji, simge iceren girisleri at
  if (w.replace(/[^\p{L}]/gu, '').length < 3) return null; // cok kisa
  if (EXCLUDE[lang].has(w)) return null;
  if (lang === 'tr' && TR_DROP_PREFIX.some((p) => w.startsWith(p))) return null;
  return w;
}

async function fetchList(lang) {
  const res = await fetch(SRC + lang);
  if (!res.ok) throw new Error(`${lang}: HTTP ${res.status}`);
  return (await res.text()).split(/\r?\n/);
}

function render(lang, words) {
  const lines = [
    BEGIN,
    '# Kaynak: LDNOOBW - List of Dirty, Naughty, Obscene, and Otherwise Bad Words (CC-BY-4.0)',
    '# https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words (dosya: ' + lang + ')',
    '# Indirme: ' + new Date().toISOString().slice(0, 10) + ' - temizlenmis, ' + words.length + ' giris. Tekli sozcukler tam eslesme (=).',
  ];
  for (const w of words) lines.push(w.includes(' ') || lang === 'ar' ? w : '=' + w);
  lines.push(END);
  return lines.join('\n') + '\n';
}

function merge(file, block) {
  let cur = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  const a = cur.indexOf(BEGIN);
  const b = cur.indexOf(END);
  if (a >= 0 && b > a) {
    const after = cur.indexOf('\n', b);
    cur = cur.slice(0, a) + cur.slice(after >= 0 ? after + 1 : cur.length);
  }
  if (cur.length && !cur.endsWith('\n')) cur += '\n';
  fs.writeFileSync(file, cur + '\n' + block, 'utf8'); // BOM'suz UTF-8
}

(async () => {
  for (const lang of ['tr', 'en', 'ar']) {
    const set = new Set();
    for (const raw of await fetchList(lang)) {
      const w = keep(lang, raw);
      if (w) set.add(w);
    }
    const words = [...set].sort((x, y) => x.localeCompare(y, lang));
    merge(path.join(OUT, `profanity-${lang}.txt`), render(lang, words));
    console.log(`${lang}: ${words.length} giris yazildi`);
  }
})().catch((e) => {
  console.error('Indirme basarisiz (ag var mi?):', e.message);
  process.exit(1);
});
