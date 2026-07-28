package com.example.order.service;

import com.example.order.client.ProductClient;
import com.example.order.client.UserClient;
import com.example.order.dto.ProductResponse;
import com.example.order.model.Order;
import com.example.order.repository.OrderRepository;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

import java.util.List;
import java.util.Optional;

@Service
public class OrderService {
    private final OrderRepository repository;
    private final UserClient userClient;
    private final ProductClient productClient;

    public OrderService(OrderRepository repository, UserClient userClient, ProductClient productClient) {
        this.repository = repository;
        this.userClient = userClient;
        this.productClient = productClient;
    }

    public List<Order> findAll() { return repository.findAll(); }
    public Optional<Order> findById(Long id) { return repository.findById(id); }

    public Order save(Order entity) {
        if (entity.getUserId() == null || entity.getProductId() == null || entity.getQuantity() == null || entity.getQuantity() <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "userId, productId and positive quantity are required");
        }
        try {
            userClient.getUser(entity.getUserId());
            ProductResponse product = productClient.getProduct(entity.getProductId());
            if (product == null || product.stock() == null || product.stock() < entity.getQuantity()) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "Insufficient product stock");
            }
        } catch (ResponseStatusException e) {
            throw e;
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Dependent service unavailable", e);
        }
        if (entity.getStatus() == null || entity.getStatus().isBlank()) entity.setStatus("CREATED");
        return repository.save(entity);
    }

    public void deleteById(Long id) { repository.deleteById(id); }
}
