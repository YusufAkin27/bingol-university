#!/usr/bin/env node
/*
 * Uygunsuz ifade listesi v2 uretici (moderation/profanity-v2-*.txt, profanity-allow-v2.txt).
 * Kullanim: node scripts/profanity/gen-v2.js   (repo kokunden)
 *
 * Soz dizimi (ProfanityMatcher): =tam eslesme, +kok+Turkce ek zinciri, ~kok+Ingilizce ek zinciri (s/es/ed/ing...),
 * *metin icinde gecme (>=5 harf, yalnizca ayirt edici kokler), !sert, isaretsiz = kok + en fazla 7 harf ek,
 * bosluklu satir = tamlama. Yalnizca moderasyon amaclidir; kaynak: proje ekibi (elle).
 * Bu dosya LISTE verisidir: yeni kelime = buraya ekle, betigi calistir, uretilen .txt dosyalarini commit et.
 */
'use strict';
const fs = require('fs');
const path = require('path');
const OUT = path.join(__dirname, '..', '..', 'backend', 'src', 'main', 'resources', 'moderation');

const uniq = (a) => [...new Set(a.map((s) => s.trim()).filter(Boolean))];
const words = (s) => uniq(s.split(/\s+/));
const lines = (s) => uniq(s.split('\n'));

// ============================================================ TURKCE
const TR_HEAD = `# Uygunsuz ifade filtresi - Turkce v2 listesi (elle yazilmis, uretici: scripts/profanity/gen-v2.js). ELLE DEGISTIRMEYIN.
# Soz dizimi icin profanity-tr.txt basligina bakin; ek isaretler: +kok = kok + guvenli Turkce ek zinciri (sozcuk sonuna kadar).
# Kisa/belirsiz kokler ASLA metin icinde aranmaz; "klasik", "mesela", "sistem" gibi sozcukler bu yuzden gecer.`;

// kok + ek zinciri (+): ayirt edici, dil bilgisi cekimi dogal
const trChain = words(`
orospu orospuluk orospuçocuğu orospucocugu orospular orosbu orosbuçocuğu orospuyu
amcık amcıklar amcığı amcuk amcıkağız amcıkağzı amcıkhoş
yarrak yarak yarrağ yarrakları yarrakkafa yarrakkafalı yarrakyalayan
taşak taşşak taşaklarım taşağım taşşaklar taşaklı
sikik sikikler sikiktir sikler siklerim sikmeyeyim sikimsonik sikimtrak
siktir siktirgit siktirin siktiriboktan siktirler
siktiğim siktiğimin siktiğimden siktiğimi siktiğimle
siktim siktin siktik siktiler sikerler sikmiş sikmişler sikilmiş
sikeyim sikerim sikersin sikecem sikecek sikeceğim sikicem sikiyim
sikişmek sikişti sikişen sikişir
sikko sikik
götveren götverenler götlek götleri götlük götoş götoşlar götelek göttenci götünü götüne götünden götünde götüm götümü götümde götsüz
pezevenk pezevenkler pezevenklik pezo
kahpe kahbe kahpelik kahpeler kahpenin
kaltak kaltaklar kaltaklık
orospuluk
fahişe fahişeler fahişelik
sürtük sürtükler sürtüklük
şıllık şıllıklar
kevaşe kevaşeler
kerhane kerhaneler
gavat gavatlar gavatlık
ibne ibneler ibnelik ibnece ibneliği
puşt puştlar puştluk puşttur
yavşak yavşaklar yavşaklık yavşakça
dangalak dangalaklar dangalaklık
gerzek gerzekler gerzeklik
salak salaklar salaklık salakça
aptal aptallar aptallık aptalca
andaval avanak avanaklar avanaklık
mankafa mankafalar
ahmak ahmaklar ahmaklık
budala budalalar budalalık
embesil embesiller
beyinsiz beyinsizler
şerefsiz şerefsizler şerefsizlik
namussuz namussuzlar namussuzluk
onursuz onursuzlar onursuzluk
haysiyetsiz haysiyetsizler
ahlaksız ahlaksızlar ahlaksızlık
alçak alçaklar alçaklık
kodumun kodumunun kodugumun
sıçmak sıçtı sıçtım sıçtığım sıçıyor sıçarım sıçayım sıçacak sıçmış sıçmışlar sıçtığımın sıçılası
bokluk boktan boklu boklar boku bokum bokunu bokuna bokunda bokundan bokta
mastürbasyoncu
`);

// tam eslesme (=): kisa/belirsiz; yalniz sozcuk olarak
const trExact = words(`
amk amq amck amcık aq amg0 ammk amkk amına amınakoyim
sg oç ocçocuğu
yrrk yrk yrak
sktr sktir skm skim skerim skeyim skik
siktr sikt sıkt
piçler piçlik piçliği piçin piçleri
pickurusu piçkurusu
şerefsizin şerefsizi şerefsizim
dümbük dümbüğü
oruspu orspu orospi orsp orosbi oropsu orosbu
gotveren götveren
ibine ibneyim
hıyarto
bozuk
`).filter((w) => !['amg0', 'amına', 'amınakoyim', 'bozuk', 'hıyarto', 'amcık'].includes(w));

// ayirt edici uzun kokler (isaretsiz: kok + en fazla 7 harf)
const trRoot = words(`
sikindirik sikinti_dummy
`).filter((w) => !w.endsWith('_dummy'));

