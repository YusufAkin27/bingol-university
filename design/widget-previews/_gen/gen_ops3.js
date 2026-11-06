// poll / quickaccess / social widget onizleme uretici (HTML/CSS -> Playwright PNG, 3x).
// Calistirma: PW=<playwright yolu> CHR=<chrome.exe> MOB=<mobile klasoru> node gen_ops3.js
const fs=require('fs'),path=require('path');
const ROOT=path.resolve(__dirname,'..');
const {chromium}=require(process.env.PW);
const C={dark:{bg:'#111113',chip:'#1F1F23',t1:'#FAFAFA',t2:'#A1A1AA',t3:'#71717A',bd:'#27272A',bar:'#FAFAFA',track:'#27272A',invbg:'#FAFAFA',invfg:'#09090B',red:'#F2555A',logo:'logo_dark.png'},
light:{bg:'#FFFFFF',chip:'#F4F4F5',t1:'#09090B',t2:'#52525B',t3:'#71717A',bd:'#E4E4E7',bar:'#09090B',track:'#E4E4E7',invbg:'#09090B',invfg:'#FFFFFF',red:'#DC2626',logo:'logo_light.png'}};
const SZ={ios:{small:[158,158],medium:[338,158],large:[338,354],r:22},android:{'2x2':[170,170],'4x2':[350,170],'4x4':[350,350],r:28}};
const ico=(n,s=14)=>{const p={
vote:'<path d="m9 12 2 2 4-4"/><path d="M5 7c0-1.1.9-2 2-2h10a2 2 0 0 1 2 2v12H5V7Z"/><path d="M22 19H2"/>',
utensils:'<path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2M7 2v20M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7"/>',
cal:'<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
calclock:'<path d="M21 7.5V6a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h3.5M16 2v4M8 2v4M3 10h5"/><circle cx="16" cy="16" r="6"/><path d="M16 14v2l1 1"/>',
ticket:'<path d="M2 9a3 3 0 0 1 0 6v2a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-2a3 3 0 0 1 0-6V7a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2Z"/><path d="M13 5v2M13 17v2M13 11v2"/>',
users:'<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.9M16 3.1a4 4 0 0 1 0 7.8"/>',
chat:'<path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z"/>',
qr:'<rect x="3" y="3" width="5" height="5" rx="1"/><rect x="16" y="3" width="5" height="5" rx="1"/><rect x="3" y="16" width="5" height="5" rx="1"/><path d="M21 16h-3a2 2 0 0 0-2 2v3M21 21v.01M12 7v3a2 2 0 0 1-2 2H7M3 12h.01M12 3h.01M12 16v.01M16 12h1M21 12v.01M12 21v-1"/>',
news:'<path d="M4 22h16a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v16a2 2 0 0 1-2 2Zm0 0a2 2 0 0 1-2-2v-9c0-1.1.9-2 2-2h2"/><path d="M18 14h-8M15 18h-5M10 6h8v4h-8V6Z"/>',
search:'<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
bell:'<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
heart:'<path d="M19 14c1.5-1.5 3-3.2 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4 3 5.5l7 7Z"/>',
check:'<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
lock:'<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
chev:'<path d="m9 18 6-6-6-6"/>',
msg:'<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2Z"/>'}[n];
return `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">${p}</svg>`};
const CSS=(c,w,h,r)=>`@font-face{font-family:Inter;src:url(assets/Inter-Regular.ttf);font-weight:400}
*{box-sizing:border-box;margin:0;padding:0;font-weight:400;font-family:Inter,sans-serif}
html,body{background:transparent}
.w{width:${w}px;height:${h}px;border-radius:${r}px;background:${c.bg};color:${c.t1};border:1px solid ${c.bd};padding:16px;display:flex;flex-direction:column;overflow:hidden;position:relative}
.cap{font-size:10px;line-height:12px;letter-spacing:.08em;text-transform:uppercase;color:${c.t3};display:flex;align-items:center;gap:4px;white-space:nowrap}
.cap svg{flex:none}
.hd{display:flex;justify-content:space-between;align-items:center;height:16px;margin-bottom:12px;flex:none}
.hd img{height:12px;opacity:.9}
.t1{color:${c.t1}}.t2{color:${c.t2}}.t3{color:${c.t3}}
.disp{font-size:22px;line-height:26px;letter-spacing:-.02em}
.ttl{font-size:17px;line-height:22px;letter-spacing:-.01em}
.q15{font-size:15px;line-height:20px;letter-spacing:-.01em}
.bd{font-size:13px;line-height:18px}.bs{font-size:12px;line-height:16px}.mi{font-size:11px;line-height:14px}
.num{font-size:34px;line-height:38px;letter-spacing:-.03em}
.ell{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;min-width:0}
.ell2{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.ell3{display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}
.row{display:flex;align-items:center;gap:8px}.sp{flex:1;min-width:0}
.grow{flex:1}.col{display:flex;flex-direction:column}
.kc{display:flex;align-items:center;gap:4px;font-size:12px;line-height:16px;color:${c.t2};white-space:nowrap}
.div{height:1px;background:${c.bd}}
.inv{background:${c.invbg};color:${c.invfg};border-radius:999px;padding:6px 14px;font-size:13px;line-height:16px;white-space:nowrap;display:inline-flex;align-items:center;gap:6px}
.chip{background:${c.chip}}
.bar{height:4px;border-radius:2px;background:${c.track};overflow:hidden}.bar i{display:block;height:100%;border-radius:2px;background:${c.bar}}
.bar.dimb i{opacity:.45}
.tile{background:${c.chip};border-radius:14px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;min-width:0}
.tile .mi{max-width:100%;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:${c.t2}}
.red{color:${c.red}}
`;
const head=(c,label,icon,mb)=>`<div class="hd"${mb!=null?` style="margin-bottom:${mb}px"`:''}><div class="cap">${ico(icon,12)}${label}</div><img src="assets/${c.logo}"></div>`;

