package com.samplebank.controller;

import com.samplebank.entity.User;
import com.samplebank.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Optional;

@RestController
public class AuthController {

    @Autowired
    private UserRepository userRepository;

    @PostMapping("/login")
    public ResponseEntity<String> login(@RequestBody Map<String, String> request) {
        String username = request.get("username");
        String password = request.get("password");

        if (username == null || username.trim().isEmpty()) {
            return ResponseEntity.badRequest().body("ERROR: Username is required");
        }
        if (password == null || password.trim().isEmpty()) {
            return ResponseEntity.badRequest().body("ERROR: Password is required");
        }

        Optional<User> userOpt = userRepository.findByUsername(username);

        if (userOpt.isEmpty()) {
            return ResponseEntity.badRequest().body("ERROR: User not found");
        }

        User user = userOpt.get();

        if (!user.getPasswordHash().equals(password)) {
            return ResponseEntity.badRequest().body("ERROR: Invalid password");
        }

        return ResponseEntity.ok(String.format("Login successful! Balance: $%.2f", user.getBalance()));
    }
}