// tamlamalar (kufur / hakaret / cinsel)
const trPhrases = lines(`
amına koyayım
amına koyarım
amına koydum
amına koduğum
amına koyim
amına koyum
amına koyacağım
amına koduğumun
amına kodumun
amını sikeyim
amını sikerim
amına sokayım
amcığını sikeyim
ananı sikeyim
ananı sikerim
ananı avradını
anasını sikeyim
anasını sikerim
anasını satayım
anan avradın
ananın amı
ananın amına
ananın ağzına
bacını sikeyim
bacını sikerim
karını sikeyim
karını sikerim
ananı sikim
orospu çocuğu
orospu evladı
orospu piçi
orospunun evladı
orospunun çocuğu
fahişe evladı
kahpe evladı
kahpe doğurmuş
kancık evladı
it oğlu it
it herif
köpek oğlu
köpoğlu
köpoğlu köpek
eşek herif
eşek oğlu eşek
dallama herif
piç kurusu
piç herif
piçin evladı
pezevenk evladı
pezevenk herif
gerizekalı herif
geri zekalı
geri zekâlı
beyinsiz herif
aklını sikeyim
ağzına sıçayım
ağzına sıçarım
ağzına sıçtığım
ağzına sıçmak
ağzına sokayım
boku yedin
boku yemek
bokunu çıkarırım
bokunu çıkar
bok herif
bok kafalı
bok gibi
sıçtığımın
sik kafalı
sik kafa
sik kıllı
sikik herif
sikik kafalı
sike sike
sikine koyayım
sikini yerim
sikimi ye
sikimi yalarsın
sikimin ucu
sikimde değil
sikime değil
götünü sikeyim
götünü yalarım
götüne koyayım
götüne sokayım
götüne girerim
göt herif
göt lalesi
göt veren
göt oğlanı
göt kafalı
götüm kadar
taşak geçmek
taşaklarını sıkarım
yarrağı yedin
yarrağımı ye
yarrağımın başı
yarrak kafalı
yarrak gibi
amcık ağızlı
amcık ağız
amcık hoşafı
amcık herif
amık herif
orospu karı
orospu kadın
kaltak karı
sürtük karı
şerefsiz herif
namussuz herif
namussuz karı
ahlaksız herif
alçak herif
aşağılık herif
aşağılık adam
aşağılık yaratık
defol git
siktir git
siktir et
siktir olup git
siktir lan
siktir ordan
siktir oradan
sik oradan
gebermiş kahpe
geberesice
gebersin kahpe
bok ye
bok ye lan
bok ye orospu
git bok ye
yalnız orospu
lan orospu
lan pezevenk
lan piç
lan it
lan köpek
lan şerefsiz
lan göt
oç lan
aq lan
amk lan
amk oçu
amk çocuğu
amk evladı
amk piçi
amk kafalı
mk çocuğu
anan baban
ananı baban
`).filter((p) => !['yalnız orospu', 'anan baban', 'ananı baban', 'sikimde değil', 'sikime değil', 'mk çocuğu', 'lan it', 'lan köpek', 'git bok ye', 'defol git', 'bok gibi', 'taşak geçmek', 'lan göt', 'gebermiş kahpe', 'sikimin ucu', 'göt lalesi', 'göt herif'].includes(p));

// hakaret ek sozcukleri
const trInsult = words(`
hıyarağası kıro_dummy
`).filter((w) => !w.endsWith('_dummy') && w !== 'hıyarağası');

// uyusturucu satis argosu (satis/arz kaliplari; salt bilgi amacli sozcukler engellenmez)
const trDrug = lines(`
esrar satılır
esrar satarım
esrar satıyorum
esrar var
esrar lazım
esrar arıyorum
esrar al
esrar bulunur
bonzai
bonzai satılır
bonzai satarım
bonzai var
bonzai bulunur
bonzay
bonza
hap satılır
hap satarım
hap var
uyuşturucu hap satılır
extacy satılır
extasy satılır
ekstazi satılır
ekstazi hap
ekstazi var
mdma satılır
mdma var
kokain satılır
kokain satarım
kokain var
kokain bulunur
eroin satılır
eroin var
eroin satarım
skunk satılır
skunk var
marihuana satılır
marihuana var
esrar hap bonzai
toz satılır
toz var
uyuşturucu satılır
uyuşturucu satarım
uyuşturucu var
uyuşturucu bulunur
uyuşturucu temin
uyuşturucu siparişi
kapıya teslim esrar
kapıya teslim kokain
kapıya teslim uyuşturucu
elden teslim esrar
kaptagon
captagon
captagon satılır
`).filter((p) => !['esrar var', 'toz var', 'hap var', 'esrar al', 'esrar hap bonzai', 'toz satılır', 'bonza', 'esrar lazım'].includes(p));

