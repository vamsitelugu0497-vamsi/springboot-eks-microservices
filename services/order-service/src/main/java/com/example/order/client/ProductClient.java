package com.example.order.client;

import com.example.order.dto.ProductResponse;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
public class ProductClient {
    private final RestClient client;
    public ProductClient(RestClient.Builder builder, @Value("${clients.product-service.url}") String baseUrl) {
        this.client = builder.baseUrl(baseUrl).build();
    }

    @Retry(name = "productService")
    @CircuitBreaker(name = "productService")
    public ProductResponse getProduct(Long id) {
        return client.get().uri("/api/v1/products/{id}", id).retrieve().body(ProductResponse.class);
    }
}
