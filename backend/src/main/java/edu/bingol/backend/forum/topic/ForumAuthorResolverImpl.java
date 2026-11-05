package edu.bingol.backend.forum.topic;

import edu.bingol.backend.forum.topic.dto.Author;
import edu.bingol.backend.forum.topic.spi.ForumAuthorResolver;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yazar gorunumunun tek uretim yeri. ANONIM yazar: ad "Anonim #N" (istek dili), kimlik/avatar/bolum yok.
 * Anonim olmayan yazar: ad/avatar/bolum mevcut profil servisinden ({@link PublicProfileMapper}: avatar ve bolum
 * gizlilik ayarlarina tabidir). Aktif olmayan hesap kimliksiz "silinmis kullanici" olur.
 */
@Service
public class ForumAuthorResolverImpl implements ForumAuthorResolver {

    private final UserRepository users;
    private final PublicProfileMapper profiles;
    private final ForumAnonAliasService aliases;
    private final I18n i18n;

    public ForumAuthorResolverImpl(UserRepository users, PublicProfileMapper profiles, ForumAnonAliasService aliases,
                                   I18n i18n) {
        this.users = users;
        this.profiles = profiles;
        this.aliases = aliases;
        this.i18n = i18n;
    }

    @Override
    @Transactional(readOnly = true)
    public List<Author> resolve(Long viewerId, List<Key> keys) {
        if (keys == null || keys.isEmpty()) {
            return List.of();
        }
        // Anonim olmayan yazarlar: tek toplu kullanici yuklemesi
        Set<Long> ids = new HashSet<>();
        for (Key k : keys) {
            if (!k.anonymous()) {
                ids.add(k.userId());
            }
        }
        Map<Long, Author> open = new HashMap<>();
        if (!ids.isEmpty()) {
            Map<Long, User> byId = users.findAllById(ids).stream()
                    .collect(Collectors.toMap(User::getId, Function.identity()));
            List<User> active = new ArrayList<>();
            for (Long id : ids) {
                User u = byId.get(id);
                if (u != null && u.getStatus() == UserStatus.ACTIVE) {
                    active.add(u);
                }
            }
            List<PublicProfile> mapped = active.isEmpty() ? List.of() : profiles.mapAll(viewerId, active);
            for (int i = 0; i < active.size(); i++) {
                PublicProfile p = mapped.get(i);
                open.put(active.get(i).getId(), new Author(p.id(), p.displayName(), p.avatarUrl(), p.department(), false));
            }
        }
        // Anonim yazarlar: konu basina mevcut numaralar tek sorguda; eksik olan tahsis edilir
        Map<Long, Set<Long>> wanted = new HashMap<>();
        for (Key k : keys) {
            if (k.anonymous()) {
                wanted.computeIfAbsent(k.topicId(), t -> new HashSet<>()).add(k.userId());
            }
        }
        Map<Long, Map<Long, Integer>> numbers = new HashMap<>();
        for (Map.Entry<Long, Set<Long>> e : wanted.entrySet()) {
            Map<Long, Integer> have = new HashMap<>(aliases.existing(e.getKey(), e.getValue()));
            for (Long uid : e.getValue()) {
                have.computeIfAbsent(uid, u -> aliases.aliasFor(e.getKey(), u));
            }
            numbers.put(e.getKey(), have);
        }
        List<Author> out = new ArrayList<>(keys.size());
        for (Key k : keys) {
            if (k.anonymous()) {
                int n = numbers.get(k.topicId()).get(k.userId());
                out.add(Author.anonymous(i18n.current("forum.anon.name", String.valueOf(n))));
            } else {
                Author a = open.get(k.userId());
                out.add(a != null ? a : new Author(null, i18n.current("forum.author.deleted"), null, null, false));
            }
        }
        return out;
    }
}