// nefret soylemi (HATE kategorisi) - grup x kalip uretimi; yalniz asagilama/insanliktan cikarma/olum cagrisi
const trGroups = [
  ['yahudi', 'yahudiler', 'yahudileri'], ['ermeni', 'ermeniler', 'ermenileri'], ['kürt', 'kürtler', 'kürtleri'],
  ['arap', 'araplar', 'arapları'], ['rum', 'rumlar', 'rumları'], ['çingene', 'çingeneler', 'çingeneleri'],
  ['alevi', 'aleviler', 'alevileri'], ['sünni', 'sünniler', 'sünnileri'], ['laz', 'lazlar', 'lazları'],
  ['suriyeli', 'suriyeliler', 'suriyelileri'], ['afgan', 'afganlar', 'afganları'], ['zenci', 'zenciler', 'zencileri'],
  ['eşcinsel', 'eşcinseller', 'eşcinselleri'], ['türk', 'türkler', 'türkleri'], ['müslüman', 'müslümanlar', 'müslümanları'],
  ['hristiyan', 'hristiyanlar', 'hristiyanları'], ['mülteci', 'mülteciler', 'mültecileri'], ['gay', 'gayler', 'gayleri'],
  ['engelli', 'engelliler', 'engellileri'], ['ateist', 'ateistler', 'ateistleri'],
];
const trHate = [];
for (const [s, p, a] of trGroups) {
  for (const x of [`${s} piçi`, `${s} köpeği`, `${s} bozuntusu`, `${s} artığı`, `${s} çöpü`, `${s} dölü`, `${s} sürüsü`, `${s} kanseri`,
    `${s} pisliği`, `${p} defolsun`, `${p} gebersin`, `${p} geberin`, `${p} yok olsun`, `${p} ölsün`, `${p} köpektir`,
    `${p} pisliktir`, `${p} hayvandır`, `${p} insan değildir`, `${p} soysuzdur`, `${a} öldürün`, `${a} gebertin`,
    `${a} yakın`, `${a} asın`, `${a} kovun`, `${a} sürün`, `${p} gebertilmeli`, `${p} öldürülmeli`, `${p} yok edilmeli`,
    `${s} düşmanı`, `ölüm ${p}`, `kahrolsun ${s}`, `kahrolsun ${p}`]) trHate.push(x);
}
trHate.push(...lines(`
beyaz ırk üstündür
ırkçılık güzeldir
yabancılar defolsun
mülteciler defolsun
göçmenler defolsun
sığınmacılar defolsun
suriyeliler geri gitsin
araplar geri gitsin
kürtler geri gitsin
türkler geri gitsin
engelli piçi
özürlü piçi
özürlü herif
sakat herif
mongol herif
mongol çocuk
ibne herif
ibne çocuk
dönme herif
pezevenk gay
gavur piçi
gavur köpeği
kafir köpeği
kafir piçi
zenci köpek
zenci pislik
zenci piçi
çingene piçi
çingene köpek
çingene pislik
`));

// izinli (masum) Turkce sozcukler: tetiklense bile gecer; nötr kimlik sozcukleri ENGELLENMEZ
const allowTr = words(`
klasik klasikler klasikleşmek klasiklik klasikçi klasikleştirmek
basik basit basitlik basitçe basitleştirmek bassik
mesela meselâ mesele meseleler
sıkıntı sıkıntılı sıkıntılar sıkıntısız sıkıntıdan
sikke sikkeler sikkim sikkenin
sıkı sıkıca sıkıcı sıkış sıkışık sıkışmak sıkıştırmak sıkıştır sıkıştırma sıkılmak sıkılgan sıkıyönetim sıkıntı
sikinti sikintili sikintilar sikistirmak sikistirma sikistir sikisik sikici sikicilik sikilgan
sistem sistemler sistematik
amasya amasyalı ambulans ambalaj ambargo amfi amfitiyatro amiral amino amip
ankara antalya aksaray adana adıyaman afyon ağrı aydın
tasarım tasarımcı tasarla tasarlamak tasarruf tasarı tasarlanmış
kullanıcı kullanıcılar kullanım kullanmak
analiz analist analitik anayasa anadolu anne annem anneanne annelik
bilgisayar mühendislik mühendisliği yazılım topluluğu
sınıf sınıflar sınıflandırma
kasa kasım kasaba
taksim taksi taksit taksici
kitap kitaplık kitabevi
mal malzeme malzemeler malatya malikane maliyet maliye
bok_dummy
bokça_dummy
pasta pastane pastırma
oruç orucu oruçlu
aşık aşıkane
hasan hüseyin mehmet ahmet ali veli
ibnisina ibnihaldun ibni
götürmek götürdü götürüyor götürmüş götürülmek götürülecek götür götürsün
götürü götürüler
taşıt taşıma taşımacılık taşınmaz taşıyıcı
yarak_dummy
yaraklı_dummy
bozkır bozulmak bozuk bozulma bozuntu
salaş salata salatalık
sigorta sigara sigorta
gerçek gerçekten gerzel
ahmet ahmetçik
piknik pikap pilav pilot pişmek
kancalı
dalgın dalga dalgalı dalış
orospu_dummy
`).filter((w) => !w.endsWith('_dummy'));

// ============================================================ INGILIZCE
const EN_HEAD = `# Uygunsuz ifade filtresi - Ingilizce v2 listesi (elle yazilmis, uretici: scripts/profanity/gen-v2.js). ELLE DEGISTIRMEYIN.
# ~kok = kok + Ingilizce ek (s, es, ed, ing, er, y...) sozcuk sonuna kadar; =tam eslesme. Kisa kokler asla metin icinde aranmaz.`;

