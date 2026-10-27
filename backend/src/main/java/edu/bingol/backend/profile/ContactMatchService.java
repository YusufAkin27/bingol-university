package edu.bingol.backend.profile;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.ContactMatchDtos.Match;
import edu.bingol.backend.profile.ContactMatchDtos.MatchResponse;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Rehber eslestirme. Gelen hash'ler ve sonuclar saklanmaz/loglanmaz; yalnizca istek suresince bellekte tutulur.
 * Gorunurluk: alan bazli gizlilik {@link PublicProfileMapper} uzerinden (avatar, fakulte, bolum).
 */
@Service
public class ContactMatchService {

    static final int MAX_HASHES = 500;
    private static final Pattern SHA256_HEX = Pattern.compile("[0-9a-f]{64}");

    private final UserRepository users;
    private final BlockService blocks;
    private final PublicProfileMapper mapper;

    public ContactMatchService(UserRepository users, BlockService blocks, PublicProfileMapper mapper) {
        this.users = users;
        this.blocks = blocks;
        this.mapper = mapper;
    }

    public MatchResponse match(Long viewerId, List<String> rawHashes) {
        List<String> input = rawHashes == null ? List.of() : rawHashes;
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
        Set<Long> excluded = new HashSet<>(blocks.hiddenFrom(viewerId));
        excluded.add(viewerId);
        excluded.add(-1L);
        List<User> found = users.findContactMatches(hashes, excluded);
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
}
