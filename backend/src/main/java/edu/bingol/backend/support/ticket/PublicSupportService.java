package edu.bingol.backend.support.ticket;

import edu.bingol.backend.auth.token.CodeResendCooldown;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.SupportProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.support.ticket.PublicSupportDtos.CodeSent;
import edu.bingol.backend.support.ticket.PublicSupportDtos.SubmitRequest;
import edu.bingol.backend.support.ticket.PublicSupportDtos.Verified;
import edu.bingol.backend.support.ticket.TicketDtos.TicketDetail;
import edu.bingol.backend.support.ticket.TicketDtos.TicketMessageView;
import edu.bingol.backend.support.ticket.TicketDtos.TicketSummary;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Locale;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionOperations;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Herkese acik (hesapsiz) destek talebi: e-posta dogrulamasi, durum sorgu anahtari, kullanici ek mesaji, temizlik.
 * Dogrulanmamis talepler yonetim listesinde gorunmez ve 24 saatte silinir.
 */
@Service
public class PublicSupportService {

    private static final Logger log = LoggerFactory.getLogger(PublicSupportService.class);

    static final Duration CODE_TTL = Duration.ofMinutes(10);
    static final Duration UNVERIFIED_TTL = Duration.ofHours(24);
    static final int MAX_ATTEMPTS = 5;

    private final TicketRepository tickets;
    private final SupportMessageRepository messages;
    private final SupportTrackTokenRepository tokens;
    private final PublicSupportMailer mailer;
    private final RateLimiter limiter;
    private final SupportProperties props;
    private final SecureRandom random = new SecureRandom();

    /** Kod yeniden isteme bekleme suresi (180 sn, tek kaynak); yoksa (elle kurulan birim testleri) bekleme uygulanmaz. */
    private CodeResendCooldown cooldown;

    @Autowired(required = false)
    void setCooldown(CodeResendCooldown cooldown) {
        this.cooldown = cooldown;
    }

    private long cooldownSeconds() {
        return cooldown == null ? CodeResendCooldown.DEFAULT_SECONDS : cooldown.seconds();
    }

    /** Sunucu imzali form jetonu (T-062); yoksa (elle kurulan birim testleri) eski elapsedMs denetimi. */
    private SupportFormToken formTokens;

    /** Durum baglantisi en cok bu kadar gun gecerli (olusturmadan itibaren). */
    @Value("${app.support.track-token-days:90}")
    private int trackTokenDays = 90;

    /** Talep kapandiktan sonra durum baglantisi bu kadar gun daha calisir (yeniden acma/yanit penceresi). */
    @Value("${app.support.track-closed-grace-days:14}")
    private int trackClosedGraceDays = 14;

    public PublicSupportService(TicketRepository tickets, SupportMessageRepository messages,
                                SupportTrackTokenRepository tokens, PublicSupportMailer mailer, RateLimiter limiter,
                                SupportProperties props) {
        this.tickets = tickets;
        this.messages = messages;
        this.tokens = tokens;
        this.mailer = mailer;
        this.limiter = limiter;
        this.props = props;
    }

    /**
     * submit/verify metotlari SMTP gonderir; DB baglantisi (havuz 30) SMTP suresince (10-20 sn zaman asimi) tutulmasin
     * diye veritabani adimlari bu sablonla ayri kisa islemlere bolunur (P07-B4). Spring disinda kurulan birim
     * testlerinde islemsiz calisir.
     */
    private TransactionOperations tx = TransactionOperations.withoutTransaction();

    @Autowired(required = false)
    void setTransactionManager(PlatformTransactionManager tm) {
        this.tx = new TransactionTemplate(tm);
    }

    /** Test kancasi: islem sinirlarini gozlemlemek icin. */
    void setTransactionOperations(TransactionOperations ops) {
        this.tx = ops;
    }

    @Autowired(required = false)
    void setFormTokens(SupportFormToken formTokens) {
        this.formTokens = formTokens;
    }

    /** Formu acarken verilen jeton (T-062). Hiz siniri: IP basina saatte 60. */
    public PublicSupportDtos.FormToken issueFormToken(String ip) {
        limiter.check("pubsup:ftip:" + ip, 60, Duration.ofHours(1));
        if (formTokens == null) {
            return new PublicSupportDtos.FormToken(null, props.minFillSeconds());
        }
        return new PublicSupportDtos.FormToken(formTokens.issue(), props.minFillSeconds());
    }