const enChain = words(`
fuck fucker fuckers fucked fucking fuckface fuckhead fuckwit fuckup fuckboy fuckwad fuckbuddy motherfucker motherfucking
fucktard fuckery fuckable fuckin fukin fuking fuk fuker fucc fucken fvck phuck phuk phucking
shit shite shitty shithead shitface shitbag shitter shitshow shitfaced shithole shitlist shitstorm horseshit dipshit batshit
bullshit bullshitter apeshit chickenshit dogshit
bitch bitchy bitching bitchass bitchboy bitchslap
asshole assholes asshat asswipe assclown assface asshead assmunch dumbass jackass smartass fatass lameass dipass jackasses
arsehole arseholes arsewipe
cunt cunts cunty cuntface cuntish
dickhead dickface dickwad dickweed dickbag dickish
cocksucker cocksuckers cocksucking cockhead cockface cockslap
pussy pussies pussyfart
whore whores whorish whorehouse whoring
slut sluts slutty slutbag
skank skanks skanky
wanker wankers wanking wankstain
twat twats twatface
bastard bastards
bollocks bugger buggered
prick_dummy
douchebag douchebags douchey
jerkoff jackoff
cumslut cumdump cumshot cumshots cumming cumbucket
blowjob blowjobs handjob handjobs rimjob rimjobs footjob titjob
dildo dildos buttplug fleshlight
pornstar pornhub pornography pornographic pornos
nigger niggers niggerish niggah niggaz nigga niggas
faggot faggots faggy faggotry
retard retards retarded retardation
spastic spastics
kike kikes
chinks_dummy
gook gooks
spic spics spick
wetback wetbacks
beaner beaners
raghead ragheads towelhead towelheads
sandnigger
camel_dummy
tranny trannies shemale shemales
dyke dykes
homo_dummy
negro_dummy
paki pakis
mongoloid mongoloids
slanteye slanteyes
coon_dummy
cracker_dummy
honky honkey honkies
darkie darkies
jigaboo jiggaboo
porchmonkey
monkey_dummy
sieg
`).filter((w) => !w.endsWith('_dummy'));

const enExact = words(`
ass arse tits boobs boobies nudes xxx hentai milf horny sexting
fck fcuk fuq fack f4ck fuc fukk fuk
sh1t shyt shit5
stfu gtfo kys
mf mfer mofo mothafucka mothafucker motherfuker
wtfuck
wanka
nutsack ballsack
gangbang gangbangs
dickhead dickheads
asswhole
cocksucker
cumguzzler
anal_dummy
jizzed jizzing idiotic idiotically moronic imbecilic
nipplefuck
rape_dummy
lmfao_dummy
`).filter((w) => !w.endsWith('_dummy'));

const enPhrases = lines(`
son of a bitch
sons of bitches
son of a whore
go fuck yourself
go fuck urself
fuck you
fuck off
fuck this
fuck your
fuck her
fuck him
fuck them
fuck me
fuck that
what the fuck
the fuck
shut the fuck up
shut the hell up
eat shit
eat my shit
suck my dick
suck my cock
suck my balls
suck a dick
suck dick
suck cock
lick my balls
kiss my ass
kiss my arse
piss off
piss on you
pissed off
up yours
up your ass
bite me
blow me
screw you
rot in hell
burn in hell
die in a fire
go to hell
stupid bitch
dumb bitch
dumb ass
dumb fuck
dumb cunt
fat bitch
ugly bitch
ugly cunt
cheap whore
dirty whore
dirty slut
big dick
small dick
tiny dick
hard cock
big cock
sex tape
sex video
sex videos
sex chat
free porn
porn video
porn videos
porn site
adult video
nude pics
nude photos
nude selfies
send nudes
naked pics
naked girls
horny girls
hot sluts
sex slave
sex slaves
sex toy
sex toys
rape her
rape you
rape them
i will rape
i will kill you
i will kill u
i will murder you
kill all
kill yourself
neck yourself
hang yourself
shoot yourself
gas the
death to
drop dead
go die
you should die
you deserve to die
hope you die
hope you get cancer
cancer ridden
camel jockey
sand monkey
sand nigger
dirty jew
dirty arab
dirty turk
dirty kurd
dirty muslim
dirty mexican
dirty gypsy
dirty nigger
dirty faggot
filthy jew
filthy arab
filthy muslim
filthy faggot
filthy nigger
white power
white pride
black power_dummy
heil hitler
sieg heil
kill the jews
kill the blacks
kill the gays
kill the muslims
kill the arabs
kill the whites_dummy
gas the jews
burn the jews
hang the niggers
lynch the niggers
fuck the jews
fuck the muslims
fuck the arabs
fuck the kurds
fuck the turks
fuck the blacks
fuck the gays
fuck islam
fuck allah
fuck jesus
fuck christ
fuck the pope
fuck mohammed
fuck muhammad
fuck ataturk
fuck turkey
fuck bingol
`).filter((w) => !w.endsWith('_dummy'));

const enGroups = [
  ['jews', 'jewish people'], ['muslims', 'muslim people'], ['blacks', 'black people'], ['gays', 'gay people'], ['asians', 'asian people'],
  ['mexicans', 'mexican people'], ['arabs', 'arab people'], ['turks', 'turkish people'], ['kurds', 'kurdish people'],
  ['armenians', 'armenian people'], ['christians', 'christian people'], ['immigrants', 'immigrant people'], ['refugees', 'refugee people'],
  ['lesbians', 'lesbian people'], ['transgender people', 'trans people'], ['disabled people', 'disabled persons'],
  ['women', 'females'], ['indians', 'indian people'], ['africans', 'african people'], ['gypsies', 'gypsy people'],
];
const enHate = [];
for (const [p, p2] of enGroups) {
  for (const x of [`${p} are vermin`, `${p} are subhuman`, `${p} are animals`, `${p} are filth`, `${p} are scum`, `${p} are cancer`,
    `${p} are disgusting`, `${p} are inferior`, `${p} should die`, `${p} must die`, `${p} deserve to die`, `${p} are a disease`,
    `${p} are parasites`, `${p} are rats`, `${p} are trash`, `${p} are dogs`, `${p} are monkeys`, `${p} are pigs`,
    `kill all ${p}`, `kill the ${p}`, `death to ${p}`, `hate ${p}`, `i hate ${p}`, `exterminate ${p}`, `exterminate the ${p}`,
    `deport all ${p}`, `ban all ${p}`, `go back to your country ${p}`, `${p2} are subhuman`, `${p2} should die`]) enHate.push(x);
}
enHate.splice(0, enHate.length, ...enHate.filter((x) => !/^(ban all|deport all)/.test(x)));

