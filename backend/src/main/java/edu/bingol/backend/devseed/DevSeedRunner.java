package edu.bingol.backend.devseed;

import edu.bingol.backend.common.storage.LocalFileStorage;
import edu.bingol.backend.messaging.ConversationService;
import edu.bingol.backend.messaging.MessageService;
import edu.bingol.backend.post.media.PostMediaService;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.io.IOException;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

/**
 * Geliştirme tohum verisi. YALNIZ `seed` profili (ve `prod` kapalıyken) çalışır: SPRING_PROFILES_ACTIVE=seed (ya da
 * dev,seed). Idempotent: her kayıt önce var mı diye bakılır; tekrar çalıştırmak çoğaltmaz. Hikaye/yorum OLUŞTURULMAZ.
 * Ayrıntı: docs/DEV_SEED.md.
 */
@Component
@Profile("seed & !prod")
public class DevSeedRunner implements ApplicationRunner {

    /** Bilinen geliştirme şifresi (yalnız yerel; docs/DEV_SEED.md ve .env.example'da belgeli). */
    public static final String DEV_PASSWORD = "DevSeed-2026!";
    static final String ADMIN_EMAIL = "seed.admin@bingol.edu.tr";
    static final String PERF_EMAIL = "mobil.test@bingol.edu.tr";

    private static final Logger log = LoggerFactory.getLogger(DevSeedRunner.class);

    private final JdbcTemplate jdbc;
    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final LocalFileStorage storage;
    private final ConversationService conversations;
    private final MessageService messages;
    private final PostMediaService postMedia;

    public DevSeedRunner(JdbcTemplate jdbc, UserRepository users, PasswordEncoder encoder, LocalFileStorage storage,
                         ConversationService conversations, MessageService messages, PostMediaService postMedia) {
        this.jdbc = jdbc;
        this.users = users;
        this.encoder = encoder;
        this.storage = storage;
        this.conversations = conversations;
        this.messages = messages;
        this.postMedia = postMedia;
    }

    private record U(String email, String name, String faculty, String dept, int year, String lang, boolean admin) {
    }

    private static final List<U> USERS = List.of(
            new U(ADMIN_EMAIL, "Seed Yonetici", "Rektorluk", "Bilgi Islem", 0, "tr", true),
            new U(PERF_EMAIL, "Mobil Test", "Muhendislik-Mimarlik Fakultesi", "Bilgisayar Muhendisligi", 3, "tr", false),
            new U("seed.ayse@bingol.edu.tr", "Ayse Demir", "Fen-Edebiyat Fakultesi", "Matematik", 2, "tr", false),
            new U("seed.mehmet@bingol.edu.tr", "Mehmet Kaya", "Muhendislik-Mimarlik Fakultesi", "Elektrik-Elektronik Muhendisligi", 4, "tr", false),
            new U("seed.zeynep@bingol.edu.tr", "Zeynep Arslan", "Iktisadi ve Idari Bilimler Fakultesi", "Isletme", 1, "en", false),
            new U("seed.emre@bingol.edu.tr", "Emre Yildiz", "Egitim Fakultesi", "Sinif Ogretmenligi", 2, "tr", false),
            new U("seed.elif@bingol.edu.tr", "Elif Sahin", "Saglik Bilimleri Fakultesi", "Hemsirelik", 3, "tr", false),
            new U("seed.can@bingol.edu.tr", "Can Ozturk", "Ziraat Fakultesi", "Bitkisel Uretim", 1, "tr", false),
            new U("seed.selin@bingol.edu.tr", "Selin Aydin", "Fen-Edebiyat Fakultesi", "Fizik", 4, "ar", false),
            new U("seed.burak@bingol.edu.tr", "Burak Celik", "Iktisadi ve Idari Bilimler Fakultesi", "Iktisat", 2, "tr", false),
            new U("seed.derya@bingol.edu.tr", "Derya Koc", "Egitim Fakultesi", "Rehberlik ve Psikolojik Danismanlik", 3, "en", false),
            new U("seed.ozan@bingol.edu.tr", "Ozan Polat", "Muhendislik-Mimarlik Fakultesi", "Makine Muhendisligi", 1, "tr", false));

