package edu.bingol.backend.profile;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.ContactMatchDtos.Match;
import edu.bingol.backend.profile.ContactMatchDtos.MatchResponse;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.ProfilePrivacy;
import edu.bingol.backend.profile.privacy.ProfilePrivacyRepository;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Rehber eslestirme. Gelen hash'ler ve sonuclar saklanmaz/loglanmaz; yalnizca istek suresince bellekte tutulur.
 * Gorunurluk: alan bazli gizlilik {@link PublicProfileMapper} uzerinden (avatar, fakulte, bolum).
 *
 * <p>T-061 (K-16 onerisi): "Rehberden bulunabilirim" acik onayi (varsayilan KAPALI) KARSILIKLIDIR: yalnizca
 * kendisi de bulunabilir olan kullanici eslestirme yapabilir ve yalnizca bulunabilir olanlar doner (kimlik/profil
 * yalniz karsilikli eslesmede). Okul numarasi adresleri (numara@bingol.edu.tr) rehber eslestirmesinden cikarilir.
 * Hesap basina gunluk aday tavani {@link ContactMatchQuota}.
 */
@Service
public class ContactMatchService {

    static final int MAX_HASHES = 500;
    private static final Pattern SHA256_HEX = Pattern.compile("[0-9a-f]{64}");

    private final UserRepository users;
    private final BlockService blocks;
    private final PublicProfileMapper mapper;
    private final ProfilePrivacyRepository privacy;
    private final ContactMatchQuota quota;

    /** Okul numarasi adresi: yerel kisim yalniz rakam (ogrenci numarasi tahmin edilebilir aday uzayi). */
    private static final Pattern NUMERIC_LOCAL = Pattern.compile("\\d+");

    public ContactMatchService(UserRepository users, BlockService blocks, PublicProfileMapper mapper,
                               ProfilePrivacyRepository privacy, ContactMatchQuota quota) {
        this.users = users;
        this.blocks = blocks;
        this.mapper = mapper;
        this.privacy = privacy;
        this.quota = quota;
    }

    public boolean isDiscoverable(Long userId) {
        return privacy.findById(userId).map(ProfilePrivacy::isContactsDiscoverable).orElse(false);
    }

    @Transactional
    public void setDiscoverable(Long userId, boolean enabled) {
        ProfilePrivacy p = privacy.findById(userId).orElseGet(() -> ProfilePrivacy.defaults(userId));
        p.setContactsDiscoverable(enabled);
        p.setUpdatedAt(Instant.now());
        privacy.save(p);
    }

    public MatchResponse match(Long viewerId, List<String> rawHashes) {
        List<String> input = rawHashes == null ? List.of() : rawHashes;
        if (!isDiscoverable(viewerId)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "CONTACTS_DISCOVERABLE_REQUIRED",
                    "Rehber eşleştirme için önce “Rehberden bulunabilirim” ayarını açmalısınız.");
        }
        if (input.size() > MAX_HASHES) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CONTACTS_TOO_MANY",
                    "En fazla {0} kişi gönderilebilir.", String.valueOf(MAX_HASHES));
        }
        // Yinelenenler atilir; biçimi bozuk degerler sessizce yok sayilir
        Set<String> hashes = new LinkedHashSet<>();
        for (String h : input) {
            if (h != null) {
                String n = h.trim().toLowerCase(Locale.ROOT);
                if (SHA256_HEX.matcher(n).matches()) {
                    hashes.add(n);
                }
            }
        }
        if (hashes.isEmpty()) {
            return new MatchResponse(List.of());
        }
        quota.consume(viewerId, hashes.size());
        Set<Long> excluded = new HashSet<>(blocks.hiddenFrom(viewerId));
        excluded.add(viewerId);
        excluded.add(-1L);
        List<User> found = visibleOnly(users.findContactMatches(hashes, excluded));
        if (found.isEmpty()) {
            return new MatchResponse(List.of());
        }
        List<PublicProfile> profiles = mapper.mapAll(viewerId, found);
        List<Match> out = new java.util.ArrayList<>(found.size());
        for (int i = 0; i < found.size(); i++) {
            User u = found.get(i);
            PublicProfile p = profiles.get(i);
            out.add(new Match(u.getEmailSha256(), u.getId(), p.displayName(), p.avatarUrl(), p.faculty(),
                    p.department()));
        }
        return new MatchResponse(out);
    }

    /** Okul numarali adresleri ve "bulunabilirim" demeyenleri eler. */
    private List<User> visibleOnly(List<User> found) {
        List<User> candidates = new java.util.ArrayList<>();
        for (User u : found) {
            if (!isSchoolNumber(u.getEmail())) {
                candidates.add(u);
            }
        }
        if (candidates.isEmpty()) {
            return candidates;
        }
        Set<Long> optedIn = new HashSet<>();
        for (ProfilePrivacy p : privacy.findByUserIdIn(candidates.stream().map(User::getId).toList())) {
            if (p.isContactsDiscoverable()) {
                optedIn.add(p.getUserId());
            }
        }
        return candidates.stream().filter(u -> optedIn.contains(u.getId())).toList();
    }

    static boolean isSchoolNumber(String email) {
        if (email == null) {
            return false;
        }
        int at = email.indexOf('@');
        return at > 0 && NUMERIC_LOCAL.matcher(email.substring(0, at)).matches();
    }
}
