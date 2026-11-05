package edu.bingol.backend.auth.oauth;

import java.security.PublicKey;

/**
 * Saglayici imza anahtarlari (JWKS). Gercek uygulama {@link RemoteJwksKeyProvider}; testlerde yerel anahtarla
 * degistirilir (ag yok).
 */
public interface OAuthKeyProvider {

    /**
     * {@code kid} icin acik anahtar; bulunamazsa (anahtar donusumu olabilir) uygulama BIR KEZ yeniler. Hala yoksa ya da
     * saglayiciya ulasilamazsa null (cagiran token'i gecersiz sayar: fail-closed).
     */
    PublicKey key(OAuthProvider provider, String kid);
}
