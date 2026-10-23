// Tema/dil titremesini önlemek için ilk boyamadan önce çalışır (hata toleranslı).
// Harici dosya: CSP `script-src 'self'` satır içi betiğe izin vermez.
try {
  var t = localStorage.getItem('bu.theme');
  if (t === 'light' || t === 'dark') document.documentElement.setAttribute('data-theme', t);
  var l = localStorage.getItem('bu.lang');
  if (l === 'en' || l === 'ar' || l === 'tr') {
    document.documentElement.lang = l;
    document.documentElement.dir = l === 'ar' ? 'rtl' : 'ltr';
  }
} catch (e) {
  /* depolama kullanılamıyor: varsayılanlar */
}
