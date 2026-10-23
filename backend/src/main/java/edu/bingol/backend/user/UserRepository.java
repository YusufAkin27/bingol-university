package edu.bingol.backend.user;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    long countByStatus(UserStatus status);

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