    @Override
    public void run(ApplicationArguments args) throws Exception {
        System.setProperty("java.awt.headless", "true");
        log.info("DEV TOHUM: basliyor (yalniz gelistirme profili)");
        List<Long> ids = seedUsers();
        Map<String, Long> clubs = seedClubs(ids);
        seedEvents(ids, clubs);
        seedPosts(ids);
        seedFollows(ids);
        seedChats(ids);
        seedPolls(ids, clubs);
        seedSupport(ids);
        seedNotifications(ids);
        log.info("DEV TOHUM: tamam. Giris: {} / {} (sifre docs/DEV_SEED.md)", PERF_EMAIL, "<DEV_PASSWORD>");
    }

    // ---------------------------------------------------------------- kullanicilar

    private List<Long> seedUsers() {
        String hash = encoder.encode(DEV_PASSWORD);
        List<Long> ids = new ArrayList<>();
        for (U s : USERS) {
            User u = users.findByEmail(s.email()).orElse(null);
            if (u == null) {
                u = new User();
                u.setEmail(s.email());
                u.setPasswordHash(hash);
                u.setDisplayName(s.name());
                u.setEmailVerified(true);
                u.setRole(s.admin() ? Role.ADMIN : Role.USER);
                u.setFaculty(s.faculty());
                u.setDepartment(s.dept());
                u.setClassYear(s.year() == 0 ? null : (short) s.year());
                u.setLanguage(s.lang());
                u.setBio(s.admin() ? "Gelistirme yonetici hesabi." : "Test kullanicisi (tohum verisi).");
                u.setLastSeenAt(Instant.now());
                u = users.save(u);
            }
            ids.add(u.getId());
        }
        return ids;
    }

    // ---------------------------------------------------------------- kulupler

    private record C(String slug, String name, String category, String policy, int owner, int[] admins, int[] members,
                     int[] pending) {
    }

    private Map<String, Long> seedClubs(List<Long> ids) throws IOException {
        List<C> cs = List.of(
                new C("seed-yazilim-toplulugu", "Yazilim Toplulugu", "Teknoloji", "OPEN", 1, new int[] {3}, new int[] {2, 4, 11}, new int[] {}),
                new C("seed-fotograf-kulubu", "Fotograf Kulubu", "Sanat", "OPEN", 2, new int[] {}, new int[] {1, 5, 6}, new int[] {}),
                new C("seed-genc-girisimciler", "Genc Girisimciler", "Kariyer", "APPROVAL", 4, new int[] {9}, new int[] {1, 7}, new int[] {10, 11}),
                new C("seed-doga-sporlari", "Doga ve Spor Kulubu", "Spor", "OPEN", 5, new int[] {}, new int[] {1, 6, 8, 11}, new int[] {}),
                new C("seed-tiyatro-toplulugu", "Tiyatro Toplulugu", "Sanat", "APPROVAL", 6, new int[] {8}, new int[] {2, 3}, new int[] {7}));
        Map<String, Long> out = new java.util.LinkedHashMap<>();
        int hue = 20;
        for (C c : cs) {
            Long id = firstLong("SELECT id FROM community WHERE slug = ?", c.slug());
            if (id == null) {
                String logo = PlaceholderImages.ensure(storage.root(), c.slug() + "-logo", c.name(), hue, 256, 256);
                String cover = PlaceholderImages.ensure(storage.root(), c.slug() + "-cover", c.name(), hue + 40, 960, 480);
                jdbc.update("INSERT INTO community (name, slug, description, category, cover_url, logo_url, join_policy, "
                        + "visibility, status, owner_id) VALUES (?,?,?,?,?,?,?,'PUBLIC','ACTIVE',?)",
                        c.name(), c.slug(), c.name() + " - tohum verisi (gelistirme).", c.category(), cover, logo,
                        c.policy(), ids.get(c.owner()));
                id = firstLong("SELECT id FROM community WHERE slug = ?", c.slug());
                member(id, ids.get(c.owner()), "OWNER", "ACTIVE");
                for (int a : c.admins()) {
                    member(id, ids.get(a), "ADMIN", "ACTIVE");
                }
                for (int m : c.members()) {
                    member(id, ids.get(m), "MEMBER", "ACTIVE");
                }
                for (int m : c.pending()) {
                    member(id, ids.get(m), "MEMBER", "PENDING");
                }
            }
            out.put(c.slug(), id);
            hue += 55;
        }
        return out;
    }

