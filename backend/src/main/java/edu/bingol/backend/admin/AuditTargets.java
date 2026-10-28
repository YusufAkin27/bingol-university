package edu.bingol.backend.admin;

import java.util.Locale;
import java.util.Set;

/**
 * Istek yolundan denetim hedefi (tur + kimlik) cikarir; servis/controller {@link AuditContext#target} ile acikca
 * bildirmediyse kullanilir. Ornek: /api/admin/users/3/role -> (USER, 3); /api/admin/settings/maintenance_mode ->
 * (SETTING, maintenance_mode); /api/admin/support/tickets/5/reply -> (TICKET, 5).
 */
final class AuditTargets {

    record Target(String type, String id) {}

    /** Ilk parcasi "ad alani" olan kaynaklar: tur ikinci parcadan alinir. */
    private static final Set<String> NAMESPACES = Set.of("moderation", "mail", "push", "crypto", "ops", "system",
            "analytics", "support", "media");
    /** Kimligi sayi olmayan kaynaklar (ikinci parca kimliktir). */
    private static final Set<String> STRING_ID = Set.of("settings", "pending-registrations", "legal", "blocklist");

    private AuditTargets() {}

    static Target infer(String path) {
        if (path == null || !path.startsWith("/api/admin/")) {
            return new Target(null, null);
        }
        String[] seg = path.substring("/api/admin/".length()).split("/");
        if (seg.length == 0 || seg[0].isEmpty()) {
            return new Target(null, null);
        }
        int typeIdx = 0;
        if (NAMESPACES.contains(seg[0]) && seg.length > 1 && !isNumeric(seg[1])) {
            typeIdx = 1;
        }
        String type = singular(seg[typeIdx]);
        String id = null;
        for (int i = typeIdx + 1; i < seg.length && i <= typeIdx + 2; i++) {
            if (isNumeric(seg[i])) {
                id = seg[i];
                break;
            }
        }
        if (id == null && STRING_ID.contains(seg[typeIdx]) && seg.length > typeIdx + 1) {
            String cand = seg[typeIdx + 1];
            if (!cand.contains(".csv") && !cand.equals("versions") && !cand.equals("acceptance-stats")) {
                id = cand;
            }
        }
        return new Target(type, id);
    }

    private static boolean isNumeric(String s) {
        if (s.isEmpty() || s.length() > 19) {
            return false;
        }
        for (int i = 0; i < s.length(); i++) {
            if (!Character.isDigit(s.charAt(i))) {
                return false;
            }
        }
        return true;
    }

    static String singular(String resource) {
        String r = resource.toLowerCase(Locale.ROOT).replace('-', '_');
        int dot = r.indexOf('.');
        if (dot > 0) {
            r = r.substring(0, dot); // export.csv gibi
        }
        if (r.endsWith("ies")) {
            r = r.substring(0, r.length() - 3) + "y";
        } else if (r.endsWith("ws") || r.endsWith("ss") || r.endsWith("us") || r.endsWith("is")) {
            // news, access gibi: oldugu gibi
        } else if (r.endsWith("s") && r.length() > 3) {
            r = r.substring(0, r.length() - 1);
        }
        return r.toUpperCase(Locale.ROOT);
    }
}
