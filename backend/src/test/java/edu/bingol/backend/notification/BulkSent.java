package edu.bingol.backend.notification;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import org.mockito.Mockito;
import org.mockito.invocation.Invocation;

/**
 * Test yardimcisi: sahte {@link NotificationService}'e {@code sendTemplatedBulk} ile giden alicilari ve cagri
 * sayisini sablon anahtarina gore okur (FINAL-ALL: uye/katilimci bildirimleri artik alici basina degil toplu gider).
 */
public final class BulkSent {

    private BulkSent() {
    }

    /** Verilen sablon anahtari icin tum {@code sendTemplatedBulk} cagrilarinin aliciları (sirayla, tekrarlar dahil). */
    @SuppressWarnings("unchecked")
    public static List<Long> to(NotificationService notifications, String key) {
        List<Long> out = new ArrayList<>();
        for (Invocation i : Mockito.mockingDetails(notifications).getInvocations()) {
            if (i.getMethod().getName().equals("sendTemplatedBulk")
                    && ((NotificationTemplates.Template) i.getArgument(1)).key().equals(key)) {
                out.addAll((Collection<Long>) i.getArgument(0));
            }
        }
        return out;
    }

    /** Verilen sablon anahtari icin {@code sendTemplatedBulk} cagri sayisi (parca sayisi). */
    public static int calls(NotificationService notifications, String key) {
        int n = 0;
        for (Invocation i : Mockito.mockingDetails(notifications).getInvocations()) {
            if (i.getMethod().getName().equals("sendTemplatedBulk")
                    && ((NotificationTemplates.Template) i.getArgument(1)).key().equals(key)) {
                n++;
            }
        }
        return n;
    }

    /** Sablon argumanlari (varargs) son cagriya gore: {@code args(n, key)[0]} ... */
    public static List<String> lastArgs(NotificationService notifications, String key) {
        List<String> out = new ArrayList<>();
        for (Invocation i : Mockito.mockingDetails(notifications).getInvocations()) {
            if (i.getMethod().getName().equals("sendTemplatedBulk")
                    && ((NotificationTemplates.Template) i.getArgument(1)).key().equals(key)) {
                out.clear();
                Object[] expanded = i.getArguments(); // varargs acilmis: (alicilar, sablon, veri, anahtar, arg...)
                for (int k = 4; k < expanded.length; k++) {
                    out.add(String.valueOf(expanded[k]));
                }
            }
        }
        return out;
    }
}
