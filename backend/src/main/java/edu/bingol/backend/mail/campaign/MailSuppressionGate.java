package edu.bingol.backend.mail.campaign;

import java.util.Collection;
import java.util.Map;

/**
 * Duyuru e-postasi alamayacak kullanicilar (abonelikten cikmis, bounce/sikayet nedeniyle bastirilmis, duyuru
 * tercihi kapali). Bastirma listesinin sahibi mail modulunun spam-onleme katmanidir; bu arayuz kampanya
 * sayaclarinin ("atlanan") dogru olmasi icin onu soyutlar. Uygulayici bean yoksa kimse engellenmez
 * ({@code MailService.enqueue} kendi kontrolunu yine yapar).
 */
public interface MailSuppressionGate {

    /** Engelli kullanicilar: kullanici kimligi -> neden kodu (ornek SUPPRESSED, OPTED_OUT). */
    Map<Long, String> blocked(Collection<Long> userIds);
}
