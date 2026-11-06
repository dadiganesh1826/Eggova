package com.eggova.repository;

import com.eggova.entity.EggPrice;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface EggPriceRepository extends JpaRepository<EggPrice, UUID> {

    Optional<EggPrice> findByDistrictAndPriceDate(String district, LocalDate priceDate);

    Optional<EggPrice> findFirstByDistrictOrderByPriceDateDesc(String district);

    List<EggPrice> findAllByPriceDateOrderByDistrictAsc(LocalDate priceDate);

    List<EggPrice> findAllByDistrictOrderByPriceDateDesc(String district, Pageable pageable);

    List<EggPrice> findAllByOrderByPriceDateDesc(Pageable pageable);

    @Modifying
    @Transactional
    @Query("DELETE FROM EggPrice e WHERE e.district = :district AND e.priceDate = :priceDate")
    void deleteByDistrictAndPriceDate(@Param("district") String district, @Param("priceDate") LocalDate priceDate);
}

