package edu.bingol.backend.mail;

import edu.bingol.backend.i18n.Lang;
import java.util.Map;

/**
 * Yonetici tarafindan tanimlanan (veritabani) sablonlarin gonderim aninda HTML + duz metne cevrilmesi.
 * {@link MailRenderer}, {@link MailTemplate#CUSTOM} icin buna devreder; uygulayici mail/campaign paketindedir.
 */
public interface CustomMailContent {

    MailRenderer.Rendered render(Lang lang, Map<String, String> vars);
}
