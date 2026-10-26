package edu.bingol.backend.crypto;

import edu.bingol.backend.crypto.CryptoException.Reason;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.stereotype.Component;

/**
 * `app.crypto.master-keys` (veya dosyasi) = "id1:base64,id2:base64". Her anahtar tam 32 bayttir.
 * Uretimde (prod profili ya da require-keys) anahtar yoksa uygulama ACILMAZ; gelistirmede
 * acikca uyarilan sabit bir gelistirme anahtari kullanilir (verileri korumaz!).
 */
@Component
public class ConfiguredKeyProvider implements KeyProvider {

    private static final Logger log = LoggerFactory.getLogger(ConfiguredKeyProvider.class);
    private static final Pattern ID = Pattern.compile("[A-Za-z0-9_.-]{1,32}");
    static final String DEV_ID = "dev";

    private final Map<String, SecretKey> keys = new LinkedHashMap<>();
    private final String activeId;
    private final boolean dev;

    public ConfiguredKeyProvider(CryptoProperties p, Environment env) {
        String raw = p.masterKeys();
        if ((raw == null || raw.isBlank()) && p.masterKeysFile() != null && !p.masterKeysFile().isBlank()) {
            try {
                raw = Files.readString(Path.of(p.masterKeysFile()), StandardCharsets.UTF_8);
            } catch (IOException e) {
                throw new IllegalStateException("app.crypto.master-keys-file okunamadi", e);
            }
        }
        boolean strict = p.requireKeys() || env.acceptsProfiles(Profiles.of("prod", "production"));
        if (raw == null || raw.isBlank()) {
            if (strict) {
                throw new IllegalStateException(
                        "Sifreleme ana anahtari yok: CRYPTO_MASTER_KEYS (id:base64) ayarlayin. Uretimde zorunludur.");
            }
            keys.put(DEV_ID, devKey());
            dev = true;
            log.warn("##### UYARI: app.crypto.master-keys ayarli degil; GELISTIRME ANAHTARI kullaniliyor. "
                    + "Bu anahtar herkese aciktir, verileri KORUMAZ. Uretimde asla kullanmayin. #####");
        } else {
            dev = false;
            for (String entry : raw.trim().split("[,;\\s]+")) {
                if (entry.isEmpty()) {
                    continue;
                }
                int i = entry.indexOf(':');
                if (i <= 0) {
                    throw new IllegalStateException("Gecersiz ana anahtar girdisi (id:base64 bekleniyor)");
                }
                String id = entry.substring(0, i);
                if (!ID.matcher(id).matches()) {
                    throw new IllegalStateException("Gecersiz ana anahtar kimligi: " + id);
                }
                byte[] k;
                try {
                    k = Base64.getDecoder().decode(entry.substring(i + 1));
                } catch (IllegalArgumentException e) {
                    throw new IllegalStateException("Ana anahtar base64 degil: " + id);
                }
                if (k.length != 32) {
                    throw new IllegalStateException("Ana anahtar tam 32 bayt olmali: " + id);
                }
                if (keys.put(id, new SecretKeySpec(k, "AES")) != null) {
                    throw new IllegalStateException("Yinelenen ana anahtar kimligi: " + id);
                }
            }
            if (keys.isEmpty()) {
                throw new IllegalStateException("app.crypto.master-keys bos");
            }
        }
        String a = p.activeKeyId();
        if (a == null || a.isBlank()) {
            // Yeni anahtar listenin sonuna eklenir; varsayilan aktif = sonuncu.
            a = keys.keySet().stream().reduce((x, y) -> y).orElseThrow();
        } else if (!keys.containsKey(a)) {
            throw new IllegalStateException("app.crypto.active-key-id listede yok: " + a);
        }
        this.activeId = a;
        log.info("Sifreleme: {} ana anahtar yuklu, aktif kimlik={}", keys.size(), activeId);
    }

    private static SecretKey devKey() {
        try {
            byte[] d = MessageDigest.getInstance("SHA-256")
                    .digest("bu-kampus-dev-only-insecure-master-key".getBytes(StandardCharsets.US_ASCII));
            return new SecretKeySpec(d, "AES");
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    @Override
    public String activeKeyId() {
        return activeId;
    }

    @Override
    public SecretKey key(String id) {
        SecretKey k = keys.get(id);
        if (k == null) {
            throw new CryptoException(Reason.KEY_UNAVAILABLE, "Ana anahtar bulunamadi: " + id);
        }
        return k;
    }

    @Override
    public Set<String> keyIds() {
        return Collections.unmodifiableSet(keys.keySet());
    }

    @Override
    public boolean isDevKey() {
        return dev;
    }
}
