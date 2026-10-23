package edu.bingol.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class BingolBackendApplication {

	public static void main(String[] args) {
		SpringApplication.run(BingolBackendApplication.class, args);
	}

}
