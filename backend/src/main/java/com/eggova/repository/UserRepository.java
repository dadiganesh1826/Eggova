package com.eggova.repository;

import com.eggova.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByEmail(String email);

    Optional<User> findByPhone(String phone);

    Optional<User> findFirstByRole(User.Role role);

    List<User> findAllByRoleOrderByCreatedAtDesc(User.Role role);

    List<User> findAllByRoleAndStatusOrderByCreatedAtDesc(User.Role role, User.Status status);

    List<User> findAllByPendingPhoneIsNotNullOrderByUpdatedAtDesc();

    List<User> findAllByRole(User.Role role);

    long countByRole(User.Role role);
}

