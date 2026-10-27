package edu.bingol.backend.post.social;

import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * @etiket onerisi: takip ettiklerim, yazistiklarim, ayni bolum onceliklidir (gonderi verilirse gonderi sahibi ve
 * yorumcular en ustte). Bos sorguda yalniz oncelikli kisiler; yalniz aktif + dogrulanmis; engel iliskisi hari.
 */
@Service
public class MentionSuggestService {

    public record Suggestion(Long id, String displayName, String avatarUrl, String department) {}

    static final int MAX = 8;

    private final JdbcTemplate jdbc;
    private final UserRepository users;
    private final PublicProfileMapper profiles;

    public MentionSuggestService(JdbcTemplate jdbc, UserRepository users, PublicProfileMapper profiles) {
        this.jdbc = jdbc;
        this.users = users;
        this.profiles = profiles;
    }

    @Transactional(readOnly = true)
    public List<Suggestion> suggest(Long viewer, String rawQ, Long postId, int size) {
        int n = size <= 0 ? MAX : Math.min(size, MAX);
        String q = rawQ == null ? "" : rawQ.strip();
        if (q.startsWith("@")) {
            q = q.substring(1);
        }
        if (q.length() > 40) {
            q = q.substring(0, 40);
        }
        String dept = users.findById(viewer).map(User::getDepartment).orElse(null);
        List<Object> args = new ArrayList<>();
        // oncelik: 0 gonderi sahibi/yorumcu, 1 takip, 2 yazisma, 3 bolum, 4 diger
        StringBuilder pri = new StringBuilder("CASE ");
        if (postId != null) {
            pri.append("WHEN u.id = (SELECT author_id FROM post WHERE id = ?) OR u.id IN (SELECT author_id FROM post_comment "
                    + "WHERE post_id = ? AND deleted_at IS NULL) THEN 0 ");
            args.add(postId);
            args.add(postId);
        }
        pri.append("WHEN EXISTS (SELECT 1 FROM user_follow f WHERE f.follower_id = ? AND f.followee_id = u.id) THEN 1 ");
        args.add(viewer);
        pri.append("WHEN EXISTS (SELECT 1 FROM conversation_member a JOIN conversation_member b "
                + "ON a.conversation_id = b.conversation_id WHERE a.user_id = ? AND b.user_id = u.id) THEN 2 ");
        args.add(viewer);
        if (dept != null && !dept.isBlank()) {
            pri.append("WHEN u.department = ? THEN 3 ");
            args.add(dept);
        }
        pri.append("ELSE 4 END");
        StringBuilder sql = new StringBuilder("SELECT id FROM (SELECT u.id AS id, u.display_name AS name, ").append(pri)
                .append(" AS pri FROM app_user u WHERE u.status = 'ACTIVE' AND u.email_verified = TRUE AND u.id <> ? "
                        + "AND NOT EXISTS (SELECT 1 FROM user_block b WHERE (b.blocker_id = ? AND b.blocked_id = u.id) "
                        + "OR (b.blocker_id = u.id AND b.blocked_id = ?))");
        args.add(viewer);
        args.add(viewer);
        args.add(viewer);
        if (!q.isEmpty()) {
            sql.append(" AND u.display_name ILIKE ? ESCAPE '\\'");
            args.add("%" + q.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%");
        }
        sql.append(") t");
        if (q.isEmpty()) {
            sql.append(" WHERE pri < 4");
        }
        sql.append(" ORDER BY pri, name, id LIMIT ").append(n);
        List<Long> ids = jdbc.queryForList(sql.toString(), Long.class, args.toArray());
        if (ids.isEmpty()) {
            return List.of();
        }
        Map<Long, PublicProfile> byId = new HashMap<>();
        profiles.mapAll(viewer, users.findAllById(ids)).forEach(p -> byId.put(p.id(), p));
        List<Suggestion> out = new ArrayList<>();
        for (Long id : ids) {
            PublicProfile p = byId.get(id);
            if (p != null) {
                out.add(new Suggestion(p.id(), p.displayName(), p.avatarUrl(), p.department()));
            }
        }
        return out;
    }
}
