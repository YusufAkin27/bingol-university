-- V1471: SSS "Kimler kayit olabilir?" cevabi (2026-11-06): e-posta alan adi kisiti kalkti, kayit herhangi bir gecerli e-posta adresi +
-- e-posta dogrulama koduyla yapilir. SSS yonetici panelinden duzenlenebilen veridir: YALNIZ V3 tohumundaki eski metinle BIREBIR
-- ayni olan satirlar guncellenir (answer = eski varsayilan); yonetici elle degistirdiyse (ya da silindiyse) satira dokunulmaz.
UPDATE faq_item
   SET answer = 'Bingöl Üniversitesi topluluğu için hazırlanan uygulamaya Gmail, Outlook, Hotmail, Yahoo gibi sağlayıcıların adresleri ile okul veya kurum e-postaları dahil, size ait geçerli herhangi bir e-posta adresiyle kayıt olabilirsiniz; bingol.edu.tr uzantılı adres zorunlu değildir. Hesap, e-posta adresinize gönderilen doğrulama kodunu girdiğinizde etkinleşir.',
       updated_at = now()
 WHERE lang = 'tr'
   AND question = 'Kimler kayıt olabilir?'
   AND answer = 'Yalnızca bingol.edu.tr (ve ogr.bingol.edu.tr gibi alt alan adları) uzantılı e-posta adresi olan öğrenci ve personel kayıt olabilir.';

UPDATE faq_item
   SET answer = 'You can register with any valid e-mail address that belongs to you, including Gmail, Outlook, Hotmail, Yahoo and school or organisation addresses; an address ending in bingol.edu.tr is not required. Your account is activated when you enter the verification code sent to your e-mail address.',
       updated_at = now()
 WHERE lang = 'en'
   AND question = 'Who can register?'
   AND answer = 'Only students and staff with an email address ending in bingol.edu.tr (including subdomains such as ogr.bingol.edu.tr) can register.';

UPDATE faq_item
   SET answer = 'يمكنك التسجيل بأي عنوان بريد إلكتروني صالح يخصّك، بما في ذلك Gmail وOutlook وHotmail وYahoo وعناوين البريد المدرسية أو المؤسسية؛ ولا يُشترط عنوان ينتهي بـ bingol.edu.tr. يُفعَّل حسابك عند إدخال رمز التحقق المرسل إلى بريدك الإلكتروني.',
       updated_at = now()
 WHERE lang = 'ar'
   AND question = 'من يمكنه التسجيل؟'
   AND answer = 'يمكن للطلاب والموظفين الذين لديهم بريد إلكتروني ينتهي بـ bingol.edu.tr (بما في ذلك النطاقات الفرعية مثل ogr.bingol.edu.tr) فقط التسجيل.';