    private void member(Long communityId, Long userId, String role, String status) {
        jdbc.update("INSERT INTO community_member (community_id, user_id, role, status) SELECT ?,?,?,? WHERE NOT EXISTS "
                + "(SELECT 1 FROM community_member WHERE community_id = ? AND user_id = ?)",
                communityId, userId, role, status, communityId, userId);
    }

    // ---------------------------------------------------------------- etkinlikler

    private record E(String title, String place, int dayOffset, int hour, Integer capacity, String status,
                     String club, int creator, boolean approval, int[] going, int[] interested, int[] pending) {
    }

    private void seedEvents(List<Long> ids, Map<String, Long> clubs) throws IOException {
        String yz = "seed-yazilim-toplulugu";
        String fo = "seed-fotograf-kulubu";
        String gg = "seed-genc-girisimciler";
        String ds = "seed-doga-sporlari";
        String tt = "seed-tiyatro-toplulugu";
        List<E> es = List.of(
                new E("Yazilim Gunleri: Acilis Oturumu", "Konferans Salonu", 5, 14, 120, "ACTIVE", yz, 1, false, new int[] {2, 3, 4, 11}, new int[] {5}, new int[] {}),
                new E("Hackathon 24 Saat", "Muhendislik Fakultesi B Blok", 12, 9, 60, "ACTIVE", yz, 3, true, new int[] {2}, new int[] {}, new int[] {4, 11, 5}),
                new E("Fotograf Gezisi: Eski Carsi", "Kampus Girisi", 3, 10, null, "ACTIVE", fo, 2, false, new int[] {1, 5, 6}, new int[] {7}, new int[] {}),
                new E("Girisimcilik Paneli", "Kongre Merkezi", 20, 13, 200, "ACTIVE", gg, 4, false, new int[] {1, 7, 9}, new int[] {2}, new int[] {}),
                new E("Kariyer Soylesisi (Basvurulu)", "Ogrenci Merkezi", 8, 15, 30, "ACTIVE", gg, 9, true, new int[] {7}, new int[] {}, new int[] {1, 10}),
                new E("Doga Yuruyusu: Yedisu", "Kampus Otoparki", 2, 8, 40, "ACTIVE", ds, 5, false, new int[] {1, 6, 8}, new int[] {11}, new int[] {}),
                new E("Tiyatro Gosterimi: Bir Yaz Gecesi", "Kultur Merkezi", 15, 19, 150, "ACTIVE", tt, 6, false, new int[] {2, 3}, new int[] {1}, new int[] {}),
                new E("Gecen Ay Yazilim Atolyesi", "Bilgisayar Laboratuvari", -20, 10, 40, "ACTIVE", yz, 1, false, new int[] {2, 3, 4}, new int[] {}, new int[] {}),
                new E("Gecen Hafta Fotograf Sergisi", "Sanat Galerisi", -6, 11, null, "ACTIVE", fo, 2, false, new int[] {1, 5}, new int[] {6}, new int[] {}),
                new E("Onay Bekleyen Bahar Senligi", "Ana Kampus", 30, 12, 500, "PENDING_REVIEW", null, 10, false, new int[] {}, new int[] {}, new int[] {}),
                new E("Iptal Edilen Satranc Turnuvasi", "Ogrenci Merkezi", 9, 16, 32, "CANCELLED", null, 8, false, new int[] {}, new int[] {}, new int[] {}));
        int hue = 200;
        for (E e : es) {
            Long creator = ids.get(e.creator());
            Long id = firstLong("SELECT id FROM user_event WHERE title = ? AND created_by = ?", e.title(), creator);
            if (id != null) {
                continue;
            }
            Instant start = Instant.now().plus(Duration.ofDays(e.dayOffset())).truncatedTo(java.time.temporal.ChronoUnit.DAYS)
                    .plus(Duration.ofHours(e.hour() - 3)); // ~Europe/Istanbul (UTC+3)
            String cover = PlaceholderImages.ensure(storage.root(), "seed-event-" + Math.abs(e.title().hashCode()),
                    e.title().length() > 24 ? e.title().substring(0, 24) : e.title(), hue, 960, 540);
            hue += 37;
            Long community = e.club() == null ? null : clubs.get(e.club());
            int going = e.going().length;
            jdbc.update("INSERT INTO user_event (title, description, starts_at, ends_at, location, cover_url, capacity, "
                    + "going_count, community_id, created_by, status) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                    e.title(), e.title() + " - tohum verisi (gelistirme).", Timestamp.from(start),
                    Timestamp.from(start.plus(Duration.ofHours(2))), e.place(), cover, e.capacity(), going, community,
                    creator, e.status());
            id = firstLong("SELECT id FROM user_event WHERE title = ? AND created_by = ?", e.title(), creator);
            if (e.approval()) {
                jdbc.update("INSERT INTO event_admission (event_id, mode, question1) VALUES (?, 'APPROVAL', ?)",
                        id, "Bu etkinlige neden katilmak istiyorsunuz?");
            }
            for (int g : e.going()) {
                jdbc.update("INSERT INTO event_rsvp (event_id, user_id, status) VALUES (?,?, 'GOING')", id, ids.get(g));
                if (e.approval()) {
                    application(id, ids.get(g), "ACCEPTED");
                }
            }
            for (int g : e.interested()) {
                jdbc.update("INSERT INTO event_rsvp (event_id, user_id, status) VALUES (?,?, 'INTERESTED')", id, ids.get(g));
            }
            for (int g : e.pending()) {
                application(id, ids.get(g), "PENDING");
            }
        }
    }

