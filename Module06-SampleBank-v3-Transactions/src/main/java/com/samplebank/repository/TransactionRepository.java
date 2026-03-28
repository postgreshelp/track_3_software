package com.samplebank.repository;

import com.samplebank.entity.Transaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TransactionRepository extends JpaRepository<Transaction, Long> {

    List<Transaction> findByFromUserId(Long fromUserId);

    List<Transaction> findByToUserId(Long toUserId);
}
