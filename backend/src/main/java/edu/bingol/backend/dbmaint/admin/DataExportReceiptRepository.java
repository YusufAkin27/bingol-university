package edu.bingol.backend.dbmaint.admin;

import java.time.LocalDate;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface DataExportReceiptRepository extends JpaRepository<DataExportReceipt, Long> {

    List<DataExportReceipt> findTop50ByOrderByIdDesc();

    List<DataExportReceipt> findTop50ByTableNameOrderByIdDesc(String tableName);

    /** Silmeyi mesrulastiran makbuz: ayni tablo, TAMAMLANMIS, silinecek araligi kapsayan (en yeni once). */
    @Query("""
            SELECT r FROM DataExportReceipt r
            WHERE r.tableName = :t AND r.status = edu.bingol.backend.dbmaint.admin.DataExportReceipt.Status.COMPLETED
              AND r.rangeFrom <= :from AND r.rangeTo >= :to
            ORDER BY r.id DESC""")
    List<DataExportReceipt> covering(@Param("t") String table, @Param("from") LocalDate from,
                                     @Param("to") LocalDate to, Pageable page);
}