    private void application(Long eventId, Long userId, String status) {
        jdbc.update("INSERT INTO event_application (event_id, user_id, status, answer1) SELECT ?,?,?,? WHERE NOT EXISTS "
                + "(SELECT 1 FROM event_application WHERE event_id = ? AND user_id = ?)",
                eventId, userId, status, "Konuya ilgim var (tohum).", eventId, userId);
    }

    // ---------------------------------------------------------------- gonderiler

    private static final String[] POSTS = {
            "Kampuste bahar geldi, herkese iyi dersler!", "Final haftasi icin calisma grubu kuruyoruz, katilmak isteyen?",
            "Kutuphanede yeni calisma alanlari acildi, cok rahat olmus.", "Bugunku yemek listesi gercekten iyiydi.",
            "Yazilim toplulugunun hackathon duyurusu yakinda geliyor.", "Fotograf kulubunun gezisinden kareler.",
            "Ders notlarini paylasmak isteyen var mi?", "Bu hafta sonu Yedisu'ya yuruyus yapiyoruz.",
            "Staj basvurulari icin CV hazirlama ipuclari.", "Yeni dönem ders programi acikladi mi?",
            "Kampus kedisi bugun de konferans salonundaydi.", "Girisimcilik panelinde gorusmek uzere!",
            "Kantinde yeni cay saati basladi.", "Tiyatro provalari tam gaz devam ediyor.",
            "Bolum tanitim gunu icin gonullu araniyor."};