const allowEn = words(`
class classes classic classics classical classify classified classification classroom classmate classmates classy
assess assessed assessment assessments assessor assassin assassination assist assistant assistants assistance assign assigned
assignment assignments associate associated association associations assume assumed assumption assurance assure asset assets
assembly assemble assembled assay assault assent assert assertion
bass basement basic basics basically bassist bassoon
pass passage passages passenger passing passion passionate passive passport password passwords
mass massive massage massacre massachusetts
grass glass glasses brass harass
compass compassion embassy ambassador
scunthorpe essex sussex middlesex wessex
cockpit cocktail cockatoo cockroach cockerel cockburn peacock hancock hitchcock babcock woodcock
dickens dickinson dickson moby
shitake shiitake
grape grapes therapist therapists analyst analysts analysis analytics
document documents documentation documentary
penistone
arsenal arsenic
sextant sexton sextet essex
cumin cumulative cumbria cucumber circumstance circumference document documentary accumulate
analyze analyzed analysis
button buttons butter butterfly buttress
shell shellfish shitstorm_dummy
hello hell_dummy
title titles titled titan titanic titration
tits_dummy
nigeria nigerian niger nigeria's
spice spicy spiced spic_dummy
scrap scrape scrapbook
japan japanese
tranny_dummy
fagot_dummy
bingol bingöl
computer science engineering software university campus
kikes_dummy
therapist
mishit
cocoa coconut
pussycat pussyfoot
skate skater skating
witch switch
peniston
glasshouse
sassy classy brassy
retardant flame-retardant
niggard niggardly
analogy analogue
rape_dummy grape grapefruit drape drapes draper scrape trapeze
cunning
dykes_dummy
hoe_dummy
muslim muslims jewish jews arab arabs turk turks turkish kurd kurds kurdish armenian christian christians buddhist hindu
gay gays lesbian lesbians transgender bisexual homosexual homosexuality queer
black white asian african european american
disabled disability blind deaf autistic autism
immigrant immigrants refugee refugees migrant migrants
`).filter((w) => !w.endsWith('_dummy'));

// ============================================================ ARAPCA
const AR_HEAD = `# Uygunsuz ifade filtresi - Arapca v2 listesi (elle yazilmis, uretici: scripts/profanity/gen-v2.js). ELLE DEGISTIRMEYIN.
# Arapca girisler tam kok eslesmesi yapar; harekeler, tatweel, alef/ya/ta marbuta varyantlari ve on/son ekler otomatik soyulur.
# Latin harfli Arapca (arabizi) yazimlar ayni dosyadadir. Rakam iceren arabizi ("a7a") leet ile cakistigi icin eklenmez.`;

const arWords = words(`
كسمك كسمين كسها كسهم كسي كسك كسو كسخت كسختك كسامك كسيخت كسمكم
زبي زبك زبه زبر_dummy
ايري ايرك ايره ايرها
طيزي طيزك طيزها طيزه
نيك نيكة نيكها نيكك نيكني نيكنا ناك ناكك ناكها ينيك ينيكك ينيكها انيك انيكك نيكو
منيوك منيوكة منيوكه منيوكين منيك منيكة منيكه منايك
متناك متناكة متناكه متناكين
شرموط شرموطة شرموطه شراميط شرموطات شرموطين شرمط
عاهر عاهرة عاهره عواهر عهر
قحبة قحبه قحاب قحبات قحاب_dummy
زانية زاني زناة
لواط لوطي لوطية لوطيين لياط
سحاق سحاقية سحاقيات
خنيث مخنث مخنثين مخنثة مأبون
ديوث ديوثة دياثة ديوثين
قواد قوادة قوادين قوادون
معرص معرصة معرصين عرص عرصة عراص
ابن_dummy
ولد_dummy
خرا خره خراء
بعبص بعبصة
فاجرة فاجرات
ساقطة ساقطات
منحلة
حقير_dummy
وسخة
لعن_dummy
ينعل ينعلك
كلبة_dummy
زفت_dummy
مصاص
مص_dummy
تمص تمصني تمصيني
امص امصني مصني
ارضع_dummy
ينيكو
نياك نياكة
بزاز بزازك بزازها
عير_dummy
هبل_dummy
عاهرات
زنا_dummy
`).filter((w) => !w.endsWith('_dummy'));

