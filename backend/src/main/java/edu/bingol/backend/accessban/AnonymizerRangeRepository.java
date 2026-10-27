package edu.bingol.backend.accessban;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AnonymizerRangeRepository extends JpaRepository<AnonymizerRange, Long> {

    Optional<AnonymizerRange> findByCidr(String cidr);
}