    private void seedPosts(List<Long> ids) {
        for (int i = 0; i < POSTS.length; i++) {
            Long author = ids.get(i % ids.size());
            String body = POSTS[i] + " (#seed" + (i + 1) + ")";
            if (firstLong("SELECT id FROM post WHERE author_id = ? AND body = ?", author, body) != null) {
                continue;
            }
            Instant at = Instant.now().minus(Duration.ofHours(3L + i * 9L));
            jdbc.update("INSERT INTO post (author_id, body, created_at) VALUES (?,?,?)", author, body, Timestamp.from(at));
            Long pid = firstLong("SELECT id FROM post WHERE author_id = ? AND body = ?", author, body);
            if (i % 3 != 2) { // her uc gonderiden ikisi gorselli
                try {
                    byte[] png = PlaceholderImages.png("Gonderi " + (i + 1), 15 + i * 23, 800, 600);
                    PostMediaService.Uploaded up = postMedia.upload(author, new PngFile("post" + i + ".png", png), null);
                    postMedia.attach(pid, author, List.of(up.id()));
                    jdbc.update("UPDATE post SET media_count = 1 WHERE id = ?", pid);
                } catch (RuntimeException | IOException ex) {
                    log.warn("DEV TOHUM: gonderi gorseli atlandi (gonderi {}): {}", pid, ex.toString());
                }
            }
            int likes = 0;
            for (int u = 0; u < ids.size() && likes < (i % 5) + 1; u++) {
                if (!ids.get(u).equals(author)) {
                    jdbc.update("INSERT INTO post_like (post_id, user_id) SELECT ?,? WHERE NOT EXISTS "
                            + "(SELECT 1 FROM post_like WHERE post_id = ? AND user_id = ?)", pid, ids.get(u), pid, ids.get(u));
                    likes++;
                }
            }
            jdbc.update("UPDATE post SET like_count = (SELECT COUNT(*) FROM post_like WHERE post_id = ?) WHERE id = ?", pid, pid);
        }
    }

    // ---------------------------------------------------------------- takip

    private void seedFollows(List<Long> ids) {
        for (int a = 0; a < ids.size(); a++) {
            for (int step : new int[] {1, 2, 5}) {
                int b = (a + step) % ids.size();
                if (a != b) {
                    jdbc.update("INSERT INTO user_follow (follower_id, followee_id) SELECT ?,? WHERE NOT EXISTS "
                            + "(SELECT 1 FROM user_follow WHERE follower_id = ? AND followee_id = ?)",
                            ids.get(a), ids.get(b), ids.get(a), ids.get(b));
                }
            }
        }
        jdbc.update("INSERT INTO user_follow_stats (user_id) SELECT id FROM app_user WHERE id IN "
                + "(SELECT user_id FROM (SELECT follower_id AS user_id FROM user_follow UNION SELECT followee_id FROM user_follow) t) "
                + "AND id NOT IN (SELECT user_id FROM user_follow_stats)");
        jdbc.update("UPDATE user_follow_stats s SET "
                + "follower_count = (SELECT COUNT(*) FROM user_follow f WHERE f.followee_id = s.user_id), "
                + "following_count = (SELECT COUNT(*) FROM user_follow f WHERE f.follower_id = s.user_id)");
    }

    // ---------------------------------------------------------------- sohbet

    private void seedChats(List<Long> ids) {
        String[][] talks = {
                {"1", "2", "Merhaba, yarinki ders icin notlari paylasir misin?", "Tabii, aksam gonderirim."},
                {"1", "3", "Hackathon icin ekip kuruyoruz, katilir misin?", "Evet, ben varim!"},
                {"4", "5", "Kulup toplantisi saat kacta?", "15:00'te ogrenci merkezinde."}};
        for (String[] t : talks) {
            Long a = ids.get(Integer.parseInt(t[0]));
            Long b = ids.get(Integer.parseInt(t[1]));
            try {
                ConversationService.Opened o = conversations.openDirect(a, b);
                if (o.created()) {
                    messages.send(a, o.conversation().id(), t[2], "seed-" + a + "-" + b + "-1");
                    messages.send(b, o.conversation().id(), t[3], "seed-" + a + "-" + b + "-2");
                }
            } catch (RuntimeException ex) {
                log.warn("DEV TOHUM: sohbet atlandi: {}", ex.toString());
            }
        }
        try {
            if (firstLong("SELECT id FROM conversation WHERE title = ?", "Seed Calisma Grubu") == null) {
                var g = conversations.createGroup(ids.get(1), "Seed Calisma Grubu", List.of(ids.get(2), ids.get(3), ids.get(4)));
                messages.send(ids.get(1), g.id(), "Grup acildi, hos geldiniz.", "seed-grp-1");
                messages.send(ids.get(2), g.id(), "Merhaba herkese!", "seed-grp-2");
            }
        } catch (RuntimeException ex) {
            log.warn("DEV TOHUM: grup sohbeti atlandi: {}", ex.toString());
        }
    }