const arPhrases = lines(`
كس امك
كس أمك
كس اختك
كس أختك
كس عرضك
كس دينك
كس ربك
كس الله
كس محمد
كس النبي
كس المسيح
كس عيسى
كس الدين
كس الاسلام
كس الإسلام
ابن الكلب
ابن الشرموطة
ابن الشرموطه
ابن القحبة
ابن القحبه
ابن العاهرة
ابن العاهره
ابن الزنا
ابن الحرام
ابن المتناكة
ابن المتناكه
ابن الوسخة
ابن الوسخه
ابن الخرا
ابن الكلبة
ابن الكلبه
ابن الزانية
ابن الزانيه
ابن اللبوة
ولد الحرام
ولد القحبة
ولد القحبه
ولد الشرموطة
ولد الشرموطه
ولد الكلب
ولد الزنا
ولد العاهرة
بنت الكلب
بنت الحرام
بنت القحبة
بنت الشرموطة
بنت الزنا
بنت العاهرة
يا ابن الكلب
يا ابن الحرام
يا ابن الشرموطة
يا ابن القحبة
يا كلب
يا كلبة
يا حمار
يا حمارة
يا خنزير
يا خنزيرة
يا حيوان
يا حقير
يا حقيرة
يا وسخ
يا وسخة
يا نذل
يا نذلة
يا قذر
يا قذرة
يا غبي
يا غبية
يا أحمق
يا احمق
يا حثالة
يا زبالة
يا ساقط
يا ساقطة
يا منحط
يا منحطة
يا عرص
يا عرصة
يا معرص
يا شرموط
يا شرموطة
يا قحبة
يا عاهرة
يا ديوث
يا قواد
يا منيوك
يا متناك
يا لوطي
يا خول
يا كافر
يا كفار
يا ملعون
يا ملعونة
يلعن ابوك
يلعن أبوك
يلعن ابو
يلعن امك
يلعن أمك
يلعن دينك
يلعن شرفك
يلعن عرضك
يلعن ربك
يلعن الله
يلعن النبي
يلعن اجدادك
يلعن روحك
ينعل ابوك
ينعل أبوك
ينعل امك
ينعل أمك
ينعل دينك
ينعل ابو
اخرس يا كلب
اخرس يا حمار
اخرس يا حقير
اخرس يا ابن
روح انيك
روح نيك
روح تنيك
اذهب إلى الجحيم
روح في داهية_dummy
نيك امك
نيك أمك
نيك اختك
نيك أختك
نيك عرضك
انيك امك
انيك أمك
انيك اختك
انيك أختك
انيك عرضك
اللي خلفك
اللي خلفوك
يا ابن ستين كلب
ابن ستين كلب
ابن سبعين كلب
بنت ستين كلب
مص زبي
مص زبري
مص ايري
مص كسي
مصي زبي
مصي زبري
لحس كسي
لحس زبي
لحس طيزي
خد في طيزك
خذ في طيزك
في طيزك
في طيزه
في كسك
في كس امك
في زبك
في ايرك
تعال انيكك
تعالي انيكك
اريد ان انيكك
بدي نيكك
بدي نيك
بدي انيكك
بدي اياكي نيك
فيديو سكس
فيديوهات سكس
افلام سكس
أفلام سكس
افلام جنسية
أفلام جنسية
افلام اباحية
أفلام إباحية
صور سكس
قصص سكس
قصص جنسية
قصص نيك
قصص محارم
سكس محارم
سكس عربي
سكس مترجم
سكس امهات
سكس مصري
سكس خليجي
سكس لبناني
سكس سوري
سكس تركي
سكس مجاني
نيك مجاني
نيك عربي
نيك مصري
نيك خليجي
نيك بنات
نيك محارم
بنات ليل
بنات للمتعة
بنات الهوى
ارقام بنات
أرقام بنات
ارقام شراميط
ارقام عاهرات
دعارة
دعارة اون لاين
`).filter((w) => !w.endsWith('_dummy') && !['دعارة', 'اللي خلفك', 'اللي خلفوك', 'يا كافر', 'يا كفار', 'يا ملعون', 'يا ملعونة', 'اذهب إلى الجحيم', 'اخرس يا ابن', 'في طيزه', 'يلعن ابو'].includes(w));

const arDrug = lines(`
حشيش للبيع
حشيش متوفر
حشيش متاح
حشيش للتوصيل
كبتاجون للبيع
كبتاجون متوفر
كبتاجون
كوكايين للبيع
كوكايين متوفر
هيروين للبيع
هيروين متوفر
حبوب مخدرة للبيع
حبوب مخدرة متوفرة
حبوب مهلوسة للبيع
مخدرات للبيع
مخدرات متوفرة
مخدرات للتوصيل
مخدرات توصيل
بيع مخدرات
بيع حشيش
بيع كبتاجون
بيع كوكايين
ترامادول للبيع
ترامادول متوفر
ماريجوانا للبيع
ماريجوانا متوفرة
بودرة للبيع
كريستال ميث للبيع
كريستال ميث متوفر
`);

const arGroups = [
  ['اليهود', 'لليهود'], ['النصارى', 'للنصارى'], ['المسيحيين', 'للمسيحيين'], ['الشيعة', 'للشيعة'], ['السنة', 'للسنة'],
  ['الاكراد', 'للاكراد'], ['الأكراد', 'للأكراد'], ['الاتراك', 'للاتراك'], ['الأتراك', 'للأتراك'], ['العرب', 'للعرب'],
  ['السود', 'للسود'], ['المثليين', 'للمثليين'], ['اللاجئين', 'للاجئين'], ['السوريين', 'للسوريين'], ['الافارقة', 'للافارقة'],
  ['الأفارقة', 'للأفارقة'], ['الايزيديين', 'للايزيديين'], ['الدروز', 'للدروز'], ['العلويين', 'للعلويين'], ['المسلمين', 'للمسلمين'],
];
const arHate = [];
for (const [g, l] of arGroups) {
  for (const x of [`${g} كلاب`, `${g} خنازير`, `${g} حثالة`, `${g} قذرين`, `${g} حيوانات`, `${g} وسخين`, `${g} اوساخ`, `${g} أوساخ`,
    `${g} قرود`, `${g} جرذان`, `${g} فئران`, `${g} سرطان`, `${g} ليسوا بشر`, `${g} ليسو بشر`, `الموت ${l}`, `الموت ${g}`,
    `يجب قتل ${g}`, `اقتلوا ${g}`, `اذبحوا ${g}`, `احرقوا ${g}`, `اطردوا ${g}`, `ابيدوا ${g}`, `أبيدوا ${g}`, `ابادة ${g}`,
    `إبادة ${g}`, `اكرههم ${g}`, `اكره ${g}`, `أكره ${g}`, `تبا ${l}`, `تباً ${l}`, `لعنة الله على ${g}`, `قتل ${g}`]) arHate.push(x);
}
arHate.push(...lines(`
رافضي
روافض
رافضة
يا رافضي
يا كافر ابن كلب
عبد اسود
يا عبد
يا عبيد
يا زنجي
يا اسود
يا أسود
زنجي وسخ
زنجي قذر
كردي وسخ
كردي قذر
كردي حقير
تركي وسخ
تركي قذر
تركي حقير
عربي وسخ
عربي قذر
عربي حقير
يهودي ابن كلب
يهودي وسخ
يهودي قذر
يهودي حقير
نصراني وسخ
نصراني قذر
سوري وسخ
سوري قذر
سوري حقير
لاجئ وسخ
لاجئ قذر
مثلي وسخ
مثلي قذر
مثلي حقير
شاذ جنسيا_dummy
هتلر كان على حق
هتلر على حق
عاش هتلر
تحيا النازية
`).filter((w) => !w.endsWith('_dummy')));