    /**
     * Talebi "dogrulanmamis" kaydeder ve e-postaya kod yollar. Bal kabagi doluysa veya form cok hizli
     * gonderildiyse hicbir sey kaydetmeden ayni genel cevabi doner. SMTP gonderimi islem DISINDADIR:
     * kayit kendi kisa isleminde yazilir, kod postalanir, gonderilemezse kayit baska bir islemle silinir.
     */
    public CodeSent submit(SubmitRequest r, String ip, Lang lang) {
        String email = normalizeEmail(r.email());
        limiter.check("pubsup:ip:" + ip, 5, Duration.ofHours(1));
        CodeSent generic = new CodeSent("CODE_SENT", (int) CODE_TTL.toMinutes(), cooldownSeconds());
        boolean tooFast;
        if (formTokens != null && formTokens.required()) {
            // T-062: istemcinin bildirdigi sure guvenilmez; yalniz sunucu imzali, zaman damgali jeton gecerlidir
            SupportFormToken.Result res = formTokens.verify(r.formToken());
            tooFast = res != SupportFormToken.Result.OK;
            if (!tooFast) {
                limiter.check("pubsup:ft:" + SupportFormToken.nonceOf(r.formToken()), 3, Duration.ofHours(2));
            }
        } else {
            tooFast = r.elapsedMs() == null || r.elapsedMs() < props.minFillSeconds() * 1000L;
        }
        if ((r.website() != null && !r.website().isBlank()) || tooFast) {
            log.info("Herkese acik destek talebi elendi (honeypot/hiz)");
            return generic;
        }
        // Kod yeniden isteme beklemesi (180 sn, e-posta basina): diger sinirlardan ONCE alinir ki erken istekler gunluk
        // hakki tuketmesin; kod gonderilemezse geri verilir. Honeypot/hiz elemesi bekleme baslatmaz.
        if (cooldown != null) {
            cooldown.acquire(CodeResendCooldown.SUPPORT, email);
        }
        try {
            return sendCode(r, email, ip, lang, generic);
        } catch (RuntimeException e) {
            if (cooldown != null) {
                cooldown.release(CodeResendCooldown.SUPPORT, email);
            }
            throw e;
        }
    }