    // ---------------------------------------------------------------- anketler

    private void seedPolls(List<Long> ids, Map<String, Long> clubs) {
        poll("Kampus kafeteryasi icin en cok hangisini istersiniz?", "SINGLE", "GLOBAL", null, ids.get(0), "OPEN",
                new String[] {"Daha genis menu", "Daha uzun calisma saati", "Vegan secenekler"}, ids, new int[][] {{1, 0}, {2, 0}, {3, 1}, {4, 2}});
        poll("Hangi etkinlik turlerine katilirsiniz? (coklu)", "MULTI", "GLOBAL", null, ids.get(0), "OPEN",
                new String[] {"Konferans", "Atolye", "Gezi", "Konser"}, ids, new int[][] {{1, 0}, {1, 1}, {2, 2}, {5, 3}});
        poll("Yazilim toplulugu bulusma gunu", "SINGLE", "COMMUNITY", clubs.get("seed-yazilim-toplulugu"), ids.get(1), "OPEN",
                new String[] {"Pazartesi", "Carsamba", "Cuma"}, ids, new int[][] {{2, 1}, {3, 1}, {4, 2}});
        poll("Gecen donem ders programi memnuniyeti", "SINGLE", "GLOBAL", null, ids.get(0), "CLOSED",
                new String[] {"Memnunum", "Kararsizim", "Memnun degilim"}, ids, new int[][] {{1, 0}, {2, 0}, {3, 2}});
    }

    private void poll(String title, String type, String scope, Long community, Long creator, String status,
                      String[] options, List<Long> ids, int[][] votes) {
        if (firstLong("SELECT id FROM poll WHERE title = ?", title) != null) {
            return;
        }
        boolean closed = "CLOSED".equals(status);
        Instant opens = Instant.now().minus(Duration.ofDays(closed ? 30 : 2));
        Instant closes = closed ? Instant.now().minus(Duration.ofDays(5)) : Instant.now().plus(Duration.ofDays(10));
        jdbc.update("INSERT INTO poll (title, type, scope, community_id, created_by, anonymous, max_choices, opens_at, "
                + "closes_at, status, closed_at) VALUES (?,?,?,?,?,TRUE,?,?,?,?,?)",
                title, type, scope, community, creator, "MULTI".equals(type) ? options.length : 1,
                Timestamp.from(opens), Timestamp.from(closes), status, closed ? Timestamp.from(closes) : null);
        Long pid = firstLong("SELECT id FROM poll WHERE title = ?", title);
        List<Long> optIds = new ArrayList<>();
        for (int i = 0; i < options.length; i++) {
            jdbc.update("INSERT INTO poll_option (poll_id, position, text) VALUES (?,?,?)", pid, i, options[i]);
            optIds.add(firstLong("SELECT id FROM poll_option WHERE poll_id = ? AND position = ?", pid, i));
        }
        for (int[] v : votes) {
            Long uid = ids.get(v[0]);
            Long oid = optIds.get(v[1]);
            jdbc.update("INSERT INTO poll_ballot (poll_id, user_id) SELECT ?,? WHERE NOT EXISTS "
                    + "(SELECT 1 FROM poll_ballot WHERE poll_id = ? AND user_id = ?)", pid, uid, pid, uid);
            jdbc.update("INSERT INTO poll_vote (poll_id, option_id, user_id) VALUES (?,?,?)", pid, oid, uid);
            jdbc.update("UPDATE poll_option SET vote_count = vote_count + 1 WHERE id = ?", oid);
        }
        jdbc.update("UPDATE poll SET voter_count = (SELECT COUNT(*) FROM poll_ballot WHERE poll_id = ?) WHERE id = ?", pid, pid);
    }

