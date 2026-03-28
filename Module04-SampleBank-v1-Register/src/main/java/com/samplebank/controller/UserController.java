package com.samplebank.controller;

import com.samplebank.entity.User;
import com.samplebank.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
public class UserController {

    @Autowired
    private UserRepository userRepository;

    @PostMapping("/register")
    public ResponseEntity<String> register(@RequestBody Map<String, String> request) {
        String username = request.get("username");
        String email = request.get("email");
        String password = request.get("password");

        if (username == null || username.trim().isEmpty()) {
            return ResponseEntity.badRequest().body("ERROR: Username is required");
        }
        if (email == null || email.trim().isEmpty()) {
            return ResponseEntity.badRequest().body("ERROR: Email is required");
        }
        if (password == null || password.trim().isEmpty()) {
            return ResponseEntity.badRequest().body("ERROR: Password is required");
        }

        if (userRepository.existsByUsername(username)) {
            return ResponseEntity.badRequest().body("ERROR: Username already exists");
        }

        User user = new User(username, email, password);
        userRepository.save(user);

        return ResponseEntity.ok("Registered successfully! Account created with $1000.00");
    }
}
