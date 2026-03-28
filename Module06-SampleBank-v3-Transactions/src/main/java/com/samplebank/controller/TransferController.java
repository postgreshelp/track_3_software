package com.samplebank.controller;

import com.samplebank.entity.User;
import com.samplebank.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.persistence.EntityManager;
import javax.persistence.PersistenceContext;
import java.math.BigDecimal;
import java.util.Map;
import java.util.Optional;

@RestController
public class TransferController {

    @Autowired
    private UserRepository userRepository;

    @PersistenceContext
    private EntityManager entityManager;

    @PostMapping("/transfer")
    public ResponseEntity<String> transfer(@RequestBody Map<String, String> request) {
        String fromUsername = request.get("fromUsername");
        String toUsername = request.get("toUsername");
        String amountStr = request.get("amount");

        if (fromUsername == null || fromUsername.trim().isEmpty()) {
            return ResponseEntity.badRequest().body("ERROR: Sender username is required");
        }
        if (toUsername == null || toUsername.trim().isEmpty()) {
            return ResponseEntity.badRequest().body("ERROR: Receiver username is required");
        }
        if (amountStr == null || amountStr.trim().isEmpty()) {
            return ResponseEntity.badRequest().body("ERROR: Amount is required");
        }

        BigDecimal amount;
        try {
            amount = new BigDecimal(amountStr);
            if (amount.compareTo(BigDecimal.ZERO) <= 0) {
                return ResponseEntity.badRequest().body("ERROR: Amount must be greater than 0");
            }
        } catch (NumberFormatException e) {
            return ResponseEntity.badRequest().body("ERROR: Invalid amount format");
        }

        String result = entityManager
            .createNativeQuery("SELECT transfer_money(:from, :to, :amount)")
            .setParameter("from", fromUsername)
            .setParameter("to", toUsername)
            .setParameter("amount", amount)
            .getSingleResult()
            .toString();

        return ResponseEntity.ok(result);
    }

    @GetMapping("/balance/{username}")
    public ResponseEntity<String> getBalance(@PathVariable String username) {
        Optional<User> userOpt = userRepository.findByUsername(username);

        if (userOpt.isEmpty()) {
            return ResponseEntity.badRequest().body("ERROR: User not found");
        }

        User user = userOpt.get();
        return ResponseEntity.ok(String.format("Balance for %s: $%.2f", username, user.getBalance()));
    }
}