    // ---------------------------------------------------------------- destek

    private void seedSupport(List<Long> ids) {
        ticket(ids.get(2), "TECHNICAL", "Uygulama acilista donuyor", "OPEN",
                "Giris yaptiktan sonra ana sayfa yuklenmiyor.", null);
        ticket(ids.get(3), "ACCOUNT", "Sifre degistirme sorusu", "ANSWERED",
                "Sifremi nereden degistirebilirim?", "Profil > Ayarlar > Sifre bolumunden degistirebilirsiniz.");
    }

    private void ticket(Long userId, String category, String subject, String status, String text, String reply) {
        if (firstLong("SELECT id FROM support_ticket WHERE user_id = ? AND subject = ?", userId, subject) != null) {
            return;
        }
        jdbc.update("INSERT INTO support_ticket (user_id, category, subject, status) VALUES (?,?,?,?)",
                userId, category, subject, status);
        Long tid = firstLong("SELECT id FROM support_ticket WHERE user_id = ? AND subject = ?", userId, subject);
        jdbc.update("INSERT INTO support_message (ticket_id, author_id, from_staff, text) VALUES (?,?,FALSE,?)",
                tid, userId, text);
        if (reply != null) {
            Long admin = firstLong("SELECT id FROM app_user WHERE email = ?", ADMIN_EMAIL);
            jdbc.update("INSERT INTO support_message (ticket_id, author_id, from_staff, text) VALUES (?,?,TRUE,?)",
                    tid, admin, reply);
        }
    }

    // ---------------------------------------------------------------- bildirimler

    private void seedNotifications(List<Long> ids) {
        Long perf = ids.get(1);
        String[][] ns = {
                {"EVENT", "Etkinlik hatirlatmasi", "Yazilim Gunleri 5 gun sonra basliyor."},
                {"COMMUNITY", "Kulup duyurusu", "Yazilim Toplulugu yeni bir duyuru paylasti."},
                {"NEWS", "Yeni haber", "Kampus haberleri guncellendi."},
                {"SYSTEM", "Hos geldiniz", "BU Kampus gelistirme ortamina hos geldiniz."},
                {"MESSAGE", "Yeni mesaj", "Ayse Demir size mesaj gonderdi."}};
        for (Long uid : new Long[] {perf, ids.get(2), ids.get(3)}) {
            for (int i = 0; i < ns.length; i++) {
                if (firstLong("SELECT id FROM notification WHERE user_id = ? AND title = ? AND body = ?", uid, ns[i][1], ns[i][2]) != null) {
                    continue;
                }
                jdbc.update("INSERT INTO notification (user_id, type, title, body, read_at, created_at) VALUES (?,?,?,?,?,?)",
                        uid, ns[i][0], ns[i][1], ns[i][2], i >= 3 ? Timestamp.from(Instant.now()) : null,
                        Timestamp.from(Instant.now().minus(Duration.ofHours(1L + i * 7L))));
            }
        }
    }

    // ---------------------------------------------------------------- yardimcilar

    private Long firstLong(String sql, Object... args) {
        List<Long> r = jdbc.queryForList(sql, Long.class, args);
        return r.isEmpty() ? null : r.get(0);
    }

    /** Servis katmanına verilen bellek içi PNG yüklemesi (spring-test bağımlılığı olmadan). */
    private record PngFile(String name, byte[] bytes) implements MultipartFile {
        @Override public String getName() { return "file"; }
        @Override public String getOriginalFilename() { return name; }
        @Override public String getContentType() { return "image/png"; }
        @Override public boolean isEmpty() { return bytes.length == 0; }
        @Override public long getSize() { return bytes.length; }
        @Override public byte[] getBytes() { return bytes; }
        @Override public java.io.InputStream getInputStream() { return new java.io.ByteArrayInputStream(bytes); }
        @Override public void transferTo(java.io.File dest) throws IOException {
            java.nio.file.Files.write(dest.toPath(), bytes);
        }
    }
}
