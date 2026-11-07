package com.eggova;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class EggovaApplication {

    public static void main(String[] args) {
        SpringApplication.run(EggovaApplication.class, args);
    }
}