    private CodeSent sendCode(SubmitRequest r, String email, String ip, Lang lang, CodeSent generic) {
        // E-posta basina gunluk sayac YALNIZ gecerli jeton/bal kabagi elemesinden sonra harcanir (P07-B16): aksi halde
        // saldirgan hedef adres icin gunluk 5 hakki bos isteklerle tuketip gercek kullaniciyi engelleyebilirdi.
        limiter.check("pubsup:em:" + Hashing.sha256(email), 5, Duration.ofDays(1));
        // Kota harcayan kimliksiz istek: once IP gunluk + kimliksiz kod butcesi (requireCodeQuota). Ortak saatlik
        // "global" tavan KALDIRILDI (T-062): tek saldirgan formu herkese kilitleyebiliyordu; koruma kod butcesinde.
        limiter.check("pubsup:ipd:" + ip, 15, Duration.ofDays(1));
        mailer.requireQuota();
        SupportTicket draft = new SupportTicket();
        draft.setPublicTicket(true);
        draft.setEmailVerified(false);
        draft.setContactEmail(email);
        draft.setContactName(cleanName(r.name()));
        draft.setLang(lang.code());
        draft.setCategory(r.category());
        draft.setSubject(subjectOf(r.message()));
        String code = String.format("%06d", random.nextInt(1_000_000));
        draft.setCodeHash(codeHash(email, code));
        draft.setCodeExpiresAt(Instant.now().plus(CODE_TTL));
        SupportTicket t = tx.execute(st -> {
            SupportTicket saved = tickets.save(draft);
            addMessage(saved, false, r.message());
            return saved;
        });
        boolean sent;
        try {
            sent = mailer.sendCode(t, code, (int) CODE_TTL.toMinutes()); // SMTP: islem disinda
        } catch (RuntimeException e) {
            log.warn("Herkese acik destek kodu gonderilemedi: {}", e.toString());
            sent = false;
        }
        if (!sent) {
            // Kod gidemediyse kayit birakma; kullanici tekrar denesin.
            tx.executeWithoutResult(st -> tickets.delete(t));
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MAIL_UNAVAILABLE",
                    "Doğrulama e-postası şu anda gönderilemiyor. Lütfen daha sonra tekrar deneyin.");
        }
        return generic;
    }

    /** verify'in islem ici sonucu: ya hata (deneme sayaci yine de yazilir) ya da dogrulanmis talep. */
    private record VerifyOutcome(ApiException error, SupportTicket ticket, String token, String first) {}

    /**
     * Kod dogruysa e-postayi dogrular, talebi yonetime dusurur. Yanlis/suresi gecmis/yok: hep ayni INVALID_CODE.
     * Hatali denemede deneme sayaci kalici yazilir (islem hata olmadan biter), hata islemden sonra firlatilir;
     * "aldik" e-postasi islem disinda gonderilir.
     */
    public Verified verify(String rawEmail, String code, String ip) {
        limiter.check("pubsup:vip:" + ip, 30, Duration.ofHours(1));
        String email = normalizeEmail(rawEmail);
        VerifyOutcome o = tx.execute(st -> verifyInTx(email, code));
        if (o.error() != null) {
            throw o.error();
        }
        try {
            mailer.sendReceived(o.ticket(), o.first(), o.token()); // basarisizligi akisi bozmaz; kullanici zaten token'i cevapta alir
        } catch (RuntimeException e) {
            log.warn("Alindi e-postasi gonderilemedi: {}", e.toString());
        }
        if (cooldown != null) {
            cooldown.release(CodeResendCooldown.SUPPORT, email); // akis tamamlandi: yeni talep icin beklemeye gerek yok
        }
        return new Verified(o.ticket().getId(), o.token());
    }

    private VerifyOutcome verifyInTx(String email, String code) {
        List<SupportTicket> pending = tickets.pendingByEmail(email, PageRequest.of(0, 1));
        if (pending.isEmpty()) {
            return failed(invalidCode());
        }
        SupportTicket t = pending.get(0);
        if (t.getCodeHash() == null || t.getCodeExpiresAt() == null || t.getCodeExpiresAt().isBefore(Instant.now())) {
            return failed(invalidCode());
        }
        t.setCodeAttempts(t.getCodeAttempts() + 1);
        if (t.getCodeAttempts() > MAX_ATTEMPTS) {
            t.setCodeHash(null);
            tickets.save(t);
            return failed(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "TOO_MANY_ATTEMPTS",
                    "Çok fazla hatalı deneme. Yeni kod isteyin."));
        }
        boolean ok = MessageDigest.isEqual(t.getCodeHash().getBytes(StandardCharsets.UTF_8),
                codeHash(email, code).getBytes(StandardCharsets.UTF_8));
        if (!ok) {
            tickets.save(t);
            return failed(invalidCode());
        }
        t.setEmailVerified(true);
        t.setCodeHash(null);
        t.setCodeExpiresAt(null);
        t.setUpdatedAt(Instant.now());
        tickets.save(t);
        String token = mintToken(t.getId());
        String first = messages.findByTicketIdOrderByIdAsc(t.getId()).stream().findFirst()
                .map(SupportMessage::getText).orElse("");
        return new VerifyOutcome(null, t, token, first);
    }

    private static VerifyOutcome failed(ApiException e) {
        return new VerifyOutcome(e, null, null, null);
    }

    /** Durum sorgusu: yalnizca gecerli anahtarla; dogrulanmamis/yok/silinmis hepsi 404. */
    @Transactional(readOnly = true)
    public TicketDetail track(String token, String ip) {
        limiter.check("pubsup:tip:" + ip, 60, Duration.ofHours(1));
        return toDetail(ticketByToken(token, ip));
    }

    @Transactional
    public TicketDetail userReply(String token, String text, String ip) {
        limiter.check("pubsup:rip:" + ip, 20, Duration.ofHours(1));
        SupportTicket t = ticketByToken(token, ip);
        limiter.check("pubsup:rt:" + t.getId(), 30, Duration.ofDays(1));
        addMessage(t, false, text);
        if (t.getStatus() == SupportTicket.Status.CLOSED) {
            t.setClosedAt(null); // kapali talep yeniden acilir
        }
        t.setStatus(SupportTicket.Status.OPEN);
        t.setUpdatedAt(Instant.now());
        tickets.save(t);
        return toDetail(t);
    }

    /** Yonetici yanitini e-postayla yollar; sonuc true/false (istisna sizdirmaz). */
    public boolean sendStaffReplyMail(Long ticketId, String reply) {
        try {
            SupportTicket t = tickets.findById(ticketId).orElse(null);
            if (t == null || !t.isPublicTicket() || t.getContactEmail() == null) {
                return false;
            }
            String first = messages.findByTicketIdOrderByIdAsc(ticketId).stream().findFirst()
                    .map(SupportMessage::getText).orElse("");
            return mailer.sendReply(t, reply, first, mintToken(ticketId));
        } catch (RuntimeException e) {
            log.error("Yanit e-postasi hazirlanamadi: {}", e.toString());
            return false;
        }
    }

    /** Gecelik temizlik: 24 saati gecen dogrulanmamislar + saklama suresi dolan herkese acik talepler. */
    @Scheduled(cron = "${app.support.cleanup-cron:0 30 3 * * *}", zone = "Europe/Istanbul")
    public void scheduledCleanup() {
        try {
            int n = cleanup(Instant.now());
            if (n > 0) {
                log.info("Herkese acik destek temizligi: {} talep silindi", n);
            }
        } catch (RuntimeException e) {
            // T-020: hata yutulmaz; zamanlayici gozlemi (JobMonitor, bu.scheduler.errors) ve sistem durumu gorsun
            log.error("Herkese acik talep temizligi basarisiz: {}", e.toString());
            throw e;
        }
    }

    @Transactional
    public int cleanup(Instant now) {
        int a = tickets.deleteUnverifiedBefore(now.minus(UNVERIFIED_TTL));
        int b = tickets.deletePublicUpdatedBefore(now.minus(Duration.ofDays(props.publicTicketRetentionDays())));
        int c = tokens.deleteCreatedBefore(now.minus(Duration.ofDays(Math.max(1, trackTokenDays))));
        int d = tokens.deleteForTicketsClosedBefore(now.minus(Duration.ofDays(Math.max(0, trackClosedGraceDays))));
        return a + b + c + d;
    }

    // --- yardimcilar ---

    String mintToken(Long ticketId) {
        byte[] raw = new byte[32];
        random.nextBytes(raw);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        SupportTrackToken row = new SupportTrackToken();
        row.setTicketId(ticketId);
        row.setTokenHash(Hashing.sha256(token));
        tokens.save(row);
        return token;
    }

    private SupportTicket ticketByToken(String token, String ip) {
        SupportTrackToken row = token == null ? null : tokens.findByTokenHash(Hashing.sha256(token.trim())).orElse(null);
        SupportTicket t = row == null ? null : tickets.findById(row.getTicketId()).orElse(null);
        if (t != null && trackLinkExpired(row, t)) {
            t = null; // T-062: suresi dolan ya da uzun suredir kapali talebin baglantisi gecersiz (404)
        }
        if (t == null || !t.isPublicTicket() || !t.isEmailVerified()) {
            limiter.check("pubsup:bad:" + ip, 20, Duration.ofHours(1)); // anahtar tahmini denemelerini sinirla
            throw new ApiException(HttpStatus.NOT_FOUND, "TICKET_NOT_FOUND", "Talep bulunamadı.");
        }
        return t;
    }

    /** Baglanti olusturmadan `trackTokenDays`, kapanistan `trackClosedGraceDays` sonra gecersizdir. */
    private boolean trackLinkExpired(SupportTrackToken row, SupportTicket t) {
        Instant now = Instant.now();
        if (row.getCreatedAt() != null && row.getCreatedAt().isBefore(now.minus(Duration.ofDays(Math.max(1, trackTokenDays))))) {
            return true;
        }
        return t.getStatus() == SupportTicket.Status.CLOSED && t.getClosedAt() != null
                && t.getClosedAt().isBefore(now.minus(Duration.ofDays(Math.max(0, trackClosedGraceDays))));
    }

    private void addMessage(SupportTicket t, boolean fromStaff, String text) {
        SupportMessage m = new SupportMessage();
        m.setTicketId(t.getId());
        m.setFromStaff(fromStaff);
        m.setText(text.trim());
        messages.save(m);
    }

    private TicketDetail toDetail(SupportTicket t) {
        return new TicketDetail(TicketSummary.of(t),
                messages.findByTicketIdOrderByIdAsc(t.getId()).stream().map(TicketMessageView::of).toList());
    }

    static String normalizeEmail(String email) {
        String e = email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
        if (e.length() > 254 || e.chars().anyMatch(c -> c <= 32 || c == 127 || c == ',' || c == ';' || c == '<' || c == '>')) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek.");
        }
        return e;
    }

    static String cleanName(String name) {
        return name.replaceAll("[\\p{Cntrl}]", " ").trim();
    }

    static String subjectOf(String message) {
        String s = message.replaceAll("\\s+", " ").trim();
        return s.length() <= 100 ? s : s.substring(0, 100) + "...";
    }

    static String codeHash(String email, String code) {
        return Hashing.sha256("pubsup:" + email + ":" + code);
    }

    private static ApiException invalidCode() {
        return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Kod geçersiz veya süresi dolmuş.");
    }
}
