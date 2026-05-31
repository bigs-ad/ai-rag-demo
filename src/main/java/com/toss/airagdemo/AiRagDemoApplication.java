package com.toss.airagdemo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;


@SpringBootApplication(exclude = {
        org.springframework.cloud.function.context.config.ContextFunctionCatalogAutoConfiguration.class
})
public class AiRagDemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(AiRagDemoApplication.class, args);
    }

}
