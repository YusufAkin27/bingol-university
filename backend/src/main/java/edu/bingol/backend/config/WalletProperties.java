package edu.bingol.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.wallet.*`: etkinlik biletini Apple Wallet / Google Cuzdan'a ekleme (T1). Yalniz BAYRAKLAR: sertifika ve servis
 * hesabi anahtari bu surumde okunmaz/kullanilmaz (imzalama kodu yok). Varsayilan hepsi kapali; bkz. docs/WALLET_SETUP.md.
 */
@ConfigurationProperties("app.wallet")
public record WalletProperties(@DefaultValue("false") boolean enabled,
                               @DefaultValue("false") boolean appleEnabled,
                               @DefaultValue("false") boolean googleEnabled) {

    /** Istemciye bildirilen: ana bayrak kapaliyken saglayici bayraklari da kapali sayilir. */
    public boolean apple() {
        return enabled && appleEnabled;
    }

    public boolean google() {
        return enabled && googleEnabled;
    }
}
