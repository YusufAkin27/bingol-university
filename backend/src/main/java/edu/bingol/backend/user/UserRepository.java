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

    /** P16: etkin FULL yonetici sayisi (profili bos eski yoneticiler de FULL sayilir); son FULL korumasi icin. */
    @Query("SELECT COUNT(u) FROM User u WHERE u.role = edu.bingol.backend.user.Role.ADMIN"
            + " AND u.status = edu.bingol.backend.user.UserStatus.ACTIVE"
            + " AND (u.adminProfile IS NULL OR u.adminProfile = edu.bingol.backend.admin.rbac.AdminProfile.FULL)")
    long countFullAdmins();

    /** P16: silinmemis tum yonetici hesaplari (profil atama listesi). */
    @Query("SELECT u FROM User u WHERE u.role = edu.bingol.backend.user.Role.ADMIN"
            + " AND u.status <> edu.bingol.backend.user.UserStatus.DELETED ORDER BY u.id")
    List<User> findAllAdmins();

    @Query("SELECT u.language FROM User u WHERE u.id = :id")
    Optional<String> findLanguage(@Param("id") Long id);

    @Query("SELECT DISTINCT u.department FROM User u WHERE u.department IS NOT NULL AND u.status = edu.bingol.backend.user.UserStatus.ACTIVE ORDER BY u.department")
    List<String> distinctDepartments();

    /** Katlanmis ad ifadesi: V1230 trigram indeksiyle BIREBIR ayni (edu.bingol.backend.search.TrFold). */
    String NAME_FOLD = "lower(translate(u.display_name, '" + edu.bingol.backend.search.TrFold.SQL_FROM + "', '"
            + edu.bingol.backend.search.TrFold.SQL_TO + "'))";

    /**
     * Isme gore arama: Turkce harf ve buyuk/kucuk harf duyarsiz, KISMI eslesme (her sozcuk-parcasi adin herhangi bir
     * yerinde gecmeli, en cok 3 parca; kullanilmayanlar '' = hepsi). Siralama: tam ad, ad/soyad onek eslesmesi, sonra
     * digerleri; alfabetik. Yalnizca aktif, dogrulanmis, silinmemis kullanicilar. Parametreler TrFold ile katlanmis,
     * LIKE kacisli (\, %, _) gelir; q = kacissiz katlanmis tam sorgu (esitlik icin).
     */
    @Query(value = "SELECT u.* FROM app_user u WHERE u.status = 'ACTIVE' AND u.email_verified = TRUE AND u.deleted_at IS NULL "
            + "AND u.id NOT IN (:excluded) "
            + "AND " + NAME_FOLD + " LIKE concat('%', :t1, '%') ESCAPE '\\' "
            + "AND " + NAME_FOLD + " LIKE concat('%', :t2, '%') ESCAPE '\\' "
            + "AND " + NAME_FOLD + " LIKE concat('%', :t3, '%') ESCAPE '\\' "
            + "ORDER BY CASE WHEN " + NAME_FOLD + " = :q THEN 0 "
            + "WHEN " + NAME_FOLD + " LIKE concat(:qe, '%') ESCAPE '\\' THEN 1 "
            + "WHEN concat(' ', " + NAME_FOLD + ") LIKE concat('% ', :qe, '%') ESCAPE '\\' THEN 2 ELSE 3 END, "
            + NAME_FOLD + ", u.id "
            + "LIMIT :lim OFFSET :off", nativeQuery = true)
    List<User> searchByNameFolded(@Param("q") String foldedQuery, @Param("qe") String escapedQuery,
                                  @Param("t1") String t1, @Param("t2") String t2, @Param("t3") String t3,
                                  @Param("excluded") Collection<Long> excluded, @Param("lim") int limit,
                                  @Param("off") int offset);

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
