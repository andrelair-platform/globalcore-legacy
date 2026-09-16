package com.globalcorp.gcore;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * GlobalCore — a deliberately-legacy insurance System of Record.
 * Java 8 / Spring / SOAP / nightly batch / one shared PostgreSQL schema.
 * Once seeded it is FROZEN: modern features are built AROUND it, never inside it.
 */
@SpringBootApplication
@EnableScheduling
public class GlobalCoreApplication {
    public static void main(String[] args) {
        SpringApplication.run(GlobalCoreApplication.class, args);
    }
}
