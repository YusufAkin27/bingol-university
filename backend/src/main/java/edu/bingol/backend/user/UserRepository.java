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

    @Query("SELECT u.language FROM User u WHERE u.id = :id")
    Optional<String> findLanguage(@Param("id") Long id);

    @Query("SELECT DISTINCT u.department FROM User u WHERE u.department IS NOT NULL AND u.status = edu.bingol.backend.user.UserStatus.ACTIVE ORDER BY u.department")
    List<String> distinctDepartments();

    /** Isme gore arama (buyuk/kucuk harf duyarsiz). Yalnizca aktif ve dogrulanmis kullanicilar. */
    @Query(value = """
            SELECT * FROM app_user
            WHERE status = 'ACTIVE' AND email_verified = TRUE
              AND lower(display_name) LIKE lower(concat('%', :q, '%')) ESCAPE '\\'
              AND id NOT IN (:excluded)
            ORDER BY display_name, id
            LIMIT :lim
            """, nativeQuery = true)
    List<User> searchByName(@Param("q") String escapedQuery, @Param("excluded") Collection<Long> excluded,
                            @Param("lim") int limit);
}
