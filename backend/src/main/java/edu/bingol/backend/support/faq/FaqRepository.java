package edu.bingol.backend.support.faq;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FaqRepository extends JpaRepository<FaqItem, Long> {

    List<FaqItem> findByLangAndPublishedTrueOrderByCategoryAscSortOrderAscIdAsc(String lang);

    Slice<FaqItem> findAllByOrderByLangAscCategoryAscSortOrderAscIdAsc(Pageable pageable);
}
