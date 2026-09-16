package com.globalcorp.gcore.batch;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * The "nightly" batch — runs on a cron (every 2 min in dev, standing in for overnight).
 * Nothing becomes official in real time: this batch is what activates pending policies
 * and generates renewals. That deliberate lag is a core legacy trait to design around.
 */
@Component
public class NightlyBatch {

    private static final Logger log = LoggerFactory.getLogger(NightlyBatch.class);
    private final JdbcTemplate jdbc;

    public NightlyBatch(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Scheduled(cron = "${gcore.batch.cron}")
    public void run() {
        log.info("=== GlobalCore nightly batch starting ===");
        Integer activated = jdbc.queryForObject("SELECT gcore_activate_pending()", Integer.class);
        Integer renewed = jdbc.queryForObject("SELECT gcore_gen_renewals(60)", Integer.class);
        log.info("=== nightly batch done: {} pending policies activated, {} renewals generated ===",
                activated, renewed);
    }
}
