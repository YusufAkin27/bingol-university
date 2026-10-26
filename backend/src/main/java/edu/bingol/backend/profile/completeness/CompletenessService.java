package edu.bingol.backend.profile.completeness;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.user.User;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;

/** Profil tamamlama yuzdesi ve eksik alan onerileri. Agirliklar toplami 100'dur. */
@Service
public class CompletenessService {

    public record Missing(String field, int weight, String suggestion) {}

    public record Completeness(int percent, List<String> filled, List<Missing> missing) {}

    /** Alan -> agirlik (sira, onerilerin onem sirasidir). */
    static final Map<String, Integer> WEIGHTS = new LinkedHashMap<>();

    static {
        WEIGHTS.put("avatar", 20);
        WEIGHTS.put("bio", 20);
        WEIGHTS.put("faculty", 15);
        WEIGHTS.put("department", 15);
        WEIGHTS.put("classYear", 15);
        WEIGHTS.put("displayName", 15);
    }

    private final I18n i18n;

    public CompletenessService(I18n i18n) {
        this.i18n = i18n;
    }

    public Completeness of(User u) {
        List<String> filled = new ArrayList<>();
        List<Missing> missing = new ArrayList<>();
        int sum = 0;
        for (Map.Entry<String, Integer> e : WEIGHTS.entrySet()) {
            if (isFilled(u, e.getKey())) {
                filled.add(e.getKey());
                sum += e.getValue();
            } else {
                missing.add(new Missing(e.getKey(), e.getValue(), i18n.current("profile.complete." + e.getKey())));
            }
        }
        return new Completeness(sum, filled, missing);
    }

    static boolean isFilled(User u, String field) {
        return switch (field) {
            case "avatar" -> notBlank(u.getAvatarUrl());
            case "bio" -> notBlank(u.getBio());
            case "faculty" -> notBlank(u.getFaculty());
            case "department" -> notBlank(u.getDepartment());
            case "classYear" -> u.getClassYear() != null;
            // E-posta oneki yerine gercek bir ad girilmis sayilir: en az 2 harf
            case "displayName" -> u.getDisplayName() != null
                    && u.getDisplayName().codePoints().filter(Character::isLetter).count() >= 2;
            default -> false;
        };
    }

    private static boolean notBlank(String s) {
        return s != null && !s.isBlank();
    }
}
