package edu.bingol.backend.forum.topic;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.topic.dto.ForumPage;
import edu.bingol.backend.forum.topic.dto.TopicSummary;
import edu.bingol.backend.forum.topic.spi.ForumTopicSummaries;
import edu.bingol.backend.post.follow.UserFollowRepository;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Konu akisi. Siralamalar (hepsi KARARLI imlecli: ayni konu iki kez gelmez, atlanmaz; sayaclar sayfalar arasinda
 * degismedikce):
 * <ul>
 *   <li>NEWEST: kimlik azalan (kimlik olusturma sirasiyla artar); imlec = son kimlik.</li>
 *   <li>MOST_COMMENTED: (yorum sayisi, kimlik) azalan; imlec = ikisi.</li>
 *   <li>POPULAR: puan = begeni + 2*yorum (son {@value #POPULAR_DAYS} gunde acilanlar), (puan, kimlik) azalan.</li>
 *   <li>FOLLOWING: takip ettigim konular + takip ettigim kullanicilarin anonim OLMAYAN konulari; kimlik azalan.</li>
 *   <li>FOR_YOU: asagidaki ACIK formul; rastgelelik YOK.</li>
 * </ul>
 * Sabitlenmis konular yalniz NEWEST ve FOR_YOU'nun ILK sayfasinda basta gelir ve o akistan cikarilir (tekrar yok).
 *
 * <p><b>FOR_YOU formulu.</b> {@code base = 1 + ln(1+begeni) + 1.5*ln(1+yorum) + yazarBonusu + kategoriBonusu};
 * {@code skor = base * 0.5^(yasSaat / 36)} (yas = son etkinlikten bu yana). Yazar bonusu +1.0: takip ettigim, anonim
 * olmayan yazar (anonim konuda uygulanmaz: siralama kimlik sizdirmasin). Kategori bonusu +0.5: son 90 gunde konu
 * actigim/begendigim/takip ettigim kategori. Ustel sonum siralamayi degistirmeden {@code anahtar = ln(base) +
 * son_etkinlik_saat * ln2 / 36} ile karsilastirilir; anahtar "simdi"ye bagli olmadigindan imlec sayfalar arasinda
 * kararlidir. Aday penceresi: son {@value #FOR_YOU_WINDOW_DAYS} gunde etkinligi olan en cok {@value #CANDIDATES} konu.
 */
@Service
public class ForumFeedService implements ForumTopicSummaries {

    static final int DEFAULT_SIZE = 15;
    static final int MAX_SIZE = 30;
    static final int POPULAR_DAYS = 30;
    static final int FOR_YOU_WINDOW_DAYS = 60;
    static final int CANDIDATES = 600;
    static final int MAX_PINNED = 5;
    static final double HALF_LIFE_HOURS = 36.0;

    public enum Sort { FOR_YOU, NEWEST, POPULAR, MOST_COMMENTED, FOLLOWING }

    private final ForumTopicRepository topics;
    private final ForumViewerFilter filter;
    private final ForumTopicAssembler assembler;
    private final UserFollowRepository userFollows;

    public ForumFeedService(ForumTopicRepository topics, ForumViewerFilter filter, ForumTopicAssembler assembler,
                            UserFollowRepository userFollows) {
        this.topics = topics;
        this.filter = filter;
        this.assembler = assembler;
        this.userFollows = userFollows;
    }

    public static Sort parseSort(String s) {
        if (s == null || s.isBlank()) {
            return Sort.FOR_YOU;
        }
        try {
            return Sort.valueOf(s.trim().toUpperCase(java.util.Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_SORT_INVALID", "Geçersiz sıralama.");
        }
    }

    @Transactional(readOnly = true)
    public ForumPage<TopicSummary> feed(Long viewerId, Sort sort, Long categoryId, String cursor, Integer sizeParam) {
        int size = sizeParam == null ? DEFAULT_SIZE : Math.min(Math.max(sizeParam, 1), MAX_SIZE);
        long cat = categoryId == null ? 0L : categoryId;
        Set<Long> hidden = filter.hiddenFrom(viewerId);
        boolean first = cursor == null || cursor.isBlank();
        List<ForumTopic> rows = new ArrayList<>();
        String next;
        List<ForumTopic> pinned = List.of();
        int room = size;
        if (first && (sort == Sort.NEWEST || sort == Sort.FOR_YOU)) {
            int pinLimit = Math.min(MAX_PINNED, Math.max(0, size - 1));
            if (pinLimit > 0) {
                pinned = topics.pinned(cat, viewerId, hidden, PageRequest.of(0, pinLimit));
                room = size - pinned.size();
            }
        }
        switch (sort) {
            case NEWEST -> {
                long before = first ? Long.MAX_VALUE : Cursor.parseId(cursor, "N");
                List<ForumTopic> page = topics.newest(cat, before, viewerId, hidden, PageRequest.of(0, room + 1));
                next = take(page, room, rows, t -> Cursor.id("N", t.getId()));
            }
            case MOST_COMMENTED -> {
                long[] c = first ? new long[] {Integer.MAX_VALUE, Long.MAX_VALUE} : Cursor.parsePair(cursor, "C");
                List<ForumTopic> page = topics.mostCommented(cat, (int) c[0], c[1], viewerId, hidden,
                        PageRequest.of(0, room + 1));
                next = take(page, room, rows, t -> Cursor.pair("C", t.getCommentCount(), t.getId()));
            }
            case POPULAR -> {
                long[] c = first ? new long[] {Integer.MAX_VALUE, Long.MAX_VALUE} : Cursor.parsePair(cursor, "P");
                Instant since = Instant.now().minus(Duration.ofDays(POPULAR_DAYS));
                List<ForumTopic> page = topics.popular(cat, since, (int) c[0], c[1], viewerId, hidden,
                        PageRequest.of(0, room + 1));
                next = take(page, room, rows, t -> Cursor.pair("P", t.getLikeCount() + 2L * t.getCommentCount(), t.getId()));
            }
            case FOLLOWING -> {
                long before = first ? Long.MAX_VALUE : Cursor.parseId(cursor, "F");
                List<ForumTopic> page = topics.following(cat, before, viewerId, hidden, PageRequest.of(0, room + 1));
                next = take(page, room, rows, t -> Cursor.id("F", t.getId()));
            }
            default -> next = forYou(viewerId, cat, hidden, first ? null : cursor, room, rows);
        }
        List<ForumTopic> all = new ArrayList<>(pinned);
        all.addAll(rows);
        return new ForumPage<>(assembler.summaries(all, viewerId), next);
    }

    /** size+1 satir cekilmis sayfadan ilk {@code size}'i {@code out}a koyar; fazlasi varsa sonraki imleci doner. */
    private static String take(List<ForumTopic> page, int size, List<ForumTopic> out,
                               java.util.function.Function<ForumTopic, String> cursorOf) {
        boolean more = page.size() > size;
        List<ForumTopic> cut = more ? page.subList(0, size) : page;
        out.addAll(cut);
        return more && !cut.isEmpty() ? cursorOf.apply(cut.get(cut.size() - 1)) : null;
    }

    // ------------------------------------------------------------------ FOR_YOU

    private String forYou(Long viewerId, long cat, Set<Long> hidden, String cursor, int room, List<ForumTopic> out) {
        double[] after = cursor == null ? null : Cursor.parseKey(cursor);
        Instant windowStart = Instant.now().minus(Duration.ofDays(FOR_YOU_WINDOW_DAYS));
        List<ForumTopic> cands = topics.candidates(cat, windowStart, viewerId, hidden, PageRequest.of(0, CANDIDATES));
        if (cands.isEmpty()) {
            return null;
        }
        List<Long> openAuthors = cands.stream().filter(t -> !t.isAnonymous()).map(ForumTopic::getUserId).distinct()
                .toList();
        Set<Long> followedAuthors = openAuthors.isEmpty() ? Set.of()
                : new HashSet<>(userFollows.followedAmong(viewerId, openAuthors));
        Set<Long> affinity = new HashSet<>(topics.affinityCategories(viewerId, Instant.now().minus(Duration.ofDays(90))));
        Map<ForumTopic, Double> keys = new LinkedHashMap<>();
        for (ForumTopic t : cands) {
            keys.put(t, key(t, followedAuthors.contains(t.getUserId()), affinity.contains(t.getCategoryId())));
        }
        Comparator<ForumTopic> order = Comparator.<ForumTopic>comparingDouble(keys::get).reversed()
                .thenComparing(Comparator.comparing(ForumTopic::getId).reversed());
        List<ForumTopic> sorted = keys.keySet().stream().sorted(order).toList();
        List<ForumTopic> page = new ArrayList<>();
        for (ForumTopic t : sorted) {
            if (after != null) {
                double k = keys.get(t);
                // (anahtar, kimlik) cifti imlecten KESIN kucuk olmali
                if (!(k < after[0] || (k == after[0] && t.getId() < (long) after[1]))) {
                    continue;
                }
            }
            page.add(t);
            if (page.size() > room) {
                break;
            }
        }
        return take(page, room, out, t -> Cursor.key(keys.get(t), t.getId()));
    }

    /** Zamandan bagimsiz karsilastirma anahtari: ln(base) + son_etkinlik_saat * ln2 / yariOmur. */
    static double key(ForumTopic t, boolean followedAuthor, boolean affinityCategory) {
        double engagement = Math.log1p(t.getLikeCount()) + 1.5 * Math.log1p(t.getCommentCount());
        double bonus = (followedAuthor && !t.isAnonymous() ? 1.0 : 0.0) + (affinityCategory ? 0.5 : 0.0);
        double base = 1.0 + engagement + bonus;
        double hours = t.getLastActivityAt().getEpochSecond() / 3600.0;
        return Math.log(base) + hours * Math.log(2) / HALF_LIFE_HOURS;
    }

    // ------------------------------------------------------------------ ForumTopicSummaries

    @Override
    @Transactional(readOnly = true)
    public List<TopicSummary> summaries(Collection<Long> topicIds, Long viewerId) {
        if (topicIds == null || topicIds.isEmpty()) {
            return List.of();
        }
        List<Long> ids = topicIds.stream().distinct().limit(60).toList();
        Map<Long, ForumTopic> byId = new LinkedHashMap<>();
        for (ForumTopic t : topics.findVisibleByIds(ids, viewerId, filter.hiddenFrom(viewerId))) {
            byId.put(t.getId(), t);
        }
        List<ForumTopic> ordered = new ArrayList<>();
        for (Long id : ids) {
            ForumTopic t = byId.get(id);
            if (t != null) {
                ordered.add(t);
            }
        }
        return assembler.summaries(ordered, viewerId);
    }

    // ------------------------------------------------------------------ imlec

    /** Opak imlec: base64url(tur;deger...). Tur eslesmesi sirayi karistirmayi onler. */
    static final class Cursor {
        private Cursor() {}

        static String id(String kind, long id) {
            return enc(kind + ";" + id);
        }

        static String pair(String kind, long a, long b) {
            return enc(kind + ";" + a + ";" + b);
        }

        /** Anahtar kayan noktali: bit deseniyle tasinir (bicimlendirme kaybi olmaz). */
        static String key(double k, long id) {
            return enc("Y;" + Long.toHexString(Double.doubleToLongBits(k)) + ";" + id);
        }

        static long parseId(String cursor, String kind) {
            String[] p = dec(cursor, kind, 2);
            return num(p[1]);
        }

        static long[] parsePair(String cursor, String kind) {
            String[] p = dec(cursor, kind, 3);
            return new long[] {num(p[1]), num(p[2])};
        }

        static double[] parseKey(String cursor) {
            String[] p = dec(cursor, "Y", 3);
            try {
                return new double[] {Double.longBitsToDouble(Long.parseUnsignedLong(p[1], 16)), num(p[2])};
            } catch (NumberFormatException e) {
                throw invalid();
            }
        }

        private static String enc(String s) {
            return Base64.getUrlEncoder().withoutPadding().encodeToString(s.getBytes(StandardCharsets.UTF_8));
        }

        private static String[] dec(String cursor, String kind, int parts) {
            try {
                String s = new String(Base64.getUrlDecoder().decode(cursor.trim()), StandardCharsets.UTF_8);
                String[] p = s.split(";");
                if (p.length != parts || !p[0].equals(kind)) {
                    throw invalid();
                }
                return p;
            } catch (IllegalArgumentException e) {
                throw invalid();
            }
        }

        private static long num(String s) {
            try {
                return Long.parseLong(s);
            } catch (NumberFormatException e) {
                throw invalid();
            }
        }

        private static ApiException invalid() {
            return new ApiException(HttpStatus.BAD_REQUEST, "FORUM_CURSOR_INVALID", "Geçersiz sayfa imleci.");
        }
    }
}