const arLatin = lines(`
sharmouta
sharmoota
sharmota
sharmuta
sharmouta
charmouta
charmoota
charmota
sharmouti
sharamit
sharameet
sharmoot
sharmouty
kahba
kahbe
kahbeh
kahbi
qahba
qahbeh
manyouk
manyook
manyoka
manyouka
manyouk
manyuk
manyuka
manyoki
metnak
metnaka
mitnak
mitnaka
mitnaki
khawal
khawalat
ibn el sharmouta
ibn el sharmoota
ibn el sharmota
ibn el kalb
ibn el kahba
ibn el kahbeh
ibn el metnaka
ibn el metnak
ibn el haram
ibn el zina
ibn el wasikha
ibn el 3ahira_dummy
ibn al kalb
ibn al sharmouta
ibn al kahba
ibn al haram
ibn al zina
ibn kalb
ibn sharmouta
ibn kahba
ibn haram
bint el kalb
bint el sharmouta
bint el kahba
bint el haram
bint al kalb
bint al sharmouta
bint al kahba
bint kalb
bint sharmouta
bint kahba
walad el kalb
walad el haram
walad el kahba
walad el sharmouta
walad al kalb
walad al haram
walad al kahba
walad al sharmouta
ya kalb
ya ibn el kalb
ya ibn el sharmouta
ya ibn el kahba
ya ibn el haram
ya ibn al kalb
ya ibn al sharmouta
ya ibn al kahba
ya sharmouta
ya sharmoota
ya kahba
ya manyouk
ya metnak
ya metnaka
ya khawal
ya haywan_dummy
kos omak
kos ummak
kos omk
kos emak
kos ommak
kus omak
kus ummak
kus omk
kus emak
kus ommak
kuss omak
kuss ummak
koss omak
koss ummak
kosomak
kosommak
kosomk
kusomak
kusommak
kusomk
kos okhtak
kos ukhtak
kos okhtik
kus okhtak
kus ukhtak
kos ekhtak
kos ekhtek
kosokhtak
kosukhtak
kos abouk_dummy
kos deenak
kos dinak
kos deenek
kus deenak
kus dinak
kos rabbak
kos rabak
kos allah
kus allah
kos el deen
kos el din
kus el deen
kos el islam
ayre fik
ayre feek
ayre bik
ayre beek
ayri fik_dummy
nik omak
nik ommak
nik okhtak
nik ukhtak
nik ekhtak
nik ummak
neek omak
neek ommak
neek okhtak
neek ummak
nayek
nayik
nayeek
nayeko
yenik
yenikak
yenikek
yenik omak
yenik ommak
yenik okhtak
anikak
anikek
anik omak
anik okhtak
zebi
zobry
zobri
zobbi
zobar_dummy
zebbi
zebbak
zebik
zubr
zubri
zubbi
tiz omak
tiz ommak
tiz okhtak
teez omak
teez ommak
teez okhtak
teezak
teezek
tizak
tizek
tizi
teezi
tezak_dummy
tezek_dummy
sharmout
sharmoutteh
charmoutah
ahbal_dummy
mkhanath_dummy
mkhannath
mokhannath
mokhanath
makhannath
dayouth
dayyouth
dayouth
dayuth
dayyuth
qawwad_dummy
kawwad_dummy
mo3ars_dummy
moarras
mo arras
mo3arras_dummy
arss
mu'arras_dummy
loti
lawat
lawati
lawwat
sa7a2_dummy
sahaq
sahhaq
sahaqiya
sahhaqiya
oss omak
oss ommak
oss okhtak
oss ukhtak
`).filter((w) => !w.endsWith('_dummy') && !/[0-9]/.test(w));

const allowAr = words(`
كأس كاس كأس_dummy كسر كسل كسوف كسب كساء كسا
زبد زبدة زبون زبيب زبائن
نيكولا نيكول نيكي
عراق عرب عربي عربية
خراب خريف خرائط خروف خرج
مسلم مسلمون مسيحي مسيحيون يهودي يهود كردي كرد تركي اتراك أتراك سوري سوريون لاجئ لاجئون
مثلي مثليون شاذ شاذة اسود أسود سود زنجي
جامعة بينغول جامعه
طيار طيارة طيران
نهار نهاية
مدرسة مدرس طالب طلاب
صلاة صلاة_dummy
`).filter((w) => !w.endsWith('_dummy'));


