package com.eggova.repository;

import com.eggova.entity.Order;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OrderRepository extends JpaRepository<Order, UUID> {

    List<Order> findAllByUserIdOrderByCreatedAtDesc(UUID userId);

    Optional<Order> findByIdAndUserId(UUID id, UUID userId);

    Optional<Order> findByRazorpayOrderIdAndUserId(String razorpayOrderId, UUID userId);

    Optional<Order> findByRazorpayOrderId(String razorpayOrderId);

    @Query("SELECT o FROM Order o LEFT JOIN FETCH o.user WHERE o.paymentStatus IN :statuses ORDER BY o.createdAt DESC")
    List<Order> findAllByPaymentStatusInOrderByCreatedAtDesc(@Param("statuses") List<Order.PaymentStatus> statuses);

    @Query("SELECT o FROM Order o LEFT JOIN FETCH o.user WHERE o.paymentStatus = :status ORDER BY o.paidAt DESC")
    List<Order> findAllByPaymentStatusOrderByPaidAtDesc(@Param("status") Order.PaymentStatus status);

    @Query("SELECT COALESCE(SUM(o.totalAmount), 0) FROM Order o WHERE o.paymentStatus = :status")
    Double sumTotalAmountByPaymentStatus(@Param("status") Order.PaymentStatus status);

    @Query("SELECT COALESCE(SUM(o.totalAmount), 0) FROM Order o WHERE o.paymentStatus IN :statuses")
    Double sumTotalAmountByPaymentStatusIn(@Param("statuses") List<Order.PaymentStatus> statuses);

    long countByPaymentStatusIn(List<Order.PaymentStatus> statuses);

    long countByPaymentStatus(Order.PaymentStatus status);
}

