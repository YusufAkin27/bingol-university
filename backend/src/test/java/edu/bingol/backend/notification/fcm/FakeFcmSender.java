package edu.bingol.backend.notification.fcm;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CopyOnWriteArrayList;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * Test icin sahte FCM gondericisi: gonderimleri kaydeder, sorgulanabilir yapar. Yalnizca test profilinde bean olur
 * (LoggingFcmSender test profilinde kapalidir); birim testlerde dogrudan `new FakeFcmSender()` de kullanilir.
 */
@Component
@Profile("test")
public class FakeFcmSender implements FcmSender {

    public record Sent(List<String> tokens, String title, String body, Map<String, String> data, String collapseKey) {}

    private final List<Sent> sent = new CopyOnWriteArrayList<>();
    private final Set<String> invalidTokens = new HashSet<>();

    @Override
    public List<String> send(Collection<String> tokens, String title, String body, Map<String, String> data) {
        return send(tokens, title, body, data, null);
    }

    @Override
    public List<String> send(Collection<String> tokens, String title, String body, Map<String, String> data,
                             String collapseKey) {
        sent.add(new Sent(List.copyOf(tokens), title, body, Map.copyOf(data), collapseKey));
        return tokens.stream().filter(invalidTokens::contains).toList();
    }

    /** Bu token'lar icin "artik gecersiz" doner (UNREGISTERED benzetimi). */
    public void markInvalid(String... tokens) {
        invalidTokens.addAll(List.of(tokens));
    }

    public List<Sent> sent() {
        return new ArrayList<>(sent);
    }

    public Sent last() {
        return sent.isEmpty() ? null : sent.get(sent.size() - 1);
    }

    /** Verilen token'a giden gonderimler. */
    public List<Sent> sentTo(String token) {
        return sent.stream().filter(s -> s.tokens().contains(token)).toList();
    }

    public void reset() {
        sent.clear();
        invalidTokens.clear();
    }
}
