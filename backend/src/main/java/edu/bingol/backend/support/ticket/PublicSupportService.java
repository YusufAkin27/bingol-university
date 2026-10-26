package edu.bingol.backend.support.ticket;

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
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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
     * Talebi "dogrulanmamis" kaydeder ve e-postaya kod yollar. Bal kabagi doluysa veya form cok hizli
     * gonderildiyse hicbir sey kaydetmeden ayni genel cevabi doner.
     */
    @Transactional
    public CodeSent submit(SubmitRequest r, String ip, Lang lang) {
        String email = normalizeEmail(r.email());
        limiter.check("pubsup:ip:" + ip, 5, Duration.ofHours(1));
        limiter.check("pubsup:em:" + Hashing.sha256(email), 5, Duration.ofDays(1));
        CodeSent generic = new CodeSent("CODE_SENT", (int) CODE_TTL.toMinutes());
        boolean tooFast = r.elapsedMs() == null || r.elapsedMs() < props.minFillSeconds() * 1000L;
        if ((r.website() != null && !r.website().isBlank()) || tooFast) {
            log.info("Herkese acik destek talebi elendi (honeypot/hiz)");
            return generic;
        }
        SupportTicket t = new SupportTicket();
        t.setPublicTicket(true);
        t.setEmailVerified(false);
        t.setContactEmail(email);
        t.setContactName(cleanName(r.name()));
        t.setLang(lang.code());
        t.setCategory(r.category());
        t.setSubject(subjectOf(r.message()));
        String code = String.format("%06d", random.nextInt(1_000_000));
        t.setCodeHash(codeHash(email, code));
        t.setCodeExpiresAt(Instant.now().plus(CODE_TTL));
        t = tickets.save(t);
        addMessage(t, false, r.message());
        if (!mailer.sendCode(t, code, (int) CODE_TTL.toMinutes())) {
            // Kod gidemediyse kayit birakma; kullanici tekrar denesin.
            tickets.delete(t);
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MAIL_UNAVAILABLE",
                    "Doğrulama e-postası şu anda gönderilemiyor. Lütfen daha sonra tekrar deneyin.");
        }
        return generic;
    }

    /** Kod dogruysa e-postayi dogrular, talebi yonetime dusurur. Yanlis/suresi gecmis/yok: hep ayni INVALID_CODE. */
    @Transactional(noRollbackFor = ApiException.class)
    public Verified verify(String rawEmail, String code, String ip) {
        limiter.check("pubsup:vip:" + ip, 30, Duration.ofHours(1));
        String email = normalizeEmail(rawEmail);
        List<SupportTicket> pending = tickets.pendingByEmail(email, PageRequest.of(0, 1));
        if (pending.isEmpty()) {
            throw invalidCode();
        }
        SupportTicket t = pending.get(0);
        if (t.getCodeHash() == null || t.getCodeExpiresAt() == null || t.getCodeExpiresAt().isBefore(Instant.now())) {
            throw invalidCode();
        }
        t.setCodeAttempts(t.getCodeAttempts() + 1);
        if (t.getCodeAttempts() > MAX_ATTEMPTS) {
            t.setCodeHash(null);
            tickets.save(t);
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "TOO_MANY_ATTEMPTS",
                    "Çok fazla hatalı deneme. Yeni kod isteyin.");
        }
        boolean ok = MessageDigest.isEqual(t.getCodeHash().getBytes(StandardCharsets.UTF_8),
                codeHash(email, code).getBytes(StandardCharsets.UTF_8));
        if (!ok) {
            tickets.save(t);
            throw invalidCode();
        }
        t.setEmailVerified(true);
        t.setCodeHash(null);
        t.setCodeExpiresAt(null);
        t.setUpdatedAt(Instant.now());
        tickets.save(t);
        String token = mintToken(t.getId());
        String first = messages.findByTicketIdOrderByIdAsc(t.getId()).stream().findFirst()
                .map(SupportMessage::getText).orElse("");
        mailer.sendReceived(t, first, token); // basarisizligi akisi bozmaz; kullanici zaten token'i cevapta alir
        return new Verified(t.getId(), token);
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
            cleanup(Instant.now());
        } catch (RuntimeException e) {
            log.error("Herkese acik talep temizligi basarisiz: {}", e.toString());
        }
    }

    @Transactional
    public int cleanup(Instant now) {
        int a = tickets.deleteUnverifiedBefore(now.minus(UNVERIFIED_TTL));
        int b = tickets.deletePublicUpdatedBefore(now.minus(Duration.ofDays(props.publicTicketRetentionDays())));
        return a + b;
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
        if (t == null || !t.isPublicTicket() || !t.isEmailVerified()) {
            limiter.check("pubsup:bad:" + ip, 20, Duration.ofHours(1)); // anahtar tahmini denemelerini sinirla
            throw new ApiException(HttpStatus.NOT_FOUND, "TICKET_NOT_FOUND", "Talep bulunamadı.");
        }
        return t;
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
