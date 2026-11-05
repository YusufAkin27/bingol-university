package edu.bingol.backend.notification;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;

/** Shared display hints for inbox and push. These never authorize an action. */
public final class NotificationPresentation {
    private static final ObjectMapper JSON = new ObjectMapper();
    private NotificationPresentation() {}

    public static Map<String, String> data(String json) {
        if (json == null || json.isBlank()) return Map.of();
        try {
            Map<String, String> result = JSON.readValue(json, new TypeReference<Map<String, String>>() {});
            return result == null ? Map.of() : result;
        } catch (Exception ignored) {
            return Map.of();
        }
    }

    public static String category(NotificationType type, String subtype, Map<String, String> data) {
        if (data == null) data = Map.of();
        String target = data.getOrDefault("targetType", data.getOrDefault("target", ""));
        if (target == null) target = "";
        if (data.containsKey("pollId") || "POLL".equals(subtype) || target.startsWith("POLL")) return "POLL";
        if ("EXAM_REMINDER".equals(subtype) || "ACADEMIC_ANNOUNCEMENT".equals(subtype)
                || data.containsKey("examId") || target.startsWith("ACADEMIC") || "EXAM".equals(target)
                || "TIMETABLE".equals(target) || "ANNOUNCEMENT_DEPT".equals(target)) return "ACADEMIC";
        if (type == null) return "SYSTEM";
        return switch (type) {
            case MESSAGE -> "MESSAGE";
            case EVENT -> "EVENT";
            case POST_LIKE, POST_COMMENT, COMMENT_REPLY, POST_MENTION, USER_FOLLOW, FOLLOW_REQUEST, FOLLOW_ACCEPTED, FORUM -> "SOCIAL";
            case SYSTEM -> "SYSTEM";
            case NEWS, ANNOUNCEMENT, COMMUNITY -> "ANNOUNCEMENT";
        };
    }
}
