const fs=require('fs'),path=require('path');
const ROOT=path.resolve(__dirname,'..');
const {chromium}=require(process.env.PW);
const C={dark:{bg:'#111113',chip:'#1F1F23',t1:'#FAFAFA',t2:'#A1A1AA',t3:'#71717A',bd:'#27272A',invbg:'#FAFAFA',invfg:'#09090B',logo:'logo_dark.png'},
light:{bg:'#FFFFFF',chip:'#F4F4F5',t1:'#09090B',t2:'#52525B',t3:'#71717A',bd:'#E4E4E7',invbg:'#09090B',invfg:'#FFFFFF',logo:'logo_light.png'}};
const SZ={ios:{small:[158,158],medium:[338,158],large:[338,354],r:22},android:{'2x2':[170,170],'4x2':[350,170],'4x4':[350,350],r:28}};
const ico=(n,s=14)=>{const p={
sun:'<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
moon:'<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>',
flame:'<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.4-.5-2-1-3-1.1-2.1-.2-4 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.2.4-2.4 1-3 0 1.4 1 2.5 2.5 2.5Z"/>',
utensils:'<path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2M7 2v20M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7"/>',
pin:'<path d="M20 10c0 6-8 12-8 12S4 16 4 10a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>',
clock:'<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
cal:'<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>'}[n];
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
.bd{font-size:13px;line-height:18px}.bs{font-size:12px;line-height:16px}
.ell{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;min-width:0}
.ell2{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.row{display:flex;align-items:center;gap:8px}.sp{flex:1;min-width:0}
.grow{flex:1}.col{display:flex;flex-direction:column}
.kc{display:flex;align-items:center;gap:4px;font-size:12px;line-height:16px;color:${c.t2};white-space:nowrap}
.div{height:1px;background:${c.bd}}
.inv{background:${c.invbg};color:${c.invfg};border-radius:8px;padding:2px 8px;font-size:13px;line-height:18px;white-space:nowrap}
.chip{background:${c.chip}}
.dim{opacity:.5}
.tt{flex:none;font-size:13px;line-height:18px;letter-spacing:-.01em}
`;
const date='Cuma, 6 Kasım';
function head(c,label,icon,mb){return `<div class="hd"${mb?` style="margin-bottom:${mb}px"`:''}><div class="cap">${ico(icon,12)}${label}</div><img src="assets/${c.logo}"></div>`}
const L=[['Ezogelin çorbası',140],['Orman kebabı',320],['Bulgur pilavı',210],['Cacık',70]];
const D=[['Mercimek çorbası',130],['Tavuk sote',290],['Fırın makarna',260],['Ayran',60]];
const sum=a=>a.reduce((s,x)=>s+x[1],0), TOT='1.570';
function menu(c,sz,empty){
 if(empty){ if(sz==='s')return `${head(c,'Yemek','utensils')}<div class="grow col" style="justify-content:center"><div class="disp ell2">Bugün menü yok</div><div class="bs t3" style="margin-top:4px">Yemekhane tatilde olabilir</div></div>`;
  return `${head(c,'Yemek menüsü','utensils')}<div class="grow col" style="justify-content:center"><div class="disp">Bugün menü yok</div><div class="bd t2" style="margin-top:4px">Menü yayımlanınca burada görünür</div></div>`;}
 if(sz==='s') return `${head(c,'Öğle','sun')}<div class="disp ell2">Orman kebabı</div><div class="bs t2 ell" style="margin-top:4px">Ezogelin · Pilav · Cacık</div><div class="grow"></div><div class="kc">${ico('flame',12)}${TOT} kcal bugün</div>`;
 const list=(a,ic,lab,n)=>`<div class="sp col"><div class="cap" style="margin-bottom:6px">${ico(ic,12)}${lab}</div>${a.slice(0,n).map(x=>`<div class="bd ell" style="margin-bottom:2px">${x[0]}</div>`).join('')}</div>`;
 if(sz==='m') return `${head(c,date,'utensils',8)}<div class="row grow" style="align-items:flex-start;gap:16px">${list(L,'sun','Öğle',3)}<div style="width:1px;align-self:stretch;background:${c.bd}"></div>${list(D,'moon','Akşam',3)}</div><div class="kc" style="margin-top:4px">${ico('flame',12)}Toplam ${TOT} kcal</div>`;
 const sec=(a,ic,lab)=>`<div class="row" style="margin-bottom:6px"><div class="cap sp">${ico(ic,12)}${lab}</div><div class="kc">${sum(a)} kcal</div></div>${a.map(x=>`<div class="row" style="margin-bottom:2px"><div class="bd ell sp">${x[0]}</div><div class="bs t3">${x[1]}</div></div>`).join('')}`;
 return `${head(c,date,'utensils')}${sec(L,'sun','Öğle')}<div class="div" style="margin:10px 0"></div>${sec(D,'moon','Akşam')}<div class="grow"></div><div class="chip row" style="padding:8px 12px;height:36px;border-radius:12px;flex:none">${ico('flame',14)}<div class="bd sp">Günlük toplam</div><div class="bd">${TOT} kcal</div></div>`;
}
const T=[['08:30','Matematik II','A-101'],['10:30','Veri Yapıları','B-204'],['13:30','Veritabanı Sistemleri','Lab-3'],['15:30','İşletim Sistemleri','C-12']];
function tt(c,sz,empty){
 if(empty){ if(sz==='s')return `${head(c,'Ders','cal')}<div class="grow col" style="justify-content:center"><div class="disp ell2">Bugün ders yok</div><div class="bs t3" style="margin-top:4px">Sıradaki: Pzt 08:30</div></div>`;
  return `${head(c,'Ders programı','cal')}<div class="grow col" style="justify-content:center"><div class="disp">Bugün ders yok</div><div class="bd t2" style="margin-top:4px">Sıradaki ders: Pazartesi 08:30</div></div>`;}
 if(sz==='s') return `${head(c,'Sıradaki','clock')}<div class="row"><div class="inv">10:30</div><div class="bs t3">18 dk sonra</div></div><div class="ttl ell2" style="margin-top:8px">Veri Yapıları</div><div class="grow"></div><div class="kc">${ico('pin',12)}B-204</div>`;
 const row=(x,i,next,big)=>{const past=i===0;return `<div class="row ${next?'chip':''} ${past?'dim':''}" style="padding:0 8px;height:${big?40:36}px;border-radius:12px;flex:none">${next?`<div class="inv" style="width:52px;text-align:center;padding:2px 0">${x[0]}</div>`:`<div class="tt ${past?'t2':'t1'}" style="width:52px">${x[0]}</div>`}<div class="bd ell sp t1">${x[1]}</div><div class="kc">${ico('pin',12)}${x[2]}</div></div>`};
 if(sz==='m') return `${head(c,date+' · Sıradaki','clock')}<div class="col" style="gap:4px">${[1,2].map(i=>row(T[i],i,i===1,false)).join('')}</div>`;
 return `${head(c,date,'cal')}<div class="row" style="margin-bottom:12px"><div class="ttl sp">Bugün 4 ders</div><div class="kc">18 dk sonra</div></div><div class="col" style="gap:6px">${T.map((x,i)=>row(x,i,i===1,true)).join('')}</div><div class="grow"></div><div class="bs t3">Son ders 17:20 de biter</div>`;
}
const WID={menu,timetable:tt};
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
   const bg=j.plat==='android'&&j.th==='dark'?{...c,bg:'#18181B',chip:'#232327'}:c;
   const html=`<!doctype html><meta charset=utf-8><style>${CSS(bg,j.w,j.h,j.r)}</style><body><div class="w">${WID[slug](bg,j.sz,j.empty)}</div>`;
   const name=`${j.plat}-${j.k}-${j.th}`;const hf=path.join(st,name+'.html');fs.writeFileSync(hf,html);
   const p=await br.newPage({viewport:{width:j.w+20,height:j.h+20},deviceScaleFactor:3});
   await p.goto('file:///'+hf.replace(/\\/g,'/'));await p.evaluate(()=>document.fonts.ready);
   await p.locator('.w').screenshot({path:path.join(out,name+'.png'),omitBackground:true});await p.close();}
 }
 await br.close();
})();
