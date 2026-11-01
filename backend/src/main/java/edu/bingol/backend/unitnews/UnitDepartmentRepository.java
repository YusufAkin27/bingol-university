package edu.bingol.backend.unitnews;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UnitDepartmentRepository extends JpaRepository<UnitDepartment, Long> {

    List<UnitDepartment> findBySourceCodeOrderByNameAsc(String sourceCode);

    List<UnitDepartment> findByNameKeyIn(Collection<String> keys);

    long countBySourceCode(String sourceCode);
}
