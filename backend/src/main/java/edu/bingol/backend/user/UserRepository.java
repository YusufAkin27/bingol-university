package edu.bingol.backend.user;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserRepository extends JpaRepository<User, Long> {

    /** Push kitlesi cozumlemesi icin hafif projeksiyon. */
    interface UserLang {
        Long getId();

        String getLanguage();
    }

    String AUDIENCE_BASE = "SELECT id AS id, language AS language FROM app_user WHERE status = 'ACTIVE' AND email_verified = TRUE";

    @Query(value = AUDIENCE_BASE, nativeQuery = true)
    List<UserLang> audienceAll();

    @Query(value = AUDIENCE_BASE + " AND department = :dept", nativeQuery = true)
    List<UserLang> audienceDepartment(@Param("dept") String department);

    @Query(value = AUDIENCE_BASE + " AND class_year = :year", nativeQuery = true)
    List<UserLang> audienceClassYear(@Param("year") short year);

    @Query(value = AUDIENCE_BASE + " AND id IN (:ids)", nativeQuery = true)
    List<UserLang> audienceIds(@Param("ids") Collection<Long> ids);

    @Query(value = AUDIENCE_BASE + " AND role = 'ADMIN'", nativeQuery = true)
    List<UserLang> audienceAdmins();

    Optional<User> findByEmail(String email);

    long countByStatus(UserStatus status);

    long countByRoleAndStatus(Role role, UserStatus status);

    /** Son yonetici kontrolunde yarisi onlemek icin tum yonetici satirlarini kilitler (FOR UPDATE; PostgreSQL). */
    @Query(value = "SELECT id FROM app_user WHERE role = 'ADMIN' ORDER BY id FOR UPDATE", nativeQuery = true)
    List<Long> lockAdminIds();

    @Query("SELECT u.language FROM User u WHERE u.id = :id")
    Optional<String> findLanguage(@Param("id") Long id);

    @Query("SELECT DISTINCT u.department FROM User u WHERE u.department IS NOT NULL AND u.status = edu.bingol.backend.user.UserStatus.ACTIVE ORDER BY u.department")
    List<String> distinctDepartments();

    /** Isme gore arama (buyuk/kucuk harf duyarsiz). Yalnizca aktif ve dogrulanmis kullanicilar. */
    @Query(value = """
            SELECT * FROM app_user
            WHERE status = 'ACTIVE' AND email_verified = TRUE
              AND display_name ILIKE concat('%', :q, '%') ESCAPE '\\'
              AND id NOT IN (:excluded)
            ORDER BY display_name, id
            LIMIT :lim OFFSET :off
            """, nativeQuery = true)
    List<User> searchByName(@Param("q") String escapedQuery, @Param("excluded") Collection<Long> excluded,
                            @Param("lim") int limit, @Param("off") int offset);

    /**
     * Rehber eslestirme: e-posta hash'i ile aktif, dogrulanmis, bingol.edu.tr (ve alt alan) kullanicilari bulur.
     * Hash sutunu indeksli (usr240_email_sha256); engel/kendi hesabi `excluded` ile elenir.
     */
    @Query(value = """
            SELECT * FROM app_user
            WHERE email_sha256 IN (:hashes)
              AND status = 'ACTIVE' AND email_verified = TRUE AND deleted_at IS NULL
              AND (email LIKE '%@bingol.edu.tr' OR email LIKE '%@%.bingol.edu.tr')
              AND id NOT IN (:excluded)
            """, nativeQuery = true)
    List<User> findContactMatches(@Param("hashes") Collection<String> hashes,
                                  @Param("excluded") Collection<Long> excluded);
}
