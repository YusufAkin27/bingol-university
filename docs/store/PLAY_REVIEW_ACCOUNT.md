# Google Play inceleme hesabı (REV1)

Play inceleme ekibi uygulamaya kayıt olamaz (kayıt yalnız `bingol.edu.tr` + e-posta doğrulama kodu ile olur ve kod okul posta kutusuna gider). Bu yüzden canlı sunucuda **hazır, doğrulanmış, normal kullanıcı** (rol USER, `ADMIN_EMAILS`'te değil) bir test hesabı tutulur. **E-posta ve parola bu belgede YOKTUR**; yalnız yerelde `C:\Users\<kullanıcı>\bu-secrets\play-review-account.txt` dosyasındadır (`EMAIL=`, `PASSWORD=`). Dosya commit'lenmez.

## Hesap neyle oluşur
Gerçek kayıt sonucuyla aynı kayıtlar (kod: `AccountCreator`, `LegalService.recordSignupConsent`):

| Tablo | Kayıt |
|---|---|
| `app_user` | 1 satır: görünen ad "Play İnceleme", `email_verified=true`, rol `USER`, durum `ACTIVE`, dil `tr`, `email_sha256`, BCrypt (`$2a$10$`, Spring `BCryptPasswordEncoder` ile uyumlu) |
| `legal_acceptance` | 4 satır: TERMS, PRIVACY, KVKK, COMMUNITY_RULES için o an AKTİF tr sürümü (yeniden onay beklemez) |

Bildirim/gizlilik tercih satırları gerçek kayıtta da tembel oluşur, bu yüzden eklenmez. Kulüp üyeliği: üretimde kulüp yoksa atlanır (betik üyelik eklemez). Sahte gönderi/mesaj eklenmez.

## Komutlar (repo kökünden, Git Bash)
```bash
bash scripts/ops/create-review-account.sh                   # yoksa oluşturur; varsa DOKUNMAZ (parola sıfırlanmaz)
bash scripts/ops/create-review-account.sh --status          # yalnız durum
bash scripts/ops/create-review-account.sh --reset-password  # parolayı dosyadaki değere sıfırlar
bash scripts/ops/create-review-account.sh --delete          # uygulamanın hesap silme mantığıyla siler (anonimleştirir)
```
- E-posta/parola yerel dosyadan okunur ve ssh **stdin** ile gönderilir; komut satırında görünmez, çıktıya yazılmaz. Ortam: `SECRETS_FILE`, `SSH_KEY`, `SSH_HOST`, `API_BASE`, `PG_CONTAINER`.
- `--delete`: hesapla giriş yapıp `DELETE /api/users/me` çağırır (KVKK anonimleştirme: e-posta `deleted-<id>@deleted.invalid`, ad "Silinmiş kullanıcı", durum `DELETED`; `legal_acceptance` hukuki kanıt olarak kalır). Parola değişmişse giriş başarısız olur; o durumda yönetici panelinden kullanıcıyı silin.
- Aynı oturum açma kuralı geçerlidir: mobil istemciyle giriş, o kullanıcının önceki **mobil** oturumunu kapatır (aynı hesabı iki inceleyici aynı anda kullanırsa biri atılır).

## Risk notu
Adres `bingol.edu.tr` alan adındadır ve o posta kutusuna erişimimiz yoktur. Gerçek biri aynı adresi kullanırsa "şifremi unuttum" kodu ona gider ve hesabı ele geçirebilir. Bu yüzden: hesabı yalnız inceleme süresince tutun, **inceleme/yayın onayı bittiğinde `--delete` ile silin**, parolayı başka yerde kullanmayın, sızıntı şüphesinde `--delete` sonra yeniden oluşturun.

## Play Console "Uygulama erişimi" (App access) formu metni (İngilizce)
Seçenek: "All or some functionality is restricted" -> kimlik bilgisi ekleyin.

```
The app requires an account. Registration is limited to university e-mail
addresses (bingol.edu.tr) and needs an e-mail verification code, so we provide a
ready, verified test account.

Username (e-mail): <EMAIL from the private credentials file>
Password:          <PASSWORD from the private credentials file>

Steps: open the app -> "Log in" -> enter the e-mail and password above ->
you land on the Home screen. No 2-step verification and no e-mail code are
needed to log in. Please do not use "Sign up".

Notes: the app is an independent, unofficial campus companion (news, announcements,
events, cafeteria menu, clubs, chat). Public news/menu content is fetched from the
university's public pages. Logging in on a second device signs out the first one.
Clubs, posts and chats may look empty because this is a fresh test account.
```
