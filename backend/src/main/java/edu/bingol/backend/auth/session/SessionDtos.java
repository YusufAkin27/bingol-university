package edu.bingol.backend.auth.session;

import java.time.Instant;

/** "Cihazlarim" yanit sekilleri. Ham IP/cihaz kimligi YOK: ipMasked kismen maskelidir. */
public final class SessionDtos {

    private SessionDtos() {}

    /**
     * Bir acik oturum. `id` = sid (DELETE /api/auth/sessions/{id}); `current`: istegi yapan access token bu oturumun;
     * `client` mobile|web; `platform` ANDROID|IOS|WEB|UNKNOWN; `deviceName` istemcinin bildirdigi ad (yoksa
     * User-Agent'tan turetilmis ya da null); `lastUsedAt` son token yenilemesi/girisi (access token omru kadar kaba).
     */
    public record SessionView(String id, String client, String platform, String deviceName, String appVersion,
                              String ipMasked, Instant createdAt, Instant lastUsedAt, boolean current) {

        static SessionView of(UserSession s, boolean current) {
            return new SessionView(s.getSid(), s.getClient(), s.getPlatform(), s.getDeviceName(), s.getAppVersion(),
                    s.getIpMasked(), s.getCreatedAt(), s.getLastUsedAt(), current);
        }
    }
}
