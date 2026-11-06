package com.eggova.repository;

import com.eggova.entity.DailyStock;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DailyStockRepository extends JpaRepository<DailyStock, UUID> {

    Optional<DailyStock> findByDate(LocalDate date);
}

