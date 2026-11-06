package edu.bingol.backend.forum.category;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface ForumCategoryGroupRepository extends JpaRepository<ForumCategoryGroup, String> {

    /** Grup sayisi kucuk ve sabittir (migration tohumu); yine de ust sinirli okunur. */
    @Query("SELECT g FROM ForumCategoryGroup g ORDER BY g.sortOrder, g.groupKey")
    List<ForumCategoryGroup> allOrdered(org.springframework.data.domain.Pageable page);
}
