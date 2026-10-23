package edu.bingol.backend.i18n;

import edu.bingol.backend.user.UserRepository;
import java.util.Locale;
import org.springframework.context.MessageSource;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.stereotype.Component;

/**
 * Ceviri yardimcisi. Anahtarlar `src/main/resources/i18n/messages*.properties` icindedir
 * (messages.properties = Turkce, varsayilan). Anahtar yoksa verilen varsayilan metin (yoksa anahtar) doner.
 * <p>Sayi argumanlari MessageFormat'in yerel rakam bicimlendirmesine (ornek: Arapca-Hint rakamlari) girmesin diye
 * metin olarak gecirilmelidir.
 */
@Component
public class I18n {

    private final MessageSource messages;
    private final UserRepository users;

    public I18n(MessageSource messages, UserRepository users) {
        this.messages = messages;
        this.users = users;
    }

    public String msg(String key, Locale locale, Object... args) {
        return messages.getMessage(key, args, key, locale);
    }

    public String msg(String key, Lang lang, Object... args) {
        return msg(key, lang.locale(), args);
    }

    /** Gecerli istegin dilinde (Accept-Language). */
    public String current(String key, Object... args) {
        return msg(key, LocaleContextHolder.getLocale(), args);
    }

    /** Hata kodu icin ceviri: `error.<KOD>`; yoksa kodda yazili varsayilan mesaj. */
    public String error(String code, String defaultMessage, Locale locale, Object[] args) {
        return messages.getMessage("error." + code, args, defaultMessage, locale);
    }

    /** Kullanicinin kayitli dili (bildirim/e-posta gibi istek disi iletisim icin). Bulunamazsa varsayilan. */
    public Lang langOf(Long userId) {
        return users.findLanguage(userId).map(Lang::of).orElse(Lang.DEFAULT);
    }
}