// ---- 1) Gunun Anketi ----
const OPT3=[['Çok iyi',54],['İdare eder',31],['Kötü',15]];
const OPT4=[['Çok iyi',48],['İdare eder',29],['Kötü',15],['Fikrim yok',8]];
const Q='Yemekhanede akşam menüsü nasıl?';
function poll(c,sz,empty){
 if(empty){ if(sz==='s')return `${head(c,'Anket','vote')}<div class="grow col" style="justify-content:center"><div class="disp ell2">Bugün anket yok</div><div class="bs t3" style="margin-top:4px">Yenisi yayımlanınca</div></div>`;
  return `${head(c,'Günün anketi','vote')}<div class="grow col" style="justify-content:center"><div class="disp">Bugün anket yok</div><div class="bd t2" style="margin-top:4px">Yeni anket yayımlanınca burada görünür</div></div>`;}
 if(sz==='s') return `${head(c,'Anket','vote')}<div class="q15 ell3">${Q}</div><div class="grow"></div><div class="row"><span class="inv">Oy ver</span></div>`;
 const opt=(o,i,n,tall)=>`<div class="col" style="gap:${tall?6:5}px"><div class="row"><div class="${tall?'bd':'bs'} ell sp t1">${o[0]}</div><div class="${tall?'bd':'bs'} ${i===0?'t1':'t2'}">%${o[1]}</div></div><div class="bar ${i===0?'':'dimb'}"><i style="width:${o[1]}%"></i></div></div>`;
 if(sz==='m') return `${head(c,'Günün anketi','vote',8)}<div class="row grow" style="align-items:stretch;gap:16px"><div class="col" style="width:40%;flex:none"><div class="q15 ell3">${Q}</div><div class="grow"></div><div class="mi t3 ell">1.284 oy · gizli</div></div><div class="col sp" style="justify-content:space-between">${OPT3.map((o,i)=>`<div class="col" style="gap:4px"><div class="row"><div class="bs ell sp t1">${o[0]}</div><div class="bs ${i===0?'t1':'t2'}">%${o[1]}</div></div><div class="bar ${i===0?'':'dimb'}"><i style="width:${o[1]}%"></i></div></div>`).join('')}</div></div>`;
 return `${head(c,'Günün anketi','vote')}<div class="ttl ell2" style="margin-bottom:16px">${Q}</div><div class="col" style="gap:14px">${OPT4.map((o,i)=>opt(o,i,4,true)).join('')}</div><div class="grow"></div><div class="row"><div class="kc">${ico('lock',12)}Oylar gizlidir · 1.284 oy</div><div class="sp"></div><div class="kc t1">Ayrıntı${ico('chev',12)}</div></div>`;
}
// ---- 2) Hizli Erisim ----
const QA=[['utensils','Yemek'],['calclock','Ders'],['ticket','Etkinlik'],['users','Kulüpler'],['chat','Sohbet'],['qr','QR Kodum'],['news','Haberler'],['search','Ara']];
function quick(c,sz,empty){
 const tile=(x,ic,lab,tw,th,isz)=>`<div class="tile" style="width:${tw}px;height:${th}px;border-radius:${tw>60?14:12}px"><span class="t1">${ico(ic,isz)}</span><div class="mi">${lab}</div></div>`;
 const pick=[QA[0],QA[2],QA[4],QA[5]];
 if(sz==='s'){const gw=isIosSmall?59:65; return `<div style="display:grid;grid-template-columns:1fr 1fr;grid-template-rows:1fr 1fr;gap:8px;flex:1;margin:-0px">${pick.map(x=>`<div class="tile"><span class="t1">${ico(x[0],22)}</span><div class="mi">${x[1]}</div></div>`).join('')}</div>`;}
 if(sz==='m') return `${head(c,'Hızlı erişim','search',10)}<div style="display:grid;grid-template-columns:repeat(4,1fr);grid-template-rows:1fr 1fr;gap:8px;flex:1">${QA.map(x=>`<div class="tile" style="flex-direction:row;gap:0"><div class="col" style="align-items:center;gap:4px"><span class="t1">${ico(x[0],18)}</span><div class="mi">${x[1]}</div></div></div>`).join('')}</div>`;
 return `<div class="hd" style="margin-bottom:4px"><div class="cap">${ico('search',12)}Hızlı erişim</div><img src="assets/${c.logo}"></div><div class="ttl" style="margin-bottom:2px">Neye bakmak istersin?</div><div class="bs t3" style="margin-bottom:14px">Dokun, uygulamada doğrudan aç</div><div style="display:grid;grid-template-columns:repeat(4,1fr);grid-template-rows:1fr 1fr;gap:8px;flex:1">${QA.map(x=>`<div class="tile"><span class="t1">${ico(x[0],24)}</span><div class="mi">${x[1]}</div></div>`).join('')}</div>`;
}
let isIosSmall=true;
// ---- 3) Sosyal Bildirim Ozeti ----
const S={msg:3,bell:5,like:12};
function social(c,sz,empty){
 if(empty){ const ck=`<span class="t1">${ico('check',sz==='s'?20:22)}</span>`; if(sz==='s')return `${head(c,'Sosyal','chat')}<div class="grow col" style="justify-content:center;gap:6px">${ck}<div class="disp">Her şey güncel</div></div>`;
  return `${head(c,'Sosyal özet','chat')}<div class="grow col" style="justify-content:center;gap:6px">${ck}<div class="disp">Her şey güncel</div><div class="bd t2">Yeni mesaj, bildirim ya da beğeni yok</div></div>`;}
 if(sz==='s') return `${head(c,'Mesaj','msg')}<div class="num">${S.msg}</div><div class="bs t2">okunmamış mesaj</div><div class="grow"></div><div class="row" style="gap:12px"><div class="kc">${ico('bell',12)}${S.bell}</div><div class="kc"><span class="red">${ico('heart',12)}</span>${S.like}</div></div>`;
 const col=(ic,n,lab,red)=>`<div class="col sp" style="gap:4px"><div class="${red?'red':'t2'}">${ico(ic,18)}</div><div class="num" style="margin-top:6px">${n}</div><div class="bs t2 ell">${lab}</div></div>`;
 const vd=`<div style="width:1px;align-self:stretch;background:${c.bd}"></div>`;
 if(sz==='m') return `${head(c,'Sosyal özet','chat',12)}<div class="row grow" style="align-items:flex-start;gap:12px">${col('msg',S.msg,'Mesaj',0)}${vd}${col('bell',S.bell,'Bildirim',0)}${vd}${col('heart',S.like,'Beğeni',1)}</div>`;
 const line=(ic,n,lab,sub,red)=>`<div class="row chip" style="height:64px;border-radius:14px;padding:0 14px;gap:12px"><div class="${red?'red':'t1'}">${ico(ic,22)}</div><div class="col sp"><div class="bd t1 ell">${lab}</div><div class="mi t3 ell">${sub}</div></div><div class="num" style="font-size:28px;line-height:32px">${n}</div></div>`;
 return `${head(c,'Sosyal özet','chat')}<div class="ttl" style="margin-bottom:2px">Bugün yeni olanlar</div><div class="bs t3" style="margin-bottom:14px">Yalnızca sayılar gösterilir</div><div class="col" style="gap:8px">${line('msg',S.msg,'Okunmamış mesaj','Sohbetler',0)}${line('bell',S.bell,'Yeni bildirim','Bildirim kutusu',0)}${line('heart',S.like,'Yeni beğeni ve takipçi','Keşfet',1)}</div>`;
}
const WID={poll,quickaccess:quick,social};
(async()=>{
 const br=await chromium.launch({executablePath:process.env.CHR});
 for(const slug of Object.keys(WID)){
  const out=path.join(ROOT,slug),st=path.join(out,'stitch','html');
  fs.mkdirSync(path.join(st,'assets'),{recursive:true});
  fs.copyFileSync(path.join(process.env.MOB,'assets/fonts/Inter-Regular.ttf'),path.join(st,'assets/Inter-Regular.ttf'));
  for(const f of ['logo_dark.png','logo_light.png'])fs.copyFileSync(path.join(process.env.MOB,'assets/branding',f),path.join(st,'assets',f));
  const jobs=[];
  for(const plat of ['ios','android'])for(const [k,v] of Object.entries(SZ[plat])){ if(k==='r')continue;
   const sz=({small:'s','2x2':'s',medium:'m','4x2':'m',large:'l','4x4':'l'})[k];
   for(const th of ['light','dark'])jobs.push({plat,k,sz,th,w:v[0],h:v[1],r:SZ[plat].r,empty:false});
  }
  for(const th of ['light','dark']){jobs.push({plat:'ios',k:'medium-empty',sz:'m',th,w:338,h:158,r:22,empty:true});jobs.push({plat:'android',k:'2x2-empty',sz:'s',th,w:170,h:170,r:28,empty:true});}
  for(const j of jobs){const c=C[j.th];
   const bg=j.plat==='android'&&j.th==='dark'?{...c,bg:'#18181B',chip:'#232327',track:'#2E2E33'}:c;
   isIosSmall=j.plat==='ios';
   let inner=WID[slug](bg,j.sz,j.empty);
   const quickSmall=slug==='quickaccess'&&j.sz==='s'&&!j.empty;
   const html=`<!doctype html><meta charset=utf-8><style>${CSS(bg,j.w,j.h,j.r)}${quickSmall?'.w{padding:12px}':''}</style><body><div class="w">${inner}</div>`;
   const name=`${j.plat}-${j.k}-${j.th}`;const hf=path.join(st,name+'.html');fs.writeFileSync(hf,html);
   const p=await br.newPage({viewport:{width:j.w+20,height:j.h+20},deviceScaleFactor:3});
   await p.goto('file:///'+hf.replace(/\\/g,'/'));await p.evaluate(()=>document.fonts.ready);
   await p.locator('.w').screenshot({path:path.join(out,name+'.png'),omitBackground:true});await p.close();}
 }
 await br.close();
})();