// ============================================================ BUDAMA (belirsiz/masum cakisma riski olan girisler)
const DROP = new Set(`
alçak alçaklar alçaklık sıkt ocçocuğu captagon kaptagon
spic spics spick sieg honky honkey honkies xxx sh1t shyt shit5 mf f4ck wanka
kill_all gas_the death_to zubr loti lawat lawati lawwat arss tizi teezi
نيكو مصني مصاص زانية زاني زناة ساقطة ساقطات منحلة قواد قوادة قوادين قوادون
`.split(/\s+/).filter(Boolean));
function prune(arr) {
  return arr.filter((l) => {
    const w = l.replace(/^[=*!+~]+/, '');
    if (DROP.has(w)) return false;
    if (/^(yenik|anik|nayek|nayik|nayeek|nayeko)/.test(w)) return false;
    return true;
  });
}
const DROP_PHRASE = [
  /^kill all$/, /^gas the$/, /^death to$/, /^go to hell$/, /^sex slaves?$/, /^drop dead$/, /^kill yourself$/,
  /\bfuck/, /\bshit/, /\bpiss/, /\bbitch/, /\bcock/, /\bdick/, /\bwhore/, /^(eat|suck|lick) /, /^up your ass$/, /^kiss my ar?se$/,
  / var$/, / bulunur$/, /^اخرس/, /^(في|مص|مصي|لحس)/, /^(كس|نيك|انيك) /, /^سكس|سكس$/, / سكس/, /^نيك /, / نيك$/,
  /^(ابن|ولد|بنت) ال(شرموط|قحب|عاهر|متناك)/, /^يا (شرموط|قحب|عاهر|ديوث|منيوك|متناك|لوطي|خول|عرص|معرص|كافر|كفار|ملعون)/,
  /^يلعن ابو$/, /^يلعن أبو$/, /^(قتل|ابادة|إبادة) /, / düşmanı$/, /^يا ساقط/, /^يا منحط/, /^moby/,
];
function prunePhrases(arr) {
  return arr.filter((l) => !DROP_PHRASE.some((r) => r.test(l)));
}

// ============================================================ YAZ
function header(h) { return h + '\n'; }
function section(title, arr) { return arr.length ? `\n# --- ${title} ---\n${arr.join('\n')}\n` : ''; }
function write(name, content) { fs.writeFileSync(path.join(OUT, name), content, { encoding: 'utf8' }); }

const trAll = prune(prunePhrases(uniq([
  ...trChain.map((w) => '+' + w),
  ...trExact.map((w) => '=' + w),
  ...trRoot,
  ...trPhrases,
  ...trInsult,
  ...trDrug,
])));
// Not: chain satirlari ayni kokun tum cekimlerini zaten kapsar; ayrica yazilmis cekimli sozcukler istenen
// "cekimli biçim" kapsamini acikca belgeler ve dogrudan test edilir.
write('profanity-v2-tr.txt', header(TR_HEAD) + section('Kufur/hakaret/cinsel (kok + ek zinciri, tam eslesme, tamlama)', trAll));
write('profanity-v2-hate-tr.txt', header('# Nefret soylemi (HATE) - Turkce v2 (uretici: scripts/profanity/gen-v2.js). Yalniz asagilama/insanliktan cikarma/olum cagrisi kaliplari; notr kimlik sozcukleri ("kurt", "turk", "yahudi", "gay", "engelli"...) ENGELLENMEZ (izin listesi).') + section('Grup kaliplari', prunePhrases(uniq(trHate))));
write('profanity-v2-drug-tr.txt', header('# Uyusturucu satis argosu (Turkce v2): yalnizca satis/arz kaliplari; salt bilgi amacli sozcukler engellenmez.') + section('Satis kaliplari', prunePhrases(trDrug).filter((p) => !/^captagon$|^kaptagon$/.test(p))));

const enAll = prune(uniq([
  ...enChain.map((w) => '~' + w),
  ...enExact.map((w) => '=' + w),
  ...prunePhrases(enPhrases),
]));
write('profanity-v2-en.txt', header(EN_HEAD) + section('Profanity / sexual / abuse', enAll));
write('profanity-v2-hate-en.txt', header('# Nefret soylemi (HATE) - Ingilizce v2 (uretici: scripts/profanity/gen-v2.js). Neutral identity words are never blocked.') + section('Group patterns', prunePhrases(uniq(enHate))));

const arAll = prune(prunePhrases(uniq([...arWords, ...arPhrases, ...arLatin, ...arDrug])));
write('profanity-v2-ar.txt', header(AR_HEAD) + section('Arapca ve arabizi', arAll));
write('profanity-v2-hate-ar.txt', header('# Nefret soylemi (HATE) - Arapca v2 (uretici: scripts/profanity/gen-v2.js).') + section('Grup kaliplari', prunePhrases(uniq(arHate))));

const allowAll = prune(uniq([...allowTr, ...allowEn, ...allowAr]));
write('profanity-allow-v2.txt', header('# Izin listesi v2 (tr + en + ar): masum sozcukler. Bir sozcuk burada (veya yalniz bilinen ek zinciriyle) ise filtre ona dokunmaz.\n# Notr kimlik sozcukleri (kurt, turk, arap, yahudi, gay, engelli, siyah, musluman...) hicbir listede engellenmez; guvenlik agi olarak burada da yer alir.') + section('Izinli', allowAll));

console.log(JSON.stringify({
  tr: trAll.length, trHate: prunePhrases(uniq(trHate)).length, trDrug: prunePhrases(trDrug).length, en: enAll.length, enHate: prunePhrases(uniq(enHate)).length,
  ar: arAll.length, arHate: prunePhrases(uniq(arHate)).length, allow: allowAll.length,
}));
